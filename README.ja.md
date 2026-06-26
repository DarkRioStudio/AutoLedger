<p align="center">
  <a href="https://app.darkrio326.top/autoledger/">
    <img src="icon.png" width="128" height="128" alt="AutoLedger Icon" />
  </a>
</p>

<h1 align="center">AutoLedger</h1>

<p align="center">
  <strong>スクリーンショットからすぐ記帳 — iPhone / iPad / Apple Watch 向けの支出記録アプリ</strong><br/>
  支払い画面、レシート写真、クリップボード、ショートカット入力から、構造化された支出記録を作成します。
</p>

<p align="center">
  <a href="README.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.en.md">English</a> ·
  <a href="README.ja.md">日本語</a>
</p>

## Features

| | 機能 | 説明 |
|---|---|---|
| 📸 | **スクリーンショット記帳** | 写真、カメラ、クリップボードから取り込み、OCR で金額、店舗名、日時を抽出します |
| ⚡ | **クイック記帳** | iPhone のアクションボタンとショートカットを使い、少ない操作で記帳できます |
| 🎙️ | **音声記帳** | ホームで録音、Siri、または短い文章から支出を入力できます。曖昧な場合は確認画面に進みます |
| 🤖 | **スマート解析** | ルールエンジンと端末側 LLM を組み合わせ、主要な支払い画面やレシート形式に対応します |
| 🔔 | **サブスクリプション管理** | 定期課金を検出し、次回請求日を予測してリマインドします |
| 🏷️ | **カスタム分類 / 取り込み元** | 分類と取り込み元ラベルを編集でき、記帳編集時にも反映されます |
| 💾 | **バックアップと復元** | JSON の手動エクスポート / インポート、iCloud Drive の単一ファイル自動バックアップに対応します |
| 🧾 | **ホテル明細アーカイブ** | ユーザーが選択したホテル明細 PDF またはローカルメール PDF 添付から、確認待ちのホテル滞在記録を作成します |
| 📚 | **複数台帳** | ローカル台帳、台帳管理、現在の台帳 / 全台帳ビュー、既定の書き込み台帳を扱えます |
| 🌐 | **多言語と認識パック** | UI は簡体字中国語、繁体字中国語、英語、日本語に対応し、認識パックは多言語の金額、日付、店舗、分類を扱います |
| 📊 | **月次レポート** | 分類別集計、支出推移、店舗ランキングを確認できます |
| 📤 | **Share Extension** | 他の App からスクリーンショットを AutoLedger に共有できます |
| 🕹️ | **Control Center Widget** | コントロールセンターからクリップボード記帳を起動できます |
| ⌚ | **Apple Watch** | Watch での音声記帳、今日の支出、最近の記録、クイック分類に対応します |
| 🔒 | **Local-first** | 解析はできるだけ端末上で行い、保存前にユーザーが結果を確認する設計です |

## Quick Start

**App 内取り込み** — AutoLedger を開く → スクリーンショットを選択 → 記録を確認します。

**クイック記帳** — ショートカットを追加し、アクションボタンに割り当てると、撮影後に素早く記帳できます。

**音声記帳** — ホームでマイクを押したまま「ランチ 28 元」のように話すと、解析結果を確認できます。

**共有拡張** — 支払い画面やレシート画像を共有し、AutoLedger を選択します。

## Screenshot Preview

App Store スクリーンショットの出力パイプラインは [tools/appstore-screenshots/README.md](tools/appstore-screenshots/README.md) を参照してください。

ローカルプレビューを更新するには `bash tools/appstore-screenshots/scripts/export.sh` を実行し、`tools/appstore-screenshots/output/preview.html` を開きます。

## Localization & Recognition Packs

AutoLedger では UI のローカライズと、レシート / 明細認識用の言語パックを分けています。

- **App UI languages**: 主要なユーザー向け導線は `zh-Hans` 簡体字中国語、`zh-Hant` 繁体字中国語、`en` 英語、`ja` 日本語に対応しています。Main App、Watch、Widget、Control Widget、Share Extension の key 一致は `scripts/check_localization_coverage.py` で検証します。
- **App Store screenshot languages**: iPhone、iPad、Mac、Apple Watch、Apple TV、visionOS のスクリーンショット文言は `zh-Hans` / `zh-Hant` / `en` / `ja` で管理されています。日本語スクリーンショットとストア metadata は提出前に人手で確認します。
- **Recognition language packs**: `AutoLedgerCore` には `zh-Hans`、`zh-Hant`、`en`、`ja` の内蔵パックがあり、レシート関連語、金額形式、日付形式、金額ラベル、店舗ラベル、店舗ではない語の除外、分類キーワード、OCR language hints を扱います。
- **Japanese receipt recognition**: 日本語パックは `合計`、`小計`、`税込`、`店舗`、`注文番号`、`カフェ`、`コンビニ` などを扱います。OCR hint は `ja-JP + en-US` を優先し、金額 / 店舗 / 分類解析はオフライン回帰に含まれています。
- **Extension model**: 今後の言語パックは、純データ、バージョン管理、fallback 可能、レビュー可能な形で追加します。ユーザー訂正の共有は opt-in、脱識別、撤回可能で、reviewed pack に入る前に確認が必要です。このリポジトリでは現時点で遠隔 hot update や自動アップロードは実装していません。

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI, iOS 17+ deployment target, Xcode 27 / iOS 27 SDK adaptive layout |
| OCR | Apple Vision (`VNRecognizeTextRequest`) |
| Parsing | Rule engine + LLM (`SmartReceiptParser`) |
| LLM | Apple Foundation Models / Gemma-2 2B (MediaPipe LLM Inference) |
| Storage | SQLite local store |
| Dependencies | CocoaPods (MediaPipe), SPM (AutoLedgerCore) |
| Watch / Widget | WatchConnectivity, WidgetKit |
| CI | Xcode Cloud |

## Project Structure

```text
AutoLedgerRio/
├── AutoLedger/                            # Xcode project
│   ├── AutoLedger/                        # Main app / iPad / Mac Catalyst target
│   │   ├── App/                           # App entry, store, router, global wiring
│   │   ├── Features/                      # Feedback, Hotel, Inbox, Ledger, Report, Settings, Subscription, iPad
│   │   ├── Domain/                        # App-layer enums, models, services, and intents
│   │   ├── Data/                          # DTOs, mappers, persistence adapters
│   │   ├── Shared/                        # Shared UI, constants, extensions
│   │   ├── Screenshots/                   # Screenshot-mode host and fixtures
│   │   ├── Resources/                     # Localization and resources
│   │   └── Assets.xcassets/               # App assets
│   ├── AutoLedgerCore/                    # Local Swift package, Foundation only
│   ├── AutoLedgerWatch Watch App/         # Apple Watch app
│   ├── AutoLedgerWidgets/                 # iOS Widget extension
│   ├── AutoLedgerWatchWidgetsExtension/   # watchOS Widget / complication
│   ├── ControlWidgetExtension/            # Control Center widget
│   ├── ShareExtension/                    # Share Extension
│   ├── AutoLedgerTV/                      # tvOS read-only dashboard
│   ├── AutoLedgerVision/                  # visionOS showcase
│   ├── Packages/RealityKitContent/        # RealityKit content package
│   └── ci_scripts/                        # Xcode Cloud scripts
├── docs/                                  # Design and topic docs
├── process/                               # Iteration workflow docs
├── scripts/                               # Local regression scripts
├── tests/                                 # Golden regression fixtures
├── tools/app-icons/                       # App icon generation and validation
├── tools/appstore-screenshots/            # App Store screenshot export pipeline
├── tools/receipt_ocr/                     # Receipt OCR batch tooling
└── versions/                              # Version plans and regression baselines
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

現在の主な状態:

- `v1.6.0` と `v1.6.1` は完了しており、ASC / App Store `1.5.0` のリリースラインに対応しています。
- `v1.6.2` は開発中です。SDK adaptation phase 2、ホテルメール取り込みの強化、Deep link / Widget / App Intents、データ信頼性、日本語リリース素材レビューが中心です。
- Device Hub Resize Mode、iPhone Mirroring 連続 resize、visionOS 実機、日本語ネイティブレビューは release smoke / evidence です。ホテル下書き永続化、メール重複排除、Demo Mode、Deep link、Widget、App Intents は `v1.6.2` の開発項目です。

| Internal Version | App Store | Status | Focus |
|---|---|---|---|
| v1.6.0 | 1.5.0 | Completed | Subscription improvements, learning cache, tvOS / visionOS display apps, full-platform build / TestFlight / ASC / schema / screenshot closeout |
| v1.6.1 | 1.5.0 | Completed | Hotel folio archive, foundational multi-ledger support, Japanese localization, cross-platform App Icon redraw, iOS 27 resizable-layout phase 1 |
| v1.6.2 | 1.5.0 by default | Active development | SDK adaptation phase 2, hotel email draft queue / dedupe / Demo Mode, deep-link Router, Widget / App Intents, data reliability, Japanese release-material review |

## License

Source code is released under the MIT License. The AutoLedger name, app icon, App Store screenshots, marketing materials, and brand assets are not included in the MIT license and are reserved by the author.
