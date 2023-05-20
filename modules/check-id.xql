xquery version "3.1";

import module namespace config="http://exist-db.org/apps/writerslibrary/config" at "config.xqm";

declare function local:check-id($string as xs:string) as xs:boolean {
    let $libraryDoc := doc($config:data-root || '/library/library.xml')
    return
        if (not($libraryDoc/range:field-eq("library-book-ID",$string))) then
            true()
        else
            false()
};

let $input := request:get-parameter('bookID', '')
return
    local:check-id($input)