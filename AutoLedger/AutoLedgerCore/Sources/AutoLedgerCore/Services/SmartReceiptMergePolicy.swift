import Foundation

public struct ReceiptAISuggestion: Equatable, Sendable {
    public let merchant: String
    public let amount: Double
    public let occurredAt: Date?
    public let confidence: Double
    public let needsUserConfirmation: Bool
    public let suggestedCategory: TransactionCategory?

    public init(
        merchant: String,
        amount: Double,
        occurredAt: Date?,
        confidence: Double,
        needsUserConfirmation: Bool,
        suggestedCategory: TransactionCategory?
    ) {
        self.merchant = merchant
        self.amount = amount
        self.occurredAt = occurredAt
        self.confidence = confidence
        self.needsUserConfirmation = needsUserConfirmation
        self.suggestedCategory = suggestedCategory
    }
}

public struct SmartReceiptMergeOutcome: Equatable, Sendable {
    public let receipt: ImportedReceipt
    public let usedRuleAmount: Bool
    public let usedAIEnrichment: Bool

    public init(receipt: ImportedReceipt, usedRuleAmount: Bool, usedAIEnrichment: Bool) {
        self.receipt = receipt
        self.usedRuleAmount = usedRuleAmount
        self.usedAIEnrichment = usedAIEnrichment
    }
}

public struct SmartReceiptMergePolicy: Sendable {
    public init() {}

    public func merge(
        aiSuggestion: ReceiptAISuggestion?,
        ruleReceipt: ImportedReceipt?,
        source: ReceiptSource,
        rawText: String,
        summary: String? = nil,
        now: () -> Date = { Date() }
    ) -> SmartReceiptMergeOutcome? {
        guard let aiSuggestion else {
            guard let ruleReceipt else { return nil }
            return SmartReceiptMergeOutcome(
                receipt: ruleReceipt,
                usedRuleAmount: true,
                usedAIEnrichment: false
            )
        }

        if let ruleReceipt {
            guard !aiSuggestion.needsUserConfirmation else {
                return SmartReceiptMergeOutcome(
                    receipt: ruleReceipt,
                    usedRuleAmount: true,
                    usedAIEnrichment: false
                )
            }

            let merchant = aiSuggestion.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let enrichedMerchant = merchant.isEmpty ? ruleReceipt.merchant : merchant
            let category = aiSuggestion.suggestedCategory ?? ruleReceipt.suggestedCategory
            let mergedRawText = rawText.isEmpty ? ruleReceipt.rawText : rawText
            let mergedSummary = summary ?? "\(source.title) AI辅助解析"
            let confidence = max(aiSuggestion.confidence, ruleReceipt.confidence)

            let receipt = ImportedReceipt(
                source: source,
                merchant: enrichedMerchant,
                amount: ruleReceipt.amount,
                occurredAt: ruleReceipt.occurredAt,
                rawText: mergedRawText,
                summary: mergedSummary,
                confidence: confidence,
                suggestedCategory: category,
                parseDiagnostics: ruleReceipt.parseDiagnostics
            )
            return SmartReceiptMergeOutcome(
                receipt: receipt,
                usedRuleAmount: true,
                usedAIEnrichment: true
            )
        }

        guard aiSuggestion.amount > 0, !aiSuggestion.needsUserConfirmation else {
            return nil
        }

        let merchant = aiSuggestion.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let receipt = ImportedReceipt(
            source: source,
            merchant: merchant.isEmpty ? "未知商户" : merchant,
            amount: aiSuggestion.amount,
            occurredAt: aiSuggestion.occurredAt ?? now(),
            rawText: rawText,
            summary: summary ?? "\(source.title) AI解析",
            confidence: aiSuggestion.confidence,
            suggestedCategory: aiSuggestion.suggestedCategory ?? .other
        )
        return SmartReceiptMergeOutcome(
            receipt: receipt,
            usedRuleAmount: false,
            usedAIEnrichment: true
        )
    }
}
