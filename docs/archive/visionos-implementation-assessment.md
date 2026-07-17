# AutoLedger visionOS Implementation Assessment

> Document status: Historical
> Source-of-truth scope: initial visionOS implementation assessment; current behavior lives in the target code and build evidence
> Classification verified: 2026-07-17
> Parent roadmap: [ROADMAP.md](../ROADMAP.md)

## Goal

`GOAL-1583` 只回答实现问题：

- `AutoLedgerVision` target 现在到底能不能 build
- 首版 scene 应该从 `WindowGroup`、`Volume` 还是 immersive space 起步
- 数据入口该复用什么
- 最小 smoke 验证怎样定义才算靠谱

## Current Target Facts

基于当前工程和 build 结果，visionOS 已经从“模板 target”进入“可继续实现”的状态。

- target：`AutoLedgerVision`
- bundle id：`top.darkrio326.AutoLedger.vision`
- deployment target：`1.0`
- supported platforms：`xros xrsimulator`
- targeted device family：`7`
- 当前入口：`WindowGroup { ContentView() }`
- 当前内容：SwiftUI 单窗口只读空间看板

额外事实：

- 当前 target 没有单独的 `CODE_SIGN_ENTITLEMENTS` 配置。
- `RealityKitContent` package 仍保留在 target 依赖中，但首版产品 UI 不再使用模板 `Model3D`。
- 当前已经接入 `AutoLedgerCore`，可读取本机正式账本并派生月度、年度、分类和最近账单展示。

## Build Smoke Results

本轮已确认：

- `xcodebuild -showdestinations -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision`
  - 可列出 `Any visionOS Device`
  - 可列出 `Any visionOS Simulator Device`
- `xcrun simctl list devices available | rg "Vision|visionOS|Apple Vision"`
  - 可见 `Apple Vision Pro` simulator
- `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'generic/platform=visionOS' build`
  - 通过
- `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'platform=visionOS Simulator,name=Apple Vision Pro' build`
  - 通过

结论：`AutoLedgerVision` 已经不是 blocker target，后续工作重点转为 scene 选择和数据接入，而不是平台组件安装。

## GOAL-1750 Implementation Result

2026-06-19 已完成 visionOS 展示版第一版。

实现内容：

- 保持 `WindowGroup` 单窗口入口。
- 移除模板 `Model3D + Hello, world!` 首屏。
- 为 `AutoLedgerVision` target 增加 `AutoLedgerCore` package product 依赖。
- 新增 SwiftUI 四区只读展示：月度支出空间看板、分类支出卡片、年度消费时间线墙、最近账单悬浮列表。
- 复用 `SQLiteTransactionStore`、`MonthlySnapshot`、`TodaySpendingSummary`，不新增 visionOS 独立统计口径。
- 支持隐私模式、刷新入口、loading / empty / unavailable 状态。

验证结果：

- `generic/platform=visionOS` build 通过。
- `platform=visionOS Simulator,name=Apple Vision Pro` build 通过。
- 已在 Apple Vision Pro simulator 安装并 launch `top.darkrio326.AutoLedger.vision`。
- 已通过 `simctl io screenshot` 确认主窗口可打开；当前模拟器无账本数据时展示 empty 状态，界面不空白、不重叠，模板 3D 内容不再遮挡 UI。

保留限制：

- 当前没有接 CloudKit 只读拉取或 dashboard snapshot。
- 当前模拟器 smoke 覆盖的是空账本状态；有真实账本数据后的四区展示仍需后续环境复测。
- 当前没有 visionOS App Store 素材、截图管线或真机 smoke。

## Scene Strategy Assessment

### Option A: WindowGroup First

优点：

- 与当前 target 入口一致，改造成本最低。
- 适合承载首版“月度总览 + 分类卡 + 最近账单 + 趋势区”的只读信息面板。
- 更容易复用 SwiftUI 现有组件和统计卡片，不必过早进入 RealityKit 布局。
- 对截图管线更友好，后续全平台截图更容易统一。

缺点：

- 空间层次感不如 volume / immersive 强。
- 分类卡和时间线墙的“漂浮感”需要谨慎用布局和深度暗示来补。

判断：**首版推荐路径。**

### Option B: Volume First

优点：

- 更自然地表达“空间中的立体对象”。
- 更适合做分类卡或时间线的前后层次。

缺点：

- 首版会更早遇到尺寸、锚定、空间舒适度和交互范围问题。
- 如果内容本质仍是几块读数面板，volume 的收益未必大于复杂度。

判断：可作为 `GOAL-1584+` 之后的增强项，不建议作为 v1 首版必需前提。

### Option C: Immersive Space First

优点：

- 视觉上最“像 visionOS 产品”。

缺点：

- 范围膨胀最快。
- 退出路径、沉浸切换、长时间停留舒适度和截图验证成本都会显著提高。
- 对“只读账本展示”这个首版目标来说，收益不成比例。

判断：**当前不推荐。**

## Recommended Implementation Path

首版最稳妥的实现路径是：

1. 保持 `WindowGroup`
2. 先移除模板 `Hello, world!` 和默认 RealityKit 演示依赖
3. 用 SwiftUI 做一个单窗口四区展示骨架
4. 在骨架中接入只读 view model
5. 后续再决定是否让某个分区升级为 `Volume` 或轻量 RealityKit 装饰

这条路径的关键优点是：

- 能最快看到真实 AutoLedger 内容，而不是继续围着模板资源转
- 不会让 visionOS 首版和 iPad / Mac 主线脱节
- 截图、状态、同步、隐私模式都更容易先跑通

## Data Reuse Boundary

visionOS 不能新增自己的统计口径。

首版建议复用的读模型：

- `TodaySpendingSummary`
- `MonthlySnapshot`
- 最近正式账单摘要
- 快照更新时间、stale 状态、空状态

不建议首版直接复用的内容：

- iPhone Widget 的本地 UI 组合
- Watch 轻量同步 payload
- raw input / OCR 原文 / 截图原图
- iPad / Mac 的可写工作流状态

### Data Source Recommendation

优先顺序建议：

1. **同步后稳定快照或只读聚合模型**
2. CloudKit 正式账单只读拉取
3. 更后续才考虑专门的 visionOS dashboard snapshot

原因：

- visionOS 首版是展示端，不值得为了它单独发明一套新的写入 schema。
- 如果直接拉正式账单，也必须在本地再派生摘要，所以 read model 仍然需要。
- 与 tvOS 一样，最终目标是共享同一套“正式账本事实 + 展示摘要”口径。

## RealityKit Template Assessment

当前 `RealityKitContent` package 仍是模板资源：

- `README.md` 还是默认占位
- 资源包存在，但尚未承载任何 AutoLedger 语义

建议：

- 首版不要让 RealityKit 模板成为 blocker
- 如果主窗口内容主要是账本面板，可先用 SwiftUI 完成
- 只有当我们确实需要空间装饰、立体图层或更自然的深度关系时，再给 RealityKit 安排真实职责

## Minimum Smoke Definition

`GOAL-1583` 之后，如果进入首版骨架实现，最小 smoke 应该定义为：

1. `generic/platform=visionOS` build 通过
2. `Apple Vision Pro` simulator build 通过
3. 模拟器可打开主窗口
4. 四个展示区不空白、不重叠、不被模板 3D 内容遮住
5. `loading / empty / stale / unavailable` 四种状态至少能静态切换验证

注意：这还不等于“visionOS 版完成”，只是说明首版骨架已可见、可读、可继续推进。

## Risks

- 如果下一轮一边做 SwiftUI 面板，一边试图保留模板 RealityKit 3D 演示，容易得到一套既不像账本也不像空间产品的混合界面。
- 如果过早引入 immersive space，会把截图、回归和交互成本一下拉高。
- 如果展示端直接拉正式账单但没有稳定的只读摘要层，后续 tvOS / visionOS 很容易重复实现相同派生逻辑。

## Recommendation

`GOAL-1583` 的结论是：

- **实现可行**
- **首版从 WindowGroup 开始最合理**
- **RealityKitContent 不应成为首版依赖**
- **下一步应实现 SwiftUI 单窗口四区骨架 + 只读 view model 接口，而不是直接冲 immersive**
