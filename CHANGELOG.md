# CHANGELOG

本文件记录 `docs/project` 维度下的文档与流程变更。

格式约定：
- 日期：`YYYY-MM-DD`
- 时间：`YYYY-MM-DD HH:mm +0800`
- 变更分类：新增 / 变更 / 修复 / 归档

## [Unreleased]

### 新增
- [2026-04-09] 新增 `process/testflight-distribution.md`：详细说明构建上传成功后如何在 App Store Connect 中获取 TestFlight 公开邀请链接（Public Link）和指定邮件邀请方式，包含 Beta App Review 注意事项与常见问题。

### 新增
- [2026-04-10 +0800] 新增「商户别名」设置：用户可在 设置 → 商户别名 中配置映射关系（如 广州骑安科技有限公司 → 青桔单车），解析入账时自动替换商户名并重新推断分类。
- [2026-04-10 +0800] 新增 `os_log` 日志：SmartReceiptParser（规则结果、LLM 结果/失败）和 LedgerStore（解析结果、别名映射）关键阶段输出到 Xcode Console，方便实时调试。
- [2026-04-09 22:00 +0800] 新增 `ClipboardImportIntent`（无参数 AppIntent，`openAppWhenRun=true`），注册为 App Shortcut「剪切板记账」，用户可将其添加到控制中心作为一键记账入口。
- [2026-04-09 24:00 +0800] 新增 `ControlWidgetExtension` Widget Extension target，包含 `ControlWidget` 注册到 iOS 控制中心；用户可在设置 → 控制中心中添加「剪切板记账」按钮。
- [2026-04-09 24:00 +0800] `ClipboardImportIntent` 迁移至 `AutoLedgerCore` 共享包（handler 模式），主 App 和 Widget Extension 共用同一 Intent 类型。

### 修复
- [2026-04-10 +0800] 新增微信支付详情页「标签块→值块」解析器：OCR 输出为分列排布（当前状态/支付时间/商户全称…标签连续排列，值按相同顺序跟随），现可正确提取商户全称和支付时间；此前会误将页面标题「• 交易详情」当作商户名。
- [2026-04-10 +0800] `AppFormatters.parseFlexibleDate` 新增 `HH:mm:ss` 秒级格式支持，修复含秒的时间字符串解析失败回退为当前时间的问题；同时将 Unicode 全角空格/不间断空格等统一归一化为 ASCII 空格。
- [2026-04-10 +0800] `extractDate` 正则新增可选秒段 `(?::[0-9]{2})?`，完整捕获 `14:50:22` 而不是截断为 `14:50`。
- [2026-04-10 +0800] 去重逻辑从「同一天」缩小为「60 秒窗口」：同商户同金额但不同时间的交易不再被误判为重复（影响 LedgerStore、QuickLedgerIntent、ShareExtension 三处）。
- [2026-04-09 23:30 +0800] 首页 Tab 名称由「收件箱」改为「记账」。
- [2026-04-09 23:30 +0800] 拍照识别按钮 tint 从 `AppTheme.accent.opacity(0.85)` 改为 `AppTheme.accent`，与其他按钮颜色统一。
- [2026-04-09 23:30 +0800] SQLite 迁移 `ALTER TABLE ADD COLUMN` 改为先查 `PRAGMA table_info` 判断列是否存在，消除重复列名错误日志。

### 新增
- [2026-04-09 22:00 +0800] App 回到前台自动读取剪切板功能（设置页开关，默认关闭）：开启后每次回到 App 自动检测剪切板是否有新截图并导入；使用 `UIPasteboard.changeCount` 防止重复导入。
- [2026-04-09 22:00 +0800] `LedgerStore` 新增 `static var shared` 和 `attemptClipboardImport(force:)` 方法，供 Intent 与自动检测共用。
- [2026-04-09 22:00 +0800] 设置页新增"回到前台自动读取剪切板"开关卡片（默认关闭）。
- [2026-04-09 22:00 +0800] 首页"一键记账"引导卡片底部新增提示：复制支付截图后回到 App 也可自动读取记账。
- [2026-04-09 16:20 +0800] 首页新增"一键记账"引导卡片（位于 Hero 区下方、支付账单导入上方）：分三步引导用户添加 iCloud 快捷指令 → 绑定 iPhone 操作按钮 → 按下即可截图记账；含 iCloud 快捷指令下载链接和跳转系统设置按钮。
- [2026-04-09 13:52 +0800] `LedgerView` 账本列表新增时间筛选：支持"全部 / 本月 / 本年"三档切换（Segmented Picker），选月/年后可通过左右箭头翻页，禁止翻到未来月/年；Section header 动态显示当前筛选范围，footer 显示当前结果条数。
- [2026-04-09 13:52 +0800] 首页 Hero 区"Top 商户"卡仅显示消费第一名商户；点击弹出"商户消费排名"Sheet，按商户 groupby 全量账单后按总金额降序展示完整列表（含排名序号）。
- [2026-04-09 13:52 +0800] 首页 Hero 区"本月支出"卡点击后跳转到月报 Tab（Tab index 2），通过 `HomeView.$selectedTab` Binding 实现跨 Tab 导航。
- [2026-04-09 14:00 +0800] 收件箱新增"拍照识别"入口：调用系统相机拍摄支付凭证，走 OCR → 解析 → 入账完整链路；`ImageSource` 新增 `.camera` 枚举值。
- [2026-04-09 14:00 +0800] 设置页重写：新增"来源管理"和"分类管理"入口；内置来源/分类以只读列表展示，用户可新增和删除自定义来源/分类（存储在 UserDefaults）；版本信息更新为 v0.1.1 当前状态。
- [2026-04-09 14:00 +0800] `MonthlySnapshot` 新增 `topMerchants: [String]` 数组（按消费金额降序排列）；首页 Hero 区 Top 商户卡片展示最多 6 家商户，超出部分以"..."省略。
- [2026-04-09 13:40 +0800] `ImportDebugRecord` 新增 `ImageSource` 枚举（`.photoLibrary` / `.shareExtension` / `.shortcutIntent` / `.clipboard` / `.unknown`）和 `imageSource` 字段，SQLite `debug_events` 表新增 `image_source` 列；所有导入入口（相册选取、Share Extension、快捷指令、剪切板）统一传递图片来源。
- [2026-04-09 13:40 +0800] `ImportDebugRecord.usedLLM` 计算属性（`llmPrompt != nil`）；`DebugView` 调试记录卡片新增 LLM 标记（"LLM" 高亮）与图片来源标签；导出文本同步包含图片来源和解析模式（LLM 智能解析 / 纯规则解析）。
- [2026-04-09 13:40 +0800] 收件箱新增"从剪切板粘贴"导入入口：读取 `UIPasteboard.general.image`，走 OCR → 解析 → 入账完整链路，统一日志记录。

### 修复
- [2026-04-09 13:52 +0800] 相机权限缺失导致拍照时卡住：在 pbxproj `GENERATE_INFOPLIST_FILE` 模式下为主 App target 的 Debug/Release 两个 build config 添加 `INFOPLIST_KEY_NSCameraUsageDescription`，权限弹框描述"用于拍照识别支付账单。"。
- [2026-04-09 15:30 +0800] App 图标真机不显示（灰色占位）：主 target 缺少 `PBXResourcesBuildPhase` 导致 `Assets.xcassets` 未编译、`Assets.car` 缺失；新增 Resources build phase 并添加 `PBXFileSystemSynchronizedBuildFileExceptionSet` 排除 16 个 `README.md` 以避免产物冲突；同时生成 Light/Dark/Tinted 三套图标变体。

### 变更
- [2026-04-09 14:00 +0800] 收件箱标题"真实截图导入"改为"支付账单导入"；按钮文案"选择支付截图"改为"从相册选取"。
- [2026-04-09 14:00 +0800] `MetricCard` 金额/商户文本增加 `.lineLimit(1).minimumScaleFactor(0.4)`，大额金额（>¥100）和长商户名不再折行，自动缩小字号适应区域。
- [2026-04-09 13:40 +0800] 收件箱移除"示例导入"区域（`sampleCard` / `sampleBadgeColor` 移除），仅保留真实截图导入入口。

- [2026-04-09 12:27 +0800] 抽出 `AutoLedgerCore` 本地 Swift Package，将 Models/Enums/Services/Persistence/Utils 层共享代码迁入；主 App 和 ShareExtension（以及未来手表端）通过 `import AutoLedgerCore` 统一依赖，无需逐文件手动关联 target。
- [2026-04-09 12:27 +0800] `TransactionCategory.tint` 拆到 `Shared/Extensions/TransactionCategory+UI.swift`（SwiftUI 扩展），Core Package 保持无 UI 依赖。
- [2026-04-09 11:59 +0800] 新增 Share Extension（`ShareExtension/`）：用户在任意 App 中分享图片到 AutoLedger，自动 OCR → 解析 → 入账；通过 `sourceApplication` bundle ID 精确识别来源 App（淘宝/微信/支付宝/饿了么等）。
- [2026-04-09 11:59 +0800] SQLite 数据库路径迁移到 App Group 共享容器（`group.top.darkrio326.AutoLedger`），主 App 和 Share Extension 共享同一数据库；首次启动自动从旧 Application Support 路径迁移。
- [2026-04-09 11:59 +0800] `TransactionEditorView` 所有字段均可编辑：商户名（TextField）、来源（Picker）、时间（DatePicker）、金额、分类、备注，不再区分只读/可修正。
- [2026-04-09 11:52 +0800] `ReceiptSource` 新增 `.taobao`（淘宝/闪购）和 `.eleme`（饿了么）来源；`infer()` 中外卖/电商平台检测优先于支付渠道，避免淘宝闪购订单误判为"手动录入"。

### 修复
- [2026-04-09 13:25 +0800] 修复微信支付详情页收据商户名误提取为"可在支持的商户扫码退款"的问题：负数金额行（`-6.00`）优先检查上方行（微信详情页商户名在金额上方），再回退检查下方行；最终回退兜底增加平台 UI 文案过滤（"全部账单"、"可在支持的商户"、"扫码退款"、"收单机构"等）。
- [2026-04-09 13:25 +0800] 修复微信支付详情页来源误判为"手动录入"：`ReceiptSource.infer()` 增加"收单机构"、"商户单号"作为微信支付识别关键词（此类页面无"微信"二字，但有微信独有字段标签）。
- [2026-04-09 13:10 +0800] 修复 Share Extension 分享导入后，主 App 的"最近 OCR 文本"和"最近解析结果"未同步的问题：Share Extension 入账成功后将 OCR 文本和解析结果写入 App Group UserDefaults；主 App 回前台时 `refreshFromStore()` 自动读取并填充 `lastRecognizedText` / `lastParsedReceipt`，读后清除，导入链路统一。
- [2026-04-09 12:55 +0800] 修复 App Store 收据商户名误提取为"如需获取有关订阅和购买项目的帮助…"的问题：来源专用解析提前到通用前缀匹配之前，避免"项目"关键词匹配到帮助文案；新增中文订阅标记（自动续期）清洗逻辑，正确提取 "Apple Developer Program"。
- [2026-04-09 12:55 +0800] 修复通用商户前缀匹配（"商户"/"项目"/"商品"）过于宽松的问题：改为要求关键词出现在冒号之前（`label: value` 格式），防止匹配到句子中间的"项目"等词。
- [2026-04-09 12:53 +0800] 清理 `project.pbxproj` 中 8678 行脏引用（`swift build` 产生的 `.build/` 目录被 Xcode 文件系统同步误索引为 DTrace 脚本）；添加 `AutoLedgerCore/.gitignore` 防止复发。
- [2026-04-09 12:53 +0800] 清理 ShareExtension Compile Sources 中 28 条手动添加的旧文件引用；改为通过 `XCLocalSwiftPackageReference` 引用 `AutoLedgerCore`。
- [2026-04-09 12:53 +0800] 添加 `Transaction+Typealias.swift`，消除 `AutoLedgerCore.Transaction` 与 `StoreKit.Transaction` 的命名歧义。
- [2026-04-09 12:55 +0800] 回归测试脚本 `run_offline_regression.sh` 更新：源文件路径指向 AutoLedgerCore Package；增加 SmartReceiptParser stub 以支持离线编译。
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

### 新增
- [2026-04-09 11:41 +0800] 新增 `SmartReceiptParser`：混合解析架构——规则提取金额/日期/来源 → Foundation Models（iOS 26+ 本地大模型）提取商户名与分类 → 设备不支持时自动回退纯规则解析。
- [2026-04-09 11:41 +0800] 调试记录新增 `llmPrompt` / `llmResponse` 字段，SQLite `debug_events` 表同步加列；`DebugView` 显示"模型输入/输出"卡片，导出文本包含 LLM I/O，支持回归测试存档。
- [2026-04-09 +0800] 新增 `QuickLedgerIntent`（AppIntent），支持快捷指令传入截图 → OCR → 解析 → 入账 → 返回结果文本；注册 `AppShortcutsProvider`，在快捷指令 App 中可发现"快速记账"。
- [2026-04-09 +0800] `AutoLedgerApp` 监听 `scenePhase`，App 回到前台自动从 SQLite 刷新账单（同步 Intent 后台入账记录）。
- [2026-04-09 +0800] `LedgerStore` 新增 `refreshFromStore()` 方法，支持从数据库重载全量账单。
- [2026-04-09 +0800] 账本列表支持左滑删除，协议/SQLite/LedgerStore/LedgerView 四层联动。
- [2026-04-09 +0800] 新增 App 图标（1024×1024 不透明 PNG，绿→橙渐变 + ¥ 符号 + 金色圆点）。

### 变更
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
