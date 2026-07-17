# AutoLedger 语音识别记账与 Siri 交互落地设计草案

> 文档状态：Reference
> 真源范围：语音记账与 Siri 初始设计；当前行为以 App Intents / Voice 代码和回归为准
> 文档分类核验：2026-07-17
> 上位路线图：[ROADMAP.md](../ROADMAP.md)

版本：v0.2
目标版本：v1.3 / v1.4
设计目标：补充截图记账之外的轻量语音记账能力，实现“一句话 → 一笔支出”。

---

## 1. 功能定位

语音记账不是替代截图记账，而是补充以下场景：

- 没有支付截图
- 现金消费
- 临时小额支出
- 停车费、路边摊、朋友代付等无法直接截图的场景

核心目标：

```text
一句话 → 解析金额和描述 → 生成一笔支出
```

当前版本只处理“支出”，暂不处理收入。

---

## 2. 产品原则

### 2.1 不做语音聊天机器人

本功能不是开放聊天，也不是财务问答。

只做：

```text
语音文本 → 结构化支出记录
```

### 2.2 不计入收入

当前版本仅支持支出记账。

例如：

```text
午饭 28
咖啡 18
停车费 12
打车 36.5
```

暂不支持：

```text
工资 8000
收到报销 200
朋友转我 50
```

这类收入、转账、报销类语句后续再扩展。

### 2.3 规则优先，AI 兜底

语音文本通常较短，应优先使用规则解析。

AI 仅在规则解析不充分时作为可选增强，不应拖慢 Siri 主链路。

---

## 3. 入口设计

## 3.1 Siri 入口

用户可以说：

```text
嘿 Siri，用 AutoLedger 记一笔午饭 28 元
```

或者：

```text
嘿 Siri，运行语音记账
```

Siri 将语音转成文本后传给 App Intent。

### Siri 场景的关键原则

Siri 场景必须快速、明确。

因此：

- 高置信度：直接记账
- 中置信度：直接失败，让用户重试
- 低置信度：直接失败，让用户重试

不要在 Siri 场景里做复杂确认，也不要让用户长时间等待。

---

## 3.2 App 内语音入口

首页可以增加一个入口：

```text
语音记账
```

点击后：

```text
系统听写 / 语音输入
→ 得到文本
→ 解析
→ 展示确认页
→ 用户确认或修改
→ 保存账单
```

### App 内场景的关键原则

App 内场景可以承载确认和编辑。

因此：

- 高置信度：可以自动填好并保存，或展示轻确认
- 中置信度：展示确认页，让用户修改
- 低置信度：展示确认页或提示用户补充金额

---

## 4. 核心链路设计

## 4.1 Siri / App Intent 链路

```text
用户说话
→ Siri 识别成文本
→ VoiceLedgerIntent 接收文本
→ TextLedgerParser 解析
→ 计算置信度
→ 高置信度直接保存
→ 返回“已记好”
```

成功示例：

```text
已记好：午饭 ¥28
```

失败示例：

```text
没有识别到明确金额，请再说一遍。
```

或：

```text
这句话不够明确，请重试，例如：午饭 28 元。
```

---

## 4.2 App 内语音链路

```text
用户点击语音记账
→ 系统听写得到文本
→ TextLedgerParser 解析
→ 生成 TransactionDraft
→ 根据置信度进入不同 UI
```

处理方式：

```text
HIGH:
  自动保存或展示轻确认

MEDIUM:
  展示确认页
  用户可修改金额、商户、分类

LOW:
  展示确认页
  标记需要补全
```

---

## 5. 解析字段

当前版本只生成支出记录。

解析字段：

```text
amount        金额
merchant      描述 / 商户 / 备注
category      分类
date          时间，默认当前时间
sourceType    voice
confidence    置信度
needsReview   是否需要复核
inputText     原始语音识别文本
parseMethod   rule / ai / mixed
```

---

## 6. 语音文本解析策略

## 6.1 MVP 支持语句

优先支持短句：

```text
午饭 28
咖啡 18 元
打车 36.5
买水果 23
停车费 12
奶茶 15
便利店 32
```

## 6.2 暂不支持语句

当前版本暂不支持收入、转账、复杂拆分：

```text
收到工资 8000
报销 200
朋友转我 50
我和朋友吃饭一共 128 他转了我 64
```

这些语句在 Siri 场景应返回失败或提示重试；在 App 内场景可以进入确认页，但默认不自动保存为收入。

---

## 7. 规则解析方案

### 7.1 金额提取

优先提取文本中的金额：

```text
28
28元
28 块
36.5
36.50
¥18
```

规则：

- 必须存在明确数字金额
- 金额必须大于 0
- 当前版本只取一个金额
- 如果出现多个金额，Siri 场景直接失败；App 内场景进入确认

### 7.2 描述提取

去掉金额和单位后的剩余文本作为 merchant / note。

示例：

```text
午饭 28 元
→ merchant = 午饭
→ amount = 28
```

```text
停车费 12
→ merchant = 停车费
→ amount = 12
```

### 7.3 分类规则

通过关键词映射分类：

```text
午饭 / 晚饭 / 早餐 / 面 / 饭 / 餐 → 餐饮
咖啡 / 瑞幸 / 星巴克 → 咖啡
打车 / 滴滴 / 出租车 → 出行
停车 / 停车费 → 出行
水果 / 超市 / 便利店 → 购物 / 餐饮，按现有分类体系决定
奶茶 / 饮料 → 饮品 / 餐饮
```

如果无法判断，使用默认分类：

```text
其他
```

---

## 8. 置信度策略

## 8.1 HIGH

条件：

- 有且只有一个明确金额
- 有有效描述文本
- 没有明显收入/转账关键词
- 分类可以命中或可使用默认分类

行为：

### Siri 场景

```text
直接保存为支出
返回“已记好”
```

### App 内场景

```text
可以直接保存
或展示轻确认结果
```

## 8.2 MEDIUM

条件：

- 金额明确
- 描述较短或模糊
- 分类不确定
- 可能需要用户确认

行为：

### Siri 场景

```text
不保存
返回失败并提示重试
```

推荐文案：

```text
这句话不够明确，请再说一遍，例如：午饭 28 元。
```

### App 内场景

```text
展示确认页
允许用户修改金额、名称、分类
```

## 8.3 LOW

条件：

- 没有金额
- 出现多个金额
- 明显包含收入/转账/报销等当前不支持语义
- 文本过长且无法明确结构化
- 金额与描述解析冲突

行为：

### Siri 场景

```text
不保存
返回失败并提示重试
```

推荐文案：

```text
没有识别到明确支出金额，请再说一遍。
```

### App 内场景

```text
展示确认页或提示补充金额
不自动保存
```

---

## 9. Siri 返回文案

### 9.1 成功

```text
已记好：午饭 ¥28
```

```text
已记好：咖啡 ¥18
```

### 9.2 中低置信度失败

```text
这句话不够明确，请再说一遍，例如：午饭 28 元。
```

### 9.3 没有金额

```text
没有识别到明确支出金额，请再说一遍。
```

### 9.4 多个金额

```text
检测到多个金额，请只说一笔支出。
```

### 9.5 收入/转账暂不支持

```text
当前语音记账仅支持支出，请换一种说法重试。
```

---

## 10. App 内确认页设计

App 内语音识别后进入确认页。

展示字段：

```text
金额：¥28
名称：午饭
分类：餐饮
类型：支出
时间：现在
来源：语音
```

操作按钮：

```text
保存
修改
取消
```

当置信度为 MEDIUM / LOW：

```text
识别结果可能不完整，请确认后保存。
```

如果没有金额：

```text
未识别到金额，请补充金额。
```

---

## 11. App Intent 设计

建议新增：

```text
VoiceLedgerIntent
```

参数：

```text
content: String
```

Intent 行为：

```text
接收语音转文本内容
→ 调用 TextLedgerParser
→ 根据置信度判断
→ 高置信度保存
→ 中低置信度返回失败提示
```

### 11.1 Siri 场景伪代码

```swift
struct VoiceLedgerIntent: AppIntent {
    static var title: LocalizedStringResource = "语音记账"

    @Parameter(title: "记账内容")
    var content: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = TextLedgerParser().parse(content)

        guard result.confidence == .high else {
            return .result(dialog: "这句话不够明确，请再说一遍，例如：午饭 28 元。")
        }

        try await TransactionService.shared.saveExpense(result)
        return .result(dialog: "已记好：\(result.merchant) ¥\(result.amount)")
    }
}
```

---

## 12. 数据模型补充

账单增加或复用以下字段：

```text
sourceType = voice
sourceId = voice_input
inputText
parseMethod
confidence
needsReview
```

示例：

```json
{
  "amount": 28,
  "merchant": "午饭",
  "category": "餐饮",
  "sourceType": "voice",
  "sourceId": "voice_input",
  "inputText": "午饭 28 元",
  "parseMethod": "rule",
  "confidence": 0.95,
  "needsReview": false
}
```

---

## 13. 本地化文案 Key 建议

```text
voice_ledger_title = 语音记账
voice_ledger_example = 例如：午饭 28 元
voice_ledger_success = 已记好：%@ ¥%@
voice_ledger_unclear = 这句话不够明确，请再说一遍，例如：午饭 28 元。
voice_ledger_no_amount = 没有识别到明确支出金额，请再说一遍。
voice_ledger_multiple_amounts = 检测到多个金额，请只说一笔支出。
voice_ledger_income_not_supported = 当前语音记账仅支持支出，请换一种说法重试。
voice_ledger_review_required = 识别结果可能不完整，请确认后保存。
```

英文：

```text
voice_ledger_title = Voice Expense
voice_ledger_example = For example: lunch 28
voice_ledger_success = Saved: %@ ¥%@
voice_ledger_unclear = This phrase is not clear enough. Please try again, for example: lunch 28.
voice_ledger_no_amount = No clear expense amount was recognized. Please try again.
voice_ledger_multiple_amounts = Multiple amounts were detected. Please say only one expense.
voice_ledger_income_not_supported = Voice bookkeeping currently supports expenses only.
voice_ledger_review_required = The result may be incomplete. Please review before saving.
```

---

## 14. MVP 范围

### 本期做

```text
[ ] VoiceLedgerIntent
[ ] content 文本参数
[ ] 规则解析金额 + 描述
[ ] 基础分类规则
[ ] 高置信度 Siri 直接保存
[ ] 中低置信度 Siri 失败提示重试
[ ] App 内中低置信度进入确认页
[ ] sourceType 标记为 voice
[ ] 本地化文案
```

### 本期不做

```text
[ ] 收入记账
[ ] 转账识别
[ ] 多金额拆分
[ ] 多轮对话确认
[ ] 复杂自然语言日期
[ ] 云端语音识别
[ ] 开放式聊天
```

---

## 15. 示例解析结果

### 示例 1

```text
输入：午饭 28
结果：
amount = 28
merchant = 午饭
category = 餐饮
type = expense
confidence = HIGH
```

### 示例 2

```text
输入：打车 36.5
结果：
amount = 36.5
merchant = 打车
category = 出行
type = expense
confidence = HIGH
```

### 示例 3

```text
输入：今天花了 20 和 30
结果：
confidence = LOW
Siri 返回：检测到多个金额，请只说一笔支出。
App 内：进入确认页
```

### 示例 4

```text
输入：收到报销 200
结果：
当前版本不支持收入
Siri 返回：当前语音记账仅支持支出，请换一种说法重试。
```

---

## 16. 优先级建议

当前推荐顺序：

```text
1. 识别稳定优化
2. iCloud 备份恢复
3. 语音记账 MVP
4. 反馈日志自动化
5. AI 兜底增强
```

语音记账适合放在：

```text
v1.3 或 v1.4
```

---

## 17. 总结

语音记账要做成：

```text
一句话 → 一笔支出
```

不要做成：

```text
语音聊天机器人
```

Siri 场景必须高置信度才自动记账；中低置信度直接失败并提示用户重试。
App 内场景可以容纳不确定性，中低置信度进入确认页让用户修改。

当前版本暂不处理收入，只处理支出。
