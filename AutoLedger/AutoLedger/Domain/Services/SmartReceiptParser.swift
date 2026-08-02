import AutoLedgerCore
import Foundation
import FoundationModels
import os.log

private let logger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "SmartParser")

/// 多模型智能解析器：规则先锁定金额 → LLM 只做商户/分类等字段增强
/// 支持 Apple Foundation Models / Gemma-4-E2B-it；模型全部不可用时回退纯规则
struct SmartReceiptParser: Sendable {

    struct LLMTrace: Sendable {
        let prompt: String
        let response: String
        let providerID: String
        let providerDisplayName: String
        let latencyMs: Int

        init(prompt: String, response: String, provider: LLMProvider, latencyMs: Int) {
            self.prompt = prompt
            self.response = response
            self.providerID = provider.rawValue
            self.providerDisplayName = provider.displayName
            self.latencyMs = latencyMs
        }

        init(prompt: String, response: String, providerID: String, providerDisplayName: String, latencyMs: Int) {
            self.prompt = prompt
            self.response = response
            self.providerID = providerID
            self.providerDisplayName = providerDisplayName
            self.latencyMs = latencyMs
        }
    }

    struct SmartResult: Sendable {
        let receipt: ImportedReceipt
        let llmTrace: LLMTrace?
        let usedRuleFallback: Bool
    }

    private struct ExternalAssistMergeResult: Sendable {
        let receipt: ImportedReceipt
        let trace: LLMTrace
        let usedRuleAmount: Bool
    }

    private let ruleParser = ReceiptParser()
    private let mergePolicy = SmartReceiptMergePolicy()
    private let externalAssistClient: any ExternalReceiptAssistClientProtocol

    init(externalAssistClient: any ExternalReceiptAssistClientProtocol = ExternalReceiptAssistClient()) {
        self.externalAssistClient = externalAssistClient
    }

    // MARK: - 同步规则解析（兜底）

    func parseWithRules(text: String, source: ReceiptSource, imageData: Data? = nil, fallbackMerchant: String? = nil) -> ImportedReceipt? {
        ruleParser.parse(text: text, source: source, imageData: imageData, fallbackMerchant: fallbackMerchant)
    }

    func parseWithExternalAssist(
        text: String,
        source: ReceiptSource,
        imageData: Data? = nil,
        fallbackMerchant: String? = nil
    ) async -> SmartResult? {
        guard !ruleParser.isFullyRefundedWeChatDetail(text: text) else {
            logger.info("[规则优先] 微信账单已全额退款，不生成正向支出草稿")
            return nil
        }
        let ruleResult = ruleParser.parse(
            text: text,
            source: source,
            imageData: imageData,
            fallbackMerchant: fallbackMerchant
        )

        if let ruleResult, Self.shouldSkipExternalAssist(for: ruleResult) {
            return SmartResult(receipt: ruleResult, llmTrace: nil, usedRuleFallback: true)
        }

        if let externalMerged = await requestExternalAssistIfAvailable(
            text: text,
            source: source,
            ruleResult: ruleResult
        ) {
            return SmartResult(
                receipt: externalMerged.receipt,
                llmTrace: externalMerged.trace,
                usedRuleFallback: externalMerged.usedRuleAmount
            )
        }

        guard let ruleResult else {
            return nil
        }
        return SmartResult(receipt: ruleResult, llmTrace: nil, usedRuleFallback: true)
    }

    // MARK: - 置信度阈值

    /// LLM 结果置信度 ≥ 此值时用于字段增强，否则规则兜底
    private static let confidenceThreshold: Double = 0.7

    // MARK: - 主入口（规则金额优先）

    @available(iOS 26.0, *)
    func parse(
        text: String,
        source: ReceiptSource,
        imageData: Data? = nil,
        fallbackMerchant: String? = nil,
        ocrMinConfidence: Float? = nil,
        provider: LLMProvider
    ) async -> SmartResult? {
        guard !ruleParser.isFullyRefundedWeChatDetail(text: text) else {
            logger.info("[规则优先] 微信账单已全额退款，不调用模型生成正向支出")
            return nil
        }
        if let diagnostics = ruleParser.receiptDiagnostics(text: text), diagnostics.isMultiItemReceipt {
            logger.info("[规则优先] 命中多商品小票，直接使用 receipt total 规则。\(diagnostics.debugSummary)")
            guard let receipt = ruleParser.parse(text: text, source: source, fallbackMerchant: fallbackMerchant) else {
                return nil
            }
            return SmartResult(receipt: receipt, llmTrace: nil, usedRuleFallback: true)
        }

        let ruleResult = ruleParser.parse(
            text: text,
            source: source,
            imageData: imageData,
            fallbackMerchant: fallbackMerchant
        )

        if let ruleResult, Self.shouldSkipExternalAssist(for: ruleResult) {
            return SmartResult(receipt: ruleResult, llmTrace: nil, usedRuleFallback: true)
        }

        let providerAvailable = await provider.isAvailable

        if let externalMerged = await requestExternalAssistIfAvailable(
            text: text,
            source: source,
            ruleResult: ruleResult
        ) {
            return SmartResult(
                receipt: externalMerged.receipt,
                llmTrace: externalMerged.trace,
                usedRuleFallback: externalMerged.usedRuleAmount
            )
        }

        // ── Step 1: 尝试 LLM 字段增强 ──
        if providerAvailable {
            let prompt = buildSmartPrompt(ocrText: text)
            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                let responseText: String
                switch provider {
                case .appleFoundation:
                    let session = LanguageModelSession(instructions: "只输出 JSON，不要输出解释文字。不要使用 thinking。")
                    let response = try await session.respond(to: prompt)
                    responseText = response.content
                case .gemma:
                    responseText = try await GemmaService.shared.generate(prompt: prompt)
                }

                let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                logger.info("[LLM/\(provider.displayName)] 响应耗时 \(latencyMs)ms")

                if let parsed = parseLLMOutput(responseText) {
                    let confidence = parsed.confidence

                    let aiSuggestion = makeAISuggestion(from: parsed)

                    // 高置信度 → 采用 LLM 字段增强，但金额仍优先使用规则结果
                    if confidence >= Self.confidenceThreshold && !parsed.needsUserConfirmation {
                        guard let merged = mergePolicy.merge(
                            aiSuggestion: aiSuggestion,
                            ruleReceipt: ruleResult,
                            source: source,
                            rawText: text,
                            summary: "\(source.title) 智能解析"
                        ) else {
                            return nil
                        }
                        logger.info("[LLM] 高置信增强: 商户=\(merged.receipt.merchant) 金额=\(merged.receipt.amount) 规则金额=\(merged.usedRuleAmount ? "是" : "否") 置信度=\(confidence)")
                        return SmartResult(
                            receipt: merged.receipt,
                            llmTrace: LLMTrace(prompt: prompt, response: responseText,
                                               provider: provider, latencyMs: latencyMs),
                            usedRuleFallback: merged.usedRuleAmount
                        )
                    }

                    // 低置信度 → 用规则引擎交叉验证
                    logger.info("[LLM] 置信度 \(String(format: "%.2f", confidence)) < \(Self.confidenceThreshold)，启用规则交叉验证")
                    guard let merged = mergePolicy.merge(
                        aiSuggestion: aiSuggestion,
                        ruleReceipt: ruleResult,
                        source: source,
                        rawText: text,
                        summary: "\(source.title) 混合解析"
                    ) else {
                        return nil
                    }
                    return SmartResult(
                        receipt: merged.receipt,
                        llmTrace: LLMTrace(prompt: prompt, response: responseText,
                                           provider: provider, latencyMs: latencyMs),
                        usedRuleFallback: merged.usedRuleAmount
                    )
                } else {
                    logger.warning("[LLM] JSON 解析失败，回退规则。响应: \(responseText.prefix(200))")
                    // LLM 返回了但无法解析 → 仍记录 trace 并走规则兜底
                    guard let ruleResult else { return nil }
                    return SmartResult(
                        receipt: ruleResult,
                        llmTrace: LLMTrace(prompt: prompt, response: responseText,
                                           provider: provider, latencyMs: latencyMs),
                        usedRuleFallback: true
                    )
                }
            } catch {
                logger.error("[LLM/\(provider.displayName)] 调用失败: \(error.localizedDescription)")
            }
        } else {
            let reason = await provider.unavailableReason ?? "未知"
            logger.info("[LLM] \(provider.displayName) 不可用: \(reason)")
        }

        // ── Step 2: 纯规则兜底 ──
        guard let ruleResult else {
            logger.warning("[规则] 规则解析也失败，无法提取可入账字段")
            return nil
        }
        logger.info("[规则兜底] 商户=\(ruleResult.merchant) 金额=\(ruleResult.amount)")
        return SmartResult(receipt: ruleResult, llmTrace: nil, usedRuleFallback: true)
    }

    // MARK: - Prompt（结构化版本）

    private func buildSmartPrompt(ocrText: String) -> String {
        """
        你是一个记账文本解析器。请从OCR文本中提取本次真实交易记录。

        字段定义：
        1. merchant_name：
           本次交易的实际商户品牌名或主店铺名。
           优先提取品牌/店名本体，不要只输出商场名、地点名、分店后缀。
           例如：
           - "鱼你在一起（东丽万达广场店）" 中 merchant_name 应为 "鱼你在一起"
           - "Example Mini Market零食（天津利津店）" 中 merchant_name 应为 "Example Mini Market零食"

        2. store_branch_name：
           商户的分店/门店名称，可包含"xx店"这类后缀。
           例如：
           - "东丽万达广场店"
           - "天津利津店"

        3. location_name：
           商场、综合体、地理位置名称。可以为空。
           例如：
           - "东丽万达广场"
           - "大悦城"
           - "印象城"

        4. amount：
           本次实际支付金额，优先选择"实付""支付金额""已支付"附近金额。
           "代金券""随机补贴""购物金""本店更多团购""推荐商品"相关金额不是本次消费金额，除非没有更明确的实付金额。

        5. expense_type：
           交易类型，从以下选项中选一个：expense, income, refund, transfer, repayment, topup, not_transaction, unknown

        规则：
        - merchant_name 必须优先输出品牌名/店铺主名，而不是商场名或单独的"xx店"。
        - 如果文本包含"品牌名（分店名）"，则 merchant_name = 品牌名，store_branch_name = 分店名。
        - 商场名不能作为 merchant_name。
        - 地址不能作为 merchant_name。
        - 如果信息不足或存在多个冲突候选，needs_user_confirmation 返回 true。
        - 不允许编造文本中不存在的信息。
        - 只输出 JSON，不要输出解释文字。

        OCR 文本：
        \(ocrText.prefix(1500))

        输出 JSON 格式如下：
        {"merchant_name": "", "store_branch_name": "", "location_name": "", "amount": "", "expense_type": "", "confidence": 0.0, "needs_user_confirmation": false, "reason": ""}
        """
    }

    // MARK: - LLM 输出解析

    private struct LLMSmartOutput: Decodable {
        let merchantName: String
        let storeBranchName: String?
        let locationName: String?
        let amount: String
        let expenseType: String
        let confidence: Double
        let needsUserConfirmation: Bool
        let reason: String?

        enum CodingKeys: String, CodingKey {
            case merchantName = "merchant_name"
            case storeBranchName = "store_branch_name"
            case locationName = "location_name"
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

    private func makeAISuggestion(from llm: LLMSmartOutput) -> ReceiptAISuggestion {
        let category = mapExpenseTypeToCategory(llm.expenseType)
        return ReceiptAISuggestion(
            merchant: llm.merchantName,
            amount: parseAmount(llm.amount),
            occurredAt: nil,
            confidence: llm.confidence,
            needsUserConfirmation: llm.needsUserConfirmation,
            suggestedCategory: category
        )
    }

    private func requestExternalAssistIfAvailable(
        text: String,
        source: ReceiptSource,
        ruleResult: ImportedReceipt?
    ) async -> ExternalAssistMergeResult? {
        let apiKey = ExternalReceiptAssistSettings.runtimeAPIKey
        let configuration = ExternalReceiptAssistSettings.gateConfiguration(apiKey: apiKey)
        let payload = ExternalReceiptAssistPayloadBuilder().build(rawText: text, source: source)
        let decision = ExternalReceiptAssistGate().evaluate(configuration: configuration, payload: payload)

        guard decision.canRequest, let apiKey else {
            if configuration.isEnabled, let reason = decision.reason {
                logger.info("[ExternalAssist] 跳过外部辅助识别: \(String(describing: reason))")
            }
            return nil
        }

        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            let suggestion = try await externalAssistClient.requestSuggestion(
                payload: payload,
                configuration: configuration,
                apiKey: apiKey
            )
            let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            let trace = LLMTrace(
                prompt: Self.externalAssistPromptSummary(payload: payload, configuration: configuration),
                response: Self.externalAssistResponseSummary(suggestion),
                providerID: "external_\(configuration.provider.rawValue)",
                providerDisplayName: "\(configuration.provider.displayName) 外部辅助",
                latencyMs: latencyMs
            )
            guard let aiSuggestion = ExternalReceiptAssistSuggestionMapper().makeAISuggestion(from: suggestion),
                  let merged = mergePolicy.merge(
                    aiSuggestion: aiSuggestion,
                    ruleReceipt: ruleResult,
                    source: source,
                    rawText: text,
                    summary: "\(source.title) 外部辅助解析"
                  ),
                  merged.usedAIEnrichment else {
                if let ruleResult, suggestion.subscriptionHint != nil {
                    logger.info("[ExternalAssist] 已记录订阅 hint，保留本地规则解析结果")
                    return ExternalAssistMergeResult(
                        receipt: ruleResult,
                        trace: trace,
                        usedRuleAmount: true
                    )
                }
                return nil
            }
            logger.info("[ExternalAssist] 已合并外部辅助候选，商户=\(merged.receipt.merchant) 规则金额=\(merged.usedRuleAmount ? "是" : "否")")
            return ExternalAssistMergeResult(
                receipt: merged.receipt,
                trace: trace,
                usedRuleAmount: merged.usedRuleAmount
            )
        } catch {
            logger.info("[ExternalAssist] 外部辅助识别失败，继续本地解析: \(error.localizedDescription)")
            return nil
        }
    }

    private static func externalAssistPromptSummary(
        payload: ExternalReceiptAssistPayload,
        configuration: ExternalReceiptAssistConfiguration
    ) -> String {
        """
        External Assist 请求摘要
        Provider: \(configuration.provider.displayName)
        Model: \(configuration.modelName)
        Sanitized OCR:
        \(payload.sanitizedText)
        """
    }

    private static func externalAssistResponseSummary(_ suggestion: ExternalReceiptAssistSuggestion) -> String {
        let merchants = suggestion.merchantCandidates.joined(separator: ", ")
        let category = suggestion.categoryHint ?? "未返回"
        let confidence = suggestion.confidence.map { String(format: "%.2f", $0) } ?? "未返回"
        let subscription = Self.externalAssistSubscriptionSummary(suggestion.subscriptionHint)
        return """
        merchantCandidates: \(merchants.isEmpty ? "未返回" : merchants)
        categoryHint: \(category)
        confidence: \(confidence)
        subscriptionHint: \(subscription)
        """
    }

    private static func externalAssistSubscriptionSummary(_ hint: ExternalReceiptAssistSubscriptionHint?) -> String {
        guard let hint else { return "未返回" }

        let serviceName = hint.serviceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let billingCycle = hint.billingCycle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let confidence = hint.confidence.map { String(format: "%.2f", $0) } ?? "未返回"
        let serviceText = serviceName?.isEmpty == false ? serviceName! : "未返回"
        let cycleText = billingCycle?.isEmpty == false ? billingCycle! : "未返回"
        return "isSubscription=\(hint.isSubscription ? "true" : "false"), serviceName=\(serviceText), billingCycle=\(cycleText), confidence=\(confidence)"
    }

    private static func shouldSkipExternalAssist(for receipt: ImportedReceipt) -> Bool {
        guard receipt.suggestedCategory == .transport else { return false }
        return receipt.merchant.hasPrefix("地铁：")
            || receipt.merchant.hasPrefix("公交：")
    }

    /// 金额字符串 → Double
    private func parseAmount(_ str: String) -> Double {
        let cleaned = str.replacingOccurrences(of: "[¥￥$€,，]", with: "", options: .regularExpression)
        return Double(cleaned) ?? 0
    }

    /// expense_type → TransactionCategory 映射
    private func mapExpenseTypeToCategory(_ type: String) -> TransactionCategory {
        switch type {
        case "expense":   return .other
        case "dining":    return .dining
        case "transport": return .transport
        case "hotel", "lodging", "accommodation":
            return .hotel
        case "income", "refund", "transfer", "repayment", "topup":
            return .other
        default:          return .other
        }
    }
}
