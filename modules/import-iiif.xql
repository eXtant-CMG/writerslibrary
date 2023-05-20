xquery version "3.1";

declare function local:extractIIIFLinks($manifest as xs:string) {

    let $manifest_response := unparsed-text($manifest)
    let $manifest_data := json-to-xml($manifest_response)
    
    let $image_urls :=
        for $sequence in $manifest_data//fn:array[@key="sequences"]//fn:map
        for $canvas in $sequence//fn:array[@key="canvases"]//fn:map
        for $image in $canvas//fn:array[@key="images"]//fn:map
            let $image-data := $image/fn:string[@key="@id"]/data()
            let $image_url := 
                        if ($image-data ne "" and
                    not(
                        contains($image-data, "/anno") or
                        contains($image-data, "default.jpg") or
                        contains($image-data, "annotation") or
                        contains($image-data, "/full/")
                        )
                    )
                    then concat($image/fn:string[@key="@id"]/data(),"/full/680,/0/default.jpg")
                          else ()
        return $image_url
    
    let $deduped-list := distinct-values($image_urls)
    
    let $facsimiles :=
        if (not(empty($deduped-list))) then
            <module type="pages">
                
            {    for $image_url at $position in $deduped-list
                return <page><pagenumber>{$position}</pagenumber><facsimile>{$image_url}</facsimile></page>
            }
            </module>
        else "<!--Unfortunately, it was not possible to extract images from this manifest.-->"
    return
        $facsimiles
};

let $input := request:get-parameter('manifest', '')
return 
    local:extractIIIFLinks($input)