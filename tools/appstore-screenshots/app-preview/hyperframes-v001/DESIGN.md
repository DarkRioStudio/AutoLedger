# AutoLedger App Preview v001 Design

## Style Prompt

Create a clean, warm, Apple-ecosystem product preview for AutoLedger. The video should feel like a practical app demonstration rather than a brand film: real UI screenshots, calm motion, precise highlights, and short Chinese App Store copy. The tone is local-first, lightweight, fast, and trustworthy.

## Colors

- Canvas parchment: `#F4F0E6`
- Warm panel: `#FFFDF7`
- Ink: `#1D2722`
- Muted ink: `#62706A`
- AutoLedger green: `#2F865F`
- Soft green: `#DDEADF`
- Warm orange: `#D77A22`
- Indigo accent: `#585BD7`

## Typography

- Display and body: `SF Pro Display`, `Helvetica Neue`, Arial, system sans-serif.
- Data labels and numbers: same family with `font-variant-numeric: tabular-nums`.
- Use heavy display weights for the short App Store claims and lighter weights for supporting details.

## Motion

- Overall pace: 20 seconds, medium energy.
- Primary transition: warm blur crossfade between related app moments.
- Accent transition: one horizontal push for the Watch ecosystem scene.
- Entrances should be staggered and practical: UI frames settle first, then highlights and short copy.
- Avoid infinite loops. Ambient movement must be finite and subtle.

## Audio

- Use a low-volume background bed generated through the existing EverestBaseCamp audio pipeline.
- Post-process the bed for App Store preview delivery: AAC LC, 48kHz, stereo, gentle loudness, softened high frequencies, and fade in/out.
- Keep the bed non-melodramatic and app-demo friendly: soft, warm, and quiet enough for silent viewing.
- Do not use stock tracks, copyrighted samples, real recorded user audio, or audio that implies unsupported app functionality.

## What NOT To Do

- Do not show real receipts, payment screenshots, accounts, phone numbers, cards, or order IDs.
- Do not imply unsupported features or show debug/test environment labels.
- Do not use dark cinematic styling, neon gradients, or abstract 3D brand animation.
- Do not make Hyperframes or any third-party service a required part of the app build.
- Do not upload or modify anything in App Store Connect from this project.
