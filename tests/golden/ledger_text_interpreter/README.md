# Ledger Text Interpreter Golden Cases

Golden cases protect existing text-to-ledger behavior from regressions.

Each line in `cases.jsonl` is one case:

- `engine`: optional parser engine. Defaults to `core`. Use `receiptParser` to lock existing `SampleReceiptProvider` behavior.
- `sampleTitle`: optional title from `SampleReceiptProvider`. When present, the runner reads the sample's `rawText` and `source`.
- `rawText`: OCR, voice, or manual text.
- `sourceType`: `ocr`, `voice`, `siri`, `clipboard`, `manual`, `share`, or `subscriptionEmail`.
- `localeIdentifier`: optional locale hint such as `ja-JP` to force a specific recognition language pack.
- `receiptSource`: optional `ReceiptSource` for `receiptParser` cases without `sampleTitle`.
- `sourceHint`: optional parser hint: `receipt`, `payment`, `sentence`, `subscription`, `unknown`.
- `expected`: field-level expectations.

Run:

```bash
bash scripts/run_golden_regression.sh
```

These cases should contain text only or references to built-in samples. Do not commit original receipt images.
