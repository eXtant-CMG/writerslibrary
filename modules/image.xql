xquery version "3.1";

(:~
 : Streams a page image from the external images root.
 :
 : controller.xq forwards every .../$library-images/{path} URL here with
 : ?library={libraryID}&path={path}. Images live outside the app collection
 : ({data-root}/{library}/images/) because the eXist package manager deletes
 : /db/apps/writerslibrary on every upgrade.
 :)

import module namespace config="http://exist-db.org/apps/writerslibrary/config" at "config.xqm";

let $library := request:get-parameter("library", "")
let $path    := request:get-parameter("path", "")
return
    if (not(matches($library, "^[a-z0-9\-]+$"))
        or $path = "" or starts-with($path, "/") or contains($path, "..")) then (
        response:set-status-code(400),
        "Bad image request"
    )
    else
        let $uri := config:images-collection($library) || "/" || $path
        return
            if (util:binary-doc-available($uri)) then (
                response:set-header("Cache-Control", "max-age=3600, must-revalidate"),
                response:stream-binary(
                    util:binary-doc($uri),
                    (xmldb:get-mime-type(xs:anyURI($uri)), "application/octet-stream")[1]
                )
            )
            else (
                response:set-status-code(404),
                "Image not found"
            )
