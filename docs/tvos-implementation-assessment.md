# AutoLedger tvOS 看板实现评估

> 文档状态：Historical
> 真源范围：tvOS 第一版实现评估快照；当前状态以代码、构建和 `PROJECT_STATUS.md` 为准
> 文档分类核验：2026-07-17
> 上位路线图：[ROADMAP.md](ROADMAP.md)

更新日期：2026-06-06
适用目标：`GOAL-1581` / `GOAL-1740`
当前状态：`GOAL-1740` 第一版只读 UI 已落地，CloudKit 只读数据入口待后续实现

## 1. 评估结论

`AutoLedgerTV` 已经不是纯占位 target。`GOAL-1740` 已将模板入口替换为第一版 tvOS 只读看板。

当前可确认：

1. `AutoLedgerTV` scheme 能被 `xcodebuild` 正常识别。
2. `generic/platform=tvOS` 构建通过。
3. tvOS Simulator destination 可解析，`Apple TV 4K (3rd generation)` 模拟器构建通过。
4. 当前 target 已有 `总览 / 分类 / 趋势 / 摘要` 四页只读 dashboard。
5. 当前 target 已链接 `AutoLedgerCore`，复用 `MonthlySnapshot` 和 `TodaySpendingSummary` 派生展示指标。
6. 当前没有 tvOS 专属 iCloud / CloudKit entitlements，也没有跨设备只读 CloudKit 数据入口。

所以 `GOAL-1581` 的结论不是“tvOS 还不能动”，而是：

- target 基线已可用
- 运行目标已可解析
- 最小 dashboard scene 已落地
- 下一步真正的工作不在工程接入，而在“CloudKit 只读数据入口 / dashboard snapshot”

## 2. 当前工程事实

### 2.1 target 现状

从 [project.pbxproj](/Users/darkrio/Downloads/ProjectRios/AutoLedgerRio/AutoLedger/AutoLedger.xcodeproj/project.pbxproj) 可确认：

- Bundle ID：`top.darkrio326.AutoLedger.tv`
- SDK：`appletvos`
- Deployment Target：`26.0`
- `TARGETED_DEVICE_FAMILY = 3`
- `GENERATE_INFOPLIST_FILE = YES`
- 当前未设置 `CODE_SIGN_ENTITLEMENTS`

这意味着 tvOS target 现在可以独立签名和构建，但还没有 App Group / iCloud 读取能力声明。

### 2.2 运行入口现状

当前 [AutoLedgerTVApp.swift](/Users/darkrio/Downloads/ProjectRios/AutoLedgerRio/AutoLedger/AutoLedgerTV/AutoLedgerTVApp.swift) 保持单 `WindowGroup`，入口仍然是 [ContentView.swift](/Users/darkrio/Downloads/ProjectRios/AutoLedgerRio/AutoLedger/AutoLedgerTV/ContentView.swift)。

`GOAL-1740` 后 `ContentView.swift` 包含：

- `总览 / 分类 / 趋势 / 摘要` 四页切换
- tvOS 专用只读 dashboard store
- `loading / empty / unavailable / ready` 状态
- 隐私隐藏切换
- 本机正式账本 SQLite 只读加载
- `MonthlySnapshot` / `TodaySpendingSummary` 指标派生

仍未包含：

- CloudKit 只读拉取
- dashboard snapshot record
- tvOS 专属同步状态
- tvOS 三语本地化资源拆分

### 2.3 构建与 destinations 证据

本轮验证结果：

- PASS：`xcodebuild -showdestinations -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV`
- PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV -configuration Debug -destination 'generic/platform=tvOS' build`
- PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV -configuration Debug -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build`
- PASS：`xcrun simctl list devices available | rg 'Apple TV'`

结论：tvOS runtime 和 simulator 目标当前已经可用，不再是阻断项。

## 3. 数据入口评估

### 3.1 不能直接复用 Widget 的本地读取路径

iPhone Widget 当前通过 [AutoLedgerWidgets.swift](/Users/darkrio/Downloads/ProjectRios/AutoLedgerRio/AutoLedger/AutoLedgerWidgets/AutoLedgerWidgets.swift) 中的 `WidgetLedgerStore` 读取 App Group SQLite 和快照元数据。

这条路径不能直接用于 tvOS，原因很简单：

- App Group 容器是单设备本地容器
- Apple TV 读到的是 Apple TV 本机容器
- 它不会天然读取到 iPhone 上的 `autoledger.sqlite3`

所以 tvOS 不能照搬“本地 App Group SQLite 读法”。

### 3.2 候选实现路径

#### 路径 A：tvOS 直接只读拉取 CloudKit 正式账单

做法：

- tvOS target 增加 iCloud / CloudKit capability
- 允许 tvOS 只读调用 `LedgerCloudKitSyncAdapter.fetchAllTransactionRecords()`
- 拉取远端正式账单与配置
- 在 tvOS 本地使用 `TodaySpendingSummary` 和 `MonthlySnapshot` 派生展示指标

优点：

- 不需要新建服务端 schema
- 直接复用现有 `CloudLedgerSyncSchema`
- 指标口径能与主账本保持一致

问题：

- 当前 `LedgerCloudKitSyncAdapter` 的读取路径和“live write 验证”绑在一起，tvOS 只读场景不合适
- 首次拉取会拿到完整正式账单集合，展示端负担比 dashboard snapshot 更重
- tvOS 还需要自己的缓存 / empty / stale / unavailable 状态机

#### 路径 B：主可写端写入一个 CloudKit dashboard snapshot，tvOS 只读该快照

做法：

- iPhone / iPad / Mac 在同步后写一个派生 dashboard snapshot
- tvOS 只拉一个轻量快照 record
- 快照中直接带本月总额、分类占比、趋势、Top 商户、更新时间、隐私可展示字段

优点：

- tvOS 读取轻、启动快、只读边界清晰
- 客厅展示端不需要拿全量交易明细
- 更符合“稳定展示快照”的产品定义

问题：

- 需要新增 snapshot schema 或 record type
- 主可写端需要承担快照写入和版本兼容
- 本轮并未为此准备额外 schema

### 3.3 推荐路径

`GOAL-1581` 建议采用“先 A 后 B”的判断：

1. 最小可实现面先按“tvOS 只读 CloudKit 正式账单 + 本地派生展示指标”评估。
2. 如果首版拉取成本、复杂度或隐私面不理想，再进入单独 GOAL，把 dashboard snapshot 升级成正式展示入口。

这么做的原因是：

- 现有 CloudKit 正式账单 schema 已存在
- `TodaySpendingSummary` 和 `MonthlySnapshot` 已可直接复用
- 不需要在 tvOS 第一轮就扩展服务端 record 设计

## 4. 最小实现面

`GOAL-1581` 之后，tvOS 第一版最小代码面建议控制在以下范围：

### 4.1 scene

- 保持单 `WindowGroup`
- 根视图使用单一 dashboard root，不引入多窗口
- 根视图只承载四页切换：`总览 / 分类 / 趋势 / 摘要`

### 4.2 数据层

- 新建 tvOS 专用只读 view model
- 不复用 iPad / Mac `LedgerStore`
- 只消费：
  - `TodaySpendingSummary`
  - `MonthlySnapshot`
  - 同步元数据 `updatedAt / isSnapshotStale`

### 4.3 UI 层

- 先做一页总览 smoke，再扩成四页
- 优先验证焦点在卡片和顶部页签之间移动是否顺手
- 最近账单只读摘要最多 5 条，不做详情 drill-down

### 4.4 状态层

- `loading`
- `fresh`
- `stale`
- `empty`
- `unavailable`

这五种状态必须在第一版骨架里就有，不然后面 UI 容易把“没数据”和“没同步”混掉。

## 5. 主要缺口

当前进入真正 tvOS UI 开发前，还差这几项：

1. tvOS target 没有 iCloud / CloudKit capability 和 entitlements。
2. `LedgerCloudKitSyncAdapter` 需要从“读写同门禁”拆成可支持只读拉取的形态。
3. 缺一个平台无关的“展示读模型装配层”。
   - iPhone Widget 现在有 `WidgetLedgerStore`
   - tvOS 不能直接用它，因为它绑定了本地 App Group SQLite 和 WidgetKit
4. 没有 tvOS 三语本地化文案。

## 6. 实现风险

### 6.1 产品风险

- 如果直接把 iPad / Mac 工作台式信息密度搬到 tvOS，大屏会显得杂乱。
- 如果首版展示最近账单过多，会破坏客厅场景的隐私边界。

### 6.2 工程风险

- 若 tvOS 直接读完整 CloudKit 正式账单，首次载入和本地聚合成本会上升。
- 若继续把 CloudKit 读取逻辑绑在现有“允许 live write”门禁上，tvOS 只读端会被不必要地卡住。

### 6.3 发布风险

- tvOS target 当前能构建，但还没有走过 App Store Connect 平台接入和真机 smoke。
- 如果没有专门的 stale / unavailable UI，审核时容易出现“空白屏或 0 数据误导”的体验问题。

## 7. 建议给下一轮

`GOAL-1581` 完成后，下一轮最合适的是：

1. 新建 tvOS 只读展示 view model，先不做完整视觉稿。
2. 把 CloudKit 读取门禁拆成可支持 tvOS 只读拉取。
3. 用总览页做第一块 smoke UI，验证：
   - 页签焦点
   - 大卡片可读性
   - `fresh / stale / empty / unavailable` 四类状态

如果这三点顺利，再继续把分类 / 趋势 / 摘要补齐。

## 8. 收尾判断

`GOAL-1581` 可以按评估完成处理。

因为关键问题已经明确：

- tvOS target 和 simulator 都可用
- 当前不是工程接入卡住，而是数据入口和展示骨架尚未实现
- 最小实现路径已经收敛到“CloudKit 只读拉取 + 本地派生 dashboard 指标”

这足够支持我们进入 tvOS 第一版真正的代码实现，或继续按顺序进入 `GOAL-1582` 先完成 visionOS 设计，再统一推进展示平台 UI。
