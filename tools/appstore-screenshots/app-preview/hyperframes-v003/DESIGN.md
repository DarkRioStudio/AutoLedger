# AutoLedger App Preview v003 Design

## Style Prompt

Create a clean, warm, Apple-ecosystem App Preview for AutoLedger ASC 1.6.0. The video is a practical product demonstration rather than a brand film: deterministic in-app UI captures stay dominant, while localized headlines, restrained transitions, and small disclosure cards explain the flow. One composition and one timing map produce five language variants without changing feature order or visual emphasis.

## Colors

- Canvas parchment: `#F4F0E6`
- Warm panel: `#FFFDF7`
- Ink: `#1D2722`
- Muted ink: `#62706A`
- AutoLedger green: `#2F865F`
- Soft green: `#DDEADF`
- Warm orange: `#D77A22`
- Hairline green: `#AFCDBA`

## Typography

- Display and body: the Apple system font stack, with `PingFang SC`, `PingFang TC`, `Hiragino Sans`, and `Apple SD Gothic Neo` fallbacks for the five shipping languages.
- Data labels and scene counters use tabular numbers.
- Headlines use heavy display weights; explanatory copy and disclosures remain lighter and shorter.
- Locale-specific sizing may reduce English, Japanese, or Korean headlines, but the hierarchy and timing must remain identical.

## Layout

- Output is `886x1920` portrait for the accepted iPhone App Preview target.
- Every scene reserves a top copy zone, a large central in-app UI capture, and a small bottom evidence/disclosure zone.
- Raw screenshot-mode UI captures are used inside the device frame; store marketing composites are not nested inside the video.
- Six scenes share one layout: OCR, voice entry, hotel folio, Watch ecosystem, monthly report, and Pro/final lockup.

## Motion

- Overall duration: 22 seconds, medium-low energy.
- Primary transition: warm blur crossfade between related product moments.
- Entrances vary between horizontal copy reveals, vertical device settles, and restrained scale focus.
- UI captures may use a subtle finite pan or focus push; no infinite loops and no movement that implies unavailable interaction.
- The last scene alone may fade out.

## Audio

- Use the original, repository-generated 22-second score `Quiet Control`; it contains no third-party samples, vocals, or reused v002 music.
- The score changes chord center and motif character at the exact visual transition timestamps: OCR soft pulse, voice airy pluck, hotel warm lower pad, Watch bright bell, report ordered motif, and Pro resolved cadence.
- Transition accents remain restrained and the mix targets `-20 LUFS` / `-1.5 dBTP`, keeping localized on-screen copy dominant.
- `score-manifest.json` is the timing and musical-intent source of truth; `scripts/generate-score.py` produces deterministic stereo PCM before delivery mastering.
- Delivery audio is AAC, 48 kHz, stereo, 256 kbps.
- No voiceover is required because App Store autoplay is commonly muted; localized on-screen copy carries the story.

## Compliance Boundaries

- Use only deterministic demo data and repository-owned UI captures.
- Do not show real receipts, accounts, payment credentials, hotel confirmations, email addresses, phone numbers, API keys, or user content.
- Do not state a price. The Pro source capture's price line is replaced in-composition by a localized review-before-save reminder, and the scene must disclose that some features require AutoLedger Pro.
- Do not imply automatic final posting: the story consistently shows review and user confirmation.
- Final ASC delivery still requires human verification that the rendered video matches Apple App Preview rules and the submitted binary.

## What NOT To Do

- Do not reuse the ASC 1.5.0 v002 copy or relabel old renders as v003.
- Do not create separate motion systems per language.
- Do not put Watch, iPad, Mac, tvOS, or visionOS into separate v003 videos during this release pass.
- Do not use dark cinematic styling, neon gradients, abstract 3D animation, hard cuts, or rapid zooms.
- Do not upload or modify App Store Connect from this project.
