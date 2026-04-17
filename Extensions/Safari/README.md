# Splynek — Safari integration

Safari's "Web Extensions" are packaged as `.appex` bundles inside a
host app, which requires an Xcode project. Splynek currently builds
from Swift Package Manager only, so we ship **bookmarklets** instead:
zero-install, drag-to-bookmarks-bar, one-click hand-off.

Open `bookmarklets.html` in Safari and drag the buttons onto your
Bookmarks Bar. The app's *About → Extensions* section does this for
you — it opens the bundled copy of `bookmarklets.html` in your
default browser.

## What the bookmarklets do

They all construct a `splynek://` URL with the current page (or a
resolved link's href) and navigate to it. Safari asks once per
scheme for permission to launch the associated app; tick *Always
allow* to make it silent from then on.

## When a proper Safari App Extension might land

When (if) the project migrates from SPM to an Xcode project, we can
ship a `.appex` that does everything the Chrome extension does —
per-link context menus, toolbar button, keyboard shortcut,
integration with Safari's built-in download panel. Tracked as an
open item in `HANDOFF.md`.
