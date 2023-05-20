xquery version "3.1";

module namespace library-browse="http://exist-db.org/apps/writerslibrary/library-browse";

import module namespace config="http://exist-db.org/apps/writerslibrary/config" at "config.xqm";
import module namespace library-functions="http://exist-db.org/apps/writerslibrary/library-functions" at "library-functions.xql";

declare option exist:serialize "method=html5 media-type=text/html";

(: 
 : This module makes the "browse view", the functionality of applying sorting categories (Author, Title, Date,...) 
 : and then browsing by alphabet, or by date range, or whatever you think is relevant and that can be retrieved
 : from a range index.
 : The sorting categories, and instructions on how they can be browsed is retrieved from data/library/config.xml.
 : The two main functions in this module are library-browse:navbar which creates the navbar, and library-browse:getEntries, 
 : which gets all of the entries from library.xml that comply to the selection as specified in the url.
 :)


(: This function, library-browse:navbar, creates the sort/browse/search nav bar.
 : For every <sortBy> element in config.xml it will create an item in the nav bar. 
 : eg: <sortBy id="Author" browseCategory="Alphabet">
 : Here the browse category is specified as Alphabet, which leads to the element
 : <browseBy id="Alphabet">, which contains an item for every letter of the alphabet.
 : These items are then used to populate the "Browse" line in the sort/browse nav bar.
 :)

declare function library-browse:navbar($node as node(), $model as map(*)){

    let $configDoc := doc($config:data-root || '/library/config.xml')
    let $libraryDoc := doc($config:data-root || '/library/library.xml')

    (: The current sorting & browsing specifications are retrieved through the param 
       "sortAndBrowse" which is created in the controller. It contains both the sort value
       (before the "/") and the browse value (after the "/"). :)
    let $sortAndBrowseParam := request:get-parameter("sortAndBrowse","Author/Z")
    let $currentSortValue := substring-before($sortAndBrowseParam,'/')
    let $currentBrowseValue := substring-after($sortAndBrowseParam,'/')
    let $currentBrowseCategory := $configDoc//sortBy[data(@id) eq $currentSortValue]/data(@browseCategory)
    
    return
        <div><!-- SORT -->
            <p class="sort">Sort by: 
              {for $sortBy at $pos in $configDoc//sorting/sortBy[not(@type eq "hidden")] 
               let $countSorting := count($configDoc//sorting/sortBy[not(@type eq "hidden")])
               let $sortByLabel := $sortBy/label/text()
               let $sortByID := $sortBy/data(@id)
               let $sortByBrowseCategory := $sortBy/data(@browseCategory)
               let $browseValueLink := if ($sortByBrowseCategory ne $currentBrowseCategory) then $configDoc//browseBy[data(@id) eq $sortByBrowseCategory]/browse[1]/value/text() else $currentBrowseValue
               return 
                    if ($sortByID eq $currentSortValue) then
                        <span><span class="current">{$sortByLabel}</span> <span>{if ($pos lt $countSorting) then " - " else ()}</span></span>
                    else
                        <span><a href="../{$sortByID}/{$browseValueLink}">{$sortByLabel}</a> <span>{if ($pos lt $countSorting) then " - " else ()}</span></span>
               }
            </p>
            <!--<div class="spacer"></div>-->
            <!-- BROWSE -->
            {if ($currentBrowseCategory ne "nothing") then 
            <table cellpadding="0" cellspacing="0" class="browse">
                <tr>       
                    <th valign="top"><span style="display:inline-block;margin-top:7px;">Browse:</span></th>
                    {for $browseBy at $pos in $configDoc//browseBy[data(@id) eq $currentBrowseCategory]/browse 
                    let $browseValue := $browseBy/value/text()
                    let $currentSortByRangeQuery := $configDoc//sortBy[data(@id) eq $currentSortValue]/rangeQuery
                    let $queryexpression := concat($currentSortByRangeQuery/fields/text(),",",$currentSortByRangeQuery/operators/text(),",",$currentSortByRangeQuery/keys/text())
                    let $context := <static-context> <variable name="currentBrowseValue">{$browseValue}</variable> <variable name="libraryDoc">{$libraryDoc}</variable> </static-context>
                    let $query := util:eval-with-context(concat('$libraryDoc/range:field(',$queryexpression,')'),$context,false())
                    let $hits := count($query)
                    return 
                        <td>{
                         if ($browseBy/value/text() eq $currentBrowseValue) then
                            <span>
                                <span class="current">{$browseBy/label/text()}</span> <br/>
                                <span class="hits">({$hits})</span>
                            </span>
                         else
                           <span>
                             <a href="../{$currentSortValue}/{$browseBy/value/text()}">{$browseBy/label/text()}</a> <br/>
                             <span class="hits">({$hits})</span>
                           </span>
                        }</td>}
                </tr>
            </table>
            else ()
            }
            <!-- SEARCH -->
            {if (request:get-parameter("view","") ne "search") then
            <div id="searchdiv">
                     <span class="searchword">Search:</span>
                     <form style="display:inline" name="searchform" id="searchform" action="../search/index.html">
                        <input type="text" name="q" id="searchterm" placeholder="your query" value=""/> in 
                            <input type="hidden" name="index" value="library"/> 
                             <select name="doc" id="doc" style="width:140px;">
                               <option value="">everything</option>
                               <option value="library-bibliography">bibliography</option>
                               <option value="library-readingtraces">all reading traces</option>
                               <option value="library-marginalia">marginalia only</option>
                               
                            </select>
                        <input type="submit" value="Search!" id="submit"/>
                    
                      <a href="javascript:void(0);" class="info-link">
                        <span class="search-info">
                           <b>Search tips</b>
                            <br/>
                            <br/> * search for "<b>Location</b>" in Bibliography to find all books in archives and private collections<br/>* search for "<b>marginalia</b>" in Reading Traces to find all books with marginalia<br/>* search for "<b>private</b>" in Bibliography to find all books currently held in private collections</span>
                        <span class="glyphicon glyphicon-info-sign"></span>
                     </a></form> 
                  </div>
                  
               else ()}
            </div>

};

(: This function gets all of the entries from library.xml (via range indexes) 
 : that comply to the selection as specified in the url.
 : The actual query is defined in the <sortBy> element in config.xml, for example
 :       <rangeQuery>
 :              <fields>("library-book-Title","library-book-type")</fields>
 :              <operators>("starts-with","eq")</operators>
 :              <keys>$currentBrowseValue, "EL"</keys>
 :      </rangeQuery>
 : which means the "library-book-Title" field starts with the current browse value,
 : and the "library-book-type" (EL or VL) should equal EL, which means only retrieve 
 : books from the extant library (and not the virtual library).
 : This query is loaded from the config file into this function and evaluated. The relevant <book>
 : nodes are retrieved and processed further to make the HTML output.
 :)
declare function library-browse:getEntries($node as node(), $model as map(*)){

    let $sortAndBrowseParam := request:get-parameter("sortAndBrowse","Author/A")
    let $currentBrowseValue := substring-after($sortAndBrowseParam,'/')
    let $currentSortValue := substring-before($sortAndBrowseParam,'/')

    let $libraryDoc := doc($config:data-root || '/library/library.xml')
    let $configDoc :=doc($config:data-root || '/library/config.xml')

    (: in the following two parameters the actual range query is constructed. :)
    let $currentSortByRangeQuery := $configDoc//sortBy[data(@id) eq $currentSortValue]/rangeQuery
    let $queryexpression := concat($currentSortByRangeQuery/fields/text(),",",$currentSortByRangeQuery/operators/text(),",",$currentSortByRangeQuery/keys/text())
        
    let $orderBy := $configDoc//sortBy[data(@id) eq $currentSortValue]/orderBy/text()
    let $libraryName := $configDoc//title/text()
    let $breadcrumbSortedByPhrase := $configDoc//sortBy[data(@id) eq $currentSortValue]/breadcrumbPhrase/text()
    
    (: The current thumbnail path and filename for the books are also retrieved from the config file,
       the relevant paths can be declared in the <imgUrl> element. :)
    let $imgUrl := $configDoc//imgUrl
    let $pathToThumbnail := concat('$result/',$imgUrl/pathToList/text(),'/',$imgUrl/pathToItem/text(),'[1]/facsimile/text()')

    (: The following two parameters set up the actual query. The current browse value is carried
       into the util:eval-with-context function through the context variable. :)
    let $context := <static-context> <variable name="currentBrowseValue">{$currentBrowseValue}</variable> <variable name="libraryDoc">{$libraryDoc}</variable> </static-context>
    let $query := util:eval-with-context(concat('$libraryDoc/range:field(',$queryexpression,')'),$context,false())
    
    let $countResults := count($query)
    let $booksTotal := count($libraryDoc//book)
    
    return
      <div>
        <div id="body">
         <!-- BREADCRUMBS -->
          <p class="breadcrumbs">
            {$libraryName} ({$booksTotal} items) > sorted by {$breadcrumbSortedByPhrase} {if (not($configDoc//browse[value/text() eq $currentBrowseValue])) then () else <span> &gt; "{$configDoc//browse[value/text() eq $currentBrowseValue]/label/text()}"</span>} ({$countResults} items)
          </p>        
          <span>{if (count($query) eq 0) then 
                     <span class="nohits"><span class="lead-in">There are currently <b>no</b> books in the <i>{$libraryName}</i> that match this selection: <span class="selection"> {lower-case($orderBy)}</span> starting with "<span class="selection">{$configDoc//browse[value/text() eq $currentBrowseValue]/label/text()}</span>", sorted by <span class="selection">{$breadcrumbSortedByPhrase}</span>.</span> </span> 
                 else ()}</span>
          
          {(: Here starts the for loop to process each book in the current list. :)
           for $result in $query
           (: 
            : If you want to use this and your data does not use <Author sort=""> and <Title sort="">, 
            : you should change the path to the correct node here in $AuthorSortLink and $TitleSortLink
            :)
           let $sortString := 
                if ($result/module[@type='bibl']/*[name() eq $orderBy][1]/data(@sort)) then $result/module[@type='bibl']/*[name() eq $orderBy][1]/data(@sort)
                else $result/module[@type='bibl']/*[name() eq $orderBy][1]/text()
           let $secondarySort := $result/module[@type='bibl']/author[1]/data(@sort)
           let $bookID := $result/data(@id)
           let $imgUrlContext := <static-context><variable name="result">{$result}</variable></static-context>
           order by $sortString, $secondarySort
           
           return
                <div class="entryEL">
                 <table width="100%">
                  <tr>
                   <td width="90px" valign="top">
                    <a name="{$bookID}"/>
                     { if (util:eval-with-context($pathToThumbnail,$imgUrlContext,false()) ne "") then
                      <a class="booklinks" href="../{$bookID}.html">
                        <div class="imagecontainer">
                          <img class="thumb" src="{if (starts-with(util:eval-with-context($pathToThumbnail,$imgUrlContext,false()),'https')) then '' else $imgUrl/serverPath/text()}{util:eval-with-context($pathToThumbnail,$imgUrlContext,false())}"/>
                          {if ($result/data(@type) eq "VL") then <span class="virtualthumb">V<br/>I<br/>R<br/>T<br/>U<br/>A<br/>L</span> else ()}
                        </div>
                        </a>
                      else 
                        <a class="booklinks" href="../{$bookID}.html"><!--<a class="booknolink">--><div class="imagecontainer"><span class="noscan"/>{if ($result/data(@type) eq "VL") then <span class="virtualthumb">V<br/>I<br/>R<br/>T<br/>U<br/>A<br/>L</span> else ()}</div></a>
                      }
                   </td>
                   <td valign="top">
                   <span class="biblio">
                     <a class="booklinks" href="../{$bookID}.html">
                       { (: 1: call to getBibliography to get the main bibliographic lines :)
                        library-functions:getBibliography($result/module[@type eq "bibl"], $currentSortValue)
                       }
                       { (: 2: check if there is one, then call to getInscriptions to get the inscription(s) :)
                        if ($result/module/dedication[1] and $result/module/dedication[1] ne "") then library-functions:getInscriptions($result/module[@type eq "prop"], $currentSortValue)  else()
                       }
                       { (: 3: check if there are reading traces, then send to function getReadingTracesList :)
                        if ($result/module/page/zone[1]) then library-functions:getReadingTracesList($result/module[@type eq "pages"], $currentSortValue)  else()
                       }
                       { (: 4: get GeneralNotes :)
                        if ($result/module/generalnote and $result/module/generalnote ne "") then library-functions:getGeneralNotes($result/module/generalnote) else ()
                       }
                       { (: 5: get ManuscriptLinks :)
                        (: first up: ManuscriptLinks on book level :)
                        if ($result/module/manuscriptlink) then 
                            library-functions:ManuscriptLinkBookLevel($result/module/manuscriptlink)
                        (: second: ManuscriptLinks on zone level :)
                        else if ($result/module/page/zone/rn/manuscriptlink) then
                            library-functions:ManuscriptLinksZoneLevel($result/module[@type='pages'], "nolink")
                        else ()
                       }
                       
                       
                     </a>
                     </span>
                   </td>
                  </tr>
                 </table>
                </div> }
  
           </div> 
        {if ($currentBrowseValue eq "") then () else <a class="nextpage" href="{$configDoc//browse[preceding-sibling::browse[1][value/text() eq $currentBrowseValue]]/value/text()}">Continue to next page</a>}
        </div>
    
};



