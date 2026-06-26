# AutoLedgerCoreKit

AutoLedgerCoreKit is a standalone Swift Package used for early platform-neutral parser experiments, worker portability evaluation, and local batch tooling.

The current canonical app core lives in `AutoLedger/AutoLedgerCore`. Treat this package as historical / experimental support material unless a current version plan explicitly says otherwise.

## Contents

```text
AutoLedgerCoreKit/
├── Package.swift
└── Sources/AutoLedgerCoreKit/
    ├── BillRelevanceGate.swift
    ├── ImportedReceipt.swift
    ├── LedgerInterpretationModels.swift
    ├── LedgerTextInterpreterCore.swift
    ├── ReceiptSource.swift
    ├── TransactionCategory.swift
    └── VoiceLedgerParser.swift
```

## Intended Use

- Validate whether parsing logic can remain Foundation-only.
- Prototype receipt relevance, amount, merchant, category, and voice parsing behavior.
- Evaluate whether the parser can run in CLI, worker, or server environments.
- Keep old design and benchmark conclusions reproducible.

## Build

From this package directory:

```bash
cd AutoLedgerCoreKit
swift build
```

This is not the main AutoLedger build gate. For the shipping app and current parser implementation, use the workspace and scripts documented in the repository root README.

## Related Docs

- [../docs/LedgerTextInterpreter.md](../docs/LedgerTextInterpreter.md)
- [../docs/autoledgercore-platform-dependency-audit.md](../docs/autoledgercore-platform-dependency-audit.md)
- [../tools/worker/EVALUATION.md](../tools/worker/EVALUATION.md)

## Maintenance Notes

- Keep this package Foundation-only.
- Do not add UIKit, SwiftUI, WatchConnectivity, Vision, PDFKit, or AppIntents here.
- Do not treat this package as the source of truth for new app features unless it is explicitly reactivated in a current version plan.
