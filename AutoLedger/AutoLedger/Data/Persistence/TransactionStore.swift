import Foundation

protocol TransactionStore {
    func loadTransactions() throws -> [Transaction]
    func save(transaction: Transaction) throws
    func update(transaction: Transaction) throws
    func bootstrapIfNeeded(with transactions: [Transaction]) throws -> [Transaction]
}
