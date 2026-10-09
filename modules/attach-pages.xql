xquery version "3.1";

(:~
 : Driver for linking uploaded page images to book files.
 :
 : For every book in a library, looks for an image collection named after the
 : book id under {data-root}/{library}/images/ and, in write mode, inserts the
 : matching <page> blocks through libmgr:insert-pages-into-book().
 :
 : This must be a STORED query in modules/ -- config:app-root does not resolve
 : in an eXide scratch buffer. Open the stored file in eXide and press Run, or
 : call it over REST as a dba user:
 :
 :   .../exist/rest/db/apps/writerslibrary/modules/attach-pages.xql?library=joyce-library
 :   ...&write=yes              insert pages for books that have none yet
 :   ...&write=yes&book=BAL-BEA one book only; also tops up a book that
 :                              already has pages (existing facsimiles skipped)
 :
 : Without write=yes nothing is modified: the report only says what would
 : happen. Run from eXide without parameters, edit the defaults below.
 :)

import module namespace libmgr="http://exist-db.org/apps/writerslibrary/library-manager" at "library-manager.xql";
import module namespace config="http://exist-db.org/apps/writerslibrary/config" at "config.xqm";

declare option exist:serialize "method=xml indent=yes";

declare variable $library := request:get-parameter("library", "joyce-library");
declare variable $write   := request:get-parameter("write", "no") = "yes";
declare variable $only    := request:get-parameter("book", "");

let $imageRoot := config:images-collection($library)
let $books := collection(config:xml-collection($library))/book
let $imageDirs :=
    if (xmldb:collection-available($imageRoot))
    then xmldb:get-child-collections($imageRoot)
    else ()
return
    <report library="{$library}" mode="{if ($write) then 'write' else 'dry-run'}"
            books="{count($books)}" imageDirs="{count($imageDirs)}">
        {
            (: image folders that match no book id: a typo in one or the other :)
            for $dir in $imageDirs
            where not($dir = $books/@id)
            order by $dir
            return <no-book dir="{$dir}"/>
        }
        {
            for $book in $books
            let $id := string($book/@id)
            where ($only = "" or $id = $only) and $id = $imageDirs
            order by $id
            let $check := libmgr:check-directory-listing($library, $id)
            let $already := count($book/module[@type = "pages"]/page)
            return
                <book id="{$id}" images="{$check/matched}" pagesAlready="{$already}">
                    {
                        for $f in $check/unmatchedFiles/file
                        return <badname>{string($f)}</badname>
                    }
                    {
                        if (not($write)) then
                            ()
                        else if ($already > 0 and $only = "") then
                            <skipped>already has pages; rerun with book={$id} to top up</skipped>
                        else
                            libmgr:insert-pages-into-book($library, $id, $id)
                    }
                </book>
        }
        <without-images>{
            count($books[not(@id = $imageDirs)])
        }</without-images>
    </report>
