import AutoLedgerCore
import Foundation
import FoundationModels
import os.log

private let logger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "SmartParser")

/// 多模型智能解析器：LLM 优先提取全部字段 → 低置信度时规则兜底
/// 支持 Apple Foundation Models / Gemma-4-E2B-it；模型全部不可用时回退纯规则
struct SmartReceiptParser: Sendable {

    struct LLMTrace: Sendable {
        let prompt: String
        let response: String
        let provider: LLMProvider
        let latencyMs: Int
    }

    struct SmartResult: Sendable {
        let receipt: ImportedReceipt
        let llmTrace: LLMTrace?
        let usedRuleFallback: Bool
    }

    private let ruleParser = ReceiptParser()

    // MARK: - 同步规则解析（兜底）

    func parseWithRules(text: String, source: ReceiptSource, fallbackMerchant: String? = nil) -> ImportedReceipt? {
        ruleParser.parse(text: text, source: source, fallbackMerchant: fallbackMerchant)
    }

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
        provider: LLMProvider
    ) async -> SmartResult? {
        if let diagnostics = ruleParser.receiptDiagnostics(text: text), diagnostics.isMultiItemReceipt {
            logger.info("[规则优先] 命中多商品小票，直接使用 receipt total 规则。\(diagnostics.debugSummary)")
            guard let receipt = ruleParser.parse(text: text, source: source, fallbackMerchant: fallbackMerchant) else {
                return nil
            }
            return SmartResult(receipt: receipt, llmTrace: nil, usedRuleFallback: true)
        }

        let providerAvailable = await provider.isAvailable

        // ── Step 1: 尝试 LLM 优先解析 ──
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

                    // 高置信度 → 直接采用 LLM 结果
                    if confidence >= Self.confidenceThreshold && !parsed.needsUserConfirmation {
                        let receipt = buildReceipt(from: parsed, source: source, rawText: text)
                        logger.info("[LLM] 高置信采用: 商户=\(receipt.merchant) 金额=\(receipt.amount) 置信度=\(confidence)")
                        return SmartResult(
                            receipt: receipt,
                            llmTrace: LLMTrace(prompt: prompt, response: responseText,
                                               provider: provider, latencyMs: latencyMs),
                            usedRuleFallback: false
                        )
                    }

                    // 低置信度 → 用规则引擎交叉验证
                    logger.info("[LLM] 置信度 \(String(format: "%.2f", confidence)) < \(Self.confidenceThreshold)，启用规则交叉验证")
                    let ruleResult = ruleParser.parse(text: text, source: source,
                                                      fallbackMerchant: fallbackMerchant)
                    let merged = mergeResults(llm: parsed, rule: ruleResult, source: source, rawText: text)
                    return SmartResult(
                        receipt: merged,
                        llmTrace: LLMTrace(prompt: prompt, response: responseText,
                                           provider: provider, latencyMs: latencyMs),
                        usedRuleFallback: true
                    )
                } else {
                    logger.warning("[LLM] JSON 解析失败，回退规则。响应: \(responseText.prefix(200))")
                    // LLM 返回了但无法解析 → 仍记录 trace 并走规则兜底
                    let ruleResult = ruleParser.parse(text: text, source: source,
                                                      fallbackMerchant: fallbackMerchant)
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
        guard let ruleResult = ruleParser.parse(text: text, source: source,
                                                 fallbackMerchant: fallbackMerchant) else {
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
           - "赵一鸣零食（天津利津店）" 中 merchant_name 应为 "赵一鸣零食"

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

    /// 从 LLM 输出构建 ImportedReceipt
    private func buildReceipt(from llm: LLMSmartOutput, source: ReceiptSource, rawText: String) -> ImportedReceipt {
        let amount = parseAmount(llm.amount)
        let category = mapExpenseTypeToCategory(llm.expenseType)
        // 日期仍由规则引擎提取（regex 对日期格式更可靠）
        let date = ruleParser.parse(text: rawText, source: source)?.occurredAt ?? Date()
        return ImportedReceipt(
            source: source,
            merchant: llm.merchantName,
            amount: amount,
            occurredAt: date,
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
        let date = rule?.occurredAt ?? Date()
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
        case "expense":   return .other
        case "dining":    return .dining
        case "transport": return .transport
        case "income", "refund", "transfer", "repayment", "topup":
            return .other
        default:          return .other
        }
    }
}
