xquery version "3.1";

import module namespace libmgr="http://exist-db.org/apps/writerslibrary/library-manager" at "library-manager.xql";
import module namespace config="http://exist-db.org/apps/writerslibrary/config" at "config.xqm";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace sm="http://exist-db.org/xquery/securitymanager";

declare option output:method "json";
declare option output:media-type "application/json";

(: Check if user is admin :)
let $isAdmin := sm:is-dba(sm:id()//sm:real/sm:username/string())

return
    if (not($isAdmin)) then
        map { "success": false(), "message": "Unauthorized" }
    else
        let $action := request:get-parameter("action", "")
        return
            if ($action = "create") then
                let $libraryId := request:get-parameter("libraryId", "")
                let $libraryName := request:get-parameter("libraryName", "")
                return libmgr:create-library($libraryId, $libraryName)
            else
                map { "success": false(), "message": "Unknown action" }