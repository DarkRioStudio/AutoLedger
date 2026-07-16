import AutoLedgerCore
import Foundation

/// Debug-only launch fixture for repeatable iPad and Mac performance profiling.
///
/// Invoke with `--performance-fixture-count 500`, `5000`, or `20000`. The
/// fixture uses an in-memory store and deliberately does not mutate the user's
/// preferences, SQLite database, CloudKit state, or analytics stream.
enum PerformanceFixtureConfiguration {
    private static let fixtureArgument = "--performance-fixture-count"
    private static let supportedTransactionCounts: Set<Int> = [500, 5_000, 20_000]

    static var isEnabled: Bool {
        transactionCount != nil
    }

    @MainActor
    static func makeLedgerStoreIfRequested() -> LedgerStore? {
        #if DEBUG
        guard let transactionCount else { return nil }
        return LedgerStore(
            transactionStore: PerformanceFixtureTransactionStore(count: transactionCount),
            loadsPersistedConfiguration: false
        )
        #else
        return nil
        #endif
    }

    private static var transactionCount: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: fixtureArgument),
              arguments.indices.contains(index + 1),
              let count = Int(arguments[index + 1]),
              supportedTransactionCounts.contains(count) else {
            return nil
        }
        return count
        #else
        return nil
        #endif
    }
}

#if DEBUG
private final class PerformanceFixtureTransactionStore: TransactionStore, @unchecked Sendable {
    private var transactions: [Transaction]

    init(count: Int) {
        let merchants = [
            "Harbor Coffee",
            "Northstar Market",
            "City Metro",
            "Riverside Hotel",
            "Cloud Music",
            "Corner Pharmacy",
            "Cedar Kitchen",
            "Atlas Books"
        ]
        let categories = TransactionCategory.allCases
        let sources = ReceiptSource.allCases
        let referenceDate = Date()
        let calendar = Calendar(identifier: .gregorian)

        transactions = (0..<count).map { index in
            let occurredAt = calendar.date(
                byAdding: .minute,
                value: -(index * 90),
                to: referenceDate
            ) ?? referenceDate
            let cents = Double(index % 100) / 100

            return Transaction(
                merchant: merchants[index % merchants.count],
                amount: Double(12 + (index % 340)) + cents,
                occurredAt: occurredAt,
                category: categories[index % categories.count],
                source: sources[index % sources.count],
                note: index.isMultiple(of: 29) ? "Performance fixture transaction \(index)" : "",
                ledgerID: TodaySpendingSummary.defaultLedgerID,
                ledgerCurrencyCode: "CNY"
            )
        }
    }

    func loadTransactions() throws -> [Transaction] {
        transactions
    }

    func save(transaction: Transaction) throws {
        transactions.insert(transaction, at: 0)
    }

    func update(transaction: Transaction) throws {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        transactions[index] = transaction
    }

    func delete(transactionID: UUID) throws {
        transactions.removeAll { $0.id == transactionID }
    }

    func bootstrapIfNeeded(with transactions: [Transaction]) throws -> [Transaction] {
        self.transactions
    }
}
#endif
