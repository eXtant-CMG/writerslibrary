$(document).ready(function() {

// book ID validation on uniqueness and well-formedness
    var bookID = $('#bookID').val();
    $.get('$app/modules/check-id.xql', {bookID: bookID}, function(data) {
        if (data.toString() === 'true') {
            $('#response').text('✔').removeClass("error");
        }
        else {
            $('#response').text('ID already exists').addClass("error");
        }
    }, 'text');

    $('#bookID').on('input', function() {
        bookID = $('#bookID').val();
        if (bookID === "") {
            $("#response").text("please supply an ID").addClass("error");
        } else if (!/^[a-zA-Z]/.test(bookID)) {
            $("#response").text("ID must begin with a regular letter").addClass("error");
        } else {
            $.get('$app/modules/check-id.xql', {bookID: bookID}, function(data) {
                if (data.toString() === 'true') {
                    $('#response').text('✔').removeClass("error");
                }
                else {
                    $('#response').text('ID already exists').addClass("error");
                }
            }, 'text');
        };
    });

// Show/hide IIIF fieldset
    $('#addIIIF').on('change', function() {
        if ($(this).is(':checked')) {
            $('#IIIFfieldset').removeClass('hidden');
        } else {
            $('#IIIFfieldset').addClass('hidden');
            $('#IIIFfieldset input').val('');
            $('#importIIIFImages').prop('checked', false);
        }
    });

// Show prefill button and auto-fill viewer URL when manifest is entered
    $('#IIIFmanifest').on('input', function() {
        var manifestValue = $(this).val();
        if (manifestValue !== '') {
            $('#IIIFviewer').val("https://uv-v4.netlify.app/#?manifest=" + manifestValue);
            $('#prefill-from-iiif').removeClass('hidden');
        } else {
            $('#IIIFviewer').val('');
            $('#prefill-from-iiif').addClass('hidden');
        }
    });

// Pre-fill metadata fields from IIIF manifest
    $('#prefill-from-iiif').on('click', function() {
        var manifest = $('#IIIFmanifest').val();
        $.get('$app/modules/import-iiif.xql', {manifest: manifest})
            .done(function(data) {
                try { $('#lastname').val(data.getElementsByTagName('Creator')[0].textContent); } catch(e) {}
                try { $('#date').val(data.getElementsByTagName('Date')[0].textContent); } catch(e) {}
                try { $('#title').val(data.getElementsByTagName('Title')[0].textContent); } catch(e) {}
                try { $('#location').val(data.getElementsByTagName('Relation')[0].textContent); } catch(e) {}
                $('#prefill-response').text('Metadata extracted').removeClass('error');
            })
            .fail(function() {
                $('#prefill-response').text('Could not fetch manifest. Check the URL for errors!').addClass('error');
            });
    });

// Check page count when import images checkbox is ticked
    $('#importIIIFImages').on('change', function() {
        if (!$(this).is(':checked')) {
            $('#import-images-response').text('');
            return;
        }
        var manifest = $('#IIIFmanifest').val();
        if (manifest === '') {
            $('#import-images-response').text('Please enter a manifest URL first.').addClass('error');
            $(this).prop('checked', false);
            return;
        }
        $('#import-images-response').text('Checking…').removeClass('error');
        $.get('$app/modules/import-iiif.xql', {manifest: manifest})
            .done(function(data) {
                var pages = data.getElementsByTagName('page').length;
                if (pages > 0) {
                    $('#import-images-response').text(pages + ' pages will be imported').removeClass('error');
                } else {
                    $('#import-images-response').text('No pages found in manifest.').addClass('error');
                    $('#importIIIFImages').prop('checked', false);
                }
            })
            .fail(function() {
                $('#import-images-response').text('Could not fetch manifest.').addClass('error');
                $('#importIIIFImages').prop('checked', false);
            });
    });

// Save book: POST form fields directly to server
    $('#save-book-button').on('click', function() {
        var $button = $(this);
        var libraryId = window.location.pathname.split('/writerslibrary/')[1].split('/')[0];

        $button.prop('disabled', true).text('Saving...');
        $('#save-response').text('').removeClass('error success');

        $.post('$app/modules/library-api.xql', {
            action:            'create-book',
            libraryId:         libraryId,
            bookId:            $('#bookID').val(),
            bookType:          $("input[name='ELLL']:checked").val(),
            firstname:         $('#firstname').val(),
            lastname:          $('#lastname').val(),
            title:             $('#title').val(),
            subtitle:          $('#subtitle').val(),
            type:              $('#type').val(),
            volume:            $('#volume').val(),
            series:            $('#series').val(),
            edition:           $('#edition').val(),
            editor:            $('#editor').val(),
            place:             $('#place').val(),
            publisher:         $('#publisher').val(),
            date:              $('#date').val(),
            generalnote:       $('#generalnote').val(),
            location:          $('#location').val(),
            iiifManifest:      $('#IIIFmanifest').val(),
            iiifViewer:        $('#IIIFviewer').val(),
            importIIIFImages:  $('#importIIIFImages').is(':checked') ? 'true' : 'false'
        }, function(data) {
            if (data.success) {
                $('#save-response').text('✔ ' + data.message).addClass('success');
            } else {
                $('#save-response').text('Error: ' + data.message).addClass('error');
            }
            $button.prop('disabled', false).text('Save to library');
        }, 'json')
            .fail(function() {
                $('#save-response').text('Request failed — check your connection.').addClass('error');
                $button.prop('disabled', false).text('Save to library');
            });
    });

// for the separate "Import image links from a IIIF manifest" tool
    $('#iiif-manifest-link-submit').on('click', function() {
        $('#link-container').removeClass('hidden');
        var manifest = $('#iiif-manifest-link').val();
        $.get('$app/modules/import-iiif.xql', {manifest: manifest})
            .done(function(data) {
                var moduleElement = data.getElementsByTagName('module')[0];
                var xmlString = new XMLSerializer().serializeToString(moduleElement);
                $('#iiif-manifest-link-textarea').val(xmlString);
            })
            .fail(function(jqXHR, textStatus, errorThrown) {
                alert('Error: check the manifest URL for errors!');
            });
    });


// remove accented letters
    function removeAccents(str) {
        var accents = "ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÐðÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž'";
        var accentsOut = "AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcDdIIIIiiiiUUUUuuuuNnSsYyyZz ";
        str = str.split('');
        var strLen = str.length;
        var i, x;
        for (i = 0; i < strLen; i++) {
            if ((x = accents.indexOf(str[i])) != -1) {
                str[i] = accentsOut[x];
            }
        }
        return str.join('');
    }

});