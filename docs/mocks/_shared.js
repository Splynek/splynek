/* Splynek IA mocks — shared behavior.
   Subview chip switching (CSS class swap), sheet open/close,
   moderator-mode banner via ?moderator=1 URL param. */

(function () {
  // ── Moderator banner ───────────────────────────────────────────
  if (new URLSearchParams(window.location.search).get('moderator') === '1') {
    document.body.classList.add('moderator');
  }

  // ── Subview chip switching ─────────────────────────────────────
  // Each .chip in the toolbar has data-subview="<id>"; each .subview
  // in the content area has data-subview="<id>".  Clicking a chip
  // swaps active state.
  document.querySelectorAll('.chips').forEach(group => {
    group.querySelectorAll('.chip').forEach(chip => {
      chip.addEventListener('click', e => {
        const id = chip.dataset.subview;
        if (!id) return;
        group.querySelectorAll('.chip').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        document.querySelectorAll('.subview').forEach(v => {
          v.classList.toggle('active', v.dataset.subview === id);
        });
        // Update the URL hash so the moderator can see the state.
        history.replaceState(null, '', '#' + id);
      });
    });
  });

  // ── On load: respect URL hash for deep-linkable subviews ───────
  if (window.location.hash) {
    const id = window.location.hash.slice(1);
    const target = document.querySelector(`.chip[data-subview="${id}"]`);
    if (target) target.click();
  }

  // ── Sheet open/close ───────────────────────────────────────────
  // <button data-open-sheet="settings"> opens #sheet-settings,
  // <button data-close-sheet> closes the nearest .sheet-backdrop.
  document.querySelectorAll('[data-open-sheet]').forEach(btn => {
    btn.addEventListener('click', e => {
      const sheetId = btn.dataset.openSheet;
      const sheet = document.getElementById('sheet-' + sheetId);
      if (sheet) sheet.classList.add('open');
    });
  });
  document.querySelectorAll('.sheet-backdrop').forEach(bd => {
    bd.addEventListener('click', e => {
      if (e.target === bd) bd.classList.remove('open');
    });
    bd.querySelectorAll('[data-close-sheet]').forEach(btn => {
      btn.addEventListener('click', () => bd.classList.remove('open'));
    });
  });

  // ── Escape closes sheets ───────────────────────────────────────
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
      document.querySelectorAll('.sheet-backdrop.open').forEach(bd =>
        bd.classList.remove('open')
      );
    }
  });
})();
