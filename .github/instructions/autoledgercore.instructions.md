---
description: "Use when creating or modifying files inside AutoLedger/AutoLedgerCore/. Enforces cross-platform purity, Sendable conformance, and no LLM/UI dependencies."
applyTo: "AutoLedger/AutoLedgerCore/**/*.swift"
---

# AutoLedgerCore Conventions

`AutoLedgerCore` 是纯 Foundation/Swift 本地 SPM 包，支持 iOS 18+ / macOS 14+ / watchOS 11+。

## Hard Rules

- **禁止 import**：`UIKit`、`SwiftUI`、`WatchConnectivity`、`MediaPipeTasksGenAI`、`FoundationModels`
- **允许 import**：`Foundation`、`SQLite3`（通过 `sqlite3_*` C API）、`Vision`（仅 `OCRService`）、`NaturalLanguage`
- 所有公开类型必须声明 `Sendable`；需跨线程共享的 class 用 `@unchecked Sendable` 并在注释中说明同步策略
- 不能依赖 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`；Core 内类型需自己明确 actor 标注或保持 `Sendable` + 无状态

## Module Boundaries

| 属于 Core | 不属于 Core |
|-----------|-------------|
| `Transaction`, `Subscription`, `ImportedReceipt` 等核心模型 | LLM 调用（`GemmaService`, `SmartReceiptParser`） |
| `ReceiptParser`（规则引擎）, `LedgerTextInterpreterCore` | SwiftUI 视图, `ObservableObject`, `@Observable` |
| `SQLiteTransactionStore`（sqlite3 C API） | `AppIntents`, `WidgetKit`, `UserNotifications` |
| `OCRService`（Vision 封装）, `VoiceLedgerParser` | `LedgerStore`（App 层状态） |

## Naming Conflicts

- 本包导出 `Transaction`，主 App target 通过 [Transaction+Typealias.swift](../../AutoLedger/Shared/Extensions/Transaction+Typealias.swift) 消歧。**Core 内无需 typealias**，直接使用 `Transaction`。
- 本包导出 `Subscription`，主 App target 的 `LedgerStore.swift` 顶层已有 typealias。**Core 内同理**，直接使用 `Subscription`。

## SQLite Conventions

- 使用 `sqlite3_*` C API，不引入任何 ORM
- `category` 和 `source` 存储为 String rawValue，枚举映射必须提供兜底（`.other` / `.manual`）
- 数据库文件路径通过 `init(baseDirectoryURL:filename:)` 注入，不硬编码

## Testing

Core 内的改动必须通过离线回归：

```bash
bash scripts/run_offline_regression.sh
```

ReceiptParser / LedgerTextInterpreterCore 的 Bug 修复需在 `tests/golden/` 补充对应 golden case。
