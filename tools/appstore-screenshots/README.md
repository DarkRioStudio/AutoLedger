# AutoLedger App Store Screenshot Export

This folder contains a repeatable local pipeline for App Store screenshots. It captures deterministic screenshot-mode screens from the iOS app and, when available, the Watch app, then renders store-ready PNGs and a local `preview.html`.

## Supported Output

- iPhone: zh-Hans, zh-Hant, and en, default 6.5-inch App Store size `1242x2688`.
- Apple Watch: zh-Hans, zh-Hant, and en when the Watch scheme and a usable Watch simulator pair are available.

The pipeline does not upload to App Store Connect, create official App Preview videos, or generate iPad screenshots.

## Run

From the repo root:

```bash
bash tools/appstore-screenshots/scripts/export.sh
```

Only iPhone:

```bash
bash tools/appstore-screenshots/scripts/export.sh --ios-only
```

Only Apple Watch:

```bash
bash tools/appstore-screenshots/scripts/export.sh --watch-only
```

Limit to one locale:

```bash
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hant
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale en
```

Re-render from existing raw screenshots:

```bash
python3 tools/appstore-screenshots/scripts/render_marketing.py
python3 tools/appstore-screenshots/scripts/render_watch.py
python3 tools/appstore-screenshots/scripts/build_preview.py
```

Open the preview:

```bash
open tools/appstore-screenshots/output/preview.html
```

## Output Layout

Generated files are written under `tools/appstore-screenshots/output/`, which is ignored by git:

```text
output/
  raw/
    ios/{zh-Hans,zh-Hant,en}/
    watch/{zh-Hans,zh-Hant,en}/
  store/
    ios/{zh-Hans,zh-Hant,en}/
    watch/{zh-Hans,zh-Hant,en}/
  preview.html
```

`reference/` is for human notes only. Scripts do not depend on reference images.

## Configuration

Edit `config/screenshots.json` to change schemes, bundle IDs, device candidates, target sizes, locales, scenes, and marketing copy.

Detected defaults in this project:

- iOS workspace: `AutoLedger/AutoLedger.xcworkspace`
- iOS scheme: `AutoLedger`
- iOS bundle ID: `top.darkrio326.AutoLedger`
- Watch scheme: `AutoLedgerWatch Watch App`
- Watch bundle ID: `top.darkrio326.AutoLedger.watchkitapp`

## iPhone Scenes

The iOS app supports screenshot mode:

```text
--screenshot-mode
--screenshot-platform ios
--screenshot-scene preview|quick_capture|import_methods|auto_extract|review_edit|monthly_report|settings_management
```

To add a scene:

1. Add a case to `ScreenshotScene`.
2. Add the view branch in `ScreenshotHostView`.
3. Add an entry to `iosShots` in `screenshots.json`.
4. Run `bash tools/appstore-screenshots/scripts/export.sh --ios-only`.

The screenshot host uses fixed fixtures and does not read the real ledger database, start OCR, access camera/photos, request notifications, or load LLM models.

## Apple Watch Scenes

The Watch app supports screenshot mode:

```text
--screenshot-mode
--screenshot-platform watch
--screenshot-scene watch_quick_add|watch_recent|watch_confirm|watch_sync
```

To add a scene:

1. Add a case to `WatchScreenshotScene`.
2. Add the view branch in `WatchScreenshotHostView`.
3. Add an entry to `watchShots` in `screenshots.json`.
4. Run `bash tools/appstore-screenshots/scripts/export.sh --watch-only`.

Watch screenshot mode is isolated from `WatchSessionManager`, so it does not depend on iPhone reachability or WatchConnectivity state.

## Sizes

iPhone defaults to `ios_65` (`1242x2688`). To switch to the reserved 6.9-inch target, enable `targets.ios_69`, update `render_marketing.py` target selection if needed, and ensure the selected simulator produces suitable raw screenshots.

Watch defaults to `410x502` in `targets.watch`. The render step keeps all zh-Hans, zh-Hant, and en Watch store screenshots at that exact size. If the simulator produces a slightly different raw size, `render_watch.py` fits it into the configured canvas without stretching.

## Manual Watch Fallback

If automatic Watch launch fails, iPhone export still succeeds and `preview.html` shows the skipped reason. You can manually capture Watch raw images by:

1. Build and launch the Watch app in Xcode or Simulator.
2. Navigate to the intended screenshot-mode or real Watch screen.
3. Save PNGs using these names:
   - `output/raw/watch/zh-Hans/00_watch_quick_add.png`
   - `output/raw/watch/zh-Hans/01_watch_recent.png`
   - `output/raw/watch/zh-Hans/02_watch_confirm.png`
   - `output/raw/watch/zh-Hans/03_watch_sync.png`
   - same names under `output/raw/watch/zh-Hant/` and `output/raw/watch/en/`
4. Run:

```bash
python3 tools/appstore-screenshots/scripts/render_watch.py
python3 tools/appstore-screenshots/scripts/build_preview.py
```

## Common Issues

- Missing simulator: install an iOS or watchOS simulator in Xcode, or add the local device name to `deviceCandidates`.
- Missing Watch simulator pair: create a paired iPhone + Apple Watch simulator in Xcode.
- `xcodebuild` failure: open `AutoLedger/AutoLedger.xcworkspace`, not the `.xcodeproj`, and verify CocoaPods are installed.
- App opens the real home screen: confirm `--screenshot-mode --screenshot-platform ios --screenshot-scene ...` is passed to `simctl launch`.
- Watch does not enter screenshot mode: confirm the Watch app bundle ID and launch arguments in `screenshots.json`.
- First screenshot is black: capture scripts retry mostly black frames before writing raw PNGs; if it still happens, increase `capture.stabilizeSeconds`.
- UI text looks oversized: screenshot hosts pin Dynamic Type to the default `.large` size, independent of the simulator's Accessibility text size.
- Permission prompts appear: screenshot host should not call camera, photo library, OCR, notifications, iCloud, or network paths; check any newly added scene for live dependencies.
- Chinese font looks wrong: install or restore the macOS system PingFang fonts. The renderer falls back with a warning.
- English copy overflows: edit `screenshots.json`; `render_marketing.py` wraps text, but very long words may still need shorter copy.
- Raw and final Watch dimensions differ: `render_watch.py` logs the conversion and outputs the configured size.

## Not Implemented

- App Store Connect API upload.
- Official App Preview video.
- iPad screenshots.
- Figma or Canva integration.
- Real OCR or real user data capture.
