# Shortcuts JSON 账单导入

> 文档状态：Active
> 真源范围：Shortcuts JSON 账单导入合同和用户确认边界
> 文档分类核验：2026-07-17
> 上位路线图：[ROADMAP.md](ROADMAP.md)

更新日期：2026-06-09
状态：v1.5.1 功能说明

## 1. 目标

`导入 JSON 账单` App Intent 用于接收 Shortcuts 或剪贴板中的结构化账单 JSON，并根据置信度决定：

- 高置信度：自动保存为正式账单
- 中置信度：打开 AutoLedger 确认页，用户复核后保存
- 低置信度或缺少关键字段：返回错误，不入账

该入口面向自动化工具、个人快捷指令和后续外部解析链路，不上传用户数据。

## 2. JSON 字段

推荐字段：

```json
{
  "amount": 18.8,
  "merchant": "Demo Coffee",
  "category": "dining",
  "date": "2026-06-09 09:30",
  "note": "latte",
  "currency": "CNY",
  "confidence": 0.92
}
```

支持的字段别名：

| 含义 | 字段 |
|------|------|
| 金额 | `amount`、`total`、`price`、`金额`、`总额`、`支付金额` |
| 商户 | `merchant`、`merchant_name`、`merchantName`、`store`、`store_name`、`payee`、`商户`、`商家`、`店铺`、`收款方` |
| 分类 | `category`、`category_raw`、`categoryRaw`、`expense_type`、`expenseType`、`分类`、`类型` |
| 日期 | `occurredAt`、`occurred_at`、`date`、`time`、`paid_at`、`paidAt`、`日期`、`时间`、`支付时间` |
| 备注 | `note`、`memo`、`description`、`remark`、`备注`、`说明` |
| 币种 | `currency`、`currency_code`、`currencyCode`、`币种` |
| 置信度 | `confidence`、`置信度`、`score` |

## 3. 置信度规则

| 置信度 | 行为 |
|--------|------|
| `>= 0.85` | 自动保存 |
| `0.50..<0.85` | 打开确认页 |
| `< 0.50` | 报错，不入账 |
| 缺省 | 按 `0.50` 处理，进入确认页 |

`confidence` 支持 `0...1` 小数，也支持 `0...100` 百分制数值。

## 4. 字段处理规则

- `amount` 必须大于 `0`
- `merchant` 不能为空
- `category` 可以是内置 raw value，例如 `dining`、`transport`，也可以是中文 / 英文分类别名
- 未提供 `category` 时，根据商户文本推断分类
- 未提供 `date` 时使用当前时间
- `currency` 当前不会写入独立字段；非 `CNY` 币种会写入备注
- `confidence` 会写入备注，便于追溯自动化来源

## 5. Shortcuts 使用方式

方式一：直接传参

1. 在 Shortcuts 中准备 JSON 文本
2. 调用 AutoLedger 的 `导入 JSON 账单`
3. 将 JSON 文本传给 `账单 JSON`

方式二：剪贴板

1. 将 JSON 文本复制到剪贴板
2. 调用 AutoLedger 的 `导入 JSON 账单`
3. `账单 JSON` 留空

## 6. 确认页

中置信度账单会打开 AutoLedger，并展示一页结构化 JSON 确认页。确认页允许用户复核并调整：

- 商户
- 日期
- 金额
- 分类
- 备注

保存后才会写入正式账本。确认页不会保存原始 JSON、截图、小票图片或 OCR 全文。

## 7. 当前边界

- 当前只支持单笔账单对象，不支持 JSON 数组批量导入
- 不写入原始截图、小票图片或 OCR 全文
- 不修改 SQLite schema
- 不新增币种字段；币种暂存入备注
- 不绕过用户确认保存低置信度账单
