xquery version "3.0";

import module namespace library-browse = "http://exist-db.org/apps/writerslibrary/library-browse" at "modules/library-browse.xql";
import module namespace admin-tools = "http://exist-db.org/apps/writerslibrary/admin-tools" at "modules/admin-tools.xql";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>
    
else if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="library/home/welcome"/>
    </dispatch>
    
        (: forwards all paths to images to resources/images/library/   :)
        (: best practice, however, is to fetch the images from outside :)
        (: of the eXist app. :)
    else if (contains($exist:path, "/$library-images/")) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/resources/images/library/{substring-after($exist:path, '/$library-images/')}">
                <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
            </forward>
        </dispatch>
        
    (: resource paths containing $resources are loaded from the resources folder :)
    else if (contains($exist:path, "/$resources/")) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/resources/{substring-after($exist:path, '/$resources/')}">
                <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
            </forward>
        </dispatch>

(: Resource paths starting with $shared are loaded from the shared-resources app :)
else if (contains($exist:path, "/$app/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/{substring-after($exist:path, '/$app/')}">
             <set-header
                        name="Cache-Control"
                        value="no-cache"/>
                    <cache-control
                        cache="no"/>
        </forward>
    </dispatch>


    else if (contains($exist:path,"usermanual/")) then
                <dispatch
                        xmlns="http://exist.sourceforge.net/NS/exist">
                        <forward
                            url="{$exist:controller}/templates/library/documentation/usermanual-container.html">
                            <set-header
                                name="Cache-Control"
                                value="no-cache"/>
                            <cache-control
                                cache="no"/>
                        </forward>
                        <view>
                            <forward
                                url="{$exist:controller}/modules/view.xq">
                                <set-header
                                    name="Cache-Control"
                                    value="no-cache"/>
                            </forward>
                        </view>
                    </dispatch>
                    
     else if (contains($exist:path,"documentation/")) then
                <dispatch
                        xmlns="http://exist.sourceforge.net/NS/exist">
                        <forward
                            url="{$exist:controller}/templates/library/documentation/documentation.html">
                            <set-header
                                name="Cache-Control"
                                value="no-cache"/>
                            <cache-control
                                cache="no"/>
                        </forward>
                        <view>
                            <forward
                                url="{$exist:controller}/modules/view.xq">
                                <set-header
                                    name="Cache-Control"
                                    value="no-cache"/>
                            </forward>
                        </view>
                    </dispatch>
        

    (: home page :)
    else if (starts-with($exist:path,"/library/home")) then
                <dispatch
                    xmlns="http://exist.sourceforge.net/NS/exist">
                    <!-- forward to  template bookview.html -->
                    <forward url="{$exist:controller}/templates/library/home.html">
                        <set-header
                            name="Cache-Control"
                            value="no-cache"/>
                        <cache-control
                            cache="no"/>
                    </forward>
                    <view>
                        <forward
                            url="{$exist:controller}/modules/view.xq">
                        <add-parameter name="moduleID" value="/library"/>
                        <add-parameter name="view" value="homepage"/>
                            <set-header
                                name="Cache-Control"
                                value="no-cache"/>
                        </forward>
                    </view>
                </dispatch> 
                
      (: search engine :)
    else if (contains($exist:path,"/library/search/")) then
                <dispatch
                    xmlns="http://exist.sourceforge.net/NS/exist">
                    <!-- forward to  template search.html -->
                    <forward url="{$exist:controller}/templates/library/search.html">
                        <set-header
                            name="Cache-Control"
                            value="no-cache"/>
                        <cache-control
                            cache="no"/>
                    </forward>
                    <view>
                        <forward
                            url="{$exist:controller}/modules/view.xq">
                        <add-parameter name="moduleID" value="/library"/>
                        <add-parameter name="view" value="search"/>
                            <set-header
                                name="Cache-Control"
                                value="no-cache"/>
                        </forward>
                    </view>
                </dispatch>
                
    (: admin tool: import images from IIIF manifest :)
    else if (starts-with($exist:path,"/library/tools/import-from-IIIFmanifest")) then
                <dispatch
                    xmlns="http://exist.sourceforge.net/NS/exist">
                    <!-- forward to  template bookview.html -->
                    <forward url="{$exist:controller}/templates/library/tools/import-from-IIIFmanifest.html">
                        <set-header
                            name="Cache-Control"
                            value="no-cache"/>
                        <cache-control
                            cache="no"/>
                    </forward>
                    <view>
                        <forward
                            url="{$exist:controller}/modules/view.xq">
                        <add-parameter name="moduleID" value="/library"/>
                        <add-parameter name="view" value="admin-tools"/>
                            <set-header
                                name="Cache-Control"
                                value="no-cache"/>
                        </forward>
                    </view>
                </dispatch>
                
    (: admin tool: zone coordinates tool :)
    else if (starts-with($exist:path,"/library/tools/zone-coordinates-tool")) then
                <dispatch
                    xmlns="http://exist.sourceforge.net/NS/exist">
                    <!-- forward to  template bookview.html -->
                    <forward url="{$exist:controller}/templates/library/tools/zone-coordinates-tool.html">
                        <set-header
                            name="Cache-Control"
                            value="no-cache"/>
                        <cache-control
                            cache="no"/>
                    </forward>
                    <view>
                        <forward
                            url="{$exist:controller}/modules/view.xq">
                        <add-parameter name="moduleID" value="/library"/>
                        <add-parameter name="view" value="admin-tools"/>
                        <add-parameter name="tool" value="zone-tool"/>
                            <set-header
                                name="Cache-Control"
                                value="no-cache"/>
                        </forward>
                    </view>
                </dispatch>
    
    (: admin tool: new book :)
    else if (starts-with($exist:path,"/library/tools/new-book-xml")) then
                <dispatch
                    xmlns="http://exist.sourceforge.net/NS/exist">
                    <!-- forward to  template bookview.html -->
                    <forward url="{$exist:controller}/templates/library/tools/new-book-xml.html">
                        <set-header
                            name="Cache-Control"
                            value="no-cache"/>
                        <cache-control
                            cache="no"/>
                    </forward>
                    <view>
                        <forward
                            url="{$exist:controller}/modules/view.xq">
                        <add-parameter name="moduleID" value="/library"/>
                        <add-parameter name="view" value="admin-tools"/>
                            <set-header
                                name="Cache-Control"
                                value="no-cache"/>
                        </forward>
                    </view>
                </dispatch>

    (: browse view:)
    else if (contains($exist:path,"/library/") and not(contains($exist:path,".html"))) then
                <dispatch
                    xmlns="http://exist.sourceforge.net/NS/exist">
                    <!-- forward to  template browse.html -->
                    <forward url="{$exist:controller}/templates/library/browse.html">
                        <set-header
                            name="Cache-Control"
                            value="no-cache"/>
                        <cache-control
                            cache="no"/>
                    </forward>
                    <view>
                        <forward
                            url="{$exist:controller}/modules/view.xq">
                        <add-parameter name="view" value=""/>
                        <add-parameter name="sortAndBrowse" value="{substring-after($exist:path,'library/')}"/>
                        <add-parameter name="moduleID" value="/library"/>
                            <set-header
                                name="Cache-Control"
                                value="no-cache"/>
                        </forward>
                    </view>
                </dispatch>
      
      (: 5: book view :)
    else if (contains($exist:path,"/library/") and not(contains($exist:path,"search/")) and contains($exist:path,".html")) then
                <dispatch
                    xmlns="http://exist.sourceforge.net/NS/exist">
                    <!-- forward to  template bookview.html -->
                    <forward url="{$exist:controller}/templates/library/bookview.html">
                        <set-header
                            name="Cache-Control"
                            value="no-cache"/>
                        <cache-control
                            cache="no"/>
                    </forward>
                    <view>
                        <forward
                            url="{$exist:controller}/modules/view.xq">
                        <add-parameter name="view" value="book"/>
                        <add-parameter name="bookID" value="{substring-before(substring-after($exist:path,'library/'),'.html')}"/>
                        <add-parameter name="moduleID" value="/library"/>
                            <set-header
                                name="Cache-Control"
                                value="no-cache"/>
                        </forward>
                    </view>
                </dispatch> 
 
                
else if (ends-with($exist:resource, ".html")) then
    (: the html page is run through view.xq to expand templates :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/modules/view.xq"/>
        </view>
		<error-handler>
			<forward url="{$exist:controller}/error-page.html" method="get"/>
			<forward url="{$exist:controller}/modules/view.xq"/>
		</error-handler>
    </dispatch>


(: Resource paths starting with $shared are loaded from the shared-resources app :)
else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>
else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>
