# AutoLedger All-Platform Screenshot Pipeline Design

> Document status: Reference
> Source-of-truth scope: original cross-platform screenshot pipeline design; executable behavior lives under `tools/appstore-screenshots/`
> Classification verified: 2026-07-17
> Parent roadmap: [ROADMAP.md](ROADMAP.md)

## Goal

`GOAL-1590` 的目标不是立刻实现全平台截图，而是给现有 `tools/appstore-screenshots/` 管线补一个明确的扩展设计，保证后续把 iPad、Mac、tvOS、visionOS 接进来时，不会破坏已经稳定的 iPhone / Watch 导出链路。

## Current Baseline

当前截图管线已经具备：

- iPhone 导出
- Apple Watch 导出
- `preview.html` 汇总
- `screenshots.json` 配置驱动
- `export.sh --ios-only / --watch-only`

当前明确缺失：

- iPad
- Mac Catalyst
- tvOS
- visionOS

`build_preview.py` 当前也只按 `ios` / `watch` 两组渲染页面结构。

## Design Principles

### 1. Do Not Break Existing iPhone / Watch Flow

全平台扩展必须保持：

- 原 `bash tools/appstore-screenshots/scripts/export.sh`
- 原 `--ios-only`
- 原 `--watch-only`
- 原 `config/screenshots.json` 的既有字段

也就是说，新平台只能 additive 扩展，不能要求先重写现有 iPhone / Watch 配置。

### 2. One Config, Multi-Platform

继续使用同一个 `screenshots.json`，但扩展出新的平台节点：

- `ipad`
- `mac`
- `tvos`
- `visionos`

避免把每个平台拆成独立配置文件，否则 copy 和 marketing copy 会很快漂移。

### 3. Raw Output First, Render Second

保持现有两阶段结构：

1. capture 原始截图
2. render 商店图

这样每个平台都能共享：

- 原始截图复查
- copy 重渲染
- `preview.html` 统一目检

### 4. Fixture-Driven, Not Live Data

全平台截图都应基于固定 fixture，不读真实账本、不跑真实同步、不依赖真实 OCR、CloudKit、WatchConnectivity 或用户设备内容。

## Proposed Config Shape

在 `app` 下新增平台信息：

- `ipad.scheme`
- `ipad.bundleId`
- `ipad.deviceCandidates`
- `mac.scheme`
- `mac.bundleId`
- `tvos.scheme`
- `tvos.bundleId`
- `tvos.deviceCandidates`
- `visionos.scheme`
- `visionos.bundleId`
- `visionos.deviceCandidates`

在 `targets` 下新增：

- `ipad_13`
- `ipad_129`
- `mac_desktop`
- `tvos_16_9`
- `visionos_window`

在 shots 列表上新增：

- `ipadShots`
- `macShots`
- `tvosShots`
- `visionosShots`

每个平台沿用当前结构：

- `id`
- `scene`
- `title`
- `subtitle`

## Proposed CLI Flags

在现有 `export.sh` 上追加，不替换旧参数：

- `--ipad-only`
- `--mac-only`
- `--tvos-only`
- `--visionos-only`
- `--platform <ios|watch|ipad|mac|tvos|visionos>`

约束建议：

- `--platform` 可作为统一入口
- 旧 flag 保留，内部映射到 `--platform`
- 禁止一次传多个 `*-only` 造成歧义

## Output Layout

当前：

```text
output/
  raw/
    ios/
    watch/
  store/
    ios/
    watch/
```

扩展后建议：

```text
output/
  raw/
    ios/{locale}/
    watch/{locale}/
    ipad/{locale}/
    mac/{locale}/
    tvos/{locale}/
    visionos/{locale}/
  store/
    ios/{locale}/
    watch/{locale}/
    ipad/{locale}/
    mac/{locale}/
    tvos/{locale}/
    visionos/{locale}/
  preview.html
```

## Platform Capture Strategy

### iPad

目标不是复用 iPhone 首页，而是导出 iPad 工作台主场景。

建议首版场景：

- 工作台总览
- 导入页
- 账本大视图
- 分析页
- 候选账单 / 数据清洗

注意：

- iPad 截图要以横屏主场景为主
- 固定外框尺寸，文字在组件内部自适应

### Mac Catalyst

Mac 截图应体现桌面生产力，不照搬 iPad。

建议首版场景：

- 导入工作区
- 账本大表格
- 批量编辑
- 重复账单检查
- 设置 / 导出

注意：

- 目标是窗口态截图，而不是全屏 marketing hero
- 应保留桌面工具感

### tvOS

建议只导出只读看板：

- 总览
- 分类
- 趋势
- 摘要

注意：

- 保持 16:9 大屏布局
- 验证远距离可读性
- 隐私模式也应该有一张可选素材

### visionOS

建议首版先导出主窗口视图，而不是沉浸式空间截图。

建议场景：

- 月度空间看板
- 分类漂浮卡片
- 年度时间线墙
- 最近账单悬浮列表

注意：

- 首版可把“空间截图”定义为主窗口中的空间层次 UI
- 不必等 immersive space 成熟才开始截图管线设计

## Preview Page Grouping

`build_preview.py` 应从当前两组扩展为六组：

- iPhone
- Apple Watch
- iPad
- Mac
- Apple TV
- visionOS

展示顺序建议：

1. iPhone
2. Apple Watch
3. iPad
4. Mac
5. Apple TV
6. visionOS

原因：

- 先展示已发布主平台
- 再展示工作台扩展
- 最后展示只读展示端

## Render Responsibilities

当前已有：

- `render_marketing.py`
- `render_watch.py`
- `build_preview.py`

扩展建议：

- 保留 `render_watch.py` 独立
- 将 `render_marketing.py` 演进为支持 `ios/ipad/mac/tvos/visionos`
- 或拆成：
  - `render_ios_family.py`
  - `render_desktop_tv_spatial.py`

推荐原则：

- 先减少重复逻辑
- 但不要为了“统一”把 Watch 特殊尺寸逻辑强行混进去

## Fixture Requirements

全平台统一 fixture 需要覆盖：

- 正式账单列表
- 今日支出
- 月度统计
- Top 商户
- 分类占比
- 最近账单摘要
- 空状态
- stale 状态

禁止作为截图 fixture 的内容：

- 真实收据
- 真实支付截图
- 真实姓名、手机号、卡号尾号、订单号
- 真实同步日志

## Minimum Implementation Plan

`GOAL-1591` 建议分四步做：

1. 扩配置
   - `screenshots.json` 加新平台与 shots
2. 扩 CLI
   - `export.sh` 加 `--ipad-only --mac-only --tvos-only --visionos-only`
3. 扩 preview
   - `build_preview.py` 支持六平台分组
4. 分平台补 capture / render
   - 先 iPad / Mac
   - 再 tvOS / visionOS

这样可以避免一次性把所有平台一起拉进同一个大调试面。

## Acceptance For GOAL-1590

完成设计即可视为通过：

- 明确配置扩展方式
- 明确 CLI flag
- 明确输出目录
- 明确 preview 分组
- 明确每个平台的首批场景
- 明确 `GOAL-1591` 的最小实施顺序

## Recommendation

`GOAL-1590` 后的推荐推进顺序：

1. 先实现 iPad / Mac 的截图扩展
2. 再接 tvOS / visionOS
3. 最后统一跑 `preview.html` 目检和像素检查

原因很简单：iPad / Mac 是当前更接近真实产品闭环的平台，它们稳定之后，tvOS / visionOS 的展示素材也更容易跟着收口。
