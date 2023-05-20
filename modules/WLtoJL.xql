xquery version "3.1";

import module namespace xmldb = "http://exist-db.org/xquery/xmldb";

declare variable $string1 := "writerslibrary";
declare variable $string2 := "joycelibrary";
declare variable $app := "/db/apps/joycelibrary";

for $dir in ($app || "/modules", $app)
for $file in xmldb:get-child-resources($dir)
where ends-with($file, ".xq") or ends-with($file, ".xql") or ends-with($file, ".xqm")
return
    let $content :=
      try {
        fn:unparsed-text(concat($dir, "/", $file))
      } catch * {
        ()
      }
  return
    if ($content) then
      let $new-content := fn:replace($content, $string1, $string2)
      return
        xmldb:store($dir, $file, $new-content)
    else ()