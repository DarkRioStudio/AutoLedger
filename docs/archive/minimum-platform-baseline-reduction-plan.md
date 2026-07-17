# 全平台最低系统需求下调规划

> 文档状态：Historical
> 真源范围：GOAL-1601 / GOAL-1602 平台基线下调规划与当时结果；当前平台要求以工程配置和根 README 为准
> 文档分类核验：2026-07-17
> 上位路线图：[ROADMAP.md](../ROADMAP.md)

更新日期：2026-06-11
状态：第一阶段已实施（GOAL-1601 / GOAL-1602 已完成）
承接版本：`v1.5.1` 候选
关联审计：`docs/archive/autoledgercore-platform-dependency-audit.md`

## 1. 目标

在不牺牲 AutoLedger 当前核心产品能力的前提下，逐步降低主发布平台的最低系统需求，让更多设备可以安装和使用正式版本。

本规划定义方向、分层和施工顺序。当前已经完成第一阶段代码 / 工程落地：

- 已迁出 `ClipboardImportIntent`，解除 `AutoLedgerCore` 对 `AppIntents` 的直接依赖。
- 已下调 `AutoLedgerCore` package platform。
- 已下调主 App / Watch / tvOS / visionOS deployment target。
- 已保留 `ControlWidgetExtension` 的 `iOS 18`。
- 尚未修改 App Store Connect 最低系统展示，需等最终发布前人工确认。

## 2. 当前真实基线（2026-06-11）

按当前工程 `project.pbxproj` 与 package 的 live 状态：

| 平台 / Target 类型 | 当前最低版本 |
|---|---:|
| iPhone / iPad 主 App | `iOS 17.0` |
| Share Extension / iOS Widget | `iOS 17.0` |
| Mac Catalyst（跟随 iOS 线） | `iOS 17.0` |
| Apple Watch App / Watch Widget | `watchOS 10.0` |
| tvOS target | `tvOS 17.0` |
| visionOS target | `visionOS 1.0` |
| ControlWidgetExtension | `iOS 18.0` |
| `AutoLedgerCore` package | `iOS 17 / macOS 14 / watchOS 10` |
| `RealityKitContent` package | `iOS 17 / macOS 14 / tvOS 17 / visionOS 1` |

说明：

- 当前 README 和部分对外文档仍可能保留旧的 `iOS 26` 事实文案；这些需要在最终发布前统一更新。
- App Store Connect 平台展示和最低系统要求尚未人工修改。

## 3. 建议目标矩阵

### 3.1 推荐目标

| 平台 / 能力 | 建议最低版本 | 说明 |
|---|---:|---|
| iPhone / iPad 主 App | `iOS 17` | 保留现代 SwiftUI / Observation 结构，尽量不重写主架构 |
| Mac Catalyst | `macOS 14` 对应线 | 与 iOS 17 主线对齐，减少分叉维护 |
| Apple Watch | `watchOS 10` | 与当前 Watch UI / Widget 能力更匹配 |
| tvOS | `tvOS 17` | 目前尚未落产品代码，最适合从较低基线起步 |
| visionOS | `visionOS 1` | 当前仍是 target / 规划阶段，直接用平台首版基线更合理 |
| ControlWidgetExtension | `iOS 18` 单独保留 | 不让高版本控制组件绑住整个主 App 基线 |
| Apple Foundation Models 增强 | `iOS 26+` 可选能力 | 保留为 feature gate，不再作为主 App 最低系统门槛 |

### 3.2 不建议目标

| 目标 | 不建议原因 |
|---|---|
| 全部平台统一降到同一个数字 | `ControlWidget`、Apple Foundation Models 这类高版本能力不适合硬绑主线 |
| 直接把 iPhone / iPad 主 App 降到 `iOS 16` | 会明显放大 `Observation`、Widget、SwiftUI 兼容改造成本 |
| 继续维持“Apple Intelligence = 最低系统要求” | 会把增强功能错当成基础门槛，拖住安装覆盖面 |

## 4. 当前代码面的真实阻力

### 4.1 已确认的高版本钉子

1. `FoundationModels`
   - `AutoLedger/AutoLedger/Domain/Services/SmartReceiptParser.swift`
   - `AutoLedger/AutoLedger/Domain/Enums/LLMProvider.swift`
   - 当前已经显式写了 `@available(iOS 26.0, *)`
   - 这部分天然适合作为 `iOS 26+` 增强功能保留

2. `ControlWidgetExtension`
   - `AutoLedger/ControlWidgetExtension/ClipboardImportControl.swift`
   - 这类能力天然不应反向约束整个主 App 的最低版本

3. `AutoLedgerCore` 当前 target 内仍混有 `AppIntents`
   - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Intents/ClipboardImportIntent.swift`
   - 从当前源码看，Core 内绝大部分文件仍是 Foundation / SQLite-only
   - 因此更合理的方向不是“整个 Core 必须维持 iOS 18+”，而是优先将 `ClipboardImportIntent` 迁出为 Intent Adapter；只有迁出后仍遇到平台 API 阻塞时，再拆独立 `CoreBase`

4. 当前文档口径
   - `README.md`
   - `AutoLedger/README.md`
   - 部分本地化文案中也有 `iOS 26+`
   - 这些需要等真正落地后再统一调整

### 4.3 GOAL-1601 审计结论（2026-06-11）

第一轮审计确认：

- `AutoLedgerCore` 当前唯一高层平台框架命中是 `AppIntents`。
- 命中文件是 `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Intents/ClipboardImportIntent.swift`。
- Core 内其他主要源码仍是 `Foundation` / `SQLite3` 级别。
- 当前不需要先做大规模 `CoreBase` 拆包。
- 更稳妥的实施路径是先把 `ClipboardImportIntent` 迁出 `AutoLedgerCore`，作为 App / Extension 层的 Intent Adapter，再下调 `AutoLedgerCore/Package.swift`。

因此，Phase B 的第一步从“判断是否必须拆 `CoreBase`”调整为：

1. 迁出 `ClipboardImportIntent`。
2. 下调 `AutoLedgerCore` package platform。
3. 若仍出现平台 API 编译阻塞，再评估是否拆出独立 `CoreBase`。

### 4.4 GOAL-1602 实施结果（2026-06-11）

已完成：

- `ClipboardImportIntent` 从 `AutoLedgerCore` 迁出。
- 主 App 与 Control Widget 各保留一份薄 App Intent 入口。
- Control Widget 通过 App Group handoff 标记触发剪贴板导入，主 App 激活后消费该标记并调用正式 `LedgerStore.attemptClipboardImport(force:)`。
- `AutoLedgerCore/Package.swift` 下调到 `iOS 17 / macOS 14 / watchOS 10`。
- 主 App、Share Extension、iOS Widget 下调到 `iOS 17.0`。
- Watch App / Watch Widget 下调到 `watchOS 10.0`。
- tvOS target 下调到 `tvOS 17.0`。
- visionOS target 下调到 `visionOS 1.0`。
- `ControlWidgetExtension` 保留 `iOS 18.0`。
- `RealityKitContent` package 下调到目标矩阵。
- `Podfile` 下调到 `iOS 17.0`，并重新执行 `pod install`。

为 iOS 17 兼容补充的 feature gate：

- `LedgerTextInterpreter` 与 `QuickLedgerIntent` 在低于 `iOS 26` 时不调用 `SmartReceiptParser.parse`，回落到规则解析。
- `QuickLedgerIntent` 移除 `@Parameter(... supportedContentTypes:)`，避免使用 `iOS 18` 才可用的参数初始化器。

验证结果：

- PASS：`git diff --check`
- PASS：`bash scripts/run_offline_regression.sh`
- PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`
- PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV -configuration Debug -destination 'generic/platform=tvOS' build`
- PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'generic/platform=visionOS' build`
- PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' build`
- PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme ControlWidgetExtension -configuration Debug -destination 'generic/platform=iOS' build`

已知保留警告：

- Mac Catalyst build 仍提示 MediaPipe xcframework 没有 Catalyst slice；这是既有状态，当前通过 Catalyst fallback 保持构建通过。
- 若未来需要彻底消除该 warning，需要进一步调整 Pod target 的 Catalyst build 脚本或依赖接入方式。

### 4.2 当前看起来不是主要 blocker 的点

以下能力虽然现代，但从 API 形态上看，并没有直接把主线锁死在 `26.0`：

- `@Observable` / Observation
- `NavigationSplitView`
- `Table`
- `PhotosPicker`
- WidgetKit 当前已用到的常规 widget API

它们更像是支持“降到 17”而不是“降到 16”的现实依据。

## 5. 产品分层原则

最低系统下调不能按“整包一刀切”处理，而应按产品层级拆开：

### 5.1 核心能力层（应尽量随最低系统下降）

- 本地记账
- OCR 解析
- 候选复核
- 账本 / 月报
- iCloud 同步
- iPad 工作台
- Mac Catalyst 工作流
- Watch 今日支出与最近支出
- JSON / CSV / backup

### 5.2 高版本增强层（允许保留更高门槛）

- Apple Foundation Models / Apple Intelligence
- Control Widget
- 后续如果接入更高版本 widget/control/siri 展示 API，也归入这一层

原则：

- 核心能力层决定主 App 的最低系统
- 增强层通过 `#available` 或独立 target 最低版本隔离
- 不允许增强层反过来锁死整个主发布平台

## 6. 分阶段实施建议

### Phase A：规划与口径收口

目标：先把“当前事实”和“未来目标”分开。

输出：

- 最低系统目标矩阵
- 哪些能力属于核心层、哪些属于增强层
- 哪些 target 可以独立保留高版本
- 哪些 README / App Store 文案要在真正落地后再更新

本轮即完成这一阶段。

### Phase B：主 App 降基线

目标：把 `iPhone / iPad / Mac Catalyst` 主线从 `26.0` 迁到 `17`

任务：

1. 审核 `AutoLedgerCore` 的真实平台依赖，判断是直接下调还是先拆 `CoreBase`
2. 必要时将 `ClipboardImportIntent` 等高层入口从基础 Core 中移出
3. 下调主 App 与共享 target 的 deployment target
4. 保留 `FoundationModels` 路径为 `iOS 26+` feature gate
5. 确认非 Apple FM 模式下，OCR / 规则解析 / Gemma 路径可正常工作
6. 修补编译期 availability 报错

验收：

- iOS generic build 通过
- Mac Catalyst build 通过
- 不启用 Apple FM 时主流程可运行

### Phase C：Watch / Widget / ControlWidget 分层

目标：让 Watch 主线与 ControlWidget 分开演进

任务：

1. 将 Watch 主线评估下调到 `watchOS 10`
2. 复查 Watch Widget 是否有更高版本 API 依赖
3. `ControlWidgetExtension` 单独保留 `iOS 18`
4. 不要求 ControlWidget 与主 App 共享同一最低版本

验收：

- Watch App / Watch Widget build 通过
- ControlWidget 独立 build 通过
- 主 App 不因 ControlWidget target 的高版本要求而回退

### Phase D：tvOS / visionOS 从低基线重新起步

目标：既然两者尚未真正落代码，就直接用更合理的首版基线

任务：

1. tvOS target 按 `tvOS 17` 规划
2. visionOS target 按 `visionOS 1` 规划
3. 首版实现只做只读展示，不引入高版本附加能力

验收：

- destinations / generic build smoke 正常
- 新平台设计与最小版本口径一致

### Phase E：文档与发布口径收口

目标：在代码真正落地后，再统一对外说明

更新范围：

- `README.md`
- `AutoLedger/README.md`
- App Store Connect 支持平台 / 最低版本展示
- 与 Apple FM 相关的设置页、副标题、本地化文案

## 7. 主要风险

| 风险 | 说明 | 处理方式 |
|---|---|---|
| 降版本后出现大量 availability 报错 | 当前虽然高版本钉子不多，但 target 一旦整体下调，隐性 API 依赖会暴露 | 按 Phase B / C 分批下调，不一次全改 |
| 文档口径先改早了 | 当前 README 的 `iOS 26` 仍是工程事实 | 先改规划文档，不提前改对外文案 |
| ControlWidget 拖住主 App | 高版本控制能力不该约束整体安装基线 | 独立 target 保留 `iOS 18` |
| Apple FM 被误认为基础功能 | 会导致“能装但关键功能不可用”的认知混乱 | 明确标为 `iOS 26+` 增强能力 |
| 盲目追求 `iOS 16` | 会放大兼容层成本并拖慢主线 | 先以 `iOS 17` 为现实目标 |

## 8. 非目标

本规划不包含：

- 本轮直接修改 deployment target
- 本轮直接修 availability 报错
- 本轮直接改 README / ASC 对外最低版本口径
- 本轮把 tvOS / visionOS 做成可发布产品代码

## 9. 建议结论

若按当前代码结构、平台阶段和维护成本综合判断，最稳妥的方案是：

- `iPhone / iPad / Mac Catalyst -> iOS 17 / macOS 14 line`
- `Apple Watch -> watchOS 10`
- `tvOS -> tvOS 17`
- `visionOS -> visionOS 1`
- `ControlWidgetExtension -> iOS 18`
- `Apple Foundation Models -> iOS 26+ optional enhancement`

如果 `AutoLedgerCore` 的现有 target 因 `AppIntents` 入口而无法直接随主线降到 `iOS 17`，则优先采用：

- `CoreBase`：Foundation / SQLite / 通用模型 / 通用服务，随主线降版本
- `Intent Adapter`：`ClipboardImportIntent` 一类高层入口独立出去
- `FeatureGate`：`FoundationModels` / Apple Intelligence 保持 `iOS 26+`

这是当前最像“真实能落地”的全平台最低系统需求下调方案。
