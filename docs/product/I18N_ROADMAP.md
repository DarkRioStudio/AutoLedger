# AutoLedger Cross-Version Localization Roadmap

> 文档状态：Canonical
> 真源范围：跨版本语言 / 市场分组、主语言策略、发布准入门禁和地区识别扩展顺序
> 最后核验：2026-07-20
> 上位产品路线图：[ROADMAP.md](../ROADMAP.md)
> 全球市场策略：[GLOBAL_PRODUCT_STRATEGY.md](GLOBAL_PRODUCT_STRATEGY.md)
> 当前版本语言矩阵：[../../versions/v1.7.0-i18n-release-matrix.md](../../versions/v1.7.0-i18n-release-matrix.md)
> 下一版本语言矩阵：[../../versions/v1.8.0-i18n-release-matrix.md](../../versions/v1.8.0-i18n-release-matrix.md)

## Product Decision

AutoLedger 从 `v1.7.0 / ASC 1.6.0` 起采用产品主题 + 语言 / 市场质量双主线：

> **每个公开功能版本同时交付一个产品主题和一组可验证的语言 / 市场能力。**

市场组可以新增 UI 语言，也可以在不新增语言时完成英语地区格式、币种、截图、价格、支持和隐私质量。语言组不是 `Localizable.strings` 的数量承诺。一个语言只有在商店、界面、识别、样本、地区票据和人工审校六项均达到发布门禁后，才可以在 App Store 和公开文案中标记为支持。

该原则不改变当前 `v1.7.0` 的范围：本版本新增语言仍只有韩语。`v1.8.0` 改为英语五市场质量组，不新增 UI 语言；日语质量提升、德语和法语进入第二阶段，西班牙语与巴西葡语顺延为后续候选。

## English Primary Language

从 App Store 对外版本 `ASC 1.6.0` 起，AutoLedger 的主语言策略统一为英语：

- Xcode 工程默认开发区域使用 `en`；当前 `AutoLedger.xcodeproj` 已满足 `developmentRegion = en`，无需为本决策修改产品代码。
- App Store Connect Primary Language 目标值为 `English (U.S.) / en-US`。
- 英语是缺少本地化资源时的默认回退语言；不能把简体中文继续作为新 target、新扩展或新截图场景的隐式 fallback。
- 产品合同、事件名、文件格式、API 字段和持久化枚举继续使用稳定的语言中立标识；用户可见英文文案是翻译源，不把显示文本写入业务判断。
- ASC Primary Language 的实际切换属于发布操作，不以仓库文档或 YAML 字段代替线上证据。执行前必须确认英语已在先前版本通过审核、全平台英语截图满足 Apple 条件，并确认当前 App 信息处于可编辑状态。

Apple 将 App 二进制本地化与 App Store metadata 本地化分开管理，因此“工程默认英语”和“ASC 主语言英语”必须分别验证。

## Language And Market Cohort Definition

### Market-Readiness Cohort

适用于共享一种 UI 语言、但日期、币种、价格、税费、术语、截图或支持内容不同的多个市场：

- 不以复制 locale 数量代替地区验收；
- 逐市场验证日期、数字、货币、订阅价格、商店截图、支持页和隐私说明；
- 英语第一阶段固定为美国、英国、加拿大、澳大利亚和新加坡。

### Standard Cohort

适用于共享拉丁字母、数字和相近票据基础设施的语言：

- 每个版本最多新增两种 UI 语言；
- 可为同一 UI 语言维护多个地区识别 profile 和 ASC locale；
- 同一组尽量共享金额、日期、税费、酒店字段和截图验收工具。

### Complex-Script Cohort

适用于印地语、泰语、阿拉伯语等需要字体、混排、OCR 或布局专项的语言：

- 一个版本以一种新 UI 语言为主；
- 同时交付对应的英语混排或地区支付识别 profile；
- RTL、复杂断词或特殊数字系统必须作为版本级 UI 基础设施验收，不能只加词表。

语言组数量不是绩效目标。若一个复杂语言无法通过真实样本和母语审校，不能以增加另一种 UI 翻译来替代质量门禁。

## Version Cohorts

| 内部开发线 | 对外版本 | 产品主题 | 新语言 / 地区组 | 主要地区识别任务 | 状态 |
|---|---|---|---|---|---|
| `v1.7.0` | ASC `1.6.0` | 当前发布收口 | 韩语 `ko` / 韩国 | KRW、韩国卡单、Kakao Pay、Naver Pay、VAT、韩英酒店水单 | Release Candidate；母语审校、真实样本和 ASC 材料仍是门禁 |
| `v1.8.0` | ASC `1.7.0` | Global Readiness & Review/Close | 英语市场组：美国、英国、加拿大、澳大利亚、新加坡 | `en-US` 主语言；MDY / DMY、USD / GBP / CAD / AUD / SGD、税费、酒店水单、价格和支持内容 | Planned；不新增 UI 语言 |
| `v1.9.0` | ASC `1.8.0` | Understand & Save | 日语质量提升 + 德语 `de` + 法语 `fr` | 日本；德国 / 奥地利 / 瑞士；法国 / 加拿大；JPY、EUR、CAD、CHF 与酒店字段 | Planned |
| `v2.0` | 待确定 | Archive & Remember | 西班牙语 `es` + 巴西葡语 `pt-BR` 候选 | `es-ES`、`es-MX`、拉美票据；PIX、CNPJ、NF-e、BRL | Candidate |
| 后续独立版本 | 待确定 | Regional expansion | 印尼语、越南语、印地语 / 印度英语、阿拉伯语 / RTL | 每组按市场证据、脚本复杂度、票据样本和维护人力单独冻结 | Later |

泰语 `th`、马来语 `ms`、意大利语 `it`、荷兰语 `nl` 等保留在候选池；不得在缺少市场证据、样本和维护人力时提前绑定公开版本。

## Six Release Gates

### 1. Store Visibility

- App Store Connect App Information、版本信息、关键词、订阅组和订阅商品均有对应 locale。
- 所有公开平台都有该语言截图；App Preview 若对该语言公开，也必须有可审校版本。
- metadata-as-code audit 能发现 planned locale、stale locale、缺失订阅文案和错误 fallback。

### 2. UI Readability

- 主 App、Watch、Widget、Control Widget、Share Extension、App Intents / Shortcuts 和截图模式主路径覆盖完整。
- key 集合与英语源一致；允许地区差异文案，但不能静默缺 key。
- 完成长文本、动态字体、窄屏、复数、数字、日期和货币格式检查。

### 3. Recognition Pack

- `AutoLedgerCore` 提供金额、日期、总额层级、商户标签、非商户排除词、分类关键词和 OCR hint。
- OCR 运行时使用 Vision 实际支持的 recognition language；不根据 App locale 假设系统一定支持。
- 不支持或置信度不足时回退到英语 / 通用规则和用户确认，不能伪造高置信度结果。

### 4. Realistic Samples

- 每种新 UI 语言在进入 Release Candidate 前准备 20-50 条脱敏或高拟真的支付、小票、订阅和酒店样本。
- 最小 golden 集必须覆盖总额、商户、日期、币种和至少两个主要分类。
- 样本不能包含真实姓名、邮箱、卡号、订单号、酒店确认号、可扫描二维码或个人地址。

### 5. Regional Receipt Coverage

- 至少覆盖一个主流支付场景、一种普通小票和一种酒店水单。
- 金额小数、千分位、税费、服务费、折扣、找零、发票号和当地币种进入专项回归。
- 地区 profile 只影响解析与展示，不改变交易 schema 或 Free / Pro 边界。

### 6. Human Review

- 用户可见核心路径、商店文案和订阅文案必须完成人工审校。
- 机器翻译可以作为初稿，不得作为 Ready 证据。
- 人工审校问题必须回填术语表、golden case 或静态门禁，避免下一版本重复出现。

## Version Workflow

每个版本按以下顺序推进语言 / 市场组：

1. **Version kickoff**：冻结目标市场、locale、地区 profile、术语表负责人、样本来源和明确非目标。
2. **Contract first**：先扩展语言包数据和 golden runner，再接 UI 和 OCR hint。
3. **Feature string freeze**：产品主题主流程冻结后，停止增加非阻断用户文案，进入全 target 翻译与长文本审计。
4. **Store asset freeze**：UI、识别和样本门禁通过后生成截图、metadata、订阅本地化和 App Preview。
5. **Release Candidate**：母语审校、ASC audit、全量离线回归和真实设备主要路径全部通过后才能标 Ready。

语言 / 市场组未完成时可以继续修复版本内其它问题，但不能用“先发布 UI 翻译、以后补识别”或“同为英语无需地区验证”绕过门禁。若发布必须延期，应缩减版本内 P1 产品功能，而不是降低质量定义。

## Platform And AI Boundaries

- iPhone、iPad 和 Mac 是完整语言主路径；Watch、Widget、Share Extension 和 App Intents 维持入口一致性；tvOS / visionOS 继续只读，但公开截图和核心文案不能回退到错误语言。
- Foundation Models、Apple Intelligence 或其它模型功能必须在运行时检查 locale 与设备可用性；App 支持某种语言不等于系统模型支持该语言。
- 端侧或云端模型只负责解释、提取和建议；金额计算、规则执行、月结状态和账本写入继续由确定性代码完成。

## Source Of Truth Boundaries

| 文档 | 负责 | 不负责 |
|---|---|---|
| 本文件 | 跨版本语言 / 市场顺序、主语言策略、通用门禁 | 单一版本完成度、具体测试证据 |
| [ROADMAP.md](../ROADMAP.md) | 产品主题和语言双主线优先级 | locale 级实现清单 |
| [GLOBAL_PRODUCT_STRATEGY.md](GLOBAL_PRODUCT_STRATEGY.md) | 目标市场、App Store 方向和国际化检查清单 | locale 级执行证据 |
| `versions/vX.Y.Z-i18n-release-matrix.md` | 单一版本语言完成度和缺口 | 改变跨版本语言顺序 |
| `versions/vX.Y.Z-plan.md` | 版本产品范围、GOAL、验收和非目标 | 独立定义语言质量标准 |
| `tools/asc-metadata/metadata.yml` | 计划发布的 metadata 内容 | 证明 ASC 已在线应用或审核通过 |
| Xcode 工程与本地化资源 | 可执行 target、默认回退和 UI 内容 | App Store Primary Language 线上状态 |

## Non-Goals

- 不以语言数量替代识别质量、真实样本或母语审校。
- 不在一个普通版本同时启动三种以上新 UI 语言。
- 不远程热更新可执行识别规则，也不自动上传用户票据或纠错原文。
- 不因新增语言改变基础识别免费、Pro 自动化收费的产品边界。
- 不把 App Store metadata 已添加等同于 App 二进制、截图或识别已经支持。
- 不承诺税务、报销、金融或发票合规；地区票据优化只服务个人记录与复核。

## Official References

- [Localize app information](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information)
- [App Store localizations](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations/)
- [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [Supporting languages and locales with Foundation Models](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)

## Update Rules

- 只有语言组顺序、主语言策略、通用门禁或复杂脚本定义变化时更新本文件。
- 单一版本的样本数、完成度、审校结果和 ASC 证据只更新对应版本矩阵。
- 新版本进入规划时必须在本文件分配语言或市场组；没有质量组的公开功能版本不能进入 Execution Ready。
- 调整语言顺序时必须同步检查产品范围，确保语言工作不是发布末期追加项。
