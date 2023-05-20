import module namespace xmldb = "http://exist-db.org/xquery/xmldb";
import module namespace util = "http://exist-db.org/xquery/util";

declare variable $source-app := "/db/apps/writerslibrary";
declare variable $target-app := "/db/apps/joycelibrary";
declare variable $exclude-files := (
  "build.xml",
  "cypress.config.js",
  "expath-pkg.xml",
  "icon.png",
  "LICENSE",
  "package-lock.json",
  "package.json",
  "post-install.xq",
  "pre-install.xq",
  "repo.xml"
);

declare function local:copy-files($source-dir as xs:string, $target-dir as xs:string) {
  let $collections := xmldb:get-child-collections($source-dir)
  return (
    for $file in xmldb:get-child-resources($source-dir)
    where not($file = $exclude-files)
    return
      if ($file = $collections) then
        let $new-target-dir := concat($target-dir, "/", $file)
        return (
          xmldb:create-collection($target-app, substring-after($new-target-dir, $target-app)),
          local:copy-files(concat($source-dir, "/", $file), $new-target-dir)
        )
      else
        let $content :=
          try {
            doc(concat($source-dir, "/", $file))
          } catch * {
            util:binary-doc(concat($source-dir, "/", $file))
          }
        return
          xmldb:store($target-dir, $file, $content),
    for $collection in $collections
    let $new-source-dir := concat($source-dir, "/", $collection)
    let $new-target-dir := concat($target-dir, "/", $collection)
    return (
      xmldb:create-collection($target-app, substring-after($new-target-dir, $target-app)),
      local:copy-files($new-source-dir, $new-target-dir)
    )
  )
};

local:copy-files($source-app, $target-app)