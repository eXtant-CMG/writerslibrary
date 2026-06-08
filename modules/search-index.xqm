xquery version "3.1";

(:~
 : search-index.xqm
 : Generates a staticSearch-compatible search index from Bibundina book XML files.
 : Called from export.xql as part of the static site export pipeline.
 :
 : Output layout under $outputDir:
 :   staticSearch/stems/{stem}.json      — one token file per stem
 :   staticSearch/ssTitles_{v}.json      — document title + cover image map
 :   staticSearch/ssStopwords_{v}.json   — English stopword list
 :   staticSearch/ssWordString_{v}.txt   — all stems, space-separated (wildcard search)
 :   staticSearch/config_{v}.json        — staticSearch runtime config
 :
 : @author  Bibundina project
 : @version 0.1
 :)
module namespace si = "http://bibundina.org/ns/search-index";

import module namespace xmldb  = "http://exist-db.org/xquery/xmldb";
import module namespace util   = "http://exist-db.org/xquery/util";
import module namespace transform = "http://exist-db.org/xquery/transform";

(: ============================================================
   CONSTANTS
   ============================================================ :)

(: Version token appended to support-file names.
   Keep short — it appears in every file name and in config.json.
   A timestamp-based token ensures stale caches are busted on re-export. :)
declare variable $si:VERSION := concat("_", format-dateTime(
    current-dateTime(), "[Y0001][M01][D01][H01][m01]"));

(: Path to the batch-stemmer XSLT inside the .xar :)
declare variable $si:STEMMER_XSLT :=
    "/db/apps/writerslibrary/resources/staticSearch/stemmer-wrapper.xsl";

(: Number of words either side of a hit to include in the KWIC context snippet :)
declare variable $si:CONTEXT_WINDOW := 12;

(: Regex that matches tokens we want to index.
   Keeps only runs of Unicode letters/digits; strips punctuation. :)
declare variable $si:TOKEN_REGEX := "[^\p{L}\p{N}]+";

(: Minimum token length — single-character tokens are rarely useful :)
declare variable $si:MIN_TOKEN_LENGTH := 2;


(: ============================================================
   PUBLIC API
   ============================================================ :)

(:~
 : Main entry point.  Call this from export.xql after the HTML pages have been
 : written.  Iterates over every book in the library, builds a merged index, and
 : writes all output files.
 :
 : @param $libraryId   the library folder name (e.g. "sample-library")
 : @param $outputDir   absolute eXist-db path to the static export root
 :                     (e.g. "/db/apps/writerslibrary/static/sample-library")
 :)
declare function si:build-index(
    $libraryId  as xs:string,
    $outputDir  as xs:string
) as empty-sequence()
{
    (: Ensure output directories exist :)
    let $ssDir    := concat($outputDir, "/staticSearch")
    let $stemsDir := concat($outputDir, "/staticSearch/stems")
    let $_0 := si:ensure-collection($ssDir)
    let $_1 := si:ensure-collection($stemsDir)
    let $_c := si:cleanup-previous($outputDir)

    (: Copy staticSearch runtime assets :)
    let $_2 := si:copy-assets($outputDir)

    (: Load stopwords once — used both for filtering and for the support file :)
    let $stopwords := si:load-stopwords()

    (: Collect every book XML in this library :)
    let $booksCol := concat("/db/apps/writerslibrary/data/", $libraryId, "/books")
    let $bookDocs := collection($booksCol)/book

    (: Per-book indexing :)
    let $allBookData :=
        for $book in $bookDocs
        let $bookId  := string($book/@id)
        let $docUri  := concat("../", $bookId, "/index.html")
        return si:index-book($book, $docUri, $stopwords, $libraryId)

    (: Merge per-book token maps into one global index :)
    let $globalIndex := si:merge-index($allBookData)

    (: Titles map :)
    let $titlesMap :=
        map:merge(
            for $bd in $allBookData
            return map:entry($bd?uri, [$bd?title, $bd?cover])
        )

    (: Write token files :)
    let $_3 := si:write-token-files($globalIndex, $stemsDir, $si:VERSION)

    (: Write support files :)
    let $_4 := si:write-support-files(
                    $globalIndex, $titlesMap, $stopwords,
                    $outputDir, $si:VERSION)
    
    (:  write search/index.html :)                
    let $searchDir := concat($outputDir, "/search")
    let $_6 := si:ensure-collection($searchDir)
    let $_5 := si:write-search-page($searchDir, $si:VERSION)
    return ()
};

(:~
 : Process one book XML element and produce indexing data.
 :
 : @param $book    the <book> element
 : @param $docUri  relative URI used as the document key in the index
 :                 (e.g. "DAR-ORI/index.html")
 : @param $stopwords  set of stopword strings (for filtering)
 : @return a map with keys: uri, tokens, title, cover
 :)
declare function si:index-book(
    $book      as element(book),
    $docUri    as xs:string,
    $stopwords as map(xs:string, xs:boolean),
    $libraryId as xs:string
) as map(*)
{
    (: Two segments: bibl module at weight 2, everything else at weight 1.
       fid is a fixed placeholder until fragment highlighting is implemented. :)
    let $segments := (
        map {
            "text"   : normalize-space(string-join($book/module[@type="bibl"]//text(), " ")),
            "weight" : "2",
            "fid"    : "bibl"
        },
        map {
            "text"   : normalize-space(string-join(
                           $book/module[not(@type="bibl")]//text(), " ")),
            "weight" : "1",
            "fid"    : "bibl"
        }
    )
    let $segments := $segments[?text ne ""]

    (: Collect unique word forms across both segments :)
    let $allWordForms :=
        distinct-values(
            for $seg in $segments
            for $tok in si:tokenize-text($seg?text)
            where not(map:contains($stopwords, lower-case($tok)))
            return lower-case($tok)
        )

    (: Batch-stem via XSLT — one call per book :)
    let $stemMap := si:stem-words($allWordForms)

    (: Build context list with sequential pos :)
    let $rawContexts :=
        for $seg in $segments
        let $words := si:tokenize-text($seg?text)
        for $i in 1 to count($words)
        let $form := lower-case($words[$i])
        where string-length($form) ge $si:MIN_TOKEN_LENGTH
          and not(map:contains($stopwords, $form))
        let $stem := (map:get($stemMap, $form), $form)[1]
        let $ctx  := si:get-context($words, $i, $words[$i])
        return map {
            "stem"    : $stem,
            "form"    : $words[$i],
            "weight"  : $seg?weight,
            "context" : $ctx,
            "fid"     : $seg?fid
        }

    let $contextsWithPos :=
        for $c at $pos in $rawContexts
        return map:put($c, "pos", $pos)

    (: Group by stem :)
    let $stemGroups :=
        let $stems := distinct-values($contextsWithPos ! ?stem)
        return map:merge(
            for $s in $stems
            return map:entry(
                $s,
                $contextsWithPos[?stem = $s]
            )
        )

    (: Title and cover :)
    let $biblModule := $book/module[@type="bibl"]
    let $title  := si:make-title($biblModule)
    let $cover :=
    let $firstFacs := normalize-space(string(
                          ($book/module[@type="pages"]/page/facsimile)[1]))
        return
            if ($firstFacs eq "") then ""
            else if (starts-with($firstFacs, "http://") or
                     starts-with($firstFacs, "https://")) then
                $firstFacs  (: IIIF URL — Python will rewrite after download :)
            else
                concat("../resources/images/", $libraryId, "/", $firstFacs)

    return map {
        "uri"    : $docUri,
        "tokens" : $stemGroups,
        "title"  : $title,
        "cover"  : $cover
    }
};


(:~
 : Stem a sequence of unique lower-cased word forms via a single XSLT call.
 : Returns a map(word → stem).  Words absent from the result map should fall
 : back to the original form in the caller.
 :
 : @param $words  sequence of unique lower-cased word strings
 : @return        map of word → Porter2 stem
 :)
declare function si:stem-words(
    $words as xs:string*
) as map(xs:string, xs:string)
{
    if (empty($words)) then map {}
    else
        let $input :=
            <words>
                {for $w in $words return <word>{$w}</word>}
            </words>
        let $xslt   := doc($si:STEMMER_XSLT)
        let $result := transform:transform($input, $xslt, ())
        (: $result is <stems><stem original="word">stemvalue</stem>...</stems> :)
        return map:merge(
            for $s in $result/stem
            return map:entry(string($s/@original), si:transliterate(string($s)))
        )
};


(:~
 : Generate a KWIC context snippet: up to $si:CONTEXT_WINDOW tokens either
 : side of the hit, with the hit term wrapped in <mark>…</mark>.
 :
 : @param $words  tokenised word sequence for the whole text segment
 : @param $pos    1-based index of the hit token within $words
 : @param $form   the original surface form of the hit (for the <mark>)
 : @return        HTML-escaped context string with a <mark> around the hit
 :)
declare function si:get-context(
    $words  as xs:string*,
    $pos    as xs:integer,
    $form   as xs:string
) as xs:string
{
    let $total  := count($words)
    let $start  := max((1, $pos - $si:CONTEXT_WINDOW))
    let $end    := min(($total, $pos + $si:CONTEXT_WINDOW))

    let $before := subsequence($words, $start, $pos - $start)
    let $after  := subsequence($words, $pos + 1, $end - $pos)

    let $prefix := if ($start gt 1)  then "… " else ""
    let $suffix := if ($end lt $total) then " …" else ""

    return concat(
        $prefix,
        string-join($before, " "),
        if (exists($before)) then " " else "",
        "&lt;mark&gt;",
        si:escape-html($form),
        "&lt;/mark&gt;",
        if (exists($after)) then " " else "",
        string-join($after, " "),
        $suffix
    )
};


(:~
 : Write one JSON file per stem into $stemsDir.
 : Each file: staticSearch/stems/{stem}.json
 :
 : @param $index      global index map(stem → map(docUri → sequence of context maps))
 : @param $stemsDir   absolute eXist-db path to the stems output collection
 : @param $version    version string (unused in filename here, kept for symmetry)
 :)
declare function si:write-token-files(
    $index    as map(*),
    $stemsDir as xs:string,
    $version  as xs:string
) as empty-sequence()
{
    for $stem in map:keys($index)
    let $docMap   := map:get($index, $stem)
    let $instances :=
        for $uri in map:keys($docMap)
        let $contexts := map:get($docMap, $uri)
        let $score    := count($contexts)
        return si:instance-to-json($uri, $score, $contexts)

    let $json := concat(
        '{"stem":', si:json-string($stem),
        ',"instances":[',
        string-join($instances, ","),
        ']}'
    )
    let $filename := concat(si:safe-filename($stem), $version, ".json")
    return xmldb:store($stemsDir, $filename, $json, "application/json")
        => (function($x){()})(  (: discard store return value :)  )
};


(:~
 : Write ssTitles, ssStopwords, ssWordString, and config support files.
 :)
declare function si:write-support-files(
    $index     as map(*),
    $titlesMap as map(*),
    $stopwords as map(xs:string, xs:boolean),
    $outputDir as xs:string,
    $version   as xs:string
) as empty-sequence()
{
    let $ssDir := concat($outputDir, "/staticSearch")
    let $_     := si:ensure-collection($ssDir)

    (: ssTitles_{version}.json :)
    let $titlesJson := concat(
        "{",
        string-join(
            for $uri in map:keys($titlesMap)
            let $arr := map:get($titlesMap, $uri)
            let $title := $arr(1)
            let $cover := $arr(2)
            return concat(
                si:json-string($uri), ":[",
                si:json-string($title),
                if ($cover ne "") then concat(",", si:json-string($cover)) else "",
                "]"
            ),
            ","
        ),
        "}"
    )
    let $_t := xmldb:store($ssDir,
                    concat("ssTitles", $version, ".json"),
                    $titlesJson, "application/json")

    (: ssStopwords_{version}.json :)
    let $swJson := concat(
        '{"words":[',
        string-join(map:keys($stopwords) ! si:json-string(.), ","),
        ']}'
    )
    let $_s := xmldb:store($ssDir,
                    concat("ssStopwords", $version, ".json"),
                    $swJson, "application/json")

    (: ssWordString_{version}.txt :)
    let $wordString := "|" || string-join(map:keys($index), "||") || "|"
    let $_w := xmldb:store($ssDir,
                    concat("ssWordString", $version, ".txt"),
                    $wordString, "text/plain")

    (: config_{version}.json :)
    let $configJson := concat(
        '{"params":[{"searchPage":"search/index.html","index":"","stopwords":"",',
        '"dictionary":"","scoringAlgorithm":"raw","stemmer":"en",',
        '"tokenizer":"","createContexts":"","results":"",',
        '"version":', si:json-string($version), ',',
        '"output":"staticSearch"}],"filtersWithCustomLabels":[]}'
    )
    let $_c := xmldb:store($ssDir,
                    concat("config", $version, ".json"),
                    $configJson, "application/json")

    return ()
};


(: ============================================================
   PRIVATE HELPERS
   ============================================================ :)

(:~
 : Merge per-book token data into a global index.
 : Input:  sequence of book-data maps (from si:index-book)
 : Output: map(stem → map(docUri → sequence-of-context-maps))
 :)
declare %private function si:merge-index(
    $allBookData as map(*)*
) as map(*)
{
    (: Collect all stems across all books :)
    let $allStems :=
        distinct-values(
            for $bd in $allBookData
            return map:keys($bd?tokens)
        )

    return map:merge(
        for $stem in $allStems
        return map:entry(
            $stem,
            map:merge(
                for $bd in $allBookData
                where map:contains($bd?tokens, $stem)
                return map:entry($bd?uri, map:get($bd?tokens, $stem))
            )
        )
    )
};

(:~
 : clean up the previously generated files 
 :)
declare %private function si:cleanup-previous(
    $outputDir as xs:string
) as empty-sequence()
{
    let $ssDir := concat($outputDir, "/staticSearch")
    (: Remove versioned support files from previous runs :)
    let $_1 :=
        for $file in xmldb:get-child-resources($ssDir)
        where matches($file, "^(ssTitles|ssStopwords|ssWordString|config)_")
        return xmldb:remove($ssDir, $file)
    (: Remove all stem files from previous runs :)
    let $_2 :=
        for $file in xmldb:get-child-resources(concat($ssDir, "/stems"))
        return xmldb:remove(concat($ssDir, "/stems"), $file)
    (: Remove old search.html from root if present from a previous run :)
    let $_3 :=
        if (util:binary-doc-available(concat($outputDir, "/search.html")))
        then xmldb:remove($outputDir, "search.html")
        else ()
    return ()
};


(:~
 : Tokenise a text string into an ordered sequence of word-form strings,
 : splitting on any run of non-letter/non-digit characters.
 : Preserves original case; filtering/lowercasing done by caller.
 :)
declare %private function si:tokenize-text(
    $text as xs:string
) as xs:string*
{
    let $raw := tokenize(normalize-space($text), $si:TOKEN_REGEX)
    return $raw[string-length(.) ge $si:MIN_TOKEN_LENGTH]
};


(:~
 : Copy required staticSearch assets into the export
 :)
declare %private function si:copy-assets(
    $outputDir as xs:string
) as empty-sequence()
{
    let $src    := "/db/apps/writerslibrary/resources/staticSearch"
    let $dest   := concat($outputDir, "/staticSearch")
    let $assets := (
        "ssHighlight.js",
        "ssInitialize.js",
        "ssReports.css",
        "ssSearch-debug.js",
        "ssSearch.css",
        "ssSearch.js",
        "ssSearch.js.map"
    )
    for $file in $assets
    where util:binary-doc-available(concat($src, "/", $file))
    return xmldb:copy-resource($src, $file, $dest, $file)
        => (function($x){()})()
};

(:~
 : Build the display title for ssTitles from a <module type="bibl"> element.
 : Format: "{lastname}, {firstname}: {title}"
 :)
declare %private function si:make-title(
    $bibl as element(module)
) as xs:string
{
    let $last    := normalize-space(string(($bibl/author/lastname)[1]))
    let $first   := normalize-space(string(($bibl/author/firstname)[1]))
    let $title   := normalize-space(string(($bibl/title)[1]))
    let $author  :=
        if ($last ne "" and $first ne "") then concat($last, ", ", $first)
        else if ($last ne "") then $last
        else if ($first ne "") then $first
        else ""
    return
        if ($author ne "" and $title ne "")
        then concat($author, ": ", $title)
        else if ($title ne "") then $title
        else if ($author ne "") then $author
        else "[no title]"
};


(:~
 : Load the English stopword list from the bundled staticSearch dictionary.
 : Returns a map(word → true()) for O(1) membership testing.
 :)
declare %private function si:load-stopwords() as map(xs:string, xs:boolean)
{
    let $swDoc := doc(
        "/db/apps/writerslibrary/resources/staticSearch/dicts/stopwords_en.xml")
    (: staticSearch format: <words><word>the</word>...</words> :)
    return map:merge(
        for $w in $swDoc//word
        return map:entry(normalize-space(string($w)), true())
    )
};


(:~
 : Ensure a db collection path exists, creating intermediate collections as needed.
 :)
declare %private function si:ensure-collection(
    $path as xs:string
) as empty-sequence()
{
    if (xmldb:collection-available($path)) then ()
    else
        let $parent := replace($path, "/[^/]+$", "")
        let $_      := si:ensure-collection($parent)
        let $name   := replace($path, "^.*/", "")
        return xmldb:create-collection($parent, $name) => (function($x){()})()
};


(:~
 : Serialize one document instance to its JSON fragment for a token file.
 :)
declare %private function si:instance-to-json(
    $uri      as xs:string,
    $score    as xs:integer,
    $contexts as map(*)*
) as xs:string
{
    concat(
        '{"docUri":', si:json-string($uri),
        ',"score":', string($score),
        ',"contexts":[',
        string-join(
            for $c in $contexts
            return concat(
                '{"form":',    si:json-string($c?form),
                ',"weight":',  si:json-string($c?weight),
                ',"pos":',     string($c?pos),
                ',"context":', si:json-string($c?context),
                ',"fid":',     si:json-string($c?fid),
                "}"
            ),
            ","
        ),
        ']}'
    )
};


(:~
 : Produce a JSON-safe double-quoted string, escaping backslash, double-quote,
 : and the four mandatory JSON control characters.
 :)
declare %private function si:json-string(
    $s as xs:string?
) as xs:string
{
    let $v := ($s, "")[1]
    return concat(
        '"',
        replace(
            replace(
                replace(
                    replace(
                        replace($v, "\\", "\\\\"),   (: \ → \\ :)
                    '"', '\\"'),                      (: " → \" :)
                "&#x0009;", "\\t"),                   (: tab :)
            "&#x000A;", "\\n"),                       (: newline :)
        "&#x000D;", "\\r"),                           (: CR :)
        '"'
    )
};

(:~
 : Write a minimal staticSearch-compatible search/index.html into $outputDir.
 : The version string is baked into data-versionstring so the JS can locate
 : the versioned support files (ssTitles, ssStopwords, ssWordString, config).
 :)
declare %private function si:write-search-page(
    $searchDir as xs:string,
    $version   as xs:string
) as empty-sequence()
{
    let $path := concat($searchDir, "/index.html")
    return
        if (util:binary-doc-available($path)) then
            let $html    := util:binary-to-string(util:binary-doc($path))
            let $patched := replace($html, "VERSIONSTRING", $version)
            let $binary  := util:string-to-binary($patched, "UTF-8")
            return xmldb:store($searchDir, "index.html",
                       $binary, "application/octet-stream")
                   => (function($x){()})()
        else
            util:log("WARN",
                "si:write-search-page: search/index.html not found at " || $path ||
                " — was export.xql run first?")
};


(:~
 : HTML-escape a string for use inside a context snippet.
 : Only the characters that are meaningful in HTML attribute/text context.
 :)
declare %private function si:escape-html(
    $s as xs:string
) as xs:string
{
    replace(
        replace(
            replace($s, "&amp;", "&amp;amp;"),
        "&lt;",  "&amp;lt;"),
    "&gt;", "&amp;gt;")
};


(:~
 : Produce a filesystem-safe filename from a stem string.
 : Replaces characters that are problematic on Windows/macOS/Linux.
 :)
 
declare %private function si:safe-filename(
    $stem as xs:string
) as xs:string
{
    (:  :replace($stem, "[^a-zA-Z0-9\-_]", "_"):)
    replace($stem, '[/\\:*?"<>|]', "_")
};

(:  must match transliterate function in ssSearch-debug.js :) 
declare %private function si:transliterate($s as xs:string) as xs:string
{
    translate($s,
        "àáâãäåçèéêëìíîïñòóôõöùúûüýÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ",
        "aaaaaaceeeeiiiinooooouuuuyAAAAAACEEEEIIIINOOOOOUUUUY")
};