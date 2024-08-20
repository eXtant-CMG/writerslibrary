# Documentation

## Getting Started

Adding data to this app is mainly done in the XML file `library.xml`, and some configuration can be customized in `config.xml`. The files can be found here:

- `/db/apps/writerslibrarary/data/library/library.xml`
- `/db/apps/writerslibrarary/data/library/config.xml`

### Editing the XML files in eXide
You can open and edit these two XML files in `eXide`, eXist-db's code editor. To open eXide, go to the eXist-db **Dashboard** and click on the eXide icon.

To edit `library.xml` and `config.xml`, you’ll need to log in as an **administrator** (dba). To do this, click on the “Login” button in the top right corner of the eXide window and enter the admin username and password you provided during the eXist-db installation.

### Editing the XML files in oXygen
In addition to eXide, you can also edit the XML files in an eXist-db using **oXygen XML Editor**. oXygen is a powerful XML editor that provides many advanced features for working with XML data.

To edit the files in oXygen, you’ll need to connect oXygen to your eXist-db. This can be done by creating a new connection to the eXist-db server in the oXygen “Data Source Explorer” view. Once the connection is established, you’ll be able to browse and edit the files in your eXist-db directly from oXygen.

For more detailed instructions on how to connect oXygen to an eXist-db and edit files, see [this page in the oXygen documentation](https://www.oxygenxml.com/doc/versions/25.1/ug-editor/topics/configure-exist-datasource.html).

## Configuration: config.xml
As a first step in configuring the app to represent a particular collection of books, an admin can change the title and subtitle in `config.xml`.

    <title>Bibundina</title>
    <subtitle>A Writer's Library App</subtitle>

The subtitle field can of course be left blank.

As the user manual states, the upper horizontal navigation bar of the writer's library app serves as a browsing tool that can sort alphabetically among **authors**, **titles** and **places** of publication. The number of items retrieved is shown under each letter to give an idea of how relevant or representative a specific search query is. It is also possible to sort the library chronologically according to the **date** of publication and to apply filters to the book collection to only display books with an **inscription**, with **reading traces**, or with **marginalia**.

In case one or more of these options are not relevant to a collection of books (for instance when they contain no marginalia), items in the navigation can be easily removed by deleting (or commenting out) the `<sortBy>` element in `config.xml` that generates them. This, for instance, is the `<sortBy>` element that generates the "Marginalia only" option:

    <!-- Marginalia only -->
    <sortBy id="Marginalia" browseCategory="Alphabet">
        <label>Marginalia only</label>
        <rangeQuery>
            <fields>("library-book-Marginalia","library-book-Author")</fields>
            <operators>("contains","starts-with")</operators>
            <keys>"*",$currentBrowseValue</keys>
        </rangeQuery>
        <orderBy>Author</orderBy>
        <breadcrumbPhrase>the presence of marginalia</breadcrumbPhrase>
    </sortBy>

When working with books published in other date ranges than the ones currently offered, the admin can add or modify date ranges using these syntax conventions:

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
    </browseBy>

Advanced users who are familiar with search indexes and range queries can add an index in `collection.xconf` and phrase the range index in this XML syntax to add another sorting option to the interface.

## Encoding Schema: library.xml

In `library.xml`, add book entries following the custom encoding scheme that is documented in the section “Encoding manual”.

The root element is `<book>`, which has attributes `type` and `id`. The `type` attribute specifies the type of book (`EL` (extant library) `VL` (virtual entry), while the `id` attribute provides a unique identifier for the book.

	<book id="ARA-LIB" type="EL">
		<!-- Module elements go here -->
	</book>

### Module 1: Bibliographic Info
This XML schema is used to encode a book's bibliographical data. 

	<module type="bibl">
        <title sort=""/>
        <subtitle/>
        <type></type>
        <author sort="">
            <firstname/>
            <lastname/>
        </author>
        <volume/>
        <series/>
        <edition/>
        <editor/>
        <place/>
        <publisher/>
        <date/>
        <generalnote/>
        <location/>
        <IIIF>
            <IIIFmanifest/>
            <IIIFviewer/>
        </IIIF>
	</module>

Within the `<book>` element is a `<module>` element with an attribute `type` set to `"bibl"`. This element contains the bibliographical information for the book. Except for `<title>` and `<author>`, all elements are optional.

The `<title>` element contains the title of the book. The `sort` attribute can be used to specify a sort key for the title. The novel *The Wind in the Willows*, for instance, can be encoded to be sorted under "W" by supplying "Wind in the Willows" in the sort attribute.

The `<type>` element specifies the type of publication, such as "Monograph", "Journal", "Collection of Essays", "Collection of Stories", "Dictionary", "Sheet Music", "Manuscript", or "Typescript".

The `<author>` element contains information about the author of the book. Within the `<author>` element are `<firstname>` and `<lastname>` elements that contain the author's first and last names. The `sort` attribute can be used to specify a sort key for the author's name. "John O'Brien" can be sorted under "B" by supplying "Brien" in the sort attribute. Please note that the sort attribute should only contain regular letters, so in the sort attribute the last name "Dupré" should be encoded as `sort="Dupre"` or `sort="Dupr&#233;"`. The value of the sort attribute is never visualized in the interface, it is only used to correctly sort authors and titles.

If a book has **no author**, the `<author>` element can be left empty, and the sort attribute can be used to make the book appear in the author lists on the basis of its title or editor:

	<Title sort="Everyday Spanish">Everyday Spanish</Title>
	<Author sort="Collier"><firstname/><lastname/></Author>
	<Editor>L.D. Collier</Editor> 

If a book has **multiple authors**, each author should be enclosed in their own `<author>` element:

	<author sort="Smith">
		<firstname>John</firstname>
		<lastname>Smith</lastname>
	</author>
	<author>
		<firstname>Jane</firstname>
		<lastname>Doe</lastname>
	</author>

The `<volume/>`, `<series/>`, `<edition/>`, `<editor/>`, `<place>`, `<publisher>`, `<date>`, and `<generalnote/>` elements can contain information about the volume number, series, edition, editor, place of publication, publisher, date of publication, and any general notes about the book, respectively.

The `<location>` element specifies the current location of the book.

The `<IIIF>` element contains information about the International Image Interoperability Framework (IIIF) resources associated with the book. Within this element are `<IIIFmanifest>` and `<IIIFviewer>` elements that contain the URLs for the IIIF manifest and a stable identifier where the images can be seen in a IIIF viewer.

	<IIIF>
		<IIIFmanifest>http://example.com/manifest.json</IIIFmanifest>
		<IIIFviewer>http://example.com/viewer</IIIFviewer>
	</IIIF>

### Module 2: Proprietary History

The proprietary history module is used to encode the ownership and provenance details of a book.

	<module type="prop">
	    <type>received</type>
	    <dateofacquisition>1934-05-15</dateofacquisition>
	    <origin>Here you can describe the provenance of a book.</origin>
	    <dedication>This is a sample dedication.</dedication>
	</module>


Within the `<book>` element, the `<module>` element with an attribute `type` set to `"prop"` contains the proprietary history of the book. This module provides information about how and when the book was acquired, its origin, and any dedications associated with it.

The `<type>` element specifies the nature of the acquisition. Common values might include:

- received
- purchased
- gifted
- inherited

The `<dateofacquisition>` element contains the date when the book was acquired. This should be formatted in a standard date format (e.g., YYYY-MM-DD).

The `<origin>` element provides a detailed description of the book's provenance, such as previous owners, acquisition source, or historical context.

The `<dedication>` element includes any dedications written in or associated with the book. This could be a personal note from the giver or an inscription found within the book.

### Module 3: Pages and Reading Traces

The Pages and Reading Traces module is used to encode information about individual pages of a book and any reading traces or annotations found on those pages.


	<module type="pages">
	    <page>
	        <pagenumber>cover</pagenumber>
	        <facsimile>DAR-ORI/cover.jpg</facsimile>
	    </page>
	    <page>
	        <pagenumber>tp</pagenumber>
	        <facsimile>DAR-ORI/tp.jpg</facsimile>
	    </page>
	    <page>
	        <pagenumber>56</pagenumber>
	        <facsimile>DAR-ORI/56.jpg</facsimile>
	        <zone>
	            <number>1</number>
	            <facsimile>DAR-ORI/zones/56(1).jpg</facsimile>
	            <type>marginalia</type>
	            <position>880</position>
	            <rn>
	                <transcription>
	                    <m>woodpecker</m> / <u>How have all those exquisite adaptations of / one part of the organisation to another part, and to the / conditions of life, and of one distinct organic being to / another being, been perfected?</u>
	                </transcription>
	                <writingtool>Red ink</writingtool>
	                <extracts>But the mere existence of individual / variability and of some few well-marked varieties, / though necessary as the foundation for the work, helps / us but little in understanding how species arise in / nature. How have all those exquisite adaptations of / one part of the organisation to another part, and to the / conditions of life, and of one distinct organic being to / another being, been perfected? We see these beautiful / co-adaptations most plainly in the woodpecker and
	                </extracts>
	            </rn>
	        </zone>
	    </page>
	</module>


The `<module>` element with the attribute `type` set to `"pages"` contains the details of individual pages within the book. Each `<page>` element includes a `<pagenumber>` and a `<facsimile>`. The `<pagenumber>` element specifies the page number or identifier (e.g., "cover", "tp" for title page), while the `<facsimile>` element provides a reference to an image file of the page, which can be a local file path or a IIIF image URL (see the "Including Images" section).

A page can have one or more reading traces, which are encoded within `<zone>` elements. Each `<zone>` element represents an individual reading trace, with several sub-elements to provide detailed information.

The `<number>` element within a `<zone>` specifies the order of the reading trace on the page, transcribed from top to bottom.

The `<facsimile>` element within a `<zone>` provides a reference to an image file of the specific reading trace.

A `<type>` element with the value "marginalia" **must** be added if the reading trace contains actual words written by the reader.

The `<position>` element indicates the position of the reading trace on the page, expressed in pixels down from the top of the image.

The `<rn>` element (reading note) contains the detailed content of the reading trace, including the transcription, writing tool, and the extract associated with the trace. The `<transcription>` element holds the transcribed text, with emphasis tags such as `<u>` for underlined text and `<m>` for marginalia notes. The `<writingtool>` element specifies the tool used to create the trace, such as "Red ink". The `<extracts>` element contains the text excerpts related to the reading trace.


## Including Images
The writer's library app accommodates **three** different ways of incorporating images and the sample data and documentation in the app will demonstrate the three ways. Images can either be stored **within the app** itself (*which we do not recommend*); images can be loaded into the app from a **static folder on the same server**; and thirdly, images can be incorporated **via IIIF**. The methods can also be combined.

### Inside the app
The writer's library app contains sample book entries with images stored within the app.

The book with id `ARA-LIB`, for instance, contains `<page>` elements such as this in `<module type="pages">`:

	<page>
		<pagenumber>cover</pagenumber>
		<facsimile>ARA-LIB/cover.jpg</facsimile>
	</page>

The app is set to search for the contents of the `<facsimile>` element (e.g., `ARA-LIB/cover.jpg`) in the `db/writerslibrary/resources/images/library/` folder. Admins can add images to this folder via eXide by clicking `Manage` under the `File` menu and navigating to the folder in the DB Manager window (click the upload icon to upload files or folders). Images can also be added by dropping them into the folder when using the app via oXygen. The `<facsimile>` element must reference the correct image location and file name.

**Note**: Storing large amounts of images in the writer’s library app is **not recommended**. This is because eXist-db is not designed to host images and doing so can increase the file size of the app instance. To incorporate a substantial collection of images in the app, it is preferable to host them in a static folder on the server (or local machine), or on a IIIF server.

### From a Static Folder
The app can be set up to retrieve images from a folder outside of eXist-db. However, this requires configuration in both eXist-db and the server’s Apache httpd or Nginx when run on a server.

By following the outlined steps, the app can retrieve images from a static folder named `library-images` (on a computer or on a server).

In the file `db/writerslibrary/controller.xq` the following statement specifies that paths to images in `<facsimile>` elements must be preceded by `db/writerslibrary/resources/images/library/`:

	    else if (contains($exist:path, "/$library-images/")) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/resources/images/library/{substring-after($exist:path, '/$library-images/')}">
                <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
            </forward>
        </dispatch>

This must be changed to the static folder outside of eXist-db:

	    else if (contains($exist:path, "/$library-images/")) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="/library-images/{substring-after($exist:path, '/$library-images/')}">
                <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
            </forward>
        </dispatch>

eXist-db uses **Jetty** as its web server. Jetty is an open-source project providing an HTTP server, HTTP client, and `javax.servlet` container. To access images from a static folder outside of eXist-db within the app, a configuration file must be created for Jetty. This file specifies the folder from which Jetty should serve resources when running. The following can be used as a template for the file:

	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE Configure PUBLIC "-//Jetty//Configure//EN" "http://www.eclipse.org/jetty/configure_9_0.dtd">
	<Configure class="org.eclipse.jetty.server.handler.ContextHandler">
		  <Set name="contextPath">/library-images</Set>
		  <Set name="handler">
		    <New class="org.eclipse.jetty.server.handler.ResourceHandler">
	         <Set name="resourceBase">/home/library-images</Set>
	         <Set name="directoriesListed">false</Set>
   		   </New>
	      </Set>
	</Configure>

This XML configuration file is used It does this by configuring a `Jetty ContextHandler` to serve resources from the specified folder. 

This configuration file should be placed in the `$EXIST_HOME/etc/jetty` directory, where `$EXIST_HOME` is the root directory of your eXist-db installation. The file should have a .xml extension and its name should start with jetty. For example, you could name it `jetty-library-images.xml`.

Here is a brief explanation of what each part of the configuration does:

- `<Set name="contextPath">/library-images</Set>`: This line sets the context path for the ContextHandler to /library-images. This means that resources served by this ContextHandler will be available at URLs starting with /library-images.
- `<Set name="resourceBase">/home/library-images</Set>`: This line sets the resourceBase property of the ResourceHandler to `/home/library-images`. This specifies the folder on the file system from which resources will be served.

After placing this configuration file in the correct location, you will need to **restart eXist-db** for the changes to take effect. 

The configuration of the webserver will also need to include a reference to the image folder. If you have chosen to proxy eXist-db behind a Web Server (as explained [here](http://exist-db.org/exist/apps/doc/production_web_proxying.xml?field=all&id=D3.17.15#D3.17.15) in the eXist-db documentation), add the following lines to your `httpd.conf` in **Apache httpd**:

	ProxyPass           /library-images http://localhost:8080/library-images
	ProxyPassReverse    /library-images http://localhost:8080/library-images

In an **Nginx** configuration, add:

	location /library-images {
	    proxy_pass http://localhost:8080/library-images;
	}

Once eXist-db and Apache httpd or Nginx have been restarted, images from the `/home/library-images` folder on the server should be available at URLs starting with `/library-images`, to which `controller.xq` will then append the references given in the `<facsimile>` elements. In this way, `<facsimile>ARA-LIB/cover.jpg</facsimile>` will correctly refer to an image stored as `/home/library-images/ARA-LIB/cover.jpg`.


### Via IIIF
If the `<facsimile>` element begins with “https”, the app will directly load the image from the specified URL. In this example:

	<page>
		<pagenumber>1</pagenumber>
     <facsimile>https://iiif.wellcomecollection.org/image/b18035723_0001.JP2/full/680,/0/default.jpg</facsimile>
	</page>

the `<facsimile>` element contains a IIIF-compliant image link that displays the image at a width of **680 pixels**, which is the width used in the app’s interface.

The app provides an **Admin tool** to import image links from a IIIF manifest (see further).

The IIIF method of including images can be easily combined with one of the two previously described methods of bringing images into the app.

## Admin Tools

When you are logged into eXist-db (via the dashboard or via eXide), a tab "Admin Tools" appears on the home page. There, admins can make use of three tools meant to facilitate the creation of a collection of book entries.  Two of the three tools are especially helpful to people incorporating images via IIIF. The three tools are:

- Create a new book entry
- Import image links from a IIIF manifest
- Zone coordinates tool (for IIIF images only)

### Create a New Book Entry

This tool helps you generate the XML for a new book entry. You can copy the result to your clipboard and paste it into `library.xml`.

**Note**: This tool doesn’t automatically insert or modify book elements in the publication interface. You must manually copy the generated XML into `library.xml`.

First, choose a valid and unique ID that starts with a letter and contains only letters and numbers. Then enter the main bibliographic information and (optionally) import images from a IIIF manifest. This feature can also be used separately (see below).

### Import image links from a IIIF manifest

This tool extracts image links from a IIIF manifest and formats them into the correct XML schema (`<module type="pages">`). You can then paste the result directly into a `<book>` entry in your library collection. However, due to structural differences in IIIF manifests, extraction may not always be successful.

For every image declared in the manifest, the tool will create the following XML:

	<page>
		<pagenumber>1</pagenumber>
     <facsimile>https://iiif.wellcomecollection.org/image/b18035723_0001.JP2/full/680,/0/default.jpg</facsimile>
	</page>

Images are numbered consecutively in the `<pagenumber>` element. The `<facsimile>` element contains a IIIF compliant image link that renders the image at a width of **680 pixels**.

### Zone Coordinates Tool

This tool allows admins to draw a rectangular zone around a reading trace on a IIIF image. The tool generates a `<zone>` element, containing the correct coordinates for the zone, which can be pasted into a `<page>` element in `library.xml`. After making a selection, click the `preview zone image` button to magnify it.

For every zone selection, the tool will create the following XML:

	<!-- zone -->
	<zone>
	   <number>1</number>
	   <facsimile>https://iiif.wellcomecollection.org/image/b18035723_0001.JP2/661,1118,1285,1012/500,/0/default.jpg</facsimile>
	   <position>296</position>
	   <rn>
	     <transcription></transcription>
	     <writingtool></writingtool>
	     <extracts></extracts>
	   </rn>
	   <type>marginalia</type>
	</zone>



## Structure of the App

- `collection.xconf`: This file is used to configure collection-specific settings, such as indexing options and triggers.
- `controller.xq`: This file is used to control the flow of requests and responses within the app.
- `data/library/config.xml`: This file contains configuration settings, such as the title of the app and the browsing and sorting options.
- `data/library/library.xml`: The main library database file.
- `modules/`: This folder contains XQuery modules, which contain the actual application code.
- `modules/library-book-view.xql`: This module contains code that creates the book view.
- `modules/library-browse.xql`: This module contains code for browsing the library.
- `modules/library-functions.xql`: This module contains general-purpose functions used by `library-browse.xql` and `library-book-view.xql`.
- `modules/search.xql`: This module contains code for searching within the app.
- `modules/admin-tools.xql`: This module likely contains code for administrative tools within the app.
- `modules/import-iiif.xql`: This module likely contains code for importing data using the IIIF (International Image Interoperability Framework) protocol.
- `resources/`: This folder contains resources such as CSS files, images, JavaScript files, and XSLT files.
- `templates/`: This folder contains HTML templates used to generate pages within the app.
