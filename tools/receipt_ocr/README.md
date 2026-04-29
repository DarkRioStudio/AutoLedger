# Receipt OCR Batch Tools

Local-only tools for v1.3.3 receipt sample regression.

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
