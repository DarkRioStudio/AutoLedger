# 迭代想法池

更新日期：2026-03-27

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
- 状态：NEW
- 优先级：P2
- 来源：用户需求
- 日期：2026-03-27
- 建议版本：v0.2.0
- 相关模块：SubscriptionDetector，NotificationService
- 描述：通过分析历史交易记录，识别出具有周期性的订阅扣费，提供下次扣费预测及提醒。
- 价值：帮助用户及时发现遗忘的订阅并进行财务规划，避免不必要的自动扣费。
- 风险：订阅金额和周期存在波动导致误识别；预测算法需在本地实现以保护隐私。
- 结论：待业务评审后再决定是否纳入下一版本。
- 原因：提升项目差异化和用户粘性，但不属于 MVP 核心。
- 已落地产物：

### IDEA-003 月度消费汇总与异常分析
- 状态：NEW
- 优先级：P2
- 来源：用户需求
- 日期：2026-03-27
- 建议版本：v0.2.0
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
