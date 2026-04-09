import Foundation

public protocol TransactionStore: Sendable {
    func loadTransactions() throws -> [Transaction]
    func save(transaction: Transaction) throws
    func update(transaction: Transaction) throws
    func delete(transactionID: UUID) throws
    func bootstrapIfNeeded(with transactions: [Transaction]) throws -> [Transaction]
}
