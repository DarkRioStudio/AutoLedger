# AutoLedger App Preview Materials

This directory contains planning material and Hyperframes source projects for App Store App Preview video production.

## Current Material

- ASC 1.6.0 current five-language source: `hyperframes-v003`
- ASC 1.6.0 local outputs: `hyperframes-v003/renders/final/app_preview_iphone_{en-US,zh-Hans,zh-Hant,ja,ko}_asc1.6.0_v003.mp4`
- ASC 1.6.0 audio: original deterministic 22-second score generated from `hyperframes-v003/score-manifest.json`; no third-party samples or reused v002 music
- ASC 1.6.0 live status (2026-07-18): all five `IPHONE_65` previews match local MD5 and report `videoDeliveryState=COMPLETE`; poster frames are set to the reviewed OCR frame at `1.4s / 00:00:01:12`, with `previewFrameImage.state=COMPLETE`
- ASC 1.5.0 previous Chinese preview: `hyperframes-v002/renders/app_preview_iphone_zh-Hans_asc1.5.0_v002.mp4`
- ASC 1.5.0 previous English preview: `hyperframes-v002-en/renders/app_preview_iphone_en_asc1.5.0_v002.mp4`
- ASC 1.5.0 source projects: `hyperframes-v002`, `hyperframes-v002-en`
- ASC 1.4.0 preserved preview: `archive/asc-1.4.0/renders/app_preview_iphone_zh-Hans_asc1.4.0_v001.mp4`
- ASC 1.4.0 editable source remains: `hyperframes-v001`

## Store Screenshot Artifact Policy

Generated screenshot outputs remain ignored under:

```text
tools/appstore-screenshots/output/
```

Do not commit the entire generated `output/` folder or v003's copied `assets/` / rendered videos into normal Git history. The v003 project regenerates selected captures and audio from repository scripts, screenshot output, and its checked-in manifests.

Recommended retention:

1. Keep screenshot scripts, screenshot configs, App Preview source projects, manifests, composition templates, and score-generation scripts in Git.
2. Upload final ASC screenshots and App Preview MP4 files as a GitHub Release artifact or versioned zip with checksums when release evidence needs to be preserved.
3. If screenshots must be committed to the repository, commit only curated `store/` PNGs for the exact ASC release, never `raw/` captures.

## Recommended Workflow

1. Export all five iPhone screenshot locales with the existing screenshot pipeline.
2. Run v003 `npm run sync-assets`; it copies the six selected raw UI captures and deterministically generates the original AAC score.
3. Update `preview-manifest.json`, `score-manifest.json`, `composition.template`, and `DESIGN.md` together.
4. Run Hyperframes `validate` / `inspect` for every locale.
5. Render all five MP4 files, then extract hero frames / contact sheets for visual review.
6. Upload the finished video with the ASC helper, then set and verify the reviewed poster frame.

Recommended export command:

```bash
bash tools/appstore-screenshots/scripts/export.sh --ios-only
```

Recommended source folders:

```text
tools/appstore-screenshots/output/store/ios/zh-Hans
tools/appstore-screenshots/output/raw/ios/zh-Hans
```

Current render command:

```bash
cd tools/appstore-screenshots/app-preview/hyperframes-v003
npm run sync-assets
npm run render-all
```

Current outputs:

```text
tools/appstore-screenshots/app-preview/hyperframes-v003/renders/final/app_preview_iphone_en-US_asc1.6.0_v003.mp4
tools/appstore-screenshots/app-preview/hyperframes-v003/renders/final/app_preview_iphone_zh-Hans_asc1.6.0_v003.mp4
tools/appstore-screenshots/app-preview/hyperframes-v003/renders/final/app_preview_iphone_zh-Hant_asc1.6.0_v003.mp4
tools/appstore-screenshots/app-preview/hyperframes-v003/renders/final/app_preview_iphone_ja_asc1.6.0_v003.mp4
tools/appstore-screenshots/app-preview/hyperframes-v003/renders/final/app_preview_iphone_ko_asc1.6.0_v003.mp4
```

The v003 final files are local release artifacts and remain ignored until they are archived outside normal Git history. ASC upload and poster-frame selection completed on 2026-07-18 through `tools/asc-metadata/asc_app_preview_upload.rb`. The shared `1.4s / 00:00:01:12` OCR frame was visually checked across all five languages before the remote timecode and generated-frame state were read back. Final binary consistency remains a manual gate.

Do not include real payment screenshots, receipts, account data, card numbers, order numbers, phone numbers, API keys, certificates, profiles, or private user data in App Preview assets.
