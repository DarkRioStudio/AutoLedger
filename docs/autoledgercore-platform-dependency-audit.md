# AutoLedgerCore 平台依赖审计

> 文档状态：Historical
> 真源范围：2026-06-11 平台依赖审计快照；不替代当前 Package.swift、工程配置或构建结果
> 文档分类核验：2026-07-17
> 上位路线图：[ROADMAP.md](ROADMAP.md)

更新日期：2026-06-11
所属版本：v1.5.1
关联 GOAL：GOAL-1601
状态：已完成第一轮审计

## 1. 结论

`AutoLedgerCore` 当前不需要先做大规模 `CoreBase` 拆包。

第一轮审计显示，Core 包内绝大多数文件只依赖 `Foundation` 或 `SQLite3`。真正把 `AutoLedgerCore` 抬到高版本平台依赖的是：

- `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Intents/ClipboardImportIntent.swift`

该文件直接 `import AppIntents`，并将 `ClipboardImportIntent` 定义在 `AutoLedgerCore` 产品内。由于 `AutoLedgerCore` 同时被主 App、Watch、Share Extension、tvOS / visionOS 等 target 引用，这个高层入口会反向污染基础 Core 的 deployment target 判断。

因此，`v1.5.1` 的建议顺序是：

1. 先将 `ClipboardImportIntent` 从 `AutoLedgerCore` 移出，迁到 App / Extension 层的 Intent Adapter。
2. 再将 `AutoLedgerCore/Package.swift` 从当前 `.iOS(.v18)`、`.watchOS(.v11)` 下调到目标线。
3. 之后再下调各 Xcode target 的 deployment target。
4. 只有在下调后发现新的平台 API 编译阻塞时，才考虑拆出更细的 `CoreBase`。

## 2. 当前 Core 包平台声明

当前 `AutoLedger/AutoLedgerCore/Package.swift`：

```swift
platforms: [
    .iOS(.v18),
    .macOS(.v14),
    .watchOS(.v11),
]
```

目标方向：

```swift
platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .watchOS(.v10),
]
```

tvOS / visionOS 当前通过 Xcode target 引入本地 package，后续应在新平台落产品代码时按各平台最低版本单独验证。

## 3. 已确认依赖分布

### 3.1 AutoLedgerCore 内部

已确认 Core 内主要依赖：

- `Foundation`
- `SQLite3`

唯一高层框架命中：

- `AppIntents`

命中文件：

- `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Intents/ClipboardImportIntent.swift`

### 3.2 App 层高版本能力

以下能力不应进入 CoreBase，也不应约束主 App 最低系统：

- `FoundationModels`
- `AppIntents`
- `WidgetKit`
- `ControlWidget`
- `CloudKit`
- `Vision`
- `UIKit` / `SwiftUI`
- `WatchConnectivity`

这些能力可以留在 App、Extension、Widget、ControlWidget 或专门 Adapter 层。

## 4. `ClipboardImportIntent` 迁移建议

当前职责：

- 暴露 `ClipboardImportIntent`
- `openAppWhenRun = true`
- 通过静态 `handler` 通知主 App 执行剪贴板导入
- 被 `ControlWidgetExtension/ClipboardImportControl.swift` 使用

建议迁移方式：

- 在 App / Intent Adapter 层新建同名或等价 Intent 类型。
- 保持 Shortcuts / Control Widget 入口的行为不变。
- Core 只保留剪贴板导入所需的解析、数据模型和服务，不持有 `AppIntent` 类型。
- 如果 ControlWidget 需要引用该 Intent，则让 ControlWidget target 依赖 Adapter 所在模块或在 extension 内保留轻量入口。

实施时需要特别保护：

- 不改 Bundle ID。
- 不改 App Group。
- 不改 ControlWidget target 的最低版本策略。
- 不改用户可见入口文案。
- 不改现有剪贴板导入行为。

## 5. Deployment Target 审计结论

当前工程仍处于高版本事实状态：

| 范围 | 当前事实 |
|---|---:|
| Main App / iPhone / iPad | iOS 26.x |
| Mac Catalyst | 跟随 iOS 26.x |
| Watch App / Watch Widget | watchOS 26.x |
| tvOS | tvOS 26.x |
| visionOS | visionOS 26.x |
| AutoLedgerCore package | iOS 18 / macOS 14 / watchOS 11 |

目标仍维持 `v1.5.1` 计划：

| 范围 | 目标 |
|---|---:|
| Main App / iPhone / iPad | iOS 17.0 |
| Mac Catalyst | macOS 14 line |
| Watch App / Watch Widget | watchOS 10.0 |
| tvOS | tvOS 17.0 |
| visionOS | visionOS 1.0 |
| ControlWidgetExtension | iOS 18.0 |
| Foundation Models / Apple Intelligence | iOS 26+ optional enhancement |

## 6. 下一步

建议进入 `GOAL-1602` 时按以下顺序实施：

1. 迁移 `ClipboardImportIntent` 出 `AutoLedgerCore`。
2. 下调 `AutoLedgerCore/Package.swift` 平台声明。
3. 下调主 App / Watch / tvOS / visionOS target deployment target。
4. 保留 `ControlWidgetExtension` 的 `iOS 18`。
5. 保留 `FoundationModels` / Apple Intelligence 的 `iOS 26+` feature gate。
6. 执行 iOS generic build、Mac Catalyst build、Watch build 和离线回归。

如果迁移 `ClipboardImportIntent` 后 `AutoLedgerCore` 仍出现平台 API 编译阻塞，再重新评估是否需要拆出独立 `CoreBase` package。
