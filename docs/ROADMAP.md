# AutoLedger Product Roadmap

> 文档状态：Canonical
> 真源范围：产品方向、优先级、跨版本主线、依赖关系与明确非目标
> 最后核验：2026-07-20
> 当前状态：[../PROJECT_STATUS.md](../PROJECT_STATUS.md)
> 当前版本执行计划：[../versions/v1.7.0-plan.md](../versions/v1.7.0-plan.md)
> 全球产品战略：[product/GLOBAL_PRODUCT_STRATEGY.md](product/GLOBAL_PRODUCT_STRATEGY.md)
> 跨版本语言路线：[product/I18N_ROADMAP.md](product/I18N_ROADMAP.md)

## Product North Star

AutoLedger 的长期定位是：

> **本地优先个人账本 + 自动化导入 + 酒店水单归档。**

英文定位固定为 `Private, local-first personal expense ledger with automated imports.`。AutoLedger 属于 Auto+：面向全球 Apple 用户，以 Privacy First、Local First、少账号依赖和主动自动化为共同原则。

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
- 从 `v1.7.0 / ASC 1.6.0` 起，每个公开功能版本必须同时交付一个通过准入门禁的新语言 / 地区组；不能只增加 UI 翻译数量。
- 从 ASC `1.6.0` 起，工程与商店主语言目标统一为英语；工程回退与 ASC Primary Language 必须分别留证。
- Pro 的主要付费表达是“解锁自动化能力”；Support Developer 只能作为次要自愿入口，不能承担商店主叙事。
- 全球增长先验证美国、英国、加拿大、澳大利亚和新加坡；第二阶段是日本、德国和法国。

## Roadmap Horizon

### Now - Ship v1.7.0 / ASC 1.6.0

当前只做发布收口，不继续横向扩 scope：

- 完成 TestFlight 性能、iCloud 最终一致性、云端收件箱和云端别名建议的跨设备验收；
- 冻结实时 OCR、五语 UI / 识别、Common API、Pro 自动化和酒店水单的当前行为；
- 完成图标、截图、App Preview、ASC metadata、订阅本地化、Review Notes 和隐私声明；
- 将 ASC Primary Language 切换或确认可切换为 `English (U.S.) / en-US`，并保留线上证据；
- 归档 Xcode Cloud、CloudKit Production schema、Worker production 和人工 smoke 证据；
- 只修复发布阻断、事实错误、隐私 / 权益边界和有证据的严重性能问题。

本版本的新语言组固定为韩语 `ko` / 韩国。西语和巴葡规划不会扩大当前候选范围。

### Global P0 - English-Market Readiness

当前发布收口后，优先完成全球基础，不立即用更多功能或更多语言扩张范围：

1. 英文 App Store 名称、副标题、描述、关键词和截图叙事；
2. 美国、英国、加拿大、澳大利亚和新加坡的日期、时间、数字、货币和价格验收；
3. 多币种原币 / 本位币、汇率日期、提供方、失败与复核体验；
4. 本地、iCloud、邮件、PDF 暂存、Common API、汇率和服务端权益的隐私说明；
5. iPhone、iPad、Mac、Watch、Widget、Share Extension、Siri / Shortcuts 的英语与地区一致性。

详细商店建议、国际化清单和当前代码结构风险见 [全球产品战略](product/GLOBAL_PRODUCT_STRATEGY.md)。

### Next - Ship v1.8.0 / ASC 1.7.0: Global Readiness & Review/Close

下一版本优先把已有能力串成可完成的账本闭环，而不是继续增加孤立入口：

1. **持久化待处理事项**：统一 OCR 待确认、云收件箱候选、重复、订阅异常、清洗建议、同步冲突和月结缺资料项。
2. **可完成的复核生命周期**：支持确认、忽略、延后、撤销和来源双向更新，避免已处理事项在重启或同步后复活。
3. **人能理解的同步状态**：把 CloudKit 阶段日志收敛为待上传、已同步、离线、本地数据安全和需要复核等稳定状态。
4. **月结检查 MVP**：从统一待处理事实生成检查清单，允许完成和重开，但不锁账。
5. **云端辅助可靠性**：补建议缓存、cooldown / backoff、配额和最小日志策略，不扩大上传字段。
6. **英语市场发布组**：以 `en-US` 为主语言，验证 `en-GB`、`en-CA`、`en-AU`、`en-SG` 的格式、术语、价格、截图、支持页和隐私说明；本版本不新增 UI 语言。

详细范围见 [../versions/v1.8.0-plan.md](../versions/v1.8.0-plan.md)；语言完成度见 [../versions/v1.8.0-i18n-release-matrix.md](../versions/v1.8.0-i18n-release-matrix.md)。两者目前均为 Draft，不表示已经进入实施。

### Later - Expand Carefully

- `v1.9.0 / Understand & Save`：规则中心、Saved Views、订阅省钱看板，完成日语质量提升并新增德语 `de` + 法语 `fr`；
- `v2.0 / Archive & Remember`：凭证保险箱、附件索引、酒店 / 旅行档案；西语 `es` + 巴西葡语 `pt-BR` 作为候选语言组；
- 更后版本：印尼语、越南语、印地语 / 印度英语，以及阿拉伯语 / RTL 依次进入独立评审；
- 高级分享模板、可编辑故事卡、隐私分级导出和年度复盘；
- 经独立隐私、成本与失败降级评审后的其它云端辅助模型。

### Not Planned

- 银行账户直连、自动抓取银行流水或代替金融机构；
- 为单一地区继续增加支付平台专用入口并把它当作版本主目标；
- 团队账本、企业报销、会计协作和税务合规产品；
- 默认把完整账本、原始小票、酒店 PDF 或邮箱内容上传到服务器；
- 无需用户确认的自动正式入账或批量静默改账；
- 通过远端配置替换本地识别规则、Pro gate 或 StoreKit 权益；
- 为扩大语言数量而发布没有识别包、样本和商店资产的 UI 翻译。

## Product Workstreams

| 主线 | 已有基础 | 下一阶段重点 | 详细真源 |
|---|---|---|---|
| 导入与复核 | 截图、拍照、实时 OCR、语音、剪贴板、Share Extension、快捷指令 | 持久化待确认队列、长票据与多笔账单、统一失败恢复 | `versions/v1.7.0-plan.md`、`docs/architecture/LedgerTextInterpreter.md` |
| 账本与同步 | SQLite、多账本、CloudKit、Watch / Widget 快照 | 冲突解释、最终一致性状态、规则与偏好同步 | `docs/architecture/autoledger_icloud_backup_design.md`、当前代码与回归 |
| 识别与学习 | 规则引擎、语言包、商户 / 分类学习、端侧 LLM | 真实样本、低置信度复核、冲突治理 | `docs/architecture/recognition-learning-cache-design.md` |
| Pro 自动化 | 高级搜索、异常订阅、月结包、高级规则、智能整理 | 待处理队列、规则中心、月结检查、Saved Views | `docs/product/autoledger-personal-pro-roadmap.md` |
| 酒店与旅行 | 手动 PDF、本地邮箱、专属收件箱、酒店档案、历史天气 | 候选统一队列、附件保险箱、旅程复盘 | `docs/product/autoledger-personal-pro-design.md`、版本计划 |
| 平台体验 | iPhone、iPad、Mac Catalyst、Watch、Widget、tvOS、visionOS | 主平台一致性、性能、辅助功能；展示平台按价值维护 | `docs/platforms/AutoLedger_Watch_Design.md`、tvOS / visionOS 文档 |
| 云端与发布 | Common API、folio Worker、ASSN、analytics dashboard、ASC metadata-as-code | SLA / 配额、隐私审计、自动化发布证据、跨 App 基础设施复用 | `tools/worker/`、`tools/asc-metadata/`、版本计划 |
| 本地化与地区识别 | 五语 UI、五种识别语言包、ASC metadata-as-code | 英语五市场质量、日德法第二阶段、地区样本、人工审校和全平台商店资产 | `docs/product/I18N_ROADMAP.md`、`docs/product/GLOBAL_PRODUCT_STRATEGY.md`、版本语言矩阵 |

表中的专项文档只展开细节，不得独立改变本路线图的优先级或产品边界。

## Version Direction

| 开发线 | 对外版本 | 路线图角色 |
|---|---|---|
| `v1.6.4` | ASC `1.5.0` | Free / Pro 边界、Personal Pro、云端水单收件箱和发布基线 |
| `v1.7.0` | ASC `1.6.0` | 当前发布线：实时 OCR、五语、Common API、Pro 自动化、发布观测；新增韩语，主语言目标改为英语 |
| `v1.8.0` | ASC `1.7.0` | Draft：全球基础、Review & Close、持久化待处理、可信同步、月结闭环；验证英语五市场，不新增 UI 语言 |
| `v1.9.0` | ASC `1.8.0` | Planned：Understand & Save、规则中心、Saved Views、订阅省钱；日语质量提升 + 德语 + 法语 |
| `v2.0` | 待确定 | Planned：Archive & Remember、凭证与旅行档案；西语 + 巴葡为候选组 |

具体版本范围、GOAL、测试和验收只在 `versions/v*.md` 中维护。本文件不记录 build number、Worker Version ID、逐轮提交或单次测试输出。

## Language Expansion Cadence

| 版本 | 新语言 / 地区组 | 版本级重点 |
|---|---|---|
| `v1.7.0 / ASC 1.6.0` | 韩语 `ko` / 韩国 | KRW、韩国卡单与支付、韩英酒店水单、ASC 韩语材料 |
| `v1.8.0 / ASC 1.7.0` | 英语市场组：`en-US` + `en-GB` / `en-CA` / `en-AU` / `en-SG` 验收 | 日期、币种、税费、价格、截图、支持页与隐私说明；不新增 UI 语言 |
| `v1.9.0 / ASC 1.8.0` | 日语质量提升 + 德语 `de` + 法语 `fr` | 日本、德国 / 奥地利 / 瑞士、法国 / 加拿大票据与酒店字段 |
| `v2.0` 候选 | 西班牙语 `es` + 巴西葡语 `pt-BR` | 西班牙 / 墨西哥地区 profile、PIX、NF-e、BRL |
| 后续独立版本 | 印尼语、越南语、印地语 / 印度英语、阿拉伯语 / RTL | 每组按真实市场、样本、布局与维护能力单独评审 |

跨版本顺序与通用六项门禁以 [product/I18N_ROADMAP.md](product/I18N_ROADMAP.md) 为真源。单一版本只有在 UI、商店、识别包、真实样本、地区票据和人工审校全部有证据后，才能把语言标记为 Ready。

## Dependency Order

1. 先保证本地账本、手动路径和数据可恢复。
2. 再建立待确认、去重、清洗、异常和月结的统一状态合同。
3. 然后让 Pro 自动化复用这些合同，保持免费替代路径。
4. 云端辅助只能在 opt-in、最小字段、服务端 entitlement、失败 fallback 和用户确认全部成立后扩展。
5. 每个版本在 kickoff 时锁定语言或市场组、审校责任、样本来源和地区 profile，不能等产品开发结束后再追加翻译。
6. 新语言必须同时具备 UI、识别包、样本、截图 / metadata、地区票据和人工审校状态。
7. 发布资产只能在功能、隐私、订阅和数据 schema 冻结后完成。

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
| `docs/product/I18N_ROADMAP.md` | 跨版本语言组、主语言策略、通用语言门禁 | 单一版本完成度和证据 |
| `docs/product/GLOBAL_PRODUCT_STRATEGY.md` | 目标市场、商店策略、国际化清单、商业化方向和结构风险 | 当前发布状态、已在线 ASC 证据 |
| `versions/v*.md` | 单一版本范围、GOAL、验收 | 跨版本产品优先级 |
| `docs/*/*-design.md` | 专项合同、交互与架构细节 | 全局状态和版本承诺 |
| `docs/*/*-audit.md` | 某一时间点的审计证据 | 永久产品真源 |
| `process/iteration-log.md` | 实施事实和回滚记录 | 当前状态摘要 |
| `CHANGELOG.md` | 已完成变更历史 | 未来规划和发布判定 |
| 四语 README | 对外介绍和路线图摘要 | 独立定义内部事实 |

## Update Rules

- 本文件只在产品优先级、跨版本主线、边界或明确非目标变化时更新。
- 当前候选、阻断、生产状态和下一步变化只更新 `PROJECT_STATUS.md`。
- 专项文档与本文件冲突时，以本文件和可执行代码 / 测试为准；随后修正专项文档。
- 每次路线图更新必须同步检查 Free / Pro、隐私、历史数据访问和发布顺序。
