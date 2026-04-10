# 迭代想法池

更新日期：2026-04-10

## 状态说明

- NEW
- REVIEWING
- ACCEPTED
- SPLIT
- DEFERRED
- REJECTED
- DONE

## 优先级说明

- P0：当前阻塞/线上风险
- P1：当前版本应纳入
- P2：后续版本可纳入
- P3：长期观察项

## 条目模板

```markdown
### IDEA-XXX 标题
- 状态：NEW
- 优先级：P2
- 来源：
- 日期：YYYY-MM-DD
- 建议版本：
- 相关模块：
- 描述：
- 价值：
- 风险：
- 结论：
- 原因：
- 已落地产物：
```

## 使用规则

- 新想法默认先入池，不直接插队
- ACCEPTED 后进入版本计划
- DONE 后补充已落地产物与链接

## 想法条目

下面列出了当前项目（AutoLedger）的部分核心想法条目。新增想法时请按照上方模板填写。

### IDEA-001 截图导入与OCR识别
- 状态：SPLIT
- 优先级：P1
- 来源：用户需求
- 日期：2026-03-27
- 建议版本：v0.1.0
- 相关模块：OCRService，ReceiptParser，CategoryClassifier
- 描述：实现对微信、支付宝和 App Store 等支付成功页面截图的导入，并通过 Vision OCR 抽取金额、商户、时间等结构化字段。
- 价值：解决用户手动记账的痛点，实现快速补录，保证账目完整性。
- 风险：iOS 系统权限限制需要用户授权；不同支付页面格式多样可能影响识别率。
- 结论：已拆分为可执行子 IDEA，按主路径分轮推进。
- 原因：当前工程仍处于 0→1 阶段，需先固定应用骨架，再接入真实截图与持久化。
- 已落地产物：`versions/v0.1.0-plan.md`、`process/iteration-log.md`、MVP 壳层代码。

### IDEA-002 订阅识别与扣费提醒
- 状态：ACCEPTED
- 优先级：P1
- 来源：用户需求
- 日期：2026-03-27
- 建议版本：v1.1.0
- 相关模块：SubscriptionDetector，NotificationService
- 描述：通过分析历史交易记录，识别出具有周期性的订阅扣费，提供下次扣费预测及提醒。
- 价值：帮助用户及时发现遗忘的订阅并进行财务规划，避免不必要的自动扣费。
- 风险：订阅金额和周期存在波动导致误识别；预测算法需在本地实现以保护隐私。
- 结论：待业务评审后再决定是否纳入下一版本。
- 原因：提升项目差异化和用户粘性，但不属于 MVP 核心。
- 已落地产物：

### IDEA-003 月度消费汇总与异常分析
- 状态：ACCEPTED
- 优先级：P2
- 来源：用户需求
- 日期：2026-03-27
- 建议版本：v1.1.0（周期检测前置）/ v1.2.0（异常分析主体）
- 相关模块：MonthlyInsight，NotificationService
- 描述：在每月结束时自动生成消费报告，包括各分类支出统计、环比变化、最常消费商户以及异常支出提醒。
- 价值：为用户提供消费可视化和趋势洞察，帮助优化预算和消费决策。
- 风险：统计口径和分类准确度需要保证；报告生成时间需要考虑用户体验。
- 结论：待完成核心功能后，再纳入下一版本评审。
- 原因：属于增强分析功能，可在基础记账功能稳定后推进。
- 已落地产物：

### IDEA-004 MVP 壳层与样例导入闭环
- 状态：DONE
- 优先级：P1
- 来源：IDEA-001 拆分
- 日期：2026-03-27
- 建议版本：v0.1.0
- 相关模块：HomeView，InboxView，LedgerStore，ReceiptParser，ReportView
- 描述：先搭建可运行的本地主路径，用样例 OCR 文本替代真实截图导入，打通“导入示例→规则解析→入账→账本/月报展示”。
- 价值：先验证信息架构、数据流和 UI 主路径，降低后续接入 Photos 与 Vision OCR 的改动风险。
- 风险：样例导入与真实截图存在差异，不能代表真实识别效果。
- 结论：已完成，作为 ITER-002 的交付物保留。
- 原因：当前工程代码基础过薄，先把壳层跑通比直接堆 OCR 更稳。
- 已落地产物：`AutoLedger/AutoLedger/App/LedgerStore.swift`、`AutoLedger/AutoLedger/Features/Inbox/InboxView.swift`、`AutoLedger/AutoLedger/Features/Ledger/LedgerView.swift`、`AutoLedger/AutoLedger/Features/Report/ReportView.swift`

### IDEA-005 相册导入与 Vision OCR 接入
- 状态：DONE
- 优先级：P1
- 来源：IDEA-001 拆分
- 日期：2026-03-27
- 建议版本：v0.1.0
- 相关模块：OCRService，InboxView，ReceiptParser
- 描述：将当前样例导入替换为真实支付截图导入，接入 PhotosPicker 与 Vision OCR，输出可确认的识别草稿。
- 价值：打通 v0.1.0 的核心差异化能力，让产品从演示壳层进入真实可用阶段。
- 风险：图片权限、OCR 误识别、多支付平台样式差异会直接影响识别成功率。
- 结论：已完成代码接入，作为 ITER-003 的交付物保留。
- 原因：已接上真实截图导入与 OCR 识别，但仍需后续人工回归更多支付样例。
- 已落地产物：`AutoLedger/AutoLedger/Domain/Services/OCRService.swift`、`AutoLedger/AutoLedger/Features/Inbox/InboxView.swift`、`AutoLedger/AutoLedger/Domain/Enums/ReceiptSource.swift`

### IDEA-006 本地持久化与账单修正
- 状态：DONE
- 优先级：P1
- 来源：IDEA-001 拆分
- 日期：2026-03-27
- 建议版本：v0.1.0
- 相关模块：Database，TransactionRepository，LedgerView
- 描述：把当前内存账本替换为 SwiftData 或 SQLite 持久化，并提供金额、分类、备注的手动修正能力。
- 价值：确保用户关闭 App 后数据不丢失，也让 OCR 误差有修正出口。
- 风险：数据迁移和编辑状态管理会提高实现复杂度。
- 结论：已完成代码接入，作为 ITER-004 的交付物保留。
- 原因：本地账本已写入 SQLite，账本页也已支持金额、分类、备注修正。
- 已落地产物：`AutoLedger/AutoLedger/Data/Persistence/SQLiteTransactionStore.swift`、`AutoLedger/AutoLedger/Data/Persistence/TransactionStore.swift`、`AutoLedger/AutoLedger/Features/Ledger/TransactionEditorView.swift`

### IDEA-007 月度汇总收口与发布门禁
- 状态：ACCEPTED
- 优先级：P1
- 来源：IDEA-001 拆分
- 日期：2026-03-27
- 建议版本：v0.1.0
- 相关模块：ReportView，v0.1.0-regression-baseline，v0.1.0-RELEASE(draft)
- 描述：在真实导入与持久化接入后，完成月度汇总页收口、最小回归包确认和版本门禁更新。
- 价值：保证 v0.1.0 不是功能堆叠，而是能被稳定发布的一版。
- 风险：若前序 OCR/持久化不稳定，收口阶段容易被迫返工。
- 结论：接受并纳入当前版本尾段迭代。
- 原因：版本需要有可执行门禁，不能长期停留在“文档 PASS、功能未完成”的状态。
- 已落地产物：基础月报页面、构建验证命令、修订中的门禁文档。

### IDEA-008 微信支付详情页标签块解析
- 状态：DONE
- 优先级：P0
- 来源：真机回归发现
- 日期：2026-04-10
- 建议版本：v1.0.0
- 相关模块：ReceiptParser，AppFormatters
- 描述：微信支付详情页 OCR 输出为标签块→值块分列结构（当前状态/支付时间/商户全称…连续排列，值按相同顺序跟随），原解析器无法识别该布局，商户误提为页面标题、时间回退为当前时间。
- 价值：覆盖微信支付最常见的详情页格式，大幅提升真实场景命中率。
- 风险：不同微信版本的 OCR 布局可能有差异。
- 结论：已完成并推送，`parseWeChatDetailBlock` 方法通过最长连续标签段偏移定位值块。
- 原因：P0 级真机阻断问题，影响核心记账准确性。
- 已落地产物：`AutoLedgerCore/Services/ReceiptParser.swift`（新增 `parseWeChatDetailBlock`）；`AutoLedgerCore/Utils/AppFormatters.swift`（HH:mm:ss + Unicode 空格归一化）；commit `8e722a3`。

### IDEA-009 商户别名映射
- 状态：DONE
- 优先级：P1
- 来源：用户需求
- 日期：2026-04-10
- 建议版本：v1.0.0
- 相关模块：LedgerStore，MerchantAliasView，SettingsView
- 描述：支持用户自定义商户名映射（如"广州骑安科技有限公司 → 青桔单车"），解析入账时自动替换商户名并重新推断分类。
- 价值：解决 OCR 解析出的商户全称对用户不友好的问题，提升账本可读性。
- 风险：别名不当可能导致分类推断偏差。
- 结论：已完成，设置页新增商户别名管理入口。
- 原因：真实使用中大量商户名为公司全称，用户难以辨认。
- 已落地产物：`MerchantAliasView.swift`、`LedgerStore.swift`（`resolveMerchant`）、`SettingsView.swift`；commit `da68408`。

### IDEA-010 解析链路 os_log 诊断日志
- 状态：DONE
- 优先级：P1
- 来源：开发调试需求
- 日期：2026-04-10
- 建议版本：v1.0.0
- 相关模块：SmartReceiptParser，LedgerStore
- 描述：在 SmartReceiptParser 和 LedgerStore 关键阶段添加 os_log 日志，输出规则/LLM 解析结果、别名映射等，方便在 Xcode Console 实时调试。
- 价值：取代 print 调试，支持按 category 过滤，提升真机调试效率。
- 风险：无。
- 结论：已完成。
- 原因：真机调试时无法查看 print 输出，需要结构化日志。
- 已落地产物：`SmartReceiptParser.swift`、`LedgerStore.swift`；commit `da68408`。

### IDEA-011 一键记账引导卡片智能折叠
- 状态：DONE
- 优先级：P2
- 来源：UX 优化
- 日期：2026-04-10
- 建议版本：v1.0.0
- 相关模块：InboxView
- 描述：当账本中已有快捷指令入账记录时，首页「一键记账」引导卡片自动收起为摘要卡（"一键记账已开启 · 已记录 N 笔"），点击可展开完整操作指引。
- 价值：老用户不再被大面积引导卡遮挡，新用户仍能看到完整引导。
- 风险：无。
- 结论：已完成。
- 原因：引导卡片占据过多首屏空间，对已配置用户无用。
- 已落地产物：`InboxView.swift`（`quickSetupCollapsed` + `hasShortcutEntries`）；commit `34201e4`。

### IDEA-012 移除冷启动预置样例数据
- 状态：DONE
- 优先级：P1
- 来源：产品定义
- 日期：2026-04-10
- 建议版本：v1.0.0
- 相关模块：LedgerStore
- 描述：新安装 App 后账本应为空，不再预置样例数据（Example Supermarket/滴滴出行/Apple Services）。
- 价值：避免用户困惑，保持账本真实干净。
- 风险：无。
- 结论：已完成。
- 原因：预置数据在 MVP 早期用于演示，现已进入真实使用阶段，不再需要。
- 已落地产物：`LedgerStore.swift`（`seedTransactions = []`）；commit `dfc95e6`。

### IDEA-013 支付宝 NFC 收据商户名提取
- 状态：DONE
- 优先级：P1
- 来源：真机回归发现
- 日期：2026-04-10
- 建议版本：v1.0.0
- 相关模块：ReceiptParser
- 描述：支付宝 NFC 收据格式商户名提取失败（误提为符号行），需识别公司名称格式并跳过纯符号行。
- 价值：扩展支付宝收据覆盖面。
- 风险：无。
- 结论：已完成。
- 原因：真机回归中发现的 P1 问题。
- 已落地产物：`AutoLedgerCore/Services/ReceiptParser.swift`；commit `73efba2`。

- 已落地产物：`ReceiptSource.swift`（新增 `.douyin` 来源）、`ReceiptParser.swift`（新增 `parseDouyinVoucher()`）、`ShareViewController.swift`（新增抖音 bundle ID 映射）、`SampleReceiptProvider.swift`（新增回归样例）、`OfflineRegression.swift`（新增回归断言）。

### IDEA-015 用户反馈闭环：App 端分级日志导出 → 邮件协议 → 服务端自动 Issue
- 状态：ACCEPTED
- 优先级：P1
- 来源：用户体验需求 + 运维效率需求
- 日期：2026-04-10
- 建议版本：v1.1.0
- 相关模块：SettingsView、DebugView、FeedbackService（新建）、`tools/feedback/`（新建）、GitHub Actions（新建）
- 设计输入文档：
  - `feedback_log_email_bundle_templates.md`（邮件标题/正文/附件 bundle 协议模板）
  - `tools_feedback_README_template.md`（服务端邮件→Issue 自动处理链路设计）
- 描述：
  搭建从 App 端到开发者的完整反馈链路，分三层：

  **A 层 — App 端（iOS 客户端）**
  1. **反馈入口**：设置页新增"问题反馈"按钮，点击后组装日志 → 预览 → 调起 `MFMailComposeViewController` 发送邮件。
  2. **日志分级**（L1/L2/L3）：
     - **L1 标准反馈（默认）**：App 版本 / 设备型号 / iOS 版本 / 最近 N 条脱敏操作日志（商户名/金额以占位符替代）/ 崩溃栈摘要。
     - **L2 增强调试**：+ 结构化解析结果（OCR 片段、规则/LLM 命中路径）、`trace.log`、`redacted_ocr_context.txt`；敏感字段自动正则脱敏（姓名、手机号、金额尾数）。
     - **L3 完整诊断**：+ `full_ocr_text.txt`、原始截图缩略图；需用户主动勾选二次确认。L3 仅内部/高级测试者开启。
  3. **脱敏与预览**：默认导出 L1，用户可逐级勾选升级；发送前弹出预览页，展示即将发送的完整内容，用户确认后才发送（核心原则：让用户放心）。
  4. **调试界面入口调整 + 内容升级**：DebugView 从设置页直达改为"多次点击当前版本号"后显示（类似开发者选项），普通用户不可见。既然入口已隐藏为开发者模式，DebugView 内容应 **≥ L3 且无脱敏限制**，额外展示：
     - 实时 SQLite 数据浏览（transactions / subscriptions / category_corrections / debug_events 表）
     - OCR 原始识别结果（全文，不脱敏）
     - 规则/LLM 解析路径详情 + 置信度
     - 最近 N 次导入的完整 trace（含时间戳、耗时）
     - App Group 容器文件列表与大小
     - 当前内存/磁盘使用概况
     - 一键导出完整诊断包（等同 L3 但不走邮件，直接 share sheet）
  5. **Fallback**：未配置邮件账户时降级为复制到剪切板 / 系统分享。

  **B 层 — 邮件/附件协议（App 输出规范）**
  1. **邮件标题格式**：`[AutoLedger][L{n}][iOS][{version}({build})][{issue_type}] 简短摘要`。
  2. **邮件正文**：上半部分自然语言（用户描述/预期/实际/复现性/时间），下半部分机器可解析 `AUTOLEDGER_FEEDBACK_META` 区块（feedback_level、issue_type、app_version、device_model 等）。
  3. **附件 bundle**：统一 zip 包 `AutoLedger_Feedback_{level}_{feedback_id}.zip`，内含 `issue_bundle.json`（结构化故障数据）、`summary.txt`、`metadata.json`，L2 额外含 `trace.log` + `redacted_ocr_context.txt`，L3 额外含 `full_ocr_text.txt` + 可选截图。
  4. **问题类型枚举**：`feedback` / `ocr_parse_wrong` / `merchant_parse_wrong` / `amount_parse_wrong` / `time_parse_wrong` / `save_failed` / `shortcut_flow` / `share_extension` / `camera_import` / `clipboard_import` / `ui_bug` / `performance` / `crash` / `other`。
  5. **Feedback ID 规则**：`AL-{vendorID_short6}-{yyyyMMddHHmmss}-{seq}`，全局唯一。`vendorID_short6` = `UIDevice.current.identifierForVendor` 的 SHA-256 前 6 位 hex，保证跨设备不碰撞；服务端以 `feedback_id` 为幂等键去重，相同 ID 不重复创建 Issue。

  **C 层 — 服务端自动处理（DevOps）**
  1. **邮件路由**：`support@darkrio326.top` → Cloudflare Email Routing → Gmail 收件箱。
  2. **GitHub Actions 定时任务**：每 15 分钟拉取 Gmail 未读反馈邮件（IMAP），解析标题前缀 `[AutoLedger]` 过滤。
  3. **邮件解析脚本** `tools/feedback/email_to_issue.py`：提取主题、正文、附件 → 解压 bundle → 读取 `issue_bundle.json` + `summary.txt` + `metadata.json` → 二次脱敏 → 调用 GitHub REST API 创建 Issue（含 label：`feedback`/`L1`/`L2`/`L3`/`issue_type`）→ 标记邮件已读。
  4. **人工分诊** → Copilot/Agent 辅助分析 → 人工 review + merge。
  5. **当前不做**：自动上传原始截图到 GitHub、自动创建 PR、自动合并修复。

- 完整链路：
  ```
  用户 App 内反馈 → MFMailComposeViewController → support@darkrio326.top
  → Cloudflare Email Routing → Gmail
  → GitHub Actions 定时拉取 → email_to_issue.py 解析
  → 自动创建 GitHub Issue（含 label + 结构化数据）
  → 人工筛选 → Copilot/Agent 辅助修复 → 人工 review + merge
  ```
- 价值：打通"用户一键反馈 → 开发者自动收到结构化 Issue"的完整闭环；降低反馈门槛 + 保护隐私 + 减少人工分诊成本。
- 风险：
  - A 层：`MFMailComposeViewController` 在未配置邮件账户设备不可用，需 fallback；日志体积过大时附件可能超限。
  - B 层：邮件协议变更需 App 端与服务端同步更新，存在版本不一致风险。
  - C 层：依赖 Gmail IMAP + Cloudflare Email Routing + GitHub API，任一环节故障会中断 Issue 自动创建；需监控告警。
- 落地节奏建议：
  - v1.1.0 Phase 4 ITER-015：A 层 + B 层（App 端生成符合协议的邮件与 bundle）
  - v1.1.0 Phase 4 ITER-016：C 层（服务端 `tools/feedback/` + GitHub Actions workflow）
  - 原 ITER-016 去重增强 → 顺延为 ITER-017
- 结论：已接受，纳入 v1.1.0 Phase 4（ITER-015 + ITER-016）。
- 原因：TestFlight 外测后用户反馈渠道是刚需；A+B+C 三层分离使客户端与服务端可独立迭代，协议层保证兼容性。
- 已落地产物:
