xquery version "3.1";

declare function local:extractIIIFLinks($manifest as xs:string) {

    let $manifest_response := unparsed-text($manifest)
    let $manifest_data := json-to-xml($manifest_response)
    
    let $image_data :=
        for $sequence in $manifest_data//fn:array[@key="sequences"]//fn:map
        for $canvas in $sequence//fn:array[@key="canvases"]//fn:map
        for $image in $canvas//fn:array[@key="images"]//fn:map
            let $image_id := $image/fn:string[@key="@id"]/data()
            let $title := $canvas//fn:array[@key="metadata"]/fn:map[fn:string[@key="label"]/data() = "Title"]/fn:string[@key="value"]/data()
            return 
                if ($image_id ne "" and
                    not(
                        contains($image_id, "/anno") or
                        contains($image_id, "default.jpg") or
                        contains($image_id, "annotation") or
                        contains($image_id, "/full/")
                        )
                    )
                then 
                    <image>
                        <id>{concat($image_id,"/full/680,/0/default.jpg")}</id>
                        <title>{$title}</title>
                    </image>
                else ()
    
    let $facsimiles :=
        if (not(empty($image_data))) then
            <module type="pages">
                
            {    for $image at $position in $image_data
                return 
                    <page><pagenumber>{if ($image/title/text() ne "") then if (starts-with($image/title/text(),'Page ')) then substring-after($image/title/text(),'Page ') else $image/title/text() else $position}</pagenumber><facsimile>{$image/id/text()}</facsimile></page>

            }
            </module>
        else "<!--Unfortunately, it was not possible to extract images from this manifest.-->"
        
        let $metadata := 
            <metadata>
                {   let $first_metadata := ($manifest_data//fn:array[@key="metadata"])[1]
                    for $metadata_items in $first_metadata//fn:map
                    let $key := replace(replace($metadata_items/fn:string[@key="label"]/data(), "/", "-"), " ", "-")
                    let $value := fn:replace($metadata_items/fn:string[@key="value"]/data(), "<[^>]*>", "")
                    return
                        element {$key} {$value}
                }
            </metadata>


    
    return
        <manifest>{($facsimiles, $metadata)}</manifest>
};



let $input := request:get-parameter('manifest', '')
return 
    local:extractIIIFLinks($input)