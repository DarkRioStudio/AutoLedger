# AutoLedger App Store Screenshot Export

This folder contains a repeatable local pipeline for App Store screenshots and App Preview keyframe preparation. It captures deterministic screenshot-mode screens from the iOS, iPad, and Mac Catalyst app, and when available the Watch app, then renders store-ready PNGs and a local `preview.html`.

The same raw and store PNGs can be handed to Hyperframes or another video tool as keyframes for an App Store App Preview. This repository still does not upload assets to App Store Connect.

## Supported Output

- iPhone: zh-Hans, zh-Hant, and en, default 6.5-inch App Store size `1242x2688`.
- iPad: zh-Hans, zh-Hant, and en, default 13-inch landscape App Store size `2732x2048`.
- Mac Catalyst: zh-Hans, zh-Hant, and en, default desktop capture size `1440x900`.
- Apple Watch: zh-Hans, zh-Hant, and en when the Watch scheme and a usable Watch simulator pair are available.

The pipeline does not upload to App Store Connect or directly create official App Preview videos. App Preview / Hyperframes production material lives in `tools/appstore-screenshots/app-preview/`.

## Run

From the repo root:

```bash
bash tools/appstore-screenshots/scripts/export.sh
```

Only iPhone:

```bash
bash tools/appstore-screenshots/scripts/export.sh --ios-only
```

Only iPad:

```bash
bash tools/appstore-screenshots/scripts/export.sh --ipad-only
```

Only Mac:

```bash
bash tools/appstore-screenshots/scripts/export.sh --mac-only
```

Only Apple Watch:

```bash
bash tools/appstore-screenshots/scripts/export.sh --watch-only
```

Limit to one locale:

```bash
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --ipad-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --mac-only --locale zh-Hans
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

## App Preview / Hyperframes

This repository does not directly generate the official App Preview video. It now provides production material for a 15-20 second Hyperframes workflow:

```text
tools/appstore-screenshots/app-preview/
  README.md
  preview_script_zh-Hans.md
  hyperframes_brief_zh-Hans.md
  shotlist_zh-Hans.md
  export_requirements.md
```

Recommended source export:

```bash
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --watch-only --locale zh-Hans
```

Recommended folders to hand to Hyperframes:

```text
tools/appstore-screenshots/output/store/ios/zh-Hans
tools/appstore-screenshots/output/raw/ios/zh-Hans
tools/appstore-screenshots/output/store/watch/zh-Hans
tools/appstore-screenshots/output/raw/watch/zh-Hans
```

Suggested App Store asset review order:

1. iPhone App Preview
2. iPhone screenshots
3. Apple Watch screenshots
4. iPad screenshots
5. Mac screenshots

## Output Layout

Generated files are written under `tools/appstore-screenshots/output/`, which is ignored by git:

```text
output/
  raw/
    ios/{zh-Hans,zh-Hant,en}/
    ipad/{zh-Hans,zh-Hant,en}/
    mac/{zh-Hans,zh-Hant,en}/
    watch/{zh-Hans,zh-Hant,en}/
  store/
    ios/{zh-Hans,zh-Hant,en}/
    ipad/{zh-Hans,zh-Hant,en}/
    mac/{zh-Hans,zh-Hant,en}/
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
--screenshot-scene preview|ocr_bill|quick_capture|voice_entry|import_methods|auto_extract|review_edit|monthly_report|settings_management
```

To add a scene:

1. Add a case to `ScreenshotScene`.
2. Add the view branch in `ScreenshotHostView`.
3. Add an entry to `iosShots` in `screenshots.json`.
4. Run `bash tools/appstore-screenshots/scripts/export.sh --ios-only`.

The screenshot host uses fixed fixtures and does not read the real ledger database, start OCR, access camera/photos, request notifications, or load LLM models.

The `ocr_bill` and `voice_entry` scenes are screenshot-only fixtures. They do not request photo library, camera, microphone, OCR, speech recognition, network, iCloud, or LLM access.

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

## iPad Scenes

The iOS app screenshot host also supports iPad workspace scenes:

```text
--screenshot-mode
--screenshot-platform ipad
--screenshot-scene workspace_review|workspace_capture|workspace_ledger|workspace_reports|workspace_cleaning
```

To add a scene:

1. Extend `IPadWorkspaceSection` or the screenshot workspace host mapping.
2. Add a new scene mapping in `ScreenshotHostView`.
3. Add an entry to `ipadShots` in `screenshots.json`.
4. Run `bash tools/appstore-screenshots/scripts/export.sh --ipad-only`.

## Mac Scenes

Mac Catalyst capture uses the same screenshot workspace host, but launches a local Mac app window and crops that window from the desktop:

```text
--screenshot-mode
--screenshot-platform mac
--screenshot-scene mac_capture|mac_ledger|mac_reports|mac_cleaning|mac_settings
```

To add a scene:

1. Extend the Mac scene mapping in `ScreenshotHostView`.
2. Add an entry to `macShots` in `screenshots.json`.
3. Run `bash tools/appstore-screenshots/scripts/export.sh --mac-only`.

## Sizes

iPhone defaults to `ios_65` (`1242x2688`). To switch to the reserved 6.9-inch target, enable `targets.ios_69`, update `render_marketing.py` target selection if needed, and ensure the selected simulator produces suitable raw screenshots.

iPad defaults to `ipad_13` (`2732x2048`). The renderer keeps the workspace screenshot inside a fixed landscape marketing canvas and fits the screenshot without vertically cropping the workspace.

Mac defaults to `mac_desktop` (`1440x900`). The exporter launches the built Mac Catalyst app, resizes the front window with AppleScript, and captures that window rectangle from the desktop.

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

The current automatic Watch pipeline does not capture a real watch face complication. If the App Store listing needs the complication itself, capture that image manually from a real Watch or simulator face and use it as supplemental App Store / App Preview material.

## Common Issues

- Missing simulator: install an iOS or watchOS simulator in Xcode, or add the local device name to `deviceCandidates`.
- Missing Watch simulator pair: create a paired iPhone + Apple Watch simulator in Xcode.
- `xcodebuild` failure: open `AutoLedger/AutoLedger.xcworkspace`, not the `.xcodeproj`, and verify CocoaPods are installed.
- App opens the real home screen: confirm `--screenshot-mode --screenshot-platform ios --screenshot-scene ...` is passed to `simctl launch`.
- iPad screenshot is blank white or still loading: the capture scripts retry incomplete frames; if it still happens, increase `capture.stabilizeSeconds` or use a screenshot scene with stable fixture content.
- Mac export is skipped: enable Accessibility permission for the terminal or Codex app so `System Events` can move and resize the AutoLedger window before `screencapture`.
- Watch does not enter screenshot mode: confirm the Watch app bundle ID and launch arguments in `screenshots.json`.
- First screenshot is black or white: capture scripts retry incomplete frames before writing raw PNGs; if it still happens, increase `capture.stabilizeSeconds`.
- UI text looks oversized: screenshot hosts pin Dynamic Type to the default `.large` size, independent of the simulator's Accessibility text size.
- Permission prompts appear: screenshot host should not call camera, photo library, OCR, notifications, iCloud, or network paths; check any newly added scene for live dependencies.
- Chinese font looks wrong: install or restore the macOS system PingFang fonts. The renderer falls back with a warning.
- English copy overflows: edit `screenshots.json`; `render_marketing.py` wraps text, but very long words may still need shorter copy.
- Raw and final Watch dimensions differ: `render_watch.py` logs the conversion and outputs the configured size.

## Not Implemented

- App Store Connect API upload.
- Direct official App Preview video generation. Hyperframes production material is provided under `app-preview/`.
- tvOS screenshots.
- visionOS screenshots.
- Figma or Canva integration.
- Real OCR or real user data capture.
