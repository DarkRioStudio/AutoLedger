<p align="center">
  <a href="https://app.darkrio326.top/autoledger/">
    <img src="icon.png" width="128" height="128" alt="AutoLedger Icon" />
  </a>
</p>

<h1 align="center">AutoLedger</h1>

<p align="center">
  <strong>ローカルファーストの個人向け自動化家計簿 + ホテル明細アーカイブ</strong><br/>
AutoLedger はローカルファーストの個人向け自動化家計簿です。スクリーンショット、レシート、音声入力、クリップボード、ショートカット、ホテル明細 PDF から支出情報を抽出し、確認可能な帳簿記録に変換します。基本的な記帳機能は継続して無料で利用でき、Pro はメール明細、候補の一括処理、専用明細受信箱など、時間を節約する自動化機能のみを解放します。
</p>

<p align="center">
  <a href="README.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.en.md">English</a> ·
  <a href="README.ja.md">日本語</a>
</p>

## License / Commercial Use

AutoLedger は source-available の非商用ライセンスで公開されています。学習、個人研究、セキュリティレビュー、貢献のために参照できます。書面による許可なく、商用利用、ホワイトラベル公開、SaaS / ホスト型再配布、または改変版 App を App Store、Google Play、Steam、Microsoft Store、WeChat Mini Programs などの公開マーケットへ公開することはできません。

Pro / IAP / サブスクリプションのゲートを削除、回避、改ざんして配布することはできません。AutoLedger の名称、アイコン、スクリーンショット、Web サイト素材、App Store 素材、ペイウォール artwork、README 画像はソースコードには含まれません。詳しくは [LICENSE](LICENSE) と [docs/brand-assets-notice.md](docs/brand-assets-notice.md) を参照してください。

## 位置づけ / Why AutoLedger

AutoLedger は、手入力を前提にした単なる家計簿 App ではありません。スクリーンショット、レシート、サブスクリプション、ホテル明細など、散らばりやすい支出素材を整理し、繰り返し入力を減らすことに重点を置いています。

解析結果は保存前に確認できます。日常の支払いスクリーンショット、紙または電子レシート、継続課金、出張や旅行後のホテル明細アーカイブに向いています。

## Features

### Quick Capture

- スクリーンショット / レシート写真 OCR で金額、店舗名、日時を抽出します。
- クリップボードと Share Extension から、他の App の支払い画面やテキストを取り込めます。
- 音声記帳、Siri / ショートカット、App Intent 入力に対応します。
- iPhone のアクションボタン、Control Center Widget、Apple Watch から素早く記録できます。

### Automatic Organization

- ルールエンジン + 端末側 LLM で、一般的な支払いスクリーンショット、レシート、明細テキストを解析します。
- 分類学習とカスタム分類 / 取り込み元ラベルで、ユーザーの修正を次回以降に活かします。
- サブスクリプション認識とリマインダーで、継続課金を見落としにくくします。
- 月次レポートで、分類別集計、支出推移、店舗ランキングを確認できます。
- 複数台帳、ローカル台帳、台帳管理、現在の台帳 / 全台帳ビュー、既定の書き込み台帳を扱えます。
- JSON エクスポート / インポートと iCloud 同期 / バックアップで、移行と復元を支えます。

### Hotel Folio Workflow

- 手動ホテル明細 PDF 取り込み。PDFKit でテキストを抽出し、確認フローに進みます。
- Pro のローカルメール PDF 候補取り込み。ユーザーが明示的にスキャンし、取り込む明細添付を選択します。
- Pro 専用明細受信箱。AutoLedger アドレスへ転送されたホテル明細候補を受け取ります。
- 保存前に候補を確認し、解析結果を正式な台帳へ自動投稿しません。
- ホテル消費アーカイブとして、ホテル、ブランド / グループ、宿泊日、泊数、料金内訳、関連取引を整理します。

## Free / Pro の境界

Free は日常の記帳に使い続けられます。AutoLedger は既存の主要機能を Pro の背後へ移動せず、Pro によってユーザーの台帳履歴をロックしません。

Free には、手動記帳、単一スクリーンショット / 写真取り込み、音声 / テキスト入力、手動ホテル明細 PDF 取り込み、ホテル履歴の確認、基本的なサブスクリプション管理、基本レポート、Widget / Share Extension、エクスポート / インポート、バックアップ、履歴記録の表示、編集、削除が含まれます。

Pro は台帳へのアクセス制限ではなく、時間を節約する自動化です。Pro には、ローカルメール明細スキャン、候補の一括取り込み、高度な重複排除、専用クラウド明細受信箱が含まれる、または今後含まれます。

## ローカルファーストとクラウド自動化

AutoLedger はローカルファーストで、主要な記帳機能にアカウントは不要です。クラウド明細受信箱は任意の自動化機能で、AutoLedger 専用アドレスへ転送されたメール添付のみを受け取り、必要に応じて元 PDF を短期間保存し、確認可能な候補を作成します。

App は保存前のユーザー確認を引き続き必要とします。クラウド自動化が取引を静かに台帳へ書き込むことはありません。

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
- **ローカルメールスキャン**: Pro の自動化経路として、ユーザーが App 内で IMAP メールボックスを明示的に接続します。認証コードはローカル Keychain のみに保存されます。App は PDF 添付付き候補メールを表示し、ユーザーが選択した PDF だけを取り込みます。
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
- `v1.7.0` は ASC / App Store `1.6.0` として計画しています。Pro をホテル明細の自動化から台帳全体の効率化へ広げ、高度な検索、サブスク異常通知、月次エクスポートパッケージ、高度なルール自動化を実装予定です。

| Internal Version | App Store | Status | Focus |
|---|---|---|---|
| v1.5.0 | 1.4.0 | Included in 1.4.0 release | iPad workspace, batch import / recognition, data cleanup, foundational multi-device sync, Watch daily spending and complications, iPad / Mac screenshot pipeline, Mac Catalyst workflow |
| v1.5.1 | 1.4.0 | Released | Lower deployment targets, Core parsing refactor, external assist pilot, edit-save stability, iCloud sync performance, current-platform screenshots, App Preview v001 |
| v1.6.0 | 1.5.0 | Completed | Subscription improvements, learning cache, tvOS / visionOS display apps, full-platform build / TestFlight / ASC / schema / screenshot closeout |
| v1.6.1 | 1.5.0 | Completed | Hotel folio archive, foundational multi-ledger support, Japanese localization, cross-platform App Icon redraw, iOS 27 resizable-layout phase 1 |
| v1.6.2 | 1.5.0 by default | Completed | SDK adaptation phase 2, hotel email draft queue / dedupe / batch candidate import, deep-link Router, Widget / App Intents, data reliability, Japanese release-material review, release smoke |
| v1.6.3 | 1.5.0 by default | Completed | Hotel C1 dedicated folio inbox App/Core skeleton: `folio+<token>@getautoledger.app` contract, cloud candidate model, deep links, PDFKit local conversion entry, review notes, and regression baseline |
| v1.6.4 | 1.5.0 by default | In development | Personal Pro foundation: Free / Pro boundaries now land in `AutoLedgerProAccessPolicy`; `ProEntitlementManager`, the C1 Cloudflare Worker, D1/R2/Queue, token claim / rotation, APNs secrets, cloud-candidate API, and App-side PDFKit conversion have landed; next are Pro page, purchase restore, email automation gates, review material, and TestFlight end-to-end validation |
| v1.7.0 | 1.6.0 | Planned | Pro automation expansion: advanced search, subscription anomaly alerts, monthly export packages, and advanced rule automation while basic search, subscriptions, export, and history remain free |

## License

Source code is released under a source-available non-commercial license. The code may be used for learning, research, and contributions, but unauthorized commercial use, white-label publishing, marketplace redistribution, hosted services, or distribution after bypassing Pro / IAP / subscription gates is not permitted. The AutoLedger name, app icon, App Store screenshots, marketing materials, and brand assets are not licensed with the source code and are reserved by the author.
