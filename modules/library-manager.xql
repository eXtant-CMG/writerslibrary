xquery version "3.1";

module namespace libmgr="http://exist-db.org/apps/writerslibrary/library-manager";

import module namespace config="http://exist-db.org/apps/writerslibrary/config" at "config.xqm";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare option exist:serialize "method=xml indent=yes";

(:~
 : Create a new library collection
 : @param $libraryId the ID for the new library (e.g., "modernism-library")
 : @param $libraryName the display name for the library (e.g., "Modernism Library")
 : @return success or error message
 :)
declare function libmgr:create-library($libraryId as xs:string, $libraryName as xs:string) as map(*) {
    try {

        (: Validate inputs :)
        if (not(matches($libraryId, "^[a-z0-9\-]+$"))) then
            map { "success": false(), "message": "Invalid library ID format" }
        else if ($libraryId = "" or $libraryName = "") then
            map { "success": false(), "message": "Library ID and name are required" }
        else
            (: Check if library already exists :)
            let $librariesDoc := doc($config:data-root || '/libraries.xml')
            let $existingLibrary := $librariesDoc//library[@id = $libraryId]
            return
                if (exists($existingLibrary)) then
                    map { "success": false(), "message": "A library with this ID already exists" }
                else
                    (: Create the library entry and directory structure :)
                    let $updateLibrariesXml := libmgr:add-library-entry($libraryId, $libraryName)
                    let $createDirectory := libmgr:create-library-directory($libraryId, $libraryName)
                    return
                        if ($updateLibrariesXml and $createDirectory) then
                            map { "success": true(), "message": "Library created successfully" }
                        else
                            map { "success": false(), "message": "Error creating library" }
    } catch * {
        map { "success": false(), "message": "Exception: " || $err:description }
    }
};

(:~
 : Add a new library entry to libraries.xml
 :)
declare function libmgr:add-library-entry($libraryId as xs:string, $libraryName as xs:string) as xs:boolean {
  try {
    let $librariesDoc := doc($config:data-root || '/libraries.xml')
    let $libraries    := $librariesDoc/libraries

    let $nl     := "&#10;"
    let $indent := "    " (: match your file: 4 spaces :)
    let $newLibrary := <library id="{$libraryId}">{$libraryName}</library>

    return (
      (: 1) Remove trailing whitespace text nodes so </libraries> won’t get stuck :)
      update delete
        $libraries/text()[matches(., '^\s*$')][not(following-sibling::element())],

      (: 2) Insert with proper surrounding whitespace :)
      update insert (
        text { $nl || $indent },
        $newLibrary,
        text { $nl }
      ) into $libraries,

      true()
    )
  } catch * {
    false()
  }
};

(:~
 : Create the library directory structure with initial XML files
 :)
declare function libmgr:create-library-directory($libraryId as xs:string, $libraryName as xs:string) as xs:boolean {
    try {
        let $libraryPath := $config:data-root || '/' || $libraryId
        
        (: Create the collection/directory :)
        let $createCollection := xmldb:create-collection($config:data-root, $libraryId)
                
        (: Create books/ subcollection :)
        let $createBooksCollection := xmldb:create-collection($libraryPath, "books")
        
        (: Create sample book ADA-MYF.xml :)
        let $bookXml :=
          <book type="EL" id="ADA-MYF">
            <module type="bibl">
              <title sort="My First Book">My First Book</title>
              <type>Monograph</type>
              <author sort="Adams">
                <firstname>Anne</firstname>
                <lastname>Adams</lastname>
              </author>
              <volume/>
              <editor/>
              <place>London</place>
              <publisher>My Publisher</publisher>
              <date>1924</date>
              <edition/>
              <generalnote/>
            </module>
          </book>
        
        let $prettyBook :=
          serialize(
            $bookXml,
            <output:serialization-parameters>
              <output:method value="xml"/>
              <output:indent value="yes"/>
              <output:omit-xml-declaration value="yes"/>
            </output:serialization-parameters>
          )
        
        let $storeBook :=
          xmldb:store($libraryPath || "/books", "ADA-MYF.xml", $prettyBook, "application/xml")


        (: Create config.xml :)
        let $configXml := 
        <module type="library">
            <title>{$libraryName}</title>
            <subtitle></subtitle>
            <imgUrl>
                <serverPath>$library-images/</serverPath>
                <pathToList type="element">module</pathToList>
                <pathToItem type="element">page</pathToItem>
            </imgUrl>
            <sorting>
                <!-- Author -->
                <sortBy id="Author" browseCategory="Alphabet">
                    <label>Author</label>
                    <rangeQuery>
                        <fields>("library-book-Author")</fields>
                        <operators>("starts-with")</operators>
                        <keys>$currentBrowseValue</keys>
                    </rangeQuery>
                    <orderBy>author</orderBy>
                    <breadcrumbPhrase>author</breadcrumbPhrase>
                </sortBy>
                <!-- Title -->
                <sortBy id="Title" browseCategory="Alphabet">
                    <label>Title</label>
                    <rangeQuery>
                        <fields>("library-book-Title")</fields>
                        <operators>("starts-with")</operators>
                        <keys>$currentBrowseValue</keys>
                    </rangeQuery>
                    <orderBy>title</orderBy>
                    <breadcrumbPhrase>title</breadcrumbPhrase>
                </sortBy>
                <!-- Place -->
                <sortBy id="Place" browseCategory="Alphabet">
                    <label>Place</label>
                    <rangeQuery>
                        <fields>("library-book-Place")</fields>
                        <operators>("starts-with")</operators>
                        <keys>$currentBrowseValue</keys>
                    </rangeQuery>
                    <orderBy>place</orderBy>
                    <breadcrumbPhrase>place of publication</breadcrumbPhrase>
                </sortBy>
                <!-- Date -->
                <sortBy id="Date" browseCategory="DateRange">
                    <label>Date</label>
                    <rangeQuery>
                        <fields>("library-book-Date")</fields>
                        <operators>("starts-with")</operators>
                        <keys>$currentBrowseValue</keys>
                    </rangeQuery>
                    <orderBy>date</orderBy>
                    <breadcrumbPhrase>date of publication</breadcrumbPhrase>
                </sortBy>
                <!-- Inscription -->
                <sortBy id="Inscription" browseCategory="Alphabet">
                    <label>Inscription</label>
                    <rangeQuery>
                        <fields>("library-book-inscription","library-book-Author")</fields>
                        <operators>("contains","starts-with")</operators>
                        <keys>"*",$currentBrowseValue</keys>
                    </rangeQuery>
                    <orderBy>author</orderBy>
                    <breadcrumbPhrase>the presence of an inscription</breadcrumbPhrase>
                </sortBy>
                <!-- All Reading Traces -->
                <sortBy id="readingTraces" browseCategory="Alphabet">
                    <label>All Reading Traces</label>
                    <rangeQuery>
                        <fields>("library-book-readingTraces","library-book-Author")</fields>
                        <operators>("contains","starts-with")</operators>
                        <keys>"*",$currentBrowseValue</keys>
                    </rangeQuery>
                    <orderBy>author</orderBy>
                    <breadcrumbPhrase>the presence of reading traces</breadcrumbPhrase>
                </sortBy>
                <!-- Marginalia only -->
                <sortBy id="Marginalia" browseCategory="Alphabet">
                    <label>Marginalia only</label>
                    <rangeQuery>
                        <fields>("library-book-Marginalia","library-book-Author")</fields>
                        <operators>("contains","starts-with")</operators>
                        <keys>"*",$currentBrowseValue</keys>
                    </rangeQuery>
                    <orderBy>author</orderBy>
                    <breadcrumbPhrase>the presence of marginalia</breadcrumbPhrase>
                </sortBy>
            </sorting>
            <browsing>
                <browseBy id="Alphabet">
                    <browse>
                        <value>A</value>
                        <label>A</label>
                    </browse>
                    <browse>
                        <value>B</value>
                        <label>B</label>
                    </browse>
                    <browse>
                        <value>C</value>
                        <label>C</label>
                    </browse>
                    <browse>
                        <value>D</value>
                        <label>D</label>
                    </browse>
                    <browse>
                        <value>E</value>
                        <label>E</label>
                    </browse>
                    <browse>
                        <value>F</value>
                        <label>F</label>
                    </browse>
                    <browse>
                        <value>G</value>
                        <label>G</label>
                    </browse>
                    <browse>
                        <value>H</value>
                        <label>H</label>
                    </browse>
                    <browse>
                        <value>I</value>
                        <label>I</label>
                    </browse>
                    <browse>
                        <value>J</value>
                        <label>J</label>
                    </browse>
                    <browse>
                        <value>K</value>
                        <label>K</label>
                    </browse>
                    <browse>
                        <value>L</value>
                        <label>L</label>
                    </browse>
                    <browse>
                        <value>M</value>
                        <label>M</label>
                    </browse>
                    <browse>
                        <value>N</value>
                        <label>N</label>
                    </browse>
                    <browse>
                        <value>O</value>
                        <label>O</label>
                    </browse>
                    <browse>
                        <value>P</value>
                        <label>P</label>
                    </browse>
                    <browse>
                        <value>Q</value>
                        <label>Q</label>
                    </browse>
                    <browse>
                        <value>R</value>
                        <label>R</label>
                    </browse>
                    <browse>
                        <value>S</value>
                        <label>S</label>
                    </browse>
                    <browse>
                        <value>T</value>
                        <label>T</label>
                    </browse>
                    <browse>
                        <value>U</value>
                        <label>U</label>
                    </browse>
                    <browse>
                        <value>V</value>
                        <label>V</label>
                    </browse>
                    <browse>
                        <value>W</value>
                        <label>W</label>
                    </browse>
                    <browse>
                        <value>X</value>
                        <label>X</label>
                    </browse>
                    <browse>
                        <value>Y</value>
                        <label>Y</label>
                    </browse>
                    <browse>
                        <value>Z</value>
                        <label>Z</label>
                    </browse>
                </browseBy>
                <browseBy id="DateRange">
                    <browse>
                        <value>17</value>
                        <label>1700→</label>
                    </browse>
                    <browse>
                        <value>18</value>
                        <label>1800→</label>
                    </browse>
                    <browse>
                        <value>190</value>
                        <label>1900→</label>
                    </browse>
                    <browse>
                        <value>191</value>
                        <label>1910→</label>
                    </browse>
                    <browse>
                        <value>192</value>
                        <label>1920→</label>
                    </browse>
                    <browse>
                        <value>193</value>
                        <label>1930→</label>
                    </browse>
                    <browse>
                        <value>194</value>
                        <label>1940→</label>
                    </browse>
                    <browse>
                        <value>195</value>
                        <label>1950→</label>
                    </browse>
                    <browse>
                        <value>196</value>
                        <label>1960→</label>
                    </browse>
                    <browse>
                        <value>197</value>
                        <label>1970→</label>
                    </browse>
                    <browse>
                        <value>198</value>
                        <label>1980→</label>
                    </browse>
                    <browse>
                        <value>n.d.</value>
                        <label>n.d.</label>
                    </browse>
                </browseBy>
        
            </browsing>
            <!--  index fields to be declared in collection.xconf 
                <lucene>
                    <text qname="module" index="no">
                        <ignore qname="Term"/>
                        <ignore qname="Source"/>
                        <ignore qname="Comment"/>
                        <field name="library-book-biblio" if="@type='bibl' or @type='prop'"/>
                        <field name="bookID" expression="parent::book/@id"/>
                        <facet dimension="document" expression="'library-bibliography'"/>
                        <facet dimension="module" expression="substring-after(util:collection-name(.),'data/')"/>
                    </text>
                    
                    <text qname="zone">
                        <ignore qname="Coordinates"/>
                        <ignore qname="PlaceOnThePage"/>
                        <ignore qname="Handwriting"/>
                        <ignore qname="WritingTool"/>
                        <field name="library-book-zone-bookID" expression="ancestor::book/@id"/>
                        <field name="library-book-zone-pagenumber" expression="preceding-sibling::pagenumber"/>
                        <field name="library-book-zone-author" expression="ancestor::book/module[1]/author[1]"/>
                        <field name="library-book-zone-title" expression="ancestor::book/module[1]/title[1]"/>
                        <field name="library-book-zone-subtitle" expression="ancestor::book/module[1]/subtitle[1]"/>
                        <facet dimension="document" expression="'library-readingtraces'"/>
                        <facet dimension="module" expression="substring-after(util:collection-name(.),'data/')"/>
                    </text>
                    
                    <text qname="m">
                        <field name="library-book-marginalia-bookID" expression="ancestor::book/@id"/>
                        <field name="library-book-marginalia-zoneID" expression="ancestor::zone/number"/>
                        <field name="library-book-marginalia-pagenumber" expression="ancestor::page/pagenumber"/>
                        <field name="library-book-marginalia-author" expression="ancestor::book/module[1]/author[1]"/>
                        <field name="library-book-marginalia-title" expression="ancestor::book/module[1]/title[1]"/>
                        <field name="library-book-marginalia-subtitle" expression="ancestor::book/module[1]/subtitle[1]"/>
                        <facet dimension="document" expression="'library-readingtraces'"/>
                        <facet dimension="module" expression="substring-after(util:collection-name(.),'data/')"/>
                    </text>
                    
                    <text qname="ManuscriptLink" index="no">
                        <field name="library-book-with-manuscript-link" expression="ancestor::book/@id"/>
                        <facet dimension="module" expression="substring-after(util:collection-name(.),'data/')"/>
                    </text>
                </lucene>
                <range>
                    <create qname="book">
                        <field name="library-book-siglum" type="xs:string" match="@id"/>
                        <field name="library-book-type" type="xs:string" match="@type"/>
                        <field name="library-book-Author" type="xs:string" match="module/author/@sort"/>
                        <field name="library-book-Title" type="xs:string" match="module/title/@sort"/>
                        <field name="library-book-Date" type="xs:string" match="module/date"/>
                        <field name="library-book-Place" type="xs:string" match="module/place"/>
                        <field name="library-book-Dedication" type="xs:string" match="module/dedication"/>
                        <field name="library-book-readingTraces" type="xs:string" match="module/page"/>
                        <field name="library-book-Marginalia" type="xs:string" match="module//m"/>
                    </create>                    
                </range>
            -->
            <!-- 
               An example of a range query that combines two fields:
                  <sortBy id="Author" browseCategory="Alphabet">
                    <label>Author</label>
                    <rangeQuery>
                        <fields>("library-book-Author","library-book-type")</fields>
                        <operators>("starts-with","eq")</operators>
                        <keys>$currentBrowseValue, "EL"</keys>
                    </rangeQuery>
                    <orderBy>author</orderBy>
                    <breadcrumbPhrase>author</breadcrumbPhrase>
                </sortBy>
            -->
        </module>
        
        let $prettyConfig :=
          serialize(
            $configXml,
            <output:serialization-parameters>
              <output:method value="xml"/>
              <output:indent value="yes"/>
              <output:omit-xml-declaration value="yes"/>
            </output:serialization-parameters>
          )
        let $storeConfig := xmldb:store($libraryPath, 'config.xml', $prettyConfig, "application/xml")
        

        
        (: Create home.xml :)
        let $homeXml := 
            <div id="home-grid-container">
                <div id="about">
                    <h4>Welcome to {$libraryName}</h4>
                    
                    <p>To edit this home page, open <code>data/{$libraryId}/home.xml</code> in eXide.</p>
                    <div id="documentation-tools-container">    
                        <div id="documentation">  
                            <p class="documentation-links"><a style="color: #003828; font-size:1.4em; font-weight:bold;" href="../documentation/index.html">Documentation</a><br/>
                                 ∟ <a href="../documentation/index.html#toc_1">Getting started</a><br/>
                                 ∟ <a href="../documentation/index.html#toc_5">Encoding schema</a><br/>
                                 ∟ <a href="../documentation/index.html#toc_10">Including images</a><br/>
                                 ∟ <a href="../documentation/index.html#toc_14">Admin tools</a></p>
                            <p class="documentation-links"><a style="color: #003828; font-size:1.4em; font-weight:bold;" href="../usermanual/index.html">User Manual</a></p>
                        </div><!--/documentation-->
                        
                        <!-- Do not remove, this line generates the admin tools -->
                        <span class="admin-tools:getAdmintools"/>
                        
                    </div><!--/documentation-tools-container-->           

                </div><!--/about-->
                <div id="home-image">
                    <img class="home" src="$resources/images/home.jpg" width="350"/>
                </div>
                
            <!--/home-grid-container--></div>
            
        let $prettyHome :=
          serialize(
            $homeXml,
            <output:serialization-parameters>
              <output:method value="xml"/>
              <output:indent value="yes"/>
              <output:omit-xml-declaration value="yes"/>
            </output:serialization-parameters>
          )
        let $storeHome := xmldb:store($libraryPath, 'home.xml', $prettyHome, "application/xml")
        
        return true()
    } catch * {
        false()
    }
};