# AutoLedger App Store Screenshot Export

This folder contains a repeatable local pipeline for App Store screenshots and App Preview keyframe preparation. It captures deterministic screenshot-mode screens from the iOS, iPad, Mac Catalyst, tvOS, and visionOS apps, and when available the Watch app, then renders store-ready PNGs and a local `preview.html`.

The same raw and store PNGs can be handed to Hyperframes or another video tool as keyframes for an App Store App Preview. This screenshot pipeline only generates assets; reviewed outputs can be uploaded with the separate helpers in `tools/asc-metadata/`.

## Supported Output

- iPhone: zh-Hans, zh-Hant, en, and ja, default 6.5-inch App Store size `1242x2688`.
- iPad: zh-Hans, zh-Hant, en, and ja, default 13-inch landscape App Store size `2732x2048`.
- Mac Catalyst: zh-Hans, zh-Hant, en, and ja, default desktop capture size `1440x900`.
- Apple Watch: zh-Hans, zh-Hant, en, and ja when the Watch scheme and a usable Watch simulator pair are available.
- Apple TV: zh-Hans, zh-Hant, en, and ja, default 4K landscape App Store size `3840x2160`.
- visionOS: zh-Hans, zh-Hant, en, and ja, default landscape marketing size `3840x2160`.

The pipeline does not itself upload to App Store Connect or directly create official App Preview videos. App Preview / Hyperframes production material lives in `tools/appstore-screenshots/app-preview/`, while upload and ASC state verification live in `tools/asc-metadata/`.

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

Only Apple TV:

```bash
bash tools/appstore-screenshots/scripts/export.sh --tvos-only
```

Only visionOS:

```bash
bash tools/appstore-screenshots/scripts/export.sh --visionos-only
```

Limit to one locale:

```bash
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --ipad-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --mac-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --tvos-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --visionos-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hant
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale en
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale ja
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale ko
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

The ASC 1.6.0 v003 project now generates one 22-second iPhone App Preview for each current release language from a shared Hyperframes composition and an original deterministic score:

```text
tools/appstore-screenshots/app-preview/
  README.md
  hyperframes-v003/
  preview_script_zh-Hans.md
  hyperframes_brief_zh-Hans.md
  shotlist_zh-Hans.md
  export_requirements.md
```

Recommended source export:

```bash
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --watch-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale ja
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale ko
```

Current five-language render:

```bash
cd tools/appstore-screenshots/app-preview/hyperframes-v003
npm run sync-assets
npm run render-all
```

`sync-assets` selects OCR, voice, hotel, Watch, monthly report, and Pro captures for `en-US`, `zh-Hans`, `zh-Hant`, `ja`, and `ko`, then generates the sample-free `Quiet Control` score. Final MP4 files are `886x1920`, 22 seconds, 30 fps, H.264 High Profile Level 4.0 with target 11 Mbps video and AAC 48 kHz stereo audio. Generated assets and renders remain ignored. The five v003 files were uploaded to ASC 1.6.0 on 2026-07-18 and verified by MD5 plus `videoDeliveryState=COMPLETE`; their poster frames use the reviewed OCR frame at `1.4s / 00:00:01:12`, and all generated frame states read back as `COMPLETE`.

Recommended folders to hand to Hyperframes:

```text
tools/appstore-screenshots/output/store/ios/zh-Hans
tools/appstore-screenshots/output/raw/ios/zh-Hans
tools/appstore-screenshots/output/store/watch/zh-Hans
tools/appstore-screenshots/output/raw/watch/zh-Hans
tools/appstore-screenshots/output/store/{platform}/ko/
tools/appstore-screenshots/output/raw/{platform}/ko/
```

Suggested App Store asset review order:

1. iPhone App Preview
2. iPhone screenshots
3. Apple Watch screenshots
4. iPad screenshots
5. Mac screenshots
6. Apple TV screenshots
7. visionOS screenshots

## Output Layout

Generated files are written under `tools/appstore-screenshots/output/`, which is ignored by git:

```text
output/
  raw/
    ios/{zh-Hans,zh-Hant,en,ja,ko}/
    ipad/{zh-Hans,zh-Hant,en,ja,ko}/
    mac/{zh-Hans,zh-Hant,en,ja,ko}/
    watch/{zh-Hans,zh-Hant,en,ja,ko}/
    tvos/{zh-Hans,zh-Hant,en,ja,ko}/
    visionos/{zh-Hans,zh-Hant,en,ja,ko}/
  store/
    ios/{zh-Hans,zh-Hant,en,ja,ko}/
    ipad/{zh-Hans,zh-Hant,en,ja,ko}/
    mac/{zh-Hans,zh-Hant,en,ja,ko}/
    watch/{zh-Hans,zh-Hant,en,ja,ko}/
    tvos/{zh-Hans,zh-Hant,en,ja,ko}/
    visionos/{zh-Hans,zh-Hant,en,ja,ko}/
  preview.html
```

`reference/` is for human notes only. Scripts do not depend on reference images.

## Configuration

Edit `config/screenshots.json` to change schemes, bundle IDs, device candidates, target sizes, locales, scenes, and marketing copy.
The `capture.themePreset` and `capture.colorScheme` fields are passed into iPhone screenshot mode so the exported language set does not depend on the simulator's last selected appearance.
Platform-specific export scripts pass `--platform` into `render_marketing.py`, so `--ios-only` renders only iPhone store images and does not warn about missing iPad, Mac, Apple TV, or visionOS raw captures.

Detected defaults in this project:

- iOS workspace: `AutoLedger/AutoLedger.xcworkspace`
- iOS scheme: `AutoLedger`
- iOS bundle ID: `top.darkrio326.AutoLedger`
- Watch scheme: `AutoLedgerWatch Watch App`
- Watch bundle ID: `top.darkrio326.AutoLedger.watchkitapp`
- Apple TV scheme: `AutoLedgerTV`
- Apple TV bundle ID: `top.darkrio326.AutoLedger` (same App Store Connect app record as iPhone / iPad)
- visionOS scheme: `AutoLedgerVision`
- visionOS bundle ID: `top.darkrio326.AutoLedger` (same App Store Connect app record as iPhone / iPad)

## iPhone Scenes

The iOS app supports screenshot mode:

```text
--screenshot-mode
--screenshot-platform ios
--screenshot-scene preview|ocr_bill|quick_capture|voice_entry|watch_ecosystem|import_methods|auto_extract|review_edit|monthly_report|settings_management|email_folio_import|cloud_folio_inbox|hotel_stays|pro_subscription
--screenshot-theme classic
--screenshot-color-scheme light
```

To add a scene:

1. Add a case to `ScreenshotScene`.
2. Add the view branch in `ScreenshotHostView`.
3. Add an entry to `iosShots` in `screenshots.json`.
4. Run `bash tools/appstore-screenshots/scripts/export.sh --ios-only`.

The screenshot host uses fixed fixtures and does not read the real ledger database, start OCR, access camera/photos, request notifications, or load LLM models.

The `ocr_bill`, `voice_entry`, and `watch_ecosystem` scenes are screenshot-only fixtures. They do not request photo library, camera, microphone, OCR, speech recognition, WatchConnectivity, network, iCloud, or LLM access.

## Apple Watch Scenes

The Watch app supports screenshot mode:

```text
--screenshot-mode
--screenshot-platform watch
--screenshot-scene watch_quick_add|watch_recent|watch_complication|watch_sync
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
--screenshot-scene workspace_review|workspace_capture|workspace_ledger|workspace_hotel|workspace_reports|workspace_cleaning
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
--screenshot-scene mac_capture|mac_ledger|mac_hotel|mac_reports|mac_cleaning|mac_settings
```

To add a scene:

1. Extend the Mac scene mapping in `ScreenshotHostView`.
2. Add an entry to `macShots` in `screenshots.json`.
3. Run `bash tools/appstore-screenshots/scripts/export.sh --mac-only`.

## Apple TV Scenes

The tvOS app supports screenshot mode by reading the launch scene and selecting the matching read-only dashboard tab:

```text
--screenshot-mode
--screenshot-platform tvos
--screenshot-scene overview|categories|trends|summary
```

To add a scene:

1. Extend the `TVDashboardPage.screenshotInitialPage` mapping in `AutoLedgerTV/ContentView.swift`.
2. Add an entry to `tvosShots` in `screenshots.json`.
3. Run `bash tools/appstore-screenshots/scripts/export.sh --tvos-only`.

The tvOS screenshot path uses DEBUG simulator fictional data when iCloud is unavailable. It remains read-only and does not import, edit, delete, or write ledger data.

## visionOS Scenes

The visionOS app supports screenshot mode by reading the launch scene and arranging the first window for the selected marketing view:

```text
--screenshot-mode
--screenshot-platform visionos
--screenshot-scene dashboard|categories|timeline
```

To add a scene:

1. Extend `VisionScreenshotScene` in `AutoLedgerVision/ContentView.swift`.
2. Add an entry to `visionosShots` in `screenshots.json`.
3. Run `bash tools/appstore-screenshots/scripts/export.sh --visionos-only`.

The visionOS screenshot path uses DEBUG simulator fictional data when iCloud is unavailable. It remains read-only and does not import, edit, delete, or write ledger data.

## Sizes

iPhone defaults to `ios_65` (`1242x2688`). To switch to the reserved 6.9-inch target, enable `targets.ios_69`, update `render_marketing.py` target selection if needed, and ensure the selected simulator produces suitable raw screenshots.

iPad defaults to `ipad_13` (`2732x2048`). The renderer keeps the workspace screenshot inside a fixed landscape marketing canvas and fits the screenshot without vertically cropping the workspace.

Mac defaults to `mac_desktop` (`1440x900`). The exporter launches the built Mac Catalyst app, resizes the front window with AppleScript, and captures that window rectangle from the desktop.

Watch defaults to `410x502` in `targets.watch`. The render step keeps all zh-Hans, zh-Hant, en, ja, and ko Watch store screenshots at that exact size. If the simulator produces a slightly different raw size, `render_watch.py` fits it into the configured canvas without stretching.

Apple TV and visionOS default to `3840x2160` in `targets.tvos` and `targets.visionos`. The renderer places the simulator capture inside a marketing canvas with title and subtitle copy.

## Manual Watch Fallback

If automatic Watch launch fails, iPhone export still succeeds and `preview.html` shows the skipped reason. You can manually capture Watch raw images by:

1. Build and launch the Watch app in Xcode or Simulator.
2. Navigate to the intended screenshot-mode or real Watch screen.
3. Save PNGs using these names:
   - `output/raw/watch/zh-Hans/00_watch_quick_add.png`
   - `output/raw/watch/zh-Hans/01_watch_recent.png`
   - `output/raw/watch/zh-Hans/02_watch_complication.png`
   - `output/raw/watch/zh-Hans/03_watch_sync.png`
   - same names under `output/raw/watch/zh-Hant/`, `output/raw/watch/en/`, `output/raw/watch/ja/`, and `output/raw/watch/ko/`
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
- Apple TV export cannot find the app: confirm `AutoLedgerTV` shared scheme exists and the target builds for an Apple TV simulator.
- visionOS export cannot find the app: confirm `AutoLedgerVision` shared scheme exists and the target builds for an Apple Vision Pro simulator.
- First screenshot is black or white: capture scripts retry incomplete frames before writing raw PNGs; if it still happens, increase `capture.stabilizeSeconds`.
- UI text looks oversized: screenshot hosts pin Dynamic Type to the default `.large` size, independent of the simulator's Accessibility text size.
- Permission prompts appear: screenshot host should not call camera, photo library, OCR, notifications, iCloud, or network paths; check any newly added scene for live dependencies.
- Chinese font looks wrong: install or restore the macOS system PingFang fonts. The renderer falls back with a warning.
- Korean font looks wrong: confirm `/System/Library/Fonts/AppleSDGothicNeo.ttc` is available. The renderer uses its Bold and Regular faces for `ko` marketing copy, then falls back to Noto Sans Gothic or Apple Gothic.
- English copy overflows: edit `screenshots.json`; `render_marketing.py` wraps text, but very long words may still need shorter copy.
- Raw and final Watch dimensions differ: `render_watch.py` logs the conversion and outputs the configured size.

## Not Implemented

- App Store Connect API upload.
- Direct official App Preview video generation. Hyperframes production material is provided under `app-preview/`.
- Figma or Canva integration.
- Real OCR or real user data capture.
