# ASC Metadata Tools

Small App Store Connect metadata helper for AutoLedger release work.

This first tool uses the official App Store Connect API to audit localizations
and copy the current English (U.S.) metadata into English (U.K.) as a short-term
workaround for App Store Connect locale validation issues.

## Credentials

Do not commit `.p8` keys or `.env` files. Provide credentials through your shell:

```bash
export ASC_ISSUER_ID="..."
export ASC_KEY_ID="..."
export ASC_PRIVATE_KEY_PATH="/secure/path/AuthKey_XXXX.p8"
```

You can also provide the private key inline with `ASC_PRIVATE_KEY`, but a local
file outside the repo is safer.

Required App Store Connect role: App Manager is sufficient for app metadata
localization reads and writes.

## Audit

```bash
ruby tools/asc-metadata/asc_metadata.rb audit \
  --app-id 6761892533 \
  --version 1.5.0
```

The audit prints:

- App Info localizations, including Privacy Policy URL and Apple TV privacy text
- App Store Version localizations for every platform version matching `1.5.0`
- Missing or empty key fields by locale

## Copy English (U.S.) To English (U.K.)

Dry-run first:

```bash
ruby tools/asc-metadata/asc_metadata.rb copy-locale \
  --app-id 6761892533 \
  --version 1.5.0 \
  --source-locale en-US \
  --target-locale en-GB
```

Apply after reviewing the dry-run output:

```bash
ruby tools/asc-metadata/asc_metadata.rb copy-locale \
  --app-id 6761892533 \
  --version 1.5.0 \
  --source-locale en-US \
  --target-locale en-GB \
  --apply
```

The copy includes:

- `appInfoLocalizations`: app name, subtitle, Privacy Policy URL, Apple TV Privacy Policy text
- `appStoreVersionLocalizations`: description, keywords, marketing URL, promotional text, support URL, What's New

It does not upload screenshots, App Preview videos, or App Privacy nutrition
label questionnaire answers yet.

## Upload Store Screenshots

`asc_screenshot_upload.rb` uploads already-rendered store screenshot PNGs from
the local screenshot pipeline into one App Store Connect locale. Use it only
after the local screenshot/contact-sheet QA confirms the image content matches
the screenshot title and description.

Dry-run first:

```bash
ruby tools/asc-metadata/asc_screenshot_upload.rb \
  --app-id 6761892533 \
  --version 1.5.0 \
  --source-locale-dir en \
  --target-locale en-GB
```

Apply after reviewing the dry-run output:

```bash
ruby tools/asc-metadata/asc_screenshot_upload.rb \
  --app-id 6761892533 \
  --version 1.5.0 \
  --source-locale-dir en \
  --target-locale en-GB \
  --apply
```

Useful options:

- `--platform IOS` limits the upload to one App Store platform. Repeat for
  multiple platforms.
- `--exclude-shot 04_workspace_cleaning` skips a local screenshot stem when QA
  finds copy/image mismatch.
- `--root tools/appstore-screenshots/output/store` overrides the screenshot
  output root.

The tool currently maps:

- `IOS`: iPhone 6.5-inch, iPad Pro 12.9-inch, Apple Watch Ultra
- `MAC_OS`: desktop screenshots
- `TV_OS`: Apple TV screenshots
- `VISION_OS`: Apple Vision Pro screenshots

For each screenshot it creates an App Store Connect upload reservation, uploads
the PNG using Apple's `uploadOperations`, commits the MD5 checksum, and skips
sets whose remote checksums already match the local files.

It does not upload App Preview videos or App Privacy nutrition label
questionnaire answers.

## Platform Filter

Restrict version localization writes to one or more platforms:

```bash
ruby tools/asc-metadata/asc_metadata.rb copy-locale \
  --platform IOS \
  --platform MAC_OS
```

When omitted, the tool applies to all App Store versions matching the requested
version string.
