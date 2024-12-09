xquery version "3.1";

module namespace search = "http://exist-db.org/apps/writerslibrary/search";

import module namespace templates="http://exist-db.org/xquery/html-templating" ;
import module namespace config = "http://exist-db.org/apps/writerslibrary/config" at "config.xqm";
import module namespace app = "http://exist-db.org/apps/writerslibrary/templates" at "app.xqm";
import module namespace library-book-view="http://exist-db.org/apps/writerslibrary/library-book-view" at "library-book-view.xql";
import module namespace library-functions="http://exist-db.org/apps/writerslibrary/library-functions" at "library-functions.xql";
import module namespace functx = "http://www.functx.com";

declare boundary-space preserve;
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare option exist:serialize "method=html5 media-type=text/html";

(:
:
: THIS MODULE CONTAINS THE LIBRARY SEARCH ENGINE
: 
: We made use of this guide:
: https://en.wikibooks.org/wiki/XQuery/Keyword_Search#Paginate_and_Summarize_Results
:)

declare function search:search($node as node(), $model as map(*), $q as xs:string?, $start as xs:integer?, $index as xs:string?, $doc as xs:string?, $AndOr as xs:string?) {   
    if ($q and not(starts-with($q,'*')) and not(starts-with($q,'?'))) then
        
        
        (: manually add the path to the library xml              :)
        let $libraryPath := $config:data-root || "/library"


        (: put together a collection from this list:)
        let $docs := 
            for $path in ($libraryPath) 
            return  
                if ($index eq "") then collection($path) 
                else if ($index ne "" and contains($path,$index)) then 
                    if ($doc ne "" and not(starts-with($doc,'library-'))) then doc(concat($path,"/",$doc,".xml")) 
                    else collection($path) 
                else ()


        let $options :=
                <options>
                    <default-operator>and</default-operator>
                    <leading-wildcard>no</leading-wildcard>
                    <filter-rewrite>yes</filter-rewrite>
                </options>
                
        let $configDoc :=doc($config:data-root || '/library/config.xml')
        let $imgUrl := $configDoc//imgUrl/serverPath
        
        (: for the bibliography + inscriptions it's the field library-book-biblio that needs to be queried :)
        let $fieldQueryLibraryBiblio := concat('library-book-biblio:(',$q,')')
        let $biblioQuery := 
          if ($doc eq "" or $doc eq "library-bibliography") then
             $docs//book[module[ft:query(.,$fieldQueryLibraryBiblio, $options) ]]
          else
            ()
        
        let $zoneQuery := 
          if ($doc eq "" or $doc eq "library-readingtraces") then 
                $docs//zone[ft:query(., $q, map { "fields": ("library-book-zone-bookID", "library-book-zone-pagenumber", "library-book-zone-author", "library-book-zone-title", "library-book-zone-subtitle")})]
          else if (starts-with($doc,"library-readingtraces-")) then
                $docs//zone[ancestor::book/data(@id) eq substring-after($doc,"traces-")][ft:query(., $q, map { "fields": ("library-book-zone-bookID", "library-book-zone-pagenumber", "library-book-zone-author", "library-book-zone-title", "library-book-zone-subtitle")})]
          else ()
        let $marginaliaQuery := $docs//m[ft:query(., $q, map { "fields": ("library-book-marginalia-bookID", "library-book-marginalia-zoneID", "library-book-marginalia-pagenumber", "library-book-marginalia-author", "library-book-marginalia-title", "library-book-marginalia-subtitle")})]

      
        (: the actual query, unsorted :)
        let $hits := $biblioQuery | $zoneQuery | $marginaliaQuery
       
        (: sort the hits :)
        let $sorted-hits :=  
                for $hit in $hits
                order by ft:score($hit) descending
                return $hit

        (: facets :)
        let $facets := ft:facets($sorted-hits, "module", ())
        let $documentFacet := ft:facets($sorted-hits, "document", ())
 

        (: count total hits :)
        let $total-result-count := xs:integer(count($sorted-hits))
        (: limit to 20 hits per page in result, get start position from url param :)
        let $start := if ($start) then $start else 0
        let $perpage := xs:integer(10)
        let $end := 
            if ($total-result-count lt $perpage) then 
            $total-result-count
            else 
            $start + $perpage

        let $number-of-pages := xs:integer(ceiling($total-result-count div $perpage))
        let $current-page := xs:integer(($start + $perpage) div $perpage)
        let $url-params-without-start := replace(request:get-query-string(), '&amp;start=\d+', '')
        let $pagination-links := 
            if ($total-result-count = 0) then ()
            else 
                    <ul class="pagination pagination-sm">
                        {
                        (: Show 'Previous' for all but the 1st page of results :)
                            if ($current-page = 1) then ()
                            else
                                <li><a href="{concat('?', $url-params-without-start, '&amp;start=', $perpage * ($current-page - 2)) }">Previous</a></li>
                        }
                
                       {
                        (: Show links to each page of results :)
                    let $max-pages-to-show := 20
                    let $padding := xs:integer(round($max-pages-to-show div 2))
                    let $start-page := 
                        if ($current-page le ($padding + 1)) then
                            1
                        else $current-page - $padding
                    let $end-page := 
                        if ($number-of-pages le ($current-page + $padding)) then
                            $number-of-pages
                        else $current-page + $padding - 1
                    for $page in ($start-page to $end-page)
                    let $newstart := $perpage * ($page - 1)
                    return
                        (
                        if ($newstart eq $start) then 
                            (<li class="active"><a>{$page}</a></li>)
                        else
                            <li><a href="{concat('?', $url-params-without-start, '&amp;start=', $newstart)}">{$page}</a></li>
                        )
                }
                
                {
                (: Shows 'Next' for all but the last page of results :)
                    if ($start + $perpage ge $total-result-count) then ()
                    else
                        <li><a href="{concat('?', $url-params-without-start, '&amp;start=', $start + $perpage)}">Next</a></li>
                }
            </ul>

        (: create results page for subset of 10 hits :)
        let $results := 
            for $hit at $pos in $sorted-hits[position() = ($start + 1 to $end)]
            let $moduleID := substring-after(util:collection-name($hit),'data/')
            let $highlightedResults := if ($q eq "_ManuscriptLink") then $hit else util:expand($hit)
            let $processedResult := 
                (: library bibliography hits :)
                if ($moduleID eq "library" and local-name($highlightedResults) eq "book") then 
                  <a class="booklinkssearch" href="../../library/{$highlightedResults/data(@id)}.html">
                    <table class="library" style="width:100%;">
                         <tr>
                            <td valign="top" width="90">
                                {if ($highlightedResults//facsimile) then 
                                   <img height="100" style="max-width:80px;" src="{if (starts-with($highlightedResults//facsimile[1]/text(),'https')) then "" else $imgUrl}{$highlightedResults//page[1]/facsimile/text()}"/>
                                 else
                                    if ($highlightedResults/@type eq "VL") then <div class="imagecontainer"><span class="noscan"></span><span class="virtualthumb">V<br/>I<br/>R<br/>T<br/>U<br/>A<br/>L</span></div> else <span class="noscan"></span>}
                            </td>
                            <td valign="top">
                                {library-book-view:getBiblio($node, $model, $highlightedResults) }
                            </td>
                         </tr>
                    </table>
                   </a>
                 (: library marginalia hits :)
                else if ($moduleID eq "library" and local-name($highlightedResults) eq "m") then
                   library-functions:readingTracesSearch($hit/ancestor::zone, ft:field($hit, "library-book-marginalia-bookID"), ft:field($hit, "library-book-marginalia-pagenumber"), ft:field($hit, "library-book-marginalia-author"), ft:field($hit, "library-book-marginalia-title"), ft:field($hit, "library-book-marginalia-subtitle"))
                 (: library reading trace hits :)
                else if ($moduleID eq "library" and local-name($highlightedResults) eq "zone") then
                   library-functions:readingTracesSearch($highlightedResults, ft:field($hit, "library-book-zone-bookID"), ft:field($hit, "library-book-zone-pagenumber"), ft:field($hit, "library-book-zone-author"), ft:field($hit, "library-book-zone-title"), ft:field($hit, "library-book-zone-subtitle"))

                (: genetic modules hits :)
                else 
                    ()
                    
            return
                <tr>
                    <td valign="top" style="width:40px;color:#999999;">{xs:integer($start + $pos)}</td>
                    <td valign="top"><span class="searchtext">{$processedResult}</span></td>
                </tr>
        (: return the entire thing :)
        return
            <div>
                <div class="hits" style="margin-top:10px">Found <b>{$total-result-count}</b> hits.</div>
                {if ($index ne "") then <span id="all"><br/>[<a href="index.html?q={$q}&amp;index=&amp;doc=">&#8592; all results</a>]</span> else ()}
                <!-- facets -->
                <div class="aggs">
                {
                    map:for-each($facets, function($label, $count) {
                    <div class="aggItem{if ($index ne "") then "Expanded" else ()}"><a href="index.html?q={$q}&amp;index={$label}&amp;doc=&amp;AndOr={$AndOr}" style="text-decoration:none;"><i>Library</i> { if ($doc eq "") then if ($q ne "_gap" and $q ne "_intertextual") then <span>(<b>{$count}</b>)</span> else() else ()}</a>
                     {if ($index ne "") then 
                         <ul class="documentFacet">
                            {
                                map:for-each($documentFacet, function($label, $count) { 
                                <li><a style="text-decoration:none;" href="index.html?q={$q}&amp;index={$index}&amp;doc={$label}&amp;AndOr={$AndOr}">{if ($label eq "library-bibliography") then "Bibliography" else if (starts-with($label, "library-readingtraces")) then "Reading Traces" else $label} { if (contains($doc,"traces-")) then () else <span>(<b>{$count}</b>)</span>}</a></li>
                                })
                            }
                         </ul>
                      else ()}
                    </div>
                    })
                }
                </div>
            <div class="pagination-div">{$pagination-links}</div>

            <table cellpadding="0" cellspacing="0" class="results" style="font-size:inherit;width:100%;">
            {$results}
            </table>
            <div class="pagination-div">{$pagination-links}</div><br/><br/>
            </div>

    else if ($q and starts-with($q,'*')) then
        <p>You cannot start a query with '*'.</p>
    else if ($q and starts-with($q,'?')) then
        <p>You cannot start a query with '?'.</p>
    else ()
    
};


declare function search:indexField($node as node(), $model as map(*)){
<select name="doc" id="doc" style="width:140px;">
   <option value="">everything</option>
   <option value="library-bibliography">bibliography</option>
   <option value="library-readingtraces">all reading traces</option>
   <option value="library-marginalia">marginalia only</option>
</select>
};

declare function search:searchJS($node as node(), $model as map(*)) {

};

(: This function is called in templates/library/library-page.html, it fetches the bdmp.css file 
   but only in the search view, because it conflicts too much with other stuff in the library module :)
declare function search:librarySearchCss($node as node(), $model as map(*)){
if (request:get-parameter("view","") eq "search") then
<link type="TEXT/CSS" href="$resources/css/search.css" rel="STYLESHEET"/>
else ()
};