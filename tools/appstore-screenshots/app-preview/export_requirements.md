# App Preview Export Requirements

## Format Direction

- Vertical iPhone App Preview first.
- Use large iPhone screenshots as source material.
- Target a 15-20 second final cut.
- Keep the video suitable for silent playback.
- Keep text overlays short and readable.

## Content Rules

- Show real AutoLedger UI experiences only.
- Do not show App features that are not implemented.
- Do not show debug screens, test environment labels, simulator labels, Xcode, terminal output, or internal logs.
- Do not show permission prompts unless the App Store preview explicitly needs them.
- Do not trigger or imply live OCR, LLM, network, iCloud, camera, photo library, or microphone access in the production source capture.

## Privacy Rules

Do not include:

- Real payment screenshots
- Real receipts
- Real account names
- Real card numbers or card tails
- Real order numbers
- Real transaction references
- Real phone numbers
- Real addresses
- API keys
- Certificates
- Provisioning profiles
- Private keys

Use fictional examples such as:

- Demo Coffee
- Example Market
- Sample Store
- 午饭 28 元
- 地铁 4 元
- 超市购物 86.5 元

## Layout Rules

- Text must not cover important UI fields.
- Amount, merchant, category, and time highlights should only appear when those fields are visible.
- Avoid overly dense copy.
- Keep the first message understandable within 3 seconds.
- Preserve original App UI proportions when animating screenshots.

## Delivery Checks

- The video plays cleanly without audio.
- No frame includes private data.
- No frame includes unsupported feature claims.
- No frame includes debug labels.
- The final export can be reviewed locally before manual App Store Connect upload.
