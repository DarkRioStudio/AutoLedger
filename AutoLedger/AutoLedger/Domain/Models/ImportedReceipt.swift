import Foundation

struct ImportedReceipt: Identifiable, Equatable {
    let id = UUID()
    let source: ReceiptSource
    let merchant: String
    let amount: Double
    let occurredAt: Date
    let rawText: String
    let summary: String
    let confidence: Double
    let suggestedCategory: TransactionCategory
}
