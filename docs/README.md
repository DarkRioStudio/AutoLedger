# AutoLedger Docs

This directory is the home for AutoLedger design notes, architecture decisions, platform assessments, and feature drafts.

Root-level Markdown is reserved for repository entry points such as `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, and `AGENTS.md`. Product and engineering design documents should live here.

## Current Index

### Product And Parsing

- [MVP1.0.md](MVP1.0.md) - App Intent one-tap ledger MVP.
- [LedgerTextInterpreter.md](LedgerTextInterpreter.md) - platform-neutral text-to-ledger parsing design.
- [recognition-learning-cache-design.md](recognition-learning-cache-design.md) - merchant, category, subscription, and short-term recognition learning cache.
- [autoledgercore-platform-dependency-audit.md](autoledgercore-platform-dependency-audit.md) - AutoLedgerCore platform dependency audit.
- [minimum-platform-baseline-reduction-plan.md](minimum-platform-baseline-reduction-plan.md) - minimum platform baseline reduction plan.

### Feature Designs

- [autoledger_icloud_backup_design.md](autoledger_icloud_backup_design.md) - iCloud single-file backup and restore design.
- [autoledger_voice_siri_design.md](autoledger_voice_siri_design.md) - voice ledger and Siri interaction design.
- [AutoLedger_Watch_Design.md](AutoLedger_Watch_Design.md) - Apple Watch quick entry and glanceable ledger design.
- [ReceiptDebugTool-implementation-draft.md](ReceiptDebugTool-implementation-draft.md) - local macOS receipt debugging tool implementation draft.
- [shortcuts-json-ledger-import.md](shortcuts-json-ledger-import.md) - Shortcuts JSON ledger import contract.
- [iap-support.md](iap-support.md) - optional Support Developer IAP notes.

### Platform And Release Assets

- [all-platform-screenshot-pipeline-design.md](all-platform-screenshot-pipeline-design.md) - cross-platform screenshot pipeline design.
- [tvos-dashboard-design.md](tvos-dashboard-design.md) - tvOS read-only dashboard design.
- [tvos-implementation-assessment.md](tvos-implementation-assessment.md) - tvOS implementation assessment.
- [visionos-spatial-design.md](visionos-spatial-design.md) - visionOS spatial showcase design.
- [visionos-implementation-assessment.md](visionos-implementation-assessment.md) - visionOS implementation assessment.

## Authoring Rules

- Put new design drafts in `docs/`, not in the repository root.
- Put executable version plans and goal status in `versions/`.
- Put iteration workflow and execution logs in `process/`.
- Keep user-facing release copy in the root README files and App Store material docs.
- Do not include real receipts, payment screenshots, raw OCR from private images, API keys, email authorization codes, certificates, or personal financial data.
