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

$('#addIIIF').on('change', function() {
    if ($(this).is(':checked')) {
        $('#IIIFfieldset').removeClass('hidden');
    } else {
        $('#IIIFfieldset').addClass('hidden');
        $('#IIIFfieldset input').val('');
    }
});

$('#IIIFmanifest').on('input', function() {
    if ($(this).val() === '') {
        $('#new-book-import-iiif').addClass('hidden');
    } else {
        $('#new-book-import-iiif').removeClass('hidden');
    }
});

// start up XML rendering in a <textarea> of the information
// in the input fields 
$('#confirm-ID-button').on('click', function() {
     $('#confirmed-bookID').val($('#bookID').val());
     $('#biblio-module').removeClass('hidden');
     $('#choose-ID').addClass('hidden');
     $('#textarea-div').removeClass('hidden');
     var xmlStringBibl = `<module type="bibl">
        <author sort="">
            <firstname/>
            <lastname/>
        </author>
        <title sort=""/>
        <subtitle/>
        <type></type>
        <volume/>
        <series/>
        <edition/>
        <editor/>
        <place/>
        <publisher/>
        <date/>
        <generalnote/>
        <location/>
</module>`;
    
    var addBookOpener = '<book id="' + $('#confirmed-bookID').val() + '" type="' + $("input[name='ELVL']:checked").val() +'">\n';
    var addBookCloser = '\n</book>';
    var newXml = addBookOpener + xmlStringBibl + addBookCloser;
    var xmlDoc = $.parseXML(newXml);
    var $xml = $(xmlDoc);
    
    // update the XML when changes are made
    $('input:not(#bookID), textarea, select').on('input', function() {
        var name = $(this).attr('name');
        var value = $(this).val();
        $xml.find(name).text(value);
        if (name === 'lastname') {
            var sortValue = removeAccents(value.substring(0, 15));
            sortValue = sortValue.charAt(0).toUpperCase() + sortValue.slice(1);
            $xml.find('author').attr('sort', sortValue);
        }
        if (name === 'title') {
            var sortValue = removeAccents(value.substring(0, 15));
            sortValue = sortValue.charAt(0).toUpperCase() + sortValue.slice(1);
            $xml.find('title').attr('sort', sortValue);
        }
        if ($('#addIIIF').is(':checked') && $xml.find('IIIF').length === 0) {
            var iiifElement = xmlDoc.createElement('IIIF');
            var iiifManifestElement = xmlDoc.createElement('IIIFmanifest');
            var iiifViewerElement = xmlDoc.createElement('IIIFviewer');
            iiifElement.appendChild(iiifManifestElement);
            iiifElement.appendChild(iiifViewerElement);
            $xml.find('module').append(iiifElement);
        } else if (!$('#addIIIF').is(':checked')) {
            $xml.find('IIIF').remove();
        }
        
        $('#new-book-import-iiif').off('click').on('click', function() {
        var manifest = $('#IIIFmanifest').val();
        $.get('$app/modules/import-iiif.xql', {manifest: manifest})
           .done(function(data) {
            var xmlString = new XMLSerializer().serializeToString(data);
            // Parse the xmlString into an XML document
            var parser = new DOMParser();
            var xmlData = parser.parseFromString(xmlString, "text/xml");
            // Import the XML data into xmlDoc
            var importedNode = xmlDoc.importNode(xmlData.documentElement, true);
            // Get the <module> child element from the root element of importedNode
            var moduleNode = importedNode.getElementsByTagName('module')[0];
            // Get the <Creator> element from importedNode
            var lastnameNode;
            try {
                lastnameNode = importedNode.getElementsByTagName('Creator')[0].textContent;
            } catch (e) {
                console.log("Creator element not found");
            }
            // Get the <Date> element from importedNode
            var dateNode;
            try {
                dateNode = importedNode.getElementsByTagName('Date')[0].textContent;
            } catch (e) {
                console.log("Date element not found");
            }
            // Get the <Title> element from importedNode
            var titleNode;
            try {
                titleNode = importedNode.getElementsByTagName('Title')[0].textContent;
            } catch (e) {
                console.log("Title element not found");
            }
            // Get the <Relation> element from importedNode
            var locationNode;
            try {
                locationNode = importedNode.getElementsByTagName('Relation')[0].textContent;
            } catch (e) {
                console.log("Relation element not found");
            }
            // Append the <module> child element to the <book> element in xmlDoc
            $xml.find('book').append(moduleNode);
            $('#lastname').val(lastnameNode);
            $('#date').val(dateNode);
            $('#title').val(titleNode);
            $('#location').val(locationNode);
            $('#IIIFmanifest').trigger('input');
            $('#lastname').trigger('input');
            $('#date').trigger('input');
            $('#title').trigger('input');
            $('#location').trigger('input');
            }, 'text')
            .fail(function(jqXHR, textStatus, errorThrown) {
                alert('Import failed. Check the manifest URL for errors!');
            });
        });
        

        
        $('#new-book-textarea').val((new XMLSerializer()).serializeToString(xmlDoc));
       

    });
    
    // add universal IIIF viewer link in IIIFviewer
        $('#IIIFmanifest').on('input', function() {
            var manifestValue = $(this).val();
            $('#IIIFviewer').val("https://uv-v4.netlify.app/#?manifest=" + manifestValue);
            $xml.find('IIIFviewer').text("https://uv-v4.netlify.app/#?manifest=" + manifestValue);
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