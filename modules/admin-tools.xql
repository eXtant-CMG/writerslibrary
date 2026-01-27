xquery version "3.1";

module namespace admin-tools="http://exist-db.org/apps/writerslibrary/admin-tools";

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
    let $adminToolsScripts := if (request:get-parameter("view","") eq "admin-tools") then
                                  let $croppingtool := if (request:get-parameter("tool","") eq "zone-tool") then 
                                                          (<script src="$resources/scripts/library/Jcrop.js"/>,
                                                          <script src="$resources/scripts/library/clipboard.min.js"/>,
                                                          <script src="$resources/scripts/library/jquery.magnific-popup.min.js"/>,
                                                          <script src="$resources/scripts/library/croppingTool.js"/>) 
                                                      else ()
                                  return (<script src="$resources/scripts/library/admin-tools.js"/>, $croppingtool)
                              else ()
    let $adminLibraryManager := if (admin-tools:userIsAdmin()) then
                                    <script src="$resources/scripts/library/admin-library-manager.js"/>
                                else ()
    return ($adminToolsScripts, $adminLibraryManager)
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

(: MANAGE LIBRARY COLLECTIONS feature :)

(: This function creates the button "Manage Library Collections" :)
declare function admin-tools:manageLibraryCollectionsButton($node as node(), $model as map(*)) {
if (admin-tools:userIsAdmin() eq true()) 
then
    <button type="button" class="btn btn-primary manage-button" data-toggle="modal" data-target="#collectionsModal">
           Manage Library Collections
    </button>
else ()
};

(: This function creates the "Manage Library Collections" modal window :)
declare function admin-tools:manageLibraryCollections($node as node(), $model as map(*)) {
if (admin-tools:userIsAdmin() eq true()) 
then
    let $libraryID := request:get-parameter("libraryID", "sample-library")
    let $librariesDoc := doc($config:data-root || '/libraries.xml')
    let $libraries := $librariesDoc/libraries/library
    
    return
        <div>
    
            <div class="table-responsive">
              <table class="table table-sm table-striped" id="library-collections-table">
                <thead>
                  <tr>
                    <th style="width:34%;">Name</th>
                    <th style="width:22%;">ID</th>
                    <th style="width:12%;">Active</th>
                    <th style="width:12%;">Default</th>
                  </tr>
                </thead>
                <tbody>
                  {
                    for $lib in $libraries
                    let $id := string($lib/@id)
                    let $name := normalize-space(string($lib))
                    let $isActive := ($id = $libraryID)
                    (: Assumption: default library is stored as @default="true" on the <library> element.
                       If you store it differently, change this line accordingly. :)
                    let $isDefault := ($lib is $lib/../*[1])
                    order by $name
                    return
                      <tr data-library-id="{$id}">
                        <td>
                          {
                            if ($isActive) then
                              $name
                            else
                              <a href="../../{$id}/home/welcome.html"
                                 target="_parent"
                                 rel="noopener noreferrer"
                                 style="text-decoration:underline;">
                                {$name}
                              </a>
                          }
                        </td>
                        <td><code>{$id}</code></td>
    
                        <td>
                          { if ($isActive) then <span class="check">✓</span> else () }
                        </td>
    
                        <td>
                          { if ($isDefault) then <span class="check">✓</span> else () }
                        </td>
                      </tr>
                  }
                </tbody>
              </table>
              <p>To <span class="bold">delete</span> a library collection, <span class="bold">remove the folder</span> named with the library ID and delete the corresponding <code>&lt;library/&gt;</code> entry in <code>data/libraries.xml</code>.</p>
              <p>To make a library collection the <span class="bold">default</span> collection, move its <code>&lt;library/&gt;</code> entry to the first position in <code>data/libraries.xml</code>.</p>
            </div>
    
            <hr/>
    
            <h4 style="margin-top:0.75rem;font-size:1.2em;">Add a new library</h4>
            <form id="add-library-form" class="form" onsubmit="return false;">
              <div class="form-row">
                <div class="col-md-6 mb-2">
                  <label for="newLibraryName">Library name:</label>
                  <input type="text"
                         id="newLibraryName"
                         class="form-control"
                         placeholder="e.g. 'Virginia Woolf Library'"
                         autocomplete="off"
                         style="width: 350px;"/>
                </div>
                <div class="col-md-4 mb-2">
                  <label for="newLibraryId">Library ID:</label>
                  <input type="text"
                       id="newLibraryId"
                       class="form-control"
                       placeholder="e.g. woolf-library"
                       autocomplete="off"
                       style="width: 350px;"
                       oninput="this.value = this.value.toLowerCase().replace(/[^a-z0-9\-]/g, '')"
                       title="Use only lowercase letters, digits, and hyphens (no spaces)"/>
                  <small class="form-text text-muted">
                    Use lowercase letters, digits, and hyphens (no spaces).
                  </small>
                </div>
                <div class="col-md-2 mb-2">
                  <label> </label> <!-- Spacer to align button -->
                  <button type="button" class="btn btn-success btn-block js-create-library">
                    Create
                  </button>
                </div>
              </div>
            </form>
        </div>
else ()
};
