xquery version "3.1";
import module namespace libmgr="http://exist-db.org/apps/writerslibrary/library-manager" at "library-manager.xql";
import module namespace config="http://exist-db.org/apps/writerslibrary/config" at "config.xqm";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace scheduler="http://exist-db.org/xquery/scheduler";
declare namespace compression="http://exist-db.org/xquery/compression";
declare option output:method "json";
declare option output:media-type "application/json";

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

    else if ($action = "create-book") then
        let $libraryId   := request:get-parameter("libraryId", "")
        let $bookId      := request:get-parameter("bookId", "")
        let $bookType    := request:get-parameter("bookType", "EL")
        let $firstname   := request:get-parameter("firstname", "")
        let $lastname    := request:get-parameter("lastname", "")
        let $title       := request:get-parameter("title", "")
        let $subtitle    := request:get-parameter("subtitle", "")
        let $type        := request:get-parameter("type", "")
        let $volume      := request:get-parameter("volume", "")
        let $series      := request:get-parameter("series", "")
        let $edition     := request:get-parameter("edition", "")
        let $editor      := request:get-parameter("editor", "")
        let $place       := request:get-parameter("place", "")
        let $publisher   := request:get-parameter("publisher", "")
        let $date        := request:get-parameter("date", "")
        let $generalnote := request:get-parameter("generalnote", "")
        let $location    := request:get-parameter("location", "")
        let $iiifManifest := request:get-parameter("iiifManifest", "")
        let $iiifViewer   := request:get-parameter("iiifViewer", "")
        return libmgr:create-book(
            $libraryId, $bookId, $bookType,
            $firstname, $lastname, $title, $subtitle,
            $type, $volume, $series, $edition, $editor,
            $place, $publisher, $date, $generalnote, $location,
            $iiifManifest, $iiifViewer
        )

    else if ($action = "start-export") then
        let $libraryId := request:get-parameter("libraryId", "")
        return
            if ($libraryId eq "") then
                map { "success": false(), "message": "libraryId is required" }
            else
                let $jobName := "export-" || $libraryId
                let $statusPath := "/db/apps/writerslibrary/static/" || $libraryId || "/export-status.xml"
                let $alreadyRunning :=
                    if (doc-available($statusPath)) then
                        let $state := doc($statusPath)/export-status/state/text()
                        let $jobRunning :=
                            scheduler:get-scheduled-jobs()//scheduler:job
                                [@name eq $jobName]
                                /scheduler:trigger/state/text() eq "NORMAL"
                        return ($state eq "running" and $jobRunning)
                    else false()
                return
                    if ($alreadyRunning) then
                        map { "success": false(), "message": "Export already running for this library" }
                    else
                        let $cancel :=
                            try { scheduler:delete-scheduled-job($jobName) } catch * { () }
                        let $stillExists := exists(
                            scheduler:get-scheduled-jobs()//scheduler:job[@name eq $jobName]
                        )
                        return
                            if ($stillExists) then
                                map { "success": false(), "message": "Could not clear existing job, try again" }
                            else
                                let $_ := if (xmldb:collection-available("/db/apps/writerslibrary/static"))
                                  then ()
                                  else xmldb:create-collection("/db/apps/writerslibrary", "static")
                                let $_ := xmldb:store(
                                    "/db/apps/writerslibrary/static",
                                    "pending-export.xml",
                                    <pending-export>
                                        <libraryID>{$libraryId}</libraryID>
                                        <requested>{current-dateTime()}</requested>
                                    </pending-export>,
                                    "application/xml")
                                let $scheduled := scheduler:schedule-xquery-periodic-job(
                                    "/db/apps/writerslibrary/modules/export.xql",
                                    5000,
                                    $jobName,
                                    (),
                                    0,
                                    0
                                )
                                let $_ := util:log("INFO", "schedule-xquery-periodic-job returned: " || string($scheduled) || " for library: " || $libraryId)
                                return
                                    if ($scheduled) then
                                        map { "success": true(), "message": "Export started" }
                                    else
                                        map { "success": false(), "message": "Failed to schedule export job" }
                            
            else if ($action = "export-status") then
                let $libraryId := request:get-parameter("libraryId", "")
                let $statusPath := "/db/apps/writerslibrary/static/" || $libraryId || "/export-status.xml"
                return
                    if (not(doc-available($statusPath))) then
                        map {
                            "state": "none",
                            "phase": "",
                            "message": "No export found for this library",
                            "pct": 0,
                            "booksOk": 0,
                            "booksFailed": 0,
                            "browseOk": 0,
                            "browseFailed": 0
                        }
                    else
                        let $s := doc($statusPath)/export-status
                        return map {
                            "state":        $s/state/text(),
                            "phase":        $s/phase/text(),
                            "message":      $s/message/text(),
                            "pct":          xs:integer($s/progress-pct/text()),
                            "booksOk":      xs:integer($s/books-ok/text()),
                            "booksFailed":  xs:integer($s/books-failed/text()),
                            "browseOk":     xs:integer($s/browse-ok/text()),
                            "browseFailed": xs:integer($s/browse-failed/text())
                        }
            else if ($action = "create-zip") then
                let $libraryId  := request:get-parameter("libraryId", "")
                let $sourcePath := "/db/apps/writerslibrary/static/" || $libraryId
                let $zipPath    := "/db/apps/writerslibrary/static/"
                let $zipName    := $libraryId || "-static-export.zip"
                return
                    if (not(xmldb:collection-available($sourcePath))) then
                        map { "success": false(), "message": "Export not found for library: " || $libraryId }
                    else
                        try {
                            let $zip := compression:zip(
                                xs:anyURI($sourcePath),
                                true(),
                                $sourcePath
                            )
                            let $stored := xmldb:store($zipPath, $zipName, $zip, "application/zip")
                            return map { "success": true(), "message": "ZIP created" }
                        } catch * {
                            map { "success": false(), "message": "Error creating ZIP: " || $err:description }
                        }
                        
            else
                map { "success": false(), "message": "Unknown action" }