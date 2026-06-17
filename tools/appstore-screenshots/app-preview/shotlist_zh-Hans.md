# App Preview Shotlist - zh-Hans

## Source Scenes

| Shot | Purpose | Screenshot pipeline source |
| --- | --- | --- |
| Opening | Pain point and quick setup | `00_ocr_bill` plus optional fictional payment / receipt mock |
| OCR | Screenshot to ready record | `00_ocr_bill` / `ocr_bill` |
| Voice | One-sentence quick entry | `01_voice_entry` / `voice_entry` |
| Watch | Wrist entry and ecosystem continuity | `00_watch_quick_add`, `01_watch_recent`, `03_watch_sync` |
| Report | Monthly insight close | `03_monthly_report` / `monthly_report` |
| Shortcuts backup | Optional automation cutaway | `05_shortcuts_import` / `import_methods` |

## Detailed Shots

### Shot 00 - Opening

Source:

- `tools/appstore-screenshots/output/store/ios/zh-Hans/00_ocr_bill.png`
- Optional fictional payment or receipt mock

Action:

- Stack two or three fictional payment cards.
- Slide AutoLedger iPhone frame into view.

Copy:

```text
每天花钱，不想手动记？
```

### Shot 01 - OCR

Source:

- `tools/appstore-screenshots/output/raw/ios/zh-Hans/00_ocr_bill.png`
- `tools/appstore-screenshots/output/store/ios/zh-Hans/00_ocr_bill.png`

Action:

- Highlight amount, merchant, category, and time.
- Show the generated ledger record.

Copy:

```text
截图账单，一键识别
```

### Shot 02 - Voice

Source:

- `tools/appstore-screenshots/output/store/ios/zh-Hans/01_voice_entry.png`

Action:

- Animate the phrase "午饭 28 元".
- Highlight the ready-to-save record.

Copy:

```text
说一句话，快速记账
```

### Shot 03 - Watch

Source:

- `tools/appstore-screenshots/output/store/watch/zh-Hans/00_watch_quick_add.png`
- `tools/appstore-screenshots/output/store/watch/zh-Hans/01_watch_recent.png`
- `tools/appstore-screenshots/output/store/watch/zh-Hans/03_watch_sync.png`

Action:

- Show Watch quick add.
- Pair with iPhone recent record or sync message.

Copy:

```text
抬腕也能记一笔
```

### Shot 04 - Report

Source:

- `tools/appstore-screenshots/output/store/ios/zh-Hans/03_monthly_report.png`

Action:

- Slight zoom on category and monthly totals.
- Fade to app icon or final screenshot.

Copy:

```text
月报统计，一眼看清
```

## Optional Material

- `05_shortcuts_import` can be used as a short automation cutaway if the preview needs one extra beat.
- Watch face complication screenshots should be manually supplied when available because the current pipeline does not automate real watch face capture.
