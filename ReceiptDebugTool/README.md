# ReceiptDebugTool

ReceiptDebugTool is a local macOS SwiftUI utility for receipt and payment-screenshot parser debugging.

It is a developer tool, not part of the shipping AutoLedger app. It helps inspect images, OCR text, parsed ledger fields, expected results, and Golden Case candidates before changes are promoted into the main parser regression suite.

## Scope

The tool is intended for:

- Dragging in local receipt or payment screenshots.
- Running Vision OCR locally.
- Editing OCR text for debugging.
- Parsing text through the platform-neutral ledger interpretation path.
- Comparing parsed output with expected fields.
- Marking obvious recognition failures.
- Exporting redacted debug logs.
- Exporting Golden Case candidates for later review.

It should not:

- Commit real receipt images to git.
- Upload receipt images or raw OCR text.
- Write directly into the user's production ledger.
- Replace `scripts/run_golden_regression.sh` or `scripts/run_receipt_batch_regression.sh` as release gates.

## Run

Open the project in Xcode:

```bash
open ReceiptDebugTool/ReceiptDebugTool.xcodeproj
```

Or build from the repository root:

```bash
xcodebuild -project ReceiptDebugTool/ReceiptDebugTool.xcodeproj \
  -scheme ReceiptDebugTool \
  -destination 'platform=macOS' \
  build
```

## Related Docs

- [../docs/ReceiptDebugTool-implementation-draft.md](../docs/ReceiptDebugTool-implementation-draft.md)
- [../docs/LedgerTextInterpreter.md](../docs/LedgerTextInterpreter.md)
- [../tools/receipt_ocr/README.md](../tools/receipt_ocr/README.md)

## Privacy

Use synthetic or redacted samples whenever possible. If a local sample contains private financial information, keep it outside git and export only redacted debug material.
