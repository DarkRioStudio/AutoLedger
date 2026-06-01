import Foundation

public struct TodaySpendingSummary: Equatable, Sendable {
    public static let defaultLedgerID = "default-local-ledger"
    public static let defaultLedgerName = "本地账本"

    public let ledgerID: String
    public let ledgerName: String
    public let dayInterval: DateInterval
    public let totalExpense: Double
    public let transactionCount: Int
    public let recentTransaction: Transaction?
    public let recentDisplayName: String?

    public var isEmpty: Bool {
        transactionCount == 0
    }

    public init(
        ledgerID: String = Self.defaultLedgerID,
        ledgerName: String = Self.defaultLedgerName,
        dayInterval: DateInterval,
        totalExpense: Double,
        transactionCount: Int,
        recentTransaction: Transaction?,
        recentDisplayName: String?
    ) {
        self.ledgerID = ledgerID
        self.ledgerName = ledgerName
        self.dayInterval = dayInterval
        self.totalExpense = totalExpense
        self.transactionCount = transactionCount
        self.recentTransaction = recentTransaction
        self.recentDisplayName = recentDisplayName
    }

    public static func build(
        from activeTransactions: [Transaction],
        referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        ledgerID: String = Self.defaultLedgerID,
        ledgerName: String = Self.defaultLedgerName
    ) -> TodaySpendingSummary {
        guard let dayInterval = calendar.dateInterval(of: .day, for: referenceDate) else {
            return TodaySpendingSummary(
                ledgerID: ledgerID,
                ledgerName: ledgerName,
                dayInterval: DateInterval(start: referenceDate, duration: 0),
                totalExpense: 0,
                transactionCount: 0,
                recentTransaction: nil,
                recentDisplayName: nil
            )
        }

        let todayTransactions = activeTransactions
            .filter { transaction in
                transaction.amount > 0 &&
                transaction.occurredAt >= dayInterval.start &&
                transaction.occurredAt < dayInterval.end
            }
            .sorted { lhs, rhs in
                if lhs.occurredAt == rhs.occurredAt {
                    return displayName(for: lhs) < displayName(for: rhs)
                }
                return lhs.occurredAt > rhs.occurredAt
            }

        let total = todayTransactions.reduce(0) { $0 + $1.amount }
        let recent = todayTransactions.first

        return TodaySpendingSummary(
            ledgerID: ledgerID,
            ledgerName: ledgerName,
            dayInterval: dayInterval,
            totalExpense: total,
            transactionCount: todayTransactions.count,
            recentTransaction: recent,
            recentDisplayName: recent.map(displayName(for:))
        )
    }

    private static func displayName(for transaction: Transaction) -> String {
        let merchant = transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if !merchant.isEmpty {
            return merchant
        }

        let category = transaction.categoryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !category.isEmpty {
            return category
        }

        let source = transaction.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty {
            return source
        }

        return "待确认"
    }
}
