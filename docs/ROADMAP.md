# AutoLedger Product Roadmap

> 文档状态：Canonical
> 真源范围：产品方向、优先级、跨版本主线、依赖关系与明确非目标
> 最后核验：2026-07-17
> 当前状态：[../PROJECT_STATUS.md](../PROJECT_STATUS.md)
> 当前版本执行计划：[../versions/v1.7.0-plan.md](../versions/v1.7.0-plan.md)

## Product North Star

AutoLedger 的长期定位是：

> **本地优先个人账本 + 自动化导入 + 酒店水单归档。**

产品价值不是要求用户维护另一套复杂表格，而是把截图、小票、语音、快捷指令、订阅扣费、酒店水单和月结材料整理成可复核、可追溯的个人账本。

## Non-Negotiable Boundaries

- 基础记账长期免费；Pro 收费的是节省时间的自动化，不是用户对自己数据的访问权。
- 手动记账、单张识别、手动酒店 PDF、基础月报、基础导出、历史查看编辑删除不能因新版本迁入 Pro。
- Pro 到期后暂停新的 Pro 自动化，不锁已生成结果、已采纳规则或历史数据。
- 识别结果默认先进入可复核流程；不做后台静默正式入账。
- OCR 与本地模型推理默认在设备端完成；用户主动使用云收件箱、Common API、服务端权益或云端辅助时才访问相应服务。
- 不使用“零上传”等绝对隐私表述；每项云能力都必须说明实际字段、目的、保留和失败 fallback。
- 服务端成本能力必须走服务端 entitlement；公开客户端中的本地 Pro gate 只负责 UI 和本机能力边界。
- 云服务失败不能阻断基础记账、历史访问、手动导入或基础导出。
- 用户账本、酒店 PDF、邮箱授权码、OCR 原文和精确消费明细不作为匿名运营观测输入。

## Roadmap Horizon

### Now - Ship v1.7.0 / ASC 1.6.0

当前只做发布收口，不继续横向扩 scope：

- 完成 TestFlight 性能、iCloud 最终一致性、云端收件箱和云端别名建议的跨设备验收；
- 冻结实时 OCR、五语 UI / 识别、Common API、Pro 自动化和酒店水单的当前行为；
- 完成图标、截图、App Preview、ASC metadata、订阅本地化、Review Notes 和隐私声明；
- 归档 Xcode Cloud、CloudKit Production schema、Worker production 和人工 smoke 证据；
- 只修复发布阻断、事实错误、隐私 / 权益边界和有证据的严重性能问题。

### Next - Make Automation Coherent

发布后优先把已有能力串成完整工作流，而不是继续增加孤立入口：

1. **统一待处理队列第二阶段**：持久化 OCR 待确认、云收件箱候选、批量邮箱候选和月结缺资料项，并明确跨设备合同。
2. **数据清洗第二阶段**：扩充可解释商户别名、分类建议和冲突治理；补响应缓存、cooldown / backoff、配额和最小日志策略。
3. **月结检查清单**：把异常订阅、缺失凭证、未处理候选、重复账单和导出资料串成月底闭环。
4. **规则中心与 Saved Views**：集中管理商户别名、分类修正、自动化规则和常用搜索，同时保留预览、撤销和审计。
5. **同步可靠性产品化**：完善冲突解释、最终一致性状态和跨设备规则同步，避免把底层 CloudKit 术语直接暴露给普通用户。
6. **真实样本和地区能力**：补齐韩语、繁体中文地区和英语地区支付 / 票据样本，再决定下一种语言。

### Later - Expand Carefully

- 订阅省钱看板和更完整的年度 / 月度复盘；
- 高级分享模板、可编辑故事卡和隐私分级导出；
- Mac / iPad 大屏月结、批量整理和附件工作台；
- 多设备自动化偏好与已确认规则同步；
- 西班牙语、巴西葡语、法语 / 德语和印度支付专项；
- 更完整的凭证保险箱、附件索引和酒店 / 旅行消费档案；
- 经独立隐私与成本评审后的其它云端辅助模型。

### Not Planned

- 银行账户直连、自动抓取银行流水或代替金融机构；
- 团队账本、企业报销、会计协作和税务合规产品；
- 默认把完整账本、原始小票、酒店 PDF 或邮箱内容上传到服务器；
- 无需用户确认的自动正式入账或批量静默改账；
- 通过远端配置替换本地识别规则、Pro gate 或 StoreKit 权益；
- 为扩大语言数量而发布没有识别包、样本和商店资产的 UI 翻译。

## Product Workstreams

| 主线 | 已有基础 | 下一阶段重点 | 详细真源 |
|---|---|---|---|
| 导入与复核 | 截图、拍照、实时 OCR、语音、剪贴板、Share Extension、快捷指令 | 持久化待确认队列、长票据与多笔账单、统一失败恢复 | `versions/v1.7.0-plan.md`、`docs/LedgerTextInterpreter.md` |
| 账本与同步 | SQLite、多账本、CloudKit、Watch / Widget 快照 | 冲突解释、最终一致性状态、规则与偏好同步 | `docs/autoledger_icloud_backup_design.md`、当前代码与回归 |
| 识别与学习 | 规则引擎、语言包、商户 / 分类学习、端侧 LLM | 真实样本、低置信度复核、冲突治理 | `docs/recognition-learning-cache-design.md` |
| Pro 自动化 | 高级搜索、异常订阅、月结包、高级规则、智能整理 | 待处理队列、规则中心、月结检查、Saved Views | `docs/autoledger-personal-pro-roadmap.md` |
| 酒店与旅行 | 手动 PDF、本地邮箱、专属收件箱、酒店档案、历史天气 | 候选统一队列、附件保险箱、旅程复盘 | `docs/autoledger-personal-pro-design.md`、版本计划 |
| 平台体验 | iPhone、iPad、Mac Catalyst、Watch、Widget、tvOS、visionOS | 主平台一致性、性能、辅助功能；展示平台按价值维护 | `docs/AutoLedger_Watch_Design.md`、tvOS / visionOS 文档 |
| 云端与发布 | Common API、folio Worker、ASSN、analytics dashboard、ASC metadata-as-code | SLA / 配额、隐私审计、自动化发布证据、跨 App 基础设施复用 | `tools/worker/`、`tools/asc-metadata/`、版本计划 |

表中的专项文档只展开细节，不得独立改变本路线图的优先级或产品边界。

## Version Direction

| 开发线 | 对外版本 | 路线图角色 |
|---|---|---|
| `v1.6.4` | ASC `1.5.0` | Free / Pro 边界、Personal Pro、云端水单收件箱和发布基线 |
| `v1.7.0` | ASC `1.6.0` | 当前发布线：实时 OCR、五语、Common API、服务端订阅、Pro 全账本自动化和发布观测 |
| Post `v1.7.0` | 待版本规划 | 先完成统一工作流和可靠性，再扩展语言、模板与更重云辅助 |

具体版本范围、GOAL、测试和验收只在 `versions/v*.md` 中维护。本文件不记录 build number、Worker Version ID、逐轮提交或单次测试输出。

## Dependency Order

1. 先保证本地账本、手动路径和数据可恢复。
2. 再建立待确认、去重、清洗、异常和月结的统一状态合同。
3. 然后让 Pro 自动化复用这些合同，保持免费替代路径。
4. 云端辅助只能在 opt-in、最小字段、服务端 entitlement、失败 fallback 和用户确认全部成立后扩展。
5. 新语言必须同时具备 UI、识别包、样本、截图 / metadata 和地区票据状态。
6. 发布资产只能在功能、隐私、订阅和数据 schema 冻结后完成。

## Decision Rules

新能力进入 `Now` 前必须回答：

- 它解决的是高频用户问题，还是只增加功能数量？
- 免费用户是否仍有完整手动路径？
- 是否改变数据上传、保留、服务端成本或 entitlement？
- 是否需要新的 SQLite / CloudKit schema、迁移或 Production 部署？
- 是否有可执行的自动回归和人工验收？
- 是否会推迟当前发布门禁？

缺少其中任一关键答案时，能力只能进入专项设计或 `Later`，不能直接进入当前版本。

## Source Of Truth Boundaries

| 文档 | 负责 | 不负责 |
|---|---|---|
| `PROJECT_STATUS.md` | 当前阶段、候选、阻断、门禁、下一步 | 长期愿景、逐轮日志 |
| 本文件 | 产品方向、优先级、跨版本依赖、非目标 | 构建号、部署 ID、执行证据 |
| `versions/v*.md` | 单一版本范围、GOAL、验收 | 跨版本产品优先级 |
| `docs/*-design.md` | 专项合同、交互与架构细节 | 全局状态和版本承诺 |
| `docs/*-audit.md` | 某一时间点的审计证据 | 永久产品真源 |
| `process/iteration-log.md` | 实施事实和回滚记录 | 当前状态摘要 |
| `CHANGELOG.md` | 已完成变更历史 | 未来规划和发布判定 |
| 四语 README | 对外介绍和路线图摘要 | 独立定义内部事实 |

## Update Rules

- 本文件只在产品优先级、跨版本主线、边界或明确非目标变化时更新。
- 当前候选、阻断、生产状态和下一步变化只更新 `PROJECT_STATUS.md`。
- 专项文档与本文件冲突时，以本文件和可执行代码 / 测试为准；随后修正专项文档。
- 每次路线图更新必须同步检查 Free / Pro、隐私、历史数据访问和发布顺序。
