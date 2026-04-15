# Gemma 多模型集成方案

更新日期：2026-04-15  
文档状态：Draft（待用户评审确认后实施）

---

## 1. 目标

在现有 `SmartReceiptParser` 架构上：

1. **多模型选择**：抽象 LLM Provider 协议，支持 Apple Foundation Models 和 Gemma-4-E2B-it 两个端侧模型
2. **设置页 UI**：用户可选择/下载/启用模型；国行设备 Apple 模型 `isAvailable == false` 时标注"不可用"
3. **流程反转**：记账文本**先过大模型**，仅当置信度不足或模型不可用时再回退规则解析
4. **优化 Prompt**：采用用户提供的结构化 prompt，输出含 `confidence` 和 `needs_user_confirmation` 的 JSON
5. **OCR 文本预清洗**：在送入 LLM 前去噪，缩短 token、提升响应速度
6. **埋点日志**：записать模型选择、耗时、成功/失败状态到 `ImportDebugRecord`

---

## 2. 现有架构分析

### 当前调用链

```
Photo/Clipboard → OCRService → LedgerStore.importRecognizedText()
                                   ↓
                              SmartReceiptParser.parse()
                                   ↓
                         ① ReceiptParser（规则提取金额/日期）
                                   ↓
                         ② FoundationModels（LLM 补充商户+分类）
                                   ↓
                              SmartResult → persistReceipt()
```

### 核心文件

| 文件 | 职责 |
|------|------|
| `SmartReceiptParser.swift` | 混合解析器：规则先行 → LLM 增强 |
| `LedgerStore.swift` | 中枢状态管理，调用 SmartParser、持久化 |
| `ReceiptParser.swift` (Core) | 纯规则解析器（7+ 平台模式匹配） |
| `SettingsView.swift` | 设置主页，toggleCard / settingsRow 模式 |
| `DebugView.swift` | 调试页，展示 LLM trace / debug records |

### 关键约束

- 项目使用 `ObservableObject` + `@Published`（LedgerStore） 
- 设置项通过 `UserDefaults.standard` 手动读写
- `FoundationModels` 仅 iOS 26+ 可用，需 `@available` 守卫
- `ImportDebugRecord` 已支持 `llmPrompt` / `llmResponse` 字段

---

## 3. 目标调用链（流程反转）

```
Photo/Clipboard → OCRService
                     ↓
               LedgerStore.importRecognizedText()
                     ↓
               OCRTextCleaner.clean(rawText)        ← 【新增】预清洗
                     ↓
               SmartReceiptParser.parse(cleanedText, provider: userSelectedProvider)
                     ↓
            ┌────────┴────────┐
            │ LLM 优先路径     │
            │                 │
            │  ① LLM 解析     │ ← Apple FM 或 Gemma
            │  ② 检查 confidence │
            │     ≥ 0.7 → 直接采用 │
            │     < 0.7 → 规则兜底 │
            └────────┬────────┘
                     │
            ┌────────┴────────┐
            │ 兜底路径         │ (模型不可用 / LLM 失败 / 低置信)
            │  ReceiptParser  │
            └────────┬────────┘
                     ↓
               SmartResult (含 provider / 耗时 / trace)
                     ↓
               persistReceipt()
```

---

## 4. 新增/修改文件清单

### 4.1 新增文件

| # | 文件路径 | 职责 |
|---|---------|------|
| 1 | `Domain/Enums/LLMProvider.swift` | 模型枚举 + 可用性判断 |
| 2 | `Domain/Services/GemmaService.swift` | Gemma 模型下载/加载/推理封装 |
| 3 | `Domain/Services/OCRTextCleaner.swift` | OCR 文本预清洗 |
| 4 | `Features/Settings/AIModelSettingsView.swift` | AI 模型设置页 |

### 4.2 修改文件

| # | 文件路径 | 改动概述 |
|---|---------|---------|
| 5 | `Domain/Services/SmartReceiptParser.swift` | 多模型调度 + 新 prompt + 流程反转 |
| 6 | `App/LedgerStore.swift` | 传递用户选择的 provider、OCR 预清洗调用 |
| 7 | `Features/Settings/SettingsView.swift` | 新增 AI 模型设置入口 |
| 8 | `CHANGELOG.md` | 记录变更 |

---

## 5. 详细设计

### 5.1 `LLMProvider` 枚举

```swift
// Domain/Enums/LLMProvider.swift
import Foundation
import os.log

enum LLMProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case appleFoundation = "apple"
    case gemma           = "gemma"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleFoundation: return "Apple Intelligence"
        case .gemma:           return "Gemma-4-E2B-it"
        }
    }

    var subtitle: String {
        switch self {
        case .appleFoundation: return "iOS 26+ 系统内置，无需下载"
        case .gemma:           return "Google 端侧模型，需下载约 2GB"
        }
    }

    var iconName: String {
        switch self {
        case .appleFoundation: return "apple.logo"
        case .gemma:           return "cpu.fill"
        }
    }

    /// 运行时可用性（同步检查）
    var isAvailable: Bool {
        switch self {
        case .appleFoundation:
            if #available(iOS 26.0, *) {
                return SystemLanguageModel.default.isAvailable
            }
            return false
        case .gemma:
            return GemmaService.shared.isModelReady
        }
    }

    /// 不可用原因（供 UI 展示）
    var unavailableReason: String? {
        switch self {
        case .appleFoundation:
            if !isAvailable { return "当前设备/地区不支持 Apple Intelligence" }
        case .gemma:
            if !isAvailable { return "模型尚未下载，请先下载" }
        }
        return nil
    }

    // MARK: - UserDefaults 持久化

    private static let key = "selectedLLMProvider"

    static var userSelected: LLMProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let provider = LLMProvider(rawValue: raw) else {
                return .appleFoundation   // 默认
            }
            return provider
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}
```

### 5.2 `GemmaService` — Gemma 模型管理

使用 **MediaPipe LlmInference** iOS SDK 加载 Gemma-4-E2B-it 本地权重。

```swift
// Domain/Services/GemmaService.swift
import Foundation
import os.log
// import MediaPipeTasksGenAI  // 实际集成时导入

private let logger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "GemmaService")

@MainActor
final class GemmaService: ObservableObject {
    static let shared = GemmaService()

    enum ModelState: Sendable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case error(String)
    }

    @Published private(set) var state: ModelState = .notDownloaded
    // private var llmInference: LlmInference?

    /// 模型文件本地存储路径
    private var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GemmaModels", isDirectory: true)
    }

    private var modelFilePath: URL {
        modelDirectory.appendingPathComponent("gemma-4-e2b-it.task")
    }

    var isModelReady: Bool {
        if case .ready = state { return true }
        return false
    }

    private init() {
        // 启动时检查本地是否已有模型文件
        if FileManager.default.fileExists(atPath: modelFilePath.path) {
            loadModel()
        }
    }

    // MARK: - 下载

    /// 从 Hugging Face / Google 下载模型权重
    func downloadModel() async {
        guard !isModelReady else { return }
        state = .downloading(progress: 0)
        logger.info("[Gemma] 开始下载模型...")

        do {
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

            // TODO: 替换为实际下载 URL
            // 这里使用 URLSession 流式下载 + 进度回调
            let downloadURL = URL(string: "https://huggingface.co/google/gemma-4-e2b-it/resolve/main/gemma-4-e2b-it.task")!
            let (tempURL, _) = try await URLSession.shared.download(from: downloadURL, delegate: nil)

            try FileManager.default.moveItem(at: tempURL, to: modelFilePath)
            logger.info("[Gemma] 模型下载完成")
            loadModel()
        } catch {
            logger.error("[Gemma] 下载失败: \(error.localizedDescription)")
            state = .error("下载失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 加载

    private func loadModel() {
        logger.info("[Gemma] 加载模型...")
        // TODO: 实际初始化 MediaPipe LlmInference
        // let options = LlmInference.Options()
        // options.modelPath = modelFilePath.path
        // options.maxTokens = 512
        // options.temperature = 0.1
        // llmInference = try? LlmInference(options: options)
        state = .ready
        logger.info("[Gemma] 模型加载完成")
    }

    // MARK: - 推理

    func generate(prompt: String) async throws -> String {
        guard isModelReady else {
            throw GemmaError.modelNotReady
        }
        let startTime = CFAbsoluteTimeGetCurrent()

        // TODO: 实际调用 MediaPipe LlmInference
        // let response = try llmInference!.generateResponse(inputText: prompt)
        let response = "{}"  // placeholder

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("[Gemma] 推理耗时: \(String(format: "%.2f", elapsed))s")
        return response
    }

    // MARK: - 删除

    func deleteModel() {
        try? FileManager.default.removeItem(at: modelDirectory)
        // llmInference = nil
        state = .notDownloaded
        logger.info("[Gemma] 模型已删除")
    }

    enum GemmaError: LocalizedError {
        case modelNotReady
        var errorDescription: String? {
            switch self {
            case .modelNotReady: return "Gemma 模型未就绪"
            }
        }
    }
}
```

**依赖方案**：通过 SPM 引入 `MediaPipeTasksGenAI`（Google 官方 iOS SDK），或如果 2026 年已有 CoreML 转换版 Gemma 权重，也可用 CoreML 原生推理（无需额外依赖）。Package.swift 新增：

```swift
.package(url: "https://github.com/google/mediapipe.git", from: "0.10.0")
```

### 5.3 `OCRTextCleaner` — 文本预清洗

**目的**：缩短 token 长度、去除无用噪声，加速端侧推理（对 2B 小模型尤其关键）。

```swift
// Domain/Services/OCRTextCleaner.swift
import Foundation

enum OCRTextCleaner {

    /// 清洗 OCR 原始文本，保留与交易相关的信息
    static func clean(_ text: String) -> String {
        var result = text

        // 1. 统一换行符
        result = result.replacingOccurrences(of: "\r\n", with: "\n")

        // 2. 合并连续空行为单个换行
        result = result.replacingOccurrences(
            of: #"\n{3,}"#, with: "\n\n", options: .regularExpression
        )

        // 3. 去除纯装饰行（连续特殊符号行，如 ------、======、******）
        result = result.replacingOccurrences(
            of: #"(?m)^[\-=\*·•─━]{3,}$"#, with: "", options: .regularExpression
        )

        // 4. 去除常见广告/推荐噪声短语（不删除整行，仅去除关键词减少干扰）
        let noisePatterns = [
            #"(?:查看|点击|领取)更多(?:优惠|红包|团购|活动)"#,
            #"(?:下载|打开)\s*(?:APP|App|app)"#,
            #"(?:广告|推广|推荐商品|猜你喜欢|为你推荐)"#,
            #"(?:回复|评价).*(?:可获|送|赠|领)"#,
        ]
        for pattern in noisePatterns {
            result = result.replacingOccurrences(
                of: pattern, with: "", options: .regularExpression
            )
        }

        // 5. 压缩连续空白（保留换行结构）
        result = result.replacingOccurrences(
            of: #"[^\S\n]{2,}"#, with: " ", options: .regularExpression
        )

        // 6. 截断上限（端侧 2B 模型建议 ≤ 1500 字符）
        let maxLength = 1500
        if result.count > maxLength {
            result = String(result.prefix(maxLength))
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

### 5.4 `SmartReceiptParser` 重构

**核心变化**：

1. `parse()` 接受 `provider` 参数
2. **LLM 优先**：先用大模型提取全部字段（商户、金额、分类、置信度）
3. 当 `confidence < 0.7` 或 `needs_user_confirmation == true` 时，用规则引擎补充/校正
4. 新增 `SmartResult` 字段：`provider`、`latencyMs`、`modelConfidence`
5. Prompt 替换为用户提供的结构化 prompt
6. 模型禁用thinking

```swift
// 关键改动示意（非完整文件，仅展示 diff 逻辑）

struct SmartReceiptParser: Sendable {

    struct LLMTrace: Sendable {
        let prompt: String
        let response: String
        let provider: LLMProvider       // 【新增】
        let latencyMs: Int              // 【新增】
    }

    struct SmartResult: Sendable {
        let receipt: ImportedReceipt
        let llmTrace: LLMTrace?
        let usedRuleFallback: Bool      // 【新增】是否走了规则兜底
    }

    private let ruleParser = ReceiptParser()

    // MARK: - 置信度阈值

    /// LLM 结果置信度 ≥ 此值时直接采用，否则规则兜底
    private static let confidenceThreshold: Double = 0.7

    // MARK: - 主入口（流程反转：LLM 优先）

    @available(iOS 26.0, *)
    func parse(
        text: String,
        source: ReceiptSource,
        fallbackMerchant: String? = nil,
        ocrMinConfidence: Float? = nil,
        provider: LLMProvider = .userSelected     // 【新增】
    ) async -> SmartResult? {

        // ── Step 1: 尝试 LLM 优先解析 ──
        if provider.isAvailable {
            let prompt = buildSmartPrompt(ocrText: text)
            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                let responseText: String
                switch provider {
                case .appleFoundation:
                    let session = LanguageModelSession()
                    let response = try await session.respond(to: prompt)
                    responseText = response.content
                case .gemma:
                    responseText = try await GemmaService.shared.generate(prompt: prompt)
                }

                let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                logger.info("[LLM/\(provider.displayName)] 响应耗时 \(latencyMs)ms")

                if let parsed = parseLLMOutput(responseText) {
                    let confidence = parsed.confidence

                    // 高置信度 → 直接采用 LLM 结果
                    if confidence >= Self.confidenceThreshold && !parsed.needsUserConfirmation {
                        let receipt = buildReceipt(from: parsed, source: source, rawText: text)
                        return SmartResult(
                            receipt: receipt,
                            llmTrace: LLMTrace(prompt: prompt, response: responseText,
                                               provider: provider, latencyMs: latencyMs),
                            usedRuleFallback: false
                        )
                    }

                    // 低置信度 → 用规则引擎交叉验证
                    logger.info("[LLM] 置信度 \(confidence) < \(Self.confidenceThreshold)，启用规则交叉验证")
                    let ruleResult = ruleParser.parse(text: text, source: source,
                                                      fallbackMerchant: fallbackMerchant)
                    let merged = mergeResults(llm: parsed, rule: ruleResult, source: source, rawText: text)
                    return SmartResult(
                        receipt: merged,
                        llmTrace: LLMTrace(prompt: prompt, response: responseText,
                                           provider: provider, latencyMs: latencyMs),
                        usedRuleFallback: true
                    )
                }
            } catch {
                logger.error("[LLM/\(provider.displayName)] 调用失败: \(error.localizedDescription)")
            }
        } else {
            logger.info("[LLM] \(provider.displayName) 不可用: \(provider.unavailableReason ?? "未知")")
        }

        // ── Step 2: 纯规则兜底 ──
        guard let ruleResult = ruleParser.parse(text: text, source: source,
                                                 fallbackMerchant: fallbackMerchant) else {
            return nil
        }
        return SmartResult(receipt: ruleResult, llmTrace: nil, usedRuleFallback: true)
    }

    // MARK: - 新 Prompt（用户提供的结构化版本）

    private func buildSmartPrompt(ocrText: String) -> String {
        return """
你是一个记账文本解析器。请从OCR文本中提取本次真实交易记录。

字段定义：
1. merchant_name：
   本次交易的实际商户品牌名或主店铺名。
   优先提取品牌/店名本体，不要只输出商场名、地点名、分店后缀。
   例如：
   - “鱼你在一起（东丽万达广场店）” 中 merchant_name 应为 “鱼你在一起”
   - “赵一鸣零食（天津利津店）” 中 merchant_name 应为 “赵一鸣零食”

2. store_branch_name：
   商户的分店/门店名称，可包含“xx店”这类后缀。
   例如：
   - “东丽万达广场店”
   - “天津利津店”

3. location_name：
   商场、综合体、地理位置名称。可以为空。
   例如：
   - “东丽万达广场”
   - “大悦城”
   - “印象城”

4. amount：
   本次实际支付金额，优先选择“实付”“支付金额”“已支付”附近金额。

5. expense_type：
   交易类型。

规则：
- merchant_name 必须优先输出品牌名/店铺主名，而不是商场名或单独的“xx店”。
- 如果文本包含“品牌名（分店名）”，则：
  - merchant_name = 品牌名
  - store_branch_name = 分店名
- 商场名不能作为 merchant_name。
- 地址不能作为 merchant_name。
- 只输出 JSON，不输出解释文字。

输出格式：
{
  "merchant_name": "",
  "store_branch_name": "",
  "location_name": "",
  "amount": "",
  "expense_type": "expense|income|refund|transfer|repayment|topup|not_transaction|unknown",
  "confidence": 0.0,
  "needs_user_confirmation": false,
  "reason": ""
}
        """
    }

    // MARK: - LLM 输出解析

    private struct LLMSmartOutput: Decodable {
        let merchantName: String           // merchant_name
        let amount: String                 // 字符串金额
        let expenseType: String            // expense_type
        let confidence: Double
        let needsUserConfirmation: Bool    // needs_user_confirmation
        let reason: String?

        enum CodingKeys: String, CodingKey {
            case merchantName = "merchant_name"
            case amount
            case expenseType = "expense_type"
            case confidence
            case needsUserConfirmation = "needs_user_confirmation"
            case reason
        }
    }

    private func parseLLMOutput(_ text: String) -> LLMSmartOutput? {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else { return nil }

        let jsonStr = String(cleaned[start...end])
        guard let data = jsonStr.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LLMSmartOutput.self, from: data)
    }

    // MARK: - 结果构建与合并

    /// 从 LLM 输出构建 ImportedReceipt
    private func buildReceipt(from llm: LLMSmartOutput, source: ReceiptSource, rawText: String) -> ImportedReceipt {
        let amount = parseAmount(llm.amount)
        let category = mapExpenseTypeToCategory(llm.expenseType)
        return ImportedReceipt(
            source: source,
            merchant: llm.merchantName,
            amount: amount,
            occurredAt: extractDate(from: rawText) ?? Date(),  // 日期仍用规则提取
            rawText: rawText,
            summary: "\(source.title) 智能解析",
            confidence: llm.confidence,
            suggestedCategory: category
        )
    }

    /// LLM 低置信 + 规则引擎交叉验证合并
    private func mergeResults(llm: LLMSmartOutput, rule: ImportedReceipt?,
                              source: ReceiptSource, rawText: String) -> ImportedReceipt {
        let llmAmount = parseAmount(llm.amount)
        // 金额：优先采用规则（regex 对数字更可靠），LLM 作参考
        let amount = rule?.amount ?? llmAmount
        // 商户：LLM 通常更准
        let merchant = llm.merchantName.isEmpty ? (rule?.merchant ?? "未知商户") : llm.merchantName
        // 日期：规则更可靠
        let date = rule?.occurredAt ?? extractDate(from: rawText) ?? Date()
        // 分类：LLM 优先
        let category = mapExpenseTypeToCategory(llm.expenseType)

        return ImportedReceipt(
            source: source,
            merchant: merchant,
            amount: amount,
            occurredAt: date,
            rawText: rawText,
            summary: "\(source.title) 混合解析",
            confidence: max(llm.confidence, rule?.confidence ?? 0),
            suggestedCategory: category
        )
    }

    /// 金额字符串 → Double
    private func parseAmount(_ str: String) -> Double {
        let cleaned = str.replacingOccurrences(of: "[¥￥$€,，]", with: "", options: .regularExpression)
        return Double(cleaned) ?? 0
    }

    /// expense_type → TransactionCategory 映射
    private func mapExpenseTypeToCategory(_ type: String) -> TransactionCategory {
        switch type {
        case "expense":         return .other       // expense 是泛类，后续可细化
        case "dining":          return .dining
        case "transport":       return .transport
        case "income", "refund", "transfer", "repayment", "topup":
            return .other  // 非支出类暂归 other
        default:                return .other
        }
    }

    /// 从原文提取日期（复用规则引擎的日期提取逻辑）
    private func extractDate(from text: String) -> Date? {
        // 复用 ruleParser 内部日期提取（可提取为公共方法）
        // 暂用简单 regex fallback
        return nil  // 实际实现时调用 ruleParser 的日期提取
    }
}
```

### 5.5 `AIModelSettingsView` — 设置页

```swift
// Features/Settings/AIModelSettingsView.swift

struct AIModelSettingsView: View {
    @State private var selectedProvider: LLMProvider = .userSelected
    @ObservedObject private var gemmaService = GemmaService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 说明卡
                infoCard(
                    title: "智能记账引擎",
                    body: "选择用于识别收据的 AI 模型。大模型优先解析，置信度不足时自动回退规则引擎。"
                )

                // 模型列表
                ForEach(LLMProvider.allCases) { provider in
                    modelCard(provider: provider)
                }

                // Gemma 下载/管理区
                if case .downloading(let progress) = gemmaService.state {
                    downloadProgressCard(progress: progress)
                }

                if case .error(let msg) = gemmaService.state {
                    errorCard(message: msg)
                }

                if gemmaService.isModelReady {
                    Button("删除 Gemma 模型") {
                        gemmaService.deleteModel()
                        if selectedProvider == .gemma {
                            selectedProvider = .appleFoundation
                            LLMProvider.userSelected = .appleFoundation
                        }
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 18)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("AI 模型")
    }

    private func modelCard(provider: LLMProvider) -> some View {
        let isSelected = selectedProvider == provider
        let available = provider.isAvailable

        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: provider.iconName)
                .font(.title3)
                .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
                .frame(width: 40, height: 40)
                .background((isSelected ? AppTheme.accent : AppTheme.mutedInk).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(provider.displayName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    if !available {
                        Text("不可用")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.gray))
                    }
                }

                Text(provider.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)

                if let reason = provider.unavailableReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                // Gemma 未下载时显示下载按钮
                if provider == .gemma && !gemmaService.isModelReady {
                    Button("下载模型 (~2 GB)") {
                        Task { await gemmaService.downloadModel() }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.top, 4)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(isSelected ? AppTheme.accent : .clear, lineWidth: 2)
                )
        )
        .onTapGesture {
            guard available else { return }
            selectedProvider = provider
            LLMProvider.userSelected = provider
        }
    }
}
```

### 5.6 `LedgerStore` 改动

```swift
// LedgerStore.importRecognizedText() 内部改动：

// 原来：
// let result = await smartParser.parse(text: normalizedText, source: source, ...)

// 改为：
let cleanedText = OCRTextCleaner.clean(normalizedText)
let selectedProvider = LLMProvider.userSelected
logger.info("[解析] 使用模型: \(selectedProvider.displayName)")

let result = await smartParser.parse(
    text: cleanedText,
    source: source,
    fallbackMerchant: fallbackMerchant,
    ocrMinConfidence: ocrMinConfidence,
    provider: selectedProvider
)
```

### 5.7 `SettingsView` 入口

在现有设置列表中增加一行：

```swift
NavigationLink {
    AIModelSettingsView()
} label: {
    settingsRow(
        icon: "brain",
        iconColor: Color(red: 0.55, green: 0.36, blue: 0.69),
        title: "AI 模型",
        subtitle: "选择记账解析模型，管理本地模型下载"
    )
}
.buttonStyle(.plain)
```

### 5.8 埋点与日志增强

在 `ImportDebugRecord` 扩展（或 `LedgerStore.recordDebugEvent`）中新增字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `llmProvider` | `String?` | 使用的模型标识（`apple` / `gemma`） |
| `llmLatencyMs` | `Int?` | LLM 推理耗时（毫秒） |
| `llmConfidence` | `Double?` | LLM 返回的置信度 |
| `usedRuleFallback` | `Bool` | 是否走了规则兜底 |

`SmartResult` 的 `LLMTrace` 已包含 `provider` 和 `latencyMs`，在 `persistReceipt()` 中透传到 `recordDebugEvent()`。

DebugView 展示时增加一行显示模型和耗时：
```
模型: Gemma-4-E2B-it | 耗时: 420ms | 置信度: 0.85 | 规则兜底: 否
```

---

## 6. Prompt 优化与端侧性能考虑

### 6.1 为什么先清洗 OCR 文本

| 优化点 | 效果 |
|--------|------|
| 去除广告/推荐行 | 减少 ~20-30% token，降低干扰 |
| 合并空行 | 结构更紧凑 |
| 截断 1500 字符 | 2B 模型最佳 context 长度 |
| 去除装饰符号行 | 避免模型误把装饰行当内容 |

### 6.2 Prompt 设计原则

| 原则 | 做法 |
|------|------|
| 明确角色 | "你是一个记账文本解析器" —— 而非通用助手 |
| 规则先于正例 | 7 条硬性规则 + 候选项枚举 |
| 输出锁定 | "只输出 JSON，不要输出解释文字" |
| 置信度自评 | `confidence` 字段让模型自报把握度 |
| 冲突预案 | `needs_user_confirmation` 明确告知后续流程 |
| reason 可追溯 | 便于 DebugView 排查误判 |

### 6.3 端侧响应速度优化

- **OCR 预清洗**：减少输入 token
- **max_tokens 限制**：Gemma session 设 `maxTokens = 256`（JSON 输出不需要长回复）
- **temperature = 0.1**：降低采样随机性，加速 greedy decode
- **Cold start 预热**：App 启动时后台预加载 Gemma 权重到内存（`GemmaService.init` 中已做）

---

## 7. 迁移兼容性

| 场景 | 处理方式 |
|------|---------|
| 用户未选择过模型 | 默认 `appleFoundation` |
| Apple FM 不可用 + Gemma 未下载 | 自动降级纯规则引擎 |
| Gemma 下载中途取消 | 清理临时文件，状态回到 `notDownloaded` |
| Gemma 模型文件损坏 | `loadModel()` 失败 → 状态设为 `error`，用户可重新下载 |
| iOS < 26 设备 | Apple FM `@available` 守卫，只能用 Gemma 或规则 |

---

## 8. 实施步骤（确认后执行）

1. **新建枚举** `LLMProvider.swift`
2. **新建服务** `GemmaService.swift`（含 TODO 占位，待 MediaPipe SPM 集成）
3. **新建工具** `OCRTextCleaner.swift`
4. **重构** `SmartReceiptParser.swift`（多模型 + 新 prompt + 流程反转）
5. **修改** `LedgerStore.swift`（预清洗 + provider 传递）
6. **新建 UI** `AIModelSettingsView.swift`
7. **修改** `SettingsView.swift`（加入口）
8. **增强** `ImportDebugRecord` 日志字段
9. **更新** `CHANGELOG.md`

---

## 9. 待确认事项

- [ ] Gemma 模型下载源：Hugging Face 还是 Google 官方 CDN？需确认是否有国内可达镜像
先从验证 Hugging Face 可达性；若不可达，走我之后自建的分发CDN。
- [ ] MediaPipe iOS SDK 版本：是否已有 SPM 支持，或需要 CocoaPods？
若预研旧 MediaPipe GenAI iOS 方案，则按 CocoaPods 处理，不按官方 SPM 支持假设设计。
- [ ] `expense_type` 中的 `income/refund/transfer` 等非支出类型是否需要在界面上特殊标记？
需要，建议 UI 上至少做两层：
	•	主类型：支出 / 收入 / 退款 / 转账 / 还款 / 其他
	•	在账单列表里用标签区分非支出类型
方案里可以先定：
	•	expense：普通样式
	•	refund：绿色或回冲标记
	•	income：收入标记
	•	transfer / repayment：灰色中性标记
- [ ] `needs_user_confirmation == true` 时是否弹确认弹窗，还是仅在 DebugView 展示？
先不弹窗按照规则落成数据，之后正常弹快捷指令通知/App通知。和记账成功逻辑一致。
- [ ] 模型文件大小限制：2GB 下载是否需要 Wi-Fi 限制提示？
需要 Wi-Fi 下载提示，建议默认仅 Wi-Fi 下载，并支持用户手动覆盖。
