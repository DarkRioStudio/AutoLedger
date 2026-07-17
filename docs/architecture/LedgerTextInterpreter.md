# LedgerTextInterpreter 设计文档（平台无关层版本）

> 文档状态：Reference
> 真源范围：平台无关文本到账单解释器的设计背景；当前合同以 AutoLedgerCore 代码和回归为准
> 文档分类核验：2026-07-17
> 上位路线图：[ROADMAP.md](../ROADMAP.md)

## 1. 设计背景

AutoLedger 支持多种记账入口：

语音 / Siri / 图片 OCR / 剪切板 / 分享 / 手动一句话

这些入口最终都可以抽象为：

一段文本（raw text）+ 来源上下文（context）

为避免各入口重复实现解析逻辑，引入统一解析核心：

**LedgerTextInterpreter（平台无关核心）**

---

## 2. 设计目标

将任意文本转换为结构化账单草稿：

```text
Text → TransactionDraft
```

目标：

- 平台无关（iOS / Worker / Node / Android）
- 入口无关（OCR / 语音 / 手动统一处理）
- 可测试（支持批量 case 回归）
- 可扩展（规则 + AI 可插拔）

---

## 3. 分层架构（核心）

```text
Input Layer（入口）
  - OCR
  - Siri / 语音
  - 剪贴板
  - 手动文本
        │
        ▼
Text Adapter（适配层）
  - 统一生成 rawText + context
        │
        ▼
LedgerTextInterpreter（平台无关核心）
        │
        ▼
TransactionDraft（结构化结果）
        │
        ▼
LedgerStore（平台相关）
  - 入库 / Widget / 备份
```

---

## 4. 模块职责划分

### 4.1 LedgerTextInterpreter（核心层）

只负责：

```text
文本 → 结构化账单
```

明确不负责：

```text
❌ 数据存储
❌ UI
❌ Widget
❌ iCloud
❌ 商户学习
```

---

## 5. 平台无关接口定义（核心协议）

```ts
// 跨平台统一接口（逻辑定义）
interface LedgerTextInterpreter {
  interpret(input: InterpretInput): InterpretResult
}
```

### 5.1 输入结构

```ts
interface InterpretInput {
  rawText: string
  sourceType: 'ocr' | 'voice' | 'clipboard' | 'manual'
  locale?: string
  timezone?: string
  hints?: {
    sourceHint?: 'receipt' | 'payment' | 'sentence'
  }
}
```

---

### 5.2 输出结构

```ts
interface InterpretResult {
  draft?: TransactionDraft
  confidence: 'high' | 'medium' | 'low'
  needsReview: boolean
  warnings: string[]
  debugTrace: string[]
}
```

---

### 5.3 TransactionDraft

```ts
interface TransactionDraft {
  amount: number
  merchant: string
  category: string
  date: string
  sourceType: string

  inputText: string
  parseMethod: 'rule' | 'ai' | 'mixed'
}
```

---

## 6. 解析流程（核心逻辑）

```text
1. 文本清洗（OCR去噪 / 标准化）
2. 场景识别（receipt / payment / sentence）
3. 多金额检测
4. Parser 编排（Receipt / Sentence / Voice）
5. 字段提取（amount / merchant / category）
6. 置信度计算
7. 输出结果
```

---

## 7. 置信度策略（统一规则）

```text
HIGH：明确金额 + 明确描述 → 自动记账
MEDIUM：金额明确 + 信息不完整 → 需确认
LOW：无金额 / 多金额 / 冲突 → 失败或补充
```

---

## 8. 平台适配层（关键设计）

LedgerTextInterpreter 不直接依赖任何平台。

通过 Adapter 调用：

---

### 8.1 iOS Adapter

```text
iOS App
→ Swift Adapter
→ LedgerTextInterpreter
→ TransactionDraft
→ LedgerStore
```

---

### 8.2 Worker API Adapter

```text
HTTP Request
→ API Layer
→ LedgerTextInterpreter
→ JSON Response
```

接口示例：

```http
POST /api/parse
```

---

### 8.3 Node 测试 Adapter

```text
Test Runner
→ LedgerTextInterpreter
→ 对比 golden case
→ 输出报告
```

---

### 8.4 Android Adapter（未来）

```text
Kotlin Wrapper
→ LedgerTextInterpreter
```

---

## 9. 多种调用方式（统一入口）

```text
OCR → Text → Interpreter
Voice → Text → Interpreter
Clipboard → Text → Interpreter
Manual → Text → Interpreter
Worker API → Interpreter
Test Runner → Interpreter
```

统一调用：

```text
interpret(rawText, context)
```

---

## 10. LedgerStore（平台层）

```text
负责：
- 商户别名
- 分类学习
- 去重
- SQLite 入库
- Debug 记录
- Widget 更新
- iCloud 备份
```

---

## 11. 代码结构建议

```text
core/
  LedgerTextInterpreter
  parsers/
  rules/

adapters/
  ios/
  worker/
  node/

apps/
  AutoLedger iOS
  OCR Tool

parser-tests/
  golden-cases.json
  runner
```

---

## 12. 测试体系（核心能力）

```text
Golden Cases：
- 输入文本
- 期望结果
- 自动回归
```

支持：

```text
批量测试
正确率统计
回归验证
```

---

## 13. 小票图片集批量 OCR 与批量测试

为持续提升 LedgerTextInterpreter 的稳定性，需要引入公开小票图片集作为测试数据来源。

目标不是保存和识别图片本身，而是建立：

```text
图片样本
→ OCR 文本
→ LedgerTextInterpreter
→ TransactionDraft
→ 与 expected 对比
→ 输出测试报告
```

---

### 13.1 数据来源

可使用公开小票数据集，例如：

```text
Voxel51/scanned_receipts
SROIE
CORD
其他公开 receipt / OCR dataset
```

使用原则：

```text
- 原图仅本地用于 OCR，不提交到公开仓库
- 测试集长期保存 OCR 后的脱敏文本
- expected 结果只保存 amount / merchant / date / sourceType 等结构化字段
- 不保存手机号、地址、订单号、卡号等敏感信息
```

---

### 13.2 批量处理链路

推荐链路：

```text
公开小票图片集
        │
        ▼
macOS OCR Tool（Apple Vision OCR）
        │
        ▼
ocr-output/*.txt / *.json
        │
        ▼
Node Batch Test Runner
        │
        ▼
LedgerTextInterpreter
        │
        ▼
测试报告 report.md / failed-cases.json
```

---

### 13.3 macOS OCR Tool

Mac 端不需要做完整 App，只需要一个 Swift CLI 工具：

```text
ReceiptOCRTool
```

职责：

```text
- 遍历图片目录
- 调用 Apple Vision OCR
- 输出每张图片的 rawText
- 输出可选的 OCR blocks / confidence / boundingBox
```

命令示例：

```bash
ReceiptOCRTool ./datasets/scanned_receipts ./parser-tests/ocr-output/receipts-en
```

输出结构：

```text
parser-tests/ocr-output/receipts-en/
  receipt_001.txt
  receipt_001.json
  receipt_002.txt
  receipt_002.json
```

`txt` 用于直接进入解析器。
`json` 用于保留 OCR block、confidence、boundingBox，便于后续排查。

---

### 13.4 OCR 输出 JSON 建议结构

```json
{
  "id": "receipt_001",
  "sourceImage": "receipt_001.jpg",
  "ocrEngine": "apple_vision",
  "recognizedAt": "2026-04-27T10:00:00Z",
  "localeHint": "en-US",
  "rawText": "...",
  "blocks": [
    {
      "text": "TOTAL 12.30",
      "confidence": 0.94,
      "boundingBox": {
        "x": 0.12,
        "y": 0.72,
        "width": 0.44,
        "height": 0.04
      }
    }
  ]
}
```

---

### 13.5 Golden Case 结构

OCR 输出后，需要人工或半自动生成 Golden Case。

示例：

```json
{
  "id": "receipt_en_001",
  "source": "Voxel51/scanned_receipts",
  "inputTextFile": "ocr-output/receipts-en/receipt_001.txt",
  "inputText": "...",
  "context": {
    "sourceType": "ocr",
    "locale": "en-US",
    "timezone": "Asia/Singapore",
    "hints": {
      "sourceHint": "receipt"
    }
  },
  "expected": {
    "amount": 12.30,
    "merchant": "NTUC FAIRPRICE",
    "category": "购物",
    "sourceType": "receipt"
  },
  "acceptance": {
    "amountRequired": true,
    "merchantRequired": true,
    "categoryRequired": false
  }
}
```

---

### 13.6 Node Batch Test Runner

Node 测试工具职责：

```text
- 读取 golden-cases.json
- 加载 inputText 或 inputTextFile
- 调用 LedgerTextInterpreter
- 对比 expected
- 统计通过率
- 输出失败详情
```

命令示例：

```bash
node tools/parser-tests/run-parser-tests.js parser-tests/golden-cases.json
```

输出示例：

```text
Total: 720
Passed: 613
Failed: 107
Amount Accuracy: 91.8%
Merchant Accuracy: 78.4%
Category Accuracy: 66.2%
```

同时输出：

```text
parser-tests/reports/latest-report.md
parser-tests/reports/failed-cases.json
```

---

### 13.7 测试报告内容

`latest-report.md` 建议包含：

```text
- 总 case 数
- 总通过数
- amount 正确率
- merchant 正确率
- category 正确率
- receipt 场景正确率
- payment 场景正确率
- 失败 case 列表
- 高频失败原因
```

`failed-cases.json` 用于后续规则修复：

```json
[
  {
    "id": "receipt_en_001",
    "reason": "amount_mismatch",
    "expected": {
      "amount": 12.30,
      "merchant": "NTUC FAIRPRICE"
    },
    "actual": {
      "amount": 2.00,
      "merchant": "FRESH MILK"
    },
    "trace": [
      "receipt_detected",
      "item_price_selected",
      "total_not_found"
    ]
  }
]
```

---

### 13.8 推荐目录结构

```text
parser-tests/
  golden-cases.json
  ocr-output/
    receipts-en/
      receipt_001.txt
      receipt_001.json
  reports/
    latest-report.md
    failed-cases.json

tools/
  ocr/
    ReceiptOCRTool/
  parser-tests/
    run-parser-tests.js
```

---

### 13.9 回归测试策略

每次修改 LedgerTextInterpreter 规则后，都应执行：

```bash
node tools/parser-tests/run-parser-tests.js parser-tests/golden-cases.json
```

目标：

```text
- 修复新场景时，不破坏已有微信 / 支付宝 / 小票 / 语音场景
- 每次规则变更都有可量化正确率
- 高频失败 case 能反向推动规则迭代
```

---

### 13.10 数据治理注意事项

```text
- 不提交原始支付截图和个人小票图片到公开仓库
- OCR 文本入库前应进行脱敏
- Golden Case 中只保留必要字段
- 对公开数据集保留来源说明和许可信息
- 用户真实反馈样本必须经过用户授权与脱敏
```

---

## 14. Worker API（可选增强）

用于：

```text
批量测试
规则调优
线上实验
```

注意：

```text
App 主链路仍优先本地解析
```

---

## 15. 演进方向

```text
- AI 兜底解析
- 多语言支持
- 商户识别增强
- 分类学习优化
- 多账单拆分（未来）
```

---

## 16. 总结

LedgerTextInterpreter = AutoLedger 核心引擎

```text
统一输入
→ 平台无关解析
→ 输出结构化账单
```

关键价值：

```text
逻辑统一
跨平台复用
可测试可回归
可扩展 AI
```
