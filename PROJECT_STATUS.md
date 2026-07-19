# AutoLedger Project Status

> 文档状态：Canonical
> 真源范围：当前开发线、发布阶段、已验证基线、剩余门禁和下一步
> 截止日期：2026-07-19
> 上位产品路线图：[docs/ROADMAP.md](docs/ROADMAP.md)
> 跨版本语言路线：[docs/product/I18N_ROADMAP.md](docs/product/I18N_ROADMAP.md)
> 当前版本执行计划：[versions/v1.7.0-plan.md](versions/v1.7.0-plan.md)

## Current Snapshot

| 项目 | 当前状态 |
|---|---|
| 内部开发线 | `v1.7.0` |
| App Store 对外版本 | `1.6.0` |
| 发布阶段 | Release Candidate 阻断修复完成，等待替换 TestFlight 候选 |
| 已验证候选产品行为基线 | build `119` / `9414b91694d4` 已被水单邮箱本地状态缺陷否决；替换候选尚未触发 |
| Xcode Cloud 触发标签 | `xcbuild-v1.7.0` 仍指向旧基线 `9414b91694d4`，需在修复提交后移动 |
| 最近人工结论 | 当前 TestFlight 候选整体已接近发布；TS 117 起 Tab 体感明显改善 |
| 精确 TestFlight build | 最近成功 build 仍为 `119` / `9414b91694d4`，但不再是最终候选；ASC 现有四平台绑定需在替换 build 成功后更新 |
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
- 已修复刷新水单导致地址显示偶发变化：Keychain access token 更新不再删除真实 routing inbox address，App 不再从 access token 派生伪邮箱，候选列表会回传认证后的真实地址以自动修复旧本地状态。folio Worker 已部署 staging `bfaacd81-396a-435d-93a3-93e5a13df02b` 与 production `2b1dd061-648c-446b-bcce-45c5e12daf65`。
- 数据清洗的云端辅助已形成第一版可用闭环：用户显式开启且具备 Pro 权益时，App 发送商户键哈希和聚合特征，Worker 返回 hash-only 商户别名建议，用户确认前不会改写账本。
- 自动化规则指标已统一布局和字号，商户别名、分类修正和受影响账单说明不再截断。
- `docs/` 已按产品、架构、能力、平台、运维和归档物理分组；核心 `ROADMAP.md` 作为唯一专项例外保留在 `docs/` 根目录。
- 已建立每版本一组新语言的跨版本路线和 `v1.8.0` Draft；工程 `developmentRegion = en` 已核验，ASC Primary Language 已在线回读确认为 `English (U.S.) / en-US`。
- 五语六平台截图已完成 ASC `1.6.0` 上传与 API 回读：中简、中繁、美英、日、韩在 iPhone、iPad、Mac、Watch、tvOS、visionOS 的 150 张目标截图均与本地 MD5 矩阵匹配；显式存在的 `en-GB` 已同步 `en-US` 元数据和六平台当前英文截图，避免旧资产覆盖主语言 fallback。
- ASC `1.5.0` 四平台元数据已从线上归档；ASC `1.6.0` 的 iOS、macOS、tvOS、visionOS 已创建并处于 `PREPARE_FOR_SUBMISSION`，planned 五语第一版版本文案已填充并回读一致。Primary Language 已确认为 `en-US`，韩语 App 名称、副标题、隐私链接与 Apple TV 隐私正文已定点写入并回读一致。
- ASC `1.6.0` 五语 iPhone App Preview v003 已上传：五条视频均与本地 MD5 一致且 `videoDeliveryState=COMPLETE`；英文 / 简中旧片在新片完成后删除。五语 poster frame 已统一为 OCR 首屏的 `1.4s / 00:00:01:12`，API 回读时间码与生成图状态均为 `COMPLETE`。韩语母语审校按发布决定转为非阻断质量增强；最终 binary 逐镜一致性核验仍未完成。
- 四平台 Review Notes 已从 repo profile 写入 ASC 并按长度 / SHA-256 回读一致；iOS / macOS 使用主功能说明，tvOS / visionOS 使用只读看板说明，均保持 `demoAccountRequired=false` 且未覆盖审核联系人字段。
- Xcode Cloud build `119` 已确认运行成功且源码为 `9414b91694d405d3e4c91edbae99d547c1684564`；ASC `1.6.0` 四个平台版本均已绑定各自的有效、未过期、App Store eligible build，并完成幂等 API 回读。
- ASC App Privacy 已人工查看：Crash Data、Performance Data、Product Interaction 均用于 Analytics，not linked，not tracking，与 `PrivacyInfo.xcprivacy` 一致；Privacy Policy URL 已保存为 `https://getautoledger.app/privacy`，页面回读新值并标记“已编辑”，该变更将随下一版本发布。
- ASC `1.6.0` 四平台五语 Promotional Text 与结构化 App Description 已统一；“截图与小票识别”“酒店水单归档”“本地优先与 Apple 生态”三张五语自定义产品页已创建为草稿。三页五语 iPhone / iPad 共 30 个截图集已按 OCR、酒店、Apple 生态分别裁剪为 iPhone 5 张 / iPad 4 张的不同主题集合，并全量有序 MD5 回读匹配；Reddit、V2EX、SSPAI、Website、QRCode Campaign Link 已生成，官网五语宣传语已部署。自定义页尚未提交审核或公开。
- 用户已在 build `119` 完成 iCloud 同步 smoke且未发现同步问题；但 2026-07-19 的水单刷新现场日志暴露 App runtime 缺陷，因此该 build 已失去最终候选资格。修复不修改 CloudKit schema 或 entitlement，但必须生成替换 TestFlight build，并重新验证水单连续刷新、401 自动续签和 iCloud 基本 smoke。

详细证据见 [process/iteration-log.md](process/iteration-log.md) 的 `ITER-421` 至 `ITER-437`。

## Release Gates

### P0 - Candidate Evidence

- build `119` 已因水单邮箱本地状态缺陷被否决；修复提交后必须触发新的 Xcode Cloud 四平台 build、确认精确源码 SHA，并将 ASC `1.6.0` 四平台重新绑定到替换候选。
- iPhone、iPad、Mac 分别完成冷启动、快速切 Tab、月报月份切换、数据清洗和 OCR 固定路径 smoke；单设备结果不能替代其它平台。
- 最新 TestFlight 候选的 iCloud 同步 smoke 已由用户确认未发现问题；若后续修改 App runtime、CloudKit schema、entitlement 或同步实现，必须在新候选重新执行。
- 使用重庆 Moxy 记录复测“保留本机 -> 推送 -> 拉取”，确认并发改动冲突不再复活。
- 在最新候选中验证云端水单收件箱 `401` 自动续签不会更换既有专属地址，并验证云端商户别名建议成功与失败 fallback。

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
- TestFlight build number、ASC processing 和人工设备结果属于外部证据，仓库文档不得根据 tag 或 MARKETING_VERSION 猜测；本次 build `119` / SHA / 四平台绑定来自实时 API 回读。
- Dashboard 历史数据包含旧版本和旧埋点语义，判断发布质量时必须按 source build 和新指标口径过滤。
- 截图与 App Preview 本地成品仍位于忽略目录；ASC MD5、视频处理状态、poster frame 时间码与生成图状态已经回读，但不会替代原生设备长文本检查或与最终提交 binary 的一致性复核。韩语母语审校是明确接受的非阻断缺口，后续反馈仍应修订文案。
- 三张自定义产品页目前处于 `PREPARE_FOR_SUBMISSION`，获批前其专属 URL 不应作为公开落地页；Campaign 与自定义页 Analytics 需要达到 Apple 的隐私阈值后才会显示数据。自定义产品页 API 不接受 Apple Watch screenshot display type，因此差异化素材范围为 iPhone 与 iPad。
- `versions/v1.7.0-plan.md` 保留逐阶段执行记录；其中带日期的“未完成”描述是当时事实，不能覆盖本文件的当前状态。
- `v1.8.0` 与后续语言组是规划事实，不代表实现、ASC locale、截图、识别样本或人工审校已经完成。

## Next Actions

1. 提交并推送水单地址稳定性修复，移动 `xcbuild-v1.7.0` 触发替换四平台构建；成功后用精确 build / SHA 更新 ASC 绑定。
2. 在替换 TestFlight 上连续刷新水单至少 5 次，覆盖正常 200 与一次 401 自动续签，确认显示和复制地址始终一致；同时复跑 iCloud 基本 smoke。
3. 复核已冻结商店资产、Review Notes、App Privacy 与最终 binary 一致性，完成 release-readiness 审计后再提交审核。

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
