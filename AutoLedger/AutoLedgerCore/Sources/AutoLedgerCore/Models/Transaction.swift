import Foundation

public struct Transaction: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let merchant: String
    public let amount: Double
    public let occurredAt: Date
    public let category: TransactionCategory
    public let source: ReceiptSource
    public let note: String

    public init(
        id: UUID = UUID(),
        merchant: String,
        amount: Double,
        occurredAt: Date,
        category: TransactionCategory,
        source: ReceiptSource,
        note: String
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.occurredAt = occurredAt
        self.category = category
        self.source = source
        self.note = note
    }
}
