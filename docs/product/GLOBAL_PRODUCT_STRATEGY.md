# AutoLedger Global Product Strategy

> 文档状态：Active
> 真源范围：全球产品定位、目标市场、App Store 方向、国际化准入、Pro 商业化和功能优先级
> 最后核验：2026-07-20
> 上位路线图：[../ROADMAP.md](../ROADMAP.md)
> 语言路线：[I18N_ROADMAP.md](I18N_ROADMAP.md)

本文把 Auto+ 的共同原则落到 AutoLedger。它只调整产品与发布规划，不表示 App Store Connect 已写入、价格已变更或新功能已经实现。

## 1. Auto+ 共同方向

Auto+ 面向全球 Apple 用户，核心不是让用户频繁打开 App，而是让工具主动完成重复工作。

共同原则：

- Apple 原生体验优先；
- Privacy First：先说明数据边界，再设计自动化；
- Local First：核心数据与基础路径优先留在设备和用户自己的 iCloud；
- 尽量减少账号依赖；
- 自动化优先于手动重复操作，但重要结果仍可复核、可撤销；
- 英语作为默认产品语言与公开翻译源；
- 面向旅行者、Apple 生态重度用户、开发者和自动化爱好者设计。

## 2. 产品定位

中文定位：

> **本地优先的个人账本 + 自动化导入 + 酒店水单归档。**

英文定位：

> **Private, local-first personal expense ledger with automated imports.**

AutoLedger 的价值不是传统预算管理，而是把用户已有的消费材料变成可复核、可追溯的个人记录：

- 截图、照片、小票、相册和剪贴板导入；
- Shortcuts、App Intents、Siri 和 Apple Watch 快速记录；
- iCloud 同步与 Apple 原生多设备体验；
- 多币种、原币金额和汇率信息；
- 酒店水单 PDF、邮件候选和旅行消费归档；
- Pro 批量处理、规则、异常发现和月结自动化。

### 明确不竞争

AutoLedger 不以以下方向作为增长主线：

- 银行账户直连、银行聚合或自动抓取银行流水；
- 复杂预算、家庭资产、投资组合或财务建议；
- 企业报销、会计协作和税务合规；
- 针对单一地区支付平台持续堆叠专用入口。

已经存在的地区识别规则继续维护回归，但不再以“覆盖更多本地支付平台”作为全球产品卖点或版本主目标。

## 3. 目标用户与核心任务

| 用户 | 核心任务 | AutoLedger 价值 |
|---|---|---|
| Apple 生态重度用户 | 从系统入口快速留下记录 | Shortcuts、Siri、App Intents、Watch、Share Extension |
| 隐私敏感用户 | 不建立新的财务账号体系 | 本地账本、可选 iCloud、明确云端边界 |
| 经常旅行的用户 | 处理多币种、酒店 PDF 和旅行凭证 | 原币记录、汇率说明、酒店水单档案 |
| 开发者与自动化用户 | 减少重复导入和整理 | JSON、快捷指令、规则、批量候选与月结包 |
| 不想维护复杂预算的用户 | 保留可搜索、可导出的消费历史 | 轻量个人账本与复核流程 |

## 4. 全球市场顺序

### 第一阶段：英语市场验证

- 美国；
- 英国；
- 加拿大；
- 澳大利亚；
- 新加坡。

第一阶段不以新增 UI 语言数量为目标，而以英语默认体验、地区日期格式、多币种、汇率解释、隐私说明、商店转化和支持内容为准入条件。`en-US` 是 ASC 主语言；`en-GB`、`en-CA`、`en-AU` 和 `en-SG` 可以复用英语内容，但必须验证日期、货币、税费、术语和截图是否需要地区差异。

### 第二阶段：日德法

- 日本：维护并提升现有日语 UI、识别包、截图和人工审校质量；
- 德国：新增德语 UI、商店材料和德语地区票据 / 酒店水单样本；
- 法国：新增法语 UI、商店材料，并覆盖法国与加拿大法语差异。

现有简体中文、繁体中文和韩语资产继续维护，不删除、不降级；它们不再决定全球增长版本的先后顺序。西班牙语与巴西葡语从已绑定的下一版本范围中移出，保留为日德法之后的候选组。

## 5. App Store 元数据调整建议

以下是下一次可编辑版本的建议，不应直接覆盖已审核版本，也不代表已经写入 ASC。

### English (U.S.)

| 字段 | 建议 |
|---|---|
| Name | `AutoLedger: Private Ledger` |
| Subtitle | `Receipts, folios & travel` |
| Promotional text | `Import receipts, screenshots, voice notes, and hotel folios into a private, local-first ledger—then review before anything is saved.` |
| Keywords | `private ledger,receipt import,travel expense,hotel folio,local finance,OCR,Shortcuts,multi currency` |

建议描述开头：

> AutoLedger is a private, local-first personal expense ledger with automated imports. Turn receipts, screenshots, voice notes, Shortcuts, and hotel folios into reviewable records—without connecting a bank account or building another online financial profile.

避免把 `expense tracker`、`budgeting app` 作为标题或主定位；如果用于搜索覆盖，只能作为低权重测试词，不能改变产品承诺。

### 截图叙事顺序

1. **Your private ledger, on your Apple devices**：先建立本地优先与 Apple 原生心智；
2. **Import what you already have**：截图、小票、相册、剪贴板；
3. **Travel receipts, organized**：酒店 PDF、多币种、住宿档案；
4. **Automate the repetitive parts**：Shortcuts、Siri、Watch、邮件候选；
5. **Review before saving**：确认、编辑、去重和可撤销边界。

自定义产品页继续按 OCR、酒店水单、本地优先 / Apple 生态划分；每页必须使用真正不同的截图集合，而不只是调整首屏顺序。

## 6. 国际化检查清单

### 语言与界面

- [ ] 英语是新 key、新 target、App Intents 和截图文案的默认翻译源；
- [ ] 主 App、iPad、Mac、Watch、Widget、Share Extension、Control Widget、Siri / Shortcuts key 集一致；
- [ ] 长文本、Dynamic Type、窄屏、VoiceOver、复数和字符串插值通过检查；
- [ ] 用户可见文本不参与业务枚举、解析判断或持久化合同；
- [ ] 机器翻译只作为初稿，公开 locale 需要人工审校。

### 日期、数字与币种

- [ ] 展示使用用户 locale，不把 `MM/dd`、`yyyy/MM/dd`、`HH:mm` 或中文年月格式写死；
- [ ] 识别时区分 `MM/dd` 与 `dd/MM`，歧义日期进入复核；
- [ ] 金额遵循 ISO 4217、地区小数位、千分位、负数、退款和零小数币种；
- [ ] 账本本位币、原始币种、换算金额、汇率日期和提供方可区分；
- [ ] 汇率失败时保留原币金额并明确待处理，不静默使用过期或猜测汇率；
- [ ] 月报与跨币种汇总明确汇率口径，不暗示会计或税务准确性。

### 票据、酒店与隐私

- [ ] 每个目标市场覆盖普通收据、酒店水单、税费 / 服务费和多币种真实或高拟真样本；
- [ ] OCR language hint 以 Vision 实际支持为准，并保留通用回退；
- [ ] 邮件扫描、专属收件箱、PDF 暂存、Common API 和汇率请求分别说明数据、目的、保留期与失败路径；
- [ ] App Store Privacy、隐私政策、App 内说明、Review Notes 与真实实现一致；
- [ ] 测试样本、截图和日志不包含真实姓名、邮箱、订单号、卡号、地址或二维码。

### 商店与发布

- [ ] 第一阶段五个英语市场分别检查 name、subtitle、keywords、截图、价格和支持页；
- [ ] 订阅组、月付、年付、恢复购买和管理订阅均有对应 locale；
- [ ] 每套商店截图在真实设备尺寸上人工预览，不把 metadata 已添加等同于 locale Ready；
- [ ] 英语主语言、工程 fallback、App Store locale 和截图语言分别留证。

## 7. Pro 商业化方向

主要付费表达统一为：

> **Unlock automation. / 解锁自动化能力。**

用户购买的是节省时间、批量处理和高级自动化，不是“支持开发者”，也不是访问自己历史数据的权利。

建议美国基准价格：

| 方案 | 价格策略 |
|---|---:|
| Monthly | `$2.99 / month` |
| Annual Early Bird | `$19.99 / year` |
| Annual Standard | `$24.99 / year` |

不同地区可以独立配置价格档位。早鸟转标准价必须在 App、订阅说明和运营计划中明确，不默认改变既有订阅者续订待遇。一次性 Support Developer 商品可以保留为次要、可选入口，但不再承担主要付费叙事、首页转化或 App Store 主描述。

## 8. 功能优先级

### P0 — 全球发布基础

1. 英文 App Store 名称、副标题、描述、关键词与截图叙事；
2. 国际日期、时间、数字和货币格式；
3. 多币种原币 / 本位币 / 汇率日期 / 提供方体验；
4. 隐私说明与所有可选云能力的数据边界；
5. 第一阶段英语市场的支持页、价格、截图和真实设备验收。

### P1 — 可感知的自动化价值

1. 酒店水单 PDF 识别与跨地区样本质量；
2. 邮箱水单候选和专属收件箱可靠性；
3. 消费总结卡片和隐私分级分享；
4. 统一待处理、批量复核、规则和月结自动化；
5. Pro 价值说明、转化与留存证据。

### 降低优先级

- 新的银行同步或聚合；
- 新的地区支付平台专用入口；
- 复杂预算、家庭资产、投资和企业财务；
- 为增加语言数量而缺少票据样本、截图与人工审校的翻译。

## 9. 当前代码结构风险（仅记录，不在本阶段重构）

| 风险 | 当前证据 | 全球化影响 | 后续建议 |
|---|---|---|---|
| 核心格式器仍以中国为默认 | `AppFormatters` 默认 `CNY`、`¥`、`zh_CN` 和中文年月格式 | 主 App 多处调用会在英语市场展示错误币种或日期 | 下一阶段先建立 locale + ledger currency 格式合同，再逐入口迁移 |
| Watch / Widget 有硬编码 | Watch 与 Widget 存在 `¥`、`MM/dd`、`yyyy/MM/dd`、`万` 和 `CNY` | Apple 多设备体验与主 App 不一致 | 统一复用可注入的金额 / 日期 formatter，并传递账本币种 |
| 语音识别固定中文 | `VoiceSpeechRecognizer` 固定 `zh_CN` | 英语、日语及后续语言语音入口失效或准确率低 | 按 App 语言与用户选择解析可用 recognizer，保留手动切换 |
| 日期解析存在歧义顺序 | `parseFlexibleDate` 同时接受月日在前和日在前格式 | `06/07/2026` 可能被无提示误解 | 将 locale / 票据证据纳入解析，歧义时强制复核 |
| 历史地区支付规则体量较大 | App/Core 仍维护微信、支付宝、银联等专项规则 | 维护资源容易继续被单一区域样本牵引 | 保留回归但冻结新增入口；新投入优先通用票据 / 酒店字段 |

这些风险只进入下一阶段工程任务，不授权本轮修改 Swift、SQLite、CloudKit、Worker 或 StoreKit 配置。

## 10. 成功判断

- 用户能在 10 秒内理解 AutoLedger 是私密、本地优先的个人账本，而不是预算或银行同步 App；
- 第一屏能同时表达导入自动化、旅行 / 酒店和“保存前复核”；
- 英语市场的日期、币种、语音、Watch 和 Widget 不再隐含中国地区默认；
- Pro 转化围绕节省时间和自动化，Free 仍可完整手动完成；
- 新市场只有在商店、UI、格式、样本、隐私和人工审校全部通过后才标记 Ready。
