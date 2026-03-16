$(document).ready(function() {
    console.log('Admin library manager loaded');
    console.log('Button found:', $('.js-create-library').length);

    // HELPERS — lock/unlock the Create Library form and export dropdown during export
    function lockCreateForm() {
        $('#newLibraryName, #newLibraryId').prop('disabled', true);
        $('.js-create-library')
            .prop('disabled', true)
            .attr('title', 'Cannot create a library while export is running');
        $('#exportLibrarySelect').prop('disabled', true);
    }

    function unlockCreateForm() {
        $('#newLibraryName, #newLibraryId').prop('disabled', false);
        $('.js-create-library')
            .prop('disabled', false)
            .removeAttr('title');
        $('#exportLibrarySelect').prop('disabled', false);
    }

    // RESTORE EXPORT STATE on modal open
    function checkExistingExport() {
        var libraryId = $('#exportLibrarySelect').val();
        if (!libraryId) return;

        $.get('$app/modules/library-api.xql', {
            action: 'export-status',
            libraryId: libraryId
        })
        .done(function(data) {
            if (data.state === 'running') {
                var $button = $('.js-start-export');
                lockCreateForm();
                $button.prop('disabled', true).html('Exporting<span class="exporting-dots"></span>');
                $('#export-progress-area').show();
                $('#export-complete-area').hide();
                $('#export-error-area').hide();
                updateProgress(data);
                startPolling(libraryId, $button);
            } else if (data.state === 'complete') {
                showExportComplete(data, libraryId, $('.js-start-export'));
            }
            // pending/error/no file: leave modal in default state
        })
        .fail(function() {
            // No status file yet — nothing to restore
        });
    }

    $('#collectionsModal').on('show.bs.modal', function() {
        checkExistingExport();
    });

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

    // EXPORT TO STATIC SITE
    var exportPollInterval = null;

    $('.js-start-export').on('click', function() {
        var $button = $(this);
        var libraryId = $('#exportLibrarySelect').val();
        if (!libraryId) {
            alert('Please select a library to export');
            return;
        }

        lockCreateForm(); // prevent library creation during export
        $button.prop('disabled', true).html('Exporting<span class="exporting-dots"></span>');
        $('#export-progress-area').show();
        $('#export-complete-area').hide();
        $('#export-error-area').hide();
        $('#export-progress-bar').css('width', '0%').text('0%').attr('aria-valuenow', 0);
        $('#export-status-message').text('Starting export...');
        $('#export-detail').text('');

        $.get('$app/modules/library-api.xql', {
            action: 'start-export',
            libraryId: libraryId
        })
        .done(function(data) {
            if (data.success) {
                startPolling(libraryId, $button);
            } else {
                unlockCreateForm();
                showExportError(data.message, $button);
            }
        })
        .fail(function(jqXHR, textStatus) {
            unlockCreateForm();
            showExportError('Request failed: ' + textStatus, $button);
        });
    });

    function startPolling(libraryId, $button) {
        window.onbeforeunload = function() {
            return 'An export is in progress. If you leave, the export will continue on the server but you will lose progress tracking.';
        };
        exportPollInterval = setInterval(function() {
            $.get('$app/modules/library-api.xql', {
                action: 'export-status',
                libraryId: libraryId
            })
            .done(function(data) {
                updateProgress(data);
                if (data.state === 'complete') {
                    clearInterval(exportPollInterval);
                    window.onbeforeunload = null;
                    unlockCreateForm();
                    showExportComplete(data, libraryId, $button);
                } else if (data.state === 'error') {
                    clearInterval(exportPollInterval);
                    window.onbeforeunload = null;
                    unlockCreateForm();
                    showExportError(data.message, $button);
                }
            })
            .fail(function() {
                // Don't stop polling on a single failed request
            });
        }, 3000);
    }

    function updateProgress(data) {
        var pct = data.pct || 0;
        $('#export-progress-bar')
            .css('width', pct + '%')
            .text(pct + '%')
            .attr('aria-valuenow', pct);
        $('#export-status-message').text(data.message || '');
        $('#export-detail').text(
            'Books: ' + (data.booksOk || 0) + ' ok, ' + (data.booksFailed || 0) + ' failed  |  ' +
            'Browse: ' + (data.browseOk || 0) + ' ok, ' + (data.browseFailed || 0) + ' failed'
        );
    }

    function showExportComplete(data, libraryId, $button) {
        $('#export-progress-bar')
            .css('width', '100%')
            .text('100%');
        $('#export-progress-area').hide();
        $('#export-complete-area').show();
        $('#export-complete-message').text(' ' + data.message);
        $('.js-download-zip').data('library-id', libraryId);
        $button.prop('disabled', false).html('Export');
    }

    function showExportError(message, $button) {
        $('#export-progress-area').hide();
        $('#export-error-area').show();
        $('#export-error-message').text(message);
        $button.prop('disabled', false).html('Export');
    }

    // DOWNLOAD ZIP
    $('.js-download-zip').on('click', function() {
        var libraryId = $(this).data('library-id');
        if (!libraryId) return;

        var $button = $(this);
        $button.prop('disabled', true).text('Creating ZIP...');

        $.get('$app/modules/library-api.xql', {
            action: 'create-zip',
            libraryId: libraryId
        })
        .done(function(data) {
            if (data.success) {
            var appRoot = window.location.pathname.split('/writerslibrary')[0] + '/writerslibrary';
            var $a = $('<a>')
                .attr('href', appRoot + '/modules/download-zip.xql?libraryId=' + libraryId)
                .attr('download', libraryId + '-static-export.zip');
                $('body').append($a);
                $a[0].click();
                $a.remove();
                $button.prop('disabled', false).text('Download ZIP');
            } else {
                alert('Error creating ZIP: ' + data.message);
                $button.prop('disabled', false).text('Download ZIP');
            }
        })
        .fail(function(jqXHR, textStatus) {
            alert('Error: ' + textStatus);
            $button.prop('disabled', false).text('Download ZIP');
        });
    });

});
