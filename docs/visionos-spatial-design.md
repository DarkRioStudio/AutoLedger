# AutoLedger visionOS Spatial Design

> Document status: Reference
> Source-of-truth scope: visionOS spatial product design; current implementation lives in the target code and build evidence
> Classification verified: 2026-07-17
> Parent roadmap: [ROADMAP.md](ROADMAP.md)

## Goal

`GOAL-1582` 的目标不是把 visionOS 变成另一个可写账本端，而是定义 AutoLedger 在空间计算设备上的第一版展示形态：它应该比 tvOS 更沉浸、比 iPad 更轻交互、比 Widget 更完整，但仍然保持只读和低负担。

## Product Position

- 平台定位：单一正式账本的空间展示端。
- 用户心智：抬头查看自己的消费结构，而不是坐下来做账本整理。
- 首版边界：只读、低噪声、可快速收起，避免把 iPad / Mac 的生产力操作搬进空间场景。

## Entry Surface

首版推荐从 `WindowGroup` 开始，而不是直接进入全屏沉浸式空间。

- 默认入口：一个主空间窗口，承担月度总览与最近账单浏览。
- 辅助展示：在同一窗口内做前中后层次，而不是首版就拆多窗口。
- Immersive Space：保留为后续增强项，首版不作为必需能力。

原因：

1. 当前 `AutoLedgerVision` target 已能通过 generic `visionOS` build，但模板仍是 `WindowGroup + RealityKitContent` 的基础形态。
2. 首版先收口“稳定读取同一账本快照 + 形成空间阅读层次”，比先做沉浸式切场更重要。
3. 若直接从 immersive 场景起步，会更早碰到空间锚定、退出路径、舒适度和截图管线复杂度问题。

## Information Architecture

首版保持四个固定展示区，但在一个主空间窗口内完成，不做复杂模式切换。

### 1. Monthly Board

主视线区域固定一块“月度空间看板”，展示：

- 本月总支出
- 本月账单数
- Top 商户
- Top 分类
- 同比 / 环比提示（若当前已有稳定口径）
- 数据更新时间 / 是否较旧

这块面板应该始终是用户进入时看到的第一层内容，视觉上类似“空间里的总控卡”。

### 2. Floating Category Cards

主看板两侧环绕一组分类卡片，展示：

- 分类名称
- 本月金额
- 占比
- 趋势方向

设计原则：

- 不超过 5 到 7 张主卡，避免视野里漂浮过多元素。
- 卡片按金额排序，优先展示对用户最重要的分类。
- 每张卡片支持轻量 focus，高亮后显示更完整的说明，但不进入深层编辑页面。

### 3. Year Timeline Wall

在主看板后方或右后侧，用较长横向区域展示“年度消费时间线墙”。

- 按月份展示年度支出节奏
- 可标记异常高支出月份
- 可附带每月 Top 分类或摘要标签

它的作用不是精确表格分析，而是让用户在空间里“一眼看到这一年的起伏”。

### 4. Recent Transactions Rail

在用户较容易扫视的位置放一条最近账单悬浮列表：

- 最近 5 到 8 笔正式账单
- 商户 / 分类 / 时间 / 金额
- 只读详情展开

最近账单区应弱于主看板，不抢主视线，但足够近，方便用户快速确认“最近发生了什么”。

## Spatial Layout Principles

### Reading Distance

- 主看板：中距离阅读，优先保证金额和标题可读性。
- 分类卡：略远于主看板，但仍应在轻微转头范围内。
- 时间线墙：更远、更横向，承担背景信息层。
- 最近账单：比时间线更近，方便扫视。

### Density

- 每个平面只承担一种阅读任务，不把摘要、趋势、明细混在同一个面板里。
- 同屏优先看结构，不优先看全部明细。
- 首版避免大段段落文案，只保留标题、金额、标签和少量说明。

### Motion

- 首版不依赖持续动画。
- 允许轻量呼吸、hover、focus 放大，但避免长时间漂浮运动。
- 数据刷新时应平滑替换，不做强烈转场。

## Interaction Model

visionOS 首版按“轻交互只读浏览”设计：

- 注视 + 捏合：查看分类卡、最近账单详情。
- 轻量筛选：时间范围或视角切换可保留一个简单 segmented control。
- 不支持：拖拽文件、批量编辑、文本输入、复杂搜索、账单清洗。

交互重点：

- 用户不需要记住层级深度。
- 任意展开都应易于返回。
- 长时间停留也不应疲劳。

## Privacy Mode

visionOS 比 tvOS 更需要隐私控制，因为它更靠近个人视野，但仍可能被旁观者看到。

首版必须支持：

- 一键隐藏金额
- 一键隐藏商户名
- 最近账单可切到仅显示分类 / 来源摘要
- “数据较旧 / 未同步”状态独立展示，不与隐私遮罩混淆

## Data Contract

visionOS 首版继续遵循 v1.5.0 单一正式账本策略：

- 只读取同一个正式账本快照
- 不维护独立账本
- 不引入新统计口径
- 不读取候选账单、raw input、OCR 原文、截图原图

展示数据建议复用：

- `TodaySpendingSummary`
- `MonthlySnapshot`
- 最近正式账单摘要
- 快照更新时间 / stale 状态

## First-Version Scope Cut

首版需要做到：

- 有明确主窗口层次
- 有月度总览
- 有分类卡
- 有年度趋势区
- 有最近账单区
- 有隐私模式
- 有 stale / empty / loading / unavailable 状态

首版明确不做：

- 沉浸式全空间漫游
- 空间里直接编辑账单
- 文件导入或拖拽
- 多账本切换
- 自定义复杂布局编辑
- 依赖 Vision Pro 真机才能成立的交互创新

## Handoff To GOAL-1583

`GOAL-1583` 需要在本设计基础上回答实现问题，而不是重复定义产品形态：

1. `WindowGroup` 是否足够承载首版全部展示区。
2. 是否需要 `Volume` 或额外 scene 才能让时间线墙和分类卡层次更自然。
3. 当前 `RealityKitContent` 模板资源是否保留，还是首版先用纯 SwiftUI 空间面板。
4. 只读数据应直接接 CloudKit 拉取，还是接同步后稳定快照。
5. 最小 smoke 验证应如何定义：generic build、simulator build、窗口可打开、基础四区可见。
