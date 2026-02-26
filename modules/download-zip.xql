xquery version "3.1";
declare namespace sm="http://exist-db.org/xquery/securitymanager";

let $isAdmin := sm:is-dba(sm:id()//sm:real/sm:username/string())
return
    if (not($isAdmin)) then (
        response:set-status-code(403),
        response:set-header("Content-Type", "text/plain"),
        "Unauthorized"
    )
    else
        let $libraryId := request:get-parameter("libraryId", "")
        let $zipPath   := "/db/apps/writerslibrary/static/" || $libraryId || "-static-export.zip"
        return
            if (not(util:binary-doc-available($zipPath))) then (
                response:set-status-code(404),
                response:set-header("Content-Type", "text/plain"),
                "ZIP not found"
            )
            else (
                response:set-header("Content-Type", "application/zip"),
                response:set-header("Content-Disposition",
                    "attachment; filename=" || $libraryId || "-static-export.zip"),
                response:stream-binary(util:binary-doc($zipPath), "application/zip")
            )