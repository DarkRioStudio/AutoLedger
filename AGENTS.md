# AutoLedger — Agent Instructions

AutoLedger 是一款以本地优先个人账本、自动化导入和酒店水单归档为核心的多平台应用。工程使用 Swift 6 编译器与严格并发检查能力，主 App 和扩展当前仍处于 Swift 5 语言模式的渐进迁移阶段。

OCR 与本地模型推理默认在设备端完成；用户主动使用专属云收件箱、Common API、天气或服务端权益校验时会访问对应云端服务。不要在代码或文档中使用“零上传”之类的绝对隐私表述。

## Quick Links

- 产品特性 & 架构概览 → [README.md](README.md)
- 当前项目状态与发布门禁 → [PROJECT_STATUS.md](PROJECT_STATUS.md)
- 产品核心路线图真源 → [docs/ROADMAP.md](docs/ROADMAP.md)
- 文档索引与生命周期 → [docs/README.md](docs/README.md)
- 迭代工作流（必读） → [process/agent-iteration-workflow.md](process/agent-iteration-workflow.md)
- 版本计划 → `versions/v*.md`，最新版本 → [versions/v1.7.0-plan.md](versions/v1.7.0-plan.md)
- CHANGELOG → [CHANGELOG.md](CHANGELOG.md)

---

## Build & Test

> 环境：Xcode 26 beta，CocoaPods

```bash
# 切换到 Xcode 26 beta（如未切换）
sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer

# 安装 CocoaPods 依赖（首次或 Podfile 变动后）
cd AutoLedger && pod install

# 构建（必须用 .xcworkspace，不是 .xcodeproj）
xcodebuild -workspace AutoLedger.xcworkspace \
  -scheme AutoLedger \
  -destination 'generic/platform=iOS' \
  build

# 离线回归（macOS 本地 swiftc，从仓库根目录运行）
bash scripts/run_offline_regression.sh

# Golden case 回归
bash scripts/run_golden_regression.sh

# 全量小票批量回归
bash scripts/run_receipt_batch_regression.sh
```

**⚠ 门禁**：构建/测试失败禁止进入下一轮迭代（见 [agent-iteration-workflow.md](process/agent-iteration-workflow.md)）。

---

## Architecture

```
AutoLedgerRio/
├── AutoLedger/
│   ├── AutoLedgerCore/          # 本地 SPM 包 — 纯 Foundation/Swift，跨平台
│   │   └── Sources/AutoLedgerCore/
│   │       ├── Models/          # Transaction, Subscription, ImportedReceipt …
│   │       ├── Services/        # ReceiptParser, LedgerTextInterpreterCore,
│   │       │                    # OCRService, VoiceLedgerParser, SubscriptionDetector
│   │       └── Persistence/     # SQLiteTransactionStore (sqlite3 C API，无 ORM)
│   └── AutoLedger/              # iOS App target (SwiftUI, AppIntents, MediaPipe)
│       ├── App/                 # @main, LedgerStore (ObservableObject, root state)
│       ├── Domain/Services/     # GemmaService, SmartReceiptParser, LedgerTextInterpreter
│       ├── Features/            # Inbox, Ledger, Report, Settings, Subscription, Feedback
│       ├── Data/                # DTO, Mapper，桥接 Core 与 App
│       └── Shared/              # Components, Constants (AppTheme), Extensions, Utils
├── scripts/                     # 回归脚本
├── versions/                    # 版本计划 & 回归基线
└── process/                     # 迭代工作流文档
```

**分层规则**：
- `AutoLedgerCore` 不能 import `UIKit` / `SwiftUI` / `WatchConnectivity`；保持纯 Foundation，以支持 Watch & macOS。
- LLM / MediaPipe 层只属于主 App target，不进 Core。
- UI 逻辑只属于 `Features/`，业务逻辑只属于 `Domain/Services/`。

---

## Key Patterns

### Actor 隔离（全局 MainActor）

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 已在 Xcode 工程全局设置——**所有未标注类型默认为 `@MainActor` 隔离**。

- 后台任务需显式 `nonisolated` 或 `Task.detached`
- AppIntents 的全局 logger 用 `nonisolated(unsafe) private let`
- `GemmaService` 显式 `@MainActor @Observable`，通过 `GemmaService.shared` 访问

### SwiftUI 状态管理

- `LedgerStore`（`ObservableObject`）为根状态，在 App 入口以 `.environmentObject(store)` 注入，子视图用 `@EnvironmentObject private var store: LedgerStore`
- `GemmaService` 用 `@Observable`（新宏），子视图直接访问 `GemmaService.shared`，无需 `@EnvironmentObject`

### 依赖注入

纯构造函数注入，无第三方 DI 框架。`LedgerStore.init` 接受 `ReceiptParser`、`TransactionStore`（含默认值），测试时传 mock。

### 解析流水线

```
截图 → OCRService (Vision) → ReceiptParser (规则) → SmartReceiptParser
  ├─ 多笔账单 → 规则引擎直接返回
  └─ 单笔账单 → LLM (Apple Foundation Models / Gemma-2 2B)
       ├─ confidence ≥ 0.7 → 直接采用
       └─ confidence < 0.7 → 规则交叉验证
```

`LLMProvider` 枚举（`.appleFoundation` / `.gemma`）从 UserDefaults 读取用户偏好。

---

## Critical Pitfalls

| 陷阱 | 正确做法 |
|------|---------|
| 打开 `.xcodeproj` | 必须用 `.xcworkspace`（含 CocoaPods） |
| 在 Xcode 监视的包目录运行 `swift build` | `.build/` 会被索引进 `project.pbxproj`，产生数千条 stale references。**不要在 `AutoLedger/AutoLedgerCore/` 下运行 `swift build`** |
| `Transaction` 命名冲突 | 主 App 文件 import AutoLedgerCore 后遇到 `StoreKit.Transaction` 冲突；已通过 [Shared/Extensions/Transaction+Typealias.swift](AutoLedger/AutoLedger/Shared/Extensions/Transaction+Typealias.swift) 消歧，新文件直接使用 `Transaction` 即可 |
| `Subscription` 命名冲突 | 遇到 `Combine.Subscription` 冲突时参考 `LedgerStore.swift` 顶层 typealias |
| WeChat OCR 括号换行 | `ReceiptParser` 中必须先 merge 括号行，再做 label→value 映射，否则 index 偏移 |
| Gemma 冷启动 | 模型已下载但未加载时不能直接调 `generate()`；`QuickLedgerIntent` 有 4 秒等待 + 降级策略可参考 |
| 多笔账单截图 | 必须先走 `ReceiptParser.detectMultipleReceipts()` 路径 |

---

## Iteration Workflow

每轮改动遵循 [process/agent-iteration-workflow.md](process/agent-iteration-workflow.md) 中的 5 步流程：

1. 锁定目标（本轮只做什么）
2. 执行前检查（文件清单、风险、验收点）
3. 实施改动（仅本轮范围）
4. 回归验证（最小回归包）
5. 回填 [process/iteration-log.md](process/iteration-log.md) & [CHANGELOG.md](CHANGELOG.md)
