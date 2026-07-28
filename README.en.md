# AutoLedger

[English](README.en.md) · [简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [日本語](README.ja.md)

AutoLedger is a private, local-first personal expense ledger with automated imports for Apple users worldwide. It turns screenshots, receipts, voice input, the clipboard, Shortcuts, and hotel folio PDFs into reviewable records. Core bookkeeping stays free; Pro unlocks time-saving automation such as email folios, batch candidates, and a dedicated folio inbox.

## Download & TestFlight

- **App Store release**: [Download AutoLedger](https://apps.apple.com/app/id6761892533)
- **TestFlight beta**: [Join the AutoLedger beta](https://testflight.apple.com/join/T3Wu6ngk). Test availability and build access are controlled by Apple TestFlight.

## License / Commercial Use

AutoLedger is source-available for learning, personal research, security review, and contributions. Commercial use, white-label publishing, SaaS / hosted redistribution, or republishing a modified app to App Store, Google Play, Steam, Microsoft Store, WeChat Mini Programs, or other public marketplaces requires prior written permission.

You may not remove, bypass, or tamper with Pro / IAP / subscription gates and distribute the result. The AutoLedger name, icon, screenshots, website assets, App Store materials, paywall artwork, and README images are not licensed with the source code. See [LICENSE](LICENSE) and [docs/operations/brand-assets-notice.md](docs/operations/brand-assets-notice.md).

## Why AutoLedger

AutoLedger is not another budgeting app and does not connect to bank accounts. It focuses on reducing repetitive input and organizing expense materials such as screenshots, receipts, subscriptions, multi-currency purchases, and hotel folios.

Parsed results stay reviewable before saving, so the user can correct the record before it becomes part of the ledger. It is designed for privacy-conscious Apple users, frequent travelers, and people who automate repetitive work.

See the [global product strategy](docs/product/GLOBAL_PRODUCT_STRATEGY.md) for the Auto+ principles, target markets, App Store recommendations, localization checklist, and documented code-structure risks.

## Features

### Quick Capture

- Screenshot and photo receipt OCR for amounts, merchants, and dates.
- Clipboard and Share Extension import from other apps.
- Voice bookkeeping, Siri / Shortcuts, and App Intent input.
- Action Button, Control Center Widget, and Apple Watch quick entry.

### Automatic Organization

- Rule engine plus on-device LLM parsing for common payment screenshots, receipts, and bill text.
- Category learning and editable category / source labels.
- Subscription recognition and reminders for recurring charges.
- Monthly reports with category, trend, and merchant views.
- Multi-ledger support with local ledgers, ledger management, current/all-ledger views, and a default write ledger.
- JSON export / import plus iCloud sync / backup for migration and recovery.

### Hotel Folio Workflow

- Manual hotel folio PDF import with PDFKit text extraction and review.
- Pro local email PDF candidate import after explicit user scanning and selection.
- Dedicated folio inbox as a Pro automation path for forwarded hotel folio emails.
- Candidate review before saving; no silent posting to the official ledger.
- Hotel expense archive for stays, hotel brands / groups, dates, nights, charge breakdowns, and linked transactions.

## Free / Pro Boundary

Free remains useful for everyday bookkeeping. AutoLedger does not move existing core features behind Pro, and Pro does not lock the user's ledger history.

Free includes manual entries, single screenshot / photo import, voice / text input, manual hotel folio PDF import, hotel history review, basic subscription management, basic reports, widgets / Share Extension, export / import, backup, and editing or deleting historical records.

The primary Pro message is “Unlock automation,” not “support the developer” or access to the ledger. Pro now covers local email folio scan, batch candidate import, advanced deduplication, the dedicated cloud folio inbox, advanced search, subscription anomaly alerts, monthly packages, advanced rules, smart cleanup suggestions, and the first opt-in cloud merchant-alias suggestions based on redacted aggregate features. Later directions include a unified review queue, month-end checklists, smart review, advanced share templates, and more reliable cross-device automation sync.

## Local-First And Cloud Automation

AutoLedger is local-first and does not require an account for core bookkeeping. Cloud folio inbox automation is optional. The cloud inbox only receives forwarded email attachments, short-term stores source PDFs when needed, and creates reviewable candidates.

The App still requires user review before saving entries. Cloud automation must not silently write transactions into the ledger.

## Hotel Folio Import

AutoLedger treats hotel folios as reviewable stay records, not just a single OCR amount.

Supported import paths:

- **Manual PDF import**: choose a hotel folio PDF in the Hotel tab. The App extracts text with PDFKit and opens the hotel folio recognition review flow.
- **Share PDF to AutoLedger**: share a hotel folio PDF from Files, Mail, or another app to enter the pending hotel review flow.
- **Local email scan**: as a Pro automation path, the user explicitly connects an IMAP mailbox inside the App. The authorization code stays in local Keychain. The App lists candidate emails with PDF attachments, and the user selects which PDFs to import.
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
- **v1.7.0 Korean scope**: the Korean App UI and `AutoLedgerCore` `ko` recognition pack shipped with ASC `1.6.0`, covering Korean amount, date, merchant, category keywords, and `ko-KR + en-US` OCR hints. Korean store copy, screenshots, and App Preview assets shipped with the release; broader realistic samples, regional depth, and native-language review remain post-release quality work.
- **Release gates and cadence**: the [current release matrix](versions/v1.7.0-i18n-release-matrix.md) requires store, UI, recognition, realistic samples, regional receipt coverage, and human review. The [cross-version localization roadmap](docs/product/I18N_ROADMAP.md) assigns one new language cohort to every public feature release.
- **English primary language**: starting with ASC `1.6.0`, both the engineering fallback and App Store primary-language target are English. Xcode `developmentRegion = en` and ASC Primary Language `English (U.S.) / en-US` require separate evidence.
- **Next quality cohort**: `v1.8.0` is in Early Execution and validates the United States, United Kingdom, Canada, Australia, and Singapore in English without adding a UI language. Phase 2 improves Japanese and adds German and French; Spanish and Brazilian Portuguese move to a later candidate cohort.
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

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for the current release stage and gates, [docs/ROADMAP.md](docs/ROADMAP.md) for the canonical product direction, and [docs/product/I18N_ROADMAP.md](docs/product/I18N_ROADMAP.md) for per-version language cohorts and admission gates. This section is a public summary.

Current repository status:

- `v1.6.0` and `v1.6.1` are complete and continue to map to the ASC / App Store `1.5.0` release line.
- App Store `1.4.0` has been released through the internal `v1.5.1` closeout; `v1.5.0` remains the implementation baseline included in that release.
- `v1.6.2` is complete. It closed SDK adaptation phase 2, hotel email import hardening, deep links, Widgets, App Intents, data reliability, Japanese release-material review, and the GOAL-1960 release-smoke baseline.
- `v1.6.3` is complete for its current scope: the hotel C1 dedicated folio inbox App/Core skeleton, review notes, and regression baseline. C2 Worker login to user mailboxes stays personal-use / future experimental only.
- `v1.6.4` has closed out as the ASC / App Store `1.5.0` baseline. `GOAL-2200` froze the Free / Pro boundary; the Pro page, restore / manage subscription entry points, local email monthly allowance, batch-candidate gate, advanced dedupe gate, C1 Cloudflare Worker, D1/R2/Queue resources, cloud-candidate API, App-side PDFKit conversion, review terms, visionOS / macOS hotfixes, and final baseline tag are now settled.
- `v1.7.0 / ASC 1.6.0` has been released: live OCR, Korean UI and `ko` recognition, the i18n release matrix, reusable `common-api` infrastructure, App Store Server Notifications, ASC metadata-as-code, Pro search / anomaly / monthly ZIP / advanced rule / smart-cleanup features, the first cloud merchant-alias suggestions, local share cards, hotel journey memories, and privacy-safe analytics are closed out on this release line.
- `v1.8.0 / ASC 1.7.0` is in Early Execution for Review & Close, human-readable sync, month close, and the five-market English quality cohort.

| Internal version | App Store | Status | Focus |
| --- | --- | --- | --- |
| v1.4.0 | 1.3.0 | Released | Apple Watch support, accessibility improvements, App Intents, localization, screenshot pipeline updates, optional Support Developer IAP |
| v1.5.0 | 1.4.0 | Included in 1.4.0 release | iPad workspace, batch import, batch OCR / receipt cleanup, foundational multi-device data sync, Apple Watch complications, iPad / Mac screenshot pipeline, and Mac Catalyst workflow |
| v1.5.1 | 1.4.0 | Released | Lower deployment targets, Core parsing refactor, external assist pilot, edit-save stability, iCloud sync performance, current-platform screenshots, and App Preview v001 |
| v1.6.0 | 1.5.0 | Completed | Stronger subscription management, AI subscription hints, merchant / category / subscription learning cache, tvOS read-only dashboard, visionOS showcase, full-platform build / TestFlight / ASC / schema / screenshot closeout |
| v1.6.1 | 1.5.0 | Completed | Hotel folio recognition and archive, foundational multi-ledger support, Japanese localization, cross-platform App Icon redraw, and iOS 27 resizable-layout phase 1; the store version stays on ASC 1.5.0 for internal patch lines |
| v1.6.2 | 1.5.0 by default | Completed | SDK adaptation phase 2, hotel email draft queue / dedupe / batch candidate import, deep-link Router, Widget / App Intents first pass, CSV / JSON and backup-restore smoke, Japanese release-material review, and GOAL-1960 release smoke |
| v1.6.3 | 1.5.0 by default | Completed | Hotel C1 dedicated folio inbox App/Core skeleton: `folio+<token>@getautoledger.app` contract, cloud-candidate model, deep links, PDFKit local-conversion entry, review notes, and regression baseline |
| v1.6.4 | 1.5.0 by default | Completed | Personal Pro foundations and ASC 1.5.0 closeout baseline: Free / Pro boundaries are frozen; the Pro page, restore / manage subscriptions, local email monthly allowance, batch-candidate gate, advanced dedupe gate, C1 Cloudflare Worker, D1/R2/Queue, cloud-candidate API, App-side PDFKit conversion, review terms, visionOS / macOS hotfixes, and final baseline tag are settled |
| v1.7.0 | 1.6.0 | Released | Live OCR and fallbacks; five-language UI / recognition; `common-api`; server subscriptions; ASC metadata-as-code; Pro search, anomaly detection, monthly ZIP, advanced rules, smart cleanup, and first hash-only cloud merchant aliases; share cards, hotel journey memories, and privacy-safe release analytics |
| v1.8.0 | 1.7.0 | Early Execution | Review & Close: persistent pending work, understandable sync state, month close, and format / store / privacy / device admission for five English-speaking markets |

## License

Source code is released under a source-available non-commercial license. See [LICENSE](LICENSE). Code may be used for learning, research, and contributions, but unauthorized commercial use, white-label publishing, marketplace redistribution, hosted services, or distribution after bypassing Pro / IAP / subscription gates is not permitted.

The AutoLedger name, app icon, App Store screenshots, marketing materials, and brand assets are not licensed with the source code and are reserved by the author.
