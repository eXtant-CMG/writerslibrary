xquery version "3.1";

module namespace library-functions="http://exist-db.org/apps/writerslibrary/library-functions";

import module namespace config="http://exist-db.org/apps/writerslibrary/config" at "config.xqm";
import module namespace templates="http://exist-db.org/xquery/html-templating" ;

declare option exist:serialize "method=html5 media-type=text/html";

(: 
 : This module contains functions that are used by library-book-view.xql, library-browse.xql and
 : search.xql. All three of these views need a function that constructs the bibliography, for instance.
 : That's the most important function in here: library-functions:getBibliography. But there's other small
 : things in here too.
 :)



(: 
   This function creates the bibliographic details as found in the browse view (library-browse.xql)
   and the book view (library-book.xql), based on stuff encoded in <module type="bibl">.
   In the browse view it also gets a parameter $highlight, to create the highlighting in bold of the
   current sorting category.
:)
declare function library-functions:getBibliography($biblModule as node(), $highlight as xs:string?) {

(: $biblModule: this function gets passed the node <module type="bibl">...</module>.
 :
 : $highlight: in the browse views the current sorting choice (author, title, date, place,...) 
 : is highlighted in bold. This is done through the $highlight param. Eg: the url "/library/Title/O"
 : passes along a value "Title" of the $highlight param.
 :
 : There is a slight difference in css between browse view and book view. 
 : In the controller, all "book view" pages get a "view" parameter with the value "book". 
 : All browse pages don't have a view param, so there the value of the view param is nothing. 
 :)
let $view := request:get-parameter("view","")

(: Author(s)
 : *********
 : 
 : The convention for authors is a bit complicated (and tiresome);
 : One author: Proust, Marcel:
 : Two authors: Proust, Marcel and Harold Pinter:
 : Three authors: Proust, Marcel, Harold Pinter and John Doe:
 : Four authors: Proust, Marcel, Harold Pinter, Jane Doe and John Doe:
 :)
let $nrOfAuthors := count($biblModule/author)
let $AuthorLine := 
    if (normalize-space($biblModule/author[1]) ne "") then
        <span class="library-{$view}author{if ($highlight eq "Author") then 'current' else ()}">
            {if ($biblModule/author[1]/lastname and $biblModule/author[1]/lastname ne "") then $biblModule/author[1]/lastname/node() else ()} 
            {if ($biblModule/author[1]/firstname and $biblModule/author[1]/firstname ne "") then <span>,  {$biblModule/author[1]/firstname/node()}</span> else ()}
            {if ($nrOfAuthors gt 1) then 
               (
                if ($nrOfAuthors eq 4) then 
                   <span>, {$biblModule/author[4]/firstname/node()}{xs:string(" ")}{$biblModule/author[4]/lastname/node()}, {$biblModule/author[3]/firstname/node()} {$biblModule/author[3]/lastname/node()}</span> else (),
                if ($nrOfAuthors eq 3) then 
                   <span>, {$biblModule/author[3]/firstname/node()}{xs:string(" ")}{$biblModule/author[3]/lastname/node()}</span> else (),
                <span> and {$biblModule/author[2]/firstname/node()}{xs:string(" ")}{$biblModule/author[2]/lastname/node()}</span>
                )
             else ()}
             {": "}
            </span>

(: Another scenario: there is no Author but there is an editor: put the editor + " (ed.)" in the author spot :)        
    else if ($biblModule/editor[1] ne '' and $biblModule/type/text() ne 'dictionary' and $biblModule/type/text() ne 'bible') then
         <span class="library-{$view}author{if ($highlight eq "Author") then 'current' else ()}">{$biblModule/editor[1]/node()} (ed.): </span>

(: Another scenario: it's a dictionary (<Type>dictionary</Type>): put "Dictionary: " in front of the title :)
    else if ($biblModule/type/text() eq "dictionary") then
        <span class="library-{$view}author{if ($highlight eq "Author") then 'current' else ()}">Dictionary: </span>
    else ()

(: Title 
 : *****
 : By inserting the "view" param into the span class, you get these two options:
 : - library-booktitle in the book view
 : - library-title in the browse view
 : If the $highlight param value is "Title", then "current" also gets added to it: library-titlecurrent
 :)
let $TitleLine := 
        <span class="library-{$view}title{if ($highlight eq "Title") then 'current' else ()}">
            {$biblModule/title/node()}
            {if ($biblModule/subtitle and $biblModule/subtitle ne "") then <span>: {$biblModule/subtitle}</span> else ()}
            {if ($biblModule/volume ne "") then <span>, Vol. {$biblModule/volume}</span> else ()}
        <br/></span>

(: Place & Publisher
 : *****************
 : The different scenarios are:
 : - one place, one publisher (London: Jonathan Cape)
 : - several places, one publisher (London / New York / Toronto: Oxford University Press)
 : - two pairs of place/publisher (London: J.M. Dent; New York: E.P. Dutton)
 :)
let $nrOfPlaces := count($biblModule/place)
let $PlaceAndPublisherLine :=
    if (count($biblModule/publisher) le 1) then
        <span>
          <span class="library-place{if ($highlight eq "Place") then 'current' else ()}">
            {for $p at $pos in $biblModule/place
             return
                if ($pos gt 1) then <span> / {$p/node()}</span> else $p/node()
               }
            {if (normalize-space($biblModule/place[1]) ne "") then ": " else ()}
          </span>
          <span class="library-publisher">{$biblModule/publisher/node()}{if ($biblModule/publisher ne "") then ", " else ()}            </span>
        </span>
    else  if (count($biblModule/publisher) gt 1 and count($biblModule/place) gt 1) then
        <span>
            {let $nrOfPublishers := count($biblModule/publisher)
             for $pl at $pos in $biblModule/publisher
             return
                (<span class="library-place{if ($highlight eq "Place") then 'current' else ()}">{$biblModule/place[$pos]}: </span>,<span class="library-publisher">{$pl}</span>, <span>{if ($pos lt $nrOfPublishers) then '; ' else ', '}</span>)
               
            }
        </span>
    else ()
    
(: Date
 : ****
 : special cases:
 : <date FE="yes">1884</date> = [1884]
 : <date>1986</date> <firstedition>1920</firstedition> = 1986 [1920]
 :)
let $DateLine := 
        <span class="library-date{if ($highlight eq "Date") then 'current' else ()}">
            {if ($biblModule/date[data(@FE)='yes']) then "[" else ()}{$biblModule/date/node()}{if ($biblModule/date[data(@FE)='yes']) then "]" else ()}{if ($biblModule/firstedition) then <span> [{$biblModule/firstedition/node()}]</span> else ()}
        </span>
        
(: Series :)
let $SeriesLine := if ($biblModule/series ne "") then ($biblModule/series,<br/>) else ()

(: Edition :)
let $EditionLine := if ($biblModule/edition ne "") then ($biblModule/edition,<br/>) else ()

(: Editor
 : ******
 : multiple editors possible, optionally with their role specified in a @type 
 :)
let $EditorLine := if ($biblModule/editor and $biblModule/editor[1] ne "") 
            then
                for $Editor in $biblModule/editor
                return
                    ($Editor/node(),' (',<span>{if ($Editor/@type) then $Editor/data(@type) else "ed."}</span>,')',<br/>)
            else ()

(: Location :)
let $LocationLine := if ($biblModule/location ne "") then (<span class="field-title">Location</span>,": ",$biblModule/location/node(),<br/>) else ()

(: Now return everything :)
return

    (
$AuthorLine, $TitleLine, $PlaceAndPublisherLine, $DateLine, <br/>, $EditionLine, $EditorLine, $SeriesLine, $LocationLine
    )


};

(: This function gets the information from the (optional) second module <module type="prop"></module> Proprietary History.
 : Again with the $highlight value to put inscriptions into bold if they are the active sorting thing in the browse view. 
 :)
declare function library-functions:getProprietaryHistory($propModule as node(), $highlight as xs:string?) {
    let $months := map {
        "01": "January", "02": "February", "03": "March", "04": "April",
        "05": "May", "06": "June", "07": "July", "08": "August",
        "09": "September", "10": "October", "11": "November", "12": "December"
    }
    return
        for $element in $propModule/*[name() != 'type']
        where fn:normalize-space($element) != ''
        return
            <span class="library-element {if ($highlight eq $element/name()) then 'current' else ()}">
                <span class="field-title">
                    {if (fn:name($element) eq 'dateofacquisition') then
                        "Date of acquisition"
                    else
                        fn:concat(fn:upper-case(fn:substring(fn:name($element), 1, 1)), fn:substring(fn:name($element), 2))}
                </span>:
                {if (fn:name($element) eq 'dateofacquisition') then
                    let $date := fn:tokenize($element, '-')
                    return
                        if (fn:count($date) eq 3) then
                            fn:concat($date[3], ' ', $months($date[2]), ' ', $date[1])
                        else if (fn:count($date) eq 2) then
                            fn:concat('MM ', $months($date[2]), ' ', $date[1])
                        else if (fn:count($date) eq 1) then
                            fn:concat('YYYY ', $date[1])
                        else
                            'Invalid date format'
                else
                    $element}<br/>
            </span>
};

(: This function gets the information from the (optional) third module <module type="reading"></module> Reading History.
 :)
declare function library-functions:getReadingHistory($readingModule as node(), $highlight as xs:string?) {
    let $months := map {
        "1": "January", "2": "February", "3": "March", "4": "April",
        "5": "May", "6": "June", "7": "July", "8": "August",
        "9": "September", "10": "October", "11": "November", "12": "December"
    }
    let $status := $readingModule/status
    let $readingDates := $readingModule/readingdate
    return

            <span class="readingHistory"><span class="readingHistoryHeader">Reading history</span>

            {
                for $readingDate in $readingDates
                let $from := $readingDate/from
                let $to := $readingDate/to
                let $source := $readingDate/source
                return
                    <span>
                        <span class="reading-period {if ($highlight eq 'readingdate') then 'highlight' else ()}">
                            {if ($from = $to) then
                                (: If <from> and <to> are identical, display only <from> :)
                                <span>
                                    {if ($from/@type = "exact") then
                                        fn:concat($from/day, " ", $months($from/month), " ", $from/year)
                                    else if ($from/@type = "season") then
                                        fn:concat($from/season, " ", $from/year)
                                    else if ($from/@type = "year") then
                                        $from/year
                                    else
                                        "Invalid date format"}
                                </span>
                            else
                                (: If <from> and <to> are different, display both :)
                                <span>
                                    {if ($from/@type = "exact") then
                                        fn:concat($from/day, " ", $months($from/month), " ", $from/year)
                                    else if ($from/@type = "season") then
                                        fn:concat($from/season, " ", $from/year)
                                    else if ($from/@type = "year") then
                                        $from/year
                                    else
                                        "Invalid date format"} —  
                                    {if ($to/@type = "exact") then
                                        fn:concat($to/day, " ", $months($to/month), " ", $to/year)
                                    else if ($to/@type = "season") then
                                        fn:concat($to/season, " ", $to/year)
                                    else if ($to/@type = "year") then
                                        $to/year
                                    else
                                        "Invalid date format"}
                                </span>
                            }
                        </span><br/>
                        <span><span class="field-title">Source</span>: <span class="{if ($highlight eq 'source') then 'highlight' else ()}">{$source}</span></span><br/><br/>
                    </span>
            }
            </span>
};





(: This function gets the list of pages with reading traces for the browse view.
 : For this the reading traces module (<module type="pages"></module>) node gets passed 
 : into the function. 
 :)
declare function library-functions:getReadingTracesList($rtModule as node(), $highlight as xs:string?) {
<span>
    <span class="library-readingtraces{if ($highlight eq "readingTraces") then 'current' else ()}"><span class="field-title">Reading traces on</span>: </span>
    <span class="library-rt-pagenumbers">
       {let $nrOfPages := count($rtModule/page[zone])
        for $page at $pos in $rtModule/page[zone]
        let $pageNumber := $page/pagenumber/text()[1]
        let $marginalia := if ($page//m) then "*" else ()
        let $fullpageNumber := $pageNumber || $marginalia
        let $comma := if ($pos lt $nrOfPages) then ', ' else '.'
        return
            concat($fullpageNumber,$comma)
       }{if ($rtModule//m) then <span> (*: page contains marginalia)</span> else ()}</span>
<br/></span>
};

(: This function returns the value of the <GeneralNote> tag in the biblio module :)
declare function library-functions:getGeneralNotes($GeneralNote as node()) {
<span><span class="field-title">Notes</span>: {$GeneralNote} <br/></span>
};


(: This function has to do with the Manuscript Links from the library to the BDMP genetic modules :)
declare function library-functions:ManuscriptLinkBookLevel($ManuscriptLinksBookLevel as node()) {
let $viewParam := request:get-parameter("view","")
return
    <span class="DU"><span class="ManuscriptLink"></span> 
    {if ($viewParam ne "book") then
         $ManuscriptLinksBookLevel
    else
      let $output := for $child in $ManuscriptLinksBookLevel/node() return if (name($child) eq "ref") then <a style="color:#999967;" href="../{substring-before($child/@target,':')}/{substring-before(substring-after($child/@target,':'),',')}/{if ($child/@type eq "pagelink") then concat(substring-before(substring-after($child/@target,','),'['),"?view=imagetext#Ann_",substring-before(substring-after($child/@target,'['),']')) else if ($child/@type eq "sentencelink") then substring-after($child/@target,',') else ()}">{$child}</a> else $child
      return
         $output
     }
     </span>
};


(: This function has to do with the Manuscript Links from the library to the BDMP genetic modules :)
declare function library-functions:ManuscriptLinksZoneLevel($rtModule as node(), $bookID as xs:string?) {
<span class="DU"><span class="ManuscriptLink"></span> on page(s): 
 {let $nrOfMsLinks := count($rtModule/page/zone/rn/manuscriptLink)
  for $MsLink at $pos in $rtModule/page/zone/rn/manuscriptLink
  let $pageNr := $MsLink/ancestor::page/pagenumber/text()
  let $zoneNr := $MsLink/ancestor::zone/number/text()
  let $output := concat($pageNr,' [zone ',$zoneNr,']')
  let $outputWithLink := <a href="{$bookID}.html?page={$pageNr}&amp;zone={$zoneNr}" style="color:#999967;">{$output}</a>
  let $finalOutput := if ($bookID eq "nolink") then $output else if (request:get-parameter("view","") ne "book") then $output else $outputWithLink

  return
    ($finalOutput, if ($pos lt $nrOfMsLinks) then ', ' else '')
   }
</span>
};

(: This function retrieves the Library Name as specified in the <name> element in config.xml
 : and inserts it in the module header.
 :)
declare function library-functions:getLibraryName($node as node(), $model as map(*)) {

let $configDoc :=doc($config:data-root || '/library/config.xml')
let $libraryName := $configDoc//title/text()


return
    $libraryName
};

(: This function retrieves the Library subtitle as specified in the <subtitle> element in config.xml
 : and inserts it in the module header.
 :)
declare function library-functions:getSubtitle($node as node(), $model as map(*)) {

let $configDoc :=doc($config:data-root || '/library/config.xml')
let $librarySubtitle := if ($configDoc//subtitle/text() ne '') then <span class="modulesubtitle">{$configDoc//subtitle/text()}</span> else ""

return
    $librarySubtitle
};



(: This function is called in the search engine (search.xql) 
 : When there is a search hit from the reading traces module,
 : this function creates the html output of the search result.
 : search.xql passes a number of things into this function:
 : - $zone: the <zone> node that contains the search hit
 : - $bookID: the id of the current book
 : - the pagenumber, author, title and subtitle, used for the line at the top of the result.
 :)
declare function library-functions:readingTracesSearch($zone as node(), $bookID as xs:string, $pagenumber as xs:string, $author as xs:string, $title as xs:string, $subtitle as xs:string?) {

(: look in the config file for the server path to the images :)
let $configDoc :=doc($config:data-root || '/library/config.xml')
let $imgUrl := $configDoc//imgUrl/serverPath/text()
(: to process all of the tags that can occur inside of the "Extracts" element, 
 : as well as replace all occurrences of "/" by <br/>, I send the Extracts node to be processed
 : by the xslt stylesheet library-search-results-readingtraces.xsl :)
let $xsl := doc($config:app-root || "/resources/xslt/library-search-results-readingtraces.xsl")

return
    <div><a style="text-decoration:none;" href="../../library/{$bookID}.html?page={$pagenumber}&amp;zone={$zone/number/text()}">{if ($author ne " " and $author ne "") then concat($author,": ") else ()}<i>{$title}{if ($subtitle ne "") then <span>: {$subtitle}</span> else ()}</i>, p. {$pagenumber}<br/>
      <table class="libraryrt">
        <tr>
            <td valign="top"><img src="{if (starts-with($zone/facsimile/text(),'https')) then "" else $imgUrl}{$zone/facsimile/text()}"/></td>
            <td valign="top">
                <span class="rthead">Zone {$zone/number/text()}</span>
                <span class="rtcontent">
                    <b>Reading Trace:</b><br/> {util:expand($zone/rn/transcription)}<br/><br/>
                    <b>Marked Passage:</b><br/> {transform:transform($zone/rn/extracts,$xsl,<parameters></parameters>)}
                </span>
            </td>
        </tr>
      </table>
      </a>
    </div>
};

(: Since there is a directory difference between paths to book view (library/PRO-ALA-1.html) and
 : browse view (library/Author/A), some of the links in the navigation bar need to be changed depending
 : on the current view. Here: the BDMP home link. :)
declare function library-functions:makeBDMPHomeLink($node as node(), $model as map(*)) {
let $view := request:get-parameter("view","")
return
    <a href="{if ($view ne "book") then "../" else()}../home" style="margin-left:20px;display:inline-block;" class="SBDMP changeviz">{templates:process($node/node(), $model)}</a>
};

(: Since there is a directory difference between paths to book view (library/PRO-ALA-1.html) and
 : browse view (library/Author/A), some of the links in the navigation bar need to be changed depending
 : on the current view. Here: the library home link. :)
declare function library-functions:makeLibraryHomeLink($node as node(), $model as map(*)) {
let $view := request:get-parameter("view","")
return
    <a href="{if ($view ne "book") then "../" else()}home/welcome" style="text-decoration:none;color:#999967;">{templates:process($node/node(), $model)}</a>
};

(: Since there is a directory difference between paths to book view (library/PRO-ALA-1.html) and
 : browse view (library/Author/A), some of the links in the navigation bar need to be changed depending
 : on the current view. Here: the logout button link. :)
declare function library-functions:logoutButton($node as node(), $model as map(*)) {
    <a href="{if (request:get-parameter("view","") ne "book") then "../" else ()}../home?logout=true" title="Log out">
        <span class="glyphicon glyphicon-log-out" aria-hiddden="true"/>
    </a>
};

(: Small difference in the nav between browse view and book view: the word "Manual" next to the icon in browse and search view :)
declare function library-functions:manualnav($node as node(), $model as map(*)) {
if (request:get-parameter("view","") ne "book") then <span class="manualnav">User Manual</span> else ()
};






