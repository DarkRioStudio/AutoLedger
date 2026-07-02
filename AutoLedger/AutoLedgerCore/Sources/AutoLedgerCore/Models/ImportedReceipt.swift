import Foundation

public struct ReceiptParseDiagnostics: Equatable, Sendable {
    public let isMultiItemReceipt: Bool
    public let totalMatched: Bool
    public let merchantCandidate: String?
    public let totalCandidates: [Double]
    public let itemLineCount: Int
    public let rule: String
    public let note: String?

    public init(
        isMultiItemReceipt: Bool,
        totalMatched: Bool,
        merchantCandidate: String?,
        totalCandidates: [Double],
        itemLineCount: Int,
        rule: String,
        note: String? = nil
    ) {
        self.isMultiItemReceipt = isMultiItemReceipt
        self.totalMatched = totalMatched
        self.merchantCandidate = merchantCandidate
        self.totalCandidates = totalCandidates
        self.itemLineCount = itemLineCount
        self.rule = rule
        self.note = note
    }

    public var debugSummary: String {
        let totals = totalCandidates
            .prefix(5)
            .map { String(format: "%.2f", $0) }
            .joined(separator: ",")
        return "receipt=\(isMultiItemReceipt) totalMatched=\(totalMatched) merchant=\(merchantCandidate ?? "-") totals=[\(totals)] itemLines=\(itemLineCount) rule=\(rule)"
    }
}

public struct ImportedReceipt: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let source: ReceiptSource
    public let merchant: String
    public let amount: Double
    public let currencyCode: String?
    public let occurredAt: Date
    public let rawText: String
    public let summary: String
    public let confidence: Double
    public let suggestedCategory: TransactionCategory
    public let parseDiagnostics: ReceiptParseDiagnostics?

    public init(
        source: ReceiptSource,
        merchant: String,
        amount: Double,
        currencyCode: String? = nil,
        occurredAt: Date,
        rawText: String,
        summary: String,
        confidence: Double,
        suggestedCategory: TransactionCategory,
        parseDiagnostics: ReceiptParseDiagnostics? = nil
    ) {
        self.source = source
        self.merchant = merchant
        self.amount = amount
        self.currencyCode = currencyCode
        self.occurredAt = occurredAt
        self.rawText = rawText
        self.summary = summary
        self.confidence = confidence
        self.suggestedCategory = suggestedCategory
        self.parseDiagnostics = parseDiagnostics
    }

    public func replacingCurrencyCode(_ newCurrencyCode: String?) -> ImportedReceipt {
        ImportedReceipt(
            source: source,
            merchant: merchant,
            amount: amount,
            currencyCode: newCurrencyCode,
            occurredAt: occurredAt,
            rawText: rawText,
            summary: summary,
            confidence: confidence,
            suggestedCategory: suggestedCategory,
            parseDiagnostics: parseDiagnostics
        )
    }
}
