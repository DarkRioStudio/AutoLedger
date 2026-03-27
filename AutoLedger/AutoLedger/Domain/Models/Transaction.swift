import Foundation

struct Transaction: Identifiable, Equatable, Codable {
    let id: UUID
    let merchant: String
    let amount: Double
    let occurredAt: Date
    let category: TransactionCategory
    let source: ReceiptSource
    let note: String

    init(
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
