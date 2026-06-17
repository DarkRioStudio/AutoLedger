# AutoLedger App Preview Materials

This directory contains planning material for App Store App Preview video production.

The repository does not directly generate an official App Preview video yet. The current recommended workflow is:

1. Export iPhone and Apple Watch screenshots with the existing screenshot pipeline.
2. Use the raw and store PNGs as keyframes.
3. Hand the keyframes and brief in this directory to Hyperframes or another video production tool.
4. Export a 15-20 second video.
5. Manually upload the finished video to App Store Connect.

Recommended export commands:

```bash
bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans
bash tools/appstore-screenshots/scripts/export.sh --watch-only --locale zh-Hans
```

Recommended source folders:

```text
tools/appstore-screenshots/output/store/ios/zh-Hans
tools/appstore-screenshots/output/raw/ios/zh-Hans
tools/appstore-screenshots/output/store/watch/zh-Hans
tools/appstore-screenshots/output/raw/watch/zh-Hans
```

Suggested output names:

```text
app_preview_iphone_zh-Hans_v001.mp4
app_preview_iphone_zh-Hans_v001.mov
```

Future options:

- Add a Remotion renderer if the animation direction becomes stable.
- Add an ffmpeg-based stitching script for a very simple video draft.
- Add Hyperframes CLI integration only if it has a stable, non-login local workflow.

Do not include real payment screenshots, receipts, account data, card numbers, order numbers, phone numbers, API keys, certificates, profiles, or private user data in App Preview assets.
