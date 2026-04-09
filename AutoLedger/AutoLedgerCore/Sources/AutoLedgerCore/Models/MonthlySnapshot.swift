import Foundation

public struct MonthlySnapshot: Sendable {
    public struct CategoryMetric: Identifiable, Sendable {
        public let id = UUID()
        public let category: TransactionCategory
        public let total: Double
        public let ratio: Double

        public init(category: TransactionCategory, total: Double, ratio: Double) {
            self.category = category
            self.total = total
            self.ratio = ratio
        }
    }

    public let monthLabel: String
    public let totalExpense: Double
    public let transactionCount: Int
    public let topMerchants: [String]
    public let categoryBreakdown: [CategoryMetric]

    public var topMerchant: String { topMerchants.first ?? "暂无" }

    public init(
        monthLabel: String,
        totalExpense: Double,
        transactionCount: Int,
        topMerchants: [String],
        categoryBreakdown: [CategoryMetric]
    ) {
        self.monthLabel = monthLabel
        self.totalExpense = totalExpense
        self.transactionCount = transactionCount
        self.topMerchants = topMerchants
        self.categoryBreakdown = categoryBreakdown
    }

    public static func build(from transactions: [Transaction], referenceDate: Date) -> MonthlySnapshot {
        let monthTransactions = transactions.filter {
            AppFormatters.calendar.isDate($0.occurredAt, equalTo: referenceDate, toGranularity: .month) &&
            AppFormatters.calendar.isDate($0.occurredAt, equalTo: referenceDate, toGranularity: .year)
        }

        let total = monthTransactions.reduce(0) { $0 + $1.amount }
        let merchantRanking = Dictionary(grouping: monthTransactions, by: \.merchant)
            .mapValues { entries in entries.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }
            .map { $0.key }

        let categoryTotals = Dictionary(grouping: monthTransactions, by: \.category)
            .mapValues { entries in entries.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }
            .map {
                CategoryMetric(
                    category: $0.key,
                    total: $0.value,
                    ratio: total > 0 ? $0.value / total : 0
                )
            }

        return MonthlySnapshot(
            monthLabel: AppFormatters.month(referenceDate),
            totalExpense: total,
            transactionCount: monthTransactions.count,
            topMerchants: merchantRanking,
            categoryBreakdown: categoryTotals
        )
    }
}
