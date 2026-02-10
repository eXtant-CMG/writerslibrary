xquery version "3.1";

import module namespace config="http://exist-db.org/apps/writerslibrary/config" at "config.xqm";

declare function local:check-id($string as xs:string) as xs:boolean {
    let $libraryID := request:get-parameter("libraryID", "sample-library")
    let $booksCollection := $config:data-root || '/' || $libraryID || '/books'
    return
        not(collection($booksCollection)/range:field-eq("library-book-ID", $string))
};


let $input := request:get-parameter('bookID', '')
return
    local:check-id($input)