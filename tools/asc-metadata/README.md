# ASC Metadata Tools

Small App Store Connect metadata helper for AutoLedger release work.

This first tool uses the official App Store Connect API to audit localizations
and copy the current English (U.S.) metadata into English (U.K.) as a short-term
workaround for App Store Connect locale validation issues.

For v1.7.0 and later, the preferred flow is metadata-as-code:

1. Edit `tools/asc-metadata/metadata.yml`.
2. Run `audit` to inspect the current App Store Connect state.
3. Run `push-config` without `--apply` and review the dry-run diff.
4. Run `push-config --apply` only after the diff is expected.
5. Run `audit` again before submitting the version.

Use `--skip-app-info`, `--skip-review-notes`, or `--skip-subscriptions` when a release-material change is intentionally limited to version-localized fields.

`asc_custom_product_pages.rb` creates configured custom product pages from the current iOS version, audits existing drafts, and prints stable Campaign Links. It never submits a page for review.

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
- A release locale matrix that marks planned, future, and stale locales
- Screenshot set counts and checksum matches for every platform display type
- App Preview set counts per locale when App Store Connect returns them
- App Review Notes length / SHA-256 and demo-account requirement per platform
- Local screenshot counts for planned / future / target locales
- Subscription group and subscription product localization coverage
- Subscription product period, state, family sharing flag, and description length

## Archive Current Metadata

Export an exact YAML snapshot of the current App Info, version localizations,
platform states, App Review Notes, subscription group, and subscription products before starting
a new release line:

```bash
ruby tools/asc-metadata/asc_metadata.rb export-config \
  --app-id 6761892533 \
  --version 1.5.0 \
  --output tools/asc-metadata/archives/asc-1.5.0.yml
```

Without `--output`, the command prints YAML to stdout. The snapshot contains no
credentials and can be committed as release evidence.

## Create App Store Version

Preview creation of the next version for every platform present in the prior
version:

```bash
ruby tools/asc-metadata/asc_metadata.rb create-version \
  --app-id 6761892533 \
  --source-version 1.5.0 \
  --version 1.6.0
```

Add `--apply` only after reviewing the platform list. Existing platform/version
pairs are detected and skipped, so the command is safe to rerun. This step does
not select a build, upload assets, submit for review, or release the version.

By default the planned ASC locales are `zh-Hans`, `zh-Hant`, `en-US`, `ja`, and
`ko` for `v1.7.0 / ASC 1.6.0`. Override the matrix
when needed:

```bash
ruby tools/asc-metadata/asc_metadata.rb audit \
  --planned-locale zh-Hans \
  --planned-locale zh-Hant \
  --planned-locale en-US \
  --planned-locale ja \
  --planned-locale ko
```

When QA intentionally excludes a screenshot from upload, exclude the same local
stem during audit so checksum counts do not look stale:

```bash
ruby tools/asc-metadata/asc_metadata.rb audit \
  --platform IOS \
  --exclude-shot 04_workspace_cleaning
```

## Push Metadata Config

`metadata.yml` is the repo-owned source for app info, version localizations,
platform-specific App Review Notes profiles, subscription group localization,
and monthly/yearly subscription localization.
It intentionally does not contain API keys, private keys, real ledger data,
hotel orders, email content, screenshots, or App Preview binaries.

Dry-run first:

```bash
ruby tools/asc-metadata/asc_metadata.rb push-config \
  --config tools/asc-metadata/metadata.yml
```

Apply after reviewing the dry-run output:

```bash
ruby tools/asc-metadata/asc_metadata.rb push-config \
  --config tools/asc-metadata/metadata.yml \
  --apply
```

If App Store Connect temporarily locks app-wide name or subtitle changes while
the prior App Info is not editable, use `--skip-app-info` to apply only version
localizations and subscription localizations. Keep the skipped App Info diff as
an explicit release gate instead of treating the push as fully complete.
For active shared localizations that ASC refuses to edit, `--shared-create-only`
preserves existing App Info and subscription locales while still creating a
new missing locale such as Korean. Version-localization updates are unaffected.
Use repeatable `--locale ko` filters for a scoped correction when only one
localization should be written across App Info, version metadata, and products.

The push updates or creates:

- `appInfoLocalizations`: app name, subtitle, Privacy Policy URL, Apple TV privacy policy text
- `appStoreVersionLocalizations`: description, keywords, marketing URL, promotional text, support URL, What's New
- `appStoreReviewDetails`: notes and `demoAccountRequired=false`; existing reviewer contact fields are preserved
- `subscriptionGroupLocalizations`: subscription group display name
- `subscriptionLocalizations`: product display name and description

`push-config` uses App Store Connect API dry-run mode by default and prints the
field-level changes it would make. It still requires credentials because it has
to compare the config against current ASC resource IDs. Subscription
descriptions must stay within ASC's 55-character limit.

When ASC exposes both the released and next-version App Info resources, the
tool selects the `PREPARE_FOR_SUBMISSION` resource for audit, export, and writes
instead of attempting to modify the locked `READY_FOR_SALE` resource.

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
sets whose remote checksums already match the local files. API requests and
binary upload operations retry bounded transient network, `429`, and `5xx`
failures. After upload, the tool waits for every screenshot checksum and
`assetDeliveryState=COMPLETE`; rerunning while Apple is still processing an
already complete-sized set waits instead of deleting it. Rerun the same command
after any terminal failure to reconcile by MD5.

## Create Custom Product Pages And Campaign Links

Define `custom_product_pages` and `campaign_links` in `metadata.yml`, then dry-run first:

```bash
ruby tools/asc-metadata/asc_custom_product_pages.rb \
  --app-id 6761892533 \
  --version 1.6.0
```

Create only missing pages after reviewing the localized copy:

```bash
ruby tools/asc-metadata/asc_custom_product_pages.rb \
  --app-id 6761892533 \
  --version 1.6.0 \
  --apply
```

The tool clones the editable iOS product page as the visual template, adds all configured localizations in one API request, and leaves each page editable. Existing page names are audited instead of recreated. Campaign data appears after Apple's privacy threshold is met.

Because cloning also copies the template screenshot order, define a distinct
`screenshots` order for every page and reconcile it before review submission:

```bash
ruby tools/asc-metadata/asc_custom_product_page_screenshots.rb \
  --app-id 6761892533

ruby tools/asc-metadata/asc_custom_product_page_screenshots.rb \
  --app-id 6761892533 \
  --apply
```

The screenshot tool validates all five-language assets before making remote
changes, trims an already-matching prefix when a page uses a focused subset,
replaces other nonmatching custom-page screenshot sets, waits for every asset
to reach `COMPLETE`, and verifies the ordered MD5 list. `--page`,
`--locale`, and `--display iphone|ipad` can be repeated for a scoped run.
It never submits a custom product page for review.

## Upload App Preview

`asc_app_preview_upload.rb` safely replaces one rendered App Preview for one
locale and display target. It uploads and waits for the new video to reach
`COMPLETE` before deleting stale previews, so a failed transcode does not remove
the previously usable video.

Dry-run first:

```bash
ruby tools/asc-metadata/asc_app_preview_upload.rb \
  --app-id 6761892533 \
  --version 1.6.0 \
  --target-locale en-US \
  --preview-type IPHONE_65 \
  --file tools/appstore-screenshots/app-preview/hyperframes-v003/renders/final/app_preview_iphone_en-US_asc1.6.0_v003.mp4 \
  --poster-frame-time-code 00:00:01:12
```

Apply after reviewing the locale, set, existing count, and file:

```bash
ruby tools/asc-metadata/asc_app_preview_upload.rb \
  --app-id 6761892533 \
  --version 1.6.0 \
  --target-locale en-US \
  --preview-type IPHONE_65 \
  --file tools/appstore-screenshots/app-preview/hyperframes-v003/renders/final/app_preview_iphone_en-US_asc1.6.0_v003.mp4 \
  --poster-frame-time-code 00:00:01:12 \
  --apply
```

The tool creates the locale's preview set when missing, reserves and uploads the
MP4 using Apple's `uploadOperations`, commits the MD5 checksum, polls
`videoDeliveryState`, and fails closed on `FAILED` or timeout. Rerunning is
idempotent when the ASC checksum and requested poster timecode match the remote
preview. When `--poster-frame-time-code HH:MM:SS:FF` is present, the tool waits
for the video to complete, updates `previewFrameTimeCode`, and requires the
generated `previewFrameImage` to reach `COMPLETE` before deleting stale files.
For the 30 fps v003 exports, `00:00:01:12` selects the frame at 1.4 seconds.
It does not answer App Privacy, bind a build, or submit the version.

## Bind A Verified Build

`asc_build_bind.rb` binds one exact Xcode Cloud / TestFlight build to every
selected App Store platform only after verifying the Xcode Cloud run's full
source commit, successful completion, App Store eligibility, encryption flag,
processing state, and platform mapping.

Dry-run first:

```bash
ruby tools/asc-metadata/asc_build_bind.rb \
  --app-id 6761892533 \
  --version 1.6.0 \
  --build-number 119 \
  --expected-source-commit 9414b91694d405d3e4c91edbae99d547c1684564
```

Add `--apply` only after the four platform/build IDs are expected. The tool
reads every relationship back after writing. It does not submit the version,
change release timing, answer App Privacy, or move Git/Xcode Cloud tags.

## Platform Filter

Restrict version localization writes to one or more platforms:

```bash
ruby tools/asc-metadata/asc_metadata.rb copy-locale \
  --platform IOS \
  --platform MAC_OS
```

When omitted, the tool applies to all App Store versions matching the requested
version string.
