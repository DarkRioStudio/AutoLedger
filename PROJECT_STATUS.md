# AutoLedger Project Status

> 文档状态：Canonical
> 真源范围：当前开发线、发布阶段、已验证基线、剩余门禁和下一步
> 截止日期：2026-07-20
> 上位产品路线图：[docs/ROADMAP.md](docs/ROADMAP.md)
> 全球产品战略：[docs/product/GLOBAL_PRODUCT_STRATEGY.md](docs/product/GLOBAL_PRODUCT_STRATEGY.md)
> 跨版本语言路线：[docs/product/I18N_ROADMAP.md](docs/product/I18N_ROADMAP.md)
> 当前版本执行计划：[versions/v1.7.0-plan.md](versions/v1.7.0-plan.md)

## Current Snapshot

| 项目 | 当前状态 |
|---|---|
| 内部开发线 | `v1.7.0` |
| App Store 对外版本 | `1.6.0` |
| 发布阶段 | ASC `1.6.0` 四平台已提交审核，当前均为 `WAITING_FOR_REVIEW` |
| 自定义产品页 | 三张五语页面已通过独立 iOS items-only submission 提交，审核单与三页均为 `WAITING_FOR_REVIEW`；主版本审核单保持独立 |
| 已验证候选产品行为基线 | build `120` / `022dba591c77b40b5a936b9d9e1d87f51a4f6796`；六项最终 TestFlight / 真机门禁已由用户确认通过 |
| Xcode Cloud 触发标签 | `xcbuild-v1.7.0` 已移动到包含 runtime 基线与发布证据文档的最新 `main` |
| 最近人工结论 | build `120` 的水单刷新、401 续签、订阅处理、iCloud、交互性能和 Mac smoke 均通过 |
| 精确 TestFlight build | build `120`；iOS、macOS、tvOS、visionOS 均为 `VALID / APP_STORE_ELIGIBLE / expired=false`，且已绑定 ASC `1.6.0` |
| 文档治理 | `PROJECT_STATUS.md`、根级 `docs/ROADMAP.md` 与 `docs/product/I18N_ROADMAP.md` 分别负责当前状态、核心产品路线和跨版本语言路线；其它 `docs` 已物理分类 |
| 下一版本 | `v1.8.0 / ASC 1.7.0` 的 Review & Close 与英语五市场质量组仅为 Draft，不扩大当前发布范围 |

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
- 已修复刷新水单导致地址显示偶发变化：Keychain access token 更新不再删除真实 routing inbox address，App 不再从 access token 派生伪邮箱，候选列表会回传认证后的真实地址以自动修复旧本地状态。folio Worker 已部署 staging `bfaacd81-396a-435d-93a3-93e5a13df02b` 与 production `2b1dd061-648c-446b-bcce-45c5e12daf65`。
- 数据清洗的云端辅助已形成第一版可用闭环：用户显式开启且具备 Pro 权益时，App 发送商户键哈希和聚合特征，Worker 返回 hash-only 商户别名建议，用户确认前不会改写账本。
- 自动化规则指标已统一布局和字号，商户别名、分类修正和受影响账单说明不再截断。
- `docs/` 已按产品、架构、能力、平台、运维和归档物理分组；核心 `ROADMAP.md` 作为唯一专项例外保留在 `docs/` 根目录。
- 已建立跨版本语言准入路线并将 `v1.8.0` 调整为英语五市场质量组；工程 `developmentRegion = en` 已核验，ASC Primary Language 已在线回读确认为 `English (U.S.) / en-US`。日语质量提升、德语与法语进入第二阶段，西班牙语与巴西葡语顺延。
- 五语六平台截图已完成 ASC `1.6.0` 上传与 API 回读：中简、中繁、美英、日、韩在 iPhone、iPad、Mac、Watch、tvOS、visionOS 的 150 张目标截图均与本地 MD5 矩阵匹配；显式存在的 `en-GB` 已同步 `en-US` 元数据和六平台当前英文截图，避免旧资产覆盖主语言 fallback。
- ASC `1.5.0` 四平台元数据已从线上归档；ASC `1.6.0` 的 iOS、macOS、tvOS、visionOS 已提交并处于 `WAITING_FOR_REVIEW`，planned 五语版本文案已填充并回读一致。Primary Language 已确认为 `en-US`，韩语 App 名称、副标题、隐私链接与 Apple TV 隐私正文已定点写入并回读一致。
- ASC `1.6.0` 五语 iPhone App Preview v003 已上传：五条视频均与本地 MD5 一致且 `videoDeliveryState=COMPLETE`；英文 / 简中旧片在新片完成后删除。五语 poster frame 已统一为 OCR 首屏的 `1.4s / 00:00:01:12`，API 回读时间码与生成图状态均为 `COMPLETE`。韩语母语审校按发布决定转为非阻断质量增强；最终 binary 逐镜一致性核验仍未完成。
- 四平台 Review Notes 已从 repo profile 写入 ASC 并按长度 / SHA-256 回读一致；iOS / macOS 使用主功能说明，tvOS / visionOS 使用只读看板说明，均保持 `demoAccountRequired=false` 且未覆盖审核联系人字段。
- Xcode Cloud build `119` 曾运行成功但因水单地址本地状态缺陷被否决；ASC `1.6.0` 四个平台现已改绑 build `120` 的有效、未过期、App Store eligible binary，并完成幂等 API 回读。
- ASC App Privacy 已人工查看：Crash Data、Performance Data、Product Interaction 均用于 Analytics，not linked，not tracking，与 `PrivacyInfo.xcprivacy` 一致；Privacy Policy URL 已保存为 `https://getautoledger.app/privacy`，页面回读新值并标记“已编辑”，该变更将随下一版本发布。
- ASC `1.6.0` 四平台五语 Promotional Text 与结构化 App Description 已统一；“截图与小票识别”“酒店水单归档”“本地优先与 Apple 生态”三张五语自定义产品页的 30 个 iPhone / iPad 截图集已按主题裁剪，135 张素材全量有序 MD5 匹配且远端处理为 `COMPLETE`。2026-07-20 三页已作为独立 iOS items-only submission 提交，审核单与三页均为 `WAITING_FOR_REVIEW`，没有修改主版本审核单；获批前仍不视为公开可用。Reddit、V2EX、SSPAI、Website、QRCode Campaign Link 已生成，官网五语宣传语已部署。
- Xcode Cloud build `120` 已成功，源码精确对应 `022dba591c77b40b5a936b9d9e1d87f51a4f6796`；四平台 binary 均为 `VALID / APP_STORE_ELIGIBLE / expired=false / usesNonExemptEncryption=false`，ASC `1.6.0` 已从被否决的 build `119` 改绑到 build `120` 并逐平台回读。
- 用户已确认 build `120` 的六项最终门禁全部通过：水单连续刷新地址稳定、401 自动续签不换地址、订阅异常确认 / 忽略与计数、iPhone / iPad iCloud 同步不复活、Tab / 冷启动 / 月份切换无明显回退，以及 Mac 启动 / 账本读取 smoke。
- 提交前线上审计发现英语、日语、简中、繁中 App Info 仍为旧文案，其中日语标题为中文；已按 `tools/asc-metadata/metadata.yml` 定点同步五语真源并二次 dry-run 回读为全量匹配，韩语保持不变。
- 2026-07-20 已为 iOS、macOS、tvOS、visionOS 分别创建且只加入一个对应 `1.6.0` 版本项目，四个平台随后正式提交审核；独立回读确认四份审核单和四个平台版本均为 `WAITING_FOR_REVIEW`、`submittedDate` 非空、绑定 build `120`，发布方式为 `AFTER_APPROVAL`。

详细证据见 [process/iteration-log.md](process/iteration-log.md) 的 `ITER-421` 至 `ITER-443`。

## Release Gates

### P0 - Candidate Evidence

- build `120`、精确源码、四平台处理 / eligibility、ASC 绑定和六项最终设备门禁均已完成；审核期间不得继续修改候选 binary、CloudKit schema、entitlement 或同步实现。
- 重庆 Moxy 冲突处置、云端商户建议和生产服务证据沿用提交前已完成的验证；如 Apple 提出新问题，按最小审核热修重新建立候选，不直接移动正式产品标签。

### P0 - Release And Privacy

- 对照 [versions/v1.7.0-i18n-release-matrix.md](versions/v1.7.0-i18n-release-matrix.md) 维护五语事实状态。韩语母语审校因暂无合适审校者，按发布决定不阻断 ASC `1.6.0`；真实样本与地区专项作为已知质量缺口继续积累，不得伪装为已经完成。
- ASC `1.6.0` 的 Primary Language 已在线确认为 `English (U.S.) / en-US`；显式 `en-GB` 元数据和六平台截图已同步当前英语资产，提交前仅剩与最终 binary 的一致性复核。
- ASC metadata、订阅本地化、截图 / App Preview、Review Notes 与 App Privacy URL 已完成线上回读；App Privacy 数据类型口径已核对一致。
- Crash Data、Performance Data 与 Product Interaction 已在线确认只用于 Analytics，not linked，not tracking。
- 若最终候选包含 CloudKit record type、field 或 index 变化，必须先将 Development schema 部署到 Production 并记录证据。
- 冻结本次商店图标：明确沿用当前图标，或完成多层图标资产后再统一重导商店素材；不能在截图完成后继续改动。

### P1 - Operational Confidence

- 复核 Common API、hotel-folio-inbox、Cloudflare Access、D1 / R2 / Queue 和 App Store Server Notifications 的生产 smoke。
- 确认 Dashboard 新旧指标口径已分开，历史样本不被解释为当前构建失败率。
- 归档最终回归基线、发布说明和人工证据；移动产品发布标签前再次确认当前提交无未记录改动。

## Known Risks And Limitations

- 云端商户辅助当前只覆盖首批可解释别名目录；成功响应缓存、持久化 cooldown / backoff、服务端配额和更广别名治理仍未完成。
- CloudKit 合并写入继续使用串行一致性路径；当前优化重点是让网络与解码不阻塞 UI，而不是把所有同步工作并行化。
- TestFlight build number、ASC processing 和人工设备结果属于外部证据，仓库文档不得根据 tag 或 MARKETING_VERSION 猜测；本次 build `120` / SHA / 四平台绑定和审核状态来自实时 API 回读。
- Dashboard 历史数据包含旧版本和旧埋点语义，判断发布质量时必须按 source build 和新指标口径过滤。
- 截图与 App Preview 本地成品仍位于忽略目录；ASC MD5、视频处理状态、poster frame 时间码与生成图状态已经回读，但不会替代原生设备长文本检查或与最终提交 binary 的一致性复核。韩语母语审校是明确接受的非阻断缺口，后续反馈仍应修订文案。
- 三张自定义产品页目前处于 `WAITING_FOR_REVIEW`，获批前其专属 URL 不应作为正式公开落地页；Campaign 与自定义页 Analytics 需要达到 Apple 的隐私阈值后才会显示数据。自定义产品页 API 不接受 Apple Watch screenshot display type，因此差异化素材范围为 iPhone 与 iPad。
- `versions/v1.7.0-plan.md` 保留逐阶段执行记录；其中带日期的“未完成”描述是当时事实，不能覆盖本文件的当前状态。
- `v1.8.0` 与后续语言组是规划事实，不代表实现、ASC locale、截图、识别样本或人工审校已经完成。

## Next Actions

1. 等待 Apple 审核，定期只读回读四个平台状态；没有 `UNRESOLVED_ISSUES` 或 Resolution Center 新消息时不重复提交。
2. 若审核通过，确认四个平台实际发布状态与商店可见版本；`AFTER_APPROVAL` 会在批准后进入发布流程。
3. 独立监控三张自定义产品页审核；获批并确认专属 URL 可见后，再把 Campaign Link 与对应 `ppid` 页面投入营销。

## Source Of Truth Map

| 问题 | 真源 |
|---|---|
| 项目现在是什么状态 | 本文件 |
| 产品长期往哪里走 | [docs/ROADMAP.md](docs/ROADMAP.md) |
| 全球市场、App Store、国际化、Pro 与结构风险 | [docs/product/GLOBAL_PRODUCT_STRATEGY.md](docs/product/GLOBAL_PRODUCT_STRATEGY.md) |
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
