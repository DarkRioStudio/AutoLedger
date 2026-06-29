# AutoLedger

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md)

AutoLedger is a local-first personal ledger, automation, and hotel folio archive for Apple platforms.

AutoLedger turns payment screenshots, camera receipts, voice input, clipboard text, Shortcuts/App Intent input, and hotel folio PDFs into reviewable personal expense records.

## Features

- Screenshot-based expense capture
- On-device OCR-based parsing
- Camera receipt capture
- Clipboard import
- Shortcuts / App Intent support
- Apple Watch quick entry
- Share Extension import from other apps
- Control Center widget for quick clipboard import
- Hotel folio archive workflow for user-selected PDFs, local email PDF attachments, and dedicated inbox candidates
- Foundational multi-ledger support with a local ledger, ledger management, current/all-ledger views, and a default write ledger
- Localization and recognition language packs for Simplified Chinese, Traditional Chinese, English, and Japanese
- iCloud backup / restore support
- Local-first personal bookkeeping workflow

## Hotel Folio Import

AutoLedger treats hotel folios as reviewable stay records, not just a single OCR amount.

Supported import paths:

- **Manual PDF import**: choose a hotel folio PDF in the Hotel tab. The App extracts text with PDFKit and opens the hotel folio recognition review flow.
- **Share PDF to AutoLedger**: share a hotel folio PDF from Files, Mail, or another app to enter the pending hotel review flow.
- **Local email scan**: the user explicitly connects an IMAP mailbox inside the App. The authorization code stays in local Keychain. The App lists candidate emails with PDF attachments, and the user selects which PDFs to import.
- **Dedicated inbox candidates**: in the Pro automation path, the user can claim a `folio+<token>@getautoledger.app` address, manually forward hotel folios, or configure their own mailbox forwarding rule. The Worker only stores short-lived PDF candidates; the App still downloads the PDF and performs text extraction, recognition, and review locally.

The target fields include hotel name, brand / group, city / country, check-in / check-out dates, nights, room type, confirmation number, currency, room charge, tax, service charge, food and beverage, other charges, total amount, payment method, source file, and recognition confidence. After confirmation, AutoLedger creates a `HotelStayRecord` and links a normal expense transaction, using the hotel accommodation category by default.

Privacy boundaries:

- The Worker does not log in to user mailboxes and does not store QQ / IMAP / Gmail / Outlook authorization codes.
- Local email scan only runs after explicit user action, and results stay pending until the user confirms them.
- The dedicated cloud inbox only processes emails forwarded to the AutoLedger address. It does not scan a user's private mailbox.
- Cloud PDF candidates are short-lived. After the App downloads / converts a PDF, it should delete the cloud copy when possible.
- Nothing is posted to the official ledger before user confirmation. Hotel records and linked transactions remain viewable, editable, and deletable in the App.

## Privacy

AutoLedger is designed as a local-first personal bookkeeping app.

- No account is required by default.
- Transaction parsing is designed to happen on device where possible.
- Users should review parsed results before saving.
- Debug and feedback exports may contain private transaction details if users choose to generate them.
- Please do not upload real receipts, payment screenshots, or personal finance data in public issues.

The app includes optional local model support and StoreKit support purchases. Store metadata, signing credentials, and production account configuration are not part of this repository.

## Localization And Recognition Packs

AutoLedger separates UI localization from receipt/bill recognition language packs:

- **App UI languages**: the main user-facing paths currently cover `zh-Hans` Simplified Chinese, `zh-Hant` Traditional Chinese, `en` English, and `ja` Japanese. Main App, Watch, Widget, Control Widget, and Share Extension key coverage is checked by `scripts/check_localization_coverage.py`.
- **App Store screenshot languages**: the screenshot pipeline organizes iPhone, iPad, Mac, Apple Watch, Apple TV, and visionOS copy for `zh-Hans`, `zh-Hant`, `en`, and `ja`. Japanese screenshots and store metadata still require human review before submission.
- **Recognition language packs**: `AutoLedgerCore` includes built-in `zh-Hans`, `zh-Hant`, `en`, and `ja` packs for receipt keywords, amount formats, date formats, layered amount labels, merchant labels, non-merchant exclusions, category keywords, and OCR language hints.
- **Japanese receipt recognition**: the Japanese pack covers common fields such as `合計`, `小計`, `税込`, `店舗`, `注文番号`, `カフェ`, and `コンビニ`; OCR hints prefer `ja-JP + en-US`, and amount / merchant / category parsing is covered by offline regression.
- **Extension model**: future packs should remain pure data, versioned, reviewable, and fallback-friendly. User correction sharing must be opt-in, redacted, revocable, and reviewed before entering a reviewed pack. This repository does not currently implement remote language-pack hot updates or automatic uploads.

## Build Requirements

- Xcode 27 beta
- Swift 6 / SwiftUI
- CocoaPods
- iOS 17 or later for the main app target
- watchOS 10 or later for the Watch app target

Required Apple capabilities:

- App Groups
- iCloud Containers
- Shortcuts / App Intents
- Watch App target
- Widget targets
- Share Extension

## Local Setup

1. Clone the repository.
2. Install CocoaPods dependencies:

   ```bash
   cd AutoLedger
   pod install
   ```

3. Open `AutoLedger/AutoLedger.xcworkspace`.
4. Set your own Apple Development Team.
5. Change Bundle Identifiers if needed.
6. Configure your own App Group and iCloud Container if needed.
7. Build the `AutoLedger` iOS target first.
8. Build the `AutoLedgerWatch Watch App` target if needed.

The repository includes `Config.example.xcconfig` as a placeholder reference for public contributors. The production Xcode project is not switched to that example file, so the real release branch can continue to build through Xcode Cloud.

For multi-target signing, configure separate Bundle IDs for:

- iOS App target
- Apple Watch App target
- Share Extension
- Widget extensions

## Project Structure

```text
AutoLedgerRio/
├── AutoLedger/
│   ├── AutoLedger/                         # Main iOS / iPadOS / Mac Catalyst app target
│   │   ├── App/                            # App entry, store, router, global wiring
│   │   ├── Features/                       # Feedback, Hotel, Inbox, Ledger, Report, Settings, Subscription, iPad
│   │   ├── Domain/                         # App-layer enums, models, services, and intents
│   │   ├── Data/                           # DTOs, mappers, persistence adapters
│   │   ├── Shared/                         # Shared components, constants, extensions
│   │   ├── Screenshots/                    # Screenshot-mode host and fixtures
│   │   ├── Resources/                      # Localization and app resources
│   │   └── Assets.xcassets/                # App assets
│   ├── AutoLedgerCore/                     # Local Swift package, Foundation only
│   ├── AutoLedgerWatch Watch App/          # Apple Watch app target
│   ├── AutoLedgerWidgets/                  # iOS Widget extension
│   ├── AutoLedgerWatchWidgetsExtension/    # watchOS Widget / complication extension
│   ├── ControlWidgetExtension/             # Control Center widget extension
│   ├── ShareExtension/                     # Share extension
│   ├── AutoLedgerTV/                       # tvOS read-only dashboard
│   ├── AutoLedgerVision/                   # visionOS showcase app
│   ├── Packages/RealityKitContent/         # RealityKit content package for visionOS
│   ├── Pods/                               # CocoaPods dependencies, gitignored
│   └── ci_scripts/                         # Xcode Cloud setup scripts
├── AutoLedgerCoreKit/                      # Core-related experiments / tooling
├── ReceiptDebugTool/                       # Receipt parser debugging tool
├── docs/                                   # Design and topic docs
├── process/                                # Agent iteration workflow docs
├── scripts/                                # Local regression scripts
├── tests/                                  # Golden regression fixtures
├── tools/app-icons/                        # App icon generation and validation
├── tools/appstore-screenshots/             # App Store screenshot export pipeline
├── tools/receipt_ocr/                      # Receipt OCR batch tooling
├── tools/worker/                           # Worker / remote capability experiments
└── versions/                               # Version plans and release notes
```

## Common Commands

```bash
# Build through the workspace
xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace \
  -scheme AutoLedger \
  -destination 'generic/platform=iOS' \
  build

# Offline parser regression
bash scripts/run_offline_regression.sh

# Golden parser regression
bash scripts/run_golden_regression.sh
```

## Repository Status

This repository is prepared for public source release. The App Store version may use signing, entitlement, Xcode Cloud, StoreKit, and store metadata configuration that are not part of this repository.

The `main` branch is intended to remain the real AutoLedger development and release branch after publication. Public-ready cleanup should not rename the Xcode workspace, schemes, targets, Bundle Identifiers, entitlements, or Xcode Cloud scripts.

## Roadmap

Current repository status:

- `v1.6.0` and `v1.6.1` are complete and continue to map to the ASC / App Store `1.5.0` release line.
- App Store `1.4.0` has been released through the internal `v1.5.1` closeout; `v1.5.0` remains the implementation baseline included in that release.
- `v1.6.2` is complete. It closed SDK adaptation phase 2, hotel email import hardening, deep links, Widgets, App Intents, data reliability, Japanese release-material review, and the GOAL-1960 release-smoke baseline.
- `v1.6.3` is complete for its current scope: the hotel C1 dedicated folio inbox App/Core skeleton, review notes, and regression baseline. C2 Worker login to user mailboxes stays personal-use / future experimental only.
- `v1.6.4` is now in development. `GOAL-2200` has frozen the Free / Pro boundary through a platform-neutral Pro access policy contract; the C1 Cloudflare Worker, D1/R2/Queue resources, token claim / rotation API, APNs secrets, cloud-candidate API, and App-side PDFKit local conversion entry have landed. The next work is the Pro page, purchase restore, email automation gates, review material, and TestFlight end-to-end validation.

| Internal version | App Store | Status | Focus |
| --- | --- | --- | --- |
| v1.4.0 | 1.3.0 | Released | Apple Watch support, accessibility improvements, App Intents, localization, screenshot pipeline updates, optional Support Developer IAP |
| v1.5.0 | 1.4.0 | Included in 1.4.0 release | iPad workspace, batch import, batch OCR / receipt cleanup, foundational multi-device data sync, Apple Watch complications, iPad / Mac screenshot pipeline, and Mac Catalyst workflow |
| v1.5.1 | 1.4.0 | Released | Lower deployment targets, Core parsing refactor, external assist pilot, edit-save stability, iCloud sync performance, current-platform screenshots, and App Preview v001 |
| v1.6.0 | 1.5.0 | Completed | Stronger subscription management, AI subscription hints, merchant / category / subscription learning cache, tvOS read-only dashboard, visionOS showcase, full-platform build / TestFlight / ASC / schema / screenshot closeout |
| v1.6.1 | 1.5.0 | Completed | Hotel folio recognition and archive, foundational multi-ledger support, Japanese localization, cross-platform App Icon redraw, and iOS 27 resizable-layout phase 1; the store version stays on ASC 1.5.0 for internal patch lines |
| v1.6.2 | 1.5.0 by default | Completed | SDK adaptation phase 2, hotel email draft queue / dedupe / batch candidate import, deep-link Router, Widget / App Intents first pass, CSV / JSON and backup-restore smoke, Japanese release-material review, and GOAL-1960 release smoke |
| v1.6.3 | 1.5.0 by default | Completed | Hotel C1 dedicated folio inbox App/Core skeleton: `folio+<token>@getautoledger.app` contract, cloud-candidate model, deep links, PDFKit local-conversion entry, review notes, and regression baseline |
| v1.6.4 | 1.5.0 by default | In development | Personal Pro foundations: Free / Pro boundaries now land in `AutoLedgerProAccessPolicy`; `ProEntitlementManager`, the C1 Cloudflare Worker, D1/R2/Queue, token claim / rotation, APNs secrets, cloud-candidate API, and App-side PDFKit conversion have landed; next are Pro page, purchase restore, email automation gates, review material, and TestFlight end-to-end validation |

## License

Source code is released under the MIT License.

The AutoLedger name, app icon, App Store screenshots, marketing materials, and brand assets are not included in the MIT license and are reserved by the author.
