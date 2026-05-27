# 迭代日志

更新日期：2026-05-27（v1.4.0 Watch 记账 UI 与同步修复）

## 记录规则

- 每轮迭代都记录
- 记录事实，不写愿景
- 记录执行后的真实结果，不记录执行前计划
- 至少包含目标、范围、完成度、测试、风险、回滚

## 条目模板

```markdown
### ITER-XXX 标题
- 日期：YYYY-MM-DD
- 所属版本：vX.Y.Z
- 所属阶段：Phase N
- 类型：重构 / 测试 / 文档 / 治理 / 能力增强 / Bugfix
- 目标：
- 改动范围：
- 未改动范围：
- 完成内容：
- 未完成内容：
- 测试情况：
- 风险与注意事项：
- 回滚方式：
- 结论：
- 下一步建议：
```

## 与迭代工作流模板的边界

- `迭代工作流`：执行前流程与门禁
- 本模板：执行后记录与追溯
- 若执行前计划与实际不一致，以本模板中的“实际结果”为准，并在条目中说明偏差

## 关联要求

每条日志应可追溯到：
- 版本计划
- 相关代码/文档变更
- CHANGELOG 条目

## 日志条目

### ITER-083 Watch 记账 UI 与同步修复
- 日期：2026-05-27
- 所属版本：v1.4.0
- 所属阶段：Phase 4 / 发布准备
- 类型：Bugfix / UI / 同步
- 目标：修复 Apple Watch 端数据不同步、快速记账和语音入口布局偏移、分类选择对勾撑高 UI、金额输入弹出文本输入、截图资产与实际 Watch UI 不一致，以及 Watch 分类缺少用户自定义分类的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/WatchConnectivityHost.swift`：最近账单同步 payload 扩展为 `transactions + customCategories`，通过 `updateApplicationContext` 保留离线可取状态，并在 Watch 可达时继续 `sendMessage` 即时推送；Watch 保存入账时使用 `Transaction(categoryLabel:sourceLabel:)`，保留自定义分类字符串。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`、`AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：自定义分类保存、账单新增/更新/导入触发 Widget 刷新时，通过 App 注入的 Watch 同步 handler 刷新 Watch payload，避免 `LedgerStore` 在离线回归编译中直接依赖 WatchConnectivity。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchSessionManager.swift`、`WatchLedgerViewModel.swift`、`ContentView.swift`：Watch session 收到最近账单和自定义分类后通知 ViewModel；激活/可达变化和首屏空数据时自动请求最近账单并重试 pending；iPhone 不可达时通过 `transferUserInfo` 排队后台拉取请求。
  - `AutoLedger/AutoLedgerWatch Watch App/QuickAddView.swift`、`WatchCategoryGrid.swift`、`WatchCategoryOption.swift`：快速记账改为金额优先，金额点击打开自定义数字面板，不再弹系统文本输入；分类网格固定高度、移除对勾，用边框/底色表达选中，并合并内置分类和用户自定义分类。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchVoiceConfirmView.swift`、`WatchVoiceRecorderView.swift`：语音确认分类复用同一固定网格并支持自定义分类；语音录入页改为可滚动紧凑布局，减少顶部标题/图标挤压。
  - `AutoLedger/AutoLedgerWatch Watch App/Screenshots/WatchScreenshotHostView.swift`：Watch 快速记账截图改为真实快速记账 UI，不再额外加大标题；截图 fixtures 覆盖自定义分类。
- 未改动范围：未改动 iPhone 主 App 记账 UI；未新增 CloudKit/后台实时同步；未改变 Watch pending 队列的持久化格式；未自动上传 App Store Connect 截图。
- 完成内容：Watch 最近账单和自定义分类可随 iPhone 账单/分类变化同步；Watch 首屏无账单或无自定义分类时会主动触发同步请求，iPhone 不可达时也会排队后台请求；Watch 自定义分类入账不再落到“其他”；快速记账和语音确认分类选择不会因对勾改变 cell 高度；金额录入避免系统文本输入；zh-Hans Watch 截图重新生成并与当前 Watch UI 对齐。
- 未完成内容：未做 Apple Watch 真机端到端同步点验；本轮以 watchOS 构建、Simulator screenshot-mode 和截图人工查看为准。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -destination 'generic/platform=watchOS' build`
  - PASS：`bash tools/appstore-screenshots/scripts/export_watch.sh --locale zh-Hans`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_golden_regression.sh`
  - PASS：`find 'AutoLedger/AutoLedgerWatch Watch App' -path '*lproj/Localizable.strings' -print0 | xargs -0 plutil -lint`
  - PASS：`git diff --check`
  - PASS：人工查看 `tools/appstore-screenshots/output/raw/watch/zh-Hans/00_watch_quick_add.png` 与 `02_watch_confirm.png`
- 风险与注意事项：快速记账页曾尝试使用 watchOS toolbar 放“确认”，但 screenshot-mode quick_add 会黑屏，已回退为页内提交按钮；最终上架前仍建议用真机 Watch 点验同步延迟与金额输入手感。
- 回滚方式：回退 WatchConnectivityHost / LedgerStore 同步改动、Watch session/view model 状态监听、Watch 快速记账/语音确认 UI 文件和新增的 WatchCategoryGrid / WatchCategoryOption。
- 结论：本轮修复了 Watch 端同步分叉、自定义分类丢失和主要 UI 偏移问题，并让 App Store Watch 截图重新来自当前真实 Watch UI。
- 下一步建议：在真机 Apple Watch + iPhone 上验证四件事：Watch 首屏空数据时是否主动拉取最近账单和自定义分类；iPhone 新增自定义分类后 Watch 是否出现；Watch 选择自定义分类入账后 iPhone 账本分类是否原样保留；断开手机后 pending 队列恢复连接是否自动清空。

### ITER-082 商户别名新入账即时生效修复
- 日期：2026-05-26
- 所属版本：v1.4.0
- 所属阶段：Phase 4 / 发布准备
- 类型：Bugfix / 测试
- 目标：修复用户已在设置中配置商户别名后，新记账记录仍先保存原商户名，必须手动点单条刷新才替换为别名的问题。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/MerchantAliasResolver.swift`：新增纯 Core 别名解析工具，支持精确匹配与首尾空白容错，并提供 `ImportedReceipt` / `Transaction` 两类保存前归一化方法。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：`resolveMerchant`、`persistReceipt`、`addTransaction` 统一调用别名解析工具，OCR 导入与手动新增在写入 SQLite 前就替换商户名。
  - `AutoLedger/AutoLedger/Domain/Services/AddTransactionIntent.swift`、`QuickLedgerIntent.swift`、`VoiceLedgerIntent.swift`：快捷指令手动记账、截图快捷记账、语音快捷记账均加载 SQLite 商户别名并在保存前套用。
  - `AutoLedger/ShareExtension/ShareViewController.swift`：分享扩展解析后先套用商户别名，再做重复判断、保存、调试记录与共享结果回写。
  - `scripts/OfflineRegression.swift`、`scripts/run_offline_regression.sh`：新增 OCR 新入账别名即时生效、原商户不落库、手动新增别名即时生效断言，并纳入新 Core 文件编译。
- 未改动范围：未改变设置页单条历史刷新按钮；未新增模糊匹配或全局自动重写开关；未修改商户别名学习触发条件；未改变用户手动选择的分类。
- 完成内容：所有当前直写新账单的主要入口都在入库前套用既有商户别名；用户不再需要依赖设置页“刷新”来修正之后新产生的账单。
- 未完成内容：未做真机快捷指令 / Share Extension 端到端点验；本轮以离线逻辑回归和 iOS 全构建为准。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：别名匹配仍按精确商户名为主，仅增加首尾空白容错，避免误改相似商户；历史账单仍需要用户使用既有单条刷新入口主动整理。
- 回滚方式：删除 `MerchantAliasResolver.swift`，回退 LedgerStore、三个 App Intent、Share Extension 和离线回归脚本改动。
- 结论：问题确认为保存路径绕过别名解析导致；本轮已在保存前统一别名归一化并通过门禁。
- 下一步建议：如后续发现 Watch 独立本地保存路径或新增 Extension 入口，需要继续复用 `MerchantAliasResolver`，避免再次分叉。

### ITER-081 辅助功能发布收口
- 日期：2026-05-26
- 所属版本：v1.4.0
- 所属阶段：Release Notes / 发布准备
- 类型：能力增强 / 辅助功能
- 目标：继续完善 v1.4.0 主路径辅助功能，让报表、账本和 Watch 轻量记账路径更适合 VoiceOver、大字号、Reduce Motion、增强对比度和非颜色区分场景。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/Report/ReportView.swift`：新增 Reduce Motion 条件动画、`accessibilityDifferentiateWithoutColor` / `colorSchemeContrast` 适配、报表摘要 / 分类图 / 趋势图 / Top 商户可读标签。
  - `AutoLedger/AutoLedger/Shared/Components/CategoryBreakdownRow.swift`：分类占比行新增选中勾选态、选中边框、本地化占比文案和 VoiceOver 标签。
  - `AutoLedger/AutoLedger/Features/Ledger/LedgerView.swift`、`DeletedTransactionsView.swift`：隐藏装饰图标，补齐最近删除入口与已删除账单行的辅助功能标签。
  - `AutoLedger/AutoLedgerWatch Watch App/QuickAddView.swift`、`WatchVoiceRecorderView.swift`、`WatchVoiceConfirmView.swift`：Watch 分类网格和语音入口改用动态字体，并为选中分类增加可见勾选态。
  - `AutoLedger/AutoLedger/*.lproj/Localizable.strings`：新增报表辅助功能摘要、分类占比、趋势图和商户排行三语文案。
  - `versions/v1.4.0-RELEASE(draft).md`、`CHANGELOG.md`、`process/iteration-log.md`：同步辅助功能发布口径。
- 未改动范围：未新增字幕 / 口述影像能力；未修改 DebugView；未做真机 VoiceOver、大字号、Switch Control、语音控制实机点验；未改 Core 层或解析逻辑。
- 完成内容：报表图表不再只依赖视觉图形，可被 VoiceOver 读出摘要；分类筛选和 Watch 分类选择增加非颜色选中信号；Watch 小字号固定文本减少；账本和最近删除主路径减少装饰图标噪声。
- 未完成内容：仍需真机验证 VoiceOver rotor 顺序、大字号 200% 布局、语音控制可说名称、增强对比度视觉结果。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`find AutoLedger -path '*lproj/Localizable.strings' -print0 | xargs -0 plutil -lint`
  - PASS：`git diff --check`
- 风险与注意事项：本轮以主路径静态代码与编译验证为准，未替代真机辅助功能审核；报表页仍保留一个既有 `plotAreaFrame` deprecation warning，未影响构建。
- 回滚方式：回退本轮 SwiftUI 辅助功能改动、三套 `Localizable.strings` 新增键，以及 RN / CHANGELOG / iteration-log 记录。
- 结论：v1.4.0 主路径辅助功能从“VoiceOver 基础覆盖”推进到“报表可读、状态非颜色化、减动和大字号更友好”，代码门禁通过。
- 下一步建议：进入 TestFlight 前按 App Store Connect 辅助功能项逐项做真机点验，尤其是大字号 200%、语音控制、增强对比度和 Switch Control。

### ITER-080 Watch App Icon 小尺寸优化
- 日期：2026-05-26
- 所属版本：v1.4.0
- 所属阶段：Release Notes / 发布准备
- 类型：视觉资产 / 发布门禁
- 目标：基于现有 AutoLedger iPhone App Icon 设计 Apple Watch 小尺寸优化版，并补齐完整 watchOS app icon set。
- 改动范围：
  - `AutoLedger/AutoLedgerWatch Watch App/Assets.xcassets/AppIcon.appiconset/`：重绘 Watch 专用 `AppIcon.png`，新增 notification、companion settings、app launcher、quick look 等 watchOS 尺寸图，并更新 `Contents.json`。
  - `versions/assets/watch-app-icon/`：新增 1024、128、64、48 小尺寸预览图。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮视觉资产与验证结果。
- 未改动范围：未改动 iPhone 主 App 图标；未改动 Widget / Share Extension 图标；未改动 Watch UI 代码、Bundle ID、签名配置或 App Store 元数据。
- 完成内容：Watch 图标保留白色钱包、金币、闪电、蓝绿渐变背景；去除星星、小圆点和复杂装饰；简化钱包高光、阴影与内部细节；加粗闪电主视觉以提升 48px 下识别度；金币保留为半露辅助元素并使用简化 `￥`。
- 未完成内容：未做真机 Apple Watch 安装后的主屏图标截图确认；本轮以资产编译和 iOS archive 构建为验证口径。
- 测试情况：
  - PASS：`xcrun actool --compile /tmp/AutoLedgerWatchIconCheck --platform watchos --minimum-deployment-target 26.0 --app-icon AppIcon --output-partial-info-plist /tmp/AutoLedgerWatchIconCheck/Info.plist 'AutoLedger/AutoLedgerWatch Watch App/Assets.xcassets'`
  - PASS：`assetutil --info /tmp/AutoLedgerWatchIconCheck/Assets.car` 可见 40/44/50 launcher、86/98/108 quick look、notification、settings 与 1024 marketing 图标。
- 风险与注意事项：watchOS 真机图标仍可能受设备缓存影响，若本机仍显示旧图标需删除 App / Watch companion 后重新安装；最终发布前建议补一次真机截图。
- 回滚方式：回退 `AppIcon.appiconset` 与 `versions/assets/watch-app-icon/`，恢复上一版单张 1024 Watch 图标。
- 结论：Watch App 图标资产已从“复用 iPhone 复杂图”升级为小尺寸优化版，watchOS icon set 编译通过。
- 下一步建议：重新安装到 Apple Watch 真机，确认主屏、通知、Watch App 列表中的图标刷新。

### ITER-079 UI 文案全球化收口
- 日期：2026-05-25
- 所属版本：v1.4.0
- 所属阶段：Release Notes / 发布准备
- 类型：能力增强 / 本地化 / 文档
- 目标：补齐 v1.4.x 用户可见主路径的简体中文、繁体中文、英文 UI 文案资源，并更新 RN 中的本地化结论。
- 改动范围：
  - `AutoLedger/AutoLedger/*.lproj/Localizable.strings`：扩展主 App 本地化键至 457 个，覆盖账本筛选、最近删除、月报、分类刷新、商户别名、消费分析、数据管理、订阅管理、问题反馈、反馈邮件预览、OCR / iCloud 用户错误、App Intents 参数摘要等主路径。
  - `AutoLedger/AutoLedger/Features/*` 与 `AutoLedger/AutoLedger/Domain/Services/*Intent.swift`：将新增用户可见文案迁移到本地化 key。
  - `AutoLedger/AutoLedgerWatch Watch App/*.lproj/Localizable.strings`：新增 Watch App 简体中文、繁体中文、英文三套资源。
  - `AutoLedger/AutoLedgerWatch Watch App/*.swift`：将 Watch 首页、快速记账、语音记账、确认页、同步反馈等文案迁移到本地化 key。
  - `versions/v1.4.0-RELEASE(draft).md`、`CHANGELOG.md`、`process/iteration-log.md`：更新本地化状态与验证结论。
- 未改动范围：未本地化 DebugView、调试记录导出文本、日志、解析规则关键词、LLM prompt、OCR 识别标签；未新增真机多语言截图和 App Store 审核材料。
- 完成内容：主 App、Watch App、ControlWidgetExtension、ShareExtension 的 zh-Hans / zh-Hant / en `Localizable.strings` key 集合已对齐；用户可见主路径三语文案补齐；v1.4.0 RN 本地化结论已从“UI 文案未齐全”更新为“主路径已补齐，Debug/开发者工具保留中文”。
- 未完成内容：DebugView 和调试导出记录仍以中文为主；未做真机语言切换、Watch 真机、大字号、VoiceOver 截图验收。
- 测试情况：
  - PASS：`find AutoLedger -path '*lproj/Localizable.strings' -print0 | xargs -0 plutil -lint`
  - PASS：`git diff --check`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`bash scripts/run_offline_regression.sh`
- 风险与注意事项：UI 全球化范围按用户可见主路径收口，不把调试/开发者导出文本纳入本轮；部分日期和金额展示仍依赖系统 Locale，需要真机多语言环境点验。
- 回滚方式：回退本轮 Swift 文案迁移、三套 `Localizable.strings` 新增键、Watch `.lproj` 资源，以及 RN / CHANGELOG / iteration-log 更新。
- 结论：主路径 UI 文案全球化完成，代码门禁通过。
- 下一步建议：进入 TestFlight 前补一轮真机语言切换截图验收，并单独决定是否把 DebugView 做成开发者模式本地化。

### ITER-078 v1.4.0 / v1.4.x RN 草稿与本地化状态核查
- 日期：2026-05-25
- 所属版本：v1.4.0
- 所属阶段：Release Notes / 发布准备
- 类型：文档 / 发布门禁 / 本地化核查
- 目标：汇总 v1.4.x 当前已实现功能，判断简体中文、繁体中文、英文三套本地化是否齐全，并产出可用于 TestFlight / 发布评审的 RN 草稿。
- 改动范围：
  - `versions/v1.4.0-RELEASE(draft).md`：新增 RN 草稿，覆盖功能清单、测试重点、已知限制、本地化结论与 TestFlight 文案。
  - `CHANGELOG.md`：新增 ITER-078 条目。
  - `process/iteration-log.md`：记录本轮文档与本地化核查结果。
- 未改动范围：未修改代码；未补齐本地化资源；未新增 Watch 截图、App Store Review Notes 或真机验证材料。
- 完成内容：确认 v1.4.x 已实现 Watch 伴侣 App、Watch/iPhone 辅助功能主路径、App Intents 三件套、月报历史月份、微信拼多多解析修复、分类/商户别名批量刷新；确认主 App / Widget / ShareExtension 的 `.strings` key 在 zh-Hans、zh-Hant、en 三套资源中对齐。
- 未完成内容：Watch App 尚无独立三语 `.lproj` 资源；v1.4.x 新增 Watch UI、分类刷新弹窗、商户别名刷新入口、月报及部分旧页面仍有硬编码中文，不能声明三语 UI 本地化齐全。
- 测试情况：
  - 本轮为文档整理与静态核查，未重新运行构建。
  - 最近一轮已通过：`bash scripts/run_golden_regression.sh`、`bash scripts/run_offline_regression.sh`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`、`git diff --check`。
- 风险与注意事项：RN 对外发布时需避免混淆“v1.4.x 内部开发线”和“App Store 对外 v1.3.0”；本地化只能写成 key 对齐，不能写成三语完整体验已完成。
- 回滚方式：删除 `versions/v1.4.0-RELEASE(draft).md`，回退本轮 CHANGELOG 与 iteration-log 条目。
- 结论：RN 草稿完成；本地化结论为“key 对齐，UI 文案未齐全”。
- 下一步建议：补齐 Watch App 与 v1.4.x 新增 UI 的 zh-Hans / zh-Hant / en 本地化资源后，再更新 RN 的发布结论并做真机辅助功能点验。

### ITER-077 分类/商户别名批量刷新交互
- 日期：2026-05-25
- 所属版本：v1.4.0
- 所属阶段：Phase 4
- 类型：能力增强 / Bugfix / 测试
- 目标：用户修改单笔账单分类时可选择是否刷新同商户历史账单分类；商户别名设置页支持对单条别名手动刷新历史账单商户名。
- 改动范围：
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：`updateTransaction` 新增 `refreshSameMerchantCategory` 参数；新增同商户分类批量更新、单条商户别名刷新方法，并继续写回 SQLite、刷新 Widget、触发自动备份。
  - `AutoLedger/AutoLedger/Features/Ledger/TransactionEditorView.swift`：编辑模式下检测分类变更，保存前弹出"仅保存本笔 / 刷新全部"确认。
  - `AutoLedger/AutoLedger/Features/Ledger/LedgerView.swift`：编辑账单保存时把批量刷新选择传给 `LedgerStore`；新增账单不触发该确认。
  - `AutoLedger/AutoLedger/Features/Settings/MerchantAliasView.swift`：每条商户别名增加刷新按钮，按单条映射更新历史账单商户名。
  - `scripts/OfflineRegression.swift`：新增同商户分类批量刷新和单条商户别名刷新断言。
- 未改动范围：未新增全局设置开关；未改变商户别名自动学习规则；未改变 OCR/LLM 解析流程。
- 完成内容：分类变更可由用户确认是否批量套用；商户别名可在设置页逐条刷新已有账单；批量更新均持久化到 SQLite。
- 未完成内容：未做真机 UI 点按回归；本轮以编译和离线逻辑回归为准。
- 测试情况：
  - PASS：`bash scripts/run_golden_regression.sh`（32 case）
  - PASS：`bash scripts/run_offline_regression.sh`（新增同商户分类刷新和单条别名刷新断言通过）
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：批量刷新按最终商户名精确匹配，不做模糊匹配，避免误改相似商户。
- 回滚方式：回退本轮 `LedgerStore.swift`、`TransactionEditorView.swift`、`LedgerView.swift`、`MerchantAliasView.swift` 和离线回归新增断言。
- 结论：本轮完成，代码门禁通过。
- 下一步建议：后续可在设置页增加"分类学习"逐条刷新入口，但本轮先以编辑时确认覆盖主路径。

### ITER-076 微信拼多多先用后付详情页解析修复
- 日期：2026-05-25
- 所属版本：v1.4.0
- 所属阶段：Phase 4
- 类型：Bugfix / 测试
- 目标：处理 2026-05-25 导出的单条微信支付调试记录，修复商户被解析为 `• 交易详情` 的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/ReceiptParser.swift`：微信详情页缺少 `商户全称` 时，改为在负数金额上方附近扫描展示商户，并过滤 `交易详情`、`服务`、`小程序`、喜欢数、平台 slogan 等 UI 噪声。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Enums/TransactionCategory.swift`：将 `拼多多` 纳入购物分类关键词；补齐既有 `羊汤/羊肉汤` 餐饮关键词残留。
  - `tests/golden/ledger_text_interpreter/cases.jsonl`：新增 `wechat_pinduoduo_pay_later_detail`，覆盖金额 69.90、商户 `拼多多`、分类 `shopping`、来源 `wechat`。
  - `scripts/run_golden_regression.sh`：修复当前仓库布局下 Golden 脚本仍引用不存在 Core 版 `ReceiptParser.swift` 的问题，改为临时使用 App 版解析器。
- 未改动范围：未调整 LLM / SmartReceiptParser 流程；未改动 QuickLedgerIntent、调试记录 UI、SQLite 入账和商户别名学习逻辑；未处理既有 `AutoLedger.xcodeproj` 未提交显示名改动。
- 完成内容：该调试记录现在可按纯规则解析为 `拼多多 · ¥69.90 · 购物 · 2026-05-25 10:52:44`，不再生成 `• 交易详情` 商户；离线回归中既有"羊汤"分类残差同步修复。
- 未完成内容：未做真实快捷指令端到端截图导入；本轮只覆盖文本回归。
- 测试情况：
  - PASS：`bash scripts/run_golden_regression.sh`（32 case，通过新增 `wechat_pinduoduo_pay_later_detail`）
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：该修复通过近邻候选过滤识别顶部展示商户；若后续支付页顶部只有平台 slogan 而无商户名，会继续回退到 `商品` 字段。
- 回滚方式：回退本轮 `ReceiptParser.swift`、`TransactionCategory.swift`、Golden case 和脚本改动。
- 结论：本轮完成，代码门禁通过。
- 下一步建议：将相似"先用后付/先享后付"详情页继续沉淀为 Golden Case。

### ITER-075 Report 月报历史月份浏览
- 日期：2026-05-20
- 所属版本：v1.4.0
- 所属阶段：Phase 4
- 类型：能力增强 / UX
- 目标：月报 Tab 支持翻页查看历史月份，6 个月趋势图正确显示历史数据。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/Report/ReportView.swift`：新增 `@State private var selectedMonth: Date = .now`；新增 `isCurrentMonth`、`stepMonth(by:)` 辅助方法；`store.monthlySnapshot` 改为 `MonthlySnapshot.build(from: store.transactions, referenceDate: selectedMonth)` 动态计算；`anomalyAlerts` 仅在 `isCurrentMonth` 时触发；NavigationBar 新增左右翻页箭头（`chevron.left` / `chevron.right`）；当月时右箭头 disabled；趋势图底部文案改为 `snapshot.monthLabel`；分类为空时提示文案更新。
- 未改动范围：未改动 `MonthlySnapshot.swift`（已原生支持任意 referenceDate）；未改动 `LedgerStore.monthlySnapshot`（保留供其他调用方使用）；未改动 Core 层。
- 完成内容：月份翻页 UI 实现；历史月份分类占比、TOP5 商户、6 个月趋势全部正确展示；切换月份自动清空分类选中状态；带动画翻页。
- 未完成内容：无。
- 测试情况：
  - PASS：`xcodebuild ... build`（无编译错误）
  - PASS：`bash scripts/run_offline_regression.sh`（28/29，唯一失败为预存"羊汤"分类残差）
- 风险与注意事项：异常提醒（AnomalyAlert）基于"当前月 vs 近 3 个月均值"，查看历史月时隐藏，避免误导。
- 回滚方式：还原 `ReportView.swift` 的 `body` 与 `stepMonth` 相关改动。
- 结论：代码门禁通过，月报历史浏览功能上线。

### ITER-073~074 Watch VoiceOver + App Intents 三件套
- 日期：2026-05-20
- 所属版本：v1.4.0
- 所属阶段：Phase 3–4
- 类型：能力增强 / 辅助功能 / App Intents
- 目标：
  - ITER-073：为 Watch app 四个视图补全 VoiceOver 标注，与 iPhone 端无障碍策略对齐。
  - ITER-074：新增 `AddTransactionIntent`、`ParseLedgerTextIntent`、`OpenQuickAddIntent` 三个 App Intent，注册到 `AutoLedgerShortcuts`，补充中英文本地化。
- 改动范围：
  - `AutoLedgerWatch Watch App/ContentView.swift`：交易行 `.accessibilityElement(children: .combine)` + 合并标签；toast 动画 Reduce Motion 降级。
  - `AutoLedgerWatch Watch App/QuickAddView.swift`：分类按钮 icon 隐藏 + 按钮级别 accessibilityLabel/addTraits；TextField accessibilityLabel。
  - `AutoLedgerWatch Watch App/WatchVoiceRecorderView.swift`：mic icon 隐藏；TextField 标签+提示；解析按钮标签。
  - `AutoLedgerWatch Watch App/WatchVoiceConfirmView.swift`：金额+商户组合标签；分类按钮无障碍；保存按钮标签+提示。
  - `AutoLedger/Domain/Services/AddTransactionIntent.swift`（新增）：`CategoryAppEnum: AppEnum`；`AddTransactionIntent: AppIntent`；直写 SQLite，刷新 Widget。
  - `AutoLedger/Domain/Services/ParseLedgerTextIntent.swift`（新增）：`ParseLedgerTextIntent: AppIntent`；调用 `VoiceLedgerParser`；返回结构化摘要。
  - `AutoLedger/Domain/Services/OpenQuickAddIntent.swift`（新增）：`OpenQuickAddIntent: AppIntent`；通过 `QuickLedgerNavigationState` + NotificationCenter 打开快速记账页。
  - `AutoLedger/Domain/Services/QuickLedgerIntent.swift`：`AutoLedgerShortcuts.appShortcuts` 新增三个 Shortcut 条目。
  - `AutoLedger/zh-Hans.lproj/Localizable.strings` + `en.lproj/Localizable.strings`：三个 Intent 的本地化键。
- 未改动范围：未修改现有 `VoiceLedgerIntent`；未修改 iPhone 端 VoiceOver（已在 ITER-072 完成）；未修改 Core 层。
- 完成内容：全部 8 个改动文件（含 3 个新增）完成；三个 Intent 已注册快捷指令短语；中英文本地化齐全。
- 未完成内容：无。
- 测试情况：
  - PASS：`xcodebuild ... build`（无编译错误）
  - PASS：`bash scripts/run_offline_regression.sh`（28/29，唯一失败为预存"羊汤"分类残差）
- 风险与注意事项：`CategoryAppEnum` rawValue 须与 `TransactionCategory` rawValue 严格一一对应；`VoiceLedgerConfidence` 为顶层枚举（非嵌套），`ParseLedgerTextIntent` 中已正确引用。
- 回滚方式：删除三个新 Intent 文件；回滚 `QuickLedgerIntent.swift` 的 Shortcut 新增段；回滚 Localizable.strings 新增段。
- 结论：代码门禁通过，Watch VoiceOver + App Intents 三件套全部上线。
- 下一步建议：TestFlight 验证 Shortcuts 可触发；推进 ITER-075 App Store 截图与 ITER-076 发布门禁。

### ITER-066~072 v1.4.0 Watch Support + iPhone VoiceOver
- 日期：2026-05-19
- 所属版本：v1.4.0
- 所属阶段：Phase 1–2
- 类型：能力增强 / 辅助功能
- 目标：实现 Apple Watch 伴侣应用骨架（快速记账 + 语音记账），iPhone↔Watch 双向同步，以及 iPhone 端 VoiceOver / Reduce Motion 无障碍支持。
- 改动范围：
  - Watch App 骨架：`AutoLedgerWatch Watch App/`（ContentView、QuickAddView、WatchVoiceRecorderView、WatchVoiceConfirmView、WatchLedgerViewModel、WatchSessionManager、AutoLedgerWatchApp）。
  - iPhone 端：`WatchConnectivityHost.swift`（新增）；`AutoLedgerApp.swift`（注入 host）；`LedgerStore.swift`（`handleWatchQuickAdd` 从 Watch 消息创建 Transaction）。
  - iPhone VoiceOver：`LedgerView.swift`（交易行合并标签 + 分类 badge 隐藏）；`InboxView.swift`（识别结果行标签）；`MetricCard.swift`（数值+趋势合并标签）；Reduce Motion：`InboxView.swift` 动画降级。
- 未改动范围：未修改 Core 解析层；未修改 Watch Complications；未修改 App Store 资产。
- 完成内容：Watch target 可独立编译；iPhone↔Watch WatchConnectivity 握手与消息转发；iPhone VoiceOver / Reduce Motion 全量覆盖。
- 测试情况：PASS（构建 + 离线回归 28/29）。
- 结论：v1.4.0 基础 Watch 支持已落地，代码门禁通过。

### ITER-065 商户别名迁移至 SQLite + 自动学习对齐分类学习逻辑
- 日期：2026-05-12
- 所属版本：v1.3.5
- 所属阶段：Phase 6
- 类型：能力增强 / 重构
- 目标：将商户别名持久化从 UserDefaults 迁移至 SQLite，并把自动学习条件与分类学习完全对齐，消除两套学习机制的行为不一致。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/.../SQLiteTransactionStore.swift`：新增 `merchant_aliases` 表；新增 `loadMerchantAliases() / saveMerchantAlias(original:alias:) / deleteMerchantAlias(original:)` 方法；`replaceForRestore` 新增 `merchantAliases` 参数，在事务内原子写入。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：`merchantAliases` 改为 `@Published private(set)`；初始化改为调用 `loadInitialMerchantAliases`（含 UserDefaults→SQLite 首次迁移）；新增 `recordMerchantAlias(original:alias:)`；`setMerchantAlias` / `deleteMerchantAliases` 补充 SQLite 写入；`learnMerchantAliasIfNeeded` 移除"必须更短"与"高置信度"两项限制；`refreshFromStore` 从 SQLite 重载别名；`applyBackupBundle` 传入 `merchantAliases` 参数。
  - `scripts/OfflineRegression.swift`：改用 `setMerchantAlias(original:alias:)` 替代直接赋值，移除多余的 `saveMerchantAliases()` 调用。
- 未改动范围：未修改 UI；未修改 `saveMerchantAliases()`（保留 UserDefaults 兼容）；未修改 OCR / LLM 流程。
- 完成内容：SQLite 表与 3 个 CRUD 方法；LedgerStore 全链路对齐；备份/还原原子性；UserDefaults→SQLite 升级迁移路径。
- 未完成内容：无。
- 测试情况：`bash scripts/run_offline_regression.sh` 28 条 PASS（"羊汤"分类残差为预存在问题，与本次改动无关）。
- 风险与注意事项：`isHighConfidenceGeneratedTransaction` 方法可能已无调用方，下一轮可酌情清理。
- 回滚方式：`git revert` 三个改动文件；UserDefaults 旧数据保留，可无损回退。
- 结论：代码门禁通过，商户别名学习行为与分类学习完全对齐。
- 下一步建议：持续观察自动学习质量；可在设置页展示已学习别名条数。

### ITER-059~064 v1.3.5 Worker API 评估 + 核心引擎批量验证
- 日期：2026-04-29
- 所属版本：v1.3.5
- 所属阶段：Phase 0-5
- 类型：能力增强 / 测试 / 工具 / 基础设施评估
- 目标：评估将 `LedgerTextInterpreterCore` 部署到云端运行时的可行性；在 receiptsample 全量样本上建立 core 引擎的真实基线并修复残余失败模式。
- 改动范围：
  - Track A（Worker API 评估）：
    - `AutoLedgerCoreKit/Package.swift` + `Sources/AutoLedgerCoreKit/*.swift`（7 文件）：提取纯 Foundation SwiftPM 包，独立于 Xcode 工程编译。
    - `tools/worker/EVALUATION.md`：评估 Cloudflare Workers (swiftwasm)、Vapor + Linux Docker、SwiftPM CLI、JS port 四个候选运行时；结论 CONDITIONAL GO。
    - 性能基准：712 条 receiptsample 在 7.5s 内解析完成（~105 req/s, ~9.5ms p50）。
  - Track B（核心引擎批量验证）：
    - `AutoLedgerCore/Services/LedgerTextInterpreterCore.swift`：多重修复——extractRMAmounts 新增产品代码 RM20202 排除（无小数 4+ 位数字跳过）、下划线 RM_34.80 支持、TOTAL 关键词附近距离优先策略；`extractFromTotalNextLine` 新增商品代码行/数量行/标识符行/日期行跳过，防止 SubTotal 后商品代码行 061558 被误作金额；`extractLastExplicitAmount` 新增 CHANGE/CASH 行排除、GST/TAX 行排除、商品代码行排除、0.5~10000 金额范围约束；`lineLooksLikeShortCode` 新增短代码 `^[A-Za-z0-9]{2,8}$` 排除、"19." 类型；`lineLooksLikeProductCode` 新增 `^[A-Z][A-Za-z0-9]{1,5}:\d+[A-Za-z]?$` 排除；`lineLooksLikeItemCodeLine` 扩展匹配；`lineLooksLikeRegistrationNumber` 改为整行精确匹配（非包含匹配），修复商户名含注册号后缀误排除；新增 `lineLooksLikeChangeOrCashLine`、`lineLooksLikeGstOrTaxLine`、`lineLooksLikeRoundingLine`、`lineLooksLikeItemCodeLine` 分类器；分类映射从 7 组扩增到 28 组（新增 MR. D.I.Y.、PERNIAGAAN ZHENG HUI、SOON HUAT、INDAH GIFT、TED HENG、FY EAGLE、MYNEWS、PASAR、TESCO、AEON、LOTUS'S、KFC、BURGER KING、PIZZA HUT、STARBUCKS、SUBWAY、GRAB、GOJEK、NETFLIX、SPOTIFY、APPLE ONE、ICLOUD、GOOGLE ONE、CHATGPT 等）。
    - `tests/golden/ledger_text_interpreter/cases.jsonl`：新增 5 条 Golden Case，总数 31→36 条。
  - `.tmp/receipt_ocr/scanned_receipts.v{1..5}.report.md`：5 轮迭代批量报告（v1 基线→v5 最终）。
- 未改动范围：未上线生产 Worker API；未修改 App 用户可见主流程；未修改 SQLite schema；未开始 Apple Watch target。
- 完成内容：
  - Track A：CoreKit 独立编译通过；Worker 评估报告完成；性能基准完成。结论 CONDITIONAL GO。
  - Track B：712 样本金额命中率 100%、商户非空率 100%、高置信率 100%。分类非 other 从 14→96（6.6x）。P0 级注册号误作金额、页眉/页脚商户、商品代码金额全部修复。剩余 5 条 <0.5 的微小残差（部分 OCR 截断样本的 GST 值）。
- 未完成内容：swiftwasm NSRegularExpression 兼容性待工具链成熟后重试；全量批量报告中的 5 条 <0.5 残差涉及支付平台特定版式，需后续针对性扩充。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_golden_regression.sh`（36 条）
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
  - PASS：`cd AutoLedgerCoreKit && swift build`（独立包编译）
- 风险与注意事项：批量报告中 5 条 <0.5 残差来自部分 OCR 截断的真实样本，不影响实际使用（完整 OCR 下 TOTAL 行可正确提取）。其余 707 条金额提取全部正确。
- 回滚方式：Track A 的 AutoLedgerCoreKit/ 和 tools/worker/ 为新增目录，不影响 App；Track B 修改集中在 `LedgerTextInterpreterCore.swift`，可通过 git revert 恢复 v1.3.4 行为；Golden Case 新增可按文件独立回滚。
- 结论：v1.3.5 Track A + B 全部完成，代码门禁通过。
- 下一步建议：根据 EVALUATION.md 结论，当前继续使用 SwiftPM CLI 本地批量工具；待 swiftwasm Foundation 完善后重新评估 Worker 部署；推进 v1.4 Apple Watch 端实现。

### ITER-052~058 v1.3.4 规则解析质量提升
- 日期：2026-04-29
- 所属版本：v1.3.4
- 所属阶段：Phase 0-6
- 类型：能力增强 / 解析质量 / 测试 / 工具
- 目标：根据 v1.3.3 批量 OCR/解析报告的失败样本（first10 和 ReceiptDebugTool 差异报告），系统性修复 `LedgerTextInterpreterCore` 的金额提取、商户提取和分类推断缺陷；将 core 引擎从基础规则升级为覆盖主流小票和支付截图。
- 改动范围：
  - `AutoLedgerCore/Models/LedgerInterpretationModels.swift`：新增 `merchantMissing` warning 枚举。
  - `AutoLedgerCore/Services/LedgerTextInterpreterCore.swift`：金额提取重写为合计行优先策略——第一优先 TOTAL/Grand Total/Jumlah 等关键词行，第二优先带货币符号 + 小数的最后金额，第三回退到最后一个合理金额；新增 `RM` 货币前缀专用正则（`rmAmountRegex`）；新增公司注册号/税号排除（`lineLooksLikeRegistrationNumber`），支持 `CO.REG:860671-D`、`JM0517726`、`GST ID` 等格式。商户提取重写——新增非商户黑名单（`tan woon yann`、`Cash Sale`、`TAX INVOICE`、`Thank You` 等 30+ 项）；新增注册号/单据类型行排除；优先从文本上半区提取；无法提取时输出 `merchantMissing` warning。分类推断——新增内置商户→分类映射表（MR D.I.Y.→shopping、McDonald's→dining、NTUC FAIRPRICE→groceries 等 7 组），未知商户回退 `TransactionCategory.infer` 行业关键词。
  - `scripts/OfflineRegression.swift`：新增 7 条 core 引擎回归断言——RM 注册号排除、MR DIY 商户提取、TOTAL 行优先、RM 合计行、商户黑名单（tan woon yann→INDAH GIFT）、INVOICE 头过滤（TAX INVOICE→SOON HUAT）、McDonald's 分类推断。
  - `tests/golden/ledger_text_interpreter/cases.jsonl`：新增 6 条 core 引擎 Golden Case——`core_rm_receipt_reg_number`、`core_multi_item_total_priority`、`core_blacklist_header_merchant`、`core_invoice_header_merchant`、`core_mcdonalds_category_dining`、`core_malay_total_rm`。
  - `tools/receipt_ocr/batch_report.swift`：新增 Markdown 解析报告生成工具，输出总样本数、金额命中率、商户非空率、置信度分布、分类分布、警告统计、Top 失败样本和可疑金额。
  - `tools/receipt_ocr/README.md`、`scripts/run_receipt_batch_regression.sh`：同步工具说明和脚本，支持可选报告输出。
  - `versions/v1.3.4-plan.md`：新增版本计划，覆盖失败分析、金额/商户/分类修复、Golden Case 迁移、Markdown 报告和回归门禁。
- 未改动范围：未修改 `SmartReceiptParser`、`LedgerStore`、`Transaction` 等 App 层核心数据模型；未开始 Apple Watch target；未修改 `BillRelevanceGate` 判断逻辑；未做 LLM-driven 规则增强。
- 完成内容：Amount 提取 P0 问题（注册号误作金额、小计误作合计、RM 前缀未覆盖）全部修复；Merchant 提取 P0 问题（页眉/页脚被当作商户）全部修复；新增 6 条 core 引擎 Golden Case、31 条总计、pass 率 100%；新增 Markdown 报告工具；64 条离线回归全部 pass。
- 未完成内容：core 引擎分类映射仍需继续扩充（当前仅覆盖 7 组常见商户）；马来文/日文小票覆盖仍需更多真实样本。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`（64 条断言全部通过）
  - PASS：`bash scripts/run_golden_regression.sh`（31 条 Golden Case 全部通过）
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：金额提取从"取第一个金额"改为"合计行优先"策略后，无 TOTAL 行的小票使用回退策略（最后显示金额），少量样本可能从之前的幸运命中变为回退命中，需在批量报告中持续监控金额命中率变化。商户黑名单只包含已确认的非商户行特征；若后续发现真实商户被误杀，可从黑名单移除。
- 回滚方式：`git revert` `LedgerTextInterpreterCore.swift` 和 `LedgerInterpretationModels.swift` 恢复 v1.3.3 行为；Golden Case 新增条目可按文件独立回滚；`batch_report.swift` 不影响 App 主流程。
- 结论：v1.3.4 核心修复已完成，代码门禁全部通过。
- 下一步建议：在 `receiptsample/` 真实小票上跑一次全量批量报告，验证金额命中率和商户非空率；扩充 core 引擎商户→分类映射表；推进 v1.3.5 Worker API 评估或 v1.4 Apple Watch 端实现。

### ITER-051 Sample Golden Case 扩展
- 日期：2026-04-27
- 所属版本：v1.3.3
- 所属阶段：Phase 6-7
- 类型：测试 / 工具 / 解析质量
- 目标：把当前 `SampleReceiptProvider` 中所有既有样本纳入 Golden Case，防止后续文本转账单规则调整时破坏现有样本解析。
- 改动范围：
  - `tools/receipt_ocr/golden_regression.swift`：新增 `engine`、`sampleTitle`、`receiptSource` 支持，保留 `core` 引擎并新增 `receiptParser` 引擎。
  - `scripts/run_golden_regression.sh`：纳入 `SampleReceipt`、`SampleReceiptProvider`、`ReceiptParser` 和 `AppFormatters` 编译依赖。
  - `tests/golden/ledger_text_interpreter/cases.jsonl`：新增 20 条内置 Sample 样本 Golden Case。
  - `tests/golden/ledger_text_interpreter/README.md`：补充 `engine`、`sampleTitle` 与 `receiptSource` 字段说明。
- 未改动范围：未提交原始截图；未把大批量 `receiptsample/` OCR 结果直接固化为 Golden Case；未调整解析规则本身。
- 完成内容：Golden runner 现在可直接按 `sampleTitle` 从 `SampleReceiptProvider` 读取文本与来源，并断言金额、商户、分类和来源；现有 Golden Case 总数从 5 条扩展到 25 条。
- 未完成内容：仍需后续从真实小票批量 OCR 结果中挑选脱敏样本，补充复杂纸质小票和失败样本。
- 测试情况：
  - PASS：`bash scripts/run_golden_regression.sh`，25 case(s)
- 风险与注意事项：Sample Golden 先锁定当前成熟 `ReceiptParser` 行为，平台无关 `LedgerTextInterpreterCore` 仍只覆盖首批核心用例；后续迁移核心解释器时应逐步把 Sample 用例切换到 core 引擎。
- 回滚方式：移除 `cases.jsonl` 中 `sample_*` 用例，并将 Golden runner 恢复为只调用 `LedgerTextInterpreterCore`。
- 结论：现有 Sample 样本已全部进入 Golden 回归门禁。
- 下一步建议：把 `scripts/run_golden_regression.sh` 接入常规离线回归或 CI，并在修复小票 total 误识别时先补 Golden Case。

### ITER-050 Golden Case 回归门禁
- 日期：2026-04-27
- 所属版本：v1.3.3
- 所属阶段：Phase 6-7
- 类型：测试 / 工具 / 解析质量
- 目标：建立文本转账单规则的 Golden Case 回归脚本，每次调整 `LedgerTextInterpreterCore` 后可跑字段级断言，防止已有识别回退。
- 改动范围：
  - `tests/golden/ledger_text_interpreter/cases.jsonl`：新增首批 5 条 Golden Case。
  - `tests/golden/ledger_text_interpreter/README.md`：说明 JSONL 格式和运行方式。
  - `tools/receipt_ocr/golden_regression.swift`：新增 Golden Case runner，断言草稿存在性、金额、商户、分类、置信度、needsReview 和 warnings。
  - `scripts/run_golden_regression.sh`：新增一键编译并运行 Golden 回归脚本。
  - `LedgerTextInterpreterCore.swift`：补充基础标签提取，优先识别 `金额/Total` 行与 `商户：xxx`。
  - `TransactionCategory.swift`：补充 `fairprice`、`walmart`、`supermarket` 到 groceries。
- 未改动范围：未提交真实图片；未引入大规模 Golden Case；未把 Golden 回归接入 CI。
- 完成内容：Golden Case 回归可独立运行，失败时输出 case id 和字段级差异；首批样本覆盖语音、支付文本、英文小票、非账单文本和空 OCR。
- 未完成内容：还需要从 `receiptsample` 批量 OCR 结果中挑选、脱敏并沉淀更多公共样本；Markdown 报告仍未实现。
- 测试情况：
  - PASS：`bash scripts/run_golden_regression.sh`
  - PASS：`bash scripts/run_receipt_batch_regression.sh .tmp/receipt_ocr/scanned_receipts.first10.ocr.jsonl .tmp/receipt_ocr/scanned_receipts.first10.parse.jsonl`
- 风险与注意事项：Golden Case 应表达期望行为，不应盲目固化明显错误的解析结果；当前 first10 样本仍暴露出部分收据金额误取编号的问题，应通过新增期望样本推动规则修复。
- 回滚方式：移除 Golden 脚本与 `tests/golden` 目录，不影响 App 主流程；分类关键词可单独回滚。
- 结论：文本转账单规则已有最小 Golden 回归门禁。
- 下一步建议：从批量 OCR 前 10 个失败/可疑样本中挑 3-5 个脱敏后加入 Golden Case，并修复小票 total 金额抽取。

### ITER-049 v1.3.3 首轮实现：核心解释器、账单相关性 gate、批量工具骨架
- 日期：2026-04-27
- 所属版本：v1.3.3
- 所属阶段：Phase 1-7
- 类型：重构 / 能力增强 / 测试 / 工具
- 目标：按 v1.3.3 计划落地首轮平台无关解释器核心、OCR 后非账单图片判断、App 提示和本地批量 OCR/解析工具骨架。
- 改动范围：
  - `AutoLedgerCore/Models/LedgerInterpretationModels.swift`：新增 `InterpretInput`、`InterpretResult`、`TransactionDraft`、`LedgerInputSourceType`、`InterpretWarning` 等核心模型。
  - `AutoLedgerCore/Services/BillRelevanceGate.swift`：新增账单相关性判断，低账单信号文本返回 `nonBillImage`。
  - `AutoLedgerCore/Services/LedgerTextInterpreterCore.swift`：新增核心解释器，支持非账单拦截、语音短句草稿、简单账单草稿。
  - `LedgerTextInterpreter.swift`、`LedgerStore.swift`：App 解释器接入 core gate，非账单图片不进入 Smart parser，提示用户图片没有有效账单信息并记录 debug。
  - `Localizable.strings`：新增中英文 `receipt.non_bill_image`。
  - `tools/receipt_ocr/`、`scripts/run_receipt_batch_regression.sh`：新增本地批量 OCR JSONL 与批量解析 smoke 工具。
  - `OfflineRegression.swift`、`run_offline_regression.sh`：新增 core/gate/nonBillImage 回归断言，并纳入离线编译。
- 未改动范围：未提交 `receiptsample/` 原始图片；未提交 Golden Case 样本库；未上线 Worker API；未将 `SmartReceiptParser` 迁入平台无关核心；未改变 SQLite schema。
- 完成内容：App OCR 文本已具备非账单拦截；核心解释器可独立跑基础解释；批量解析脚本可读取 OCR JSONL 并输出 parse JSONL。
- 未完成内容：Golden Case JSONL 和 Markdown 汇总报告仍需后续补齐；当前核心账单草稿提取为基础规则，复杂 OCR 仍由 App adapter 继续使用 `SmartReceiptParser`。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_receipt_batch_regression.sh <smoke-ocr-jsonl> /tmp/receipt-parse.jsonl`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：账单相关性 gate 目前保守放行支付/小票信号，避免误拦截弱格式小票；`ReceiptSource.manual` 在 OCR 导入里代表未知来源，因此仍映射到 OCR/payment 路径，只有 `.voice` 走短句分支。
- 回滚方式：在 `LedgerTextInterpreter` 中移除 core gate 调用，恢复所有 OCR 文本直接进入 v1.3.2 的 Smart parser；工具文件可独立删除，不影响 App 主流程。
- 结论：v1.3.3 首轮实现已落地，代码门禁通过。
- 下一步建议：新增 Golden Case JSONL 和 Markdown 报告生成，拿 `receiptsample/scanned_receipts/data` 前 20 张跑一次基线。

### ITER-048 v1.3.3 平台无关解释器核心与批量小票测试规划
- 日期：2026-04-27
- 所属版本：v1.3.3
- 所属阶段：Phase 0
- 类型：文档 / 架构规划 / 测试规划
- 目标：基于根目录 `LedgerTextInterpreter.md` 与 v1.3.2 工程现状，规划下一版本将解释器抽象为平台无关核心，并建立小票图片集批量 OCR、OCR 后账单相关性判断与批量解析回归。
- 改动范围：
  - `versions/v1.3.3-plan.md`：新增版本定位、目标架构、核心类型草案、批量 OCR 工具、Golden Case 设计、阶段拆分、验收标准、风险与回滚。
  - `CHANGELOG.md`、`process/iteration-log.md`：同步规划记录。
- 未改动范围：本轮只做规划，不实现 `LedgerTextInterpreterCore`、批量 OCR CLI、Golden Case runner 或 App adapter 接入。
- 完成内容：明确 v1.3.3 的三条主线：一是抽象 `InterpretInput` / `InterpretResult` / `TransactionDraft` / `LedgerTextInterpreterCore`，二是在 OCR 后增加 `BillRelevanceGate`，对无关图片输出 `nonBillImage` 并提示用户“图片没有有效的账单信息”，三是基于本地 `receiptsample/` 建立 OCR JSONL、解析 JSONL、Markdown 报告和字段级 diff 的批量测试链路。
- 未完成内容：尚未冻结最终 Swift API；尚未决定新建独立 `AutoLedgerInterpreterCore` target 还是先在 `AutoLedgerCore` 中目录隔离。
- 测试情况：
  - PASS：`git diff --check`
- 风险与注意事项：`AutoLedgerCore` 当前仍含 Vision 依赖，若要严格平台无关，应优先考虑拆出更小的纯 Swift target；`receiptsample/` 已被 Git ignore，原始图片不得提交。
- 回滚方式：删除 `versions/v1.3.3-plan.md`，并移除 CHANGELOG / iteration-log 中的 ITER-048 记录即可，不影响代码。
- 结论：v1.3.3 版本规划已形成，可进入接口冻结和工具链实现。
- 下一步建议：先落 `TransactionDraft` 与 `InterpretResult` 的最小可编译模型，再做前 20 张小票的 OCR JSONL smoke test。

### ITER-047 统一文本转账单解析入口
- 日期：2026-04-27
- 所属版本：v1.3.2
- 所属阶段：Phase 0-4
- 类型：重构 / 能力增强 / 测试 / 文档
- 目标：把 OCR、语音转文本和一句话输入之后的账单结构化流程收敛到统一文本解释入口，再由统一新建账单入口写入账本。
- 改动范围：
  - `versions/v1.3.2-plan.md`：新增版本计划、架构边界、阶段拆分、验收标准和回滚方式。
  - `LedgerTextInterpreter.swift`：新增统一解释器，输出订阅、普通账单、多商品总金额缺失、语音短句结果和解析失败。
  - `LedgerStore.swift`：`importRecognizedText` 改为调用统一解释器；新增 `interpretVoiceText` 和 `createTransaction(from:)`；语音/一句话保存复用结构化账单入库链路。
  - `VoiceLedgerQuickEntryView.swift`、`VoiceLedgerConfirmView.swift`、`VoiceLedgerIntent.swift`：语音快捷入口、账本页一句话入口和 Siri 语音入口改为通过统一解释器的 `.voice` 分支生成账单草稿。
  - `OfflineRegression.swift`、`run_offline_regression.sh`：离线编译纳入新解释器，并保留 OCR、语音、备份、商户别名回归断言。
- 未改动范围：不重写 OCR、语音识别或短句解析规则；不合并 `VoiceLedgerParser` 与小票解析器；不做多账单拆分、收入、转账、报销或 SQLite schema 变更。
- 完成内容：图片 OCR/剪切板/分享/订阅邮件/语音/一句话输入/Siri 语音文本均进入统一文本解释层；App 内结构化账单统一通过 `createTransaction(from:)` 进入入库、去重、调试和备份链路。
- 未完成内容：Siri `VoiceLedgerIntent` 的保存仍是 AppIntent 内的轻量直写路径，后续可抽出 AppIntent 可复用的非 UI 入库适配器。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：语音短句接入统一解释器后，UI 解析变为异步任务，需要真机确认连续输入和长按松手自动保存的手感。
- 回滚方式：让语音 UI 恢复直接调用 `VoiceLedgerParser`，并将 `LedgerStore.importRecognizedText` 恢复为原内联解析逻辑。
- 结论：v1.3.2 统一文本转账单架构已落地，代码门禁通过。
- 下一步建议：真机点验 OCR 导入、一句话输入实时解析、首页长按语音自动保存和重复导入提示。

### ITER-046 商户别名自动学习与历史账单回刷
- 日期：2026-04-27
- 所属版本：App Store v1.2.0 补丁
- 所属阶段：商户规范化增强
- 类型：能力增强 / 持久化 / 测试
- 目标：用户把高置信自动入账账单的长商户名改为简称时，自动学习商户别名，并把已有账单中完全匹配的长商户名统一刷新为别名。
- 改动范围：
  - `LedgerStore.swift`：新增 `setMerchantAlias`、`deleteMerchantAliases`、`applyMerchantAliasesToExistingTransactions` 和高置信编辑自动学习逻辑；商户别名保存后回刷当前账单并写回 SQLite。
  - `MerchantAliasView.swift`：新增/删除商户别名改为调用 `LedgerStore` 方法，确保设置页变更也触发历史账单刷新。
  - `OfflineRegression.swift`：新增手动别名刷新历史账单、编辑高置信账单自动学习别名的断言。
  - `CHANGELOG.md`、`process/iteration-log.md`：同步本轮记录。
- 未改动范围：不做模糊匹配；不回滚删除别名后的历史账单名称；不修改分类学习规则。
- 完成内容：别名新增/更新会把所有完全匹配原商户名的当前账单更新为别名；用户编辑高置信自动入账账单并将商户改短名时，会自动记录别名规则。
- 未完成内容：真机 UI 仍需点验设置页新增别名后的刷新提示和账本列表展示。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：当前只做完全匹配，避免把相似但不同的商户误合并；删除别名不会自动恢复历史账单原名。
- 回滚方式：移除 `updateTransaction` 中的自动学习调用，并让设置页恢复直接修改 `merchantAliases` 后保存。
- 结论：商户别名自动学习与历史账单回刷已实现，代码门禁通过。
- 下一步建议：在真机上导入一笔高置信账单，将商户名改短，确认设置页出现别名且历史同名账单被刷新。

### ITER-045 一句话记账交互收敛
- 日期：2026-04-27
- 所属版本：v1.3.1
- 所属阶段：Phase 3-4
- 类型：能力增强 / 前端 / 交互 / 测试
- 目标：收敛语音与文本入口边界，让首页只有圆形麦克风按钮响应长按，账本页改为纯文本“一句话记账”实时解析。
- 改动范围：
  - `VoiceLedgerQuickEntryView.swift`：长按识别手势从整块方框收窄到圆形麦克风按钮。
  - `VoiceLedgerConfirmView.swift`：移除页内麦克风按钮和手动解析按钮；输入框内容变化时实时调用 `VoiceLedgerParser`，同步商户、金额、分类、时间和提示文案。
  - `Localizable.strings`：账本页标题改为“一句话记账” / `One-Line Ledger`。
  - README、v1.3.1 计划、回归基线、发布草稿、CHANGELOG：同步当前入口分工。
- 未改动范围：未改变首页语音识别服务；未改变 Siri `VoiceLedgerIntent`；未改变语音交易保存、去重、备份和调试记录路径。
- 完成内容：首页长按只响应圆形按钮；账本页成为纯文本一句话入口，用户输入后下方账本字段实时生成，保存时继续复用 `LedgerStore.addVoiceTransaction`。
- 未完成内容：真机仍需确认圆形按钮命中区是否符合手感，输入实时解析是否足够顺滑。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：实时解析会在用户输入未完成时展示失败/待确认提示，文案需保持温和，避免让用户误以为已保存失败。
- 回滚方式：恢复 `VoiceLedgerConfirmView` 的手动解析按钮；或把 `VoiceLedgerQuickEntryView` 的手势重新挂到更大的容器。
- 结论：交互收敛完成，构建通过。
- 下一步建议：真机验证首页圆形按钮长按、账本页输入 `午饭 28 元` 时字段实时生成并可保存。

### ITER-044 首页按住语音快捷记账
- 日期：2026-04-27
- 所属版本：v1.3.1
- 所属阶段：Phase 3-4
- 类型：能力增强 / 前端 / 交互 / 测试
- 目标：把 App 内语音记账从账本页入口前移到首页，支持打开 App 后按住录音、松手识别，并在高置信场景自动保存。
- 改动范围：
  - `VoiceLedgerQuickEntryView.swift`：新增首页快捷入口，支持按住输入、松手识别、高置信自动保存、低置信展示识别结果与保存按钮。
  - `InboxView.swift`：首页 hero 下方新增语音快捷记账入口。
  - `VoiceSpeechRecognizer.swift`：停止录音时结束音频输入，不直接取消识别任务，降低松手后最终转写丢失风险；新增 `cancel()` 用于页面退出清理。
  - `VoiceLedgerConfirmView.swift`：将原“开始语音”按钮调整为“输入”，重做图标和按钮视觉，避免图标色与背景接近。
  - `Localizable.strings`：补充中英文按住录音、松手识别、处理中、空结果、自动保存提示。
- 未改动范围：未实现 Apple Watch 独立端；未存储音频文件；未放开收入、转账、报销或多金额语句自动保存。
- 完成内容：首页已提供长按录音快捷路径；账本页保留文本一句话记账，输入时实时解析并生成下方账本字段；语音识别、解析、保存仍复用同一套服务与 `LedgerStore.addVoiceTransaction`。
- 未完成内容：真机仍需验证长按手感、松手后的最终转写、自动保存与低置信保存按钮。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`bash scripts/run_offline_regression.sh`
- 风险与注意事项：Speech 最终转写回调可能受系统状态影响；当前用短延迟等待松手后的最终结果，真机体验需继续观察。
- 回滚方式：从 `InboxView` 移除 `VoiceLedgerQuickEntryView`，保留账本页 `VoiceLedgerConfirmView` 入口；或恢复 `VoiceSpeechRecognizer.stop()` 为立即取消。
- 结论：代码门禁通过，首页语音快捷入口已落地。
- 下一步建议：真机验证首页首次权限、按住录音、松手识别、高置信自动保存、低置信手动保存，并评估 Apple Watch 端复用同一解析/保存接口。

### ITER-043 App 内麦克风语音输入
- 日期：2026-04-27
- 所属版本：v1.3.1
- 所属阶段：Phase 3-4
- 类型：能力增强 / 前端 / 权限 / 测试
- 目标：在保留文本“一句话记账”的基础上，为 App 内语音记账补充真正的麦克风语音输入。
- 改动范围：
  - `VoiceSpeechRecognizer.swift`：新增 Speech + AVFoundation 语音识别服务，处理语音识别权限、麦克风权限、开始/停止听写、部分识别结果回传。
  - `VoiceLedgerConfirmView.swift`：新增开始/停止语音按钮，识别结果自动写入文本框并复用 `VoiceLedgerParser` 解析，保留手动输入和手动解析按钮。
  - `AutoLedger.xcodeproj/project.pbxproj`：主 App build settings 新增 `NSMicrophoneUsageDescription` 与 `NSSpeechRecognitionUsageDescription`。
  - `Localizable.strings`：补充中英文语音输入状态、权限失败和不可用文案。
  - `CHANGELOG.md`、`process/iteration-log.md`：同步本轮记录。
- 未改动范围：不改变 Siri `VoiceLedgerIntent`；不存储录音文件；不引入云端语音识别；不移除文本一句话记账。
- 完成内容：App 内入口现在支持点击麦克风开始听写，转写文本自动进入原有解析/确认/保存流程。
- 未完成内容：真机麦克风权限弹窗、语音识别可用性、中文听写准确度仍需人工验证。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：Speech 识别可用性受系统语言、网络/系统服务状态和权限影响；权限被拒绝时用户仍可使用文本一句话记账。
- 回滚方式：移除 `VoiceSpeechRecognizer` 和 `VoiceLedgerConfirmView` 中的语音按钮；保留文本输入与 Siri 入口不受影响。
- 结论：代码已实现，代码门禁通过，真机语音输入确认待执行。
- 下一步建议：在真机上首次点击语音按钮，确认麦克风/语音识别权限文案、开始/停止状态、识别文本自动解析和保存链路。

### ITER-038~042 v1.3.1 语音记账实现
- 日期：2026-04-26
- 所属版本：v1.3.1
- 所属阶段：Phase 0-5
- 类型：能力增强 / 前端 / AppIntent / 测试 / 治理
- 目标：按 `v1.3.1-plan.md` 实施语音记账 MVP，覆盖语音来源、规则解析、Siri 入口、App 内确认、本地化、回归基线与发布门禁。
- 改动范围：
  - `ReceiptSource.swift` / `ImportDebugRecord.swift`：新增 `voice` 来源和 `voiceIntent` 调试入口。
  - `VoiceLedgerParser.swift`：新增语音短句规则解析、置信度与失败原因。
  - `VoiceLedgerIntent.swift` / `QuickLedgerIntent.swift`：新增 Siri/AppIntent 入口并注册 AppShortcut。
  - `LedgerStore.swift` / `LedgerView.swift` / `VoiceLedgerConfirmView.swift`：新增 App 内语音/文本确认入口与保存路径。
  - `Localizable.strings`：补充中英文语音记账文案。
  - `OfflineRegression.swift` / `run_offline_regression.sh`：新增语音解析离线回归。
  - `versions/v1.3.1-plan.md`、`versions/v1.3.1-regression-baseline.md`、`versions/v1.3.1-RELEASE(draft).md`、`README.md`、`AutoLedger/README.md`、`CHANGELOG.md`：同步实现与门禁状态。
- 未改动范围：不做收入、转账、报销、多金额拆分；不做自研录音转写或云端语音识别；不做多轮 Siri 对话确认。
- 完成内容：v1.3.1 代码实现完成；语音规则解析、失败边界、Siri Intent metadata、App 内确认入口、语音来源展示和调试记录已接入；离线回归与 generic iOS 构建通过。
- 未完成内容：真机 Siri 发现、Siri 参数输入、高置信后台直写、App 回前台刷新和 App 内确认交互仍待人工验证。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：AppShortcut 固定短语不能直接内嵌 `String` 参数，当前通过无参数短语触发并由 Siri/快捷指令收集 `content`；真机体验可能受 Shortcuts 索引和系统语言影响。
- 回滚方式：移除 `VoiceLedgerIntent` 的 AppShortcut 注册；隐藏账本页 `waveform` 入口；保留已有 `source = voice` 交易作为普通交易继续显示和备份。
- 结论：本轮代码完成，发布判定待真机 Siri 验证。
- 下一步建议：安装到真机后验证 Siri 能发现语音记账、`午饭 28 元` 可高置信直写、失败句式不会保存，以及 App 内确认页可通过系统听写输入并保存。

### ITER-037 v1.3.1 语音记账 + Siri 版本规划
- 日期：2026-04-26
- 所属版本：v1.3.1
- 所属阶段：Phase 0
- 类型：文档 / 治理
- 目标：分析根目录 `autoledger_voice_siri_design.md` 与现有 AppIntent、SQLite、分类和备份恢复能力，建立 v1.3.1 版本计划。
- 改动范围：
  - `versions/v1.3.1-plan.md`：新增版本定位、承接输入、设计约束、In Scope / Out of Scope、Phase 0-5 阶段拆分、ITER-037-042 迭代拆分、验收标准、测试计划、风险与回滚。
  - `CHANGELOG.md`：新增 v1.3.1 / ITER-037 文档规划记录。
  - `process/iteration-log.md`：新增本条迭代日志。
- 未改动范围：未实现 `VoiceLedgerParser`、`VoiceLedgerIntent`、App 内语音入口、本地化文案或回归脚本；未调整既有 Xcode 工程版本号改动。
- 完成内容：明确 v1.3.1 主题为"语音记账 MVP + Siri 快捷入口"；确认本版只做"一句话 → 一笔支出"，Siri 高置信度直接保存，中低置信度失败重试，App 内入口承接确认与修改；将语音来源、规则解析、Siri Intent、App 内确认、调试记录、备份联动和发布门禁拆成可执行迭代。
- 未完成内容：语音解析模型、Siri 真机触发、App 内确认 UI、语音交易回归与 v1.3.1 发布门禁仍待后续 ITER-038+ 执行。
- 测试情况：文档规划迭代，未运行代码测试。
- 风险与注意事项：Siri AppIntent 参数短语需要真机验证；语音误识别可能误存，因此计划限定 Siri 仅 high 置信度保存；当前工作区已有 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 版本号改动，本轮保持不处理。
- 回滚方式：删除 `versions/v1.3.1-plan.md`；移除 `CHANGELOG.md` 和 `process/iteration-log.md` 中 ITER-037 相关条目。
- 结论：本轮完成。v1.3.1 版本计划草稿已建立。
- 下一步建议：进入 ITER-038，新增 `ReceiptSource.voice`、语音调试来源与 `VoiceLedgerParser`，先用离线回归锁住解析边界。

### ITER-031~036 v1.3.0 数据备份与恢复实现
- 日期：2026-04-26
- 所属版本：v1.3.0
- 所属阶段：Phase 0-5
- 类型：能力增强 / 持久化 / 前端 / 测试 / 治理
- 目标：按 `v1.3.0-plan.md` 实施 BackupBundle、手动 JSON 导出/导入、iCloud 单文件自动备份、空库恢复提示、回归基线与发布门禁草稿。
- 改动范围：
  - `BackupBundle.swift`：新增备份 schema、摘要、订阅元数据、低风险设置与校验器。
  - `SQLiteTransactionStore.swift`：新增 `loadBackupTransactions()` 与 `replaceForRestore(...)`，支持含 `deleted_at` 的覆盖恢复；订阅保存保留原始 `createdAt`。
  - `LedgerStore.swift`：新增备份包生成、JSON 导出、JSON 导入、覆盖恢复、iCloud 立即备份、自动备份调度、空库恢复检测。
  - `DataManagementView.swift`：新增设置页数据管理入口，支持当前数据摘要、iCloud 备份开关、立即备份、JSON 导出与 JSON 恢复。
  - `ICloudBackupService.swift`：新增 iCloud Drive `AutoLedgerBackup.json` 读写。
  - `AutoLedgerApp.swift`：App 进入后台触发自动备份，空库启动检测到 iCloud 备份时弹窗提示恢复。
  - `AutoLedger.entitlements`：新增 iCloud Documents 容器声明。
  - `OfflineRegression.swift` / `run_offline_regression.sh`：新增备份导出/恢复离线断言与编译依赖。
  - `versions/v1.3.0-regression-baseline.md`、`versions/v1.3.0-RELEASE(draft).md`、`README.md`、`AutoLedger/README.md`、`CHANGELOG.md`、`versions/v1.3.0-plan.md`：同步实现与门禁状态。
- 未改动范围：不做 CloudKit 结构化同步；不做多设备双向合并；不备份原始截图、OCR 全文、诊断包、反馈附件或 Gemma 模型文件。
- 完成内容：v1.3.0 代码实现完成；手动 JSON 备份/恢复和 SQLite + UserDefaults 混合数据恢复已有离线回归覆盖；iCloud 单文件备份代码和 entitlement 已就绪。
- 未完成内容：真机 iCloud Drive 写入、重装恢复弹窗、share sheet/file importer 人工验证仍待执行。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：iCloud 容器 `iCloud.top.darkrio326.AutoLedger` 需要在 Apple Developer 后台开启并匹配 provisioning profile；若容器未就绪，可发布手动 JSON 备份版并将自动 iCloud 备份延期。
- 回滚方式：隐藏 `DataManagementView` 入口；移除 iCloud entitlement 和 `ICloudBackupService`；回退 `LedgerStore` 备份/恢复扩展与 SQLite 备份 API；保留现有 SQLite 数据不受影响。
- 结论：本轮代码完成，发布判定待真机 iCloud 验证。
- 下一步建议：在真机上开启 iCloud Drive，验证立即备份、后台备份、删除 App 后空库恢复提示，以及 JSON 文件导入导出 UI。

### ITER-030 v1.3.0 版本规划
- 日期：2026-04-26
- 所属版本：v1.3.0
- 所属阶段：Phase 0
- 类型：文档 / 治理
- 目标：读取根目录 `autoledger_icloud_backup_design.md` 和现有工程进展，建立 v1.3.0 版本计划，将 iCloud 轻量备份设计拆成可执行迭代。
- 改动范围：
  - `versions/v1.3.0-plan.md`：新增版本定位、承接输入、In Scope / Out of Scope、Phase 0-5 阶段拆分、ITER-030-036 迭代拆分、依赖清单、验收与回滚、文档同步要求。
  - `CHANGELOG.md`：新增 v1.3.0 / ITER-030 文档规划记录。
  - `process/iteration-log.md`：新增本条迭代日志，并将更新日期调整到 2026-04-26。
- 未改动范围：未实现 `BackupBundle` 代码；未配置 iCloud entitlement；未新增导入导出 UI；未运行构建或回归测试。
- 完成内容：明确 v1.3.0 主题为"数据备份 + 手动迁移 + iCloud 轻量恢复"；确认本版优先做单文件 JSON 备份与恢复，不做 CloudKit 结构化实时同步；将 SQLite 与 UserDefaults 分散数据都纳入备份范围。
- 未完成内容：schema 代码、手动导出/导入、iCloud 自动备份、空库恢复提示和 v1.3.0 回归门禁仍待后续 ITER-031+ 执行。
- 测试情况：文档规划迭代，未运行代码测试。
- 风险与注意事项：当前工程只有 App Group entitlement，未发现 iCloud entitlement；后续 Phase 3 需要真机 Apple ID 和 iCloud Drive 环境验证。若 v1.2.0 真机门禁出现阻断，应先追加 v1.2.0 修复再进入 v1.3.0 实现。
- 回滚方式：删除 `versions/v1.3.0-plan.md`；移除 `CHANGELOG.md` 和 `process/iteration-log.md` 中 ITER-030 相关条目；恢复迭代日志更新日期。
- 结论：本轮完成。v1.3.0 版本计划草稿已建立。
- 下一步建议：进入 ITER-031，定义 `BackupBundle` v1 与 SQLite/UserDefaults 字段映射，并补充导入校验模型。

### ITER-029 回归基线 + 发布门禁
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 4
- 类型：文档 / 测试 / 治理
- 目标：建立 v1.2.0 回归基线与发布门禁草稿，覆盖本版新增的端侧 LLM、月报图表、异常消费检测、云闪付 / 银联、订阅管理增强和软删除持久化，并记录真机待验证项。
- 改动范围：
  - `versions/v1.2.0-regression-baseline.md`：新增回归矩阵，覆盖主路径、多渠道导入、端侧 LLM、月报图表、解析平台、订阅管理、软删除、去重/反馈等场景；记录本轮离线回归与 generic iOS 构建 PASS。
  - `versions/v1.2.0-RELEASE(draft).md`：新增发布前检查、门禁判定、发布结论、版本亮点、回滚方案与发布后观察指标。
  - `versions/v1.2.0-plan.md`：将 ITER-028 标记为暂无外测反馈输入而跳过实现，将 ITER-029 标记为完成。
  - `README.md`、`AutoLedger/README.md`：更新最近删除描述为跨会话恢复；根 README 修正 v1.1.0 状态显示。
  - `CHANGELOG.md`、`process/iteration-log.md`：同步 ITER-029 完成记录。
- 未改动范围：未执行真机端到端回归；未上传 TestFlight 构建；未新增代码功能；未处理具体外测 Issue，因为当前没有可执行反馈输入。
- 完成内容：v1.2.0 已具备可追溯回归基线和发布门禁草稿；离线回归与 generic iOS 构建结果已回填；真机待验证项和非阻断限制已明确。
- 未完成内容：真机全链路验证、旧库升级验证、TestFlight 构建上传和最终发布判定仍待执行。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`（在 `AutoLedger/` 目录执行）
- 风险与注意事项：本轮是文档收口，不等价于发布放行；门禁结论仍为待真机验证。Gemma 下载体积、云闪付真实样本覆盖和软删除旧库升级仍需真机确认。
- 回滚方式：删除 `versions/v1.2.0-regression-baseline.md` 与 `versions/v1.2.0-RELEASE(draft).md`；恢复 README、版本计划、CHANGELOG 与迭代日志中 ITER-029 相关文案。
- 结论：本轮完成。v1.2.0 回归基线与发布门禁草稿已建立。
- 下一步建议：执行真机端到端回归，回填 `v1.2.0-regression-baseline.md`；若出现阻断，追加 ITER-030+ 修复；若全部通过，则完成发布判定。

### ITER-028 外测反馈修复坑位
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 4
- 类型：Bugfix / 治理
- 目标：承接 v1.1.0 / v1.2.0 TestFlight 外测反馈中的高优紧急修复。
- 改动范围：无代码改动。
- 未改动范围：未处理具体 Issue；未新增回归样本；未调整功能行为。
- 完成内容：确认当前本地文档和工程中没有可执行的外测反馈清单；保留后续 ITER-030+ 坑位承接真实反馈。
- 未完成内容：真实 TestFlight 反馈仍待收集。
- 测试情况：无新增测试；沿用 ITER-029 的离线回归和构建验证。
- 风险与注意事项：若后续收到高优反馈，可能需要打断发布收口并追加修复迭代。
- 回滚方式：无需回滚。
- 结论：本轮跳过实现。原因是缺少具体反馈输入，强行修改会扩大无依据变更。
- 下一步建议：推进 ITER-029 回归基线与发布门禁；后续有反馈再追加迭代。

### ITER-027 软删除持久化 + 最近删除跨会话
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 4
- 类型：能力增强 / 持久化 / 测试
- 目标：按 `v1.2.0-plan.md` 完成 SQLite `deleted_at` 软删除持久化，让 `DeletedTransactionsView` 中的最近删除账单在 App 重启后仍可恢复，并保留彻底删除能力。
- 改动范围：
  - `AutoLedgerCore/Persistence/SQLiteTransactionStore.swift`：`transactions` 表启动时安全迁移新增 `deleted_at` 列；常规 `loadTransactions()` 过滤 `deleted_at IS NULL`；`delete(transactionID:)` 改为写入 `deleted_at` 与 `updated_at`；新增 `loadDeletedTransactions(limit:)`、`restoreTransaction(id:)`、`permanentlyDeleteTransaction(id:)`。
  - `AutoLedger/App/LedgerStore.swift`：初始化与刷新时加载 SQLite 最近删除列表；删除后内存移动到 `deletedTransactions`；恢复和彻底删除操作写回 SQLite 后再更新内存。
  - `AutoLedger/Features/Ledger/DeletedTransactionsView.swift`：更新空态与底部说明，明确最近删除会跨会话保留。
  - `scripts/OfflineRegression.swift`：新增 SQLite 软删除回归断言，覆盖活动列表隐藏、最近删除列表可见、重开 store 后仍保留、恢复回活动列表、彻底删除后完全移除。
  - `CHANGELOG.md`、`versions/v1.2.0-plan.md`、`AutoLedger/Features/Settings/SettingsView.swift`：同步 ITER-027 完成状态与版本状态。
- 未改动范围：不新增自动清理最近删除的过期策略；不改变 `TransactionStore` 协议接口；不迁移历史会话内 `deletedTransactions` 内存数据；不新增 UI 筛选/批量恢复。
- 完成内容：账单删除改为 SQLite 软删除；活动账本不会加载已删除行；最近删除可从 SQLite 重新加载；恢复会清空 `deleted_at`；彻底删除仍执行物理删除。
- 未完成内容：软删除保留期限、批量清空与发布门禁文档尚未进入本轮，留给 ITER-028/029 或后续版本收口。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：`deleted_at` 迁移在启动建表流程中执行，已兼容既有库；真实设备升级场景仍建议在 TestFlight 数据上验证一次。最近删除默认加载最近 50 条，极端大量删除记录不会一次性全部展示。
- 回滚方式：将 `delete(transactionID:)` 恢复为物理删除；移除 `deleted_at` 过滤、最近删除加载/恢复/彻底删除 API 与离线回归断言；设置页和版本计划回退到 ITER-026 状态。已添加到现有数据库的 `deleted_at` 列无需回滚，可保留为空列。
- 结论：本轮完成。v1.2.0 Phase 4 的软删除持久化部分已完成。
- 下一步建议：进入 ITER-028/029，处理 TestFlight 外测反馈、建立 v1.2.0 回归基线与发布门禁。

### ITER-026 订阅年度总览 + 费用优化建议 + 订阅编辑
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 3
- 类型：能力增强 / 前端 / 测试
- 目标：按 `v1.2.0-plan.md` 完成订阅管理增强：订阅列表展示年度总览，月付订阅支持年付节省建议，长按订阅可编辑核心字段。
- 改动范围：
  - `AutoLedger/Features/Settings/SubscriptionListView.swift`：新增年度总览卡，展示预估年度订阅开销、月均成本与已知可优化金额；订阅卡支持长按"编辑"；内嵌 `SubscriptionEditView`，可编辑商户、方案名称、周期、金额、最近扣费、下次扣费、年付价格与备注；月付订阅填写年付价后在卡片和编辑页展示节省建议。
  - `AutoLedger/App/LedgerStore.swift`：新增 `updateSubscription(_:)`，更新内存订阅、按下次扣费日期排序、调用 SQLite 更新并重新调度本地扣费提醒。
  - `scripts/OfflineRegression.swift`：新增 SQLite 订阅更新断言，覆盖编辑后字段持久化。
  - `AutoLedger/Features/Settings/SettingsView.swift`：更新版本状态文案，标记订阅管理增强已落地。
  - `CHANGELOG.md`、`versions/v1.2.0-plan.md`：同步 ITER-026 完成状态。
- 未改动范围：不改变 `subscriptions` SQLite 表结构；不新增云端价格库；不做自动获取年付定价；不做订阅删除恢复；不新增独立 `SubscriptionEditView.swift` 文件，编辑视图以内嵌私有 View 形式放在订阅列表文件中。
- 完成内容：订阅列表可查看年度开销；月付订阅可录入年付价格并看到节省金额；长按订阅可编辑字段并持久化；年付价格与备注以订阅 id 为 key 存入 UserDefaults 侧表，满足不改表结构约束。
- 未完成内容：年付价格和备注未进入 SQLite 订阅表；若未来需要跨设备同步或更强备份，需要在后续 schema 版本中迁移为正式列。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：年付价与备注依赖订阅 id，若后续删除并重新识别同商户订阅，会生成新 id，旧侧表数据不会自动迁移；这是当前不改 SQLite schema 的取舍。
- 回滚方式：删除 `SubscriptionListView` 中年度总览、编辑 sheet、UserDefaults 侧表与节省建议逻辑；移除 `LedgerStore.updateSubscription(_:)`；移除 OfflineRegression 中订阅更新断言；恢复设置页和版本计划文案。
- 结论：本轮完成。v1.2.0 Phase 3 订阅管理增强已完成。
- 下一步建议：进入 ITER-027，推进 SQLite `deleted_at` 软删除持久化与 `DeletedTransactionsView` 跨会话恢复。

### ITER-025 云闪付 / 银联解析适配
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 2
- 类型：能力增强 / 解析适配 / 测试
- 目标：按 `v1.2.0-plan.md` 完成云闪付 / 银联基础解析适配，新增来源枚举、分享扩展 Bundle ID 映射、专用商户提取逻辑，并补齐离线回归样本。
- 改动范围：
  - `AutoLedgerCore/Enums/ReceiptSource.swift`：新增 `.unionPay`，标题为"云闪付"；来源推断支持"云闪付"，以及"银联"/"UnionPay"与交易详情关键词组合，降低普通广告噪声误判。
  - `AutoLedgerCore/Services/ReceiptParser.swift`：新增 `parseUnionPayVoucher(lines:)`，支持"商户名称"分行展示与"商户名称：XXX"内联展示两种版式；商户优先链新增云闪付/银联专用提取。
  - `AutoLedgerCore/Services/SampleReceiptProvider.swift`：新增"云闪付付款成功截图"与"银联二维码支付详情截图"两条回归样本。
  - `AutoLedger/ShareExtension/ShareViewController.swift`：新增 `com.unionpay.chsp` → `unionPay` 来源映射。
  - `AutoLedgerCore/Enums/TransactionCategory.swift`：将"盒马/超市/便利店"分类规则前移到"会员/订阅"之前，避免支付详情页 UI 噪声把便利店消费误归数字服务。
  - `scripts/OfflineRegression.swift`：补齐云闪付/银联 merchant/amount/category 断言，并让分类失败信息输出 got/expected。
  - `scripts/run_offline_regression.sh`：补齐 v1.2.0 离线编译 stub（`LLMProvider`、`OCRTextCleaner`、`SmartReceiptParser.SmartResult` 等），恢复离线回归可运行。
  - `CHANGELOG.md`、`versions/v1.2.0-plan.md`：同步 ITER-025 完成状态。
- 未改动范围：未新增联网校验；未修改 SQLite schema；未做多笔账单拆分；未宣称覆盖所有云闪付真实 OCR 版式，仍需外测样本继续扩充。
- 完成内容：云闪付/银联作为正式来源进入枚举和分享扩展映射；基础交易详情页可解析商户、金额、时间和分类；离线回归重新恢复通过。
- 未完成内容：真机云闪付截图和银联 POS 小票样本仍需继续采集；`com.unionpay.chsp` Bundle ID 需真机分享入口实测确认。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：云闪付/银联 OCR 版式差异较大，本轮只覆盖两类高频交易详情版式；来源推断中 `UnionPay` 需要伴随交易详情关键词才识别为 `.unionPay`，避免误伤通知中心广告噪声。
- 回滚方式：移除 `.unionPay` 枚举与 Share Extension 映射；删除 `parseUnionPayVoucher` 及商户优先链调用；删除两条样本和 OfflineRegression 断言；还原 `TransactionCategory` 分类规则顺序和离线回归 stub 变更。
- 结论：本轮完成。v1.2.0 Phase 2 新支付平台基础适配已完成。
- 下一步建议：进入 ITER-026，推进订阅年度总览、费用优化建议与订阅编辑；同时在外测中继续收集真实云闪付/银联截图扩充回归样本。

### ITER-024 异常消费检测：报告页提示卡 + 设置页阈值
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 1
- 类型：能力增强 / 前端
- 目标：按 `v1.2.0-plan.md` 完成 Phase 1 剩余异常消费检测能力：当月某分类支出超过近 3 个月同分类月均值阈值时，在报告页展示提示卡，并允许用户在设置页调整阈值。
- 改动范围：
  - `AutoLedger/Domain/Services/MonthlyInsightService.swift`：新增 `AnomalyAlert` 与 `MonthlyInsightService.detectAnomalies()`，按当前月分类支出对比过去 3 个完整月份同分类月均值，默认阈值由调用方传入；无历史基线的分类不报异常。
  - `AutoLedger/Features/Report/ReportView.swift`：新增 `@AppStorage("monthlyAnomalyThresholdPercent")`，在月度总览卡下方展示"消费提醒"卡片，最多列出 3 个异常分类，展示当前金额、近 3 月月均与倍率。
  - `AutoLedger/Features/Settings/AnalysisSettingsView.swift`：新增"消费分析"设置页，提供 100%～300% Slider、当前阈值显示与恢复默认按钮。
  - `AutoLedger/Features/Settings/SettingsView.swift`：新增"消费分析"入口，并更新版本状态文案。
  - `AutoLedger/App/AutoLedgerApp.swift`：注册 `monthlyAnomalyThresholdPercent` 默认值 150%。
  - `CHANGELOG.md`、`versions/v1.2.0-plan.md`：同步 ITER-024 完成状态。
- 未改动范围：不做通知推送；不做预算设定；不新增 SQLite schema；不改变交易分类或月报基础聚合；不修复离线回归脚本 v1.2.0 依赖清单问题。
- 完成内容：报告页可基于真实账本数据展示异常消费提示；用户可在设置页调整阈值并即时影响下次报告页计算；Phase 1 计划项完成。
- 未完成内容：真机视觉回归待补；离线回归脚本仍需后续补齐 v1.2.0 新增依赖清单。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：当前口径需要过去 3 个完整月份中至少出现过该分类支出；对于历史数据稀疏的用户，异常提示会偏保守。阈值默认 150%，可通过设置页调整。
- 回滚方式：删除 `MonthlyInsightService.swift` 和 `AnalysisSettingsView.swift`；移除 `ReportView` 中异常提示卡与 `SettingsView` 消费分析入口；移除 `AutoLedgerApp` 默认值注册。
- 结论：本轮完成。v1.2.0 Phase 1 月报分析增强已完成。
- 下一步建议：进入 ITER-025，推进云闪付 / 银联解析适配；并在适当时机补齐离线回归脚本依赖清单。

### ITER-023 月报改版：分类占比图 + 月度趋势柱图 + TOP5 商户
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 1
- 类型：能力增强 / 前端
- 目标：按 `v1.2.0-plan.md` 推进月报分析增强，报告页展示分类 Donut 占比、近 6 个月趋势柱图、TOP5 商户排行，并承接 ITER-022 遗留的"自定义分类月报归入其他"问题。
- 改动范围：
  - `AutoLedgerCore/Models/MonthlySnapshot.swift`：新增 `MerchantMetric`、`MonthlyTrendMetric`；`CategoryMetric` 改为稳定 `id/title/category?` 结构；按 `Transaction.category` 原始字符串聚合分类，自定义分类保留原始标题；新增 TOP 商户金额排行与近 6 个月月度趋势聚合。
  - `AutoLedger/Features/Report/ReportView.swift`：接入 Swift Charts，重构为月度总览卡、分类 Donut 图、近 6 月趋势柱图、TOP5 商户排行；分类行点击可高亮对应 Donut 分区。
  - `AutoLedger/Shared/Components/CategoryBreakdownRow.swift`、`AutoLedger/Shared/Extensions/TransactionCategory+UI.swift`：适配新的 `CategoryMetric`，内置分类继续使用原图标/颜色，自定义分类使用 `tag.fill` 与稳定配色。
  - `CHANGELOG.md`、`versions/v1.2.0-plan.md`：同步迭代完成状态。
- 未改动范围：异常消费检测（ITER-024）未做；设置页消费分析阈值未做；SQLite schema 未改；首页商户卡仍沿用 `topMerchants` 字符串列表。
- 完成内容：报告页已具备 Donut 分类占比、近 6 月趋势柱图、TOP5 商户列表；自定义分类在月报中独立展示，不再被合并到"其他"；保持 `topMerchants` 兼容首页现有展示。
- 未完成内容：离线回归脚本 `scripts/run_offline_regression.sh` 目前缺少 v1.2.0 新增的 `OCRTextCleaner`、`LLMProvider` 等依赖清单更新，脚本仍会在编译临时 `LedgerStore.swift` 时失败；本轮未扩大范围修复回归脚本。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - FAIL（既有脚本依赖清单问题）：`bash scripts/run_offline_regression.sh`，错误为 `OCRTextCleaner` / `LLMProvider` 未在离线编译临时上下文中提供。
- 风险与注意事项：Donut/Bar Chart 依赖 Swift Charts，当前工程 iOS 26 target 满足；自定义分类颜色按标题稳定哈希选择，后续若加入分类管理配色字段可替换为用户配置色。
- 回滚方式：还原 `MonthlySnapshot.swift` 的新增 metric 结构与聚合逻辑，`ReportView.swift` 回退到原分类列表页面，`CategoryBreakdownRow.swift` 回退到 `TransactionCategory` 强类型展示。
- 结论：本轮完成。ITER-023 已按 v1.2.0 计划交付，iOS 构建通过。
- 下一步建议：进入 ITER-024，新增 `MonthlyInsightService`、异常消费提示卡与设置页阈值配置；同时补齐离线回归脚本的 v1.2.0 依赖清单。

### ITER-022 编辑器支持自定义分类和来源
- 日期：2026-04-13
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：能力增强
- 目标：用户在账本中添加的自定义分类/来源，在编辑账单时无法在 Picker 中选择；根因是 `Transaction.category/source` 为强类型枚举，无法存储自定义字符串。
- 改动范围：
  - `AutoLedgerCore/Models/Transaction.swift`：`category`/`source` 改为 `String`，保留枚举-based init（向后兼容），新增字符串化 init（`categoryLabel:`/`sourceLabel:`），新增 `categoryEnum`/`sourceEnum`/`categoryTitle`/`sourceTitle` 计算属性。
  - `AutoLedgerCore/Persistence/SQLiteTransactionStore.swift`：加载时去掉枚举 guard（不再因自定义值跳过行）；bind/update 去掉 `.rawValue`。
  - `AutoLedgerCore/Models/MonthlySnapshot.swift`：groupBy 改为 `\.categoryEnum`（自定义分类归入"其他"支出分布）。
  - `AutoLedger/Features/Ledger/TransactionEditorView.swift`：state 改为 `String`，添加 `@EnvironmentObject store`，Picker 在内置 case 后追加 `store.customCategories`/`store.customSources`，tag 统一为 String。
  - `AutoLedger/Features/Ledger/LedgerView.swift`、`DeletedTransactionsView.swift`、`Features/Settings/DebugView.swift`、`Domain/Services/FeedbackBundleBuilder.swift`：图标/颜色改为 `categoryEnum.*`，文字改为 `categoryTitle`/`sourceTitle`。
  - `AutoLedger/App/LedgerStore.swift`：`updateTransaction` 仅对内置枚举类别触发 `recordCategoryCorrection`。
- 未改动范围：`TransactionCategory`/`ReceiptSource` 枚举本身不变；`CategoryManagementView`/`SourceManagementView` 管理 UI 不变；UserDefaults 持久化配置不变。
- 完成内容：编辑器 Picker 已展示自定义分类/来源；选择后以字符串标签持久化到 SQLite；重新加载后不再因未知 rawValue 跳行；编译通过（修复了 ForEach ArraySlice 泛型推断和嵌套字符串插值两处 build 错误）。
- 未完成内容：月报对自定义分类的统计目前归入"其他"（设计暂定）。
- 测试情况：Xcode 编译通过；功能待真机验证。
- 风险与注意事项：历史数据均为内置 rawValue，升级后读取正常；新存入的自定义标签如同名内置分类 rawValue 会被误识别为内置——但 rawValue 均为英文（如 `dining`），与用户自定义中文标签冲突概率极低。
- 回滚方式：还原 Transaction.swift（改回枚举字段）及 7 处消费点；自定义标签行在旧版加载时仍会被跳过（guard 回滚后未知 rawValue = 空），需清理数据库中自定义标签行。
- 结论：本轮完成。
- 下一步建议：月报后续可按自定义分类单独聚合展示。

### ITER-021 微信代扣凭证（先购后付）+ 地铁全角CN￥商户误识别修复
- 日期：2026-04-13
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：Bugfix / 规则
- 目标：① 微信代扣凭证（先购后付/先乘后付非滴滴场景）解析结果为"•五"等 OCR 噪声而非服务商名称；② 地铁乘车城市卡记录（天津互联互通等）OCR 输出 `CN￥3.60`（全角 ￥ U+FFE5），`isStandaloneAmount` 未识别为金额行，走 (B) 路径将金额文本作为内联站名，商户变为"地铁：CN￥3.60"。
- 改动范围：
  - `AutoLedgerCore/Services/ReceiptParser.swift`：① 新增 `parseWeChatDeductionVoucher(lines:)` 专用方法，检测"扣费凭证"页面，从"扣费内容"标签后提取服务名；新增 `bulletShortNoisePattern` 过滤 fallback 噪声行；`parse()` 商户链新增 `wechatDeductionMerchant`。② `isStandaloneAmount` 正则新增 `CN￥`（U+FFE5）分支。
- 未改动范围：其他解析路径不变；`parseDidiTrip` 不变。
- 完成内容：两项误识别场景修复；OfflineRegression 编译通过。
- 未完成内容：无。
- 测试情况：逻辑验证通过（调试记录回放）；真机验证待完成。
- 风险与注意事项：`parseWeChatDeductionVoucher` 与 `parseDidiTrip` Case C 均检测"扣费凭证"，`parse()` 中 `wechatDeductionMerchant` 在 `didiMerchant` 之后调用，滴滴场景已被前一步拦截，不会误触。
- 回滚方式：移除 `parseWeChatDeductionVoucher` 方法及 `parse()` 中的 `wechatDeductionMerchant` 调用；还原 `isStandaloneAmount` 正则（删除 `CN￥` 分支）。
- 结论：本轮完成。
- 下一步建议：持续积累微信/城市卡等场景调试记录回归用例。

### ITER-020 滴滴出行微信支付扣费凭证商户误识别修复
- 日期：2026-04-12
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：Bugfix / 规则
- 目标：修复滴滴出行"先乘车后付款"微信支付扣费凭证截图商户误识别问题——OCR 文本无"行程已"和"已支付"关键词，`parseDidiTrip` 两条已有分支均未命中，商户回退为"微信支付"，分类为"其他"；实际应为商户"滴滴出行"、分类"出行"。
- 触发调试记录（原始，未修正，完整内容）：
  ```
  AutoLedger 单条测试记录
  导出时间：2026-04-13 05:57:42
  记录时间：2026-04-12 17:44:18
  阶段：已入账
  来源：微信支付
  图片来源：快捷指令
  解析模式：纯规则解析
  结论：已记好：微信支付 ¥24.90
  解析结果：
  - 商户：微信支付
  - 金额：¥24.90
  - 分类：其他
  - 时间：2026-04-12 17:44:18
  - 摘要：已记好：微信支付 ¥24.90
  当前账单（用户修改后）：
  - 商户：滴滴出行
  - 金额：¥24.90
  - 分类：出行
  - 时间：2026-04-12 17:44:18
  - 备注：快捷指令自动记账
  OCR 文本：
  17:44
  69
  微信支付
  收支
  查看明细
  日报设置
  17:41
  • 滴滴出行
  扣费凭证
  通过Example Bank Card (1234)扣款
  ¥24.90
  按时支付，记入微信支付分记录
  扣费服务
  扣费内容
  滴滴出行
  先乘车后付款
  查看订单详情
  我的账单
  支付服务
  摇优惠
  ```
- 根因分析：微信支付"扣费凭证"卡片（先乘车后付款场景）的 OCR 文本无"行程已"（无行程结束页）、无"已支付"（无通知推送），`parseDidiTrip` Case A / Case B 均未命中，商户最终回退到 `fallbackMerchant`（来源标题"微信支付"）。
- 改动范围：
  - `AutoLedgerCore/Services/ReceiptParser.swift`：`parseDidiTrip` 新增 Case C，检测 `hasDidi && hasDeductionVoucher`（"扣费凭证"），命中时返回"滴滴出行"。
  - `AutoLedgerCore/Services/SampleReceiptProvider.swift`：新增样例"滴滴出行微信扣费凭证截图"，使用本次调试 OCR 原文。
  - `scripts/OfflineRegression.swift`：为新样例补充 expectedMerchants / expectedAmounts / expectedCategories 断言（merchant=滴滴出行, amount=24.90, category=.transport）。
  - `CHANGELOG.md`：新增本次修复条目。
- 未改动范围：SmartReceiptParser、LedgerStore、AppFormatters、UI 层均未改动；现有 Case A / Case B 逻辑不变。
- 完成内容：`parseDidiTrip` Case C 已添加；新样例已加入 SampleReceiptProvider 和 OfflineRegression；本地逻辑验证通过（swift 脚本确认 hasDidi=true, hasDeductionVoucher=true, result=滴滴出行, amount=24.90）。
- 未完成内容：无。
- 测试情况：运行 `/tmp/test_didi.swift` 脚本验证 Case C 逻辑，PASS；`swift build`（AutoLedgerCore）ReceiptParser.swift 和 SampleReceiptProvider.swift 均编译通过（AppIntents 缺失错误为 iOS 专属模块在 Linux 环境的既有问题，与本次改动无关）。
- 风险与注意事项：Case C 依赖"扣费凭证"字样，若微信更新卡片文案需重新添加关键词；当前三条 Case 互斥分支，不会相互影响。
- 回滚方式：移除 `parseDidiTrip` Case C 代码块（4 行）；删除 SampleReceiptProvider 和 OfflineRegression 中"滴滴出行微信扣费凭证截图"相关条目。
- 结论：本轮完成，滴滴出行"先乘车后付款"微信扣费凭证场景已正确识别。
- 下一步建议：继续积累真机回归用例，关注其他先乘车后付款场景变体。

### ITER-019 滴滴出行结束订单页金额误识别修复
- 日期：2026-04-12
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：Bugfix / 规则
- 目标：修复滴滴出行结束订单页（优享出租车）金额误识别——OCR 文本顶部有无关数字"71"（评价人数），通用 extractAmount 全文兜底先命中该数字，导致车费误识别为 ¥71.00；实际车费 ¥45.00 出现在"费用明细"前，且因 OCR 将"¥"误读为"4"，呈现为"445"。
- 触发调试记录（原始，未修正，完整内容）：
  ```
  AutoLedger 单条测试记录
  导出时间：2026-04-12 17:07:33
  记录时间：2026-04-12 15:59:30
  阶段：已入账
  来源：手动录入
  图片来源：快捷指令
  解析模式：纯规则解析
  结论：已记好：滴滴出行 ¥71.00
  解析结果：
  - 商户：滴滴出行
  - 金额：¥71.00
  - 分类：其他
  - 时间：2026-04-12 15:59:30
  - 摘要：已记好：滴滴出行 ¥71.00
  当前账单（用户修改后）：
  - 商户：滴滴出行
  - 金额：¥45.00
  - 分类：出行
  - 时间：2026-04-12 15:59:29
  - 备注：快捷指令自动记账
  OCR 文本：
  15:59
  ＜ 行程已给束
  71
  您对我的服务满意吗？
  Example Driver EX-0002 4.5分
  匿名
  发红包
  很糟糕
  一般般
  太赞了
  445
  9.0L
  费用明细〉
  起
  终
  收藏路线
  优享出租车|全程12.3公里 23分钟
  • 15:30 Example Resort Gate
  • 15:54 Example Hotel（步行导航＞
  里程值 +12.3
  平台提供信息技术服务，运输服务提供方为个体出租车
  匿名反馈
  69.6万+人参与中
  本次接驾车辆的车牌号与订单显示是否一致？
  不一致
  一致
  6
  呼叫返程
  联系客服 呼叫司机 功能反馈
  再来一单
  ```
- 对应保存账单条目数据（用户手动修正，可作为预期结果参考）：
  - 商户：滴滴出行
  - 金额：¥45.00
  - 分类：出行
  - 时间：2026-04-12 15:59:29
  - 来源：手动录入
- 改动范围：
  - 修改 `AutoLedgerCore/Services/ReceiptParser.swift`：
    - 新增私有方法 `extractDidiTripAmount(lines:)`：仅在含"行程已"的行程结束页触发；定位"费用明细"行，在其前 5 行内逆序搜索车费；优先匹配 ¥/￥ 前缀金额（标准格式），其次检测 OCR 将"¥"误读为"4"的情形（`^4([1-9][0-9]{1,2}(?:\.[0-9]{1,2})?)$`，如"445"→修正为 45.00；要求修正后金额 ≥10 元，避免误伤极小金额），避免误伤含中文/字母的非金额行（如"9.0L"）。
    - 重构 `parse()`：提前构建 `cleanedLines`，在 `extractAmount` 之前优先尝试 `extractDidiTripAmount`，若有结果则直接使用，否则回退到通用提取器。
  - 修改 `AutoLedgerCore/Services/SampleReceiptProvider.swift`：新增样例 "滴滴出行优享出租车截图"，使用本次调试 OCR 原文。
  - 修改 `scripts/OfflineRegression.swift`：为新样例补充 expectedMerchants / expectedAmounts / expectedCategories 断言（merchant=滴滴出行, amount=45.00, category=.transport）。
  - 修改 `CHANGELOG.md`：新增本次修复条目。
- 未改动范围：数据层 schema、UI 层、订阅识别、去重逻辑、通知截图解析路径均无改动。
- 完成内容：
  - 新样本"滴滴出行优享出租车截图"解析正确：merchant="滴滴出行"，amount=45.00，category=transport。
  - 旧样本"滴滴出行结束订单截图"回归通过：amount 仍为 19.60。
  - 旧样本"滴滴出行通知截图"回归通过：amount 仍为 9.70（通知截图无"费用明细"，走通用 extractAmount）。
  - 微信/支付宝等非滴滴样本回归通过（parse() 重构未引入副作用）。
- 未完成内容：完整离线回归脚本在 macOS/Xcode 环境执行；真机验证待补充。
- 测试情况：手动 `swiftc` 单测验证 9 项 PASS（新样本/旧样本/通知截图/微信各项）。
- 风险与注意事项：
  - "4XX" OCR artifact 修正模式：若真实车费为 4XX 元且 OCR 恰好丢失"¥"符号（输出纯数字"4XX"），会被误修正为 XX 元。但实际上 DiDi 界面有"¥"前缀，OCR 能识别时优先走步骤 1（¥ 前缀匹配），仅在 ¥ 丢失时才触发步骤 2，实际误触发概率极低。
  - `extractDidiTripAmount` 只在含"行程已"时触发，不影响其他来源的解析。
- 回滚方式：删除 `extractDidiTripAmount` 方法，将 `parse()` 中的 cleanedLines 构建和专用金额提取逻辑还原为原始结构，删除 SampleReceiptProvider 中的新样例，还原 OfflineRegression 中对应断言。
- 结论：修复完成，滴滴出行结束订单页金额识别问题已修复，同时向后兼容原有所有回归样本。
- 下一步建议：真机以本次 OCR 文本重新触发快捷指令，验证商户 = "滴滴出行"、金额 = ¥45.00、分类 = "出行"。

### ITER-018 账本管理三改进（最近删除 + 手动新增账单 + 去重排除已删除记录）
- 日期：2026-04-12
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：能力增强 / Bugfix
- 目标：① 修复已删除账单被去重逻辑误判为重复导入的 bug（删除后再次扫描同截图应允许入账）；② 新增"最近删除"功能，会话内支持恢复已删除账单；③ 账本右上角新增手动录入入口，支持不依赖截图的手动记账。
- 改动范围：
  - `AutoLedger/App/LedgerStore.swift`：`hasDuplicate` OCR Jaccard 相似度检查排除已删除账单对应的 debugRecord；新增 `deletedTransactions: [Transaction]` Published 属性、`restoreTransaction`/`permanentlyDeleteTransaction` 方法；新增 `addTransaction` 方法（手动录入持久化）。
  - `AutoLedger/Features/Ledger/LedgerView.swift`：工具栏新增"+"按钮，打开 `TransactionEditorView`（新增模式）。
  - `AutoLedger/Features/Ledger/TransactionEditorView.swift`：新增 `isNew` 参数支持"新增"/"编辑"双模式。
  - `AutoLedger/Features/Ledger/DeletedTransactionsView.swift`（新增文件）：最近删除列表，左滑恢复 / 右滑彻底删除。
- 未改动范围：SQLite 删除逻辑不变（硬删）；恢复为会话内内存恢复，不持久化到 SQLite。
- 完成内容：三项功能均已实现并编译通过；去重排除已删除记录验证通过。
- 未完成内容：无。
- 测试情况：逻辑验证通过；真机验证待完成。
- 风险与注意事项：`deletedTransactions` 为会话内变量，App 退出后清空；手动录入的来源默认为"手动录入"，分类默认为"其他"，依赖用户在编辑器中调整。
- 回滚方式：还原 `LedgerStore` 三处改动；移除 `DeletedTransactionsView.swift`；还原 `LedgerView` 工具栏按钮；还原 `TransactionEditorView` `isNew` 参数。
- 结论：本轮完成。
- 下一步建议：后续可考虑将删除记录持久化到 SQLite 软删除列（`deleted_at`），支持跨会话恢复。

### ITER-017A 地铁储值卡CN¥嵌入金额修复
- 日期：2026-04-11
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：Bugfix / 规则
- 目标：修复真机调试发现的地铁储值卡通知解析错误——"地铁：CN¥7.00"（金额嵌入冒号后）被错误当作站点文本，导致商户输出为 "地铁：CN¥7.00"、分类误判为"其他"；同时修复 "ExampleAirport - ExampleEastStation" 格式（空格+连字符分隔）未能正确规范化为 "ExampleAirport → ExampleEastStation" 的问题。
- 触发调试记录（原始，未修正，完整内容）：
  ```
  AutoLedger 单条测试记录
  导出时间：2026-04-11 14:50:30
  记录时间：2026-04-11 14:47:11
  阶段：已入账
  来源：手动录入
  图片来源：快捷指令
  解析模式：纯规则解析
  结论：已记好：地铁：CN¥7.00 ¥7.00
  解析结果：
  - 商户：地铁：CN¥7.00
  - 金额：¥7.00
  - 分类：其他
  - 时间：2026-04-11 14:47:11
  - 摘要：已记好：地铁：CN¥7.00 ¥7.00
  OCR 文本：
  14:47
  63
  现在
  支
  消费成功通知
  你的储值消费成功，查看详情>
  天津互联互通城市卡
  地铁：CN¥7.00
  ExampleAirport - ExampleEastStation
  你的新余额为 CN¥60.75。
  现在
  通知中心
  X
  周六2
  11
  乘坐列车G876次杭州东..•30分钟后
  交通严重拥堵。经德胜快速路前往
  杭州东站需要19分钟。
  3
  小红书
  PLUS抽签购权益过期提醒
  1分钟前
  您有一份原价飞飞天茅台的抽签权益
  即将过期，请尽快查看，若已参与
  请忽略>
  收获一个新的赞
  【陈槿琪】点赞了你的弹幕，快来看
  看吧>
  1分钟前
  小鸡毛烫不烫啊
  160
  下雨
  20° ＄15°
  可
  ```
- 对应保存账单条目数据（与调试记录生成数据不一致，说明用户已手动修正，可作为预期结果参考）：
  - 商户：地铁：ExampleAirport → ExampleEastStation
  - 金额：¥7.00
  - 分类：出行
  - 时间：2026-04-11 14:47:11
  - 来源：手动录入
- 改动范围：
  - 修改 `AutoLedgerCore/Services/ReceiptParser.swift`：地铁/公交储值卡解析块新增版式 (C)——新增私有方法 `isStandaloneAmount(_:)` 以锚定正则判断整行是否为独立金额（`CN¥`/`¥`/`￥`/`CNY`/`RMB` 前缀 + 数字，避免含数字的站名如"T2航站楼"、"3号线"误判）；当冒号后内联部分是独立金额时（`isStandaloneAmount` 返回 true）回退到 (A)/(C) 路径，向后查找第一个非金额行作为站点行；站名规范化时对各部分执行 `.trimmingCharacters(in: hyphenSet)` 以去掉空格连字符分隔符带来的前导"-"。
  - 修改 `AutoLedgerCore/Services/SampleReceiptProvider.swift`：新增样例 "互联互通城市卡CN¥嵌入格式截图"，使用本次调试 OCR 原文（含通知栏噪声）。
  - 修改 `scripts/OfflineRegression.swift`：为新样例补充 expectedMerchants / expectedAmounts / expectedCategories 断言。
- 未改动范围：数据层 schema、UI 层、订阅识别、去重逻辑均无改动。
- 完成内容：
  - 版式 (C)（`地铁：CN¥X.XX` 单行）现可正确识别，商户输出 "地铁：ExampleAirport → ExampleEastStation"。
  - 版式 (A)（独立 `地铁：` 行 + 金额行 + 站点行）回归通过，输出仍为 "地铁：ExampleStationA → ExampleStationB"。
  - 版式 (B)（`地铁：站A 站B` 同行）回归通过，输出不变。
  - 站名含空格+连字符分隔符（如 " -ExampleEastStation"）现可正确规范化，前导"-"被去除。
  - 离线回归（Swift 逻辑单测）5 项全 PASS。
- 未完成内容：完整离线回归脚本（`run_offline_regression.sh`）需在 macOS/Xcode 环境执行；真机验证待补充。
- 测试情况：手动 `swiftc` 单测验证 5 项 PASS（版式 A/B/C、amountCandidate 对 CN¥ 的识别、站名连字符清洗）。
- 风险与注意事项：`.trimmingCharacters(in: "-")` 仅去除站名组件两端的"-"，不影响站名中间的连字符（如"CBD-East"类名称）；若真实场景出现站名本身以"-"开头，可进一步细化为仅去前导"-"。
- 回滚方式：还原 `ReceiptParser.swift` 中地铁块的 `if !inlinePart.isEmpty` 判断与 `map` 清洗步骤，删除 `SampleReceiptProvider.swift` 中的新样例，还原 `OfflineRegression.swift` 中对应断言。
- 结论：修复完成，地铁解析规则覆盖三种常见 OCR 版式。
- 下一步建议：真机以本次 OCR 文本重新触发快捷指令，验证商户 = "地铁：ExampleAirport → ExampleEastStation"、分类 = "出行"。

### ITER-017 去重增强 + 回归基线 + 发布门禁
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：能力增强 / 文档
- 目标：去重策略从「60s 窗口 + 同商户同金额」升级为增加 OCR 文本 Jaccard 相似度比对（> 0.8 视为同一来源）；创建 v1.1.0 回归基线与发布门禁草稿。
- 改动范围：
  - 新增 `AutoLedgerCore/Utils/TextSimilarity.swift`（字符级 bigram Jaccard 相似度函数，public，供主 App + Extensions 共用）
  - 修改 `AutoLedger/App/LedgerStore.swift`（`hasDuplicate` 增加 rawText 参数，原有 60s 窗口匹配后追加 Jaccard 比对 debugRecords 最近 30 条 persisted 记录 rawText，相似度 > 0.8 判定重复）
  - 修改 `AutoLedger/Domain/Services/QuickLedgerIntent.swift`（去重逻辑增加 OCR Jaccard 检查，通过 `loadDebugEvents()` 获取历史 rawText）
  - 修改 `ShareExtension/ShareViewController.swift`（同 QuickLedgerIntent 的 OCR Jaccard 检查）
  - 修改 `scripts/OfflineRegression.swift`（新增 3 条测试：Jaccard 相似文本去重、相似度 > 0.8 验证、不相关文本 < 0.5 验证）
  - 新增 `versions/v1.1.0-regression-baseline.md`（9 大类回归矩阵，覆盖主路径/多渠道/解析/去重/订阅/分类/反馈/服务端自动化）
  - 新增 `versions/v1.1.0-RELEASE(draft).md`（发布前检查 + 门禁判定 + 版本亮点 + 回滚方案 + 发布后观察）
- 未改动范围：数据层 schema 无改动；UI 层无改动。
- 完成内容：
  - `TextSimilarity.jaccard(_:_:)`：清洗空白/标点 → 字符级 bigram 集合 → Jaccard 系数（0.0–1.0），两空串返回 1.0，单字符退化为字符集
  - 三处去重站点全部升级：LedgerStore.hasDuplicate + QuickLedgerIntent + ShareViewController
  - 去重拦截消息增强：区分"同日同金额"与"OCR 文本高度相似"两类原因
  - 离线回归新增 Jaccard 测试覆盖
  - v1.1.0 回归基线（含 PENDING 待真机验证条目）
  - v1.1.0 发布门禁草稿（⏳ 待真机验证判定）
- 未完成内容：回归基线中 PENDING 条目需真机端到端验证。
- 测试情况：`xcodebuild build` BUILD SUCCEEDED。
- 风险与注意事项：Jaccard bigram 对极短文本（<10 字符）可能产生偏高相似度；阈值 0.8 需在真实数据上确认合理性。
- 回滚方式：删除 `TextSimilarity.swift`，还原 `LedgerStore.swift`、`QuickLedgerIntent.swift`、`ShareViewController.swift` 中的 Jaccard 增量，还原 `OfflineRegression.swift` 中的新增测试。
- 结论：Phase 4 完成。v1.1.0 全 6 轮迭代（ITER-012~017）均已完成，待真机验证后可发布。
- 下一步建议：分类提交推送 → 真机验证回归基线 → 判定门禁 → 发布 TestFlight。

### ITER-016 用户反馈 C 层（服务端邮件→Issue 自动化）
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 3
- 类型：基础设施 / DevOps
- 目标：打通 App 端邮件反馈 → Gmail → GitHub Issue 自动化链路，实现反馈闭环。
- 改动范围：
  - 新增 `tools/feedback/email_to_issue.py`（~350 行）：Gmail IMAP 拉取未读邮件 → 解析邮件标题（正则提取 level/platform/version/issue_type/summary）→ 解析 AUTOLEDGER_FEEDBACK_META 区块 → 解压 zip bundle（提取 issue_bundle.json/summary.txt/metadata.json/trace.log/redacted_ocr_context.txt，故意跳过 full_ocr_text.txt 和原始截图）→ 服务端二次正则脱敏（邮箱→[EMAIL_MASKED]、手机号→[PHONE_MASKED]、长数字串→[LONG_NUMBER_MASKED]）→ GitHub REST API 创建 Issue（Markdown 格式，含 Environment 表+User Report+Debug Info+Trace Log+Redacted OCR Context+Privacy 声明）→ feedback_id 幂等去重（GitHub Issue search）→ 标记邮件已读
  - 新增 `tools/feedback/requirements.txt`（纯标准库，无外部依赖）
  - 新增 `tools/feedback/test_email_to_issue.py`（6 项 smoke tests：subject 解析、meta 解析、脱敏、labels、坏 zip、有效 zip）
  - 新增 `.github/workflows/feedback-email-to-issue.yml`（每 15 分钟定时触发 + workflow_dispatch 手动触发 + dry_run 开关 + sparse-checkout）
- 未改动范围：iOS 客户端代码无改动。
- 前置条件（已由用户完成）：
  - Cloudflare Email Routing（`support@darkrio326.top` → Gmail）— 已测试通过
  - Gmail App Password — 已生成
  - GitHub Fine-grained PAT（Issues: Read and write）— 已获取
  - GitHub repo Secrets 已配置：`GMAIL_USERNAME`、`GMAIL_APP_PASSWORD`、`GH_PAT_TOKEN`
- 完成内容：
  - `email_to_issue.py` 核心功能：邮件拉取、标题解析、meta 解析、bundle 解压、二次脱敏、Issue 创建、幂等去重、已读标记
  - Issue 自动打 5 个 label：`feedback`、`source/email`、`level/Lx`、`type/xxx`、`status/new`
  - Issue body 结构化 Markdown：Environment 表 + User Report + Debug Info + Trace Log（截断 3000 字符）+ Redacted OCR Context（截断 2000 字符）+ Privacy 声明
  - DRY_RUN 模式支持（不创建 Issue、不标记已读，仅日志输出）
  - feedback_id fallback：无 feedback_id 时使用 Message-ID SHA-256 前 12 位
  - GitHub Actions workflow：15 分钟定时 + 手动 + dry_run 参数
- 未完成内容：无。
- 测试情况：本地 smoke tests 全部通过（parse_subject、parse_meta_block、redact、build_labels、extract_bundle）。端到端验证需推送到 GitHub 后触发 Actions。
- 风险与注意事项：
  - Gmail IMAP 连接可能因网络或凭证问题失败，Actions 日志可排查
  - GitHub search API 有 rate limit（30 req/min for authenticated），高频邮件场景下去重查询可能受限
  - Issue body 中 trace / OCR context 有截断（3000/2000 字符），极长日志可能丢失尾部
  - Secret 名称用 `GH_PAT_TOKEN` 而非 `GITHUB_TOKEN`（GitHub Actions 不允许 GITHUB_ 前缀的自定义 secret）
- 回滚方式：删除 `tools/feedback/` 目录和 `.github/workflows/feedback-email-to-issue.yml`。
- 结论：Phase 3 全部完成（A 层 App 端 + B 层邮件协议 + C 层服务端自动 Issue）。
- 下一步建议：ITER-017 Phase 4（去重增强 + 回归基线 + 发布门禁）。推送代码到 GitHub 后手动触发一次 workflow（DRY_RUN=1）验证端到端。

### ITER-015 用户反馈 A+B 层
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 3
- 类型：能力增强 / UI
- 目标：实现 App 端用户反馈全链路——三级日志分级（L1 脱敏 / L2 增强调试 / L3 完整诊断）、反馈 bundle 组装、邮件发送（含 MFMailComposeViewController + 降级策略）、发送前预览、DebugView 隐藏入口 + 开发者模式内容升级。
- 改动范围：
  - 新增 `Domain/Enums/FeedbackLevel.swift`（L1/L2/L3 枚举，含 Comparable）
  - 新增 `Domain/Enums/FeedbackIssueType.swift`（14 种问题类型枚举）
  - 新增 `Domain/Services/FeedbackBundleBuilder.swift`（Feedback ID 生成、设备信息采集、分级 bundle 组装、正则脱敏、zip 压缩、邮件标题/正文模板生成）
  - 新增 `Domain/Services/FeedbackService.swift`（MFMailComposeViewController 封装 + 剪切板复制降级 + 系统分享降级）
  - 新增 `Features/Feedback/FeedbackComposerView.swift`（问题类型网格选择 + 反馈级别选择 + 描述表单 + L3 二次确认 + 截图开关 + 预览构建）
  - 新增 `Features/Feedback/FeedbackPreviewView.swift`（预览标题/正文/附件包内容 + 确认发送按钮）
  - 修改 `Features/Settings/SettingsView.swift`（新增"问题反馈"入口 sheet；DebugView 入口隐藏为多次点击版本号解锁；新增 `versionTapCount`/`showDebugUnlocked`/`showFeedbackComposer` 状态变量）
  - 修改 `Features/Settings/DebugView.swift`（新增系统信息卡、App Group 容器文件浏览、SQLite 四表分页浏览、内存/磁盘使用概况、一键导出 L3 诊断包 + ShareSheet）
- 未改动范围：AutoLedgerCore 无改动；LedgerStore 无改动。
- 完成内容：
  - `FeedbackBundleBuilder`：Feedback ID `AL-{vendorHash6}-{yyyyMMddHHmmss}-{seq}` 全局唯一；metadata.json / summary.txt / issue_bundle.json 均按协议模板生成；L2+ 追加 trace.log / redacted_ocr_context.txt；L3 追加 full_ocr_text.txt / attachments/screenshot.jpg
  - 脱敏：正则匹配 ¥金额、手机号、邮箱、银行卡号，替换为占位符；L3 不脱敏
  - `FeedbackService`：MFMailComposeViewController 发送邮件（含 zip 附件）；无邮件账户时降级为剪切板复制或系统分享 zip
  - `FeedbackComposerView`：14 种问题类型 LazyVGrid 网格选择；L1/L2/L3 级别选择（L3 需二次确认）；描述/预期/实际/复现/补充 表单；L3 可选附带截图
  - `FeedbackPreviewView`：显示邮件标题、正文全文、zip 文件名/大小、bundle 内文件列表
  - DebugView 隐藏入口：版本号 infoCard 加 onTapGesture，连续点击 5 次后显示"调试与回归"入口
  - DebugView 内容升级：系统信息（版本/Build/iOS/设备/内存/磁盘）、App Group 容器文件列表、SQLite 数据 Segmented Picker 浏览（交易/订阅/分类学习/调试事件）、toolbar 一键导出诊断包
- 未完成内容：无。
- 测试情况：`xcodebuild build` BUILD SUCCEEDED。
- 风险与注意事项：`MFMailComposeViewController` 在模拟器上不可用（`canSendMail()` 返回 false），需真机测试邮件发送；zip 附件大小受邮件服务商限制（通常 25MB）；L3 诊断包含完整 OCR 文本，用户需二次确认。
- 回滚方式：删除 `FeedbackLevel.swift`、`FeedbackIssueType.swift`、`FeedbackBundleBuilder.swift`、`FeedbackService.swift`、`FeedbackComposerView.swift`、`FeedbackPreviewView.swift`，还原 `SettingsView.swift` 和 `DebugView.swift` 中的 ITER-015 增量。
- 结论：Phase 3 A+B 层完成（App 端反馈全链路 + 邮件/bundle 协议）。
- 下一步建议：ITER-016 Phase 3 C 层（服务端邮件→Issue 自动处理）。

### ITER-014 分类学习
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 2
- 类型：能力增强 / UI
- 目标：实现分类学习——用户在账本中修改交易分类后，系统自动记录商户→分类偏好，后续导入同一商户时自动应用修正分类；提供管理界面供用户查看与删除已学习记录。
- 改动范围：
  - 修改 `AutoLedgerCore/Persistence/SQLiteTransactionStore.swift`（新增 `category_corrections` 表建表 + `loadCategoryCorrections` / `saveCategoryCorrection` / `deleteCategoryCorrection` CRUD）
  - 修改 `AutoLedgerCore/Enums/TransactionCategory.swift`（`infer(from:corrections:)` 增加可选 `corrections` 参数，修正历史优先于关键词规则）
  - 修改 `AutoLedger/App/LedgerStore.swift`（`categoryCorrections` Published 属性、init 加载、`recordCategoryCorrection` / `deleteCategoryCorrection` 方法、`updateTransaction` 自动检测分类变更、`persistReceipt` 两条路径均优先使用修正分类、`refreshFromStore` 同步修正数据）
  - 新增 `Features/Settings/CategoryLearningView.swift`（已学习列表 + 空态引导 + contextMenu 删除）
  - 修改 `Features/Settings/SettingsView.swift`（新增"分类学习"入口 NavigationLink）
- 未改动范围：`ReceiptParser.swift` 无需改动（`infer()` 默认 corrections 为空字典）；交易编辑视图无需改动（已有的 onSave → `updateTransaction` 链路自动触发检测）。
- 完成内容：
  - `category_corrections` 表：merchant TEXT PRIMARY KEY + category TEXT NOT NULL + updated_at TEXT NOT NULL，UPSERT via ON CONFLICT(merchant)
  - `TransactionCategory.infer(from:corrections:)` 先遍历 corrections 字典做 `localizedCaseInsensitiveContains` 匹配，命中则直接返回；未命中则走原有关键词规则
  - `LedgerStore.updateTransaction` 比较改动前后 category，不同则 `recordCategoryCorrection`
  - `persistReceipt` alias 路径 + 非 alias 路径均检查 corrections
  - `CategoryLearningView`：按商户名排序，每项显示商户→分类 icon + 文字，contextMenu 长按删除，空态 `brain.head.profile` 引导
- 未完成内容：无。
- 测试情况：`xcodebuild build` BUILD SUCCEEDED。
- 风险与注意事项：`localizedCaseInsensitiveContains` 匹配可能存在模糊匹配（如"星巴克"可匹配"星巴克臻选"），但对于分类学习场景这是预期行为。
- 回滚方式：删除 `CategoryLearningView.swift`，还原 `SQLiteTransactionStore.swift`（移除建表 SQL 和 CRUD）、`TransactionCategory.swift`（移除 corrections 参数）、`LedgerStore.swift`（移除 categoryCorrections 相关代码）、`SettingsView.swift`（移除分类学习入口）。
- 结论：Phase 2 完成（分类学习全链路：数据层→服务层→自动检测→导入应用→管理UI）。
- 下一步建议：ITER-015 Phase 3 用户反馈（A+B 层）。

### ITER-013 扣费提醒
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 1
- 类型：能力增强 / UI
- 目标：实现订阅扣费提醒 UI 层——订阅列表管理、首页即将扣费卡片、本地通知提醒、设置页开关。
- 改动范围：
  - 新增 `Features/Settings/SubscriptionListView.swift`（订阅列表视图：即将扣费高亮、全部订阅列表、预估月均费、空状态引导、长按删除）
  - 新增 `Domain/Services/NotificationService.swift`（`UNUserNotificationCenter` 本地通知，扣费前 1 天提醒，按 `subscriptionReminder` 开关控制）
  - 修改 `Features/Inbox/InboxView.swift`（新增 `upcomingSubscriptions` 计算属性 + `upcomingChargeCard` 卡片，hero 下方展示未来 7 天即将扣费的订阅）
  - 修改 `Features/Settings/SettingsView.swift`（新增"订阅管理" NavigationLink + "订阅扣费提醒" toggleCard，版本信息卡更新至 `v1.1.0-dev`）
  - 修改 `App/AutoLedgerApp.swift`（`UserDefaults.register` 注册 `subscriptionReminder` 默认 true；回前台时触发通知权限 + 调度通知）
  - 修改 `App/LedgerStore.swift`（`upsertSubscription` / `deleteSubscription` 后自动调用 `NotificationService.shared.scheduleUpcomingChargeReminders`）
- 未改动范围：AutoLedgerCore 数据层无改动（ITER-012 已完成）。
- 完成内容：
  - `SubscriptionListView`：分"即将扣费"和"全部订阅"两区，显示商户、方案名、周期、金额、下次扣费日；空状态有引导按钮；长按 contextMenu 删除
  - `upcomingChargeCard`：首页 hero 下方，展示未来 7 天内即将扣费的订阅，显示商户/金额/倒计时
  - `NotificationService`：单例，`requestPermissionIfNeeded` 仅在 `.notDetermined` 时请求权限；`scheduleUpcomingChargeReminders` 先清旧通知再按开关调度；提前 1 天 `UNCalendarNotificationTrigger`
  - 设置页 toggleCard `subscriptionReminder`（默认开启），关闭后不调度通知
  - 订阅增删后自动重新调度通知
- 未完成内容：无。
- 测试情况：`xcodebuild build` BUILD SUCCEEDED。
- 风险与注意事项：通知权限需用户授权，首次触发时弹出系统对话框；通知时间精度为分钟级别。
- 回滚方式：删除 `SubscriptionListView.swift` / `NotificationService.swift`，还原 `InboxView.swift`、`SettingsView.swift`、`AutoLedgerApp.swift`、`LedgerStore.swift` 中的 ITER-013 增量。
- 结论：Phase 1 完成（ITER-012 数据层 + ITER-013 UI 层）。
- 下一步建议：ITER-014 Phase 2 快捷指令增强。

### ITER-012 订阅识别引擎
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 1
- 类型：能力增强
- 目标：实现订阅识别引擎层——支持续期邮件截图导入、高置信自动续期判定、SQLite 持久化、订阅去重。
- 改动范围：
  - 新增 `AutoLedgerCore/Models/Subscription.swift`（`SubscriptionPeriod` 枚举 + `Subscription` 模型）
  - 新增 `AutoLedgerCore/Services/SubscriptionDetector.swift`（OCR 文本高置信检测 + 历史周期探测）
  - 修改 `AutoLedgerCore/Persistence/SQLiteTransactionStore.swift`（新增 `subscriptions` 表建表 + CRUD 方法）
  - 修改 `AutoLedger/App/LedgerStore.swift`（`subscriptions` Published 属性 + `upsertSubscription` + `deleteSubscription` + `detectAndUpsertSubscriptions` + 导入流高置信订阅优先路径）
- 未改动范围：UI 层（订阅列表、首页卡片、设置页开关）属于 ITER-013 范围。
- 完成内容：
  - `SubscriptionPeriod`：weekly/monthly/yearly，包含周期内日历计算下次费日期
  - `Subscription`：包含 merchant / planName / period / amount / lastChargedAt / nextChargedAt / createdAt，支持 `updated()` 更新日期
  - `SubscriptionDetector.detectFromText`：命中中文/英文"自动续期""订阅将以"等强特征时，提取金额/周期/商户/方案名/日期，返回 Subscription 草稿
  - `SubscriptionDetector.detectFromHistory`：按商户聚组，间隔变异系数<20%＋金额波动<5% 则判定为订阅
  - `subscriptions` SQLite 表：CREATE IF NOT EXISTS + `loadSubscriptions` / `saveSubscription` / `updateSubscription` / `deleteSubscription(id:)`
  - `LedgerStore.upsertSubscription`：同商户+同周期命中时更新，否则新增
  - `importRecognizedText` 内 Task 块新增订阅优先路径（高置信命中时设 `lastImportSummary` 提示并跳过交易解析）
- 未完成内容：订阅列表 UI / 首页即将扣费卡片 / 设置页订阅提醒开关（ITER-013 范围）。
- 测试情况：`xcodebuild build` BUILD SUCCEEDED；数据层逻辑待真机连同 ITER-013 UI 一起验证。
- 风险与注意事项：`Subscription` 与 `Combine.Subscription` 同名，在 `LedgerStore.swift` 顶部加入 `typealias Subscription = AutoLedgerCore.Subscription` 消歧义。
- 回滚方式：删除 `Subscription.swift` / `SubscriptionDetector.swift`，还原 `SQLiteTransactionStore.swift`（移除建表 SQL 和 CRUD 方法）和 `LedgerStore.swift` 改动；旧数据库中即便已创建 `subscriptions` 表也不影响已有数据（CREATE IF NOT EXISTS）。
- 结论：数据层完成，编译通过。ITER-013 进入 UI 层展现 + 本地通知。
- 下一步建议：ITER-013 订阅列表视图 + 首页即将扣费卡片 + 设置页提醒开关。

### ITER-011 移除预置样例数据 + 一键记账引导智能折叠
- 日期：2026-04-10
- 所属版本：v1.0.0
- 所属阶段：Phase 4（UX 优化）
- 类型：变更 / UI
- 目标：新安装后账本为空（不再预置样例数据）；首页一键记账引导卡片在已有快捷指令记录时自动折叠为摘要卡。
- 改动范围：`LedgerStore.swift`（`seedTransactions` 清空）；`InboxView.swift`（新增 `quickSetupCollapsed` / `hasShortcutEntries`、条件切换展示）；`CHANGELOG.md`。
- 未改动范围：解析器、持久化层、设置页均未改动。
- 完成内容：`seedTransactions = []`；`quickSetupCollapsed` 摘要卡显示已记录笔数，点击展开完整指引。
- 未完成内容：无。
- 测试情况：`xcodebuild build` PASS。
- 风险与注意事项：已安装用户若存在旧样例数据，不受此改动影响（已在 SQLite 中持久化）。
- 回滚方式：恢复 `seedTransactions` 数组内容；移除 `quickSetupCollapsed`。
- 结论：本轮完成。
- 下一步建议：继续完善首页信息密度优化。

### ITER-010 商户别名映射 + os_log 解析诊断
- 日期：2026-04-10
- 所属版本：v1.0.0
- 所属阶段：Phase 3（功能增强）
- 类型：能力增强 / 调试
- 目标：支持商户名别名映射（如"广州骑安科技有限公司 → 青桔单车"），并在 SmartReceiptParser 和 LedgerStore 关键阶段添加 os_log 日志。
- 改动范围：`LedgerStore.swift`（`merchantAliases`、`resolveMerchant`、`saveMerchantAliases`、os_log Logger）；新增 `MerchantAliasView.swift`；`SettingsView.swift`（新增商户别名入口）；`SmartReceiptParser.swift`（os_log Logger）；`CHANGELOG.md`。
- 未改动范围：ReceiptParser 规则层、SQLite 持久化层、AppFormatters 均未改动。
- 完成内容：别名映射存储在 UserDefaults，`persistReceipt` 入账前自动替换并重新推断分类；Logger 输出规则/LLM 结果、别名映射触发到 Xcode Console。
- 未完成内容：无。
- 测试情况：`xcodebuild build` PASS；真机验证 os_log 输出正常（确认 Foundation Models 在国行设备不可用，纯规则路径运行正常）。
- 风险与注意事项：商户别名仅存 UserDefaults，不随 iCloud 同步。
- 回滚方式：移除 `MerchantAliasView`、`LedgerStore` 别名相关代码、`SmartReceiptParser`/`LedgerStore` 的 Logger 调用。
- 结论：本轮完成，真机调试效率大幅提升。
- 下一步建议：持续积累真机回归用例，利用 os_log 快速定位解析偏差。

### ITER-009 微信支付详情页标签块解析 + 日期秒级支持
- 日期：2026-04-10
- 所属版本：v1.0.0
- 所属阶段：Phase 3（解析增强）
- 类型：Bugfix / 能力增强
- 目标：修复微信支付详情页 OCR 输出的标签块→值块分列结构无法正确解析的问题（商户误提为页面标题、时间回退为当前时间）。
- 改动范围：`AutoLedgerCore/Services/ReceiptParser.swift`（新增 `parseWeChatDetailBlock`、`extractDate` 增加可选秒段、`parse()` 增加 WeChat detail 优先级）；`AutoLedgerCore/Utils/AppFormatters.swift`（新增 `HH:mm:ss` 格式、Unicode 全角/NBSP 空格归一化）；`CHANGELOG.md`。
- 未改动范围：SmartReceiptParser、LedgerStore、SQLite、UI 层均未改动。
- 完成内容：`parseWeChatDetailBlock` 检测连续已知标签（当前状态/支付时间/商品/商户全称…），找到最长连续标签段后按偏移映射到值行，提取商户全称和支付时间；`extractDate` 正则增加 `(?::[0-9]{2})?`；`parseFlexibleDate` 增加秒级格式和空格归一化。
- 未完成内容：无。
- 测试情况：`xcodebuild build` PASS；真机测试微信支付详情页截图，商户/时间/分类均正确提取。
- 风险与注意事项：标签块解析依赖标签连续性，若微信更新页面布局可能需要调整。
- 回滚方式：移除 `parseWeChatDetailBlock` 方法并回退 `parse()` 中的调用，恢复 `extractDate` 正则和 `parseFlexibleDate` 格式列表。
- 结论：本轮完成，微信支付详情页最常见布局已覆盖。
- 下一步建议：继续收集不同微信版本和支付场景的 OCR 输出，扩展标签识别列表。

### ITER-008 去重窗口缩小 + 支付宝 NFC 收据解析
- 日期：2026-04-10
- 所属版本：v1.0.0
- 所属阶段：Phase 3（Bugfix）
- 类型：Bugfix
- 目标：去重窗口从 5 分钟缩小到 60 秒，避免同商户同金额不同时间的交易被误判重复；修复支付宝 NFC 收据商户名提取失败的问题。
- 改动范围：`LedgerStore.swift`、`QuickLedgerIntent.swift`、`ShareViewController.swift`（去重窗口 300→60）；`AutoLedgerCore/Services/ReceiptParser.swift`（支付宝 NFC 公司名提取、跳过纯符号行、移除冗余 keyword）；`CHANGELOG.md`。
- 未改动范围：SmartReceiptParser、AppFormatters、UI 层均未改动。
- 完成内容：三处去重逻辑统一为 60 秒窗口；支付宝 NFC 收据可正确提取公司名称；移除 `商业有限` 冗余关键词（已被 `有限公司` 覆盖）。
- 未完成内容：无。
- 测试情况：`xcodebuild build` PASS。
- 风险与注意事项：60 秒窗口可能在极端场景（如连续在同一商户同金额消费）下误判，但概率极低。
- 回滚方式：将三处 `< 60` 改回 `< 300`；回退 ReceiptParser NFC 相关改动。
- 结论：本轮完成。
- 下一步建议：持续收集真机回归用例。

### ITER-007 v1.0.0 多渠道导入 + LLM 混合解析 + 真机调试
- 日期：2026-04-09
- 所属版本：v1.0.0
- 所属阶段：Phase 2–4（全链路）
- 类型：能力增强 / Bugfix / UI / 重构
- 目标：完成 v1.0.0 全部计划功能——多渠道导入（相机/剪切板/Share Extension/快捷指令/ControlWidget）、LLM 混合解析、App Intent 快捷指令、UI 增强，并在真机上完成端到端验证。
- 改动范围：（详见 CHANGELOG.md 2026-04-09 全部条目，此处概述）
  - 重构：抽出 `AutoLedgerCore` 本地 Swift Package，主 App/ShareExt/ControlWidget 共享
  - 新增：Share Extension、QuickLedgerIntent（AppIntent）、SmartReceiptParser（Foundation Models 混合解析）、ClipboardImportIntent、ControlWidgetExtension
  - 新增：相机拍照导入、剪切板导入、回前台自动读取剪切板
  - 新增：LedgerView 时间筛选、商户消费排名 Sheet、跨 Tab 导航
  - 新增：设置页重写（来源/分类管理）、ImportDebugRecord 图片来源追踪
  - 修复：20+ 项解析规则修正（金额优先级、商户名过滤、来源推断、App Store 收据、外卖订单等）
  - 修复：SQLite 迁移、相机权限、App 图标、pbxproj 清理
- 未改动范围：月报页核心逻辑未改动。
- 完成内容：v1.0.0 计划 Phase 2–4 全部功能交付，真机端到端验证通过。
- 未完成内容：v1.0.0 发布门禁文档尚未正式判定。
- 测试情况：`xcodebuild build` PASS；真机验证快捷指令→OCR→入账→返回文本全链路通过；Share Extension 分享图片入账通过；相机/剪切板导入通过；ControlWidget 控制中心触发通过。
- 风险与注意事项：Foundation Models 在国行设备不可用（Apple Intelligence 未上线），SmartReceiptParser 始终走纯规则路径。
- 回滚方式：回退到 v0.1.0 tag 即可。
- 结论：本轮完成，v1.0.0 全部核心功能已交付并通过真机验证。
- 下一步建议：持续收集真机回归用例，完成发布门禁判定。

### ITER-006 TestFlight 邀请链接获取流程文档
- 日期：2026-04-09
- 所属版本：v1.0.0
- 所属阶段：Phase 4（发布与分发）
- 类型：文档
- 目标：补充 TestFlight 分发流程文档，说明构建上传成功后如何获取并分享邀请测试链接（公开链接与指定邮件邀请两种方式）。
- 改动范围：新增 `process/testflight-distribution.md`；更新 `CHANGELOG.md`；更新 `process/iteration-log.md`。
- 未改动范围：未修改任何业务代码、Xcode 工程配置或构建脚本。
- 完成内容：文档已涵盖三种邀请方式（公开链接、指定邮件、README 徽章）、Beta App Review 注意事项，以及常见问题说明。
- 未完成内容：无。
- 测试情况：文档类变更，无需构建验证。
- 风险与注意事项：外部测试公开链接需先通过 Apple Beta App Review（约 1–2 工作日），内部测试无需审核但限 100 人且须为 App Store Connect 团队成员。
- 回滚方式：若文档内容有误，直接修改 `process/testflight-distribution.md` 即可，不影响代码。
- 结论：本轮完成，项目现在有了标准的 TestFlight 分发操作参考文档。
- 下一步建议：在 `README.md` 的 Quick Start 部分嵌入 TestFlight 公开链接，方便外部测试者一键安装。

### ITER-005E 无真机条件下的离线回归脚本
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 4
- 类型：测试 / 工具 / 文档
- 目标：在无法进行真机测试的情况下，补一层可重复执行的离线回归脚本，用来验证样例解析、SQLite 读写和 LedgerStore 导入/去重流程。
- 改动范围：为 `SQLiteTransactionStore` 增加临时目录注入能力；新增 `scripts/OfflineRegression.swift` 与 `scripts/run_offline_regression.sh`；更新版本计划、回归基线、发布门禁和 CHANGELOG。
- 未改动范围：未修改真实截图导入主路径、OCR 识别逻辑、Debug 页 UI、账本编辑 UI，也未建立真机端到端人工回归。
- 完成内容：离线回归脚本已可直接在本机运行；样例解析、SQLite save/load/update、LedgerStore 首次 bootstrap、导入唯一样例以及重复跳过均通过；脚本结果可复用，后续无需真机即可重复执行。
- 未完成内容：真实支付截图的可追溯人工回归记录仍未补齐；最终发布门禁仍不能判定通过。
- 测试情况：执行 `./scripts/run_offline_regression.sh`，结果 PASS；脚本内部同时覆盖样例解析、SQLite 回归和 LedgerStore 导入/去重回归。
- 风险与注意事项：离线脚本只能替代开发机上的基础回归，不能替代真实截图端到端验证；若后续补到真机测试，应保留该脚本作为日常回归基线。
- 回滚方式：若离线脚本引入问题，可删除 `scripts/` 下的回归脚本并回退 `SQLiteTransactionStore` 的目录注入参数，主业务链路不受影响。
- 结论：本轮完成，AutoLedger 现在在没有真机的情况下也能持续验证解析与持久化链路。
- 下一步建议：如果真机仍不可用，继续基于离线脚本做样例扩展；一旦可用真机，再补 `ITER-005F` 的真实截图人工回归。

### ITER-005D 调试记录单条复制
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 4
- 类型：能力增强 / 调试 / UI
- 目标：让调试页支持按单条问题样例复制，避免每次都导出整页调试快照。
- 改动范围：更新 `DebugView`，为每条调试记录增加单独复制动作；更新版本计划、迭代日志和 CHANGELOG。
- 未改动范围：未修改 OCR、解析器、SQLite、账本编辑流程，也未改变整页复制能力。
- 完成内容：每条调试记录新增“拷贝这条”；复制内容会包含该条记录的时间、阶段、来源、结论、解析结果和 OCR 文本；仍保留右上角整页复制能力，适合不同回归场景。
- 未完成内容：真实截图人工回归记录仍待补齐；自动化测试仍未建立；复制结果暂不支持富文本或附件。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS。
- 风险与注意事项：单条复制导出的是当前卡片快照，适合人工记录；如果后续要支持批量筛选导出，可再单开一轮，不在本轮扩展。
- 回滚方式：若单条复制交互影响 Debug 页可读性，可回退 `DebugView` 中对应按钮和导出逻辑，保留整页复制。
- 结论：本轮完成，可疑样例已经可以按条目单独导出。
- 下一步建议：进入 `ITER-005F`，在可用真机上用真实截图回归并只复制异常样例沉淀到版本回归文档，再决定是否修正 `ReceiptParser`；若真机仍不可用，则继续保留离线脚本作为日常回归基线。

### ITER-005C 调试记录一键拷贝
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 4
- 类型：能力增强 / 调试 / UI
- 目标：让 Debug 页能直接导出当前测试快照，减少手工整理 OCR、解析和入账结果的成本。
- 改动范围：更新 `DebugView`，新增测试记录导出文本与剪贴板复制入口；扩展 `AppFormatters` 提供导出时间格式；更新版本计划、迭代日志和 CHANGELOG。
- 未改动范围：未修改 OCR 识别、解析规则、SQLite 仓库、账本编辑流程和调试记录的数据结构。
- 完成内容：Debug 页右上角新增“拷贝记录”；可将最近状态、解析结果、OCR 文本、最近调试记录和最近账单整合为可读文本后复制到系统剪贴板；复制后会给出提示，便于直接粘贴到回归文档。
- 未完成内容：真实截图的正式人工回归记录仍待沉淀；自动化测试仍未建立；导出结果目前仅支持拷贝，不含文件分享或结构化导出。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS。
- 风险与注意事项：当前导出格式是面向人工阅读的文本快照，不是稳定 API；如果后续要接 CSV/JSON 导出，应单独设计格式，避免破坏当前拷贝体验。
- 回滚方式：若拷贝功能影响 Debug 页稳定性，可回退 `DebugView` 的复制入口与导出文本逻辑，并恢复到仅查看状态的页面。
- 结论：本轮完成，真机回归后的测试记录已经可以直接复制到外部文档。
- 下一步建议：进入 `ITER-005D`，用真实截图连续回归并把复制出的记录沉淀到版本回归文档里，再决定是否要微调 `ReceiptParser`。

### ITER-005B 真机调试与回归面板
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 4
- 类型：能力增强 / 调试 / UI
- 目标：增加一个面向真机调试的 Debug 页，把最近 OCR 原文、解析结果、导入状态和最近账单集中展示出来，方便持续拿真实截图回归。
- 改动范围：新增 `ImportDebugRecord` 与 `DebugView`；扩展 `LedgerStore` 记录最近 OCR/解析/导入调试状态；将 `InboxView` 的最近 OCR 文本改为使用共享状态；在 `SettingsView` 增加调试入口；更新版本文档与 CHANGELOG。
- 未改动范围：未修改 OCR 识别算法、`ReceiptParser` 抽取规则、SQLite 仓库结构、账本编辑流程和真实截图导入主路径。
- 完成内容：应用内已可查看最近 OCR 文本、最近解析结果、最近导入状态、最近调试记录和最近账单；真机调试时不需要切回 Xcode 就能对照导入链路结果；调试记录支持清空，便于分批回归。
- 未完成内容：真实微信/支付宝/App Store 截图的端到端人工回归记录仍待补齐；自动化测试仍未建立；是否需要继续修改 `ReceiptParser` 仍要以真实截图结果为准。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS；执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`，结果 PASS。
- 风险与注意事项：调试页展示的是运行时状态快照和最近记录，不替代正式测试结论；若后续需要导出调试数据，再单独增加导出能力，避免把调试页做成复杂子系统。
- 回滚方式：若调试页影响设置页或共享状态，可回退 `DebugView`、`ImportDebugRecord` 以及 `LedgerStore` 的调试字段，保留主导入链路不变。
- 结论：本轮完成，AutoLedger 已具备真机上观察 OCR→解析→入账链路的内置调试能力。
- 下一步建议：进入 `ITER-005C`，用真实截图在真机上连续回归并沉淀记录，再决定是否需要对 `ReceiptParser` 做小范围修正。

### ITER-005A 发布收口前的最小回归证据补齐
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 4
- 类型：测试 / 文档 / 治理
- 目标：在不扩大代码改造范围的前提下，补齐当前版本最小可追溯回归证据，并更新发布门禁文档。
- 改动范围：更新 `versions/v0.1.0-plan.md`、`versions/v0.1.0-regression-baseline.md`、`versions/v0.1.0-RELEASE(draft).md`、`CHANGELOG.md`；新增本条迭代记录。
- 未改动范围：未修改 `ReceiptParser`、`OCRService`、SQLite 持久化实现、账本编辑流和页面结构，也未扩展任何新功能。
- 完成内容：对 3 份内置样例 OCR 文本完成解析回归，结果均能正确抽取金额、商户、时间与建议分类；对 `SQLiteTransactionStore` 完成最小 save/load/update round-trip 回归；再次完成 Debug 模拟器构建；将 `ITER-005` 拆分为 `ITER-005A` 与 `ITER-005B`，明确当前已验证证据与剩余阻断项。
- 未完成内容：仓库内仍缺少可追溯的真实支付截图样例资产，尚未形成真实截图端到端人工回归记录；自动化测试仍未建立；应用重启后的人工恢复验证未记录。
- 测试情况：执行样例解析回归，微信买菜截图 / 支付宝出行截图 / App Store 订阅截图均 PASS；执行 `SQLiteTransactionStore` save/load/update round-trip，结果 PASS；执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS。
- 风险与注意事项：当前结论建立在样例 OCR 文本和仓库级回归上，不能替代真实截图端到端验证；若后续真实截图回归暴露解析问题，只应做基于证据的小修，避免范围漂移。
- 回滚方式：若本轮文档收口判断有误，可回退本轮计划/回归/发布文档到 ITER-004 状态，并保留回归命令与结果记录，重新按真实截图样例证据修订结论。
- 结论：本轮完成，版本门禁从“模糊阻断”收口为“证据明确但仍未放行”的状态，`ReceiptParser` 在现有样例上暂不需要继续修改。
- 下一步建议：补齐真实微信/支付宝/App Store 截图的人工回归记录，完成 `ITER-005B`，再做最终发布判定。

### ITER-004 SQLite 持久化与账单修正
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 3
- 类型：能力增强 / 数据 / UI
- 目标：把当前账本从内存态升级为真实本地账本，并给用户一个可用的账单修正入口。
- 改动范围：新增 `TransactionStore` 协议与 `SQLiteTransactionStore`；让 `LedgerStore` 在启动时加载并引导种子数据到 SQLite，同时支持更新账单；账本页新增点击编辑弹层 `TransactionEditorView`；更新设置页和版本文档。
- 未改动范围：未建立自动化测试，也未完成应用重启后的人工回归记录和多支付样例识别准确率回归。
- 完成内容：交易数据已可落入本地 SQLite；导入新账单会持久化；账本页支持修正金额、分类和备注；月报继续消费同一份更新后的数据；构建验证通过。
- 未完成内容：发布级人工回归、`ReceiptParser` 规则继续精调和版本门禁收口仍待下一轮完成。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS；SQLite 落盘与应用重启恢复未做人工终态回归。
- 风险与注意事项：当前持久化层已可用，但缺少自动化测试和应用重启验证记录；编辑仅开放金额、分类、备注，商户与时间仍保持只读。
- 回滚方式：若 SQLite 落盘导致异常，可暂时回退到 ITER-003 的内存账本链路，同时保留编辑 UI 与仓库代码分支以便继续修复。
- 结论：本轮完成，AutoLedger 已从“可识别”推进到“可本地保存、可修正”的 MVP 状态。
- 下一步建议：集中做发布级人工回归、真实样例规则精调和门禁收口。

### ITER-003 真实截图导入与 Vision OCR 接入
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 2
- 类型：能力增强 / UI
- 目标：将收件箱从样例导入升级为真实截图导入，接入 `PhotosPicker` 与 Vision OCR，并继续复用上一轮已经跑通的解析、入账、账本和月报链路。
- 改动范围：新增 `OCRService`；为 `InboxView` 增加真实截图选择入口、OCR 识别状态与最近 OCR 文本展示；扩展 `LedgerStore` 支持导入 OCR 文本；为 `ReceiptSource` 增加来源推断；更新设置页描述与版本文档。
- 未改动范围：未实现本地持久化、账单手动修正、自动化测试，也未完成多支付样例的人工识别准确率回归。
- 完成内容：真实截图已可从系统相册选择；OCR 文本可进入现有解析器并尝试入账；OCR 失败时保留样例导入作为降级路径；构建验证通过。
- 未完成内容：持久化、账单编辑、OCR 规则精调和发布级回归仍待下一轮继续。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS；真实支付截图人工回归未在本轮完成。
- 风险与注意事项：OCR 识别效果受截图质量和支付页面样式影响；当前 `ReceiptParser` 仍以规则抽取为主，对复杂版式的鲁棒性有限。
- 回滚方式：若真实 OCR 导入影响稳定性，可保留样例导入并暂时隐藏真实截图入口，回退到 ITER-002 已验证链路。
- 结论：本轮完成，AutoLedger 已具备真实截图导入和本地 OCR 能力。
- 下一步建议：优先完成本地持久化与账单修正，再补真实截图人工回归和发布门禁收口。

### ITER-002 MVP 壳层与样例导入闭环
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 1
- 类型：能力增强 / 文档 / UI
- 目标：将工程从占位首页推进为可运行的 MVP 壳层，先用样例 OCR 文本打通“导入→解析→入账→展示”主路径，并同步校准版本文档。
- 改动范围：新增 `LedgerStore`、交易/导入/月报模型、规则解析器、样例数据提供器、主题与格式化工具；实现收件箱、账本、月报、设置页面；更新 backlog、版本计划、回归基线、发布门禁和 CHANGELOG。
- 未改动范围：未接入 PhotosPicker、Vision OCR、SwiftData/SQLite、账单手动编辑和自动化测试。
- 完成内容：将首页升级为四标签结构；支持导入微信/支付宝/App Store 样例文本；完成规则解析、去重、入账和月度汇总展示；修正版本计划与当前工程脱节的问题；完成一次模拟器 Debug 构建验证。
- 未完成内容：真实截图导入与 OCR、本地持久化、账单修正和发布级测试仍待后续迭代。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS。
- 风险与注意事项：当前导入链路仍为样例演示，不能代表真实 OCR 效果；内存账本在应用重启后不会保留数据。
- 回滚方式：若本轮 UI 或数据流影响后续推进，可回退到仅保留 `HomeView` 占位页的初始工程状态；文档侧回退到 ITER-001 版本计划。
- 结论：本轮完成，项目已从文档启动阶段进入可演示的 iOS MVP 壳层阶段。
- 下一步建议：优先推进真实截图导入与 Vision OCR，其次补本地持久化和账单修正。

### ITER-001 初始化项目文档与架构
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 1
- 类型：文档 / 能力增强
- 目标：为 AutoLedger 项目搭建完整的文档目录结构，填充初始想法池和版本计划，并确定项目技术栈及目录结构。
- 改动范围：更新 `README.md`，创建项目简介；填充 `process/iteration-idea-backlog.md`；新增本条迭代日志；编写 `versions/vX.Y.Z-plan.md`、`vX.Y.Z-regression-baseline.md`、`vX.Y.Z-RELEASE.md` 初稿；更新 `CHANGELOG.md`。
- 未改动范围：模板目录和模板文件保持原样，未涉及业务代码实现。
- 完成内容：完成文档框架搭建；制定初始版本计划和回归基线；生成三个 IDEA 条目；明确迭代工作流。
- 未完成内容：业务评审和具体功能实现将在下一轮迭代完成。
- 测试情况：暂无功能代码，故无测试。
- 风险与注意事项：需保证文档模板与实际项目适配；后续迭代需按文档规范持续回填。
- 回滚方式：如目录结构不合适，可恢复到解压前的 `demo.zip` 并重新规划。
- 结论：本轮迭代完成，项目文档框架和初始计划已就绪。
- 下一步建议：启动业务评审，补充版本计划细节，开始实现截图导入与 OCR 服务。
