# App Preview Shotlist - zh-Hans

## Version Scope

This shotlist describes the ASC 1.5.0 App Preview video in `hyperframes-v002`.

The ASC 1.4.0 v001 video is preserved under:

```text
tools/appstore-screenshots/app-preview/archive/asc-1.4.0
```

## Source Scenes

| Shot | Purpose | Screenshot pipeline source |
| --- | --- | --- |
| Opening | Review-first bill candidate model | `00_ocr_bill` plus fictional bill cards |
| Quick Ledger | Screenshot recognition and one-sentence entry | `00_ocr_bill`, `01_voice_entry` |
| Hotel | Hotel folio / hotel spending module | `06_hotel_stays` |
| Pro | AutoLedger Pro automation introduction | `07_autoledger_pro` |
| Report | Monthly insight close | `03_monthly_report` |

## Detailed Shots

### Shot 00 - Opening

Source:

- `tools/appstore-screenshots/output/store/ios/zh-Hans/00_ocr_bill.png`
- Fictional cards generated in Hyperframes HTML

Action:

- Stack fictional screenshot and hotel folio bill cards.
- Slide AutoLedger iPhone frame into view.
- Show the privacy note that the video uses demo data.

Copy:

```text
账单先整理好，再由你确认
```

### Shot 01 - Quick Ledger

Source:

- `tools/appstore-screenshots/output/store/ios/zh-Hans/00_ocr_bill.png`
- `tools/appstore-screenshots/output/store/ios/zh-Hans/01_voice_entry.png`

Action:

- Present screenshot recognition as the primary frame.
- Add one-sentence quick entry as a small overlapping frame.
- Highlight the ready-to-save record and show the phrase `午饭 28 元`.

Copy:

```text
截图或一句话，都能变成账单
```

### Shot 02 - Hotel Spending

Source:

- `tools/appstore-screenshots/output/store/ios/zh-Hans/06_hotel_stays.png`

Action:

- Show the hotel spending module.
- Highlight the folio amount detail area.
- Use a `PDF` callout to describe review-before-ledger behavior.

Copy:

```text
酒店水单，整理成消费详情
```

### Shot 03 - AutoLedger Pro

Source:

- `tools/appstore-screenshots/output/store/ios/zh-Hans/07_autoledger_pro.png`

Action:

- Present the AutoLedger Pro screenshot.
- Add Pro badge and automation pills for mailbox scanning, dedicated inbox, and batch candidate organization.
- Highlight that Pro organizes candidates first and does not auto-post without confirmation.

Copy:

```text
Pro 帮你把候选先整理好
```

### Shot 04 - Report

Source:

- `tools/appstore-screenshots/output/store/ios/zh-Hans/03_monthly_report.png`

Action:

- Slight zoom on monthly report.
- Close with app icon lockup and “免费记账不变，Pro 自动整理”.

Copy:

```text
月报统计，一眼看清
```
