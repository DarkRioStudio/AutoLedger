# AutoLedger Hyperframes App Preview v003

This project produces the ASC 1.6.0 iPhone App Preview in five current release languages from one deterministic timing and layout template.

## Scope

- Output: one `886x1920`, 22-second, 30 fps iPhone Preview per locale.
- Locales: `en-US`, `zh-Hans`, `zh-Hant`, `ja`, `ko`.
- Scenes: OCR, voice entry, hotel folio, Watch ecosystem, monthly report, Pro/final lockup.
- Source UI: deterministic raw screenshot-mode captures. No real user data.
- Not included: iPad, Mac, tvOS, visionOS, standalone Watch Preview, ASC upload, or review submission.

## Source Of Truth

- Visual and motion rules: `DESIGN.md`
- Locale and scene matrix: `preview-manifest.json`
- Original-score cue map: `score-manifest.json`
- Shared composition: `composition.template`
- Marketing title/subtitle copy: `../../config/screenshots.json`
- Generated active composition: `index.html`

Do not edit localized copy directly in generated `index.html`. Change the screenshot config or `preview-manifest.json`, then run `npm run select -- <locale>`.

## Prepare Assets

Export the five iPhone screenshot sets first if `../../output/raw/ios/<locale>` is missing, then run:

```bash
npm run sync-assets
```

This copies only the six selected UI captures per locale into `assets/`, reuses the repository-owned app icon, then deterministically synthesizes and masters the original 22-second `Quiet Control` score. The score uses no third-party samples and aligns its chapter accents with the visual transition timestamps.

## Inspect One Locale

```bash
npm run select -- en-US
npm run check
npm run dev
```

Studio URL after the server starts:

```text
http://localhost:3002/#project/hyperframes-v003
```

## Render

One locale with all checks:

```bash
npm run render-locale -- ko --check
```

All five locales:

```bash
npm run render-all
```

Hyperframes review renders are written to `renders/review/`. Delivery MP4 files are post-processed to H.264 High Profile Level 4.0, 30 fps, target 11 Mbps video, and AAC 256 kbps / 48 kHz / stereo under `renders/final/`. Both directories stay out of normal Git history; preserve approved delivery files as release evidence or upload them manually to ASC.

## Release Checks

- `npm run check` passes for all five locales.
- Every final file is 15-30 seconds, `886x1920`, 30 fps or lower, H.264, and below 500 MB.
- Audio is AAC, stereo, 44.1 or 48 kHz, with all tracks enabled.
- No text clips at hero frames or poster-frame candidates.
- Copy is human-reviewed, especially Japanese and Korean.
- Pro disclosure is visible and no product price appears in overlay copy.
- The Preview matches the submitted binary and contains only authorized demo content.
- Upload and poster-frame selection remain manual release actions.
