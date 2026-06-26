# AutoLedger Tools

This directory contains local developer tooling for assets, screenshots, OCR regression, feedback automation, and worker evaluation.

These tools are not part of the shipping app runtime. Most generated outputs are local artifacts and should stay out of git unless a tool-specific README says otherwise.

## Directory Index

- [app-icons/](app-icons/) - deterministic App Icon generation, validation, and platform-shaped preview.
- [appstore-screenshots/](appstore-screenshots/) - App Store screenshot export pipeline for iPhone, iPad, Mac Catalyst, Apple Watch, tvOS, and visionOS.
- [receipt_ocr/](receipt_ocr/) - local batch OCR, parse, report, and Golden regression helpers.
- [feedback/](feedback/) - email-to-Issue helper scripts for feedback triage.
- [worker/](worker/) - Worker / remote parser evaluation notes.

## Common Commands

Generate and validate App Icons:

```bash
python3 tools/app-icons/generate_app_icons.py
python3 tools/app-icons/validate_app_icons.py
python3 tools/app-icons/preview_app_icons.py
```

Export App Store screenshots:

```bash
bash tools/appstore-screenshots/scripts/export.sh
```

Run receipt OCR and Golden regression gates:

```bash
bash scripts/run_receipt_batch_regression.sh
bash scripts/run_golden_regression.sh
```

Run feedback helper tests:

```bash
python3 -m pytest tools/feedback/test_email_to_issue.py
```

## Privacy And Safety

- Do not commit raw private receipts, payment screenshots, OCR dumps, email content, API keys, certificates, or authorization codes.
- Keep batch OCR outputs under `.tmp/` or another ignored local directory.
- Screenshot fixtures should use deterministic demo data, not a real personal ledger.
- Tooling should not modify signing, entitlements, schema, bundle identifiers, or `MARKETING_VERSION` unless a version goal explicitly requires it.
