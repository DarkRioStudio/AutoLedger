# ReceiptDebugTool Mac App 实施规格

> 文档状态：Reference
> 真源范围：ReceiptDebugTool 实施规格背景；当前能力以 `ReceiptDebugTool/` 代码为准
> 文档分类核验：2026-07-17
> 上位路线图：[ROADMAP.md](../ROADMAP.md)

日期：2026-04-28
目标版本：v1.3.3+
目录：`ReceiptDebugTool/`
状态：可进入工程实施

## 1. 实施目标

新建一个本地 macOS SwiftUI 调试工具，用于把批量图片测试链路可视化：

```text
图片集 → Vision OCR → OCR 文本修订 → LedgerTextInterpreterCore → 字段级期望对比 → Golden 候选导出
```

首版只服务开发和回归测试，不进入主 App，不面向用户发布。

首版必须解决：

- 批量拖入小票/支付截图/非账单图片。
- 批量 OCR，展示原始 OCR 和可编辑 OCR。
- 调用 `LedgerTextInterpreterCore` 平台无关核心生成结构化账单。
- 手动录入或用当前结果填充期望。
- 字段级显示 pass/fail/missing/ignored。
- 标记明显识别错误并高亮。
- 导出脱敏调试日志。
- 导出 Golden Case 候选 JSONL，并可在 App 内/脚本中验证。

首版不做：

- 不调用 LLM API 生成期望。
- 不直接把图片提交进 git。
- 不默认导出原始 OCR 文本。
- 不直接写入正式 `tests/golden/ledger_text_interpreter/cases.jsonl`。
- 不调用 App 层 `LedgerTextInterpreter`、`SmartReceiptParser` 或 `LedgerStore`。

## 2. 现有能力复用

当前工程已有能力：

- `tools/receipt_ocr/batch_ocr.swift`：批量图片 OCR。
- `tools/receipt_ocr/batch_parse.swift`：OCR JSONL → `LedgerTextInterpreterCore` 解析 JSONL。
- `tools/receipt_ocr/golden_regression.swift`：Golden Case 字段级断言。
- `tests/golden/ledger_text_interpreter/cases.jsonl`：现有 Golden Case。
- `AutoLedgerCore`：`LedgerTextInterpreterCore`、`InterpretInput`、`InterpretResult`、`TransactionDraft`、`BillRelevanceGate`。

实施原则：

- OCR 逻辑可以先复制到 ReceiptDebugTool 内部的 `ReceiptOCRService`，后续再抽成 CLI 与 App 共用模块。
- 解析逻辑必须直接依赖 `AutoLedgerCore`，禁止复制解释器规则。
- Golden Case 格式必须与现有 runner 保持兼容。

## 3. 工程接入

首版工程采用独立 macOS App 工程，放在：

```text
ReceiptDebugTool/
  ReceiptDebugTool.xcodeproj
  ReceiptDebugTool/
```

依赖：

- 本地 Swift Package：`../AutoLedger/AutoLedgerCore`
- Framework：`SwiftUI`、`AppKit`、`Vision`、`UniformTypeIdentifiers`

首版构建命令：

```bash
xcodebuild -project ReceiptDebugTool/ReceiptDebugTool.xcodeproj \
  -scheme ReceiptDebugTool \
  -destination 'platform=macOS' build
```

验收时仍需保留主工程验证：

```bash
bash scripts/run_offline_regression.sh
bash scripts/run_golden_regression.sh
xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace \
  -scheme AutoLedger \
  -destination 'generic/platform=iOS' build
```

## 4. 隐私与文件策略

这是首版硬门禁。

### 4.1 默认只写 `.tmp`

所有运行产物默认写入：

```text
.tmp/receipt_debug_tool/
```

默认产物不得进入 git：

```text
.tmp/receipt_debug_tool/
receiptsample/
```

### 4.2 原始图片

- App 可以读取拖入图片。
- 默认不复制原始图片到导出目录。
- 如需复制图片，必须通过显式开关 `Include Raw Images`，导出目录名必须包含 `private_raw`。
- Golden Case 永远不包含图片路径。

### 4.3 OCR 文本

默认展示原文，但默认导出脱敏文本。

必须实现：

```text
rawText → redactedText → preview
```

脱敏至少覆盖：

- 手机号。
- 身份证/长数字串。
- 银行卡尾号/支付卡号。
- 交易单号、商户单号、订单号。
- 地址中的门牌号、楼栋、房间号。
- 邮箱。

默认导出：

```text
redacted_ocr.jsonl
redacted_debug.md
golden_candidates.jsonl   # 使用 redactedText
```

可选原文导出必须显式开启，并写入：

```text
private_raw_ocr.jsonl
private_raw_debug.md
```

### 4.4 Golden 写入策略

首版 `纳入 Golden Case` 的行为是“导出候选”，不直接修改正式 `cases.jsonl`。

默认输出：

```text
.tmp/receipt_debug_tool/golden_candidates.jsonl
```

正式追加到 `tests/golden/ledger_text_interpreter/cases.jsonl` 留给人工 review 或后续命令行完成。

Golden 候选必须满足：

- 使用 `redactedText`，不使用原始 OCR。
- 不包含原始图片路径。
- 包含稳定 `id`。
- 包含 `sourceType`、`sourceHint`。
- 包含已确认期望字段。
- 导出后必须通过 Golden validator。

## 5. UI 实施口径

单窗口四栏，从左到右按工作流排列。

```text
┌─────────────────────────────────────────────────────────────────────┐
│ 清空图片 | 刷新 OCR 文本 | 刷新账单文本 | 纳入 Golden Case           │
├──────────────┬──────────────┬──────────────────┬───────────────────┤
│ 拖入图片      │ OCR 文本      │ 结构化账单文本     │ 测试结果 / 期望      │
│ Image List   │ OCR Editor   │ Parse Result     │ Expectation       │
│ Preview      │ Raw/Redacted │ Draft JSON       │ Pass/Fail Diff    │
├──────────────┴──────────────┴──────────────────┴───────────────────┤
│ 导出调试日志                                                         │
└─────────────────────────────────────────────────────────────────────┘
```

顶部按钮：

- `清空图片`：清空当前会话，不删除已导出文件。
- `刷新 OCR 文本`：对选中样本执行 OCR；无选中时对全部样本执行 OCR。
- `刷新账单文本`：对选中样本调用 `LedgerTextInterpreterCore`；无选中时对全部已 OCR 样本执行解析。
- `纳入 Golden Case`：导出通过隐私校验的候选 JSONL，并运行 validator。

底部按钮：

- `导出调试日志`：导出脱敏批量调试日志。

列表行状态：

```swift
enum ReceiptDebugStatus: String, Codable {
    case imported
    case ocrReady
    case parsed
    case expectedReady
    case compared
    case goldenCandidate
    case validatorFailed
    case nonBill
    case failed
}
```

明显识别错误或 failed 行使用浅红底色；nonBill 使用中性色标识。

## 6. 四栏功能

### 6.1 拖入图片

支持：

- 单张图片。
- 多张图片。
- 文件夹。
- 格式：`jpg`、`jpeg`、`png`、`heic`、`tif`、`tiff`。

每张图片生成：

```text
caseID = sanitizedFileName + "-" + imageContentHashPrefix
```

需要记录：

- 原文件名。
- 文件路径 hash。
- 图片内容 hash。
- 图片尺寸。
- 导入时间。
- OCR/解析/期望状态。

如果启用 macOS sandbox，必须保存 security scoped bookmark：

```swift
var securityScopedBookmarkData: Data?
```

### 6.2 OCR 文本

展示：

- OCR 原文。
- 脱敏预览。
- 人工修订文本。
- OCR 行数。
- OCR min/mean confidence。
- OCR 耗时。
- 图片尺寸。

解析默认使用：

```swift
activeOCRText = ocrTextEdited?.nonEmpty ?? ocrTextOriginal
```

Golden 导出默认使用：

```swift
redactedText(activeOCRText)
```

### 6.3 结构化账单文本

调用：

```swift
LedgerTextInterpreterCore().interpret(
    InterpretInput(
        rawText: activeOCRText,
        sourceType: .ocr,
        hints: LedgerInterpretHints(sourceHint: selectedSourceHint)
    )
)
```

展示：

- amount
- merchant
- category
- occurredAt
- sourceType
- parseMethod
- confidence
- needsReview
- warnings
- debugTrace

同时展示 JSON 视图。

### 6.4 期望与对比

首版支持手动期望和“一键用当前解析结果填充期望”。

字段：

```swift
struct GoldenExpectation: Codable, Equatable {
    var draftExists: Bool?
    var amount: Double?
    var amountTolerance: Double?
    var merchantEquals: String?
    var merchantContains: String?
    var category: String?
    var source: String?
    var confidence: String?
    var needsReview: Bool?
    var warningsContains: [String]?
}
```

字段状态：

```swift
enum FieldCheckStatus: String, Codable {
    case pass
    case fail
    case missing
    case ignored
}
```

默认启用校验字段：

- `draftExists`
- `amount`
- `merchantEquals`
- `category`

可手动启用：

- `confidence`
- `needsReview`
- `warningsContains`
- `source`

非账单快捷期望：

```json
{
  "draftExists": false,
  "confidence": "low",
  "needsReview": true,
  "warningsContains": ["nonBillImage"]
}
```

## 7. 明显识别错误

明显识别错误既支持自动判定，也支持人工标记。

```swift
enum ObviousErrorReason: String, Codable, CaseIterable {
    case amountFromItemPrice
    case merchantFromItemName
    case totalNotFound
    case missingAmount
    case nonBillMisclassified
    case dateMisread
    case categoryWrong
    case other
}
```

自动判定首版只做低风险规则：

- `draftExists == false` 且 OCR 文本含金额/支付/total 信号 → `missingAmount`
- `warnings` 包含 `missingReliableTotal` → `totalNotFound`
- parsed merchant 命中常见商品词，如 `milk`、`bread`、`fresh milk` → `merchantFromItemName`

人工标记必须导出到 diff 和调试日志。

## 8. 数据模型

```swift
struct ReceiptDebugCase: Identifiable, Codable {
    var id: String
    var originalFileName: String
    var imageURL: URL
    var securityScopedBookmarkData: Data?
    var imagePathHash: String
    var imageContentHash: String
    var imageWidth: Int?
    var imageHeight: Int?
    var importedAt: Date

    var ocrTextOriginal: String
    var ocrTextEdited: String?
    var redactedText: String
    var ocrMinConfidence: Float?
    var ocrMeanConfidence: Float?
    var ocrLineCount: Int
    var ocrDurationMs: Int?
    var ocrError: String?

    var sourceType: LedgerInputSourceType
    var sourceHint: LedgerSourceHint
    var parseResult: InterpretResult?
    var parsedAt: Date?

    var expectation: GoldenExpectation?
    var expectationSource: ExpectationSource
    var testStatus: ReceiptDebugStatus
    var fieldDiffs: [FieldDiff]
    var isObviousError: Bool
    var obviousErrorReasons: [ObviousErrorReason]
}
```

```swift
enum ExpectationSource: String, Codable {
    case manual
    case parseSnapshot
    case importedGolden
    case llmDraft
}
```

## 9. 工程结构

```text
ReceiptDebugTool/
  ReceiptDebugTool.xcodeproj
  ReceiptDebugTool/
    ReceiptDebugToolApp.swift
    ContentView.swift
    Models/
      ReceiptDebugCase.swift
      GoldenExpectation.swift
      FieldDiff.swift
      ReceiptDebugStatus.swift
      ObviousErrorReason.swift
    Services/
      ReceiptOCRService.swift
      ReceiptDebugParser.swift
      ReceiptTextRedactor.swift
      GoldenCaseWriter.swift
      GoldenCaseValidator.swift
      DebugLogExporter.swift
      SingleCaseDebugExporter.swift
      LLMExpectationService.swift
    Views/
      ToolbarView.swift
      ImageDropColumn.swift
      OCRTextColumn.swift
      ParsedBillColumn.swift
      ExpectationColumn.swift
      BottomActionBar.swift
```

首版 `LLMExpectationService` 只保留协议和 disabled UI，不实现网络调用。

## 10. Golden Case 导出与验证

Golden 候选 JSONL 格式：

```json
{"id":"receipt_debug_xxx","rawText":"REDACTED_TEXT","sourceType":"ocr","sourceHint":"receipt","expected":{"draftExists":true,"amount":12.8,"merchantEquals":"罗森便利店","category":"groceries"}}
```

导出流程：

1. 用户确认期望。
2. App 生成 `redactedText`。
3. App 展示脱敏 diff。
4. App 写入 `.tmp/receipt_debug_tool/golden_candidates.jsonl`。
5. App 调用同一套 Golden validator。
6. UI 显示 validator pass/fail。

Validator 首版实现方式：

- 优先在 App 内复用 `GoldenCaseValidator` 逻辑。
- 可以先 shell 调用：

```bash
bash scripts/run_golden_regression.sh .tmp/receipt_debug_tool/golden_candidates.jsonl
```

若 shell 调用失败或路径不可用，UI 必须展示错误。

## 11. 调试日志导出

批量导出目录：

```text
receipt-debug-log-YYYYMMDD-HHmm/
  cases.json
  redacted_ocr.jsonl
  parse.jsonl
  diffs.jsonl
  golden_candidates.jsonl
  summary.md
```

显式启用 raw 导出时额外包含：

```text
private_raw_ocr.jsonl
private_raw_debug.md
```

`summary.md` 包含：

- 图片总数。
- OCR 成功/失败数量。
- 解析成功/失败数量。
- pass/fail/missing/ignored 数量。
- nonBill 数量。
- obviousError 数量。
- Top warnings。
- 失败样本列表。

单条样本支持：

- Copy Debug Log。
- Export Debug Log。

单条日志默认使用 redacted OCR 文本。

## 12. 实施阶段

### Phase 0：工程骨架

- 新建 macOS SwiftUI App 工程。
- 接入 `AutoLedgerCore`。
- 搭建四栏 UI 空状态。
- 支持拖入图片和文件夹。

验收：

- `xcodebuild -project ReceiptDebugTool/ReceiptDebugTool.xcodeproj -scheme ReceiptDebugTool -destination 'platform=macOS' build` 通过。
- 拖入图片后列表显示文件名和缩略图。

### Phase 1：OCR 与脱敏

- 实现 `ReceiptOCRService`。
- 实现 `ReceiptTextRedactor`。
- 显示 OCR 原文、编辑文本、脱敏预览。
- 支持批量 OCR。

验收：

- 批量 OCR 可运行。
- 脱敏预览可见。
- 默认导出不包含原始 OCR。

### Phase 2：核心解析

- 实现 `ReceiptDebugParser`。
- 调用 `LedgerTextInterpreterCore`。
- 展示 parse result JSON 和 debugTrace。

验收：

- OCR 文本变更后可重新解析。
- 非账单图片输出 `nonBillImage`。

### Phase 3：期望与 diff

- 实现期望表单。
- 实现字段级 diff。
- 实现明显识别错误自动/人工标记。
- 支持筛选 failed/missing/nonBill/obviousError。

验收：

- 每个样本显示字段级结果。
- 金额支持 tolerance。
- obviousError 行高亮。

### Phase 4：Golden 候选

- 实现 `GoldenCaseWriter`。
- 实现 `GoldenCaseValidator`。
- 导出 `.tmp/receipt_debug_tool/golden_candidates.jsonl`。
- 导出后运行 validator。

验收：

- 候选 JSONL 能通过 `scripts/run_golden_regression.sh`。
- 未通过时 UI 显示具体 case id 和字段差异。
- 候选 JSONL 不含图片路径和未脱敏原文。

### Phase 5：日志导出

- 实现批量调试日志导出。
- 实现单条调试日志复制和导出。

验收：

- 默认日志使用 redacted OCR。
- raw 导出必须显式开启。
- 日志可复现失败样本的 parse input/result/expectation/diff。

### Phase 6：LLM 期望生成

后续版本实现，首版不做。

约束：

- 只生成期望草稿。
- 用户确认前不能写 Golden 候选。
- API Key 只从环境变量或 Keychain 读取。
- 日志不得记录 API Key。

## 13. 首版完成门禁

必须全部满足：

- ReceiptDebugTool macOS build 通过。
- 主 App iOS build 通过。
- `bash scripts/run_offline_regression.sh` 通过。
- `bash scripts/run_golden_regression.sh` 通过。
- 可拖入图片/文件夹。
- 可批量 OCR。
- 可编辑 OCR 文本并重新解析。
- 可生成 `LedgerTextInterpreterCore` 解析结果。
- 可录入期望并字段级 diff。
- 可标记 obviousError。
- 可导出 redacted 调试日志。
- 可导出并验证 Golden 候选 JSONL。
- 默认不导出图片、不导出 raw OCR、不直接写正式 Golden Case。

## 14. 风险与处理

- 隐私文本进入仓库：通过 redaction 强制门禁和候选文件流程控制。
- Golden 固化错误行为：候选导出后必须 validator pass，并由人工 review 再合入正式 cases。
- OCR 依赖 macOS Vision：ReceiptDebugTool 是 Mac 本地工具，不影响平台无关核心。
- 文件访问失效：记录 content hash；sandbox 开启时保存 security scoped bookmark。
- 核心解释器能力尚弱：失败样本进入 obviousError/failed 队列，不自动修改规则。

## 15. 后续演进

- A/B 对比 `ReceiptParser` vs `LedgerTextInterpreterCore`。
- 从 `.tmp/receipt_ocr/*.jsonl` 导入已有 OCR 结果。
- UI 内运行正式 Golden Case 并展示历史趋势。
- obviousError 原因聚类。
- 从单条调试日志生成 GitHub Issue 草稿。
- LLM 生成期望草稿。
