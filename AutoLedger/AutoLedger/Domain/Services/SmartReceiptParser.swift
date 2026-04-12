import AutoLedgerCore
import Foundation
import FoundationModels
import os.log

private let logger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "SmartParser")

/// 混合解析器：规则提取金额/日期 → Foundation Models 提取商户+分类
/// 设备不支持时自动回退到纯规则解析
struct SmartReceiptParser: Sendable {

    struct LLMTrace: Sendable {
        let prompt: String
        let response: String
    }

    struct SmartResult: Sendable {
        let receipt: ImportedReceipt
        let llmTrace: LLMTrace?
    }

    private let ruleParser = ReceiptParser()

    // MARK: - 同步规则解析（兜底）

    func parseWithRules(text: String, source: ReceiptSource, fallbackMerchant: String? = nil) -> ImportedReceipt? {
        ruleParser.parse(text: text, source: source, fallbackMerchant: fallbackMerchant)
    }

    // MARK: - 智能解析（规则 + LLM）

    /// 低 OCR 置信度阈值：低于此值时 LLM prompt 额外要求验证金额字段
    private static let lowOCRConfidenceThreshold: Float = 0.75

    @available(iOS 26.0, *)
    func parse(text: String, source: ReceiptSource, fallbackMerchant: String? = nil,
               ocrMinConfidence: Float? = nil) async -> SmartResult? {
        // 1. 规则先提取金额和日期（可靠）
        guard let ruleResult = ruleParser.parse(text: text, source: source, fallbackMerchant: fallbackMerchant) else {
            logger.warning("[规则] 规则解析失败，无法提取金额")
            return nil
        }
        logger.info("[规则] 商户=\(ruleResult.merchant) 金额=\(ruleResult.amount) 时间=\(AppFormatters.exportDateTime(ruleResult.occurredAt)) 分类=\(ruleResult.suggestedCategory.title)")

        // 2. 检查设备是否支持 Foundation Models
        guard SystemLanguageModel.default.isAvailable else {
            logger.info("[LLM] 设备不支持 Foundation Models，使用纯规则结果")
            return SmartResult(receipt: ruleResult, llmTrace: nil)
        }

        // OCR 置信度低于阈值时，让 LLM 也协助验证金额（用于截图模糊等场景）
        let needsAmountVerification: Bool
        if let conf = ocrMinConfidence, conf < Self.lowOCRConfidenceThreshold {
            logger.warning("[LLM] OCR 置信度 \(String(format: "%.2f", conf)) < \(Self.lowOCRConfidenceThreshold)，启用金额二次验证")
            needsAmountVerification = true
        } else {
            needsAmountVerification = false
        }

        // 3. 用 LLM 提取商户名和分类（可选：同时验证金额）
        let prompt = buildPrompt(ocrText: text, verifyAmount: needsAmountVerification)

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let responseText = response.content

            guard let parsed = parseJSON(responseText) else {
                logger.warning("[LLM] JSON 解析失败，回退规则结果。响应: \(responseText.prefix(200))")
                return SmartResult(
                    receipt: ruleResult,
                    llmTrace: LLMTrace(prompt: prompt, response: responseText)
                )
            }

            let merchant = parsed.merchant.isEmpty ? ruleResult.merchant : parsed.merchant
            let category = TransactionCategory(rawValue: parsed.category) ?? ruleResult.suggestedCategory

            // 低置信模式：若 LLM 返回了 amount 且与规则结果差异 ≥ 5%，优先使用 LLM 金额
            let finalAmount: Double
            if needsAmountVerification, let llmAmount = parsed.amount, llmAmount > 0 {
                // 除数取 max(ruleResult.amount, 0.01) 避免规则金额为 0 时除零
                let minimumAmountForComparison = 0.01
                let ruleDiff = abs(llmAmount - ruleResult.amount) / max(ruleResult.amount, minimumAmountForComparison)
                if ruleDiff > 0.05 {
                    logger.warning("[LLM] OCR 低置信：规则金额=\(ruleResult.amount) LLM金额=\(llmAmount)，采用LLM结果")
                    finalAmount = llmAmount
                } else {
                    finalAmount = ruleResult.amount
                }
            } else {
                finalAmount = ruleResult.amount
            }
            logger.info("[LLM] 商户=\(merchant) 分类=\(category.title) 金额=\(finalAmount)")

            let enhanced = ImportedReceipt(
                source: source,
                merchant: merchant,
                amount: finalAmount,
                occurredAt: ruleResult.occurredAt,
                rawText: ruleResult.rawText,
                summary: "\(source.title) 智能解析",
                confidence: 0.92,
                suggestedCategory: category
            )

            return SmartResult(
                receipt: enhanced,
                llmTrace: LLMTrace(prompt: prompt, response: responseText)
            )
        } catch {
            logger.error("[LLM] 调用失败: \(error.localizedDescription)")
            return SmartResult(receipt: ruleResult, llmTrace: LLMTrace(prompt: prompt, response: "错误：\(error.localizedDescription)"))
        }
    }

    // MARK: - Prompt

    private func buildPrompt(ocrText: String, verifyAmount: Bool = false) -> String {
        let amountField = verifyAmount ? """
        - amount：数字金额，不带货币符号（如 45.00）。OCR 识别质量可能较低，请根据上下文判断真实应付金额；如无法确定请返回 null
        """ : ""
        let amountOutput = verifyAmount ? #", "amount": 金额数字或null"# : ""
        return """
        你是一个支付收据解析助手。从以下 OCR 文本中提取字段，以 JSON 格式返回。
        只返回 JSON，不要解释。

        字段说明：
        - merchant：商户或商品名称（如"麦当劳""Apple Developer Program"），不要填写帮助文案、付款方式等无关内容
        - category：从以下选项中选一个最匹配的：groceries, dining, transport, shopping, digital, utilities, entertainment, other
        \(amountField)
        分类参考：
        - dining：餐饮、咖啡、奶茶、外卖、快餐
        - digital：App Store、订阅服务、会员、软件
        - transport：打车、地铁、出行
        - groceries：超市、便利店、生鲜
        - shopping：电商、商城
        - utilities：水电燃气
        - entertainment：电影、游戏

        OCR 文本：
        \(ocrText.prefix(2000))

        返回格式：
        {"merchant": "商户名", "category": "分类"\(amountOutput)}
        """
    }

    // MARK: - JSON 解析

    private struct LLMOutput: Decodable {
        let merchant: String
        let category: String
        /// 仅在低 OCR 置信度模式下由 LLM 填充
        let amount: Double?
    }

    private func parseJSON(_ text: String) -> LLMOutput? {
        // 尝试从响应中提取 JSON 块
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 找到第一个 { 和最后一个 }
        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else {
            return nil
        }

        let jsonStr = String(cleaned[start...end])
        guard let data = jsonStr.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LLMOutput.self, from: data)
    }
}
