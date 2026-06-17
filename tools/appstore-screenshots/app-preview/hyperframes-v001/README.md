# AutoLedger Hyperframes App Preview v001

This project is a Hyperframes source package for the first Chinese iPhone App Preview draft.

It uses only local, generated App Store screenshot assets from `tools/appstore-screenshots/output/` plus the app icon. It does not access App Store Connect, iCloud, network APIs, real user data, camera, microphone, OCR, or LLM services.

## Composition

- Project: `hyperframes-v001`
- Main file: `index.html`
- Size: `886x1920`
- Duration: `20s`
- Locale: `zh-Hans`
- Output target: iPhone App Store Preview draft

## Narrative

1. Pain point: daily spending is annoying to enter manually.
2. OCR: screenshots and receipts become expense records.
3. Voice: one sentence creates a ready-to-save record.
4. Watch: quick wrist entry and iPhone continuation.
5. Report: monthly spending summary and final product lockup.

## Source Assets

- `assets/ios_ocr_bill.png` from iPhone zh-Hans store screenshot `00_ocr_bill`
- `assets/ios_open_bill.png` from iPhone zh-Hans store screenshot `00_ocr_bill`, duplicated as a separate opening keyframe asset
- `assets/ios_voice_entry.png` from iPhone zh-Hans store screenshot `01_voice_entry`
- `assets/ios_watch_ecosystem.png` from iPhone zh-Hans store screenshot `02_watch_ecosystem`
- `assets/ios_monthly_report.png` from iPhone zh-Hans store screenshot `03_monthly_report`
- `assets/ios_shortcuts_import.png` from iPhone zh-Hans store screenshot `05_shortcuts_import`
- `assets/watch_quick_add.png` from Watch zh-Hans store screenshot `00_watch_quick_add`
- `assets/watch_sync.png` from Watch zh-Hans store screenshot `03_watch_sync`
- `assets/app_icon.png` from the local app icon asset catalog
- `assets/app_preview_bed_v001.m4a` is generated through the existing EverestBaseCamp audio pipeline, then normalized to AAC LC / 48kHz / stereo for App Store preview upload

## Commands

```bash
cd tools/appstore-screenshots/app-preview/hyperframes-v001
npm run check
npm run dev -- --port 3017
npm run render -- --output renders/app_preview_iphone_zh-Hans_v001.mp4 --fps 30 --quality standard
```

FFmpeg is required for MP4 rendering.

## v001 Rendered Output

- MP4: `renders/app_preview_iphone_zh-Hans_v001.mp4`
- Keyframes: `renders/keyframes/preview_00_opening.png` through `preview_04_report.png`
- Contact sheet: `renders/keyframes/contact_sheet.png`
