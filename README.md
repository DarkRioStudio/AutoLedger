<p align="center">
  <img src="icon.png" width="128" height="128" alt="AutoLedger Icon" />
</p>

<h1 align="center">AutoLedger</h1>

<p align="center">
  <strong>截图即记账 — iPhone 自动化消费记录工具</strong><br/>
  拍一张支付截图，自动识别金额和商户，一秒入账。
</p>

<p align="center">
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
| 🤖 | **智能解析** | 规则引擎 + LLM 双模式，覆盖微信、支付宝、App Store 等 |
| 📊 | **月度报告** | 分类统计、消费趋势、商户排名一目了然 |
| 📤 | **Share Extension** | 在任意 App 中分享截图直接导入 |
| 🔒 | **完全离线** | 所有识别和分析在本地完成，零数据上传 |

## Quick Start

**App 内导入** — 打开 AutoLedger → 选择截图 → 自动入账

**一键记账（推荐）** — [安装快捷指令](https://www.icloud.com/shortcuts/e64528fb5bc34afdab4d7c64242d537e) → 绑定操作按钮 → 按一下记账

**分享扩展** — 在微信/支付宝中分享截图 → 选择 AutoLedger

## Tech Stack

| 层级 | 技术 |
|------|------|
| UI | SwiftUI, iOS 26 |
| OCR | Apple Vision (`VNRecognizeTextRequest`) |
| 解析 | 规则引擎 + LLM (SmartReceiptParser) |
| 存储 | SQLite (本地) |
| 架构 | MVVM + 依赖注入 |
| 快捷指令 | AppIntents / `ForegroundContinuableIntent` |
| 分享 | Share Extension |

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
│   ├── ShareExtension/          # Share Extension
│   └── ControlWidgetExtension/  # 控制中心 Widget Extension
├── versions/                    # 版本计划 & 回归基线
├── process/                     # 迭代工作流文档
├── scripts/                     # 回归测试脚本
└── template/                    # 文档模板
```

## Build

```bash
# 环境要求：Xcode 26 beta
sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer

# 构建 (真机)
cd AutoLedger
xcodebuild -project AutoLedger.xcodeproj \
  -scheme AutoLedger \
  -destination 'generic/platform=iOS' \
  build

# 回归测试
bash scripts/run_offline_regression.sh
```

## Roadmap

| 版本 | 状态 | 主要内容 |
|------|------|----------|
| v0.1.0 | ✅ 已发布 | MVP：截图导入、OCR、规则解析、分类、账本、月报 |
| v1.0.0 | ✅ 已发布 | 一键记账引导、LLM 智能解析、操作按钮集成、图标、TestFlight 外测就绪 |
| v1.1.0 | 📋 计划中 | 订阅识别、扣费预测与提醒、去重、分类学习 |
| v1.2.0 | 📋 计划中 | 异常消费检测、个性化建议、更多平台适配 |

## License

MIT License. See [LICENSE](LICENSE) for details.
