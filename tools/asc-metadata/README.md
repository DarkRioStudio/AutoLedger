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

## Platform Filter

Restrict version localization writes to one or more platforms:

```bash
ruby tools/asc-metadata/asc_metadata.rb copy-locale \
  --platform IOS \
  --platform MAC_OS
```

When omitted, the tool applies to all App Store versions matching the requested
version string.
