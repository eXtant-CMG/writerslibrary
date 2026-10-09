xquery version "1.0";
(:~ The pre-install runs before the actual install and deploy.
 :
 : @version 1.0.0
 :)
import module namespace xdb="http://exist-db.org/xquery/xmldb";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

(: Library data lives outside the app collection -- see $config:data-root
   in modules/config.xqm, which this must match. :)
declare variable $data-root := "/db/writerslibrary-data";

(: store the collection configuration: for the app collection, and for the
   data root, which is where the indexed book XML actually lives :)
local:mkcol("/db/system/config", $target),
xdb:store-files-from-pattern(concat("/db/system/config", $target), $dir, "*.xconf"),
local:mkcol("/db/system/config", $data-root),
xdb:store-files-from-pattern(concat("/db/system/config", $data-root), $dir, "*.xconf")
