<p align="center">
  <a href="https://app.darkrio326.top/autoledger/">
    <img src="icon.png" width="128" height="128" alt="AutoLedger Icon" />
  </a>
</p>

<h1 align="center">AutoLedger</h1>

<p align="center">
  <strong>ローカル優先の個人台帳、自動取り込み、ホテル明細アーカイブ</strong><br/>
  スクリーンショット、レシート写真、音声、クリップボード、ショートカット、ホテル明細 PDF から、確認可能な個人支出記録を作成します。
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

## ホテル明細の取り込み

AutoLedger はホテル明細を単なる 1 件の金額 OCR として扱わず、確認可能な宿泊消費記録として整理します。

対応する取り込み経路:

- **手動 PDF 取り込み**: ホテルタブでホテル明細 PDF を選択します。App は PDFKit でテキストを抽出し、ホテル明細の認識と確認フローに進みます。
- **PDF を AutoLedger に共有**: Files、Mail、その他の App からホテル明細 PDF を共有すると、ホテル消費の確認待ちフローに入ります。
- **ローカルメールスキャン**: ユーザーが App 内で IMAP メールボックスを明示的に接続します。認証コードはローカル Keychain のみに保存されます。App は PDF 添付付き候補メールを表示し、ユーザーが選択した PDF だけを取り込みます。
- **専用受信箱候補**: Pro 自動化の経路では、ユーザーが `folio+<token>@getautoledger.app` の専用アドレスを取得できます。ホテル明細を手動転送するか、自分のメール側で転送ルールを設定します。Worker は短期間の PDF 候補だけを保存し、App がダウンロード後もローカルでテキスト抽出、認識、確認を行います。

認識対象はホテル名、ブランド / グループ、都市 / 国、チェックイン / チェックアウト日、泊数、部屋タイプ、予約番号、通貨、宿泊料金、税、サービス料、飲食、その他料金、合計、支払い方法、元ファイル、認識信頼度です。確認後は `HotelStayRecord` を作成し、通常の支出取引を関連付けます。既定ではホテル宿泊カテゴリに分類されます。

プライバシー境界:

- Worker はユーザーのメールボックスにログインせず、QQ / IMAP / Gmail / Outlook の認証コードを保存しません。
- ローカルメールスキャンはユーザーの明示的な操作後にのみ実行され、結果は確認待ち状態になります。自動で正式記帳されません。
- クラウド専用受信箱は AutoLedger アドレスへ転送されたメールだけを処理します。ユーザーの個人メールボックスをスキャンしません。
- クラウド上の PDF 候補は短期間のみ保存されます。App が PDF をダウンロード / 変換した後は、可能な場合クラウドコピーを削除します。
- ユーザー確認前に正式台帳へ書き込まれません。ホテル記録と関連取引は App 内で確認、編集、削除できます。

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
- App Store `1.4.0` はリリース済みです。内部 `v1.5.1` がこのリリースラインの最終クローズアウトで、`v1.5.0` は実装ベースラインとして含まれます。
- `v1.6.2` は完了しました。SDK adaptation phase 2、ホテルメール取り込み、Deep link / Widget / App Intents、データ信頼性、日本語リリース素材レビュー、`GOAL-1960` release smoke を収束しました。
- `v1.6.3` は現在の範囲を完了しました。ホテル C1 AutoLedger 専用受信箱の App/Core 第一版骨格、レビュー説明、回帰 baseline までを収束しています。C2 Worker によるユーザー mailbox ログイン型自動スキャンは個人利用または将来の実験扱いのままです。
- `v1.6.4` は開発段階に入りました。`GOAL-2200` で Free / Pro 境界を固定し、プラットフォーム非依存の Pro access policy contract を追加しました。C1 Cloudflare Worker、D1/R2/Queue、token 取得 / ローテーション API、APNs secrets、クラウド候補 API、App 側 PDFKit ローカル変換入口は実装済みです。次は Pro ページ、購入復元、メール自動化 gate、レビュー資料、TestFlight end-to-end 検証を進めます。

| Internal Version | App Store | Status | Focus |
|---|---|---|---|
| v1.5.0 | 1.4.0 | Included in 1.4.0 release | iPad workspace, batch import / recognition, data cleanup, foundational multi-device sync, Watch daily spending and complications, iPad / Mac screenshot pipeline, Mac Catalyst workflow |
| v1.5.1 | 1.4.0 | Released | Lower deployment targets, Core parsing refactor, external assist pilot, edit-save stability, iCloud sync performance, current-platform screenshots, App Preview v001 |
| v1.6.0 | 1.5.0 | Completed | Subscription improvements, learning cache, tvOS / visionOS display apps, full-platform build / TestFlight / ASC / schema / screenshot closeout |
| v1.6.1 | 1.5.0 | Completed | Hotel folio archive, foundational multi-ledger support, Japanese localization, cross-platform App Icon redraw, iOS 27 resizable-layout phase 1 |
| v1.6.2 | 1.5.0 by default | Completed | SDK adaptation phase 2, hotel email draft queue / dedupe / batch candidate import, deep-link Router, Widget / App Intents, data reliability, Japanese release-material review, release smoke |
| v1.6.3 | 1.5.0 by default | Completed | Hotel C1 dedicated folio inbox App/Core skeleton: `folio+<token>@getautoledger.app` contract, cloud candidate model, deep links, PDFKit local conversion entry, review notes, and regression baseline |
| v1.6.4 | 1.5.0 by default | In development | Personal Pro foundation: Free / Pro boundaries now land in `AutoLedgerProAccessPolicy`; `ProEntitlementManager`, the C1 Cloudflare Worker, D1/R2/Queue, token claim / rotation, APNs secrets, cloud-candidate API, and App-side PDFKit conversion have landed; next are Pro page, purchase restore, email automation gates, review material, and TestFlight end-to-end validation |

## License

Source code is released under the MIT License. The AutoLedger name, app icon, App Store screenshots, marketing materials, and brand assets are not included in the MIT license and are reserved by the author.
