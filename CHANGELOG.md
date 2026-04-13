# CHANGELOG

本文件记录 `docs/project` 维度下的文档与流程变更。

格式约定：
- 日期：`YYYY-MM-DD`
- 时间：`YYYY-MM-DD HH:mm +0800`
- 变更分类：新增 / 变更 / 修复 / 归档

## [Unreleased]

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
- [2026-04-12 +0800] 修复滴滴出行通知截图解析 bug：`ReceiptParser.parseDidiTrip` 新增通知截图路径（"滴滴"+"已支付"→"滴滴出行"）；新增"感谢使用XXX"通用通知商户提取规则；fallback 商户提取增加运营商名（中国联通/中国移动/中国电信等）、日期行、"通知中心"/"请确认"过滤；新增"滴滴出行通知截图"回归样本及预期值；补齐"支付宝碰一下支付截图（7-11）"回归预期值；`run_offline_regression.sh` 更新：新增 iOS-only 类型 stubs（UIPasteboard/OCRService/NotificationService）、SmartReceiptParser stub 改为调用 ReceiptParser 实际解析、补充编译文件列表（Subscription/SubscriptionDetector/TextSimilarity）、修复 import 清理；`OfflineRegression.swift` 改为 async main 以支持 Task-based import 测试。
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
