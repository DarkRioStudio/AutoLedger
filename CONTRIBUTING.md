# Contributing

Thanks for your interest in AutoLedger.

## Reporting Bugs

- Use GitHub Issues for reproducible bugs.
- Include device, OS version, app version, and clear steps to reproduce.
- Use mock data in reproduction steps.
- Do not upload real receipts, payment screenshots, bank statements, personal finance data, phone numbers, addresses, or identity documents.

## Proposing Features

- Open an issue describing the workflow and why it matters.
- Keep proposals aligned with AutoLedger's local-first and privacy-first direction.
- Avoid changes that require user accounts or server-side transaction processing unless the privacy model is explicit.

## Pull Requests

- Preserve existing Xcode workspace, scheme, target, Bundle Identifier, entitlement, and Xcode Cloud script names unless a maintainer explicitly approves a release migration.
- Keep `AutoLedgerCore` Foundation-only. It should not import UIKit, SwiftUI, WatchConnectivity, or app-only frameworks.
- Include focused tests or regression cases for parser, persistence, and import-path changes.
- Do not commit signing certificates, provisioning profiles, `.p8` keys, `.env` files, local screenshots, or real receipts.

## Sample Data

All committed sample data should be fictional. Use names such as Demo Coffee, Example Market, Sample Store, or similar placeholders.
