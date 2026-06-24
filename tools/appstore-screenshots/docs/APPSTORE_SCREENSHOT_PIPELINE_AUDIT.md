# AutoLedger App Store Screenshot Pipeline Audit

Date: 2026-06-17

This audit records the current state of the existing `tools/appstore-screenshots` pipeline. It is intentionally scoped to the current pipeline and does not introduce a parallel marketing or App Store asset system.

## Supported Platforms

- iPhone
- iPadOS
- Mac Catalyst
- Apple Watch
- Apple TV
- visionOS

tvOS and visionOS were added after the initial audit. They use their own app targets and simulator captures, then reuse the same marketing renderer and `preview.html` output.

## Supported Locales

- `zh-Hans`
- `zh-Hant`
- `en`

Locale values are defined in `tools/appstore-screenshots/config/screenshots.json` and passed to the app through `-AppleLanguages` and `-AppleLocale`.

## Current iPhone Scenes

Screenshot mode arguments:

```text
--screenshot-mode
--screenshot-platform ios
--screenshot-scene <scene>
```

Current scenes:

- `preview`
- `ocr_bill`
- `quick_capture`
- `voice_entry`
- `watch_ecosystem`
- `import_methods`
- `auto_extract`
- `review_edit`
- `monthly_report`
- `settings_management`

Current configured iPhone shots:

- `00_ocr_bill` -> `ocr_bill`
- `01_voice_entry` -> `voice_entry`
- `02_watch_ecosystem` -> `watch_ecosystem`
- `03_monthly_report` -> `monthly_report`
- `04_icloud_sync` -> `settings_management`
- `05_shortcuts_import` -> `import_methods`

## Current iPad Scenes

Screenshot mode arguments:

```text
--screenshot-mode
--screenshot-platform ipad
--screenshot-scene <scene>
```

Current configured iPad shots:

- `00_workspace_overview` -> `workspace_review`
- `01_workspace_capture` -> `workspace_capture`
- `02_workspace_ledger` -> `workspace_ledger`
- `03_workspace_reports` -> `workspace_reports`
- `04_workspace_cleaning` -> `workspace_cleaning`

The iPad screenshot host uses the existing iPad workspace fixture and does not access the real ledger database.

## Current Mac Scenes

Screenshot mode arguments:

```text
--screenshot-mode
--screenshot-platform mac
--screenshot-scene <scene>
```

Current configured Mac shots:

- `00_mac_capture` -> `mac_capture`
- `01_mac_reports` -> `mac_reports`
- `02_mac_cleaning` -> `mac_cleaning`
- `03_mac_settings` -> `mac_settings`

Mac Catalyst capture launches the built Mac app, resizes the window with AppleScript, captures the window area, and then renders store-ready PNGs.

## Current Apple Watch Scenes

Screenshot mode arguments:

```text
--screenshot-mode
--screenshot-platform watch
--screenshot-scene <scene>
```

Current scenes:

- `watch_quick_add`
- `watch_recent`
- `watch_complication`
- `watch_sync`

Current configured Watch shots:

- `00_watch_quick_add` -> `watch_quick_add`
- `01_watch_recent` -> `watch_recent`
- `02_watch_complication` -> `watch_complication`
- `03_watch_sync` -> `watch_sync`

The `02_watch_complication` slot renders a static screenshot-mode complication preview. A real watch face complication screenshot can still be captured manually when an App Store listing needs the exact face chrome.

## What The Scripts Automate

- Build the iOS app for an available iPhone simulator.
- Launch the app in screenshot mode for each configured iPhone scene and locale.
- Capture raw iPhone screenshots into `output/raw/ios/<locale>/`.
- Build and capture iPad scenes into `output/raw/ipad/<locale>/`.
- Build and capture Mac Catalyst scenes into `output/raw/mac/<locale>/` when local Accessibility permission allows window control.
- Build and capture Apple Watch scenes when a usable Watch simulator pair is available.
- Render iPhone, iPad, and Mac marketing PNGs with `render_marketing.py`.
- Render Watch PNGs with `render_watch.py`.
- Generate `output/preview.html` with `build_preview.py`.

## What Still Requires Manual Work

- Uploading screenshots to App Store Connect.
- Creating or uploading official App Preview videos.
- Capturing real Apple Watch face complication screenshots if the automatic Watch app screenshot is not enough.
- Checking App Store Connect metadata, privacy text, review notes, and final platform ordering.
- Reviewing generated screenshots for layout, text wrapping, cropped UI, and locale-specific fit.
- Verifying that no real payment screenshot, receipt, account, order number, phone number, card number, or private user data is included.

## App Preview Video Status

The current pipeline does not directly generate official App Preview videos. It can export raw and store PNGs that are suitable as keyframes or source material for Hyperframes, Remotion, ffmpeg, or a manual video workflow.

This round adds App Preview production documents under:

```text
tools/appstore-screenshots/app-preview/
```

## Hyperframes Fit

The pipeline is suitable for Hyperframes as a source of deterministic keyframes:

- Store screenshots provide polished marketing frames.
- Raw screenshots provide clean UI captures for animation and cropping.
- Watch screenshots can be mixed into the iPhone App Preview sequence.
- Mock payment or receipt assets must remain fictional and privacy-safe.

Hyperframes should remain optional. The repository should not require a Hyperframes login, CLI, or external service to run the screenshot export pipeline.

## Minimum Safe Change Scope For This Round

- Update `tools/appstore-screenshots/config/screenshots.json` copy and shot ordering.
- Add lightweight `ocr_bill` and `voice_entry` screenshot-only scenes using static fixtures.
- Update existing screenshot fixtures with fictional marketing sample data only.
- Add App Preview / Hyperframes planning documents inside `tools/appstore-screenshots/app-preview/`.
- Update `tools/appstore-screenshots/README.md` with execution instructions.

Out of scope:

- No App Store Connect changes.
- No certificate, profile, entitlement, signing, Bundle ID, or target changes.
- No real screenshot, receipt, OCR, LLM, iCloud, network, camera, photo library, or microphone access in screenshot mode.
- No new parallel `marketing/` or `appstore/` directory tree.
