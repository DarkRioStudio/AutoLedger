# AutoLedger Docs

> 文档状态：Canonical
> 真源范围：`docs/` 导航、物理分类、文档生命周期和编写规则
> 最后核验：2026-07-17
> 当前状态：[../PROJECT_STATUS.md](../PROJECT_STATUS.md)
> 核心路线图：[ROADMAP.md](ROADMAP.md)
> 跨版本语言路线：[product/I18N_ROADMAP.md](product/I18N_ROADMAP.md)

`docs/` 已按职责物理分组。根目录只保留本索引与核心产品路线图；版本执行计划放在 `versions/`，迭代流程与事实日志放在 `process/`。

```text
docs/
├── README.md          # 文档导航与治理真源
├── ROADMAP.md         # 唯一核心产品路线图
├── product/           # 产品专项与跨版本语言路线
├── architecture/      # 架构、数据与识别合同
├── capabilities/      # 用户能力与工具设计
├── platforms/         # Watch / tvOS / visionOS 平台设计
├── operations/        # 发布资产、权益、IAP 与运维审计
└── archive/           # 已执行规划与历史评估
```

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
| [ROADMAP.md](ROADMAP.md) | Canonical | 核心产品方向、跨版本优先级、依赖和非目标 |
| [product/I18N_ROADMAP.md](product/I18N_ROADMAP.md) | Canonical | 每版本语言组、英语主语言策略与通用语言门禁 |
| [../versions/v1.7.0-plan.md](../versions/v1.7.0-plan.md) | Canonical | 当前版本范围、GOAL、测试与验收 |
| [../versions/v1.7.0-i18n-release-matrix.md](../versions/v1.7.0-i18n-release-matrix.md) | Active | 当前版本语言完成度与缺口 |
| [../versions/v1.8.0-plan.md](../versions/v1.8.0-plan.md) | Draft | 下一版本 Review & Close 产品计划 |
| [../versions/v1.8.0-i18n-release-matrix.md](../versions/v1.8.0-i18n-release-matrix.md) | Draft | 下一版本西语 / 巴葡实施矩阵 |
| [../process/agent-iteration-workflow.md](../process/agent-iteration-workflow.md) | Canonical | 迭代方法、门禁与执行前检查 |
| [../process/iteration-log.md](../process/iteration-log.md) | Canonical | 每轮实施事实、风险、验证和回滚 |
| [../CHANGELOG.md](../CHANGELOG.md) | Canonical | 已完成变更历史 |

## Product

| 文档 | 状态 | 说明 |
|---|---|---|
| [product/I18N_ROADMAP.md](product/I18N_ROADMAP.md) | Canonical | 跨版本语言分组、主语言策略与发布准入 |
| [product/autoledger-personal-pro-design.md](product/autoledger-personal-pro-design.md) | Active | Personal Pro 定位、Free / Pro 原则和酒店 / 邮箱自动化设计 |
| [product/autoledger-personal-pro-roadmap.md](product/autoledger-personal-pro-roadmap.md) | Active | Pro 专项路线；优先级由核心 `ROADMAP.md` 派生 |

## Architecture

| 文档 | 状态 | 说明 |
|---|---|---|
| [architecture/LedgerTextInterpreter.md](architecture/LedgerTextInterpreter.md) | Reference | 平台无关账单文本解释器设计 |
| [architecture/recognition-learning-cache-design.md](architecture/recognition-learning-cache-design.md) | Active | 商户、分类、订阅倾向和短期识别学习缓存设计 |
| [architecture/autoledger_icloud_backup_design.md](architecture/autoledger_icloud_backup_design.md) | Reference | 单文件备份 / 恢复设计，不是当前 CloudKit 同步完整真源 |

## Capabilities

| 文档 | 状态 | 说明 |
|---|---|---|
| [capabilities/autoledger_voice_siri_design.md](capabilities/autoledger_voice_siri_design.md) | Reference | 语音记账与 Siri 交互设计 |
| [capabilities/shortcuts-json-ledger-import.md](capabilities/shortcuts-json-ledger-import.md) | Active | Shortcuts JSON 账单导入合同 |
| [capabilities/ReceiptDebugTool-implementation-draft.md](capabilities/ReceiptDebugTool-implementation-draft.md) | Reference | ReceiptDebugTool 实施规格；实际能力以工具代码为准 |

## Platforms

| 文档 | 状态 | 说明 |
|---|---|---|
| [platforms/AutoLedger_Watch_Design.md](platforms/AutoLedger_Watch_Design.md) | Reference | Apple Watch 快速记账与摘要设计 |
| [platforms/tvos-dashboard-design.md](platforms/tvos-dashboard-design.md) | Reference | tvOS 只读看板设计 |
| [platforms/visionos-spatial-design.md](platforms/visionos-spatial-design.md) | Reference | visionOS 空间展示设计 |

## Operations

| 文档 | 状态 | 说明 |
|---|---|---|
| [operations/all-platform-screenshot-pipeline-design.md](operations/all-platform-screenshot-pipeline-design.md) | Reference | 全平台截图管线设计；执行说明位于 `tools/appstore-screenshots/` |
| [operations/brand-assets-notice.md](operations/brand-assets-notice.md) | Canonical | AutoLedger 品牌与商店资产授权边界 |
| [operations/iap-support.md](operations/iap-support.md) | Active | Support Developer 与 Pro IAP 支持说明 |
| [operations/pro-access-audit.md](operations/pro-access-audit.md) | Active | 当前客户端与服务端权益边界审计快照 |

## Archive

| 文档 | 状态 | 说明 |
|---|---|---|
| [archive/MVP1.0.md](archive/MVP1.0.md) | Historical | App Intent 一键记账 MVP 初始设计 |
| [archive/autoledgercore-platform-dependency-audit.md](archive/autoledgercore-platform-dependency-audit.md) | Historical | 2026-06-11 Core 平台依赖审计快照 |
| [archive/minimum-platform-baseline-reduction-plan.md](archive/minimum-platform-baseline-reduction-plan.md) | Historical | 已执行的最低平台基线下调规划与结果 |
| [archive/tvos-implementation-assessment.md](archive/tvos-implementation-assessment.md) | Historical | tvOS 实现前评估 |
| [archive/visionos-implementation-assessment.md](archive/visionos-implementation-assessment.md) | Historical | visionOS 实现前评估 |

## Source Of Truth Rules

- 同一事实只能有一个真源。README、专项设计和发布文案只能摘要或链接，不得分别维护冲突状态。
- 当前阶段、候选、阻断和下一步只写入 `PROJECT_STATUS.md`。
- 核心产品方向、跨版本优先级和明确非目标只写入根级 `ROADMAP.md`。
- 语言组顺序、英语主语言策略和通用语言门禁只写入 `product/I18N_ROADMAP.md`。
- 版本范围、GOAL、测试与验收只写入 `versions/v*.md`。
- Free / Pro 能力的执行真源是代码、服务端 entitlement 和回归测试；审计文档必须跟随实现更新。
- 带日期的执行记录表示当时事实。后续进展应新增当前总结或明确 superseded，不静默改写历史证据。
- 文档与可执行代码 / 测试冲突时，以代码和测试为准，并把文档失真视为待修问题。

## Authoring And Placement Rules

- 新设计先写明状态、真源范围、最后核验日期、上位真源和相关实现入口。
- 核心路线图是唯一允许与本索引并列在 `docs/` 根目录的专项文档；其它新增文档必须进入现有分类目录。
- 产品方向放 `product/`；架构与数据合同放 `architecture/`；用户能力放 `capabilities/`；平台专项放 `platforms/`；发布、权益和运维放 `operations/`；已完成规划与历史快照放 `archive/`。
- 可执行版本计划放 `versions/`；流程和执行证据放 `process/`。
- 移动文档必须使用可追踪重命名、全仓链接检查，并同步本索引、当前状态和相关版本计划。
- 不在路线图中记录构建号、Worker Version ID、单次测试输出或逐轮提交。
- 不使用“零上传”等绝对隐私表述；需要说明何时访问云端、发送哪些字段以及失败 fallback。
- 不包含真实小票、支付截图、原始 OCR、邮箱授权码、API key、证书、JWT、p8、真实酒店订单或个人财务数据。
