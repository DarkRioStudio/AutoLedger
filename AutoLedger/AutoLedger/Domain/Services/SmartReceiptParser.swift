import AutoLedgerCore
import Foundation
import FoundationModels

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

    @available(iOS 26.0, *)
    func parse(text: String, source: ReceiptSource, fallbackMerchant: String? = nil) async -> SmartResult? {
        // 1. 规则先提取金额和日期（可靠）
        guard let ruleResult = ruleParser.parse(text: text, source: source, fallbackMerchant: fallbackMerchant) else {
            return nil
        }

        // 2. 检查设备是否支持 Foundation Models
        guard SystemLanguageModel.default.isAvailable else {
            return SmartResult(receipt: ruleResult, llmTrace: nil)
        }

        // 3. 用 LLM 提取商户名和分类
        let prompt = buildPrompt(ocrText: text)

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let responseText = response.content

            guard let parsed = parseJSON(responseText) else {
                return SmartResult(
                    receipt: ruleResult,
                    llmTrace: LLMTrace(prompt: prompt, response: responseText)
                )
            }

            let merchant = parsed.merchant.isEmpty ? ruleResult.merchant : parsed.merchant
            let category = TransactionCategory(rawValue: parsed.category) ?? ruleResult.suggestedCategory

            let enhanced = ImportedReceipt(
                source: source,
                merchant: merchant,
                amount: ruleResult.amount,
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
            return SmartResult(receipt: ruleResult, llmTrace: LLMTrace(prompt: prompt, response: "错误：\(error.localizedDescription)"))
        }
    }

    // MARK: - Prompt

    private func buildPrompt(ocrText: String) -> String {
        """
        你是一个支付收据解析助手。从以下 OCR 文本中提取两个字段，以 JSON 格式返回。
        只返回 JSON，不要解释。

        字段说明：
        - merchant：商户或商品名称（如"麦当劳""Apple Developer Program"），不要填写帮助文案、付款方式等无关内容
        - category：从以下选项中选一个最匹配的：groceries, dining, transport, shopping, digital, utilities, entertainment, other

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
        {"merchant": "商户名", "category": "分类"}
        """
    }

    // MARK: - JSON 解析

    private struct LLMOutput: Decodable {
        let merchant: String
        let category: String
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
