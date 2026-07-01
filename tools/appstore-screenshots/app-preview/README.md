# AutoLedger App Preview Materials

This directory contains planning material and Hyperframes source projects for App Store App Preview video production.

## Current Material

- ASC 1.5.0 current preview: `hyperframes-v002/renders/app_preview_iphone_zh-Hans_asc1.5.0_v002.mp4`
- ASC 1.5.0 English preview: `hyperframes-v002-en/renders/app_preview_iphone_en_asc1.5.0_v002.mp4`
- ASC 1.5.0 source projects: `hyperframes-v002`, `hyperframes-v002-en`
- ASC 1.4.0 preserved preview: `archive/asc-1.4.0/renders/app_preview_iphone_zh-Hans_asc1.4.0_v001.mp4`
- ASC 1.4.0 editable source remains: `hyperframes-v001`

## Store Screenshot Artifact Policy

Generated screenshot outputs remain ignored under:

```text
tools/appstore-screenshots/output/
```

For ASC 1.5.0, the current `store/` PNG set is about 68 MB across 74 files, while `raw/` is about 142 MB. Do not commit the entire generated `output/` folder into normal Git history.

Recommended retention:

1. Keep screenshot scripts, screenshot configs, App Preview source projects, rendered preview videos, keyframes, and contact sheets in Git.
2. Upload final ASC store screenshots as a GitHub Release artifact or versioned zip when release evidence needs to be preserved.
3. If screenshots must be committed to the repository, commit only curated `store/` PNGs for the exact ASC release, never `raw/` captures.

## Recommended Workflow

1. Export iPhone screenshots with the existing screenshot pipeline.
2. Copy the needed store PNGs into the active Hyperframes project `assets/`.
3. Update `index.html`, `DESIGN.md`, `preview_script_zh-Hans.md`, and `shotlist_zh-Hans.md` together.
4. Run Hyperframes checks.
5. Render the MP4 and extract keyframes / contact sheet for visual review.
6. Manually upload the finished video to App Store Connect.

Recommended export command:

```bash
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans
```

Recommended source folders:

```text
tools/appstore-screenshots/output/store/ios/zh-Hans
tools/appstore-screenshots/output/raw/ios/zh-Hans
```

Current render commands:

```bash
cd tools/appstore-screenshots/app-preview/hyperframes-v002
npm run check
npm run render -- --output renders/app_preview_iphone_zh-Hans_asc1.5.0_v002.mp4 --fps 30 --quality standard

cd ../hyperframes-v002-en
npm run check
npm run render -- --output renders/app_preview_iphone_en_asc1.5.0_v002.mp4 --fps 30 --quality standard
```

Current outputs:

```text
tools/appstore-screenshots/app-preview/hyperframes-v002/renders/app_preview_iphone_zh-Hans_asc1.5.0_v002.mp4
tools/appstore-screenshots/app-preview/hyperframes-v002-en/renders/app_preview_iphone_en_asc1.5.0_v002.mp4
```

Do not include real payment screenshots, receipts, account data, card numbers, order numbers, phone numbers, API keys, certificates, profiles, or private user data in App Preview assets.
