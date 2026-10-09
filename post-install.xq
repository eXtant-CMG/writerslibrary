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

declare function local:copy-resources($from as xs:string, $to as xs:string) {
    for $r in xmldb:get-child-resources($from)
    return xmldb:copy-resource($from, $r, $to, $r)
};

(:~
 : Seed the data root from the package, but ONLY when it has no libraries.xml
 : yet, i.e. on a fresh install. On an upgrade this does nothing: existing
 : library data and images are never overwritten.
 :
 : The package keeps the seed in the repo layout:
 :   data/libraries.xml, data/{lib}/config.xml, data/{lib}/home.xml,
 :   data/{lib}/books/*.xml, resources/images/{lib}/...
 : and it is copied into the database layout (see modules/config.xqm):
 :   {data-root}/libraries.xml, {data-root}/{lib}/config.xml, .../home.xml,
 :   {data-root}/{lib}/xml/*.xml, {data-root}/{lib}/images/...
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
            let $src := $seed || "/" || $lib
            let $dst := xmldb:create-collection($data-root, $lib)
            let $xml := xmldb:create-collection($dst, "xml")
            let $img := xmldb:create-collection($dst, "images")
            let $imgSrc := $target || "/resources/images/" || $lib
            return (
                local:copy-resources($src, $dst),
                if (xmldb:collection-available($src || "/books"))
                then local:copy-resources($src || "/books", $xml) else (),
                if (xmldb:collection-available($imgSrc)) then (
                    local:copy-resources($imgSrc, $img),
                    for $c in xmldb:get-child-collections($imgSrc)
                    return xmldb:copy-collection($imgSrc || "/" || $c, $img)
                ) else ()
            ),
            xmldb:copy-resource($seed, "libraries.xml", $data-root, "libraries.xml")
        )
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