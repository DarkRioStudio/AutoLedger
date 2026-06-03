# CHANGELOG

本文件记录 `docs/project` 维度下的文档与流程变更。

格式约定：
- 日期：`YYYY-MM-DD`
- 时间：`YYYY-MM-DD HH:mm +0800`
- 变更分类：新增 / 变更 / 修复 / 归档

## [Unreleased]

### 修复（v1.5.0）
- [2026-06-03 +0800] 修复 iCloud 同步接入后的三处真机体验问题：App 启动时 iCloud 拉取 / 外部入口补推和 Gemma 预热延后到首屏渲染后再后台执行，降低 iPhone / iPad 启动 UI 卡顿；iPad 工作台右侧 detail 绑定侧边栏 selection identity，设置页内部 push 后切换主菜单会正确刷新右侧页面；Apple Watch 左滑到“最近支出”第二屏时 navigation title 会随页面切换，不再继续显示“今日支出”。
- [2026-06-02 +0800] 修复 iPad 设置页进入“数据管理”时可能崩溃的问题：设置页会把根 `LedgerStore` 显式传给依赖账本状态的导航目的页，避免 `DataManagementView` 首屏读取 `@EnvironmentObject` 时因导航环境丢失触发 fatal error；同时保留 CloudKit 后台通知 / iCloud KVS 所需 entitlement，保证后续同步能力可用。

### 变更（v1.5.0）
- [2026-06-03 +0800] 推进第二批 GOAL-1521B1 Widget 点击路径：`DailyExpenseWidget` 增加 `autoledger://ledger/today` deep link，主 App 根视图接收后复用现有账本页导航状态，iPhone 桌面 / 负一屏今日支出小组件点击后进入账本页；本轮不新增 watchOS WidgetKit extension target，不修改 Bundle ID / signing / entitlements，真正 Apple Watch 表盘 target 仍需后续受控推进。
- [2026-06-03 +0800] 完成 GOAL-1570 Mac Catalyst 接入评估：确认当前主 App 仍为 iPhone + iPad，`SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"` 且 `SUPPORTS_MACCATALYST = NO`；本轮不启用 Catalyst、不改 target / scheme / signing / entitlements / Xcode Cloud 配置，只输出 Mac 复用资产、依赖风险、文件权限、菜单快捷键、大表格和批量导入依赖清单；建议先完成 GOAL-1540 批量导入队列，再进入 GOAL-1571 Mac 拖拽导入。
- [2026-06-03 +0800] 收尾 GOAL-1566 Watch / Widget / 展示端同步快照：将 Watch / Widget 的同步后稳定快照、更新时间、过期提示和 Watch 第二屏标题修复作为最小闭环完成；tvOS / visionOS 展示端不继续放在 1566 内扩张，转入 GOAL-1580～1583 单独设计与实现评估；发布前仍保留 iPhone Widget / Today View / Apple Watch 真机 smoke。
- [2026-06-02 +0800] 部分完成 GOAL-1566A Watch / Widget 同步快照元数据：主 App 在 App Group 记录本机账本快照更新时间和 iCloud 最近成功同步时间；Watch 今日支出 payload 改用该快照时间并携带过期状态；Widget 读取同一 App Group 元数据，今日支出 / 月报小组件在同步可能过期时显示轻量“较旧 / Stale”提示，避免只读端把 timeline 刷新时间误当作账本数据时间。
- [2026-06-02 +0800] 收尾 GOAL-1565 iPhone / iPad 基础 iCloud 同步闭环：将 GOAL 队列中的 1565 从“部分完成”改为“已完成”，明确已覆盖正式账单、软删除、主要配置、App Intents 和 Share Extension 外部入口补推；Mac Catalyst 复用验证转入 GOAL-1570，Watch / Widget / 展示端快照转入 GOAL-1566，CloudKit custom zone / silent push / 配置逐条 record 不再作为 1565 blocker。
- [2026-06-02 +0800] 完成 GOAL-1565O Share Extension 记账 iCloud 补推链路：Share Extension 直写 App Group SQLite 成功后会在 App Group 中标记待推送账单；主 App 启动、回前台或外部入口通知触发时会同时检查标准 defaults 与 App Group 标记，成功增量推送到 iCloud 后统一清除标记；同步状态文案从“快捷指令”扩展为“外部入口”，覆盖快捷指令与分享扩展。
- [2026-06-02 +0800] 完成 GOAL-1565N iCloud 配置快照同步：新增 `LedgerConfiguration` CloudKit record，用单个配置快照同步订阅、商户别名、分类修正、自定义分类 / 来源、订阅年费覆盖 / 备注和必要用户设置；本地配置变化会更新时间戳并触发增量推送，pull 时会按远端更新时间应用配置；旧 iCloud Drive 备份开关不会通过配置快照重新打开。
- [2026-06-02 +0800] 完成 GOAL-1565M 快捷指令记账 iCloud 补推链路：QuickLedgerIntent、VoiceLedgerIntent、AddTransactionIntent 直写 SQLite 成功后会标记待推送账单并通知主 App；主 App 启动、回前台或收到 Intent 保存通知时会刷新本地账本并触发 iCloud 增量推送，推送成功后清除待推送标记。
- [2026-06-02 +0800] 完成 GOAL-1565L iCloud 同步推拉职责拆分：App 启动改为只从 iCloud 拉取远端账本；账本页 / iPad 账本下拉刷新改为懒加载拉取；本地新增、编辑、删除、恢复、商户别名批量刷新账单后延迟触发增量推送；数据管理页“强制刷新数据”继续执行一次全量推送 + 拉取，用于人工排查和重拉。
- [2026-06-02 +0800] 完成 GOAL-1565K iCloud 同步设置页收口：根据 iPad 真机同步通过结果，将“CloudKit 账本同步”改为“iCloud 同步”；隐藏 iCloud Drive 旧备份卡片；移除同步卡片的长说明和重复状态行；“同步一次”改为“强制刷新数据”并执行全量同步；同步日志继续作为进度和错误的唯一展开区；版本计划同步记录订阅和商户别名后续纳入 iCloud 同步 schema。
- [2026-06-02 +0800] 部分完成 GOAL-1565J iCloud 同步启用流程：数据管理页新增“启用 iCloud 同步”开关，首次开启会清空 CloudKit push checkpoint 并立即执行全量同步；开启后 App 启动 `.task` 会自动触发一次后台增量同步；CloudKit 同步状态统一写入近期日志，UI 展示阶段进度和最近 6 条日志，手动“同步一次”仅在开关开启后可用。
- [2026-06-02 +0800] 部分完成 GOAL-1565I CloudKit 全量 / 增量同步性能收口：根据真机错误确认 `_defaultZone` 不支持 `getChanges`，拉取回退到 `CKQueryOperation` 100 条分页；推送从诊断期单条 record operation 恢复为最多 100 条一批，并在本地保存 `lastSuccessfulCloudKitPushAt`，后续手动同步只推本机新增 / 修改 / tombstone 变更；备份恢复会清除 push checkpoint，避免恢复旧数据后漏推。
- [2026-06-02 +0800] 部分完成 GOAL-1565H CloudKit 拉取索引依赖收口：根据真机回填确认 `LedgerTransaction` push / pull 已可成功，但旧拉取路径依赖 CloudKit Dashboard 中 `recordName` 标记为 Queryable；`LedgerCloudKitSyncAdapter` 改用 default zone changes 拉取远端账单，避免手动同步依赖 `recordName` query index，并记录首次全量同步慢、290 条同步统计与数据管理页当前计数口径不一致的问题待后续优化。
- [2026-06-02 +0800] 部分完成 GOAL-1565G CloudKit 最小探针诊断：根据真机回填确认单条 `LedgerTransaction` 完整 record 仍被 `serverRejectedRequest` / `CKInternalErrorDomain 2000` 拒绝；`CKModifyRecordsOperation` 保存策略改为 `.allKeys`，完整保存失败后会用同 record type 写入最小探针 record 并尝试删除，用 `Probe: minimal-save ...` 区分容器 / record type 本身不可写，还是完整字段集合被拒绝。
- [2026-06-02 +0800] 完成 GOAL-1594 平台无关解释器主链路收口规划：在 `versions/v1.5.0-plan.md` 记录当前 `LedgerTextInterpreterCore` 已存在但主入账链路仍主要用 App 层 `SmartReceiptParser` / `ReceiptParser` 产出最终结构化账单的事实；明确目标链路为 Core 候选实体提取与评分、可选本地 AI rerank、App adapter 只负责 OCR / provider / UI / 保存，并新增 GOAL-1595～1598 跟进 Core 候选模型、主链路切换、Intent / Share Extension 收口和平台规则迁移。
- [2026-06-02 +0800] 完成 GOAL-1593 淘宝闪购支付宝账单详情商户提取：`ReceiptParser` 新增支付宝 / 淘宝账单详情的“商品说明”标签块解析，在“支付时间 / 付款方式 / 商品说明”连续标签后按同序值提取真实店铺说明，并清理 OCR 换行与“外卖订单”后缀；新增 Golden Case 覆盖 `淘宝闪购` 平台行 + `LINLEE林里•手打柠檬茶（南开海光MALL店）` 商品说明样本，避免继续把平台名误当商户。
- [2026-06-02 +0800] 部分完成 GOAL-1565F CloudKit 推送拒绝定位：根据真机 UI 回填确认 `CKErrorDomain` code 15 发生在 push 阶段，且 underlying 为 `CKInternalErrorDomain` code 2000；CloudKit 手动同步临时改为单条 record 一个 modify operation，并在单条保存 / 删除失败时显示 recordName、字段类型与字符串长度摘要，不输出商户或备注原文，便于继续定位是否为单条账单内容、字段长度、schema 或服务端限制导致拒绝。
- [2026-06-02 +0800] 部分完成 GOAL-1565E CloudKit 真机错误诊断：针对 iPad / iPhone 手动同步时出现的 `CKErrorDomain` code 15，将手动同步状态拆分为推送、拉取和本地 SQLite 写入阶段；CloudKit adapter 新增 CKError / partial error / underlying error 描述，并将 push 保存与删除请求按 100 条一组分批提交，便于定位是 record schema、query / index 还是批量 operation 被服务端拒绝；WatchConnectivity counterpart 未安装日志记录为非本轮 CloudKit 阻断。
- [2026-06-02 +0800] 部分完成 GOAL-1565D 手动 CloudKit 同步闭环：主 App entitlement 保留 CloudDocuments 并新增 CloudKit，去除本轮不需要的 `aps-environment`；数据管理页新增 CloudKit 账本同步手动入口，执行 account status 检查、push 本机正式账单、fetch 远端 `LedgerTransaction` 并按 sync revision / updatedAt 应用到 SQLite；旧 iCloud Drive 自动备份从 UI 自动开关降级为 legacy 手动备份 / 恢复；离线回归新增远端 insert / update / tombstone / conflict 应用断言。
- [2026-06-02 +0800] 部分完成 GOAL-1565C CloudKit live 前置门控：`LedgerCloudKitSyncAdapter` 新增 iCloud account status 检查、`allowsLiveCloudKitWrites` 手动写入开关和最小 `CKModifyRecordsOperation` push 路径；默认仍关闭 live 写入，缺少人工 capability / provisioning / Xcode Cloud / 真机验证时只返回受控错误；未修改 entitlements、Bundle ID、App Group 或 iCloud Container。
- [2026-06-02 +0800] 部分完成 GOAL-1565B CloudKit dry-run adapter：主 App 新增 `LedgerCloudKitSyncAdapter`，提供 disabled / dry-run / live 三态保护；dry-run 可把 `LedgerSyncPushBatch` 映射为 `LedgerCloudKitMappedRecord` 并生成 `CKRecord`，live 模式在 capability、provisioning 和 Xcode Cloud 验证前仍抛出受控错误；本轮未写入 CloudKit、不修改 entitlements、不改变发布链。
- [2026-06-02 +0800] 部分完成 GOAL-1565 基础账本同步闭环：新增 `CloudLedgerSyncSchema`、`LedgerTransactionSyncPayload`、`LedgerSyncPushBatch` 和 `LedgerSyncPlanner`，固定正式账单 CloudKit record type、record name、字段映射、upsert / tombstone / expired tombstone 拆分和 `changedAfter` 增量过滤；当前为本地计划层，不 import CloudKit、不修改 entitlements、不声明真实多端同步已完成。
- [2026-06-02 +0800] 完成 GOAL-1564 基础同步元数据与冲突模型底座：新增 `TransactionSyncMetadata` / `TransactionSyncRecord`、`SyncConflictState` 和基础冲突判定器；SQLite `transactions` 增量补齐 `sync_revision`、`sync_device_id`、`sync_idempotency_key`、`sync_conflict_state`，保存 / 更新 / 软删除 / 恢复会维护 revision 与 tombstone；`BackupTransaction` 新增可选 `syncMetadata` 并保持旧 v1 JSON 兼容；离线回归新增 sync metadata、tombstone、active/deleted sync record 和旧备份解码用例。
- [2026-06-02 +0800] 完成 GOAL-1563 多端同步现状审计与策略冻结：确认当前 iCloud 为 CloudDocuments 单文件 BackupBundle 备份、Watch 为 WatchConnectivity 轻量同步、Widget 为 App Group 本机 SQLite 只读；冻结 v1.5.0 最小策略为 local-first + CloudKit private database 结构化同步优先，iCloud Drive BackupBundle 保留备份 / 导出 / 恢复角色，原始截图、OCR 全文、支付截图、小票图片、raw input 和调试包默认不进入同步。
- [2026-06-02 +0800] 文档补充 v1.5.0 基础多端数据同步要求：将 iPhone / iPad / Mac 可写端、Apple Watch 轻写入端、Widget / tvOS / visionOS 只读端的数据一致性列为本版本底座问题；明确 iCloud Drive 单文件备份、WatchConnectivity 和本机 App Group Widget 读取都不等同于完整多端同步；新增 GOAL-1563～1566 作为多端同步审计、元数据 / 冲突模型、基础账本同步闭环和展示端快照同步任务。
- [2026-06-01 +0800] 部分完成 GOAL-1521 表盘小组件 UI 基础：现有 `DailyExpenseWidget` 新增 `.accessoryInline`、`.accessoryCircular`、`.accessoryRectangular` 三种 accessory family 展示，复用今日支出数据口径，支持 inline 文案、圆形金额 / 笔数、矩形金额 / 笔数摘要；当前工程仍无独立 watchOS WidgetKit complication target，因此 Apple Watch 表盘上线仍需后续 target / embedding / signing 收口。
- [2026-06-01 +0800] 完成 GOAL-1512 Watch 左滑最近支出第二屏：最近支出页补充当前账本提示，列表行显示今天 / 昨天 / 日期 + 时间，最近账单可点入只读详情；iPhone -> Watch 同步 payload 增加分类和来源展示字段，Watch 详情页展示金额、商户、分类、来源、时间和备注；补齐 Watch 三语本地化 key，Watch generic watchOS Debug build 通过。
- [2026-06-01 +0800] 完成 GOAL-1511 Watch 首屏今日支出：iPhone `WatchConnectivityHost` 同步 payload 新增 `todaySummary`，Watch session / view model 接收今日总额、笔数、最近展示名和更新时间；Watch App 首屏切换为“今日支出”摘要卡，保留语音记账与快速记账入口，并将最近 5 笔支出保留为左滑第二页；补齐简体中文、繁体中文、英文 Watch 本地化 key，Watch generic watchOS Debug build 通过。
- [2026-06-01 +0800] 部分完成 GOAL-1520 iPhone / Watch Widget 今日支出数据源统一：现有 `DailyExpenseWidget` 已覆盖 iPhone 桌面小组件和负一屏 / Today View，小组件数据口径对齐 GOAL-1510，按本地日区间、`amount > 0`、未删除正式账单统计今日支出；日期查询改为匹配 SQLite ISO8601 存储格式，并为最近展示名增加商户 -> 分类 -> 来源回退。Watch 表盘小组件 target / UI 仍留待后续。
- [2026-06-01 +0800] 完成 GOAL-1510 Watch 今日支出数据服务：在 `AutoLedgerCore` 新增 `TodaySpendingSummary`，按本地日区间 `[localStartOfDay, nextLocalStartOfDay)`、正金额、活跃正式账单统计今日总额、笔数和最近账单展示名；`LedgerStore` 新增 `todaySpendingSummary` 只读入口；离线回归补齐今日正金额、昨日排除、零/负金额排除、已删除输入契约、日边界和展示名回退用例，并通过主 App generic iOS Debug build。
- [2026-06-01 +0800] 完成 GOAL-1503 SQLite / BackupBundle schema 缺口评估：基于当前 `Transaction`、`SQLiteTransactionStore`、`BackupBundle` 和 `LedgerStore` 备份恢复实现，形成 additive migration 方案；建议引入 `PRAGMA user_version`、新增 `ledgers` 默认账本表、扩展 `transactions` 的 ledger / type / currency 字段、独立建立 import batches / raw inputs / candidate transactions / candidate events 候选区表，并规划 BackupBundle v2 在兼容 v1 恢复的前提下支持多账本和可选候选区备份。
- [2026-06-01 +0800] 完成 GOAL-1502 候选账单状态模型设计：在版本计划中定义 `rawInput`、`candidate`、`reviewed`、`transaction`、`rejected` 状态流，明确只有正式 `transaction` 进入账本统计；补充候选记录最小字段草案、失败原因枚举、High / Medium / Low 置信度复核策略、重复提示不自动删除原则、原始输入隐私边界、后续 SQLite / BackupBundle 迁移建议和测试用例设计。
- [2026-06-01 +0800] 完成 GOAL-1501 默认账本与今日支出口径定义：在版本计划中明确当前无多账本字段时使用虚拟 `default-local-ledger` 承载所有活跃正式账单；今日支出按用户本地日历日 `[localStartOfDay, nextLocalStartOfDay)`、`occurredAt`、正金额、未删除、已确认正式账单统计；候选账单、已删除账单、零/负金额和未确认多币种不进入今日支出，并补充 GOAL-1510 后续离线测试用例设计。
- [2026-06-01 +0800] 扩展 v1.5.0 版本计划为全平台路线：在 iPad 工作台完善后，以 Mac Catalyst 推进桌面端拖拽导入、CSV / JSON 导入导出、快捷键、基础菜单栏、大表格、批量修正和重复账单检查；后续规划 tvOS 只读家庭大屏看板与 visionOS 空间展示版本，并将 GOAL 队列扩展到 Mac / tvOS / visionOS / 全平台截图与发布回归。
- [2026-06-01 +0800] 完成 GOAL-1531 iPad 工作台深化与部署烟测：iPad 入口从占位侧边栏推进为真实工作台，总览页显示本月支出、账单总数、Top 商户、最近账单和整理工作流入口；账本页提供 iPad 原生列表 + 详情检查器，支持新增、编辑、删除、语音记账和刷新；候选账单与数据清洗保留为规划工作区清单。已通过 generic iOS Debug build、iPad Pro 13-inch (M5) Simulator build / install / launch、离线回归、Golden 回归和 `git diff --check`。
- [2026-06-01 +0800] 完成 GOAL-1530 iPad 线第一版入口：主 App target 切到 iPhone + iPad，保持 Mac Catalyst 关闭；iPad 设备进入新增 `IPadWorkspaceView`，使用 `NavigationSplitView` 侧边栏组织导入、账本、分析、候选账单、数据清洗和设置；iPhone 继续使用原 `HomeView` Tab；候选账单和数据清洗只做规划入口，不接真实队列或 schema；补齐中英繁三语 iPad 工作台文案，并通过主 App generic iOS Debug build、离线回归与 Golden 回归。
- [2026-06-01 +0800] 完成 GOAL-1500 v1.5.0 基线审计：记录当前 `main` / `v1.4.0` tag / `MARKETING_VERSION=1.4.0` / target 设备族配置，确认 `Transaction`、SQLite 与 BackupBundle 对多账本、候选账单、批量导入队列和清洗历史仍有 schema 缺口；记录截图管线当前只覆盖 iPhone 与 Apple Watch、不覆盖 iPad；`xcodebuild -list`、离线回归、Golden 回归和主 App generic iOS Debug build 均通过。
- [2026-06-01 +0800] 评审 v1.5.0 当前版本计划并补充 GOAL 目标拆解：将 Watch 今日支出、表盘小组件、iPad 工作台、批量导入与识别、数据清洗、多账本、Mac 复用评估、iPad 截图管线和发布回归拆成可独立执行、回归和回滚的 GOAL 队列，并明确推荐推进顺序与首个可执行 GOAL。
- [2026-05-28 +0800] 当前项目切换到内部 v1.5.0 / App Store v1.4.0：Xcode 全 target `MARKETING_VERSION` 从 `1.3.0` 更新为 `1.4.0`；根 README / 英文 README 将 v1.5.0 状态标记为开发中；设置页后续计划文案切换到 iPad 工作台、批量导入与识别、多账本整理和 Watch 今日支出小组件方向。
- [2026-05-28 +0800] v1.5.0 规划承接关系更新：在根 README / 英文 README Roadmap 中标记内部 v1.4.0（App Store v1.3.0）已过审发布，并新增内部 v1.5.0 规划行；`versions/v1.5.0-plan.md` 明确承接内部 v1.4.0 发布基准，面向下一轮 App Store v1.4.0 开发。
- [2026-05-28 +0800] 文档记录 v1.5.0 iPad 截图管线扩展：明确当前 `tools/appstore-screenshots` 仅覆盖 iPhone 与 Apple Watch，不生成 iPad 截图；将 iPad App Store 截图纳入 v1.5.0 发布资产规划，要求补齐 `--ipad-only`、iPad target size、横屏工作台画布、稳定演示数据、多语言输出目录和 `preview.html` 分组目检。

### 变更（public-ready）
- [2026-05-28 +0800] public-ready README 入口调整：根目录 `README.md` 恢复为中文主入口，尽量保留原项目介绍、功能表、技术栈、构建方式和 Roadmap；新增 `README.en.md` 作为英文 public-ready 说明，并在中英文 README 之间互相链接。
- [2026-05-28 +0800] 准备 public repository 首轮整理：补充公开 README、MIT License、贡献指南、安全报告说明、示例 xcconfig 和更完整的 ignore 规则；明确源码授权与 AutoLedger 名称、图标、App Store 截图、营销/品牌素材的授权边界；公开协作说明要求使用虚构账单与 mock 数据，避免在 Issue / PR 中上传真实小票、支付截图或个人财务信息。

### 新增（v1.4.0）
- [2026-05-27 +0800] ITER-085 Support Developer 消耗型内购首版：新增 StoreKit 2 `SupportPurchaseManager`，拉取 `top.darkrio326.AutoLedger.support.coffee/lunch/sponsor` 三个 consumable 支持档位，处理 verified / unverified / pending / userCancelled 购买结果并对 verified transaction 调用 `finish()`；监听 `Transaction.updates` 处理延迟完成交易；本地记录 `supportPurchaseCount`、`lastSupportProductId`、`lastSupportDate` 和已处理 transaction id，避免重复计数；设置页新增“支持 AutoLedger”入口与三语支持页面，明确支持不会解锁额外功能；新增 `AutoLedgerSupport.storekit`、scheme StoreKit 配置和 `docs/iap-support.md`，说明本地 StoreKit 测试与 App Store Connect 配置，并要求内购展示名 / 说明覆盖英文、简体中文、繁体中文。
- [2026-05-27 +0800] ITER-083 Watch 记账 UI 与同步修复：Apple Watch 快速记账改为金额优先布局，金额点击不再弹系统文本输入，改用 Watch 内自定义数字金额面板；分类网格移除对勾图标，改用固定高度按钮、边框和底色表示选中，避免布局被撑开；Watch 分类列表同步 iPhone 用户自定义分类，Watch 入账保存时保留自定义分类字符串；WatchConnectivity 改为账单/分类变化后通过 applicationContext + 可达 sendMessage 同步最近账单和自定义分类，Watch 首屏无账单或无自定义分类时主动触发同步请求，iPhone 不可达时通过 transferUserInfo 排队后台拉取；Watch ViewModel 监听 session 状态变化自动刷新，主 App 通过注入 handler 触发 Watch 同步以保持离线回归可编译；重新导出 zh-Hans Watch 截图，快速记账与确认页截图使用真实 Watch UI。
- [2026-05-26 +0800] ITER-081 辅助功能发布收口：报表页新增 VoiceOver 图表摘要、分类占比 / Top 商户行级可读标签、Reduce Motion 动画降级、增强对比度下的图表弱化态调整，并在分类筛选选中态增加非颜色符号；账本与最近删除行隐藏装饰图标并补齐删除入口 / 已删除账单行标签；Watch 快速记账与语音确认分类网格改用动态字体并增加可见勾选态，降低大字号和 VoiceOver 场景下的识别成本。
- [2026-05-26 +0800] ITER-080 Watch App Icon 小尺寸优化：基于现有 iPhone 图标生成 Apple Watch 专用图标，保留白色钱包、金币、闪电和蓝绿渐变背景，去除星星 / 小圆点等复杂装饰，简化钱包高光与阴影并加粗闪电主视觉；`AutoLedgerWatch Watch App/Assets.xcassets/AppIcon.appiconset` 从单张 1024 universal 图扩展为完整 watchOS app icon set（notification / companion settings / app launcher / quick look / marketing），并新增 `versions/assets/watch-app-icon/` 下的 1024、128、64、48 预览图。
- [2026-05-25 +0800] ITER-079 UI 文案全球化收口：补齐主 App v1.4 主路径与 Watch App 的简体中文 / 繁体中文 / 英文 UI 文案资源；Watch App 新增独立 `zh-Hans.lproj`、`zh-Hant.lproj`、`en.lproj`；主 App `Localizable.strings` 扩展至 457 个 key，覆盖账本筛选、最近删除、月报、分类刷新、商户别名、消费分析、数据管理、订阅管理、问题反馈、反馈邮件预览、OCR / iCloud 用户错误与 App Intents 参数摘要等用户可见入口。DebugView 与调试导出文本继续保留中文，作为开发者 / 回归工具暂不纳入本轮 UI 全球化范围。
- [2026-05-25 +0800] ITER-078 v1.4.0 / v1.4.x Release Notes 草稿：新增 `versions/v1.4.0-RELEASE(draft).md`，汇总 Watch 伴侣 App、辅助功能、App Intents、月报历史月份、微信拼多多解析修复、分类/商户别名批量刷新等已实现能力；补充简体中文 / 繁体中文 / 英文本地化检查结论，明确 `.strings` key 已对齐但 Watch 与部分新增 UI 仍存在硬编码中文，暂不建议声明三语完整本地化。
- [2026-05-20 +0800] ITER-075 月报历史月份浏览：`ReportView` 新增 `@State selectedMonth` + NavigationBar 左右翻页箭头；月报数据改为 `MonthlySnapshot.build(from: store.transactions, referenceDate: selectedMonth)` 动态计算，6 个月趋势图现可显示选中月前 6 个月历史；查看历史月时自动隐藏异常消费提醒（仅当月有效）；切换月份自动清空分类选中状态；趋势图底部文案改为 `snapshot.monthLabel`。
- [2026-05-20 +0800] ITER-073 Watch VoiceOver：`ContentView`（交易行合并标签+Reduce Motion 降级）、`QuickAddView`（分类按钮标签/选中态）、`WatchVoiceRecorderView`（TextField 标签+提示+解析按钮标签）、`WatchVoiceConfirmView`（金额+商户合并标签、分类选中态、保存按钮标签+提示）全部补全 VoiceOver 标注。
- [2026-05-20 +0800] ITER-074 App Intents 三件套：新增 `AddTransactionIntent`（手动记账，直写 SQLite，刷新 Widget）、`ParseLedgerTextIntent`（解析文字账单，调用 `VoiceLedgerParser`，返回结构化摘要）、`OpenQuickAddIntent`（打开快速记账，通过 `QuickLedgerNavigationState` + NotificationCenter 导航）；三个 Intent 均注册到 `AutoLedgerShortcuts.appShortcuts`；中英文本地化全量覆盖。

### 变更（v1.4.0）
- [2026-05-28 +0800] 内部 v1.4.0 发布基准收口：App Store 对外版本 v1.3.0 已过审发布，`versions/v1.4.0-RELEASE(draft).md` 更新为已发布基准记录，后续开发转入 v1.5.0 规划线。
- [2026-05-28 +0800] ITER-089 App Store 截图管线繁体中文输出：截图配置新增 `zh-Hant` locale（`appleLanguages=(zh-Hant)`、`appleLocale=zh_TW`），iPhone 与 Apple Watch 全部截图场景补齐繁体中文标题 / 副标题；截图宿主 SwiftUI 文案从简中 / 英文扩展为简中 / 繁中 / 英文三语选择；`export.sh`、截图 README 和输出目录说明同步更新，支持 `--locale zh-Hant` 单独导出繁体截图。
- [2026-05-28 +0800] ITER-087 v1.4.x Release Notes 更新：`versions/v1.4.0-RELEASE(draft).md` 同步到 2026-05-28 当前状态，补入 Watch 语音记账离线优先入口、Support Developer 可选支持入口、设置页版本状态文案、最新三语本地化 key 数、watchOS 构建与 StoreKit 本地配置验证结果，并更新 TestFlight RN 建议文案、测试重点、已知限制和发布结论。
- [2026-05-28 +0800] ITER-086 Watch 语音记账离线优先入口：Apple Watch 语音记账页从“点击输入框后选择听写”调整为主按钮“语音输入”，通过 WatchKit 系统文本输入控制器触发听写；听写完成后自动复用 `VoiceLedgerParser` 解析并进入确认保存页，解析失败时保留识别文本供用户修改后重新解析；补齐简体中文、繁体中文、英文 Watch 文案，提示未连接 iPhone 时会先暂存，继续保留 Watch 本地 pending 队列能力。
- [2026-05-27 +0800] ITER-084 设置页版本状态文案更新：设置页“当前版本”正文同步到当前 App Store v1.3.0 发布候选能力，覆盖 Apple Watch 轻量记账、快捷指令与语音记账、月报历史月份、iCloud 备份恢复、商户别名与分类批量整理；“后续计划”改为面向用户的产品路线表达，包含更多支付场景识别优化、更多专业版功能和更灵活的账单整理能力；版本号继续读取 `CFBundleShortVersionString`，不改 `MARKETING_VERSION`。

### 修复（v1.4.0）
- [2026-05-28 +0800] ITER-090 App Store 截图管线稳定性修复：截图宿主视图固定 Dynamic Type 为默认 `.large`，避免模拟器曾开启大字体后营销截图继承异常字号；Watch 截图模式跳过真实 WatchConnectivity 同步，避免最近账单 fixture 被空会话覆盖；iPhone 与 Watch 捕获脚本增加 `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryL` 启动参数，并对 mostly black raw PNG 进行最多 5 次重试，修复 `00_preview` 首帧黑屏被写入最终截图的问题；截图 README 补充黑屏与大字体排查说明；根 README 增加截图预览 HTML 入口。
- [2026-05-28 +0800] ITER-088 Support IAP 价格刷新修复：Support AutoLedger 页面价格本身未写死，使用 StoreKit `Product.displayPrice`；修复切换 App Store storefront / 沙盒商店区域后页面可能继续显示旧 `Product` 价格的问题，新增 `Storefront.updates` 监听并在 App 回到前台时强制重新拉取产品，避免 UI 价格币种与 App Store 购买弹窗不一致。
- [2026-05-26 +0800] ITER-082 商户别名新入账即时生效：新增 `MerchantAliasResolver` 统一处理商户别名解析；OCR 入账、手动新增、AddTransactionIntent、QuickLedgerIntent、VoiceLedgerIntent 与 Share Extension 均在保存前套用既有商户别名，避免新账单先保存原商户、必须手动点刷新后才替换；离线回归新增 OCR 新入账与手动新增别名生效断言。
- [2026-05-25 +0800] ITER-077 分类/商户别名批量刷新：编辑账单分类时新增确认弹窗，可选择仅保存本笔或刷新同商户所有现存账单分类；`LedgerStore.updateTransaction` 支持 `refreshSameMerchantCategory` 批量更新并写回 SQLite；设置页"商户别名"每条映射新增刷新按钮，可单独把历史账单商户名更新为对应别名；离线回归新增同商户分类刷新和单条别名刷新断言。
- [2026-05-25 +0800] ITER-076 微信拼多多先用后付详情页解析：`ReceiptParser` 在微信详情页缺少"商户全称"时，不再直接取负数金额上一行作为商户；新增附近展示商户扫描与微信 UI 噪声过滤，避免 `• 交易详情` 被误入账，并将 `拼多多` 归入购物分类；补齐既有"羊汤"餐饮分类残留；新增对应 Golden Case，`run_golden_regression.sh` 同步修复为当前 App 版解析器路径。

### 新增（v1.3.5）
- [2026-05-12 +0800] ITER-065 商户别名迁移至 SQLite + 自动学习对齐分类学习逻辑：新增 SQLite `merchant_aliases` 表，提供 `loadMerchantAliases / saveMerchantAlias / deleteMerchantAlias` 三个 API 与 `replaceForRestore` 原子还原支持；`LedgerStore` 初始化优先从 SQLite 加载，首次升级自动将 UserDefaults 旧数据迁移入库；新增 `recordMerchantAlias(original:alias:)` 写入入口（平行 `recordCategoryCorrection`），`merchantAliases` 改为 `@Published private(set)`；`learnMerchantAliasIfNeeded` 移除"必须更短"与"高置信度"两项限制，与分类学习条件完全对齐；`refreshFromStore` 与 `applyBackupBundle` 同步读写 SQLite；离线回归 28 条全部通过。
- [2026-04-29 +0800] ITER-059~064 v1.3.5 Worker API 评估 + 核心引擎批量验证：Track A — 提取 `AutoLedgerCoreKit` 纯 Foundation 独立 SwiftPM 包（7 文件），在 macOS 上独立编译通过；评估 Cloudflare Workers (swiftwasm)、Vapor + Docker、SwiftPM CLI、JS port 四个候选运行时；输出 `tools/worker/EVALUATION.md`，结论 CONDITIONAL GO（当前使用 SwiftPM CLI，待 swiftwasm Foundation 完善后重新评估），性能基准 712 样本 7.5s 完成。Track B — receiptsample 全量基线报告（712 样本）：金额命中率 100%、商户非空率 100%、高置信率 100%；分类映射从 7 组扩增到 28 组（shopping 60/groceries 27/dining 7/transport 2），非 other 分类从 14 提升到 96 条（6.6x）；修复注册号误作金额 P0、页眉/页脚商户 P0、TOTAL 跨行金额、CHANGE/CASH 误提取、商品代码行 61558/14960/20202 误作金额、全角括号注册号等故障模式；新增 5 条 Golden Case，总数 31→36 条。`bash scripts/run_offline_regression.sh`、`bash scripts/run_golden_regression.sh`、`xcodebuild` 全部通过。

### 新增（v1.3.4）
- [2026-04-29 +0800] ITER-052~058 v1.3.4 规则解析质量提升：`LedgerTextInterpreterCore` 金额提取重写为合计行优先策略，支持中文/英文/马来文 TOTAL 关键词行优先提取金额，新增 `RM` 货币前缀识别（`rmAmountRegex`）；新增公司注册号/税号行排除（`lineLooksLikeRegistrationNumber`），修复公司注册号（如 `860671-D`）被误作金额的 P0 问题。商户提取重写为非商户黑名单过滤 + 注册号/单据类型行排除，新增 `tan woon yann`/`Cash Sale`/`TAX INVOICE` 等黑名单，修复 OCR 页眉/页脚被当作商户的 P0 问题；新增 `merchantMissing` warning。分类推断新增内置商户→分类映射表（MR D.I.Y.→shopping、McDonald's→dining 等），结合 `TransactionCategory.infer` 行业关键词。新增 `tools/receipt_ocr/batch_report.swift` Markdown 报告生成工具；`scripts/run_receipt_batch_regression.sh` 支持可选报告输出。Golden Case 从 25 条扩展到 31 条，新增 6 条 core 引擎用例覆盖 RM 小票、注册号排除、TOTAL 行优先、商户黑名单、分类映射。

### 新增（v1.3.3）
- [2026-04-27 +0800] ITER-051 Sample Golden Case 扩展：`tools/receipt_ocr/golden_regression.swift` 新增 `engine` 与 `sampleTitle` 支持，可直接引用 `SampleReceiptProvider` 内置样本；`scripts/run_golden_regression.sh` 纳入 `SampleReceiptProvider`、`ReceiptParser` 与格式化依赖；`tests/golden/ledger_text_interpreter/cases.jsonl` 新增全部 20 个现有 Sample 样本，断言金额、商户、分类和来源，使现有样本解析行为进入 Golden 回归门禁。
- [2026-04-27 +0800] ITER-050 Golden Case 回归门禁：新增 `tests/golden/ledger_text_interpreter/cases.jsonl` 与 README，首批覆盖语音短句、支付宝支付文本、英文小票、非账单文本和空 OCR；新增 `tools/receipt_ocr/golden_regression.swift` 与 `scripts/run_golden_regression.sh`，按字段断言 `draftExists`、金额、商户、分类、置信度、needsReview 和 warning，失败时输出 case id 与字段级 diff；英文超市关键词 `fairprice` / `walmart` / `supermarket` 归入 groceries，保证英文纸质小票 Golden Case 不回退。
- [2026-04-27 +0800] ITER-049 v1.3.3 首轮实现：新增 `LedgerInterpretationModels`、`BillRelevanceGate` 与 `LedgerTextInterpreterCore`，提供 `InterpretInput` / `InterpretResult` / `TransactionDraft`、`nonBillImage` / `emptyOCRText` 等 warning，并支持语音短句与简单账单文本生成草稿；App 层 `LedgerTextInterpreter` 接入核心 gate，OCR 文本缺少账单信号时直接返回非账单结果，`LedgerStore` 提示“图片没有有效的账单信息，请换一张支付截图或小票照片。”并写入调试记录；新增中英文 `receipt.non_bill_image` 文案；新增 `tools/receipt_ocr/batch_ocr.swift`、`tools/receipt_ocr/batch_parse.swift`、`scripts/run_receipt_batch_regression.sh` 与工具 README，支持本地小票图片 OCR JSONL 与批量解析 smoke；离线回归新增核心 gate / nonBillImage 断言。
- [2026-04-27 +0800] ITER-048 v1.3.3 平台无关解释器核心与批量小票测试规划：新增 `versions/v1.3.3-plan.md`，承接根目录 `LedgerTextInterpreter.md` 与 v1.3.2 当前工程状态，将下一版本定位为“平台无关 `LedgerTextInterpreter` 核心 + 小票图片集批量 OCR/批量测试”；规划 `InterpretInput`、`InterpretResult`、`TransactionDraft`、`LedgerTextInterpreterCore`、App adapter、OCR 后账单相关性判断 `BillRelevanceGate`、非账单图片 `nonBillImage` warning、用户提示“图片没有有效的账单信息”、`receiptsample/` 本地图片 OCR JSONL、Golden Case JSONL、批量解析报告和字段级 diff 门禁；明确本版不提交原始测试图片、不上线 Worker API、不默认启用 LLM 批量测试。

### 新增（v1.3.2）
- [2026-04-27 +0800] ITER-047 统一文本转账单解析入口：新增 `LedgerTextInterpreter`，把 OCR 文本、订阅邮件文本、语音转文本、Siri 语音文本和账本页一句话输入收敛为统一的“文本 -> 结构化结果”解释层；`LedgerStore.importRecognizedText` 改为调用解释器处理订阅、普通账单、多商品总金额缺失和解析失败；新增 `LedgerStore.createTransaction(from:)` 作为结构化账单入库入口，语音/一句话保存也复用该入口，继续保留去重、商户别名、分类学习、调试记录、Widget 刷新和自动备份链路；新增 `versions/v1.3.2-plan.md` 并扩展离线回归覆盖解释器编译与商户别名场景。

### 新增（App Store v1.2.0 补丁）
- [2026-04-27 +0800] ITER-046 商户别名自动学习与历史账单回刷：用户编辑高置信自动入账账单时，若将较长商户名改为较短简称，自动学习 `原商户名 -> 简称` 的商户别名；商户别名新增或更新后会扫描当前账本，把完全匹配原商户名的历史账单同步更新为别名，并写回 SQLite、刷新 Widget 和触发自动备份；设置页商户别名新增/删除改为统一走 `LedgerStore` 方法；离线回归新增别名回刷和高置信编辑自动学习断言。

### 新增（v1.3.1）
- [2026-04-27 +0800] ITER-045 一句话记账交互收敛：`VoiceLedgerQuickEntryView` 的长按识别命中区收窄到圆形麦克风按钮，避免整张卡片误触；账本页 `VoiceLedgerConfirmView` 改为“一句话记账”，去掉输入/解析按钮和页内麦克风控制，用户输入文本时实时解析并填充商户、金额、分类和时间，继续复用 `VoiceLedgerParser` + `LedgerStore.addVoiceTransaction` 的文本转账本链路。
- [2026-04-27 +0800] ITER-044 首页按住语音快捷记账：新增 `VoiceLedgerQuickEntryView`，首页打开后可按住麦克风录音、松手停止并解析；高置信结果自动保存，需复核结果展示识别文本、商户、金额和分类并提供保存按钮；`VoiceSpeechRecognizer` 停止逻辑改为结束音频而非直接取消任务，减少松手丢失最后转写的风险；账本页语音按钮文案从“开始语音”调整为“输入”，重做按钮图标对比度和中英文状态文案；该快捷入口复用 `VoiceSpeechRecognizer` + `VoiceLedgerParser` + `LedgerStore.addVoiceTransaction`，为后续 Apple Watch 端长按录音入口保留服务层复用路径。
- [2026-04-27 +0800] ITER-043 App 内麦克风语音输入：保留原有文本“一句话记账”，新增 `VoiceSpeechRecognizer`，使用 Speech + AVFoundation 在 `VoiceLedgerConfirmView` 内提供开始/停止语音按钮；识别结果自动写入文本框并复用 `VoiceLedgerParser` 解析，用户仍可确认和修改后保存；主 App Info.plist build settings 新增麦克风与语音识别权限文案；补充中英文语音输入状态、权限失败和不可用提示。
- [2026-04-26 +0800] ITER-038~042 v1.3.1 语音记账实现：新增 `ReceiptSource.voice` 与 `ImageSource.voiceIntent`，语音交易可在账本、来源管理、调试记录和备份恢复链路中识别；新增 `VoiceLedgerParser`，支持金额、描述、今天/昨天/前天、基础分类推断和 high/needsReview/failed 置信度，拒绝无金额、多金额、收入、报销和转账语句；新增 `VoiceLedgerIntent` 和 Siri/AppShortcuts 语音入口，高置信语句后台直写 SQLite，复用去重、Widget 刷新、成功通知与 App 前台刷新；账本页新增 `waveform` 语音入口和 `VoiceLedgerConfirmView`，支持文本/系统听写后确认并修改商户、金额、分类、时间；补充中英文 `voice_ledger_*` 文案；离线回归新增语音解析断言；新增 `versions/v1.3.1-regression-baseline.md` 与 `versions/v1.3.1-RELEASE(draft).md`。
- [2026-04-26 +0800] ITER-037 v1.3.1 语音记账 + Siri 版本规划：新增 `versions/v1.3.1-plan.md`，承接根目录 `autoledger_voice_siri_design.md` 与现有 AppIntent / SQLite / 备份恢复工程基础，将下一版本定位为"语音记账 MVP + Siri 快捷入口"；明确本版只做"一句话 → 一笔支出"，Siri 高置信度直接保存，中低置信度失败重试，App 内入口承担确认与修改；规划 `VoiceLedgerParser`、`VoiceLedgerIntent`、语音来源标记、调试记录、本地化、备份联动、回归基线与发布门禁，并明确本版不做语音聊天、收入/转账、云端语音识别或多轮 Siri 确认。

### 新增（v1.3.0）
- [2026-04-26 +0800] ITER-031~036 v1.3.0 数据备份与恢复实现：新增 `BackupBundle` v1 与校验器，覆盖账单、最近删除、订阅、分类学习、自定义分类/来源、商户别名、订阅年付价/备注和低风险设置；`SQLiteTransactionStore` 新增备份读取与覆盖恢复接口，恢复时保留软删除状态和订阅创建时间；设置页新增 `DataManagementView`，支持 JSON 导出、系统分享、JSON 文件导入、二次确认覆盖恢复；新增 `ICloudBackupService`，写入 iCloud Drive `Documents/AutoLedgerBackup.json`，支持立即备份、自动备份开关、后台自动备份和空库启动恢复提示；主 App entitlements 增加 iCloud Documents 容器；离线回归新增 `BackupBundle` 导出/恢复断言，覆盖 SQLite + UserDefaults 混合数据。
- [2026-04-26 +0800] ITER-030 v1.3.0 版本规划：新增 `versions/v1.3.0-plan.md`，承接根目录 `autoledger_icloud_backup_design.md` 与当前工程进展，将下一版本定位为"数据备份 + 手动迁移 + iCloud 轻量恢复"；规划 `BackupBundle` v1、手动 JSON 导出/导入、iCloud 单文件自动备份、重装/换机恢复提示、冲突防护、回归基线与发布门禁，并明确本版不做 CloudKit 实时同步或静默覆盖。

### 新增（v1.2.0）
- [2026-04-23 +0800] ITER-029 回归基线 + 发布门禁：新增 `versions/v1.2.0-regression-baseline.md`，覆盖端侧 LLM、月报图表、异常消费检测、云闪付 / 银联解析、订阅管理增强、软删除持久化和 v1.1.0 继承路径；新增 `versions/v1.2.0-RELEASE(draft).md`，记录发布前检查、门禁判定、版本亮点、回滚方案和发布后观察指标；`README.md` 与 `AutoLedger/README.md` 同步更新最近删除跨会话恢复描述。ITER-028 当前暂无 TestFlight 反馈输入，未产生代码修复。
- [2026-04-23 +0800] ITER-027 软删除持久化：`SQLiteTransactionStore` 新增 `deleted_at` 安全迁移，账单删除由物理 `DELETE` 改为 `UPDATE SET deleted_at`，常规加载统一过滤 `deleted_at IS NULL`；新增 `loadDeletedTransactions(limit:)`、`restoreTransaction(id:)` 与 `permanentlyDeleteTransaction(id:)`，支持最近删除跨会话保留、恢复与彻底删除；`LedgerStore` 启动和刷新时同步加载 SQLite 最近删除列表，恢复/彻底删除操作写回 SQLite；`DeletedTransactionsView` 更新文案说明跨会话恢复；离线回归新增软删除隐藏、最近删除重启保留、恢复与彻底删除断言。
- [2026-04-23 +0800] ITER-026 订阅管理增强：`SubscriptionListView` 新增年度总览卡，展示预估年度订阅开销、月均成本与已知可优化金额；订阅卡长按菜单新增"编辑"，内嵌 `SubscriptionEditView` 支持修改商户、方案名称、周期、金额、最近扣费、下次扣费、年付价格与备注；`LedgerStore` 新增 `updateSubscription(_:)`，复用既有 SQLite `updateSubscription` 持久化核心订阅字段并重新调度扣费提醒；年付价格与备注按订阅 id 存入 UserDefaults 侧表，不改变 `subscriptions` 表结构；月付订阅填写年付价后展示"切换年付可节省 ¥X/年"建议；离线回归新增 SQLite 订阅更新断言。
- [2026-04-23 +0800] ITER-025 云闪付 / 银联解析适配：`ReceiptSource` 新增 `.unionPay`，支持按"云闪付"/"银联"/"UnionPay" + 交易详情关键词推断来源；`ReceiptParser` 新增 `parseUnionPayVoucher(lines:)`，支持"商户名称"分行与"商户名称：XXX"两种云闪付/银联交易详情版式提取商户，金额与时间沿用通用解析；`ShareViewController.bundleSourceMap` 新增云闪付 Bundle ID `com.unionpay.chsp`；`SampleReceiptProvider` 与 `OfflineRegression` 新增 2 条云闪付/银联回归样本；`run_offline_regression.sh` 补齐 v1.2.0 离线编译 stub（`LLMProvider`、`OCRTextCleaner`、`SmartResult`），离线回归恢复可运行；分类规则调整为"便利店/超市/盒马"优先于"会员"噪声，修复微信详情页被误归数字服务的问题。
- [2026-04-23 +0800] ITER-024 异常消费检测：新增 `MonthlyInsightService` 与 `AnomalyAlert`，按当前月分类支出对比过去 3 个完整月份同分类月均值；`ReportView` 在月报总览下展示"消费提醒"卡片，列出超过阈值的 TOP 异常分类；新增 `AnalysisSettingsView`，设置页"消费分析"入口支持将异常阈值在 100%～300% 间调整并持久化到 `monthlyAnomalyThresholdPercent`，默认 150%；设置页版本状态同步更新为 Phase 1 已落地。
- [2026-04-23 +0800] ITER-023 月报改版：`MonthlySnapshot` 新增自定义分类保留聚合、TOP 商户金额排行、近 6 个月月度趋势数据；`ReportView` 接入 Swift Charts，新增分类 Donut 图（支持点选分类高亮）、近 6 月趋势柱图、TOP5 商户排行和月度总览卡；`CategoryBreakdownRow` 与 `TransactionCategory+UI` 同步支持自定义分类标题与稳定配色，自定义分类不再在月报中被合并到"其他"。
- [2026-04-17 +0800] 多账单检测与用户提示（App Store 审核 2.1(a) 修复）：`ReceiptParser` 新增 `detectMultipleReceipts(text:)` 启发式检测（交易头部关键词重复 / 独立金额行多次出现），解析仍取首笔账单入账，同时在 status banner 追加 "⚠️ 图片中可能包含多笔账单" 提示引导用户裁剪。`LedgerStore`、`ShareExtension`、`QuickLedgerIntent` 三个入口均已集成。
- [2026-04-17 +0800] AI 模型识别增强开关：`AIModelSettingsView` 右上角新增 Toggle 开关（`LLMProvider.isEnhancementEnabled`，key: `llmEnhancementEnabled`）；关闭时识别链路走纯规则解析，同时自动删除已下载的 Gemma 模型文件释放存储空间，模型选择卡片置灰禁用；开启时恢复 LLM 优先 → 超时/低置信度回退规则的完整链路。`LedgerStore` 和 `QuickLedgerIntent` 均尊重该开关状态。
- [2026-04-16 +0800] Gemma 推理耗时埋点 + P50/P90 统计：`GemmaService` 新增推理耗时记录（`recordInferenceTime`），加载/推理各保留最近 30 次样本至 `UserDefaults`；新增 `percentile()` 线性插值计算，暴露 `loadTimeP50`/`loadTimeP90`/`inferenceTimeP50`/`inferenceTimeP90` 计算属性；`DebugView` "Gemma 性能统计"卡片改版——分"模型加载"和"推理"两栏，各显示最近/P50/P90 指标；移除旧 `averageLoadTimeSeconds` 属性。附带修复 `QuickLedgerIntent` Swift 6 autoclosure `await` 编译错误。

### 修复（v1.2.0）
- [2026-04-20 +0800] 快捷指令记账后账本数据不刷新：`QuickLedgerIntent` 直写 SQLite 绕过 `LedgerStore`，App 被 `openAppWhenRun` 唤起时 `scenePhase` 触发的 `refreshFromStore()` 先于 Intent 写入完成，导致账本显示旧数据。修复：① `NotificationService` 新增 `didSaveTransactionFromIntent` 通知名；② Intent 入账成功后在主线程 post 该通知；③ `AutoLedgerApp` 监听该通知并调用 `refreshFromStore()`；④ `LedgerView` 新增 `.refreshable` 下拉刷新，兜底用户手动刷新。
- [2026-04-17 +0800] QuickLedgerIntent Swift 6 actor isolation 编译错误：`ForegroundContinuableIntent` 弃用改为 `openAppWhenRun`；`intentLogger` 标记 `nonisolated(unsafe)`；`LLMProvider.isEnhancementEnabled` / `OCRTextCleaner.clean()` / `SmartReceiptParser()` / `parseWithRules()` / `NotificationService` 调用均补充 `await` actor 跳转；`&&` autoclosure 内 `await` 改为 `,` 逗号条件；`writeDebugEvent` 标记 `nonisolated`。
- [2026-04-17 +0800] 英文/国际收据解析：① `currencyPrefixPattern` 扩展支持 £/$€ 三种国际货币符号；② `actualPayKeywords` 新增 "Total"/"Grand Total"/"Amount Due"/"Balance Due"/"Subtotal" 英文关键词；③ 新增 `totalLinePattern` 专用正则，匹配 `TOTAL £8.08` / `Grand Total 12.50` 等英文小票总额行；④ `amountCandidate` 和 `isStandaloneAmount` 模式扩展 £/$€；⑤ `extractMerchant` 新增英文小票启发式——检测到 TOTAL/Subtotal 行时，跳过产品行（行尾带价格）、数量标记行（x2 @£0.95）、日期行、电话行、噪声行（receipt/card/vat/cashier 等），取第一个看起来像店名的行作为商户名，避免误将 "FRESH MILK" 等产品名当作商户。修复 Apple 审核员使用英文超市小票时金额与商户均识别错误的问题。
- [2026-04-16 +0800] Gemma 模型加载耗时统计虚高：将 `loadModelAsync()` 中的计时从主 actor 移入 `Task.detached` 内部，仅测量 `LlmInference` 初始化的真实耗时，排除主线程排队延迟；新增 `resetStats()` 方法及 DebugView "重置统计"按钮，可清除历史虚高样本。

### 新增（v1.2.0 续）
- [2026-04-16 +0800] Gemma 模型加载耗时埋点：`GemmaService` 在 `loadModelAsync()` 成功后记录耗时，最多保留最近 10 次样本至 `UserDefaults`（key: `gemmaLoadTimeSamples`），并通过 `@Observable` 属性（`lastLoadTimeSeconds`、`averageLoadTimeSeconds`、`loadCount`）实时暴露；`DebugView` 新增"Gemma 模型加载"卡片，显示当前模型状态、最近加载耗时和平均加载耗时（N 次），跟随真实加载自动刷新。
- [2026-04-16 +0800] QuickLedgerIntent 冷启动超时回退：`async let preload` + 无限 `await` 改为三路就绪策略——① 模型已在内存（`isModelReady`）立即推理；② 模型已下载但未加载时后台触发 `ensureLoaded()`（与 OCR 并行），最多等待 4 秒，超时则本次降级纯规则解析（`parseWithRules`），后台加载任务继续预热以便下次调用；③ 非 Gemma 提供方行为不变。解决快捷指令冷启动调用 AppIntent 时模型推理报错问题。
- [2026-04-16 +0800] Intent 链路修复 + 模型生命周期管理 + 设置页信息更新：① `LLMProvider.isAvailable` 对 Gemma 从检查 `isModelReady`（state == .ready）改为检查 `isModelDownloaded`（文件是否存在），修复异步加载重构后 Intent 始终走纯规则兜底的 bug；② `QuickLedgerIntent` OCR 与 `ensureLoaded()` 改为 `async let` 并行执行，模型加载时间被 OCR 覆盖；③ `GemmaService` 新增推理后自动卸载机制——`scheduleAutoUnload()` 推理结束后 120 秒无新调用则释放 `llmInference` 内存（文件保留），新调用自动取消计时器并重加载；④ `AutoLedgerApp` 启动时 `.task` 预热 Gemma（若用户已选择且已下载）；⑤ `SettingsView` 三张 infoCard 更新——当前版本 `v1.1.0-dev` → `v1.2.0-dev`，隐私策略补充 CDN 网络请求说明，版本状态更新为"端侧 LLM 已落地，推进月报/平台/订阅"；⑥ `v1.2.0-plan.md` 新增 Phase 0（端侧 LLM 集成，已完成）及 ITER-020/021/022 三轮已完成迭代记录。
- [2026-04-15 +0800] GemmaService 异步模型加载 + Extension 安全防护 + UI 布局优化：① 模型加载改为异步——`loadModel()` 拆分为同步 `loadModelSync()` 和异步 `ensureLoaded()`，`init()` 不再同步阻塞加载，改为首次 `generate()` 或进入 AI 模型页面时懒触发，消除"每次进菜单卡顿数秒"问题；② Extension 环境检测——新增 `ProcessInfo.isAppExtension`（通过 `Bundle.main.bundlePath` 后缀 `.appex` 判定），`GemmaService` 在 Extension 进程中跳过模型加载，`LLMProvider.isAvailable` 在 Extension 中对 Gemma 始终返回 false，确保 ControlWidget / ShareExtension 不因尝试加载 2.5 GB 模型而 OOM；③ `AIModelSettingsView` 模型卡片名称与状态标签从同行 HStack 拆为上下分行 VStack，避免小屏幕文字挤压换行。
- [2026-04-15 +0800] 修复 CDN 下载进度不显示的问题（两处修复）：① `DownloadProgressDelegate` 新增 `expectedBytes` 参数，当 R2 CDN 不返回 Content-Length（`totalBytesExpectedToWrite == -1`）时 fallback 到 `manifest.sizeBytes` 作为分母；② `URLSession.download(for:)` async API 的 delegate 从 session 级别改为通过 `download(for:request, delegate:)` 显式传参，确保进度回调被正确触发。
- [2026-04-15 +0800] GemmaService 切换自建 CDN + 完整性校验：下载源从 HuggingFace（需 Token）切换至 Cloudflare R2 CDN（`cdn.darkrio326.top`，无认证直连）；新增 manifest 版本检查机制（启动时拉取 `manifest.json`，对比本地版本号 + sha256，版本一致跳过下载，版本不同提示可更新）；下载完成后使用 CryptoKit SHA-256 流式校验（1 MB 分块，不全量加载内存）文件完整性；新增 `ModelManifest` 数据模型（model_id/version/backend/filename/size_bytes/sha256/download_url/min_app_version/notes）；新增 `ModelState.checkingManifest`/`.verifying`/`.updateAvailable` 状态；新增 `GemmaError.integrityCheckFailed`；`AIModelSettingsView` 移除 HF Token 输入区域，新增版本检查中/校验中/可更新/重试 UI 状态；预留 `authHeaders` 映射供后续认证扩展。
- [2026-04-15 +0800] MediaPipe LLM Inference 集成（Gemma-2 2B 端侧推理可用）：引入 CocoaPods 依赖 `MediaPipeTasksGenAI` + `MediaPipeTasksGenAIC` (v0.10.33)，新增 `Podfile`；`GemmaService` 由 placeholder 重写为真实 MediaPipe 推理：模型加载（`LlmInference.Options` + `LlmInference`）、Session 推理（`LlmInference.Session` + `generateResponseAsync` 流式收集）、HuggingFace Token 认证下载（Bearer Auth）、下载进度回调（`URLSessionDownloadDelegate`）、Bundle 内置模型支持；模型文件改为 `Gemma2-2B-IT_multi-prefill-seq_q8_ekv1280.task`（HuggingFace litert-community 托管，~2.5 GB）；`LLMProvider.displayName` 由 "Gemma-4-E2B-it" 改为 "Gemma-2 2B"；`AIModelSettingsView` 新增 HF Token 输入区域（SecureField）、下载认证流程、模型大小展示；后续 LiteRT-LM Swift SDK 就绪后升级至 Gemma-4。
- [2026-04-14 +0800] 多模型端侧 LLM 集成（Gemma + Apple Intelligence）：新增 `LLMProvider` 枚举（apple/gemma，含运行时可用性检测、UserDefaults 持久化）；新增 `GemmaService`（Gemma-4-E2B-it 模型生命周期管理：下载/加载/推理/删除，MediaPipe 集成 TODO 占位）；新增 `OCRTextCleaner`（OCR 文本预清洗——去装饰线/广告噪声/压缩空白/截断 1500 字符）；重构 `SmartReceiptParser` 为 LLM-first 流（LLM 先 → 置信度 ≥ 0.7 直接采用 → < 0.7 与规则结果合并 → 纯规则兜底），新增结构化 JSON prompt（含 merchant_name/store_branch_name/location_name/amount/expense_type/confidence/needs_user_confirmation/reason），支持 `provider` 参数多模型分发；新增 `AIModelSettingsView`（模型卡片选择、Gemma 下载进度/删除、可用性标签）；`SettingsView` 新增"AI 模型"入口；`LedgerStore.importRecognizedText` 集成 OCR 预清洗与模型选择；`ImportDebugRecord` 新增 llmProvider/llmLatencyMs/llmConfidence/usedRuleFallback 字段，SQLite 安全迁移；`QuickLedgerIntent` 同步 OCR 预清洗与多模型参数。

### 新增（v1.1.0）
- [2026-04-13 +0800] 编辑器支持自定义分类和来源：`Transaction.category` 和 `Transaction.source` 由枚举类型改为 `String`（存储 rawValue 或自定义标签），新增 `categoryEnum`/`sourceEnum`（枚举回退）及 `categoryTitle`/`sourceTitle`（显示用标题，自定义标签原样展示）计算属性；新增字符串化 init（`categoryLabel:`/`sourceLabel:`）；`SQLiteTransactionStore` 加载时不再因未知 rawValue 跳过行，bind/update 直接写字符串；`MonthlySnapshot` 改用 `\.categoryEnum` 分组（自定义分类归入"其他"）；`TransactionEditorView` 分类/来源 Picker 新增 `@EnvironmentObject var store`，在内置选项后追加 `store.customCategories` / `store.customSources`，tag 统一为 String；`LedgerView`、`DeletedTransactionsView`、`DebugView`、`FeedbackBundleBuilder` 全部更新为 `categoryEnum`/`categoryTitle`/`sourceTitle`；自定义分类/来源已由 UserDefaults 持久化（现可在分类管理和来源管理中添加，编辑账单时即时生效）。
- [2026-04-13 +0800] 修复地铁乘车记录商户名包含金额的 bug：`ReceiptParser.isStandaloneAmount` 正则新增 `CN￥`（全角 ￥ U+FFE5）前缀，原有只匹配 `CN¥`（半角 U+00A5）；天津互联互通城市卡等场景 OCR 输出 `CN￥3.60` 时，`isStandaloneAmount` 返回 `false`，导致走 (B) 路径将金额文本当作内联站名，最终商户变为 `地铁：CN￥3.60`；修复后正确识别为格式 (C)，从下一行提取站点 `滨海国际机场 张贵庄`，商户为 `地铁：滨海国际机场 → 张贵庄`。（调试来源：用户反馈，2026-04-13 导出记录，解析结果"地铁：CN￥3.60"→用户修正"地铁：滨海国际机场→张贵庄"）
- [2026-04-13 +0800] 修复微信代扣凭证（先购后付）商户误识别 bug：`ReceiptParser` 新增 `parseWeChatDeductionVoucher(lines:)` 专用方法，检测"扣费凭证"页面特征，优先从"扣费内容"标签后提取服务类型名（如"先购后付"），跳过公司名后缀行（如单独出现的"公司"），次选取"扣费凭证"上方的公司名行；同时修复 fallback 商户提取将"•五"等子弹符号 + 短字符 OCR 噪声行误判为商户名的问题，新增 `bulletShortNoisePattern`（`^[•·▪▸►▷◦‣⁃]\s*.{0,3}$`）过滤；`parse()` 商户优先链新增 `wechatDeductionMerchant`（优先级在 `taobaoFlashMerchant` 之后、`extractMerchant` 之前）。（调试来源：用户反馈，2026-04-13 导出记录，解析结果"•五"→用户修正"先购后付"）
- [2026-04-13 +0800] 修复淘宝闪购订单进行中截图商户误识别 bug：`ReceiptParser` 新增 `parseTaobaoFlashOrder(lines:)` 专用方法，检测"骑士"+"闪购"组合（淘宝即时配送订单进行中页特征），在"闪购"标签行之后搜索含中文括号"（）"的店铺名称行，去除尾部导航箭头（＞）后返回正确商户名（如"Sample Restaurant（Example Branch）"）；`parse()` 商户优先链新增 `taobaoFlashMerchant`；fallback 商户提取 skip 列表新增"外卖红包"、"骑士"、"催单"，防止外卖 UI 噪声行被误识别为商户名；新增"淘宝闪购订单进行中截图"回归样本及预期值（merchant=Sample Restaurant（Example Branch）, amount=47.4, category=dining）。
- [2026-04-12 +0800] ITER-018 账本管理三改进：① 修复已删除账单被误判为重复导入的 bug——`hasDuplicate` 的 OCR Jaccard 相似度检查现在排除已删除账单对应的 debugRecord，使用户删除后重试不再被跳过；② 新增"最近删除"功能——`LedgerStore` 新增 `deletedTransactions` 属性及 `restoreTransaction`/`permanentlyDeleteTransaction` 方法，删除的账单在本次会话内可从 `DeletedTransactionsView`（左滑恢复 / 右滑彻底删除）恢复；③ 账本右上角新增加号按钮——`LedgerView` 工具栏新增"+"按钮，打开 `TransactionEditorView`（新增模式）可手动录入商户/金额/分类/来源/时间/备注，`LedgerStore` 新增 `addTransaction` 方法持久化手动账单；`TransactionEditorView` 新增 `isNew` 参数支持"新增账单"与"编辑账单"双模式。
- [2026-04-12 +0800] 修复滴滴出行"微信支付扣费凭证"（先乘车后付款）商户误识别 bug：`ReceiptParser.parseDidiTrip` 新增 Case C，检测"滴滴" + "扣费凭证"组合，将商户正确识别为"滴滴出行"（分类自动推断为"出行"）；新增"滴滴出行微信扣费凭证截图"回归样本及预期值（merchant=滴滴出行, amount=24.90, category=transport）。
- [2026-04-12 +0800] 新增 OCR 置信度感知 + 低置信 LLM 金额验证：`OCRService` 新增 `OCRResult` 结构体（含 `minimumWordConfidence: Float`）和 `recognizeTextWithConfidence(from:)` 方法；`SmartReceiptParser.parse()` 增加 `ocrMinConfidence: Float?` 参数，当 Vision 最低单词置信度 < 0.75 时，LLM prompt 额外要求提取 `amount` 字段，若与规则金额差异 > 5% 则采用 LLM 结果；`LedgerStore.attemptClipboardImport()` 和 `QuickLedgerIntent` 两条主要 OCR 入口均已升级为 `recognizeTextWithConfidence()`；`LedgerStore.importRecognizedText()` 增加 `ocrMinConfidence` 参数。
- [2026-04-12 +0800] 修复滴滴出行结束订单页金额误识别 bug：`ReceiptParser` 新增 `extractDidiTripAmount(lines:)` 专用方法，在"费用明细"前 5 行内逆序搜索车费，避免将评价人数等页面顶部无关数字（如"71"）误识别为车费；同时处理 OCR 将"¥"误读为"4"的情形（如"¥45.00"→"445"→修正为 45.00；要求修正后金额 ≥10 元避免误伤）；重构 `parse()` 使 cleanedLines 提前构建、优先走滴滴专用提取器；新增"滴滴出行优享出租车截图"回归样本及预期值（merchant=滴滴出行, amount=45.00, category=transport）。
- [2026-04-11 +0800] 修复深色模式配色：`AppTheme` 所有基础色（canvas/card/ink/mutedInk/screenGradient）改用 `UIColor(dynamicProvider:)` 实现 Light/Dark 双套值，解决深色模式下导航标题白字黄底可读性问题及账本年月分区字体对比度不足问题。
- [2026-04-11 +0800] 修复支付宝支付成功页"回首页"按钮被误识别为商户名：`ReceiptParser` fallback 商户提取 skip 列表新增"回首页"（支付宝页面导航按钮）；fix 后"Demo Burger Restaurant"等真实商户可正常提取，分类自动命中 .dining；新增"支付宝麦当劳支付成功截图"回归样本及预期值。
- [2026-04-12 +0800] 修复滴滴出行通知截图解析 bug：`ReceiptParser.parseDidiTrip` 新增通知截图路径（"滴滴"+"已支付"→"滴滴出行"）；新增"感谢使用XXX"通用通知商户提取规则；fallback 商户提取增加运营商名（Example Carrier/中国移动/中国电信等）、日期行、"通知中心"/"请确认"过滤；新增"滴滴出行通知截图"回归样本及预期值；补齐"支付宝碰一下支付截图（7-11）"回归预期值；`run_offline_regression.sh` 更新：新增 iOS-only 类型 stubs（UIPasteboard/OCRService/NotificationService）、SmartReceiptParser stub 改为调用 ReceiptParser 实际解析、补充编译文件列表（Subscription/SubscriptionDetector/TextSimilarity）、修复 import 清理；`OfflineRegression.swift` 改为 async main 以支持 Task-based import 测试。
- [2026-04-10 +0800] ITER-017 去重增强 + 回归基线 + 发布门禁：新增 `AutoLedgerCore/Utils/TextSimilarity.swift`（字符级 bigram Jaccard 相似度函数）；`LedgerStore.hasDuplicate` 增加 `rawText` 参数，原有 60s 窗口去重基础上新增 Jaccard > 0.8 判定为重复来源（比较 debugRecords 中最近 30 条已持久化记录之 rawText）；`QuickLedgerIntent` 和 `ShareViewController` 去重逻辑同样增加 OCR Jaccard 相似度检查（通过 `loadDebugEvents()` 获取历史 rawText）；`OfflineRegression.swift` 新增 Jaccard 去重与 TextSimilarity 单元回归测试项（3 条）；新增 `v1.1.0-regression-baseline.md`（回归矩阵覆盖 9 大类场景，含去重增强/订阅/分类学习/反馈全链路），新增 `v1.1.0-RELEASE(draft).md`（发布门禁草稿，含检查项/门禁项/亮点/回滚方案）。
- [2026-04-10 +0800] ITER-016 用户反馈 C 层（服务端自动 Issue）：新增 `tools/feedback/email_to_issue.py`（Gmail IMAP 拉取未读反馈邮件 → 解析邮件标题/正文/AUTOLEDGER_FEEDBACK_META 区块 → 解压 bundle zip 提取 issue_bundle.json/summary.txt/metadata.json/trace.log/redacted_ocr_context.txt → 服务端二次正则脱敏（邮箱/手机号/长数字串）→ GitHub REST API 创建 Issue（含 label：feedback/source·email/level·Lx/type·xxx/status·new）→ feedback_id 幂等去重 → 标记邮件已读）；新增 `.github/workflows/feedback-email-to-issue.yml`（每 15 分钟定时 + 手动触发 + dry_run 开关）；新增 `tools/feedback/requirements.txt`（纯标准库，无外部依赖）；新增 `tools/feedback/test_email_to_issue.py`（本地 smoke tests）。Secret 名称：`GMAIL_USERNAME`、`GMAIL_APP_PASSWORD`、`GH_PAT_TOKEN`。
- [2026-04-10 +0800] ITER-015 用户反馈 A+B 层：新增 `FeedbackLevel`（L1/L2/L3）与 `FeedbackIssueType`（14 种问题类型）枚举；新增 `FeedbackBundleBuilder`（生成 Feedback ID、设备信息采集、分级 bundle 组装、正则脱敏、zip 压缩、邮件标题/正文生成）；新增 `FeedbackService`（MFMailComposeViewController 发送 + 剪切板复制降级 + 系统分享降级）；新增 `FeedbackComposerView`（问题类型选择、反馈级别选择、描述表单、L3 二次确认、截图附带开关）；新增 `FeedbackPreviewView`（发送前预览标题/正文/附件包内容）；`SettingsView` 新增“问题反馈”入口；`DebugView` 入口隐藏为多次点击版本号解锁；`DebugView` 内容升级：新增系统信息卡、App Group 容器文件浏览、SQLite 数据分页浏览（交易/订阅/分类学习/调试事件）、内存磁盘概况、一键导出 L3 诊断包。
- [2026-04-10 +0800] ITER-014 分类学习：新增 `category_corrections` SQLite 表（merchant PRIMARY KEY, category, updated_at）及 CRUD 方法；`TransactionCategory.infer(from:corrections:)` 支持修正历史优先查询；`LedgerStore` 新增 `categoryCorrections` Published 属性、`recordCategoryCorrection`/`deleteCategoryCorrection` 方法；`updateTransaction` 自动检测分类变更并记录修正；`persistReceipt` 两条路径均优先使用修正分类；新增 `CategoryLearningView`（已学习列表 + 空态引导 + 长按删除）；`SettingsView` 新增"分类学习"入口。
- [2026-04-10 +0800] ITER-013 扣费提醒：新增 `SubscriptionListView`（全部订阅列表 + 即将扣费高亮 + 预估月均费用 + 长按删除）；`InboxView` 新增"即将扣费"卡片（未来 7 天内有预测扣费时自动展示，含商户/金额/倒计时）；新增 `NotificationService`（`UNUserNotificationCenter` 本地通知，扣费前 1 天提醒）；`SettingsView` 新增"订阅管理"入口 + "订阅扣费提醒"开关（默认开启）；`AutoLedgerApp` 注册默认设置 + 回前台时自动调度通知；`LedgerStore` 订阅增删后自动重新调度通知；版本信息卡更新为 `v1.1.0-dev`。
- [2026-04-10 +0800] 小修改（文档）：`v1.1.0-plan.md` 同步实际进度——Phase 1（订阅识别）+ Phase 2（扣费提醒）合并为 Phase 1，Phase 编号整体前移（5→4 阶段）；ITER-012/013 状态标记为 ✅ DONE；依赖状态更新。
- [2026-04-10 +0800] ITER-012 订阅识别引擎：新增 `Subscription` 模型（`SubscriptionPeriod` 枚举 + weekly/monthly/yearly）、`SubscriptionDetector` 服务（续期邮件 OCR 高置信检测 + 历史账单周期检测）、`subscriptions` SQLite 表（CRUD）；`LedgerStore` 新增 `subscriptions` Published 属性、`upsertSubscription` 去重入库、`detectAndUpsertSubscriptions` 历史扫描、导入流高置信订阅优先路径。
- [2026-04-10 +0800] 小修改（文档）：将 `feedback_log_email_bundle_templates.md` 和 `tools_feedback_README_template.md` 从根目录移至 `process/`；同步更新 `v1.1.0-plan.md` 路径引用。
- [2026-04-10 +0800] 小修改（文档）：README `🌐 官网` 文本链接更改为与其他 badge 等宽的 shields.io badge 格式。

### 修复（TestFlight 外测就绪）
- [2026-04-10 +0800] 新增 `PrivacyInfo.xcprivacy`（声明 UserDefaults API 使用，NSPrivacyTracking=false），满足 Apple 隐私清单要求。
- [2026-04-10 +0800] 新增 `ControlWidgetExtension.entitlements`，添加 App Group（`group.top.darkrio326.AutoLedger`），使 Widget Extension 可访问共享 SQLite 数据库。
- [2026-04-10 +0800] 全部 target MARKETING_VERSION 从 `1.0` 改为 `1.0.0`，与 App Store Connect 上传版本对齐。
- [2026-04-10 +0800] 主 App Debug/Release 添加 `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`，跳过每次上传的出口合规手动确认。
- [2026-04-10 +0800] ShareExtension `TARGETED_DEVICE_FAMILY` 从 `"1,2"`（iPhone+iPad）改为 `1`（仅 iPhone），与主 App 保持一致。

### 新增
- [2026-04-10 +0800] 新增 `.douyin`（抖音团购）来源：`ReceiptSource.infer()` 检测"待使用"+"券号"/"适用门店"，自动识别抖音团购券码页；`ReceiptParser` 新增 `parseDouyinVoucher()` 从"适用门店（X家）"区块提取门店名，自动剥离"U 直播中"等直播状态前缀；`ShareViewController.bundleSourceMap` 新增抖音 Bundle ID（`com.ss.iphone.ugc.Aweme`）映射。

### 变更
- [2026-04-10 +0800] 版本号体系从 `v0.1.1` 统一调整为 `v1.0.0`（因 App Store Connect 已上传 build 1.0，版本号只能递增）；文档、标签、CHANGELOG 同步更新。
- [2026-04-10 +0800] 小修改（文档）：更新 `v1.1.0` 版本计划，新增"订阅续期邮件截图导入"能力、"自动续期高置信按订阅处理"规则与"已有订阅去重"要求。
- [2026-04-10 +0800] 小修改（文档）：IDEA-014（用户反馈：分级日志导出 + 邮件发送）通过需求评审，状态 NEW→ACCEPTED/P1，纳入 v1.1.0 Phase 4（ITER-015）；原 Phase 4 顺延为 Phase 5（ITER-016）。
- [2026-04-10 +0800] 变更（文档）：IDEA-014 整合为"用户反馈闭环"，吸收 `feedback_log_email_bundle_templates.md`（邮件/bundle 协议）和 `tools_feedback_README_template.md`（服务端 email→Issue 自动化），拆分为 A 层（App 端）+ B 层（协议）+ C 层（服务端）；ITER-015 覆盖 A+B 层，新增 ITER-016 覆盖 C 层，原 ITER-016 去重增强顺延为 ITER-017。
- [2026-04-10 +0800] 变更（文档）：Feedback ID 规则从 `AL-{yyyyMMdd}-{seq}` 改为 `AL-{vendorID_short6}-{yyyyMMddHHmmss}-{seq}`（全局唯一），服务端以此幂等去重防重复 Issue；DebugView 开发者模式内容升级为 ≥ L3（无脱敏限制，含 SQLite 浏览、OCR 全文、trace、容器概况、一键导出诊断包）。

## [v1.0.0] — 2026-04-10

### 新增
- [2026-04-10 +0800] 记账页「一键记账」引导卡片改为智能折叠：当账本中已有快捷指令入账记录时，自动收起为「一键记账已开启 · 已记录 N 笔」摘要卡，点击可展开完整操作指引。
- [2026-04-10 +0800] 新增「商户别名」设置：用户可在 设置 → 商户别名 中配置映射关系（如 广州骑安科技有限公司 → 青桔单车），解析入账时自动替换商户名并重新推断分类。
- [2026-04-10 +0800] 新增 `os_log` 日志：SmartReceiptParser（规则结果、LLM 结果/失败）和 LedgerStore（解析结果、别名映射）关键阶段输出到 Xcode Console，方便实时调试。
- [2026-04-09 24:00 +0800] 新增 `ControlWidgetExtension` Widget Extension target，包含 `ControlWidget` 注册到 iOS 控制中心；用户可在设置 → 控制中心中添加「剪切板记账」按钮。
- [2026-04-09 24:00 +0800] `ClipboardImportIntent` 迁移至 `AutoLedgerCore` 共享包（handler 模式），主 App 和 Widget Extension 共用同一 Intent 类型。
- [2026-04-09 22:00 +0800] 新增 `ClipboardImportIntent`（无参数 AppIntent，`openAppWhenRun=true`），注册为 App Shortcut「剪切板记账」，用户可将其添加到控制中心作为一键记账入口。
- [2026-04-09 22:00 +0800] App 回到前台自动读取剪切板功能（设置页开关，默认关闭）：开启后每次回到 App 自动检测剪切板是否有新截图并导入；使用 `UIPasteboard.changeCount` 防止重复导入。
- [2026-04-09 22:00 +0800] `LedgerStore` 新增 `static var shared` 和 `attemptClipboardImport(force:)` 方法，供 Intent 与自动检测共用。
- [2026-04-09 22:00 +0800] 设置页新增"回到前台自动读取剪切板"开关卡片（默认关闭）。
- [2026-04-09 22:00 +0800] 首页"一键记账"引导卡片底部新增提示：复制支付截图后回到 App 也可自动读取记账。
- [2026-04-09 16:20 +0800] 首页新增"一键记账"引导卡片（位于 Hero 区下方、支付账单导入上方）：分三步引导用户添加 iCloud 快捷指令 → 绑定 iPhone 操作按钮 → 按下即可截图记账；含 iCloud 快捷指令下载链接和跳转系统设置按钮。
- [2026-04-09 14:00 +0800] 收件箱新增"拍照识别"入口：调用系统相机拍摄支付凭证，走 OCR → 解析 → 入账完整链路；`ImageSource` 新增 `.camera` 枚举值。
- [2026-04-09 14:00 +0800] 设置页重写：新增"来源管理"和"分类管理"入口；内置来源/分类以只读列表展示，用户可新增和删除自定义来源/分类（存储在 UserDefaults）；版本信息更新为 v1.0.0 当前状态。
- [2026-04-09 14:00 +0800] `MonthlySnapshot` 新增 `topMerchants: [String]` 数组（按消费金额降序排列）；首页 Hero 区 Top 商户卡片展示最多 6 家商户，超出部分以"..."省略。
- [2026-04-09 13:52 +0800] `LedgerView` 账本列表新增时间筛选：支持"全部 / 本月 / 本年"三档切换（Segmented Picker），选月/年后可通过左右箭头翻页，禁止翻到未来月/年；Section header 动态显示当前筛选范围，footer 显示当前结果条数。
- [2026-04-09 13:52 +0800] 首页 Hero 区"Top 商户"卡仅显示消费第一名商户；点击弹出"商户消费排名"Sheet，按商户 groupby 全量账单后按总金额降序展示完整列表（含排名序号）。
- [2026-04-09 13:52 +0800] 首页 Hero 区"本月支出"卡点击后跳转到月报 Tab（Tab index 2），通过 `HomeView.$selectedTab` Binding 实现跨 Tab 导航。
- [2026-04-09 13:40 +0800] `ImportDebugRecord` 新增 `ImageSource` 枚举（`.photoLibrary` / `.shareExtension` / `.shortcutIntent` / `.clipboard` / `.unknown`）和 `imageSource` 字段，SQLite `debug_events` 表新增 `image_source` 列；所有导入入口（相册选取、Share Extension、快捷指令、剪切板）统一传递图片来源。
- [2026-04-09 13:40 +0800] `ImportDebugRecord.usedLLM` 计算属性（`llmPrompt != nil`）；`DebugView` 调试记录卡片新增 LLM 标记（"LLM" 高亮）与图片来源标签；导出文本同步包含图片来源和解析模式（LLM 智能解析 / 纯规则解析）。
- [2026-04-09 13:40 +0800] 收件箱新增"从剪切板粘贴"导入入口：读取 `UIPasteboard.general.image`，走 OCR → 解析 → 入账完整链路，统一日志记录。
- [2026-04-09 11:41 +0800] 新增 `SmartReceiptParser`：混合解析架构——规则提取金额/日期/来源 → Foundation Models（iOS 26+ 本地大模型）提取商户名与分类 → 设备不支持时自动回退纯规则解析。
- [2026-04-09 11:41 +0800] 调试记录新增 `llmPrompt` / `llmResponse` 字段，SQLite `debug_events` 表同步加列；`DebugView` 显示"模型输入/输出"卡片，导出文本包含 LLM I/O，支持回归测试存档。
- [2026-04-09 +0800] 新增 `QuickLedgerIntent`（AppIntent），支持快捷指令传入截图 → OCR → 解析 → 入账 → 返回结果文本；注册 `AppShortcutsProvider`，在快捷指令 App 中可发现"快速记账"。
- [2026-04-09 +0800] `AutoLedgerApp` 监听 `scenePhase`，App 回到前台自动从 SQLite 刷新账单（同步 Intent 后台入账记录）。
- [2026-04-09 +0800] `LedgerStore` 新增 `refreshFromStore()` 方法，支持从数据库重载全量账单。
- [2026-04-09 +0800] 账本列表支持左滑删除，协议/SQLite/LedgerStore/LedgerView 四层联动。
- [2026-04-09 +0800] 新增 App 图标（1024×1024 不透明 PNG，绿→橙渐变 + ¥ 符号 + 金色圆点）。
- [2026-04-09] 新增 `process/testflight-distribution.md`：详细说明构建上传成功后如何在 App Store Connect 中获取 TestFlight 公开邀请链接（Public Link）和指定邮件邀请方式，包含 Beta App Review 注意事项与常见问题。

### 修复
- [2026-04-10 +0800] 新增微信支付详情页「标签块→值块」解析器：OCR 输出为分列排布（当前状态/支付时间/商户全称…标签连续排列，值按相同顺序跟随），现可正确提取商户全称和支付时间；此前会误将页面标题「• 交易详情」当作商户名。
- [2026-04-10 +0800] `AppFormatters.parseFlexibleDate` 新增 `HH:mm:ss` 秒级格式支持，修复含秒的时间字符串解析失败回退为当前时间的问题；同时将 Unicode 全角空格/不间断空格等统一归一化为 ASCII 空格。
- [2026-04-10 +0800] `extractDate` 正则新增可选秒段 `(?::[0-9]{2})?`，完整捕获 `14:50:22` 而不是截断为 `14:50`。
- [2026-04-10 +0800] 去重逻辑从「同一天」缩小为「60 秒窗口」：同商户同金额但不同时间的交易不再被误判为重复（影响 LedgerStore、QuickLedgerIntent、ShareExtension 三处）。
- [2026-04-10 +0800] 支付宝 NFC 收据商户名提取修复：识别公司名称格式（XX有限公司等），跳过纯符号行；移除冗余关键词「商业有限」（已被「有限公司」覆盖）。
- [2026-04-09 23:30 +0800] 首页 Tab 名称由「收件箱」改为「记账」。
- [2026-04-09 23:30 +0800] 拍照识别按钮 tint 从 `AppTheme.accent.opacity(0.85)` 改为 `AppTheme.accent`，与其他按钮颜色统一。
- [2026-04-09 23:30 +0800] SQLite 迁移 `ALTER TABLE ADD COLUMN` 改为先查 `PRAGMA table_info` 判断列是否存在，消除重复列名错误日志。
- [2026-04-09 15:30 +0800] App 图标真机不显示（灰色占位）：主 target 缺少 `PBXResourcesBuildPhase` 导致 `Assets.xcassets` 未编译、`Assets.car` 缺失；新增 Resources build phase 并添加 `PBXFileSystemSynchronizedBuildFileExceptionSet` 排除 16 个 `README.md` 以避免产物冲突；同时生成 Light/Dark/Tinted 三套图标变体。
- [2026-04-09 13:52 +0800] 相机权限缺失导致拍照时卡住：在 pbxproj `GENERATE_INFOPLIST_FILE` 模式下为主 App target 的 Debug/Release 两个 build config 添加 `INFOPLIST_KEY_NSCameraUsageDescription`，权限弹框描述"用于拍照识别支付账单。"。
- [2026-04-09 13:25 +0800] 修复微信支付详情页收据商户名误提取为"可在支持的商户扫码退款"的问题：负数金额行（`-6.00`）优先检查上方行（微信详情页商户名在金额上方），再回退检查下方行；最终回退兜底增加平台 UI 文案过滤（"全部账单"、"可在支持的商户"、"扫码退款"、"收单机构"等）。
- [2026-04-09 13:25 +0800] 修复微信支付详情页来源误判为"手动录入"：`ReceiptSource.infer()` 增加"收单机构"、"商户单号"作为微信支付识别关键词（此类页面无"微信"二字，但有微信独有字段标签）。
- [2026-04-09 13:10 +0800] 修复 Share Extension 分享导入后，主 App 的"最近 OCR 文本"和"最近解析结果"未同步的问题：Share Extension 入账成功后将 OCR 文本和解析结果写入 App Group UserDefaults；主 App 回前台时 `refreshFromStore()` 自动读取并填充 `lastRecognizedText` / `lastParsedReceipt`，读后清除，导入链路统一。
- [2026-04-09 12:55 +0800] 修复 App Store 收据商户名误提取为"如需获取有关订阅和购买项目的帮助…"的问题：来源专用解析提前到通用前缀匹配之前，避免"项目"关键词匹配到帮助文案；新增中文订阅标记（自动续期）清洗逻辑，正确提取 "Apple Developer Program"。
- [2026-04-09 12:55 +0800] 修复通用商户前缀匹配（"商户"/"项目"/"商品"）过于宽松的问题：改为要求关键词出现在冒号之前（`label: value` 格式），防止匹配到句子中间的"项目"等词。
- [2026-04-09 12:55 +0800] 回归测试脚本 `run_offline_regression.sh` 更新：源文件路径指向 AutoLedgerCore Package；增加 SmartReceiptParser stub 以支持离线编译。
- [2026-04-09 12:53 +0800] 清理 `project.pbxproj` 中 8678 行脏引用（`swift build` 产生的 `.build/` 目录被 Xcode 文件系统同步误索引为 DTrace 脚本）；添加 `AutoLedgerCore/.gitignore` 防止复发。
- [2026-04-09 12:53 +0800] 清理 ShareExtension Compile Sources 中 28 条手动添加的旧文件引用；改为通过 `XCLocalSwiftPackageReference` 引用 `AutoLedgerCore`。
- [2026-04-09 12:53 +0800] 添加 `Transaction+Typealias.swift`，消除 `AutoLedgerCore.Transaction` 与 `StoreKit.Transaction` 的命名歧义。
- [2026-04-09 11:47 +0800] 修复快捷指令后台运行时沙箱权限不足无法读取截图的问题（`BackgroundShortcutRunner` sandbox extension 失败）：`QuickLedgerIntent` 增加 `ForegroundContinuableIntent` + `openAppWhenRun`，确保前台运行获得文件读取权限；`screenshot.data` 读取增加 `do/catch` 容错。
- [2026-04-09 11:46 +0800] 修复外卖订单金额误取红包券面值（¥3）而非实付金额（¥25）的问题：`extractAmount` 新增"实付/实际支付"关键词行优先提取，排在普通 ¥ 前缀行之前。
- [2026-04-09 11:46 +0800] 修复商户名提取到状态栏时间（如"11:42"）或纯数字行（如"974"）的问题：`extractMerchant` 末尾兜底增加时间行和纯数字行过滤；新增外卖平台"闪购/外卖"前缀行商户提取。
- [2026-04-09 11:46 +0800] 补充餐饮分类关键词：闪购、骑士、粉、米线、面、饭，提升外卖场景命中率。
- [2026-04-09 11:41 +0800] 修复 Apple 收据（如 Developer Program）来源误判为支付宝的问题：`ReceiptSource.infer()` 中 Apple/App Store 检测提升到微信/支付宝之前。
- [2026-04-09 11:41 +0800] 修复 Apple 收据商户名提取到帮助文案的问题：`ReceiptParser.extractMerchant()` 新增自动续期/订阅行匹配，优先提取 App Store 订阅商品名。
- [2026-04-09 +0800] 修复 `ReceiptParser` 金额误提取状态栏时间（如 `10:131`）、商户名提取到字段标签（如 `商户全称`）的问题；增加微信支付格式负数金额行回退策略。
- [2026-04-09 +0800] 修复快捷指令自动记账不生成调试记录的问题；`refreshFromStore()` 回前台时检测 Intent 新入账交易并补生成 debug 记录。
- [2026-04-09 +0800] 调试记录持久化到 SQLite `debug_events` 表；`QuickLedgerIntent` 每个分支（OCR 失败 / 解析失败 / 重复跳过 / 入账成功 / 入账失败）均直接写入调试记录；主 App 启动和回前台时从 SQLite 加载全量调试记录，清空操作同步删除 SQLite 数据。
- [2026-04-09 +0800] 修复 Swift 6 严格并发编译错误：为 `OCRService`、`ReceiptParser`、`Transaction`、`ImportedReceipt`、`ReceiptSource`、`TransactionCategory` 添加 `Sendable`；`SQLiteTransactionStore` 标记 `@unchecked Sendable`；`QuickLedgerIntent` 改用 `supportedContentTypes` API。
- [2026-04-09 +0800] 修复金额提取优先级：微信支付 `-XX.XX` 负数行优先 → `¥` 前缀行 → 关键词行 → 全文兜底，避免误取无关数字（如 100）。
- [2026-04-09 +0800] 修复分类推断：`dining` 优先于 `digital`，新增麦当劳/肯德基/星巴克/外卖等餐饮关键词；`digital` 移除宽泛的 `store` 匹配，改为 `app store`。

### 变更
- [2026-04-10 +0800] 移除冷启动预置样例数据（Example Supermarket/滴滴出行/Apple Services），新安装后账本为空。
- [2026-04-09 14:00 +0800] 收件箱标题"真实截图导入"改为"支付账单导入"；按钮文案"选择支付截图"改为"从相册选取"。
- [2026-04-09 14:00 +0800] `MetricCard` 金额/商户文本增加 `.lineLimit(1).minimumScaleFactor(0.4)`，大额金额（>¥100）和长商户名不再折行，自动缩小字号适应区域。
- [2026-04-09 13:40 +0800] 收件箱移除"示例导入"区域（`sampleCard` / `sampleBadgeColor` 移除），仅保留真实截图导入入口。
- [2026-04-09 12:27 +0800] 抽出 `AutoLedgerCore` 本地 Swift Package，将 Models/Enums/Services/Persistence/Utils 层共享代码迁入；主 App 和 ShareExtension（以及未来手表端）通过 `import AutoLedgerCore` 统一依赖，无需逐文件手动关联 target。
- [2026-04-09 12:27 +0800] `TransactionCategory.tint` 拆到 `Shared/Extensions/TransactionCategory+UI.swift`（SwiftUI 扩展），Core Package 保持无 UI 依赖。
- [2026-04-09 11:59 +0800] 新增 Share Extension（`ShareExtension/`）：用户在任意 App 中分享图片到 AutoLedger，自动 OCR → 解析 → 入账；通过 `sourceApplication` bundle ID 精确识别来源 App（淘宝/微信/支付宝/饿了么等）。
- [2026-04-09 11:59 +0800] SQLite 数据库路径迁移到 App Group 共享容器（`group.top.darkrio326.AutoLedger`），主 App 和 Share Extension 共享同一数据库；首次启动自动从旧 Application Support 路径迁移。
- [2026-04-09 11:59 +0800] `TransactionEditorView` 所有字段均可编辑：商户名（TextField）、来源（Picker）、时间（DatePicker）、金额、分类、备注，不再区分只读/可修正。
- [2026-04-09 11:52 +0800] `ReceiptSource` 新增 `.taobao`（淘宝/闪购）和 `.eleme`（饿了么）来源；`infer()` 中外卖/电商平台检测优先于支付渠道，避免淘宝闪购订单误判为"手动录入"。
- [2026-04-09 +0800] 收件箱首页文案改为面向用户（"随手记账，一拍即入"），移除开发说明文字。
- [2026-04-09 +0800] 截图导入备注改为"支付截图照片导入"；示例导入移至页面底部，备注改为"示例导入"。
- [2026-04-09 +0800] 示例导入不再生成调试记录，仅截图导入和 Intent 导入走调试链路。
- [2026-04-09 +0800] 最近解析列表扩展为显示最近 10 条。
- [2026-03-27 20:55 +0800] 为无真机条件新增离线回归基线，补充样例解析、SQLite 读写和 LedgerStore 导入/去重的可执行验证脚本。
- [2026-03-27 13:17 +0800] 为调试记录增加单条复制能力，允许只导出可疑样例，并将最终发布判定顺延到 `ITER-005E`。
- [2026-03-27 13:14 +0800] 为调试页增加测试记录一键拷贝能力，可直接复制当前 OCR、解析、导入和账本快照到外部回归文档，并将最终发布判定顺延到 `ITER-005D`。
- [2026-03-27 13:00 +0800] 为 Phase 4 增加真机调试与回归面板，集中展示最近 OCR 文本、解析结果、导入状态和最近账单，并将最终发布判定顺延到 `ITER-005C`。
- [2026-03-27 12:56 +0800] 将 Phase 4 收口拆分为 `ITER-005A` 与 `ITER-005B`，补齐样例解析与 SQLite 回归证据，并明确真实截图人工回归仍为发布阻断项。
- [2026-03-27 12:49 +0800] 更新 `v0.1.0` 执行状态，标记 SQLite 本地持久化与账单修正已完成，剩余工作收口到发布级人工回归与版本门禁。
- [2026-03-27 12:42 +0800] 更新 `v0.1.0` 执行状态，标记真实截图导入与 Vision OCR 已完成接入，剩余工作收口到持久化、账单修正与发布门禁。
- [2026-03-27 11:47 +0800] 重排 `v0.1.0` 执行计划，按真实工程状态拆分为已完成的 MVP 壳层与待完成的 OCR / 持久化收口阶段。
- [2026-03-27 00:00 +0800] 初始化 AutoLedger 项目文档结构，补充项目简介、想法池、版本计划、回归基线和发布门禁等文件。

### 新增
- [2026-03-27 20:55 +0800] 新增 `scripts/run_offline_regression.sh` 与 `scripts/OfflineRegression.swift`，可在本机直接运行离线回归。
- [2026-03-27 13:14 +0800] 新增调试记录导出文本与剪贴板复制入口，便于沉淀真机回归记录。
- [2026-03-27 13:17 +0800] 新增单条调试记录复制入口，支持按问题样例导出。
- [2026-03-27 13:00 +0800] 新增 `DebugView` 与导入调试记录模型，支持在真机上持续查看 OCR 原文、解析结果和入账状态。
- [2026-03-27 12:49 +0800] 新增 SQLite 本地账本仓库与账单编辑弹层，支持账单落盘和金额/分类/备注修正。
- [2026-03-27 12:42 +0800] 新增 `OCRService` 与真实截图导入链路，接入 `PhotosPicker`、Vision OCR 和 OCR 文本展示。
- [2026-03-27 11:47 +0800] 新增 iOS MVP 壳层代码：收件箱样例导入、账本列表、月报页、应用主题、规则解析器与本地内存数据流。
- [2026-03-27 00:00 +0800] 新增 `process/iteration-idea-backlog.md` 想法条目；新增 `process/iteration-log.md` 第一条迭代记录；新增 `versions/v0.1.0-plan.md`、`v0.1.0-regression-baseline.md`、`v0.1.0-RELEASE.md` 初稿。

### 修复
- [2026-03-27 20:55 +0800] 修复 SQLiteTransactionStore 仅能固定写入应用支持目录的问题，增加临时目录注入能力以支持离线回归。
- [2026-03-27 13:17 +0800] 修复调试页只能整页导出的问题，支持按单条问题记录复制。
- [2026-03-27 13:14 +0800] 修复真机回归仍需手工整理记录的问题，支持直接复制当前测试快照。
- [2026-03-27 13:00 +0800] 修复真机调试只能依赖临时界面状态的问题，把 OCR 与解析结果提升为共享调试状态并提供设置页入口。
- [2026-03-27 12:56 +0800] 修复发布门禁描述过于笼统的问题，将“已验证证据”和“剩余阻断项”按真实回归结果拆开记录。
- [2026-03-27 12:49 +0800] 修复账本仅存在内存中的问题，并同步校正文档中的迭代阶段拆分。
- [2026-03-27 12:42 +0800] 修复收件箱仅能导入样例的问题，并同步校正文档中的迭代状态。
- [2026-03-27 11:47 +0800] 修复 backlog、回归基线和发布门禁与当前工程实现不一致的问题。
- [2026-03-27 00:00 +0800] 修复模板与实际文档引用路径不一致的问题。

## [vX.Y.Z] - YYYY-MM-DD

### 变更
- [YYYY-MM-DD HH:mm +0800] 示例条目：版本发布前的文档收口说明。
