<p align="center">
  <a href="https://app.darkrio326.top/autoledger/">
    <img src="icon.png" width="128" height="128" alt="AutoLedger Icon" />
  </a>
</p>

<h1 align="center">AutoLedger</h1>

<p align="center">
  <strong>截图即记账 — iPhone 自动化消费记录工具</strong><br/>
  拍一张支付截图，自动识别金额和商户，一秒入账。
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
| 🔒 | **完全离线** | 所有识别和分析在本地完成，唯一网络请求为 Gemma 模型版本检查与下载（CDN），零用户数据上传 |

## Quick Start

**App 内导入** — 打开 AutoLedger → 选择截图 → 自动入账

**一键记账（推荐）** — [安装快捷指令](https://www.icloud.com/shortcuts/e64528fb5bc34afdab4d7c64242d537e) → 绑定操作按钮 → 按一下记账

**语音记账** — 在首页按住麦克风说「午饭 28 元」可快速识别，高置信结果自动保存；账本页仍可点击波形按钮输入一句话，账本字段会实时生成并可确认保存，也可通过 Siri/快捷指令触发语音记账

**分享扩展** — 在微信/支付宝中分享截图 → 选择 AutoLedger

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
| CI | Xcode Cloud |

## Project Structure

```
AutoLedgerRio/
├── AutoLedger/                  # Xcode 工程
│   ├── AutoLedger/              # 主 App 源码
│   │   ├── App/                 # 入口 & 全局配置
│   │   ├── Features/            # 功能模块 (Inbox, Ledger, Report, Settings)
│   │   ├── Domain/              # 模型、枚举、业务服务
│   │   ├── Data/                # 持久化、DTO、Mapper
│   │   ├── Shared/              # 通用组件、常量、扩展
│   │   └── Assets.xcassets/     # 图标 & 资源
│   ├── AutoLedgerCore/          # 本地 Swift Package (共享模型)
│   ├── Pods/                    # CocoaPods 依赖 (MediaPipe, gitignored)
│   ├── ci_scripts/              # Xcode Cloud CI 脚本
│   ├── ShareExtension/          # Share Extension
│   └── ControlWidgetExtension/  # 控制中心 Widget Extension
├── versions/                    # 版本计划 & 回归基线
├── process/                     # 迭代工作流文档
├── scripts/                     # 回归测试脚本
└── template/                    # 文档模板
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
```

## Roadmap

| 版本 | 状态 | 主要内容 |
|------|------|----------|
| v0.1.0 | ✅ 已发布 | MVP：截图导入、OCR、规则解析、分类、账本、月报 |
| v1.0.0 | ✅ 已发布 | 一键记账引导、LLM 智能解析、操作按钮集成、图标、TestFlight 外测就绪 |
| v1.1.0 | ✅ 外测基线完成 | 订阅识别 & 扣费提醒、分类学习、自定义分类 / 来源、用户反馈闭环、去重增强、最近删除、手动记账、控制中心 Widget |
| v1.2.0 | ✅ 代码完成 | Gemma-2 2B 端侧 LLM 集成（CDN + SHA-256）、模型生命周期管理、月报图表增强（Swift Charts）、异常消费检测、云闪付 / 银联适配、订阅管理增强、软删除持久化 |
| v1.3.0 | ✅ 代码完成 | BackupBundle、JSON 导出/导入、覆盖恢复、iCloud 单文件自动备份、重装恢复提示 |
| v1.3.1 | ✅ 代码完成 | 语音记账 MVP、首页按住语音入口、Siri/AppIntent 入口、App 内确认页、语音来源与调试记录、语音解析回归 |

## License

MIT License. See [LICENSE](LICENSE) for details.
