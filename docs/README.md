# AutoLedger Docs

> 文档状态：Canonical
> 真源范围：`docs/` 导航、文档生命周期和编写规则
> 最后核验：2026-07-17
> 当前状态：[../PROJECT_STATUS.md](../PROJECT_STATUS.md)
> 产品路线图：[ROADMAP.md](ROADMAP.md)

`docs/` 保存产品、架构、能力、平台、审计和工具设计资料。发布前采用逻辑分类，不大规模移动既有路径；路径重组留到 `v1.7.0` 发布后单独执行，以避免外部链接和历史引用在候选冻结期发生无关变化。

根目录 Markdown 只保留仓库入口和治理真源，例如 `README.md`、`PROJECT_STATUS.md`、`CHANGELOG.md`、`CONTRIBUTING.md`、`SECURITY.md` 与 `AGENTS.md`。版本执行计划放在 `versions/`，迭代流程与事实日志放在 `process/`。

## Status Definitions

| 状态 | 含义 |
|---|---|
| Canonical | 对一个明确范围拥有唯一真源职责 |
| Active | 当前仍用于设计或决策，但受上位真源约束 |
| Reference | 仍有参考价值，不代表当前完整实现 |
| Draft | 尚未冻结或仍需验证的草案 |
| Historical | 保留历史背景，不应用于判断当前状态 |
| Superseded | 已被其它文档替代，只保留兼容入口或历史 |

## Canonical Entry Points

| 文档 | 状态 | 职责 |
|---|---|---|
| [../PROJECT_STATUS.md](../PROJECT_STATUS.md) | Canonical | 当前版本、发布阶段、阻断、门禁和下一步 |
| [ROADMAP.md](ROADMAP.md) | Canonical | 产品方向、跨版本优先级、依赖和非目标 |
| [../versions/v1.7.0-plan.md](../versions/v1.7.0-plan.md) | Canonical | 当前版本范围、GOAL、测试与验收 |
| [../process/agent-iteration-workflow.md](../process/agent-iteration-workflow.md) | Canonical | 迭代方法、门禁与执行前检查 |
| [../process/iteration-log.md](../process/iteration-log.md) | Canonical | 每轮实施事实、风险、验证和回滚 |
| [../CHANGELOG.md](../CHANGELOG.md) | Canonical | 已完成变更历史 |

## Product And Entitlement

| 文档 | 状态 | 说明 |
|---|---|---|
| [autoledger-personal-pro-design.md](autoledger-personal-pro-design.md) | Active | Personal Pro 定位、Free / Pro 原则和酒店 / 邮箱自动化设计 |
| [autoledger-personal-pro-roadmap.md](autoledger-personal-pro-roadmap.md) | Active | Pro 专项路线图；优先级从 `ROADMAP.md` 派生，不是全局路线图 |
| [pro-access-audit.md](pro-access-audit.md) | Active | 当前客户端与服务端权益边界审计快照；执行真源仍是代码与测试 |
| [iap-support.md](iap-support.md) | Active | Support Developer 与 Pro IAP 支持说明 |
| [brand-assets-notice.md](brand-assets-notice.md) | Canonical | AutoLedger 品牌与商店资产授权边界 |

## Architecture And Recognition

| 文档 | 状态 | 说明 |
|---|---|---|
| [LedgerTextInterpreter.md](LedgerTextInterpreter.md) | Reference | 平台无关账单文本解释器设计；以当前 Core 代码和回归为执行真源 |
| [recognition-learning-cache-design.md](recognition-learning-cache-design.md) | Active | 商户、分类、订阅倾向和短期识别学习缓存设计 |
| [autoledger_icloud_backup_design.md](autoledger_icloud_backup_design.md) | Reference | 单文件备份 / 恢复设计，不是当前 CloudKit 同步完整真源 |
| [autoledgercore-platform-dependency-audit.md](autoledgercore-platform-dependency-audit.md) | Historical | 2026-06-11 AutoLedgerCore 平台依赖审计快照 |
| [minimum-platform-baseline-reduction-plan.md](minimum-platform-baseline-reduction-plan.md) | Historical | 已执行的最低平台基线下调规划与结果记录 |

## Capabilities And Tools

| 文档 | 状态 | 说明 |
|---|---|---|
| [autoledger_voice_siri_design.md](autoledger_voice_siri_design.md) | Reference | 语音记账与 Siri 交互设计 |
| [shortcuts-json-ledger-import.md](shortcuts-json-ledger-import.md) | Active | Shortcuts JSON 账单导入合同 |
| [ReceiptDebugTool-implementation-draft.md](ReceiptDebugTool-implementation-draft.md) | Reference | ReceiptDebugTool 实施规格；实际能力以工具代码为准 |
| [MVP1.0.md](MVP1.0.md) | Historical | App Intent 一键记账 MVP 初始设计 |

## Platforms And Release Assets

| 文档 | 状态 | 说明 |
|---|---|---|
| [AutoLedger_Watch_Design.md](AutoLedger_Watch_Design.md) | Reference | Apple Watch 快速记账与摘要设计 |
| [all-platform-screenshot-pipeline-design.md](all-platform-screenshot-pipeline-design.md) | Reference | 全平台截图管线设计；执行说明位于 `tools/appstore-screenshots/` |
| [tvos-dashboard-design.md](tvos-dashboard-design.md) | Reference | tvOS 只读看板设计 |
| [tvos-implementation-assessment.md](tvos-implementation-assessment.md) | Historical | tvOS 实现前评估，已被当前工程实现推进 |
| [visionos-spatial-design.md](visionos-spatial-design.md) | Reference | visionOS 空间展示设计 |
| [visionos-implementation-assessment.md](visionos-implementation-assessment.md) | Historical | visionOS 实现前评估，已被当前工程实现推进 |

## Source Of Truth Rules

- 同一事实只能有一个真源。README、专项设计和发布文案只能摘要或链接，不得分别维护相互冲突的状态。
- 当前阶段、候选、阻断和下一步只写入 `PROJECT_STATUS.md`。
- 产品方向、跨版本优先级和明确非目标只写入 `ROADMAP.md`。
- 版本范围、GOAL、测试与验收只写入 `versions/v*.md`。
- Free / Pro 能力的执行真源是 `ProAccessPolicy.swift`、服务端 entitlement 和回归测试；审计文档必须跟随代码更新。
- 带日期的执行记录表示当时事实。后续进展应新增当前总结或明确 superseded，不静默改写历史证据。
- 文档与可执行代码 / 测试冲突时，以代码和测试为准，并把文档失真视为需要修复的问题。

## Authoring Rules

- 新设计先写明状态、真源范围、最后核验日期、上位真源和相关实现入口。
- 设计草案放在 `docs/`；可执行版本计划放在 `versions/`；流程和执行证据放在 `process/`。
- 根 README 只保留面向协作者和用户的公开摘要，并链接当前状态与路线图。
- 不在路线图中记录构建号、Worker Version ID、单次测试输出或逐轮提交。
- 不在当前状态文档中堆完整设计规格或历史变更。
- 不使用“零上传”等绝对隐私表述；需要说明何时访问云端、发送哪些字段以及失败 fallback。
- 不包含真实小票、支付截图、原始 OCR、邮箱授权码、API key、证书、JWT、p8、真实酒店订单或个人财务数据。

## Release-Safe Reorganization

`v1.7.0` 发布前只做真源、索引、状态和过期事实修正，不移动现有文档路径。发布后可单独规划以下物理目录，并通过 `git mv`、全仓链接检查和兼容说明完成迁移：

- `docs/product/`
- `docs/architecture/`
- `docs/capabilities/`
- `docs/platforms/`
- `docs/operations/`
- `docs/archive/`
