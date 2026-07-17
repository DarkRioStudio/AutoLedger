# AutoLedger Project Status

> 文档状态：Canonical
> 真源范围：当前开发线、发布阶段、已验证基线、剩余门禁和下一步
> 截止日期：2026-07-18
> 上位产品路线图：[docs/ROADMAP.md](docs/ROADMAP.md)
> 跨版本语言路线：[docs/product/I18N_ROADMAP.md](docs/product/I18N_ROADMAP.md)
> 当前版本执行计划：[versions/v1.7.0-plan.md](versions/v1.7.0-plan.md)

## Current Snapshot

| 项目 | 当前状态 |
|---|---|
| 内部开发线 | `v1.7.0` |
| App Store 对外版本 | `1.6.0` |
| 发布阶段 | TestFlight 反馈收口 -> Release Candidate 冻结前 |
| 已验证候选产品行为基线 | `9414b91694d4`；当前仓库后续 Swift 改动仅服务 `--screenshot-mode` / 截图 Host，不进入正式启动路径 |
| Xcode Cloud 触发标签 | `xcbuild-v1.7.0`，基线指向 `9414b91694d4` |
| 最近人工结论 | 当前 TestFlight 候选整体已接近发布；TS 117 起 Tab 体感明显改善 |
| 精确 TestFlight build | 属于 App Store Connect 外部证据；未从仓库推断或写死 |
| 文档治理 | `PROJECT_STATUS.md`、根级 `docs/ROADMAP.md` 与 `docs/product/I18N_ROADMAP.md` 分别负责当前状态、核心产品路线和跨版本语言路线；其它 `docs` 已物理分类 |
| 下一版本 | `v1.8.0 / ASC 1.7.0` 的 Review & Close 与西语 / 巴葡计划仅为 Draft，不扩大当前发布范围 |

本文件回答“项目现在在哪里”。它不替代版本计划、回归证据、CHANGELOG 或逐轮迭代日志。

## Release Position

`v1.7.0 / ASC 1.6.0` 的主要产品与工程能力已经进入主线：

- 实时 OCR 票据扫描，以及拍照 / 相册 fallback 和保存前确认；
- 简体中文、繁体中文、英文、日文与韩语 UI / 识别包基础；
- 多账本、iCloud / CloudKit 同步、酒店水单档案和专属云端收件箱；
- Pro 高级搜索、订阅异常、月结 ZIP、高级规则、数据清洗和统一待处理中心；
- Common API 地点、币种、汇率、历史天气、release notes 与匿名发布观测；
- App Store Server Notifications、ASC metadata-as-code 和服务端 Pro entitlement 基础；
- 本地分享图、酒店旅程回忆和跨平台工作台。

当前阶段不再适合横向加入大功能。发布前只处理明确阻断、事实错误、隐私 / 权益边界、严重性能问题和发布材料缺口。

## Recently Closed

- 启动 SQLite 水合和同步完成后的全量解码已移出 UI actor；启动 iCloud 同步等待本地账本可交互后继续。
- 账本与酒店 Tab 复用派生快照，TS 117 真机反馈比前版明显改善。
- “保留本机”后的旧 CloudKit 冲突元数据不再在下一轮拉取时复活。
- 开发者模式性能阶段数据已进入现有 AutoLedger Dashboard，不另建监控系统。
- Dashboard 已把旧“导入完成率”拆成“导入任务成功率”和“实时扫描确认率”。
- 云端水单收件箱收到 `401 unauthorized` 时，App 会尝试续签原凭据并重试。
- 数据清洗的云端辅助已形成第一版可用闭环：用户显式开启且具备 Pro 权益时，App 发送商户键哈希和聚合特征，Worker 返回 hash-only 商户别名建议，用户确认前不会改写账本。
- 自动化规则指标已统一布局和字号，商户别名、分类修正和受影响账单说明不再截断。
- `docs/` 已按产品、架构、能力、平台、运维和归档物理分组；核心 `ROADMAP.md` 作为唯一专项例外保留在 `docs/` 根目录。
- 已建立每版本一组新语言的跨版本路线和 `v1.8.0` Draft；工程 `developmentRegion = en` 已核验，但 ASC Primary Language 的线上切换尚未以仓库证据确认。
- 韩语六平台截图管线已补齐：iPhone、iPad、Mac、Watch、tvOS、visionOS 本地导出 30 张 raw 与 30 张商店尺寸成品，逐平台视觉复核后修正截图 Host 的中文 fallback；生成物按规则忽略，不等同于 ASC 已上传或韩语已通过母语审校。

详细证据见 [process/iteration-log.md](process/iteration-log.md) 的 `ITER-421` 至 `ITER-430`。

## Release Gates

### P0 - Candidate Evidence

- 确认最终 Xcode Cloud 四平台构建成功，并记录 TestFlight build number 与源码 SHA 的对应关系。
- iPhone、iPad、Mac 分别完成冷启动、快速切 Tab、月报月份切换、数据清洗和 OCR 固定路径 smoke；单设备结果不能替代其它平台。
- 验证启动后立即交互时 iCloud 同步仍能最终完成，且不会重新阻塞 UI。
- 使用重庆 Moxy 记录复测“保留本机 -> 推送 -> 拉取”，确认并发改动冲突不再复活。
- 在最新候选中验证云端水单收件箱 `401` 自动续签不会更换既有专属地址，并验证云端商户别名建议成功与失败 fallback。

### P0 - Release And Privacy

- 对照 [versions/v1.7.0-i18n-release-matrix.md](versions/v1.7.0-i18n-release-matrix.md) 完成五语状态复核；韩语虽已完成本地六平台截图导出，但母语审校、真实样本、ASC 上传与 App Preview 证据未齐前不得标记为 Ready。
- 从 ASC `1.6.0` 起以 `English (U.S.) / en-US` 为 Primary Language；执行前确认当前 App 信息可编辑、英语此前已通过审核且全平台英语截图满足切换条件，执行后归档 ASC 线上证据。Xcode `developmentRegion = en` 不能替代该证据。
- 确认 ASC metadata、订阅本地化、截图 / App Preview、Review Notes、隐私政策和 App Privacy 口径一致。
- 确认 Crash Data、Performance Data 与 Product Interaction 只用于 Analytics，not linked，not tracking。
- 若最终候选包含 CloudKit record type、field 或 index 变化，必须先将 Development schema 部署到 Production 并记录证据。
- 冻结本次商店图标：明确沿用当前图标，或完成多层图标资产后再统一重导商店素材；不能在截图完成后继续改动。

### P1 - Operational Confidence

- 复核 Common API、hotel-folio-inbox、Cloudflare Access、D1 / R2 / Queue 和 App Store Server Notifications 的生产 smoke。
- 确认 Dashboard 新旧指标口径已分开，历史样本不被解释为当前构建失败率。
- 归档最终回归基线、发布说明和人工证据；移动产品发布标签前再次确认当前提交无未记录改动。

## Known Risks And Limitations

- 云端商户辅助当前只覆盖首批可解释别名目录；成功响应缓存、持久化 cooldown / backoff、服务端配额和更广别名治理仍未完成。
- CloudKit 合并写入继续使用串行一致性路径；当前优化重点是让网络与解码不阻塞 UI，而不是把所有同步工作并行化。
- TestFlight build number、ASC processing 和人工设备结果属于外部证据，仓库文档不得根据 tag 或 MARKETING_VERSION 猜测。
- Dashboard 历史数据包含旧版本和旧埋点语义，判断发布质量时必须按 source build 和新指标口径过滤。
- 韩语截图生成物位于忽略目录，本地 30 / 30 导出与工程视觉复核只能证明素材管线可用，不能替代 ASC 上传状态、原生设备长文本检查或母语审校。
- `versions/v1.7.0-plan.md` 保留逐阶段执行记录；其中带日期的“未完成”描述是当时事实，不能覆盖本文件的当前状态。
- `v1.8.0` 与后续语言组是规划事实，不代表实现、ASC locale、截图、识别样本或人工审校已经完成。

## Next Actions

1. 完成当前候选的 iPhone / iPad / Mac 与 iCloud 最终 smoke，并把结果回填本文件和版本回归基线。
2. 冻结五语商店资产、图标、ASC metadata、Review Notes 与隐私声明；上传并核对韩语六平台截图，完成 `en-US` Primary Language 的发布操作与留证。
3. 完成 release-readiness 审计后，再决定提交审核和移动不可变产品版本标签。

## Source Of Truth Map

| 问题 | 真源 |
|---|---|
| 项目现在是什么状态 | 本文件 |
| 产品长期往哪里走 | [docs/ROADMAP.md](docs/ROADMAP.md) |
| 每个版本扩展哪些语言、统一门禁是什么 | [docs/product/I18N_ROADMAP.md](docs/product/I18N_ROADMAP.md) |
| v1.7.0 做什么、如何验收 | [versions/v1.7.0-plan.md](versions/v1.7.0-plan.md) |
| 多语言是否可公开发布 | [versions/v1.7.0-i18n-release-matrix.md](versions/v1.7.0-i18n-release-matrix.md) |
| 下一版本规划了什么 | [versions/v1.8.0-plan.md](versions/v1.8.0-plan.md) 与 [versions/v1.8.0-i18n-release-matrix.md](versions/v1.8.0-i18n-release-matrix.md)；均为 Draft |
| Free / Pro 可执行边界 | `AutoLedgerCore/Models/ProAccessPolicy.swift` 与对应回归 |
| Free / Pro 审计解释 | [docs/operations/pro-access-audit.md](docs/operations/pro-access-audit.md) |
| 每轮做了什么 | [process/iteration-log.md](process/iteration-log.md) |
| 已完成变更历史 | [CHANGELOG.md](CHANGELOG.md) |
| 对外项目介绍 | 四语根 README，内容应从以上真源提炼 |

## Update Rules

- 只有发布阶段、候选基线、P0 门禁、阻断或下一步发生变化时才更新本文件；普通代码细节进入迭代日志。
- 每次更新必须写明截止日期，并区分仓库证据、生产证据和用户人工反馈。
- 不记录 secret、JWT、p8、邮箱授权码、真实账单、商户、金额、酒店订单或个人财务数据。
- 本文件与代码冲突时，以可执行代码和测试为准，并立即修正文档。
