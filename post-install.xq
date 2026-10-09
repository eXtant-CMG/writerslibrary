xquery version "3.1";
(:~ The post-install runs after contents are copied to db.
 :
 : @version 1.0.0
 :)
declare namespace repo="http://exist-db.org/xquery/repo";
import module namespace sm="http://exist-db.org/xquery/securitymanager";
(: The following external variables are set by the repo:deploy function :)
(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

(: Library data lives outside the app collection -- see $config:data-root
   in modules/config.xqm, which this must match. :)
declare variable $data-root := "/db/writerslibrary-data";
(: ...and $config:images-root :)
declare variable $images-root := "/db/writerslibrary-images";

(:~
 : Seed the data root from the packaged data/ (sample-library + libraries.xml)
 : and the images root from resources/images/sample-library, but ONLY when the
 : data root has no libraries.xml yet, i.e. on a fresh install. On an upgrade
 : this does nothing: existing library data and images are never overwritten.
 :)
declare function local:seed-data-root() {
    if (doc-available($data-root || "/libraries.xml")) then
        ()
    else
        let $_ := xmldb:create-collection("/db", substring-after($data-root, "/db/"))
        let $seed := $target || "/data"
        return (
            for $lib in xmldb:get-child-collections($seed)
            where not(xmldb:collection-available($data-root || "/" || $lib))
            return xmldb:copy-collection($seed || "/" || $lib, $data-root),
            xmldb:copy-resource($seed, "libraries.xml", $data-root, "libraries.xml"),
            local:seed-images()
        )
};

declare function local:seed-images() {
    let $seed := $target || "/resources/images/sample-library"
    let $_ :=
        if (xmldb:collection-available($images-root)) then ()
        else xmldb:create-collection("/db", substring-after($images-root, "/db/"))
    return
        if (xmldb:collection-available($seed)
            and not(xmldb:collection-available($images-root || "/sample-library")))
        then xmldb:copy-collection($seed, $images-root)
        else ()
};
(: Create export service account if it doesn't exist :)
let $_ :=
    if (not(sm:user-exists("export-service"))) then
        sm:create-account("export-service", "change-me-on-install", "dba", ())
    else
        ()
let $_ := local:seed-data-root()
(: Bring the data root's indexes in line with the collection.xconf just
   stored by pre-install.xq :)
let $_ := xmldb:reindex($data-root)
(: Ensure all XQuery files in modules are executable :)
return
    for $f in xmldb:get-child-resources($target || "/modules")
    where matches($f, '\.(xql|xqm|xq)$')
    return sm:chmod(xs:anyURI($target || "/modules/" || $f), "rwxr-xr-x")