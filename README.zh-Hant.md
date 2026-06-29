<p align="center">
  <a href="https://app.darkrio326.top/autoledger/">
    <img src="icon.png" width="128" height="128" alt="AutoLedger Icon" />
  </a>
</p>

<h1 align="center">AutoLedger</h1>

<p align="center">
  <strong>本地優先的個人自動化帳本與酒店水單歸檔工具</strong><br/>
  透過截圖、拍照小票、語音、剪貼簿、捷徑和酒店水單 PDF，把消費資訊整理成可複核的個人帳本。
</p>

<p align="center">
  <a href="README.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.en.md">English</a> ·
  <a href="README.ja.md">日本語</a>
</p>

## Features

| | 功能 | 說明 |
|---|---|---|
| 📸 | **截圖記帳** | 從相簿、相機或剪貼簿匯入，OCR 自動識別金額、商戶和時間 |
| ⚡ | **一鍵記帳** | 搭配 iPhone 操作按鈕與捷徑，一次完成匯入與記帳流程 |
| 🎙️ | **語音記帳** | 首頁按住錄音、Siri 或輸入一句話記錄支出；高信心直接保存，不明確時進入確認 |
| 🤖 | **智慧解析** | 規則引擎 + 端側 LLM 雙模式，覆蓋微信、支付寶、App Store、抖音團購等常見場景 |
| 🔔 | **訂閱識別與提醒** | 識別週期性訂閱扣費，預測下次扣費日並提前提醒 |
| 🏷️ | **自訂分類 / 來源** | 可自由增減分類和來源標籤，編輯帳單時即時生效 |
| 💾 | **備份與恢復** | JSON 手動匯出 / 匯入，iCloud Drive 單檔自動備份，重裝後提示恢復 |
| 🧾 | **酒店消費歸檔** | 從酒店水單 PDF 或使用者主動選擇的本機郵件 PDF 附件產生待確認酒店消費記錄 |
| 📚 | **多帳本** | 支援本地帳本、帳本管理、目前帳本 / 全部帳本口徑和預設寫入帳本 |
| 🌐 | **多語言與識別語言包** | App UI 覆蓋簡體中文、繁體中文、英文、日文；帳單解析語言包支援多語金額、日期、商戶和分類識別 |
| 📊 | **月度報告** | 分類統計、消費趨勢、商戶排名一目了然 |
| 📤 | **Share Extension** | 在任意 App 中分享截圖即可直接匯入 |
| 🕹️ | **控制中心 Widget** | 從控制中心直接觸發剪貼簿記帳 |
| ⌚ | **Apple Watch** | 手錶語音記帳、今日支出、最近帳單與快速分類記帳，透過 WatchConnectivity 與 iPhone 同步 |
| 🔒 | **本地優先** | 帳單解析以端側處理為主；保存前建議使用者確認結果；請不要在公開 Issue 中上傳真實小票或個人財務資料 |

## Quick Start

**App 內匯入** — 打開 AutoLedger → 選擇截圖 → 產生帳單

**一鍵記帳** — 安裝捷徑 → 綁定操作按鈕 → 截圖後按一下記帳

**語音記帳** — 在首頁按住麥克風說出「午餐 28 元」等短句；不明確時可進入確認頁。

**分享擴充** — 在微信 / 支付寶等 App 中分享支付截圖 → 選擇 AutoLedger。

## 酒店消費匯入

AutoLedger 的酒店消費不是只識別一筆金額，而是把酒店水單整理成可複核的住宿消費檔案。

支援的匯入入口：

- **手動 PDF 匯入**：在酒店消費模組選擇或拖入酒店水單 PDF，App 使用 PDFKit 提取文字，並進入酒店水單識別與複核流程。
- **分享 PDF 到 App**：從 Files、Mail 或其他 App 分享酒店水單 PDF 到 AutoLedger，可直接進入酒店消費待確認流程。
- **本機信箱掃描**：使用者主動在 App 內連接 IMAP 信箱，授權碼只保存在本機 Keychain；App 拉取帶 PDF 附件的候選郵件，使用者勾選後批次匯入。
- **專屬收件箱候選**：Pro 自動化路徑中，使用者可領取 `folio+<token>@getautoledger.app` 專屬地址，手動轉寄酒店水單郵件或設定自己的信箱轉寄規則；Worker 只短期暫存 PDF 候選，App 下載後仍在本機提取文字、識別和複核。

識別目標包括酒店名稱、品牌 / 集團、城市 / 國家、入住 / 退房日期、晚數、房型、訂單號、幣種、房費、稅費、服務費、餐飲、其他消費、總額、支付方式、來源文件和識別信心度。確認後會產生 `HotelStayRecord`，並自動關聯一條普通支出流水，預設歸入酒店住宿分類。

隱私邊界：

- Worker 不登入使用者信箱，不保存 QQ / IMAP / Gmail / Outlook 授權碼。
- 本機信箱掃描必須由使用者主動觸發，結果進入待確認狀態，不自動正式入帳。
- 雲端專屬收件箱只處理使用者轉寄到 AutoLedger 地址的郵件，不掃描使用者私人信箱。
- PDF 候選在雲端只做短期暫存；App 成功下載 / 轉換後會優先刪除雲端 PDF。
- 使用者確認前不會寫入正式帳本；酒店記錄和關聯流水仍可在 App 內查看、編輯和刪除。

## Screenshot Preview

App Store 截圖管線說明：[tools/appstore-screenshots/README.md](tools/appstore-screenshots/README.md)

如需刷新本機截圖預覽，執行 `bash tools/appstore-screenshots/scripts/export.sh`，然後開啟 `tools/appstore-screenshots/output/preview.html`。

## Localization & Recognition Packs

AutoLedger 的介面本地化和帳單識別語言包是兩層獨立能力：

- **App UI 語言**：目前主路徑覆蓋 `zh-Hans` 簡體中文、`zh-Hant` 繁體中文、`en` 英文和 `ja` 日文；主 App、Watch、Widget、Control Widget、Share Extension 的 key 集合由 `scripts/check_localization_coverage.py` 校驗。
- **App Store 截圖語言**：截圖管線已按 `zh-Hans` / `zh-Hant` / `en` / `ja` 組織 iPhone、iPad、Mac、Apple Watch、Apple TV 和 visionOS 場景文案；日文截圖和商店 metadata 仍需人工審校後再提交。
- **帳單識別語言包**：`AutoLedgerCore` 內建 `zh-Hans`、`zh-Hant`、`en`、`ja` 識別包，承載帳單關鍵詞、金額格式、日期格式、分層金額標籤、商戶標籤、非商戶排除詞、分類關鍵詞和 OCR 語言提示。
- **日文帳單識別**：日文包覆蓋 `合計`、`小計`、`税込`、`店舗`、`注文番号`、`カフェ`、`コンビニ` 等常見欄位；OCR hint 使用 `ja-JP + en-US`，金額和商戶 / 分類解析已進入離線回歸。
- **擴展原則**：後續語言包以純資料、版本化、可 fallback 的方式擴展；使用者糾錯共享必須 opt-in、脫敏、可撤回，並經審核後才可能進入 reviewed pack。本倉庫目前不實作遠端語言包熱更新或自動上傳。

## Tech Stack

| 層級 | 技術 |
|------|------|
| UI | SwiftUI, iOS 17+ deployment target, Xcode 27 / iOS 27 SDK adaptive layout |
| OCR | Apple Vision (`VNRecognizeTextRequest`) |
| 解析 | 規則引擎 + LLM (`SmartReceiptParser`) |
| LLM | Apple Foundation Models / Gemma-2 2B (MediaPipe LLM Inference) |
| 儲存 | SQLite（本機） |
| 依賴管理 | CocoaPods (MediaPipe), SPM (AutoLedgerCore) |
| Watch / Widget | WatchConnectivity, WidgetKit |
| CI | Xcode Cloud |

## Project Structure

```text
AutoLedgerRio/
├── AutoLedger/                            # Xcode 工程
│   ├── AutoLedger/                        # 主 App / iPad / Mac Catalyst target
│   │   ├── App/                           # 入口、Store、Router、全域組裝
│   │   ├── Features/                      # Feedback, Hotel, Inbox, Ledger, Report, Settings, Subscription, iPad
│   │   ├── Domain/                        # App 層 Enums、Models、Services、Intents
│   │   ├── Data/                          # DTO、Mapper、Persistence adapter
│   │   ├── Shared/                        # 共用元件、常數、擴充
│   │   ├── Screenshots/                   # 截圖模式 host 與 fixture UI
│   │   ├── Resources/                     # 多語言資源與設定
│   │   └── Assets.xcassets/               # App 資產
│   ├── AutoLedgerCore/                    # 本機 Swift Package，純 Foundation
│   ├── AutoLedgerWatch Watch App/         # Apple Watch App
│   ├── AutoLedgerWidgets/                 # iOS Widget Extension
│   ├── AutoLedgerWatchWidgetsExtension/   # watchOS Widget / complication
│   ├── ControlWidgetExtension/            # 控制中心 Widget
│   ├── ShareExtension/                    # Share Extension
│   ├── AutoLedgerTV/                      # tvOS 只讀看板
│   ├── AutoLedgerVision/                  # visionOS 展示版
│   ├── Packages/RealityKitContent/        # visionOS RealityKit 內容包
│   └── ci_scripts/                        # Xcode Cloud 腳本
├── docs/                                  # 設計與專題文件
├── process/                               # 迭代流程文件
├── scripts/                               # 本機回歸腳本
├── tests/                                 # Golden regression fixtures
├── tools/app-icons/                       # App Icon 生成與驗證
├── tools/appstore-screenshots/            # App Store 截圖匯出管線
├── tools/receipt_ocr/                     # 小票 OCR 批處理工具
└── versions/                              # 版本計畫與回歸基線
```

## Build

```bash
cd AutoLedger
pod install

xcodebuild -workspace AutoLedger.xcworkspace \
  -scheme AutoLedger \
  -destination 'generic/platform=iOS' \
  build

cd ..
bash scripts/run_offline_regression.sh
bash scripts/run_golden_regression.sh
```

## Roadmap

目前主線狀態：

- `v1.6.0` 與 `v1.6.1` 已完成，並繼續對應 ASC / App Store `1.5.0` 大版本口徑。
- App Store `1.4.0` 已發布；內部 `v1.5.1` 是該發布線的最終收口版本，`v1.5.0` 作為實作基線併入發布。
- `v1.6.2` 已完成，收口 SDK 適配階段二、酒店郵件匯入、Deep link / Widget / App Intents、資料可靠性、日文發布材料審校和 `GOAL-1960` release smoke。
- `v1.6.3` 已完成目前範圍：酒店 C1 AutoLedger 專屬收件箱第一版 App/Core 工程骨架、審核說明和回歸 baseline；C2 Worker 登入使用者信箱自動掃描僅保留為個人自用或未來實驗路線。
- `v1.6.4` 已進入開發階段，`GOAL-2200` 完成 Free / Pro 邊界凍結，新增平台無關 Pro 存取策略合同；C1 Cloudflare Worker、D1/R2/Queue、token 領取 / 輪換 API、APNs secrets、雲端候選 API 和 App 端 PDFKit 本地轉換入口已落地。後續繼續推進 Pro 頁面、恢復購買、郵箱自動化 gate、審核材料和 TestFlight 端到端驗證。

| 內部版本 | App Store | 狀態 | 主要內容 |
|---|---|---|---|
| v1.5.0 | 1.4.0 | 已併入 1.4.0 發布 | iPad 工作台、批量匯入 / 識別、資料清理、基礎多端同步、Watch 今日支出與錶面小工具、iPad / Mac 截圖管線、Mac Catalyst 主線能力 |
| v1.5.1 | 1.4.0 | 已發布 | 最低系統需求優化、識別鏈路 Core 化、外部輔助識別試點、編輯保存穩定性、iCloud 同步性能、目前平台截圖與 App Preview v001 |
| v1.6.0 | 1.5.0 | 已完成 | 訂閱管理補強、AI 訂閱判斷、學習快取、tvOS / visionOS 展示、全平台構建 / TestFlight / ASC / schema / 截圖收口 |
| v1.6.1 | 1.5.0 | 已完成 | 酒店水單識別、多帳本基礎能力、日文支援、跨平台 App Icon 重繪、iOS 27 可拉伸布局階段一 |
| v1.6.2 | 1.5.0 預設沿用 | 已完成 | SDK 適配階段二、酒店郵件草稿佇列 / 去重 / 候選批次匯入、Deep link Router、Widget / App Intents 第一段、資料可靠性、日文發布材料審校和 release smoke |
| v1.6.3 | 1.5.0 預設沿用 | 已完成 | 酒店水單 C1 專屬收件箱第一版 App/Core 骨架：`folio+<token>@getautoledger.app` 合同、雲端候選模型、deep link、PDFKit 本地轉換入口、審核說明和回歸 baseline |
| v1.6.4 | 1.5.0 預設沿用 | 開發中 | Personal Pro 訂閱基礎：Free / Pro 邊界已凍結並落地 `AutoLedgerProAccessPolicy`；`ProEntitlementManager` 第一版、C1 Cloudflare Worker、D1/R2/Queue、token 領取 / 輪換、APNs secrets、雲端候選 API 和 App 端 PDFKit 轉換已落地；後續推進 Pro 頁面、恢復購買、郵箱自動化 gate、授權引導、審核材料和 TestFlight 端到端驗證 |

## License

原始碼使用 MIT License。AutoLedger 名稱、App 圖示、App Store 截圖、行銷素材與品牌素材不包含在 MIT License 授權範圍內，相關權利由作者保留。
