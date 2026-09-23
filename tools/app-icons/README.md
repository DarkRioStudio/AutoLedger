# AutoLedger App Icon Tools

All platforms use the approved Locked A artwork in `sources/`. The iPhone/iPad light and dark PNGs remain pixel-identical to the approved master; tinted uses its luminance. Mac Catalyst has explicit 16–1024 pixel catalog slots from that same master.

Watch and visionOS scale the original SVG composition to fit a circular mask. tvOS keeps the same artwork centered in its wide icon and Top Shelf images. The depth stacks separate the original background, white card and card contents; they do not redraw a different logo.

## Regenerate

Requires Python Pillow, Node and the pinned build-time SVG renderer:

```sh
npm ci --prefix tools/app-icons
python3 tools/app-icons/generate_app_icons.py
python3 tools/app-icons/validate_app_icons.py
python3 tools/app-icons/preview_app_icons.py
```

The renderer is a development dependency only. Generated PNGs are checked in; Xcode/CI does not install npm packages to build the app. Inspect the preview with platform masks, then compile the changed asset catalogs with Xcode actool. Validation covers dimensions, catalog references, opaque bases, foreground presence and unchanged iPhone master pixels. Bundle identifiers, signing, entitlements and version numbers are unchanged.
