# StoreKit Products

> 文档状态：Active
> 真源范围：Support Developer 与 AutoLedger Pro 商品 / 权益说明；可执行 gate 以代码和服务端 entitlement 为准
> 上位路线图：[ROADMAP.md](ROADMAP.md)

更新日期：2026-07-17

## 1. 产品定位

AutoLedger 的付费能力分为两条线：

- `Support Developer`：一次性消耗型赞助，不解锁功能，不影响任何记账能力。
- `AutoLedger Pro`：订阅型自动化权益，只解锁省时间的自动化能力，例如本地邮箱水单扫描、专属水单收件箱、批量候选导入、高级去重、高级搜索、订阅异常提醒、月结导出包、智能整理建议、高级规则自动应用和用户显式开启后的第一版云端商户别名建议。

基础记账长期免费。手动记账、单张截图 / 照片识别、语音 / 文本输入、手动酒店水单 PDF 导入、酒店历史记录查看、基础订阅管理、基础月报、Widget / Share Extension、JSON 导入导出、备份恢复以及历史记录编辑 / 删除，都不应被 Pro 锁住。

## 2. StoreKit 配置文件

本地配置文件：

```text
AutoLedger/AutoLedgerSupport.storekit
```

Xcode Scheme：

```text
AutoLedger.xcworkspace -> AutoLedger scheme -> Run -> Options -> StoreKit Configuration
```

如果 Xcode 没有自动选中，请在 Scheme Editor 中手动选择 `AutoLedger/AutoLedgerSupport.storekit`。

## 3. Support Developer Consumables

这些产品只用于支持独立开发，不授予功能权益。

| Reference Name | Product ID | Price | Type |
|---|---|---:|---|
| Coffee Support | `top.darkrio326.AutoLedger.support.coffee` | $0.99 | Consumable |
| Lunch Support | `top.darkrio326.AutoLedger.support.lunch` | $4.99 | Consumable |
| Sponsor Support | `top.darkrio326.AutoLedger.support.sponsor` | $9.99 | Consumable |

购买成功后页面显示感谢状态，并在本地记录：

- `supportPurchaseCount`
- `lastSupportProductId`
- `lastSupportDate`

取消购买不应显示成功；pending 状态会显示等待处理提示；unverified transaction 不会记录支持状态。

## 4. AutoLedger Pro Subscriptions

这些产品属于同一个 `AutoLedger Pro` subscription group。

| Reference Name | Product ID | Price | Period |
|---|---|---:|---|
| AutoLedger Pro Monthly | `top.darkrio326.AutoLedger.pro.monthly` | $2.99 | Monthly |
| AutoLedger Pro Yearly | `top.darkrio326.AutoLedger.pro.yearly` | $19.99 | Yearly |

当前首发年付价为 `$19.99 / year`。后续新订阅用户价格可能调整；已订阅用户将尽量保留当前续订价格。实际价格、地区税费和本地化展示以 App Store Connect 为准。

Pro 当前 P0 自动化权益：

- 本地邮箱水单扫描。
- 专属酒店水单收件箱。
- 批量候选导入。
- 高级去重自动拦截和解释。
- 高级搜索组合筛选。
- 订阅异常与续费压力提醒。
- 月结包导出。
- 高级规则自动应用。
- 商户归一化与智能整理建议。

Pro 到期后：

- 不锁历史账本、酒店消费记录、原始 PDF、基础导出或手动编辑。
- 暂停新的 Pro 自动化入口。
- 用户可继续使用免费基础路径手动完成同类工作。

## 5. 本地测试建议

1. 使用 `AutoLedgerSupport.storekit` 运行 App。
2. 进入 设置 -> AutoLedger Pro。
3. 确认页面展示月付、年付、恢复购买、管理订阅和免费版说明。
4. 购买月付或年付订阅，确认 `ProEntitlementManager.isProActive` 变为 true。
5. 使用 StoreKit 测试面板模拟取消、过期、账单重试和恢复购买。
6. Pro 到期后确认历史账单、酒店消费历史、手动 PDF 导入、基础导出和编辑 / 删除仍可使用。
7. 非 Pro 状态下确认本地邮箱扫描、批量候选导入、专属收件箱、高级搜索、订阅异常、月结包、高级规则和智能整理建议提示 Pro 自动化说明，并保留手动替代路径。

命令行结构校验：

```bash
ruby -rjson -e 'JSON.parse(File.read("AutoLedger/AutoLedgerSupport.storekit"))'
swift -F /Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks \
  -e 'import StoreKitTest; import Foundation; _ = try SKTestSession(contentsOf: URL(fileURLWithPath: "AutoLedger/AutoLedgerSupport.storekit")); print("storekit-session-loaded")'
```

## 6. App Store Connect 配置

Consumable IAP：

1. 进入 App Store Connect -> AutoLedger -> Monetization -> In-App Purchases。
2. 创建 3 个 Consumable 产品，并确保 Product ID 与本文件一致。
3. 补齐英文、简体中文、繁体中文本地化展示名和说明。

Subscription：

1. 进入 App Store Connect -> AutoLedger -> Monetization -> Subscriptions。
2. 创建 `AutoLedger Pro` subscription group。
3. 创建月付和年付两个 subscription product。
4. Product ID 必须与代码和 StoreKit 配置完全一致：
   - `top.darkrio326.AutoLedger.pro.monthly`
   - `top.darkrio326.AutoLedger.pro.yearly`
5. 补齐英文、简体中文、繁体中文、日文、韩文本地化展示名和说明。
6. 确认隐私政策 URL、订阅说明、恢复购买入口和管理订阅入口在审核前可用。

App 内不要引导用户使用外部支付方式，不要在文案中提供外部付款链接。

## 7. Review Notes 建议

```text
AutoLedger includes optional consumable purchases for developer support and AutoLedger Pro subscriptions for time-saving automation. Core bookkeeping remains free. Pro does not lock existing ledger data, manual entries, manual hotel folio PDF import, basic export/import, widgets, basic reports, or historical editing/deletion.

Pro automation covers email folio scanning, a dedicated cloud folio inbox, batch candidate import, advanced deduplication, advanced search, subscription anomaly detection, monthly export packages, smart cleanup suggestions, and advanced rule automation. Pro automation creates reviewable candidates only. It does not silently write transactions into the ledger. Hotel folio entries still require user review before saving.
```

## 8. 当前边界

- `Support Developer` 和 `AutoLedger Pro` 是两条独立产品线。
- `Support Developer` 不授予 Pro 权益。
- `AutoLedger Pro` 只 gate 自动化入口，不 gate 历史数据和基础记账。
- C1 专属收件箱不登录用户邮箱，不保存用户 IMAP / QQ / Gmail / Outlook 授权码。
- 云端水单候选不会自动正式入账，必须由用户在 App 中确认。
- 真实订阅 entitlement 后端校验、token 到期同步和运营面板继续后续收口。
