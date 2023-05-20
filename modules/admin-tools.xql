xquery version "3.1";

module namespace admin-tools="http://exist-db.org/apps/writerslibrary/admin-tools";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://exist-db.org/apps/writerslibrary/config" at "config.xqm";
import module namespace library-functions="http://exist-db.org/apps/writerslibrary/library-functions" at "library-functions.xql";
import module namespace library-book-view="http://exist-db.org/apps/writerslibrary/library-book-view" at "library-book-view.xql";
import module namespace import-iiif="http://exist-db.org/apps/writerslibrary/import-iiif" at "import-iiif.xql";


(: This function checks whether a user is an Admin :)

declare function admin-tools:userIsAdmin() {
if (sm:is-dba(sm:id()//sm:real/sm:username/string())) 
then fn:true()
else fn:false()
};


(: This function is called in templates/library/home.html, it checks whether a user is an Admin and, if so,
   creates the tab with the 3 admin tools :)
   
declare function admin-tools:getAdmintools($node as node(), $model as map(*)) {
if (admin-tools:userIsAdmin() eq true()) 
then 
            <div class="admintools">
            <a class="info-link-admin-tools" href="javascript:void(0);" style="float:right;"><span class="admin-info">This tab with admin tools appears when a user is logged in as an administrator (dba) in eXist-db.</span><span class="glyphicon glyphicon-info-sign  tools-info-sign"></span></a>
                <h4>Admin Tools</h4>
                <p class="documentation-links"> > <a href="../tools/new-book-xml">Create a new book entry</a></p>
                <p class="documentation-links"> > <a href="../tools/import-from-IIIFmanifest">Import image links from a IIIF manifest</a></p>
                <p class="documentation-links"> > <a href="../tools/zone-coordinates-tool">Zone coordinates tool (for IIIF images only)</a></p>
                
            </div>
else ()
    
};



(: This function is called in templates/library/library-page.html, it fetches the css files needed for the
   admin tools  :)
   
declare function admin-tools:getCss($node as node(), $model as map(*)){
if (request:get-parameter("view","") eq "admin-tools") then
<link type="TEXT/CSS" href="$resources/css/Jcrop.css" rel="STYLESHEET"/>
else ()
};

(: This function is called in templates/library/library-page.html, it fetches the js files needed for the
   admin tools  :)
   
declare function admin-tools:getJs($node as node(), $model as map(*)){
if (request:get-parameter("view","") eq "admin-tools") then

   let $croppingtool := if (request:get-parameter("tool","") eq "zone-tool") then 
                            (<script src="$resources/scripts/library/Jcrop.js"/>,
                            <script src="$resources/scripts/library/clipboard.min.js"/>,
                            <script src="$resources/scripts/library/jquery.magnific-popup.min.js"/>,
                            <script src="$resources/scripts/library/croppingTool.js"/>) 
                        else ()
    return (<script src="$resources/scripts/library/admin-tools.js"/>,$croppingtool)
    
else ()
};

(: This function is called in templates/library/tools/zone-coordinates-tool.html, it checks whether an image
   has correctly been selected or not :)
   
declare function admin-tools:initiateZoneTool($node as node(), $model as map(*)){
if (request:get-parameter("pageID","") ne "")
then
    <div id="cropping_tool"> </div>
else
    <p class="notification">You can access the tool from the <strong>book view</strong>: navigate to an image and click on "<span class="admin-tools-heading">Admin Tool: </span><a id="page-to-open-link" href="#">open page <span id="page-to-open">X</span> in the <span class="admin-tools-zone-tool-name">Zone coordinates tool</span></a>".</p>
};


(: This function is called from admin-tools:initiateZoneTool(), it takes the parameter "pageID" (delivered via the URL) and searches the correct <facimile> element in the database :)

declare function admin-tools:createImageID() {
let $bookID := substring-before(request:get-parameter("pageID",""),",")
let $pageID := replace(substring-after(request:get-parameter("pageID",""),","), "-_-", " ")
let $bookNode := library-book-view:getBookNode($bookID)
let $imageID := substring-before($bookNode//page[pagenumber eq $pageID]/facsimile/text(),"/full/")

return $imageID
};

(: This function creates the javascript variables needed to correctly call up the image in the zone tool :)
declare function admin-tools:setImageID($node as node(), $model as map(*)) {
if (admin-tools:userIsAdmin() eq true() and request:get-parameter("view","") eq "admin-tools") 
then 
    <script>
    var imageID = "{admin-tools:createImageID()}";
    var bookID = "{substring-before(request:get-parameter("pageID",""),",")}";
    var pageID = "{substring-after(request:get-parameter("pageID",""),",")}";
    var images = [{ let $bookNode := library-book-view:getBookNode(substring-before(request:get-parameter("pageID",""),",")) 
                    let $pages := for $page in $bookNode/module[@type='pages']/page return concat('"',$page/pagenumber/text(),'"')
                    return string-join($pages, ", ")
                   }]

    </script>
else ()
};
