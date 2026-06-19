# AutoLedger Recognition Learning Cache Design

更新日期：2026-06-19
关联版本：`v1.6.0`
关联 GOAL：`GOAL-1730`
状态：设计冻结 / L3 第一版已实现

## 1. 目标

识别学习缓存用于降低常见商户的重复识别成本，并提高商户、分类和订阅倾向的稳定性。它只服务“候选增强”，不能替代用户确认、不能决定金额、不能决定日期，也不能把账单自动保存。

本设计覆盖三类能力：

- 商户名称学习：把用户确认过的商户别名、模型候选和最终商户归并成更稳定的商户候选。
- 分类学习：把用户确认过的商户默认分类作为下次候选分类。
- 订阅倾向学习：把用户确认过的订阅服务或订阅否定结果作为下次提示依据。

## 2. 非目标

- 不缓存完整原始 OCR。
- 不缓存原始截图、支付截图、小票图片或图片文件路径。
- 不缓存订单号、卡号、手机号、地址、车牌、司机、路线地点等敏感字段。
- 不缓存金额、发生时间、余额、订单时间等随交易变化的字段。
- 不把“整张 OCR -> 完整账单”作为可复用结果。
- 不用缓存结果自动创建订阅。
- 不因缓存命中跳过用户确认。
- 不引入多账本归属；`v1.6.0` 仍按单一正式账本设计。

## 3. 现有基础

当前工程已经具备以下可复用基础：

- `merchantAliases`：用户确认后的商户别名表，已经进入 SQLite、备份和 iCloud 配置快照。
- `categoryCorrections`：用户确认后的商户分类修正表，已经进入 SQLite、备份和 iCloud 配置快照。
- `subscriptions`：用户确认后的订阅列表，支持手动新增、账单详情创建、编辑、暂停、取消和删除。
- `ExternalReceiptAssistSuggestion.subscriptionHint`：外部模型可以返回订阅候选判断，并写入调试记录。

GOAL-1730 不新增运行时代码，只冻结缓存边界与后续实现策略。

## 4. 缓存分层

### 4.1 L1 用户确认规则

L1 是当前最安全、优先级最高的学习层。

数据来源：

- 用户在账单编辑页确认保存商户别名。
- 用户在账单编辑页或分类学习页确认商户分类。
- 用户在账单详情或订阅管理中显式创建订阅。

允许保存：

- `originalMerchant`
- `canonicalMerchant`
- `category`
- `subscriptionServiceName`
- `subscriptionPeriod`
- `lastUserConfirmedAt`

禁止保存：

- OCR 文本。
- 截图。
- 订单号、卡号、手机号、地址。
- 单笔交易金额和时间。

使用方式：

- 导入时先应用 `merchantAliases`。
- 分类候选优先使用 `categoryCorrections`。
- 订阅提示只作为“可能是已知订阅服务”的 UI hint，仍需用户确认。

### 4.2 L2 商户级低风险画像

L2 是未来可新增的商户画像缓存，粒度是商户，不是某张截图。

建议模型：

```swift
struct MerchantRecognitionProfile {
    let canonicalMerchant: String
    let aliases: Set<String>
    let categoryVotes: [TransactionCategory: Int]
    let externalCandidateVotes: [String: Int]
    let subscriptionPositiveCount: Int
    let subscriptionNegativeCount: Int
    let lastConfirmedAt: Date
    let updatedAt: Date
}
```

写入条件：

- 仅在用户保存账单后写入。
- 用户实际修改了商户、分类或订阅判断时权重更高。
- 外部模型返回的候选只能在用户最终确认后进入计数。

使用方式：

- 作为商户候选排序加权。
- 作为分类候选排序加权。
- 作为订阅提示加权。

限制：

- 不保存 `rawText`。
- 不保存脱敏 OCR 全文。
- 不保存金额和日期。
- 不直接覆盖规则解析出来的金额、日期和来源。
- 不直接自动保存账单。

### 4.3 L3 短期脱敏 OCR hash 缓存

L3 只用于性能优化，已在 `GOAL-1735` 完成第一版实现。

允许保存：

- `sanitizedTextHash`
- `provider`
- `model`
- `merchantCandidates`
- `categoryHint`
- `subscriptionHint`
- `createdAt`
- `expiresAt`

禁止保存：

- `sanitizedText` 原文。
- 原始 OCR。
- 图片。
- 金额、日期、订单号、卡号、手机号和地址。

建议 TTL：

- 默认 24 小时。
- 最长不超过 7 天。
- App 升级或外部 Assist 配置变化后可清空。

同步策略：

- L3 不进入 iCloud 同步。
- L3 不进入 JSON 备份。
- L3 可以只保存在本机 SQLite 或 UserDefaults 的临时命名空间。

当前实现：

- Core 策略：`ExternalReceiptAssistCache.swift`
- App 存储：`ExternalReceiptAssistClient.swift`
- 存储位置：本机 `UserDefaults` 的 `externalReceiptAssistShortTermCache.v1`
- key：脱敏 OCR 文本 SHA-256 指纹 + 来源 + provider + model + endpoint 指纹
- 上限：最多 80 条
- 配置变化：provider / endpoint / model / API key 变化时清理

## 5. 识别链路插入点

推荐顺序：

1. 规则解析金额、日期、来源和明显交通计费短路。
2. 应用 L1 用户确认规则：商户别名、分类修正、已确认订阅服务。
3. 应用 L2 商户画像候选排序，只增强商户 / 分类 / 订阅 hint。
4. 如仍需要外部 Assist，构建脱敏 payload 并请求 provider。
5. 用户保存账单后，根据最终保存结果回写 L1 / L2。
6. 如果后续实现 L3，只在外部 Assist 成功后写入短期 hash 缓存。

硬性规则：

- 金额和日期只来自规则解析、用户编辑或结构化 JSON 输入，不能来自缓存或外部模型。
- 外部模型和缓存都只能影响候选排序、分类 hint 和订阅 hint。
- 订阅创建必须走用户确认链路。

## 6. 冲突与衰减

商户 / 分类冲突：

- 用户最近确认的结果优先。
- 同一商户不同分类可累计投票，但 UI 只展示最高权重分类。
- 如果用户连续修正某个缓存建议，降低该建议权重。

订阅倾向冲突：

- `subscriptionPositiveCount` 只来自用户确认创建订阅或明确保存为订阅服务。
- `subscriptionNegativeCount` 来自用户明确忽略订阅提示。
- 负向次数达到阈值后，该商户不再主动提示订阅，但仍可在调试记录里展示模型 hint。

建议阈值：

- 订阅正向提示：`positive >= 1` 或外部 hint `confidence >= 0.85`。
- 订阅静默降权：`negative >= 2`。
- 商户候选降权：同一候选被用户改掉 2 次后降权。

## 7. 隐私与安全

必须满足：

- 不记录 API key。
- 不记录原始 OCR。
- 不记录未脱敏支付文本。
- 不记录图片或图片路径。
- 不记录订单号、卡号、手机号、地址、车牌、司机、路线地点。
- Debug 输出可以展示脱敏请求摘要和模型候选，但不展示缓存内部 hash 反查材料。

建议：

- hash 使用 SHA-256。
- 如引入 salt，salt 保持本机私有，不进入 iCloud。
- 用户提供“清除识别学习数据”入口时，应清除 L2 / L3；L1 的商户别名、分类修正和订阅列表仍由现有管理页分别维护。

## 8. 同步与备份

推荐策略：

- L1：继续进入现有 SQLite、JSON 备份和 iCloud 配置快照。
- L2：如果实现为用户确认后的商户画像，可进入 iCloud 配置快照，但必须只包含低风险商户级统计。
- L3：不进入 iCloud，不进入备份，只留本机短期性能缓存。

理由：

- L1 / L2 是用户确认后的偏好和低风险统计，适合跨设备延续。
- L3 是 provider 请求结果的短期性能缓存，跨设备同步价值低，且更容易引入隐私和一致性风险。

## 9. 实施拆分

### GOAL-1730

- 冻结设计边界。
- 明确可缓存 / 不可缓存字段。
- 明确 L1 / L2 / L3 分层。
- 不写运行时代码。

### GOAL-1735

- 实现 L3 短期脱敏 OCR hash 缓存。（DONE）
- TTL 默认 24 小时。
- 只缓存候选，不缓存原文。
- 离线回归覆盖 hash 不可逆输入、TTL 过期和 provider 配置变化清理。

### 后续 GOAL

- 实现 L2 商户画像。
- 增加订阅 hint 用户确认提示。
- 增加“忽略此订阅提示”负向学习。
- 增加“清除识别学习数据”入口。

## 10. 验收标准

- 文档明确不缓存原始 OCR、截图、金额、时间和敏感字段。
- 文档明确缓存只增强候选，不覆盖金额和日期。
- 文档明确订阅创建仍需用户确认。
- 文档明确 L3 短期缓存不进入 iCloud 和备份。
- `versions/v1.6.0-plan.md`、`CHANGELOG.md`、`process/iteration-log.md` 回填完成。
