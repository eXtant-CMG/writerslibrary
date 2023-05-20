/*
 * croppingTool.js: manipulate images served via IIIF Image API via controls linked to IIIF parameters
 *   makes use of JCrop library for visual selection of image region & MagnificPopup for image preview
 *
 * J B Howard - john.b.howard@ucd.ie - @john_b_howard - https://github.com/jbhoward-dublin
 * License Free software under MIT License
 *
 */
var croptool = {
    
    /* initialise  */
    init: function () {
        this.crop();
    },
    
    crop: function () {
        
        var clipboard = new Clipboard('.btn');
        clipboard.on('success', function (e) {
            e.clearSelection();
            showTooltip(e.trigger, 'Copied!');
        });
        clipboard.on('error', function (e) {
            showTooltip(e.trigger, fallbackMessage(e.action));
        });
        function showTooltip(elem, msg) {
            $('.btn-copy-link').tooltip('hide');
            $('button.btn-copy-link').attr('data-placement', 'bottom');
            $('button.btn-copy-link').attr('data-original-title', msg);
            elem.setAttribute('aria-label', msg);
            $('.btn-copy-link').tooltip('show');
            $('button.btn-copy-link').attr('data-placement', 'right');
            $('button.btn-copy-link').attr('data-original-title', 'Copy link to clipboard');
            elem.setAttribute('aria-label', 'Copy link to clipboard');
        }
        
        /* page HTML */
        
        
        var image_selection =
        '  <div class="cropping_image_container">' +
        '    <div class="crop-align">' +
        '        <div class="hidden image_error"></div>' +
        '    </div>' +
        '    <div id="interface" class="row text-center page-interface">' +
        '        <div class="crop-align">' +
        '            <img src id="target"/>' +
        '        </div>' +
        '    </div>' +
        '  </div>';
        
        var image_navbox =
        '    <div class="nav-box">' +
        '        <span class="admin-tools-zone-tool-heading">Page number <span class="admin-tools-zone-tool-ID">' + pageID.split("-_-").join(" ") + '</span> of book ID <span class="admin-tools-zone-tool-ID">' + bookID + '</span></span>' +
        '        <p class="image-options"><span style="font-weight:bold;">1. Mark a zone on the image</span></p>' +
        '        <form onsubmit="return false;" id="text-inputs" class="form form-inline">' +
        '            <div class="inp-group">' +
        '                <p class="coordinates-selected hidden">' +
        '                    <strong>Coordinates selected: </strong>' +
        '                    <b> X </b>' +
        '                    <input type="text" name="cx" id="crop-x"/>' +
        '                    <span class="inp-group">' +
        '                        <b> Y </b>' +
        '                        <input type="text" name="cy" id="crop-y"/>' +
        '                    </span>' +
        '                    <span class="inp-group">' +
        '                        <b> W </b>' +
        '                        <input type="text" name="cw" id="crop-w"/>' +
        '                    </span>' +
        '                    <span class="inp-group">' +
        '                        <b> H </b>' +
        '                        <input type="text" name="ch" id="crop-h"/>' +
        '                    </span>' +
        '                </p>' +
        '                <span class="hidden"><input type="radio" name="img_widthf#iiif" id="lg" value="500" checked="checked"/></span>' +
        '                <!-- add more options: rotate ; format ; quality -->' +
        '                <input type="hidden" name="img_format" value=".jpg"/><input type="hidden" name="img_quality" value="default"/>' +
        '                <p class="image-options">' +
        '                    rotate zone image:<br/>' +
        '                    <label class="radio-inline">' +
        '                        <input type="radio" name="img_rotation" id="rot0" value="0" checked="checked"/> 0 </label>' +
        '                    <label class="radio-inline">' +
        '                        <input type="radio" name="img_rotation" id="rot90" value="90"/> 90 </label>' +
        '                    <label class="radio-inline">' +
        '                        <input type="radio" name="img_rotation" id="rot180" value="180"/> 180 </label>' +
        '                    <label class="radio-inline">' +
        '                        <input type="radio" name="img_rotation" id="rot270" value="270"/> 270 </label>' +
        '                    <label id="label_rotationArbitrary" class="textbox">' +
        '                        &#8212; <strong>other:</strong> ' +
        '                        <input type="text" name="img_rotation" maxlength="3" size="3" id="rot_other" value=""/>' +
        '                    </label>' +
        '                </p>' +
        '                <p class="image-options">' +
        '                <label for="marginalia">Marginalia in this reading trace?</label> <input type="radio" id="yes" name="marginalia" value="yes"> <label for="yes">Yes</label> <input type="radio" id="no" name="marginalia" value="no" checked> <label for="no">No</label>' +
        '                </p>' +
        '                <p class="image-options"><a data-toggle="modal" data-target="#previewModal">' +
        '                     <button id="zone-tool-previewButton">preview zone image</button>' +
        '                </a></p>' +
        '                <p class="image-options"><span style="font-weight:bold;">2. Zone OK? Paste this <code>&lt;zone&gt;</code> element into <code>library.xml</code> inside the <code>&lt;page&gt;</code> numbered <code>' + pageID.split("-_-").join(" ") + '</code> in <code>' + bookID + '</code>.</span></p>' +
        '                <input type="hidden" id="multiplier" name="multiplier"/>' +
        '                    <div class="textarea-container"><textarea class="iiif_link" type="text" name="iiif_textarea" id="iiif_textarea" readonly="readonly"></textarea><button id="zone-tool-copyButton">copy to clipboard</button></div>' +
        '            </div>' +
        '        </form>' +
        '        <p><a href="../' + bookID + '.html?page=' + pageID + '"><button class="admin-tools-back-button">back to book view</button></a></p>' +
        '        <p><span style="font-weight:bold;">Other pages in this book: </span><select onchange="javascript:location.href = this.value;" id="select-page"><option>-</option></p>' +
        '    </div>';
        
        /* inject HTML */
        $("#cropping_tool").append(image_selection).append(image_navbox);
        
        $.each(images, function(index, value) {
            var option = $("<option></option>").text(value);
            option.attr("value", "?pageID=" + bookID + "," + value);
            $("#select-page").append(option);
        });
        
        /*  var imageID = getParameterByName('imageID');*/
        
        /* get metadata about requested image from IIIF server */
        var info_url = imageID + '/info.json';
        var result = {
        };
        
        $.ajax({
            async: true,
            url: info_url,
            dataType: "json",
            statusCode: {
                400: function () {
                    alert('400 status code! user error');
                    console.log('HTTP 400: Bad request');
                    showImageInfoLoadError(400);
                },
                401: function () {
                    console.log('HTTP 401: Not authorised');
                    showImageInfoLoadError(401);
                },
                403: function () {
                    console.log('HTTP 403: Forbidden');
                    showImageInfoLoadError(403);
                },
                404: function () {
                    console.log('HTTP 404: Not found');
                    showImageInfoLoadError(404);
                },
                500: function () {
                    console.log('HTTP 500: Server error');
                    showImageInfoLoadError(500);
                }
            },
            error: function (xhr) {
                console.log(xhr.status + ': request for image metadata failed with URL ' + info_url);
                showImageLoadError();
            },
            success: function (data) {
                result = data;
                getImageData();
            }
        });
        
        function showImageInfoLoadError(status_code) {
            $("#set-select-all").hide();
            switch (status_code) {
                case 400:
                $("#target").attr("src", "400-bad-request.png");
                break;
                case 401:
                $("#target").attr("src", "img/401-unauthorized.png");
                break;
                case 403:
                $("#target").attr("src", "img/403-forbidden.png");
                break;
                case 404:
                $("#target").attr("src", "img/404-not-found.png");
                break;
                case 500:
                $("#target").attr("src", "img/500-server-error.png");
                break;
                default:
                $("#target").attr("src", "400-bad-request.png");
            }
            return true;
        }
        
        function getParameterByName(name, url) {
            if (! url) url = window.location.href;
            name = name.replace(/[\[\]]/g, "\\$&");
            var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
            results = regex.exec(url);
            if (! results) return null;
            if (! results[2]) return '';
            return results[2].replace(/\+/g, "%20");
        }
        
        function preload(arrayOfImages) {
            $(arrayOfImages).each(function () {
                $('<img/>')[0].src = this;
            });
        }
        
        function getImageData() {
            /* image info from info.json */
            var width = result.width;
            var height = result.height;
            var multiplier = (width / 680);
            $("#multiplier").val(multiplier);
            
            /* get image height and width ; use setInterval to account for latency */
            
            function get_target_details() {
                var img_display_size = document.getElementById('target');
                if (img_display_size.clientWidth == undefined) {
                    return false;
                }
                return img_display_size;
            }
            
            var iiif_rotation = '0';
            var iiif_format = '.jpg';
            var iiif_quality = 'default';
            var sizeAboveFull = false;
            
            /* API v. 1.0 and 1.1 use 'native' rather than 'default' */
            
            if (result[ '@context'] !== undefined) {
                if (result[ '@context'].match(/image\-api\/1\.1/) || result[ '@context'].match(/image\-api\/1\.0/)) {
                    iiif_quality = 'native';
                }
            } else if (result.qualities !== undefined) {
                iiif_quality = 'native';
            }
            
            if (result.profile.constructor == Array) {
                $.each(result.profile, function (index, value) {
                    if (value.formats !== undefined) {
                        $.each(value.formats, function (item, format) {
                            var attr_id = '#label_' + format;
                            $(attr_id).removeClass("hidden");
                        });
                    }
                    if (value.qualities !== undefined) {
                        $.each(value.qualities, function (item, quality) {
                            var attr_id = '#label_' + quality;
                            $(attr_id).removeClass("hidden");
                        });
                    }
                    if (value.maxWidth !== undefined) {
                        /* treat the maxWidth value as the actual width */
                        width = value.maxWidth;
                        if (width > 1280) {
                            var attr_id = 'label_' + '1280';
                            $(attr_id).addClass("hidden");
                        }
                        if (width > 1024) {
                            var attr_id = 'label_' + '1024';
                            $(attr_id).addClass("hidden");
                        }
                        if (width > 800) {
                            var attr_id = 'label_' + '800';
                            $(attr_id).addClass("hidden");
                        }
                        if (width > 400) {
                            var attr_id = 'label_' + '400';
                            $(attr_id).addClass("hidden");
                        }
                    }
                    if (value.supports !== undefined) {
                        $.each(value.supports, function (item, supported) {
                            if (supported == 'mirroring') {
                                var attr_id = '#label_' + supported;
                                $(attr_id).removeClass("hidden");
                            } else if (supported == 'rotationArbitrary') {
                                var attr_id = '#label_' + supported;
                                $(attr_id).removeClass("hidden");
                            } else if (supported == 'regionSquare') {
                                var attr_id = '#label_' + supported;
                                $(attr_id).removeClass("hidden");
                            } else if (supported == 'sizeAboveFull') {
                                sizeAboveFull = true;
                            }
                            /*
                             * other properties to support:
                             *     rotationBy90s
                             *     regionSquare
                             */
                        });
                    }
                });
            }
            
            var iiif_width;
            if (width < 680) {
                iiif_width = width + ',';
            } else {
                iiif_width = '680,';
            }
            
            var getTargetDetails, img_display_width, img_display_height;
            
            var getTargetInterval = setInterval(function () {
                getTargetDetails = get_target_details();
                if (getTargetDetails.clientWidth !== undefined) {
                    clearInterval(getTargetInterval);
                } else {
                    img_display_width = getTargetDetails.clientWidth;
                    img_display_height = getTargetDetails.clientHeight;
                }
            },
            500);
            
            /* image details for display on page */
            
            if (imageID !== undefined) {
                var uri_decoded = imageID + '/full/' + iiif_width + '/' + iiif_rotation + '/' + iiif_quality + iiif_format;
                preload([uri_decoded]);
                var loadImage = $('#target').attr("src", uri_decoded);
                
                var image_status = waitForImage();
                if (loadImage.naturalWidth !== "undefined" && loadImage.naturalWidth === 0) {
                    $('#target').attr("src", "img/404-not-found.png");
                    return false;
                }
                if (loadImage[0].complete && loadImage[0].naturalHeight !== 0) {
                    if (image_status == true) {
                        setSelectJcrop();
                    }
                } else {
                    loadImage.load(setSelectJcrop());
                }
                function setSelectJcrop() {
                    if (sel_x == undefined) {
                        return false;
                    }
                    $('#target').Jcrop({
                        setSelect:[sel_x, sel_y, sel_x1, sel_y1]
                    });
                }
            }
            
            $("input:radio[name=img_width]").click(function () {
                iiif_width = $(this).val() + ',';
            });
            
            $("input:text[name=img_width_other]").change(function () {
                if ($(this).val() == 'full') {
                    iiif_width = 'full';
                } else {
                    if ($(this).val() > width && sizeAboveFull == false) {
                        alert("Maximum allowed width is " + width + " pixels");
                        $("input[name='img_width_other']").val(width);
                        iiif_width = width + ',';
                    } else {
                        iiif_width = $(this).val() + ',';
                    }
                }
            });
            
            /* arbitrary image rotation */
            $("input:text[name=img_rotation]").change(function () {
                var degrees = $(this).val();
                if ((degrees + "").match(/^\d+$/)) {
                    if (degrees < 361) {
                        iiif_rotation = degrees;
                    } else {
                        console.log('bad value for image rotation');
                    }
                } else {
                    console.log('bad value for image rotation');
                }
            });
            
            $("input:radio[name=img_rotation]").click(function () {
                iiif_rotation = $(this).val();
            });
            $("input[name=img_format]").click(function () {
                iiif_format = $(this).val();
            });
            $("input[name=img_quality]").click(function () {
                iiif_quality = $(this).val();
            });
            
           var zone_xml_start =
                '<!-- zone -->\n' +
                '<zone>\n' +
                '   <number>1</number>\n' +
                '   <facsimile>';
           
          
           
           var zone_xml_middle =
                '</facsimile>\n' +
                '   <position>';
                
           var zone_xml_end =
                '</position>\n' +
                '   <rn>\n' +
                '     <transcription></transcription>\n' +
                '     <writingtool></writingtool>\n' +
                '     <extracts></extracts>\n' +
                '   </rn>\n';
            
            var d = document, ge = 'getElementById';
            
            $('#interface').on('cropmove cropend', function (e, s, c) {
                var iiif_region = Math.round((c.x * multiplier)) + ',' + Math.round(c.y * multiplier) + ',' + Math.round(c.w * multiplier) + ',' + Math.round(c.h * multiplier);
                
                var marginalia = $('input[name="marginalia"]:checked').val() === 'yes' ? '   <type>marginalia</type>\n' : '';
                
                $('#get_url').attr('data-mfp-src', imageID + '/' + iiif_region + '/' + iiif_width + '/' + iiif_rotation + '/' + iiif_quality + iiif_format);
                $('.img_download').attr('href', imageID + '/' + iiif_region + '/' + iiif_width + '/' + iiif_rotation + '/' + iiif_quality + iiif_format);
                $('#iiif_textarea').val(zone_xml_start + imageID + '/' + iiif_region + '/500,/' + iiif_rotation + '/' + iiif_quality + iiif_format + zone_xml_middle + c.y + zone_xml_end + marginalia + '</zone>');
                
                $('#ZoneImagePreview').attr('src', imageID + '/' + iiif_region + '/850,/' + iiif_rotation + '/' + iiif_quality + iiif_format)
                
                $("#zone-tool-copyButton").click(function() {
                var temp = $("<textarea/>");
                $("body").append(temp);
                temp.text(zone_xml_start + imageID + '/' + iiif_region + '/500,/' + iiif_rotation + '/' + iiif_quality + iiif_format + zone_xml_middle + c.y + zone_xml_end + marginalia + '</zone>').select();
                document.execCommand("copy");
                var originalText = "copy to clipboard";
                $(this).text(originalText.replace("copy to clipboard", "copied!"));
                var that = this;
                setTimeout(function() {
                    $(that).text(originalText);
                }, 2000);
                temp.remove();
                });
                
                d[ge]('crop-x').value = c.x;
                d[ge]('crop-y').value = Math.round(c.y);
                d[ge]('crop-w').value = c.w;
                d[ge]('crop-h').value = c.h;
            });
            
            /* set selection coords */
            var sel_x = Math.round(img_display_width / 4);
            var sel_y = Math.round(img_display_height / 4);
            var sel_x1 = Math.round(img_display_width / 2);
            var sel_y1 = Math.round(img_display_height / 2);
            
            $(".select_all").click(function () {
                console.log('select_all');
                if (img_display_height == 0) {
                    var getTargetDetails = get_target_details();
                    img_display_width = getTargetDetails.clientWidth;
                    img_display_height = getTargetDetails.clientHeight;
                }
                $('#target').Jcrop('api').animateTo([
                0, 0, img_display_width, img_display_height]);
            });
            
            var src;
            if (imageID !== undefined) {
                src = imageID + '/full/680,/0/' + iiif_quality + '.jpg';
            }
            
            $('#text-inputs').on('change', 'input', function (e) {
                $('#target').Jcrop('api').animateTo([
                parseInt(d[ge]('crop-x').value),
                parseInt(d[ge]('crop-y').value),
                parseInt(d[ge]('crop-w').value),
                parseInt(d[ge]('crop-h').value)]);
            });
            
            /* there can be significant latency loading the image, so ... */
            function waitForImage() {
                img_display_size = document.getElementById('target');
                if (img_display_size.clientWidth > 0) {
                    //console.log('image loaded...')
                    $('p.wait-spinner').hide();
                    img_display_width = img_display_size.clientWidth;
                    img_display_height = img_display_size.clientHeight;
                    var sel_x = Math.round(img_display_width / 4);
                    var sel_y = Math.round(img_display_height / 4);
                    var sel_x1 = Math.round(img_display_width / 2);
                    var sel_y1 = Math.round(img_display_height / 2);
                    $('#target').Jcrop({
                        setSelect:[sel_x, sel_y, sel_x1, sel_y1]
                    });
                } else {
                    setTimeout(function () {
                        waitForImage();
                    },
                    250);
                }
                return true;
            }
            
            if (img_display_width > 0) {
                $('p.wait-spinner').hide();
            } else {
                var tmp = waitForImage();
            }
        }
        
        /* popup a preview image */
        $('#get_url').magnificPopup({
            type: 'image'
        });
        
        /* initialise boostrap tooltips */
        $(function () {
            $('[data-toggle="tooltip"]').tooltip()
        })
        
    }
}

$(document).ready(function () {
    croptool.init();
    
    
});
