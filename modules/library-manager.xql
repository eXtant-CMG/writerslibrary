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
 : Fetch a IIIF manifest and return a <module type="pages"> element
 : with one <page> per image, or an empty sequence on failure.
 : Mirrors the logic in import-iiif.xql.
 :)
declare function libmgr:pages-from-iiif-manifest($manifestUrl as xs:string) {
    try {
        let $raw  := unparsed-text($manifestUrl)
        let $data := json-to-xml($raw)

        let $images :=
            for $sequence in $data//fn:array[@key="sequences"]//fn:map
            for $canvas in $sequence//fn:array[@key="canvases"]//fn:map
            for $image in $canvas//fn:array[@key="images"]//fn:map
            let $imageId := $image/fn:string[@key="@id"]/data()
            let $title   := $canvas//fn:array[@key="metadata"]/fn:map[fn:string[@key="label"]/data() = "Title"]/fn:string[@key="value"]/data()
            where $imageId ne "" and
                  not(contains($imageId, "/anno")) and
                  not(contains($imageId, "default.jpg")) and
                  not(contains($imageId, "annotation")) and
                  not(contains($imageId, "/full/"))
            return
                <image>
                    <id>{concat($imageId, "/full/680,/0/default.jpg")}</id>
                    <title>{$title}</title>
                </image>

        return
            if (exists($images)) then
                <module type="pages">
                    {for $image at $pos in $images
                     let $label :=
                         if ($image/title/text() ne "") then
                             if (starts-with($image/title/text(), "Page "))
                             then substring-after($image/title/text(), "Page ")
                             else $image/title/text()
                         else $pos
                     return
                         <page>
                             <pagenumber>{$label}</pagenumber>
                             <facsimile>{$image/id/text()}</facsimile>
                         </page>}
                </module>
            else ()
    } catch * {
        ()
    }
};

(:~
 : Create a new book entry and store it in the library's books collection.
 : @param $libraryId  the target library (e.g. "woolf-library")
 : @param $bookId     the unique book siglum / filename stem (e.g. "WOO-WAV")
 : @param $bookType   "EL" (extant) or "LL" (lost)
 : @param $firstname  author firstname
 : @param $lastname   author lastname
 : @param $title      book title
 : @param $subtitle   book subtitle (may be empty)
 : @param $type       publication type (Monograph, Journal, …)
 : @param $volume     volume number (may be empty)
 : @param $series     series (may be empty)
 : @param $edition    edition (may be empty)
 : @param $editor     editor (may be empty)
 : @param $place      place of publication
 : @param $publisher  publisher
 : @param $date       publication date (YYYY or n.d.)
 : @param $generalnote general note (may be empty)
 : @param $location   current location / holding institution
 : @param $iiifManifest IIIF manifest URL (may be empty)
 : @param $iiifViewer   IIIF viewer URL (may be empty)
 : @return success/error map
 :)
declare function libmgr:create-book(
    $libraryId    as xs:string,
    $bookId       as xs:string,
    $bookType     as xs:string,
    $firstname    as xs:string,
    $lastname     as xs:string,
    $title        as xs:string,
    $subtitle     as xs:string,
    $type         as xs:string,
    $volume       as xs:string,
    $series       as xs:string,
    $edition      as xs:string,
    $editor       as xs:string,
    $place        as xs:string,
    $publisher    as xs:string,
    $date         as xs:string,
    $generalnote  as xs:string,
    $location     as xs:string,
    $iiifManifest      as xs:string,
    $iiifViewer        as xs:string,
    $importIIIFImages  as xs:boolean
) as map(*) {
    try {
        (: Basic validation :)
        if (not(matches($bookId, "^[a-zA-Z][a-zA-Z0-9\-]+$"))) then
            map { "success": false(), "message": "Invalid book ID format" }
        else if ($bookId eq "" or $libraryId eq "") then
            map { "success": false(), "message": "Book ID and library ID are required" }
        else if (not($bookType = ("EL", "LL"))) then
            map { "success": false(), "message": "Book type must be EL or LL" }
        else
            let $booksPath := $config:data-root || '/' || $libraryId || '/books'
            let $filename  := $bookId || '.xml'

            (: Check the file doesn't already exist :)
            return
                if (doc-available($booksPath || '/' || $filename)) then
                    map { "success": false(), "message": "A book with this ID already exists" }
                else
                    (: Build the sort attributes :)
                    let $lastnameSortRaw := upper-case(substring($lastname, 1, 1)) || lower-case(substring($lastname, 2, 14))
                    let $titleSortRaw    := upper-case(substring($title, 1, 1)) || lower-case(substring($title, 2, 14))

                    (: Build the <IIIF> element only when a manifest URL was supplied :)
                    let $iiifElement :=
                        if ($iiifManifest ne "") then
                            <IIIF>
                                <IIIFmanifest>{$iiifManifest}</IIIFmanifest>
                                <IIIFviewer>{$iiifViewer}</IIIFviewer>
                            </IIIF>
                        else ()

                    (: Fetch and build <module type="pages"> if requested :)
                    let $pagesModule :=
                        if ($importIIIFImages and $iiifManifest ne "") then
                            libmgr:pages-from-iiif-manifest($iiifManifest)
                        else ()

                    let $bookXml :=
                        <book id="{$bookId}" type="{$bookType}">
                            <module type="bibl">
                                <author sort="{$lastnameSortRaw}">
                                    <firstname>{$firstname}</firstname>
                                    <lastname>{$lastname}</lastname>
                                </author>
                                <title sort="{$titleSortRaw}">{$title}</title>
                                <subtitle>{$subtitle}</subtitle>
                                <type>{$type}</type>
                                <volume>{$volume}</volume>
                                <series>{$series}</series>
                                <edition>{$edition}</edition>
                                <editor>{$editor}</editor>
                                <place>{$place}</place>
                                <publisher>{$publisher}</publisher>
                                <date>{$date}</date>
                                <generalnote>{$generalnote}</generalnote>
                                <location>{$location}</location>
                                {$iiifElement}
                            </module>
                            {$pagesModule}
                        </book>

                    let $_ := xmldb:store($booksPath, $filename, $bookXml, 'application/xml')
                    return map { "success": true(), "message": "Book saved as " || $filename }
    } catch * {
        map { "success": false(), "message": "Exception: " || $err:description }
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

(:
 : Standalone / ad-hoc functions for generating <page> blocks from a directory
 : of FADGI-style-named image files (e.g. DOS-BRO-2_0001_frontcover.jpg).
 :
 : Intended usage:
 :   1. Upload images to resources/images/{libraryID}/{siglum}/ as usual.
 :   2. Open eXide, import this module (or paste into library-manager.xql),
 :      and call libmgr:pages-from-directory-listing() to preview the XML,
 :      or libmgr:insert-pages-into-book() to write it straight into a book.
 :
 : Filename assumption: {SIGLUM}_{4-digit-sequence}_{label}.{ext}
 : e.g. DOS-BRO-2_0001_frontcover.jpg -> pagenumber "frontcover",
 :      facsimile "DOS-BRO-2/DOS-BRO-2_0001_frontcover.jpg"
 :
 : Adjust the $imageDir and facsimile path construction below if your
 : actual resources/images layout differs.
 :)

(: Generates <page> elements from a directory of images, sorted by the
   zero-padded sequence number embedded in the filename. Does NOT touch
   any book document -- just returns the XML so you can eyeball it first. :)
declare function libmgr:pages-from-directory-listing(
    $libraryID as xs:string,
    $siglum as xs:string
) as element(page)* {
    let $imageDir := $config:app-root || "/resources/images/" || $libraryID || "/" || $siglum
    let $files := xmldb:get-child-resources($imageDir)
    let $pattern := "^" || $siglum || "_(\d+)_(.+)\.(jpg|jpeg|png|tif|tiff|jp2)$"
    let $matched :=
        for $file in $files
        where matches($file, $pattern, "i")
        let $seq := replace($file, $pattern, "$1", "i")
        let $label := replace($file, $pattern, "$2", "i")
        order by $seq
        return
            <page>
                <pagenumber>{$label}</pagenumber>
                <facsimile>{$siglum || "/" || $file}</facsimile>
            </page>
    return $matched
};

(: Same as above, but also reports any files in the directory that did NOT
   match the expected naming pattern -- run this first as a sanity check
   before trusting the output, since a stray file (a .DS_Store, an unrelated
   scan, an inconsistent name) would otherwise be silently skipped. :)
declare function libmgr:check-directory-listing(
    $libraryID as xs:string,
    $siglum as xs:string
) as element(report) {
    let $imageDir := $config:app-root || "/resources/images/" || $libraryID || "/" || $siglum
    let $files := xmldb:get-child-resources($imageDir)
    let $pattern := "^" || $siglum || "_(\d+)_(.+)\.(jpg|jpeg|png|tif|tiff|jp2)$"
    let $matchedCount := count($files[matches(., $pattern, "i")])
    let $unmatched := $files[not(matches(., $pattern, "i"))]
    return
        <report>
            <directory>{$imageDir}</directory>
            <totalFiles>{count($files)}</totalFiles>
            <matched>{$matchedCount}</matched>
            <unmatchedFiles>
                {for $f in $unmatched return <file>{$f}</file>}
            </unmatchedFiles>
        </report>
};

(: Finds the book document by ID -- mirrors the lookup pattern already used
   in library-book-view:getBookNode(). :)
declare function libmgr:get-book-doc(
    $libraryID as xs:string,
    $bookID as xs:string
) as node()? {
    let $booksCollection := $config:data-root || '/' || $libraryID || '/books'
    return collection($booksCollection)/range:field-eq("library-book-ID", $bookID)[1]
};

(: Inserts the generated <page> elements directly into a book's
   module[@type="pages"] (creating that module if it doesn't exist yet).
   This WRITES to the document -- run pages-from-directory-listing() and
   check-directory-listing() first to confirm the output looks right. :)
declare function libmgr:insert-pages-into-book(
    $libraryID as xs:string,
    $bookID as xs:string,
    $siglum as xs:string
) as element()? {
    let $bookNode := libmgr:get-book-doc($libraryID, $bookID)
    let $allPages := libmgr:pages-from-directory-listing($libraryID, $siglum)
    return
        if (not($bookNode)) then
            <error>No book found with id "{$bookID}" in library "{$libraryID}".</error>
        else if (empty($allPages)) then
            <error>No matching images found for siglum "{$siglum}" -- run check-directory-listing() first.</error>
        else
            let $existingPagesModule := $bookNode/module[@type="pages"]
            let $existingFacsimiles := $existingPagesModule/page/facsimile/text()
            let $newPages := $allPages[not(facsimile/text() = $existingFacsimiles)]
            return
                if (empty($newPages)) then
                    <skipped>All {count($allPages)} page(s) for "{$bookID}" already present -- nothing inserted.</skipped>
                else
                    (
                        if ($existingPagesModule) then
                            update insert $newPages into $existingPagesModule
                        else
                            update insert <module type="pages">{$newPages}</module> into $bookNode
                        ,
                        <success>Inserted {count($newPages)} new page(s) into book "{$bookID}" ({count($allPages) - count($newPages)} already present, skipped).</success>
                    )
};

(: Removes all <page> entries for a book -- full reset before regenerating.
   Leaves the module[@type="pages"] element itself in place (empty) rather
   than removing it, so insert-pages-into-book() can just insert into it. :)
declare function libmgr:remove-pages-from-book(
    $libraryID as xs:string,
    $bookID as xs:string
) as element() {
    let $bookNode := libmgr:get-book-doc($libraryID, $bookID)
    return
        if (not($bookNode)) then
            <error>No book found with id "{$bookID}" in library "{$libraryID}".</error>
        else
            let $pagesModule := $bookNode/module[@type="pages"]
            return
                if (not($pagesModule) or empty($pagesModule/page)) then
                    <skipped book="{$bookID}">No pages to remove</skipped>
                else
                    let $count := count($pagesModule/page)
                    return (
                        update delete $pagesModule/page,
                        <removed book="{$bookID}">Removed {$count} page(s)</removed>
                    )
};
