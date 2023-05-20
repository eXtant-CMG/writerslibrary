xquery version "3.1";

module namespace library-book-view="http://exist-db.org/apps/writerslibrary/library-book-view";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://exist-db.org/apps/writerslibrary/config" at "config.xqm";
import module namespace library-functions="http://exist-db.org/apps/writerslibrary/library-functions" at "library-functions.xql";
import module namespace admin-tools="http://exist-db.org/apps/writerslibrary/admin-tools" at "admin-tools.xql";

declare option exist:serialize "method=html5 media-type=text/html";

(: 
 : This module makes the "book view". See also templates/library/bookview.html
 : and templates/library/bookview-script.html.
 : The book view has the bibliographic information again, but also, if there are images,
 : an image viewer and navigation window. The images are switched around via jquery.
 : If a book has READING TRACES, this is also where these can be navigated.
 : 
 :)

(: This function gets the current book node by querying the range field "library-book-ID" with
   the book ID. This function is used by a number of functions on this page to quickly grab things 
   from the book node. :)
declare function library-book-view:getBookNode($bookID as xs:string) {
let $libraryDoc := doc($config:data-root || '/library/library.xml')
let $bookNode := $libraryDoc/range:field-eq("library-book-ID",$bookID)
return
    $bookNode
};

(: This function constructs the bibliographic section, mainly by calling 
   library-functions:getBibliography() for all the stuff that is needed in the book view. :)
declare function library-book-view:getBiblio($node as node(), $model as map(*), $book as node()?) {

let $bookID := request:get-parameter("bookID","")
let $bookNode := if ($book) then $book else library-book-view:getBookNode($bookID)

return 
       <span>
                      { (: 1: call to getBibliography to get the main bibliographic lines :)
                        library-functions:getBibliography($bookNode/module[@type eq "bibl"], "")
                       }
                       { (: 2: check if there is one, then call to getInscriptions to get the inscription(s) :)
                        if ($bookNode/module/dedication[1] and $bookNode/module/dedication[1] ne "") then library-functions:getInscriptions($bookNode/module[@type eq "prop"],"")  else()
                       }
                       { (: 3: get GeneralNotes :)
                        if ($bookNode/module/generalnote and $bookNode/module/generalnote ne "") then library-functions:getGeneralNotes($bookNode/module/generalnote) else ()
                       }
                       { (: 4: get IIIF manifest link :)
                        if ($bookNode/module/IIIF and $bookNode/module/IIIF/IIIFmanifest ne "") then (<a href="{$bookNode/module/IIIF/IIIFviewer/text()}?manifest={$bookNode/module/IIIF/IIIFmanifest/node()}" target="_blank"><img src="$resources/images/logo-iiif-34x30.png" title="{if ($bookNode/module/IIIF/IIIFviewer/text() ne "") then "Click or " else ""}Drag and Drop"/></a>,<br/>) else ()
                       }
          </span>
};

(: This function constructs the image viewer, puts the first image into it, 
   and also creates the initial PREV and NEXT links. 
   It constructs the correct path to the images based on the information
   declared in config.xml of where the images are: <imgUrl> 
   <serverPath>$bdmp-images/library/</serverPath>: in the case of the BDMP
   all paths to images from the library start with "$bdmp-images/library/".
   Then you can specify how the images are declared inside library.xml.
   In the case of the BDMP this is:
       <book>
         <images>
           <image n="0">CHE-TCH,cover</image>
           <image n="1">CHE-TCH,tp</image>
           ...
         </images>
        </book>
   This path is made explicit in <imgUrl> in this way:
        <pathToList type="element">images</pathToList>
        <pathToItem type="element">image</pathToItem>
   This function puts this all together and then evaluates the result to create the
   proper paths. I (VN) hope this allows for lots of different scenarios of serving
   images in different circumstances.
    :)
declare function library-book-view:getImage($node as node(), $model as map(*)) {

let $bookID := request:get-parameter("bookID","")
let $bookNode := library-book-view:getBookNode($bookID)

let $configDoc :=doc($config:data-root || '/library/config.xml')
let $imgUrl := $configDoc//imgUrl
let $imgUrlContext := <static-context><variable name="bookNode">{$bookNode}</variable></static-context>
let $pathToFirstImage :=  concat('$bookNode/',$imgUrl/pathToList/text(),'/',$imgUrl/pathToItem/text(),'[1]/facsimile')
let $pathToSecondImage := concat('$bookNode/',$imgUrl/pathToList/text(),'/',$imgUrl/pathToItem/text(),'[2]/facsimile')
let $pathToSecondImageEvaluated := if (util:eval-with-context($pathToSecondImage,$imgUrlContext,false()) ne "") then util:eval-with-context($pathToSecondImage,$imgUrlContext,false()) else util:eval-with-context($pathToFirstImage,$imgUrlContext,false())

let $imageLink := if (starts-with(util:eval-with-context($pathToFirstImage,$imgUrlContext,false()),"https")) then util:eval-with-context($pathToFirstImage,$imgUrlContext,false()) else concat($imgUrl/serverPath/text(),util:eval-with-context($pathToFirstImage,$imgUrlContext,false()))
let $image2Link := if (starts-with(util:eval-with-context($pathToSecondImage,$imgUrlContext,false()),"https")) then util:eval-with-context($pathToSecondImage,$imgUrlContext,false()) else concat($imgUrl/serverPath/text(),$pathToSecondImageEvaluated)


return 
if (util:eval-with-context($pathToFirstImage,$imgUrlContext,false()) ne "") then
    <div>
      <div id="imagecontainer">
        <img id="fac" width="680" style="float:left;" src="{$imageLink}"/>
      </div><!-- /imagecontainer -->
      <p id="factext">
        <a id="prev" class="faclink" href="{$imageLink}" data-image="{concat($bookID,',')}{util:eval-with-context($pathToFirstImage,$imgUrlContext,false())/../pagenumber/text()}">&lt; PREV</a>
        <span id="currentfac">{util:eval-with-context($pathToFirstImage,$imgUrlContext,false())/../pagenumber/text()}</span>
        <a id="next" class="faclink" href="{$image2Link}" data-image="{concat($bookID,',')}{util:eval-with-context(concat('$bookNode/',$imgUrl/pathToList/text(),'/',$imgUrl/pathToItem/text(),'[2]/pagenumber/text()'),$imgUrlContext,false())}">NEXT &gt;</a>
      </p>
    </div>
else ()
};

(: this function produces the list in the "available scans" tab in the book view. 
   Like the previous function, it constructs this list by putting together the 
   paths from the variables declared in config.xml and the facs lists in 
   the book nodes in library.xml :)
declare function library-book-view:getFacList($node as node(), $model as map(*)) {

let $bookID := request:get-parameter("bookID","")
let $bookNode := library-book-view:getBookNode($bookID)

let $configDoc :=doc($config:data-root || '/library/config.xml')
let $imgUrl := $configDoc//imgUrl
let $imgUrlContext := <static-context><variable name="bookNode">{$bookNode}</variable></static-context>
let $pathToImages := concat('$bookNode/',$imgUrl/pathToList/text(),'/',$imgUrl/pathToItem/text())
let $nrOfImages := count(util:eval-with-context($pathToImages,$imgUrlContext,false()))
return
if ($nrOfImages ne 0) then
    <span class="faclist">
        <span class="faclistHeader">Available scans <span id="FLcaret" class="FLcaret">▿</span></span>
        <span class="faclistBody">
           {
            for $image at $pos in util:eval-with-context($pathToImages,$imgUrlContext,false())
            let $comma := if ($pos lt $nrOfImages) then ', ' else '.'
            let $imageLink := <a href="{if (starts-with($image/facsimile/text(),'https')) then $image/facsimile/text() else concat($imgUrl/serverPath/text(),$image/facsimile/text())}" id="{concat($bookID,',',$image/pagenumber/text())}" data-image="{concat($bookID,',',$image/pagenumber/text())}" class="faclink">{$image/pagenumber/text()}{if ($image//m or $image//type eq "marginalia") then "*" else ()}</a>
            return
                ($imageLink,$comma)
           }
           {if (admin-tools:userIsAdmin() eq true() and $bookNode//IIIF) then <span class="admin-tools-open-in-zone-tool"><span class="admin-tools-heading">Admin Tool: </span> <a id="page-to-open-link" href="tools/zone-coordinates-tool?pageID={$bookID},{$bookNode//page[1]/pagenumber/text()}">open page <span id="page-to-open">{$bookNode//page[1]/pagenumber/text()}</span> in the <span class="admin-tools-zone-tool-name">Zone coordinates tool</span></a></span> else ()}
        </span>
    </span>
else ()
};


(: This function constructs the nav bar in the book view. It offers a back button, links to go to the
 : author browse view with the first letter of the current author's last name, to the title browse view
 : with the first letter of the current title, or to the place browse view with the first letter of the 
 : current first place.
 :)
declare function library-book-view:navbar($node as node(), $model as map(*)) {

let $bookID := request:get-parameter("bookID","")
let $bookNode := library-book-view:getBookNode($bookID)

let $AuthorSortLink := <span style="margin-right:20px;"><a href="Author/{substring($bookNode/module/author[1]/data(@sort),1,1)}">Author <span class="current">{substring($bookNode/module/author[1]/data(@sort),1,1)}</span></a> </span>
let $TitleSortLink := <span style="margin-right:20px;"><a href="Title/{substring($bookNode/module/title/data(@sort),1,1)}">Title <span class="current">{substring($bookNode/module/title/data(@sort),1,1)}</span></a> </span>
let $PlaceSortLink := <span style="margin-right:20px;"><a href="Place/{substring($bookNode/module/place[1]/text(),1,1)}">Place <span class="current">{substring($bookNode/module/place[1]/text(),1,1)}</span></a> </span>

return 
    <span>
      <span class="back"><a href="javascript:history.back()" class="back">← back</a></span><a style="margin-right:20px;" title="Home" href="home/welcome"><span aria-hiddden="true" class="glyphicon glyphicon-home"></span></a>
       {($AuthorSortLink,$TitleSortLink,$PlaceSortLink)}
    </span>
};

(: This is an important function for browsing the reading traces in a book.
   The code for the zones on every page is served via javascript (jquery).
   This is NOT done by firing AJAX requests to construct the relevant code
   when a user loads a certain page by clicking a link, but instead it is
   all created at load time for all pages through this function. That can
   make the processing time for books with lots and lots of reading traces
   a bit long (between one and two seconds). 
   This function is called a number of times from templates/library/bookview-script.html
   with an additional parameter: "component", because several components need to
   be loaded at several places in the JS script. :)
declare function library-book-view:getJS($node as node(), $model as map(*), $component as xs:string) {
if (request:get-parameter("view","") eq "book") then

    let $bookID := request:get-parameter("bookID","")
    let $bookNode := library-book-view:getBookNode($bookID)

    (: You can also go directly to a particular zone on a particular page
       via a url. For instance:
       library/ARA-LIB.html?page=24&amp;zone=1
       will cause the book view to load page 24 and bring up the pop-ups for
       zone 1 on load time. That's why these two params also need to be loaded
       here. :)
    let $pageParam := replace(request:get-parameter("page",""),"-_-", " ")
    let $zoneParam := request:get-parameter("zone","")
    
    let $configDoc :=doc($config:data-root || '/library/config.xml')
    let $imgUrl := $configDoc//imgUrl
    let $imgUrlContext := <static-context><variable name="bookNode">{$bookNode}</variable></static-context>
    let $pathToImages := concat('$bookNode/',$imgUrl/pathToList/text(),'/',$imgUrl/pathToItem/text())
    let $nrOfImages := count(util:eval-with-context($pathToImages,$imgUrlContext,false()))
    let $localOrIIIF := if (starts-with(util:eval-with-context($pathToImages,$imgUrlContext,false())/facsimile/text(),'https')) then "IIIF" else "local"
    
    let $pagenumberList := for $image in util:eval-with-context($pathToImages,$imgUrlContext,false()) return $image/pagenumber/text()
    let $facsmileList := 
        for $image in util:eval-with-context($pathToImages,$imgUrlContext,false()) 
        let $imagePath := if (starts-with($image/facsimile/text(),'https')) then $image/facsimile/text() else concat($imgUrl/serverPath/text(),$image/facsimile/text())
        return concat("'",$imagePath,"'")
    let $rtList := 
        for $i in util:eval-with-context($pathToImages,$imgUrlContext,false()) 
        return
            if ($i/zone) then "'yes'" else "'yesno'"
    
    (: In the conditionals underneath different stuff is returned to bookview-script.html
       based on the value of the "component" variable. :)
    return
        if ($component eq "tmpPagenumbers") then
           concat("'",string-join($pagenumberList,','),"'")
        else if ($component eq "tmpLinks") then
           string-join($facsmileList,',')
        (: TO BE CHANGED :)
        else if ($component eq "prevnextLinks") then
            concat("'",$imgUrl/serverPath/text(),$bookID,",'")
        else if ($component eq "bookID") then
            concat("'",$bookID,"'")
        else if ($component eq "yesno") then
            string-join($rtList,',')
        (: this is the most important part: it constructs the javascript/html
           for each zone by processing the book node through the xslt stylesheet
           /resources/xslt/library-readingtrace-js.xsl. :)
        else if ($component eq "readingtraces") then
            transform:transform($bookNode,doc($config:app-root || "/resources/xslt/library-readingtrace-js.xsl"),<parameters></parameters>)
        else if ($component eq "imgUrl") then
            if ($localOrIIIF eq "local") then concat("'",$imgUrl/serverPath/text(),"'")
            else "''"
        else if ($component eq "pageAndZoneLink" and $pageParam ne "") then           
            concat('document.getElementById("',$bookID,',',$pageParam,'").click();',' document.getElementById("',$zoneParam,'").click();')
        else ()
else ()
};

(: This function is called in templates/library/library-page.html.
   It's a dirty way of only including the jquery script for the images 
   and reading traces only in the book view and not in the browse view.
   :)
declare function library-book-view:checkView($node as node(), $model as map(*)) {
if (request:get-parameter("view","") eq "book") then
  templates:process($node/node(), $model)
else ()
};

(: This function creates the html for the dropdown menus of the search engine in the
   book view. To be able to search only in the reading traces of one particular book,
   the id of that book needs to be added to the option value "library-readingtraces-{$bookID}"
   :)
declare function library-book-view:getSearchSelect($node as node(), $model as map(*)) {
let $bookID := request:get-parameter("bookID","")
let $bookNode := library-book-view:getBookNode($bookID)
return 
<span>
     <input type="hidden" name="index" value="library"/>
     <select name="doc" id="doc" style="width:180px;">
        {if ($bookNode/module//zone) then <option value="library-readingtraces-{$bookID}">this book (reading traces)</option> else ()}
        <option value="library-readingtraces">all reading traces</option>
        <option value="library-marginalia">marginalia only</option>
        <option value="library-bibliography">bibliography</option>
        <option value="">the library</option>
    </select>
    </span>
};

(: This function checks if there are marginalia in a book (<m> tag) and if there are
   creates a link under the bibliography to do a search for the marginalia in the book. :)
declare function library-book-view:getMarginaliaLink($node as node(), $model as map(*)) {

let $bookID := request:get-parameter("bookID","")
let $bookNode := library-book-view:getBookNode($bookID)
return
    if ($bookNode//m) then
    <span>&gt; <a class="show-all-marginalia"  href="../library/search/index.html?q=marginalia&amp;index=library&amp;doc=library-readingtraces-{$bookID}">Show <b>all marginalia</b> in this book</a><br/></span>
    else ()
};
















