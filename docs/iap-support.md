# Support Developer IAP

更新日期：2026-05-27

## 1. 功能定位

AutoLedger 第一版内购只用于“支持独立开发者”，不做订阅、不做 Pro 解锁，也不回收任何现有免费功能。所有记账、OCR、JSON 导出、iCloud 备份、自定义商户别名、自定义分类、月度统计、Apple Watch 和快捷指令能力继续免费可用。

本轮产品均为 Consumable：

| Reference Name | Product ID | Display Name | Description |
|---|---|---|---|
| Coffee Support | `top.darkrio326.AutoLedger.support.coffee` | Coffee Support | Support the independent development of AutoLedger. |
| Lunch Support | `top.darkrio326.AutoLedger.support.lunch` | Lunch Support | Support future improvements to AutoLedger. |
| Sponsor Support | `top.darkrio326.AutoLedger.support.sponsor` | Sponsor Support | A generous way to support AutoLedger's development. |

本地化展示名与说明需覆盖英文、简体中文、繁体中文：

| Product ID | Locale | Display Name | Description |
|---|---|---|---|
| `top.darkrio326.AutoLedger.support.coffee` | English | Coffee Support | Support the independent development of AutoLedger. |
| `top.darkrio326.AutoLedger.support.coffee` | 简体中文 | 支持一杯咖啡 | 支持 AutoLedger 的独立开发。 |
| `top.darkrio326.AutoLedger.support.coffee` | 繁体中文 | 支持一杯咖啡 | 支持 AutoLedger 的獨立開發。 |
| `top.darkrio326.AutoLedger.support.lunch` | English | Lunch Support | Support future improvements to AutoLedger. |
| `top.darkrio326.AutoLedger.support.lunch` | 简体中文 | 支持一顿午餐 | 支持 AutoLedger 后续改进。 |
| `top.darkrio326.AutoLedger.support.lunch` | 繁体中文 | 支持一頓午餐 | 支持 AutoLedger 後續改進。 |
| `top.darkrio326.AutoLedger.support.sponsor` | English | Sponsor Support | A generous way to support AutoLedger's development. |
| `top.darkrio326.AutoLedger.support.sponsor` | 简体中文 | 赞助开发者 | 更慷慨地支持 AutoLedger 的后续开发。 |
| `top.darkrio326.AutoLedger.support.sponsor` | 繁体中文 | 贊助開發者 | 更慷慨地支持 AutoLedger 的後續開發。 |

## 2. 本地 StoreKit 测试

1. 打开 `AutoLedger/AutoLedger.xcworkspace`。
2. 选择 `AutoLedger` scheme。
3. 确认 scheme 的 Run 配置使用 `AutoLedgerSupport.storekit`。如果 Xcode 没有自动选中，在 Scheme Editor -> Run -> Options -> StoreKit Configuration 中手动选择 `AutoLedger/AutoLedgerSupport.storekit`。
4. 运行 App，进入 设置 -> 支持 AutoLedger。
5. 页面应能显示 3 个支持档位及本地化价格。
6. 点击任意档位，使用 Xcode StoreKit 测试弹窗完成购买。
7. 购买成功后页面会显示感谢状态，并在本地记录：
   - `supportPurchaseCount`
   - `lastSupportProductId`
   - `lastSupportDate`
8. 取消购买不应显示成功；pending 状态会显示等待处理提示；unverified transaction 不会记录支持状态。

## 3. App Store Connect 配置

1. 进入 App Store Connect。
2. 打开 AutoLedger App。
3. 进入 Monetization -> In-App Purchases。
4. 创建 3 个 Consumable In-App Purchase。
5. 分别填写 Reference Name、Product ID、Display Name、Description 和 Price，并补齐英文、简体中文、繁体中文三套本地化展示名与说明。
6. Product ID 必须与代码和 StoreKit 配置完全一致：
   - `top.darkrio326.AutoLedger.support.coffee`
   - `top.darkrio326.AutoLedger.support.lunch`
   - `top.darkrio326.AutoLedger.support.sponsor`
7. 首次加入 IAP 时，内购项目通常需要随一个新的 App 版本一起提交审核。
8. App 内不要引导用户使用外部支付方式，不要在文案中提供外部付款链接。

## 4. Review Notes 建议

```text
AutoLedger includes optional consumable in-app purchases that allow users to support the independent developer. These purchases do not unlock features or affect app functionality. All core features remain available for free.
```

## 5. 当前边界

- 不实现订阅。
- 不实现 Pro 解锁。
- 不实现 restore entitlement 逻辑，因为这 3 个产品都是 consumable 且不授予功能权益。
- `Transaction.updates` 只用于处理 App 外完成或延迟完成的已验证 consumable transaction。
- 已验证的 support transaction 会调用 `finish()`；无法验证的 transaction 不会记录支持状态。
