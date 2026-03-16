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
(: Create export service account if it doesn't exist :)
let $_ :=
    if (not(sm:user-exists("export-service"))) then
        sm:create-account("export-service", "change-me-on-install", "dba", ())
    else
        ()
(: Ensure all XQuery files in modules are executable :)
return
    for $f in xmldb:get-child-resources($target || "/modules")
    where matches($f, '\.(xql|xqm|xq)$')
    return sm:chmod(xs:anyURI($target || "/modules/" || $f), "rwxr-xr-x")