import Foundation

public struct LedgerDashboardCloudSnapshot: Codable, Equatable, Sendable {
    public static let defaultMaxTransactions = 720

    public let recordName: String
    public let generatedAt: Date
    public let referenceDate: Date
    public let deviceID: String
    public let transactions: [LedgerDashboardCloudTransaction]

    public init(
        recordName: String = CloudLedgerSyncSchema.dashboardSnapshotRecordName(),
        generatedAt: Date,
        referenceDate: Date,
        deviceID: String,
        transactions: [LedgerDashboardCloudTransaction]
    ) {
        self.recordName = recordName
        self.generatedAt = generatedAt
        self.referenceDate = referenceDate
        self.deviceID = deviceID
        self.transactions = transactions
    }

    public init(
        transactions: [Transaction],
        generatedAt: Date = .now,
        referenceDate: Date = .now,
        deviceID: String,
        maxTransactions: Int = Self.defaultMaxTransactions
    ) {
        let displayTransactions = transactions
            .filter { $0.amount > 0 }
            .sorted { lhs, rhs in
                if lhs.occurredAt == rhs.occurredAt {
                    return lhs.merchant < rhs.merchant
                }
                return lhs.occurredAt > rhs.occurredAt
            }
            .prefix(max(maxTransactions, 0))
            .map(LedgerDashboardCloudTransaction.init(transaction:))

        self.init(
            generatedAt: generatedAt,
            referenceDate: referenceDate,
            deviceID: deviceID,
            transactions: Array(displayTransactions)
        )
    }

    public var displayTransactions: [Transaction] {
        transactions.map(\.transaction)
    }
}

public struct LedgerDashboardCloudTransaction: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let merchant: String
    public let amount: Double
    public let occurredAt: Date
    public let category: String
    public let source: String
    public let note: String

    public init(
        id: UUID,
        merchant: String,
        amount: Double,
        occurredAt: Date,
        category: String,
        source: String,
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

    public init(transaction: Transaction) {
        self.init(
            id: transaction.id,
            merchant: transaction.merchant,
            amount: transaction.amount,
            occurredAt: transaction.occurredAt,
            category: transaction.category,
            source: transaction.source,
            note: transaction.note
        )
    }

    public var transaction: Transaction {
        Transaction(
            id: id,
            merchant: merchant,
            amount: amount,
            occurredAt: occurredAt,
            categoryLabel: category,
            sourceLabel: source,
            note: note
        )
    }
}
