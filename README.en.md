# AutoLedger

[中文 README](README.md)

AutoLedger is a fast local-first expense capture app for iPhone, iPad, and Apple Watch.

AutoLedger helps turn payment screenshots, camera receipts, clipboard text, and Shortcuts/App Intent input into structured personal expense records.

## Features

- Screenshot-based expense capture
- On-device OCR-based parsing
- Camera receipt capture
- Clipboard import
- Shortcuts / App Intent support
- Apple Watch quick entry
- Share Extension import from other apps
- Control Center widget for quick clipboard import
- iCloud backup / restore support
- Local-first personal bookkeeping workflow

## Privacy

AutoLedger is designed as a local-first personal bookkeeping app.

- No account is required by default.
- Transaction parsing is designed to happen on device where possible.
- Users should review parsed results before saving.
- Debug and feedback exports may contain private transaction details if users choose to generate them.
- Please do not upload real receipts, payment screenshots, or personal finance data in public issues.

The app includes optional local model support and StoreKit support purchases. Store metadata, signing credentials, and production account configuration are not part of this repository.

## Build Requirements

- Xcode 26 beta
- Swift 6 / SwiftUI
- CocoaPods
- iOS 26 or later for the main app target
- watchOS 11 or later for the Watch app target

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
│   ├── AutoLedger/                 # iOS app target
│   ├── AutoLedgerCore/             # Local Swift package, Foundation only
│   ├── AutoLedgerWatch Watch App/  # Apple Watch app target
│   ├── AutoLedgerWidgets/          # Widget extension
│   ├── ControlWidgetExtension/     # Control Center widget extension
│   ├── ShareExtension/             # Share extension
│   └── ci_scripts/                 # Xcode Cloud setup scripts
├── scripts/                        # Local regression scripts
├── tests/                          # Golden regression fixtures
├── tools/                          # Screenshot, feedback, and OCR tools
├── process/                        # Agent iteration workflow docs
└── versions/                       # Version plans and release notes
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

| Internal version | App Store | Status | Focus |
| --- | --- | --- | --- |
| v1.4.0 | 1.3.0 | Released | Apple Watch support, accessibility improvements, App Intents, localization, screenshot pipeline updates, optional Support Developer IAP |
| v1.5.0 | 1.4.0 | Baseline complete | iPad workspace, batch import, batch OCR / receipt cleanup, foundational multi-device data sync, Apple Watch complications, iPad / Mac screenshot pipeline, and Mac Catalyst workflow |
| v1.5.1 | 1.4.0 | Release candidate | Lower deployment targets, Core parsing refactor, external assist pilot, edit-save stability, iCloud sync performance, current-platform screenshots, and App Preview v001; tvOS / visionOS and multi-ledger support are deferred |
| v1.6.0 | TBD 1.5.0 | Planned | Stronger subscription management, AI subscription hints, merchant / category / subscription learning cache, tvOS read-only dashboard, visionOS showcase, and continued Mac / cross-platform polish |

## License

Source code is released under the MIT License.

The AutoLedger name, app icon, App Store screenshots, marketing materials, and brand assets are not included in the MIT license and are reserved by the author.
