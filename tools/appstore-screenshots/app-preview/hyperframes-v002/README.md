# AutoLedger Hyperframes App Preview v002

This project is a Hyperframes source package for the ASC 1.5.0 Chinese iPhone App Preview.

It uses only local, generated App Store screenshot assets from `tools/appstore-screenshots/output/` plus the app icon. It does not access App Store Connect, iCloud, network APIs, real user data, camera, microphone, OCR, or LLM services.

## Composition

- Project: `hyperframes-v002`
- Main file: `index.html`
- Size: `886x1920`
- Duration: `22s`
- Locale: `zh-Hans`
- Output target: iPhone App Store Preview for ASC 1.5.0

## Narrative

1. Opening: AutoLedger prepares candidate bills and the user confirms them.
2. Quick ledger: screenshots and one-sentence entry become ready-to-save records.
3. Hotel spending: hotel folio details are reviewed before writing to the ledger.
4. AutoLedger Pro: mailbox scanning, dedicated inbox, and batch candidate organization are presented as automation.
5. Report: monthly spending summary and final product lockup.

## Source Assets

- `assets/ios_ocr_bill.png` from iPhone zh-Hans store screenshot `00_ocr_bill`
- `assets/ios_voice_entry.png` from iPhone zh-Hans store screenshot `01_voice_entry`
- `assets/ios_watch_ecosystem.png` from iPhone zh-Hans store screenshot `02_watch_ecosystem`
- `assets/ios_monthly_report.png` from iPhone zh-Hans store screenshot `03_monthly_report`
- `assets/ios_hotel_stays.png` from iPhone zh-Hans store screenshot `06_hotel_stays`
- `assets/ios_autoledger_pro.png` from iPhone zh-Hans store screenshot `07_autoledger_pro`
- `assets/app_icon.png` from the local app icon asset catalog
- `assets/app_preview_bed_v002.m4a` is the ASC 1.5.0 preview background bed, derived from the existing quiet App Preview bed and faded for this timeline

## Commands

```bash
cd tools/appstore-screenshots/app-preview/hyperframes-v002
npm run check
npm run dev -- --port 3018
npm run render -- --output renders/app_preview_iphone_zh-Hans_asc1.5.0_v002.mp4 --fps 30 --quality standard
```

FFmpeg is required for MP4 rendering.

## v002 Rendered Output

- MP4: `renders/app_preview_iphone_zh-Hans_asc1.5.0_v002.mp4`
- Keyframes: `renders/keyframes/preview_00_opening.png` through `preview_04_report.png`
- Contact sheet: `renders/keyframes/contact_sheet.png`
