import Foundation

public struct ImportedReceipt: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let source: ReceiptSource
    public let merchant: String
    public let amount: Double
    public let occurredAt: Date
    public let rawText: String
    public let summary: String
    public let confidence: Double
    public let suggestedCategory: TransactionCategory

    public init(
        source: ReceiptSource,
        merchant: String,
        amount: Double,
        occurredAt: Date,
        rawText: String,
        summary: String,
        confidence: Double,
        suggestedCategory: TransactionCategory
    ) {
        self.source = source
        self.merchant = merchant
        self.amount = amount
        self.occurredAt = occurredAt
        self.rawText = rawText
        self.summary = summary
        self.confidence = confidence
        self.suggestedCategory = suggestedCategory
    }
}
