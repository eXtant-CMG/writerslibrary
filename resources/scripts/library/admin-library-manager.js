$(document).ready(function() {
    console.log('Admin library manager loaded');
    console.log('Button found:', $('.js-create-library').length);

// ADD NEW LIBRARY FEATURE
    $('.js-create-library').on('click', function() {
        console.log('Button clicked!');
        
        var $button = $(this);
        var libraryId = $('#newLibraryId').val().trim();
        var libraryName = $('#newLibraryName').val().trim();
        
        if (!libraryId || !libraryName) {
            alert('Please fill in both fields');
            return;
        }
        
        $button.prop('disabled', true).text('Creating...');
        
        $.get('$app/modules/library-api.xql', {
            action: 'create',
            libraryId: libraryId,
            libraryName: libraryName
        })
        .done(function(data) {
            if (data.success) {
                alert('Library created successfully!');
                location.reload();
            } else {
                alert('Error: ' + data.message);
                $button.prop('disabled', false).text('Create');
            }
        })
        .fail(function(jqXHR, textStatus, errorThrown) {
            alert('Error creating library: ' + textStatus);
            $button.prop('disabled', false).text('Create');
        });
    });
});