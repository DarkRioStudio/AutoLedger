<p align="center">
  <a href="https://app.darkrio326.top/autoledger/">
    <img src="icon.png" width="128" height="128" alt="AutoLedger Icon" />
  </a>
</p>

<h1 align="center">AutoLedger</h1>

<p align="center">
  <strong>本地優先的個人自動化帳本 + 飯店水單歸檔工具</strong><br/>
AutoLedger 是一個本地優先的個人自動化帳本。它可以從截圖、收據、語音、剪貼簿、捷徑和飯店水單 PDF 中擷取消費資訊，生成可複核的帳本記錄。基礎記帳長期免費；Pro 只解鎖郵件水單、批次候選、專屬收件箱等節省時間的自動化能力。
</p>

<p align="center">
  <a href="README.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.en.md">English</a> ·
  <a href="README.ja.md">日本語</a>
</p>

## License / Commercial Use

AutoLedger 採用 source-available 非商業授權，可供學習、個人研究、安全審查與貢獻參考。未經書面許可，不允許商業使用、換皮發布、SaaS / 托管服務、再分發，或將修改版 App 上架到 App Store、Google Play、Steam、Microsoft Store、微信小程式或其他公開應用市場。

不得移除、繞過或篡改 Pro / IAP / 訂閱門禁後分發。AutoLedger 名稱、圖示、截圖、官網素材、App Store 素材、付費牆 artwork 和 README 圖片不隨源碼授權；詳見 [LICENSE](LICENSE) 與 [docs/brand-assets-notice.md](docs/brand-assets-notice.md)。

## 定位 / Why AutoLedger

AutoLedger 不是又一個需要手動填表的記帳 App。它專注於減少重複輸入，把截圖、收據、訂閱和飯店水單這些零散的消費素材整理成結構化記錄。

識別結果預設進入可複核流程，使用者保存前可以檢查和編輯。它適合日常支付截圖、紙本或電子收據、週期訂閱，以及出差 / 旅行後的飯店水單歸檔。

## Features

### 快速記錄

- 截圖 / 拍照收據 OCR，自動擷取金額、商戶和時間。
- 剪貼簿和 Share Extension 匯入，從任意 App 將支付截圖或文字帶進帳本。
- 語音記帳、Siri / 捷徑和 App Intent 輸入。
- iPhone 操作按鈕、控制中心 Widget、Apple Watch 快速記錄。

### 自動整理

- 規則引擎 + 端側 LLM 解析，覆蓋常見支付截圖、收據和帳單文字。
- 分類學習與自訂分類 / 來源，記住使用者修正後的偏好。
- 訂閱識別與提醒，預測週期性扣費。
- 月度報告，展示分類統計、消費趨勢和商戶排行。
- 多帳本，本地帳本、帳本管理、目前帳本 / 全部帳本口徑和預設寫入帳本。
- JSON 匯出 / 匯入與 iCloud 同步 / 備份，便於遷移和恢復。

### 飯店水單工作流

- 手動飯店水單 PDF 匯入，使用 PDFKit 提取文字並進入複核。
- Pro 本機郵件 PDF 候選匯入，使用者主動掃描並選擇要匯入的水單附件。
- Pro 專屬水單收件箱，接收轉寄到 AutoLedger 地址的飯店水單候選。
- 保存前候選複核，不自動把識別結果寫入正式帳本。
- 飯店消費檔案，記錄飯店、品牌 / 集團、入住退房、晚數、費用拆分和關聯流水。

## Free / Pro 邊界

Free 會長期保留可用的日常記帳能力。AutoLedger 不會把既有核心功能移到 Pro 後面，也不會用 Pro 鎖住使用者的帳本歷史。

Free 包括手動記帳、單張截圖 / 拍照匯入、語音 / 文字輸入、手動飯店水單 PDF 匯入、飯店歷史查看、基礎訂閱管理、基礎月報、Widget / Share Extension、JSON 匯入匯出、備份，以及歷史記錄的查看、編輯和刪除。

Pro 的定位是節省時間的自動化，而不是帳本存取權限。Pro 包括或將包括本機郵件水單掃描、批次候選匯入、進階去重，以及專屬雲端水單收件箱。

## 本地優先與雲端自動化

AutoLedger 是本地優先 App，核心記帳不需要帳號。雲端水單收件箱是可選自動化能力，只處理使用者轉寄到 AutoLedger 專屬地址的郵件附件，在需要時短期暫存來源 PDF，並生成可複核候選。

App 仍要求使用者在保存前複核候選結果。雲端自動化不會靜默建立正式帳單，也不會自動把交易寫入使用者帳本。

## Quick Start

**App 內匯入** — 打開 AutoLedger → 選擇截圖 → 識別後確認保存

**一鍵記帳** — 安裝捷徑 → 綁定操作按鈕 → 截圖後按一下進入識別 / 確認流程

**語音記帳** — 在首頁按住麥克風說出「午餐 28 元」等短句；解析結果可在保存前確認。

**分享擴充** — 在微信 / 支付寶等 App 中分享支付截圖 → 選擇 AutoLedger。

## 飯店水單匯入

AutoLedger 的飯店消費不是只識別一筆金額，而是把飯店水單整理成可複核的住宿消費檔案。

支援的匯入入口：

- **手動 PDF 匯入**：在飯店消費模組選擇或拖入飯店水單 PDF，App 使用 PDFKit 提取文字，並進入飯店水單識別與複核流程。
- **分享 PDF 到 App**：從 Files、Mail 或其他 App 分享飯店水單 PDF 到 AutoLedger，可直接進入飯店消費待確認流程。
- **本機信箱掃描**：Pro 自動化路徑中，使用者主動在 App 內連接 IMAP 信箱，授權碼只保存在本機 Keychain；App 拉取帶 PDF 附件的候選郵件，使用者勾選後批次匯入。
- **專屬收件箱候選**：Pro 自動化路徑中，使用者可領取 `folio+<token>@getautoledger.app` 專屬地址，手動轉寄飯店水單郵件或設定自己的信箱轉寄規則；Worker 只短期暫存 PDF 候選，App 下載後仍在本機提取文字、識別和複核。

識別目標包括飯店名稱、品牌 / 集團、城市 / 國家、入住 / 退房日期、晚數、房型、訂單號、幣種、房費、稅費、服務費、餐飲、其他消費、總額、支付方式、來源文件和識別信心度。確認後會產生 `HotelStayRecord`，並自動關聯一條普通支出流水，預設歸入飯店住宿分類。

隱私邊界：

- Worker 不登入使用者信箱，不保存 QQ / IMAP / Gmail / Outlook 授權碼。
- 本機信箱掃描必須由使用者主動觸發，結果進入待確認狀態，不自動正式入帳。
- 雲端專屬收件箱只處理使用者轉寄到 AutoLedger 地址的郵件，不掃描使用者私人信箱。
- PDF 候選在雲端只做短期暫存；App 成功下載 / 轉換後會優先刪除雲端 PDF。
- 使用者確認前不會寫入正式帳本；飯店記錄和關聯流水仍可在 App 內查看、編輯和刪除。

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
- `v1.6.4` 已進入發布收口階段，`GOAL-2200` 完成 Free / Pro 邊界凍結，新增平台無關 Pro 存取策略合同；Pro 頁面、恢復購買 / 管理訂閱、本地郵箱月度免費額度、候選批次 gate、高級去重 gate、C1 Cloudflare Worker、D1/R2/Queue、雲端候選 API 和 App 端 PDFKit 本地轉換入口已落地。production APNs secrets、App Store Server API secrets、ASC sandbox 購買、審核材料和 TestFlight 端到端驗證仍需外部環境收口。
- `v1.7.0` 規劃為 ASC / App Store `1.6.0`：把 Pro 從酒店水單自動化擴展到全帳本效率層，計畫實作進階搜尋、訂閱異常提醒、月結匯出包和進階規則自動套用。

| 內部版本 | App Store | 狀態 | 主要內容 |
|---|---|---|---|
| v1.5.0 | 1.4.0 | 已併入 1.4.0 發布 | iPad 工作台、批量匯入 / 識別、資料清理、基礎多端同步、Watch 今日支出與錶面小工具、iPad / Mac 截圖管線、Mac Catalyst 主線能力 |
| v1.5.1 | 1.4.0 | 已發布 | 最低系統需求優化、識別鏈路 Core 化、外部輔助識別試點、編輯保存穩定性、iCloud 同步性能、目前平台截圖與 App Preview v001 |
| v1.6.0 | 1.5.0 | 已完成 | 訂閱管理補強、AI 訂閱判斷、學習快取、tvOS / visionOS 展示、全平台構建 / TestFlight / ASC / schema / 截圖收口 |
| v1.6.1 | 1.5.0 | 已完成 | 酒店水單識別、多帳本基礎能力、日文支援、跨平台 App Icon 重繪、iOS 27 可拉伸布局階段一 |
| v1.6.2 | 1.5.0 預設沿用 | 已完成 | SDK 適配階段二、酒店郵件草稿佇列 / 去重 / 候選批次匯入、Deep link Router、Widget / App Intents 第一段、資料可靠性、日文發布材料審校和 release smoke |
| v1.6.3 | 1.5.0 預設沿用 | 已完成 | 酒店水單 C1 專屬收件箱第一版 App/Core 骨架：`folio+<token>@getautoledger.app` 合同、雲端候選模型、deep link、PDFKit 本地轉換入口、審核說明和回歸 baseline |
| v1.6.4 | 1.5.0 預設沿用 | 收口中 | Personal Pro 訂閱基礎：Free / Pro 邊界已凍結並落地 `AutoLedgerProAccessPolicy`；`ProEntitlementManager`、Pro 頁面、恢復購買 / 管理訂閱、本地郵箱月度免費額度、候選批次 gate、高級去重 gate、C1 Cloudflare Worker、D1/R2/Queue、雲端候選 API 和 App 端 PDFKit 轉換已落地；production secrets、ASC sandbox 購買、審核材料和 TestFlight 端到端驗證繼續收口 |
| v1.7.0 | 1.6.0 | 規劃中 | Pro 自動化擴展：進階搜尋、訂閱異常提醒、月結匯出包和進階規則自動套用；基礎搜尋、基礎訂閱、基礎匯出和歷史資料仍保持免費 |

## License

原始碼採用 source-available 非商業授權。程式碼可供學習、研究和貢獻參考，但未經書面許可，不允許商業使用、換皮發布、上架修改版 App、SaaS 化、托管服務或繞過 Pro / IAP / 訂閱門禁後分發。AutoLedger 名稱、App 圖示、App Store 截圖、行銷素材與品牌素材不隨源碼授權，相關權利由作者保留。
