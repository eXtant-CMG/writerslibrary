// Browse entry chips: one open panel per entry.
document.addEventListener('click', function (e) {
    var chip = e.target.closest('.entry-chip[aria-controls]');
    if (!chip) return;
    var wasOpen = chip.getAttribute('aria-expanded') === 'true';
    chip.closest('.entry-chips-wrap').querySelectorAll('.entry-chip[aria-controls]').forEach(function (c) {
        c.setAttribute('aria-expanded', 'false');
        document.getElementById(c.getAttribute('aria-controls')).hidden = true;
    });
    if (!wasOpen) {
        chip.setAttribute('aria-expanded', 'true');
        document.getElementById(chip.getAttribute('aria-controls')).hidden = false;
    }
});

// Book page panels: each opens and closes on its own.
document.addEventListener('click', function (e) {
    var head = e.target.closest('.book-panel-head[aria-controls]');
    if (!head) return;
    var open = head.getAttribute('aria-expanded') !== 'true';
    head.setAttribute('aria-expanded', String(open));
    document.getElementById(head.getAttribute('aria-controls')).hidden = !open;
});
