# Receipt OCR Batch Tools

Local-only tools for receipt sample regression.

## Batch OCR

```bash
swift tools/receipt_ocr/batch_ocr.swift \
  --input receiptsample/scanned_receipts/data \
  --output .tmp/receipt_ocr/scanned_receipts.ocr.jsonl \
  --limit 20
```

The output is JSONL. Keep it under `.tmp/`; do not commit raw OCR from private images.

## Batch Parse

```bash
bash scripts/run_receipt_batch_regression.sh \
  .tmp/receipt_ocr/scanned_receipts.ocr.jsonl \
  .tmp/receipt_ocr/scanned_receipts.parse.jsonl
```

The parser uses `LedgerTextInterpreterCore`, including the `nonBillImage` relevance gate.

## Batch Report

Generate a Markdown summary report from parse results:

```bash
swift tools/receipt_ocr/batch_report.swift \
  .tmp/receipt_ocr/scanned_receipts.parse.jsonl \
  .tmp/receipt_ocr/scanned_receipts.report.md
```

Report metrics:
- Total samples, amount hit rate, merchant non-empty rate
- Confidence distribution (high/medium/low)
- Non-bill images intercepted count
- Category distribution
- Warning frequency
- Top amount failures (missing or zero)
- Suspicious amounts (>10k or <0.5)

## Golden Regression

```bash
bash scripts/run_golden_regression.sh
```
