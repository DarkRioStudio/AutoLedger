<p align="center">
  <a href="https://app.darkrio326.top/autoledger/">
    <img src="icon.png" width="128" height="128" alt="AutoLedger Icon" />
  </a>
</p>

<h1 align="center">AutoLedger</h1>

<p align="center">
  <strong>截图即记账 — iPhone / iPad / Apple Watch 自动化消费记录工具</strong><br/>
  拍一张支付截图、拍照小票、粘贴剪贴板内容或通过快捷指令触发，快速生成账单。
</p>

<p align="center">
  <a href="README.en.md">English README</a>
</p>

<p align="center">
  <a href="https://app.darkrio326.top/autoledger/"><img src="https://img.shields.io/badge/官网-app.darkrio326.top-orange?logo=safari&logoColor=white" alt="官网" /></a>
  <img src="https://img.shields.io/badge/platform-iOS_26+-blue?logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License" />
</p>

---

## Features

| | 功能 | 说明 |
|---|---|---|
| 📸 | **截图记账** | 相册选取 / 拍照 / 剪切板粘贴，OCR 自动识别金额、商户和时间 |
| ⚡ | **一键记账** | iPhone 操作按钮 + 快捷指令，按一下完成全流程 |
| 🎙️ | **语音记账** | 首页按住录音、Siri 或输入一句话记录支出，高置信直接保存，不明确时进入确认 |
| 🤖 | **智能解析** | 规则引擎 + 端侧 LLM（Apple Intelligence / Gemma-2 2B）双模式，覆盖微信、支付宝、App Store、抖音团购等 |
| 🧠 | **Gemma 端侧推理** | MediaPipe LLM Inference，CDN 分发 + SHA-256 完整性校验，推理后自动释放内存 |
| 🔔 | **订阅识别与提醒** | 自动识别周期性订阅扣费，预测下次扣费日并提前提醒 |
| 🏷️ | **自定义分类 / 来源** | 自由增减分类和来源标签，编辑账单时即时生效并持久化 |
| 🧠 | **分类学习** | 记住用户修正历史，同商户后续入账自动使用偏好分类 |
| 🗑️ | **最近删除 & 手动记账** | 删除账单可跨会话恢复；账本右上角可手动录入不依赖截图的账单 |
| 💾 | **数据备份与恢复** | JSON 手动导出/导入，iCloud Drive 单文件自动备份，重装后提示恢复 |
| 📊 | **月度报告** | 分类统计、消费趋势、商户排名一目了然 |
| 📤 | **Share Extension** | 在任意 App 中分享截图直接导入 |
| 🕹️ | **控制中心 Widget** | 从控制中心直接触发剪切板记账，无需解锁进 App |
| ⌚ | **Apple Watch** | 腕上语音记账、今日支出、最近账单、快速分类记账，通过 WatchConnectivity 与 iPhone 同步 |
| 🔒 | **本地优先** | 账单解析以端侧处理为主；用户保存前应确认识别结果；请不要在公开 Issue 中上传真实小票、支付截图或个人财务数据 |

## Quick Start

**App 内导入** — 打开 AutoLedger → 选择截图 → 自动入账

**一键记账（推荐）** — [安装快捷指令](https://www.icloud.com/shortcuts/e64528fb5bc34afdab4d7c64242d537e) → 绑定操作按钮 → 按一下记账

**语音记账** — 在首页按住麦克风说「午饭 28 元」可快速识别，高置信结果自动保存；账本页仍可点击波形按钮输入一句话，账本字段会实时生成并可确认保存，也可通过 Siri/快捷指令触发语音记账

**分享扩展** — 在微信/支付宝中分享截图 → 选择 AutoLedger

## Screenshot Preview

App Store 截图管线说明：[tools/appstore-screenshots/README.md](tools/appstore-screenshots/README.md)

如需刷新本地截图预览，运行 `bash tools/appstore-screenshots/scripts/export.sh`，然后打开本地生成的 `tools/appstore-screenshots/output/preview.html`。

## Tech Stack

| 层级 | 技术 |
|------|------|
| UI | SwiftUI, iOS 26 |
| OCR | Apple Vision (`VNRecognizeTextRequest`) |
| 解析 | 规则引擎 + LLM (SmartReceiptParser) |
| LLM | Apple Foundation Models / Gemma-2 2B (MediaPipe LLM Inference) |
| 模型分发 | Cloudflare R2 CDN + SHA-256 (CryptoKit) |
| 存储 | SQLite (本地) |
| 架构 | MVVM + 依赖注入 |
| 依赖管理 | CocoaPods (MediaPipe), SPM (AutoLedgerCore) |
| 快捷指令 | AppIntents / `ForegroundContinuableIntent` |
| 分享 | Share Extension |
| Watch | watchOS 11, WatchConnectivity |
| Widget | WidgetKit (主屏 & 控制中心) |
| CI | Xcode Cloud |

## Project Structure

```text
AutoLedgerRio/
├── AutoLedger/                    # Xcode 工程
│   ├── AutoLedger/                # 主 App 源码
│   │   ├── App/                   # 入口 & 全局配置
│   │   ├── Features/              # 功能模块 (Inbox, Ledger, Report, Settings)
│   │   ├── Domain/                # 模型、枚举、业务服务
│   │   ├── Data/                  # 持久化、DTO、Mapper
│   │   ├── Shared/                # 通用组件、常量、扩展
│   │   └── Assets.xcassets/       # 图标 & 资源
│   ├── AutoLedgerCore/            # 本地 Swift Package (纯 Foundation，跨平台)
│   ├── AutoLedgerWatch Watch App/ # Apple Watch App 源码
│   ├── AutoLedgerWidgets/         # 主屏 Widget Extension
│   ├── ControlWidgetExtension/    # 控制中心 Widget Extension
│   ├── ShareExtension/            # Share Extension
│   ├── Pods/                      # CocoaPods 依赖 (gitignored)
│   └── ci_scripts/                # Xcode Cloud CI 脚本
├── versions/                      # 版本计划 & 回归基线
├── process/                       # 迭代工作流文档
├── scripts/                       # 回归测试脚本
├── tests/                         # Golden 回归样例
├── tools/app-icons/               # App Icon 生成与验证工具
├── tools/appstore-screenshots/    # App Store 截图导出管线（zh-Hans / zh-Hant / en / ja）
└── template/                      # 文档模板
```

## Build

```bash
# 环境要求：Xcode 26 beta + CocoaPods
sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer
brew install cocoapods

# 安装依赖
cd AutoLedger
pod install

# 构建 (需使用 workspace)
xcodebuild -workspace AutoLedger.xcworkspace \
  -scheme AutoLedger \
  -destination 'generic/platform=iOS' \
  build

# 回归测试
cd ..
bash scripts/run_offline_regression.sh
bash scripts/run_golden_regression.sh
```

本仓库包含 `Config.example.xcconfig`，仅作为公开协作时的占位示例。真实发布工程没有切换到该示例配置，因此 `main` 合并后仍可作为 AutoLedger 的真实开发和 Xcode Cloud 发布主分支。

如果你要在自己的 Apple Developer 账号下构建，请为 iOS App、Apple Watch App、Share Extension、Widget Extension 分别配置 Bundle ID，并配置自己的 App Groups 与 iCloud Containers。

## Privacy

- AutoLedger 以本地优先为设计目标，默认不需要账号。
- 账单解析尽可能在设备端完成；用户应在保存前确认识别结果。
- 调试导出、反馈包或截图可能包含个人消费数据，请不要在公开 Issue / PR 中上传真实小票、支付截图、账单截图或个人财务信息。
- App Store 版本可能包含签名、entitlement、StoreKit、Xcode Cloud 和商店元数据配置，这些配置不一定属于本仓库公开内容。

## Roadmap

| 内部版本 | App Store | 状态 | 主要内容 |
|---------|-----------|------|----------|
| v0.1.0 | — | ✅ 已发布 | MVP：截图导入、OCR、规则解析、分类、账本、月报 |
| v1.0.0 | — | ✅ 已发布 | 一键记账引导、LLM 智能解析、操作按钮集成、图标、TestFlight 外测就绪 |
| v1.1.0 | — | ✅ 已发布 | 订阅识别 & 扣费提醒、分类学习、自定义分类 / 来源、用户反馈闭环、去重增强、最近删除、手动记账、控制中心 Widget |
| v1.2.0 | **1.1.0** | ✅ 已发布 | Gemma-2 2B 端侧 LLM 集成（CDN + SHA-256）、模型生命周期管理、月报图表增强（Swift Charts）、异常消费检测、云闪付 / 银联适配、订阅管理增强、软删除持久化 |
| v1.3.0 | **1.2.0** | ✅ 已发布 | BackupBundle、JSON 导出/导入、覆盖恢复、iCloud 单文件自动备份、重装恢复提示 |
| v1.3.1 | **1.2.0** | ✅ 已发布 | 语音记账 MVP、首页按住语音入口、Siri/AppIntent 入口、App 内确认页、语音来源与调试记录、语音解析回归 |
| v1.3.2 | **1.2.0** | ✅ 已发布 | 统一 `LedgerTextInterpreter` 解析入口，收敛 OCR / 剪切板 / 分享 / 语音 / Siri 多路径 |
| v1.3.3 | **1.2.0** | ✅ 已发布 | 平台无关 `LedgerTextInterpreterCore` 提取为 AutoLedgerCore 模块，批量 OCR 测试框架 |
| v1.3.4 | **1.2.0** | ✅ 已发布 | 规则解析质量提升（合计行优先、商户黑名单、分类映射）、批量报告驱动修复 |
| v1.3.5 | **1.2.0** | ✅ 已发布 | Worker API 可行性评估、712 样本批量回归（金额命中率 100%）、商户别名迁移 |
| v1.4.0 | **1.3.0** | ✅ 已发布 | Apple Watch 端上线（语音记账、今日支出、最近账单）、辅助功能专项、App Intents 增强、中英繁本地化与截图管线、可选 Support Developer 内购 |
| v1.5.0 | **1.4.0** | ✅ 基线完成 | iPad 工作台、批量导入 / 批量识别、数据清洗、基础多端数据同步、Watch 今日支出与表盘小组件、iPad / Mac 截图管线、Mac Catalyst 主线能力 |
| v1.5.1 | **1.4.0** | ✅ 收尾完成 | 最低系统需求优化、识别链路 Core 化、外部辅助识别试点、编辑保存稳定性、iCloud 同步性能、当前平台截图与 App Preview v001；tvOS / visionOS 与多账本顺延 |
| v1.6.0 | **1.5.0** | 🚧 第一版推进中 | 订阅管理补强、AI 订阅判断、商户 / 分类 / 订阅倾向学习缓存、tvOS 只读看板、visionOS 展示版、Mac 与全平台体验继续打磨 |
| v1.6.1 | **1.5.0** | 🚧 内部开发中 | 酒店水单识别与酒店消费归档、多账本基础能力、新一轮多语言支持：macOS 手动 PDF 导入、酒店消费确认入账、默认账本迁移、账本切换、三语文案覆盖与日文支持；商店不区分内部小版本 |

## License

源码使用 MIT License，详见 [LICENSE](LICENSE)。

AutoLedger 名称、App 图标、App Store 截图、营销素材与品牌素材不包含在 MIT License 授权范围内，相关权利由作者保留。
