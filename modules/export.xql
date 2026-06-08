xquery version "3.1";
(:
 : export.xql
 : Run directly from eXide (execute with F8).
 : Output: /db/apps/writerslibrary/static/{libraryID}/
 :)
 
import module namespace config = "http://exist-db.org/apps/writerslibrary/config"
    at "/db/apps/writerslibrary/modules/config.xqm";
import module namespace si = "http://bibundina.org/ns/search-index"
    at "/db/apps/writerslibrary/modules/search-index.xqm";
import module namespace http = "http://expath.org/ns/http-client";
import module namespace request="http://exist-db.org/xquery/request";
declare namespace xmldb      = "http://exist-db.org/xquery/xmldb";
declare namespace util = "http://exist-db.org/xquery/util";


(: ============================================================
   CONFIGURATION
   ============================================================ :)
   
declare variable $httpUser := $config:export-user;
declare variable $httpPass := $config:export-pass;

(: Library to export :)
declare variable $libraryID as xs:string external := "sample-library";

(: Output root collection :)
declare variable $staticRoot := "/db/apps/writerslibrary/static";


(: ============================================================
   HELPERS
   ============================================================ :)
   
(:  determine base url for http requests  :)   
declare function local:base-url() as xs:string {
    try {
        let $scheme := request:get-scheme()
        let $host   := request:get-server-name()
        let $port   := request:get-server-port()
        return
            if ($scheme and $host and $port) then
                let $defaultPort :=
                    ($scheme = "https" and $port = 443) or ($scheme = "http" and $port = 80)
                let $portPart := if ($defaultPort) then "" else ":" || $port
                return $scheme || "://" || $host || $portPart || "/exist/apps/writerslibrary"
            else
                $config:export-base-url
    } catch * {
        $config:export-base-url
    }
};
   
(: Ensure a collection exists, creating it and any missing parents :)
declare function local:ensure-collection($path as xs:string) as xs:string {
    let $parts  := tokenize($path, "/")[. ne ""]
    let $unused := fold-left($parts, "", function($acc, $part) {
        let $current := $acc || "/" || $part
        return
            if (xmldb:collection-available($current)) then $current
            else (xmldb:create-collection($acc, $part), $current)[last()]
    })
    return $path
};

(: Copy all resources + subcollections from $src to $dst (creates $dst if needed).
   Overwrites existing resources with the same name. :)
declare function local:sync-collection(
    $src as xs:string,
    $dst as xs:string
) as empty-sequence() {
    let $dstCreated := local:ensure-collection($dst)
    (: Copy all resources :)
    let $copyFiles :=
        for $f in xmldb:get-child-resources($src)
        return xmldb:copy-resource($src, $f, $dstCreated, $f)
    (: Recurse into subcollections :)
    let $copySub :=
        for $c in xmldb:get-child-collections($src)
        let $srcChild := $src || "/" || $c
        let $dstChild := $dstCreated || "/" || $c
        return local:sync-collection($srcChild, $dstChild)
    return ()
};

(: Rewrite internal links and resource paths in exported HTML :)
declare function local:rewrite-html(
    $html as xs:string, 
    $bookID as xs:string,
    $libraryID as xs:string
) as xs:string {
    (: $resources/ → ../resources/ :)
    let $s := replace($html, '\$resources/', '../resources/')
    (: $library-images/ → ../resources/images/{libraryID}/ :)
    let $s := replace($s, '\$library-images/', '../resources/images/' || $libraryID || '/')
    (: browse links stay as-is: ../browse/Author-A.html already correct :)
    (: remove admin tools section (not relevant in static export) :)
    let $s := replace($s, '<span class="admin-tools-open-in-zone-tool">.*?</span>', '', 's')
    (: remove manage library collections button :)
    let $s := replace($s,
        '<button[^>]*manage-button[^>]*>.*?</button>', '', 's')
    let $s := replace($s, '\.\./\.\./[^/]+/search/', '../search/')
    return $s
};

declare function local:rewrite-search-html(
    $html as xs:string,
    $libraryID as xs:string
) as xs:string {
    let $s := replace($html, '\$resources/', '../resources/')
    let $s := replace($s, '\$library-images/', '../resources/images/' || $libraryID || '/')
    let $s := replace($s, '<span class="admin-tools-open-in-zone-tool">.*?</span>', '', 's')
    let $s := replace($s, '<button[^>]*manage-button[^>]*>.*?</button>', '', 's')
    let $s := replace($s, '\.\./\.\./[^/]+/search/', '../search/')
    return $s
};

(: Process a single book's images into manifest XML :)
declare function local:process-book-images(
    $bookID as xs:string,
    $bookDoc as document-node(),
    $libraryID as xs:string,
    $baseUrl as xs:string
) as element(book)? {
    let $pagesModule := $bookDoc//module[@type eq "pages"]
    return
        if ($pagesModule) then
            <book id="{$bookID}">
                <images>
                    {
                        (: Page images :)
                        for $page in $pagesModule/page
                        let $facs := $page/facsimile/text()
                        return
                            if (starts-with($facs, "https://") or starts-with($facs, "http://")) then
                                <image type="page" source="iiif">
                                    <pagenumber>{$page/pagenumber/text()}</pagenumber>
                                    <url>{$facs}</url>
                                </image>
                            else
                                <image type="page" source="local">
                                    <pagenumber>{$page/pagenumber/text()}</pagenumber>
                                    <url>{$baseUrl}/{$libraryID}/$library-images/{$facs}</url>
                                    <local-path>resources/images/{$facs}</local-path>
                                </image>
                    }
                    {
                        (: Zone images (reading traces) :)
                        for $zone in $pagesModule/page/zone
                        let $facs := $zone/facsimile/text()
                        let $pagenum := $zone/../pagenumber/text()
                        let $zonenum := $zone/number/text()
                        return
                            if (starts-with($facs, "https://") or starts-with($facs, "http://")) then
                                <image type="zone" source="iiif">
                                    <pagenumber>{$pagenum}</pagenumber>
                                    <zone>{$zonenum}</zone>
                                    <url>{$facs}</url>
                                </image>
                            else
                                <image type="zone" source="local">
                                    <pagenumber>{$pagenum}</pagenumber>
                                    <zone>{$zonenum}</zone>
                                    <url>{$baseUrl}/{$libraryID}/$library-images/{$facs}</url>
                                    <local-path>resources/images/{$facs}</local-path>
                                </image>
                    }
                </images>
            </book>
        else ()
};

(: Generate manifest incrementally in chunks to handle large libraries :)
declare function local:generate-manifest-incremental(
    $libraryID as xs:string,
    $booksCol as xs:string,
    $baseUrl as xs:string,
    $outputPath as xs:string
) as xs:string {
    let $bookFiles := xmldb:get-child-resources($booksCol)[ends-with(., '.xml')]
    let $totalBooks := count($bookFiles)
    
    (: Create initial manifest with header :)
    let $header := 
        <manifest>
            <libraryID>{$libraryID}</libraryID>
            <generated>{current-dateTime()}</generated>
            <total-books>{$totalBooks}</total-books>
        </manifest>
    
    let $stored := xmldb:store($outputPath, "image-manifest.xml", $header, "application/xml")
    
    (: Process books in chunks of 100 to avoid memory issues :)
    let $chunkSize := 100
    let $numChunks := xs:integer(ceiling($totalBooks div $chunkSize))
    
    let $processChunks :=
        for $i in (0 to $numChunks - 1)
        let $startPos := $i * $chunkSize + 1
        let $chunk := subsequence($bookFiles, $startPos, $chunkSize)
        
        (: Process this chunk of books :)
        let $bookNodes :=
            for $filename in $chunk
            let $bookID := substring-before($filename, '.xml')
            let $bookDoc := doc($booksCol || '/' || $filename)
            return local:process-book-images($bookID, $bookDoc, $libraryID, $baseUrl)
        
        (: Append chunk to manifest :)
        let $manifest := doc($outputPath || "/image-manifest.xml")
        let $updated := 
                if (count($bookNodes) gt 0) then
                    let $manifest := doc($outputPath || "/image-manifest.xml")
                    return update insert $bookNodes into $manifest/manifest
                else ()
        
        return count($bookNodes)
    
    return $outputPath || "/image-manifest.xml"
};

(: Generate list of all browse page URLs from config.xml :)
declare function local:enumerate-browse-urls(
    $libraryID as xs:string,
    $configDoc as document-node(),
    $baseUrl as xs:string
) as xs:string* {
    let $sorting := $configDoc//sorting/sortBy
    let $browsing := $configDoc//browsing/browseBy
    
    (: For each sortBy dimension, cross with its browse category values :)
    for $sortBy in $sorting
    let $sortByID := $sortBy/@id/string()
    let $browseCategory := $sortBy/@browseCategory/string()
    let $browseValues := $browsing[@id eq $browseCategory]/browse/value/text()
    
    (: Generate URL for each combination :)
    for $value in $browseValues
    return $baseUrl || '/' || $libraryID || '/browse/' || $sortByID || '-' || $value || '.html?export=true'
};

(: Rewrite browse page HTML (similar to book rewrite but for browse context) :)
declare function local:rewrite-browse-html(
    $html as xs:string,
    $libraryID as xs:string
) as xs:string {
    let $s := replace($html, '\$resources/', '../resources/')
    let $s := replace($s, '\$library-images/', '../resources/images/' || $libraryID || '/')
    (: Book links: ../DAR-ORI/index.html stays as-is :)
    let $s := replace($s, '<span class="admin-tools-open-in-zone-tool">.*?</span>', '', 's')
    let $s := replace($s, '<button[^>]*manage-button[^>]*>.*?</button>', '', 's')
    let $s := replace($s, '\.\./\.\./[^/]+/search/', '../search/')
    (: TODO: When pagination is added, rewrite ?page=2 → -p2.html here :)
    return $s
};

(: Rewrite home page HTML :)
declare function local:rewrite-home-html(
    $html as xs:string,
    $libraryID as xs:string
) as xs:string {
    let $s := replace($html, '\$resources/', '../resources/')
    let $s := replace($s, '\$library-images/', '../resources/images/' || $libraryID || '/')
    (: Home stays at home/welcome.html, no rewriting needed :)
    (: Browse links: ../browse/Author-A.html stays as-is :)
    let $s := replace($s, '<span class="admin-tools-open-in-zone-tool">.*?</span>', '', 's')
    let $s := replace($s, '<button[^>]*manage-button[^>]*>.*?</button>', '', 's')
    let $s := replace($s, '\.\./\.\./[^/]+/search/', '../search/')
    return $s
};

(: Log progress message with timestamp :)
declare function local:log-progress($message as xs:string) as empty-sequence() {
    let $timestamp := format-dateTime(current-dateTime(), "[H01]:[m01]:[s01]")
    let $logged := util:log("INFO", "[EXPORT " || $timestamp || "] " || $message)
    return ()
};

declare function local:write-status(
    $libraryID as xs:string,
    $state as xs:string,
    $phase as xs:string,
    $message as xs:string,
    $pct as xs:integer,
    $booksOk as xs:integer,
    $booksFailed as xs:integer,
    $browseOk as xs:integer,
    $browseFailed as xs:integer
) as empty-sequence() {
    let $outCol := local:ensure-collection($staticRoot || '/' || $libraryID)
    let $status :=
        <export-status>
            <libraryID>{$libraryID}</libraryID>
            <state>{$state}</state>
            <phase>{$phase}</phase>
            <message>{$message}</message>
            <progress-pct>{$pct}</progress-pct>
            <updated>{current-dateTime()}</updated>
            <books-ok>{$booksOk}</books-ok>
            <books-failed>{$booksFailed}</books-failed>
            <browse-ok>{$browseOk}</browse-ok>
            <browse-failed>{$browseFailed}</browse-failed>
        </export-status>
    let $stored := xmldb:store($outCol, "export-status.xml", $status, "application/xml")
    let $logged := local:log-progress($message)
    return ()
};

(: ============================================================
   MAIN
   ============================================================ :)
let $libraryID :=
    if (doc-available("/db/apps/writerslibrary/static/pending-export.xml")) then
        doc("/db/apps/writerslibrary/static/pending-export.xml")/pending-export/libraryID/string()
    else
        $libraryID  (: fall back to the external default when running manually from eXide :)
let $startTime   := util:system-time()
let $logStart    := local:write-status($libraryID, "running", "init",
                        "Export started for library: " || $libraryID,
                        0, 0, 0, 0, 0)
let $baseUrl     := local:base-url()
let $booksCol    := $config:data-root || '/' || $libraryID || '/books'
let $bookFiles   := xmldb:get-child-resources($booksCol)[ends-with(., '.xml')]
let $totalBooks  := count($bookFiles)

let $outLibCol   := local:ensure-collection($staticRoot || '/' || $libraryID)

(: COPY ASSETS :)
let $logAssets   := local:write-status($libraryID, "running", "assets",
                        "Copying static assets...",
                        5, 0, 0, 0, 0)
let $srcResRoot := "/db/apps/writerslibrary/resources"
let $dstResRoot := local:ensure-collection($outLibCol || "/resources")
let $copyAssets :=
(
    if (xmldb:collection-available($srcResRoot || "/css")) then
        local:sync-collection($srcResRoot || "/css", $dstResRoot || "/css")
    else (),
    if (xmldb:collection-available($srcResRoot || "/scripts")) then
        local:sync-collection($srcResRoot || "/scripts", $dstResRoot || "/scripts")
    else (),
    if (xmldb:collection-available($srcResRoot || "/fonts")) then
        local:sync-collection($srcResRoot || "/fonts", $dstResRoot || "/fonts")
    else (),
    if (xmldb:collection-available($srcResRoot || "/images")) then
        local:sync-collection($srcResRoot || "/images", $dstResRoot || "/images")
    else ()
)

(: BOOKS :)
let $logBooksStart := local:write-status($libraryID, "running", "books",
                        "Starting book export (" || $totalBooks || " books)...",
                        10, 0, 0, 0, 0)
let $results :=
    for $filename at $pos in $bookFiles
    let $bookID  := substring-before($filename, '.xml')
    let $logProgress :=
        if ($pos mod 100 eq 0) then
            local:write-status($libraryID, "running", "books",
                "Exported " || $pos || "/" || $totalBooks || " books",
                (: pct: books phase is 10-50% :)
                xs:integer(10 + ($pos div $totalBooks) * 40),
                $pos, 0, 0, 0)
        else ()
    let $throttle := if ($pos mod 10 eq 0) then util:wait(50) else ()
    let $url     := $baseUrl || '/' || $libraryID || '/' || $bookID || '/index.html?export=true'
    let $bookCol := local:ensure-collection($outLibCol || '/' || $bookID)
    let $response :=
        http:send-request(
            <http:request method="GET"
                          href="{$url}"
                          username="{$httpUser}"
                          password="{$httpPass}"
                          auth-method="basic"
                          send-authorization="true"/>
        )
    let $meta       := $response[1]
    let $statusCode := xs:integer($meta/@status)
    let $location   := string($meta/http:header[@name="Location"]/@value)
    let $rawHtml    := serialize($response[2], map { "method": "html" })
    return
        if ($statusCode eq 200) then
            let $rewritten := local:rewrite-html($rawHtml, $bookID, $libraryID)
            let $binary    := util:string-to-binary($rewritten, "UTF-8")
            let $stored    := xmldb:store($bookCol, "index.html",
                                 $binary, "application/octet-stream")
            return <book id="{$bookID}" status="ok" url="{$url}" location="{$location}"/>
        else
            <book id="{$bookID}" status="error"
                  statusCode="{$statusCode}" url="{$url}" location="{$location}"/>

let $booksOk     := count($results[@status eq 'ok'])
let $booksFailed := count($results[@status eq 'error'])
let $logBooksDone := local:write-status($libraryID, "running", "browse",
                        "Books done (" || $booksOk || " ok, " || $booksFailed || " failed). Starting browse pages...",
                        50, $booksOk, $booksFailed, 0, 0)

(: BROWSE :)
let $configDoc   := doc($config:data-root || '/' || $libraryID || '/config.xml')
let $browseUrls  := local:enumerate-browse-urls($libraryID, $configDoc, $baseUrl)
let $totalBrowse := count($browseUrls)
let $browseDir   := local:ensure-collection($outLibCol || "/browse")
let $browseResults :=
    for $url at $pos in $browseUrls
    let $throttle  := if ($pos mod 10 eq 0) then util:wait(50) else ()
    let $filename  := tokenize(tokenize($url, '/')[last()], '\?')[1]
    let $response :=
        http:send-request(
            <http:request method="GET"
                          href="{$url}"
                          username="{$httpUser}"
                          password="{$httpPass}"
                          auth-method="basic"
                          send-authorization="true"/>
        )
    let $statusCode := xs:integer($response[1]/@status)
    let $rawHtml := serialize($response[2], map { "method": "html" })
    return
        if ($statusCode eq 200) then
            let $rewritten := local:rewrite-browse-html($rawHtml, $libraryID)
            let $binary := util:string-to-binary($rewritten, "UTF-8")
            let $stored := xmldb:store($browseDir, $filename,
                             $binary, "application/octet-stream")
            return <browse-page filename="{$filename}" status="ok" url="{$url}"/>
        else
            <browse-page filename="{$filename}" status="error"
                  statusCode="{$statusCode}" url="{$url}"/>

let $browseOk     := count($browseResults[@status eq 'ok'])
let $browseFailed := count($browseResults[@status eq 'error'])
let $logBrowseDone := local:write-status($libraryID, "running", "home",
                        "Browse done (" || $browseOk || " ok, " || $browseFailed || " failed). Exporting home page...",
                        65, $booksOk, $booksFailed, $browseOk, $browseFailed)

(: HOME :)
let $homeDir := local:ensure-collection($outLibCol || "/home")
let $homeUrl := $baseUrl || '/' || $libraryID || '/home/welcome.html?export=true'
let $homeResponse :=
    http:send-request(
        <http:request method="GET"
                      href="{$homeUrl}"
                      username="{$httpUser}"
                      password="{$httpPass}"
                      auth-method="basic"
                      send-authorization="true"/>
    )
let $homeStatusCode := xs:integer($homeResponse[1]/@status)
let $homeExport :=
    if ($homeStatusCode eq 200) then
        let $homeHtml     := serialize($homeResponse[2], map { "method": "html" })
        let $homeRewritten := local:rewrite-home-html($homeHtml, $libraryID)
        let $homeBinary   := util:string-to-binary($homeRewritten, "UTF-8")
        let $homeStored   := xmldb:store($homeDir, "welcome.html",
                               $homeBinary, "application/octet-stream")
        return "ok"
    else "error"

let $redirectHtml :=
    '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=home/welcome.html">
    <title>Redirecting...</title>
    <link rel="canonical" href="home/welcome.html">
</head>
<body>
    <p>Redirecting to <a href="home/welcome.html">home page</a>...</p>
</body>
</html>'
let $redirectBinary := util:string-to-binary($redirectHtml, "UTF-8")
let $redirectStored := xmldb:store($outLibCol, "index.html",
                         $redirectBinary, "application/octet-stream")

(: SEARCH PAGE :)
let $logSearch := local:write-status($libraryID, "running", "search",
                        "Exporting search page...",
                        68, $booksOk, $booksFailed, $browseOk, $browseFailed)
let $searchDir  := local:ensure-collection($outLibCol || "/search")
let $searchUrl  := $baseUrl || '/' || $libraryID || '/search/static.html?export=true'
let $searchResponse :=
    http:send-request(
        <http:request method="GET"
                      href="{$searchUrl}"
                      username="{$httpUser}"
                      password="{$httpPass}"
                      auth-method="basic"
                      send-authorization="true"/>
    )
let $searchStatusCode := xs:integer($searchResponse[1]/@status)
let $searchExport :=
    if ($searchStatusCode eq 200) then
        let $searchHtml     := serialize($searchResponse[2], map { "method": "html" })
        let $searchRewritten := local:rewrite-search-html($searchHtml, $libraryID)
        let $searchBinary   := util:string-to-binary($searchRewritten, "UTF-8")
        let $searchStored   := xmldb:store($searchDir, "index.html",
                                   $searchBinary, "application/octet-stream")
        return "ok"
    else "error"

(: SEARCH INDEX :)
let $logIndex := local:write-status($libraryID, "running", "index",
                        "Building search index...",
                        72, $booksOk, $booksFailed, $browseOk, $browseFailed)
let $indexBuilt := si:build-index($libraryID, $outLibCol)

(: PHASE 2 SCRIPTS :)
let $logPhase2 := local:write-status($libraryID, "running", "phase2",
                        "Writing Phase 2 scripts...",
                        70, $booksOk, $booksFailed, $browseOk, $browseFailed)


(: ============================================================
   WRITE PHASE 2 SCRIPTS TO EXPORT ROOT
   ============================================================ :)
   
let $logPhase2 := local:log-progress("Writing Phase 2 scripts...")

let $pythonScript := 
'#!/usr/bin/env python3
"""
Phase 2: Download IIIF images and rewrite HTML
Reads manifests/image-manifest.xml and downloads all external images.
Also rewrites staticSearch ssTitles JSON if present.
"""
import os
import re
import json
import glob
import hashlib
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlparse
import time

try:
    import requests
except ImportError:
    print("Error: requests library not installed")
    print("Run: pip install -r requirements.txt")
    exit(1)

DELAY = 0.5  # seconds between downloads (be nice to IIIF servers)


def download_image(url, output_path):
    """Download image from URL to output_path"""
    if output_path.exists():
        print(f"    (already exists, skipping)")
        return True

    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_bytes(response.content)
        time.sleep(DELAY)
        return True
    except Exception as e:
        print(f"  ERROR downloading {url}: {e}")
        return False


def url_to_filename(url):
    """Convert IIIF URL to local filename"""
    try:
        iiif_path = url.split("/image/")[1]
        parts = iiif_path.split("/")
        base = parts[0].replace(".JP2", "").replace(".jp2", "")
        if len(parts) > 1 and parts[1] != "full":
            coords = parts[1].replace(",", "-")
            return f"{base}_{coords}.jpg"
        return f"{base}.jpg"
    except Exception:
        hash_digest = hashlib.md5(url.encode()).hexdigest()[:16]
        return f"image_{hash_digest}.jpg"


def rewrite_titles_json(library_id, url_map):
    """Rewrite IIIF URLs in ssTitles JSON to local paths.
    Silently skips if staticSearch is not present in the export."""

    ss_dir = Path("staticSearch")
    if not ss_dir.exists():
        print("No staticSearch folder found, skipping titles rewrite")
        return

    titles_files = list(ss_dir.glob("ssTitles_*.json"))
    if not titles_files:
        print("No ssTitles JSON found in staticSearch/, skipping")
        return

    for titles_path in titles_files:
        print(f"Rewriting {titles_path}...")
        try:
            with open(titles_path, "r", encoding="utf-8") as f:
                titles = json.load(f)

            changed = False
            for doc_uri, arr in titles.items():
                if len(arr) >= 2:
                    cover = arr[1]
                    if cover in url_map:
                        arr[1] = "../resources/images/" + url_map[cover]
                        changed = True

            if changed:
                with open(titles_path, "w", encoding="utf-8") as f:
                    json.dump(titles, f, ensure_ascii=False)
                print(f"  Rewrote IIIF cover URLs in {titles_path}")
            else:
                print(f"  No IIIF URLs found in {titles_path}")

        except Exception as e:
            print(f"  Warning: Could not process {titles_path}: {e}")


def main():
    print("=" * 70)
    print("Phase 2: Download IIIF Images")
    print("=" * 70)
    print()

    manifest_path = Path("manifests/image-manifest.xml")
    if not manifest_path.exists():
        print("Error: manifests/image-manifest.xml not found")
        print("Make sure you are running this script from the export root directory")
        exit(1)

    print("Reading manifest...")
    tree = ET.parse(manifest_path)
    root = tree.getroot()

    library_id = root.find("libraryID").text
    print(f"Library: {library_id}")
    print()

    iiif_images = []
    for book in root.findall("book"):
        book_id = book.get("id")
        for img in book.findall(".//image[@source=\"iiif\"]"):
            img_type = img.get("type")
            url = img.find("url").text
            pagenumber = img.find("pagenumber").text
            zone = img.find("zone").text if img.find("zone") is not None else None
            filename = url_to_filename(url)
            iiif_images.append({
                "url": url,
                "filename": filename,
                "book_id": book_id,
                "type": img_type,
                "page": pagenumber,
                "zone": zone
            })

    if not iiif_images:
        print("No IIIF images found in manifest - nothing to download")
        return

    print(f"Found {len(iiif_images)} IIIF images to download")

    page_count = sum(1 for img in iiif_images if img["type"] == "page")
    zone_count = sum(1 for img in iiif_images if img["type"] == "zone")
    print(f"  - {page_count} page images")
    print(f"  - {zone_count} zone images (reading traces)")

    est_time = len(iiif_images) * DELAY / 60
    print(f"Estimated download time: ~{est_time:.1f} minutes")
    print()

    print("Downloading images...")
    print("-" * 70)

    success = 0
    failed = []

    for i, img in enumerate(iiif_images, 1):
        label = f"{img[&apos;book_id&apos;]}"
        if img["type"] == "page":
            label += f" page {img[&apos;page&apos;]}"
        else:
            label += f" page {img[&apos;page&apos;]} zone {img[&apos;zone&apos;]}"

        print(f"[{i}/{len(iiif_images)}] {label}")
        print(f"    {img[&apos;filename&apos;]}")

        book_dir = Path(f"resources/images/{library_id}/{img[&apos;book_id&apos;]}")
        output_path = book_dir / img["filename"]

        if download_image(img["url"], output_path):
            success += 1
        else:
            failed.append((img["book_id"], img["url"]))

    print("-" * 70)
    print()
    print(f"Downloaded {success}/{len(iiif_images)} images")

    if failed:
        print(f"Failed: {len(failed)} images")
        print("Failed downloads:")
        for book_id, url in failed:
            print(f"  - {book_id}: {url}")
        print()

    # Build url_map: full IIIF URL → {libraryId}/{bookId}/{filename}
    url_map = {}
    for img in iiif_images:
        local_path = f"{library_id}/{img[&apos;book_id&apos;]}/{img[&apos;filename&apos;]}"
        url_map[img["url"]] = local_path

    print()
    print("=" * 70)
    print("Rewriting HTML files to use local images...")
    print("=" * 70)
    print()

    html_files = []
    for pattern in ["*.html", "*/*.html", "*/*/*.html"]:
        html_files.extend(Path(".").glob(pattern))

    print(f"Found {len(html_files)} HTML files")

    rewritten = 0
    files_changed = []

    for html_file in html_files:
        try:
            html = html_file.read_text(encoding="utf-8")
            original = html

            depth = len(html_file.parts) - 1
            rel_prefix = "../" * depth + "resources/images/"

            for url, local_path in url_map.items():
                full_local_path = rel_prefix + local_path
                html = html.replace(url, full_local_path)

            if html != original:
                html_file.write_text(html, encoding="utf-8")
                rewritten += 1
                files_changed.append(str(html_file))
        except Exception as e:
            print(f"  Warning: Could not process {html_file}: {e}")

    print(f"Rewrote {rewritten} HTML files")

    if files_changed and len(files_changed) <= 10:
        print("Changed files:")
        for f in files_changed:
            print(f"  - {f}")

    print()
    print("=" * 70)
    print("Rewriting staticSearch titles JSON...")
    print("=" * 70)
    print()
    rewrite_titles_json(library_id, url_map)

    print()
    print("=" * 70)
    print("Phase 2 complete!")
    print("=" * 70)
    print()
    print(f"Downloaded {success} images to resources/images/{library_id}/{{bookID}}/")
    print(f"Rewrote {rewritten} HTML files")
    print()
    print("Your static site is now fully standalone and can be deployed anywhere.")


if __name__ == "__main__":
    main()
'

let $requirements := 'requests>=2.28.0'

let $readme := 
'# Static Site Export - Phase 2: Download IIIF Images

This export includes links to images hosted on external IIIF servers. To make the site fully standalone:

## Prerequisites
- Python 3.7 or higher
- pip (Python package installer)

## Instructions

1. Install dependencies:
```bash
   pip install -r requirements.txt
```

2. Run the download script from this directory:
```bash
   python _download-images.py
```

3. The script will:
   - Read `manifests/image-manifest.xml`
   - Download all IIIF images to `resources/images/{libraryID}/{bookID}/`
   - Rewrite all HTML files to use local image paths
   - Show progress (may take 10-30 minutes depending on image count)

## After completion
All IIIF images are now stored locally. The site is fully standalone and can be deployed to any web server.

## Notes
- The script adds a 0.5 second delay between downloads to avoid overwhelming IIIF servers
- Already-downloaded images are skipped (safe to re-run if interrupted)
- Internet connection required during download phase only
'

let $scriptStored := xmldb:store($outLibCol, "_download-images.py",
                        $pythonScript, "text/plain")
let $reqsStored := xmldb:store($outLibCol, "requirements.txt",
                      $requirements, "text/plain")
let $readmeStored := xmldb:store($outLibCol, "README-PHASE2.md",
                        $readme, "text/plain")

let $logPhase2Done := local:log-progress("Phase 2 scripts written")



(: ============================================================
   GENERATE IMAGE MANIFEST (incrementally)
   ============================================================ :)
let $logManifest := local:write-status($libraryID, "running", "manifest",
                        "Generating image manifest...",
                        75, $booksOk, $booksFailed, $browseOk, $browseFailed)
let $manifestDir  := local:ensure-collection($outLibCol || "/manifests")
let $manifestPath := local:generate-manifest-incremental(
                         $libraryID, $booksCol, $baseUrl, $manifestDir)


(: ============================================================
   BUILD REPORT
   ============================================================ :)
let $elapsed := seconds-from-duration(util:system-time() - $startTime)
let $report  :=
    <export-report>
        <timestamp>{current-dateTime()}</timestamp>
        <libraryID>{$libraryID}</libraryID>
        <duration-seconds>{$elapsed}</duration-seconds>
        <books-exported>{$booksOk}</books-exported>
        <books-failed>{$booksFailed}</books-failed>
        <browse-pages-exported>{$browseOk}</browse-pages-exported>
        <browse-pages-failed>{$browseFailed}</browse-pages-failed>
        <output>{$outLibCol}</output>
        <manifest>{$manifestPath}</manifest>
        <books>{$results}</books>
        <browse-pages>{$browseResults}</browse-pages>
    </export-report>
let $unused := xmldb:store($outLibCol, "export-report.xml", $report, "application/xml")

(: FINAL STATUS :)
let $logDone := local:write-status($libraryID, "complete", "done",
                    "Export complete in " || $elapsed || " seconds. " ||
                    $booksOk || " books, " || $browseOk || " browse pages exported.",
                    100, $booksOk, $booksFailed, $browseOk, $browseFailed)
                    
(: CLEANUP SCHEDULER JOB AND PENDING FILE :)
let $_ := try { scheduler:delete-scheduled-job("export-" || $libraryID) } catch * { ()  }
let $_ := if (doc-available("/db/apps/writerslibrary/static/pending-export.xml"))
          then xmldb:remove("/db/apps/writerslibrary/static", "pending-export.xml")
          else ()
          
return $report

