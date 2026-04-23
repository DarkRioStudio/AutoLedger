import Foundation

public struct MonthlySnapshot: Sendable {
    public struct CategoryMetric: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let category: TransactionCategory?
        public let total: Double
        public let ratio: Double

        public var iconName: String {
            category?.iconName ?? "tag.fill"
        }

        public init(id: String, title: String, category: TransactionCategory?, total: Double, ratio: Double) {
            self.id = id
            self.title = title
            self.category = category
            self.total = total
            self.ratio = ratio
        }
    }

    public struct MerchantMetric: Identifiable, Sendable {
        public var id: String { merchant }

        public let merchant: String
        public let total: Double
        public let transactionCount: Int
        public let ratio: Double

        public init(merchant: String, total: Double, transactionCount: Int, ratio: Double) {
            self.merchant = merchant
            self.total = total
            self.transactionCount = transactionCount
            self.ratio = ratio
        }
    }

    public struct MonthlyTrendMetric: Identifiable, Sendable {
        public var id: Date { monthStart }

        public let monthStart: Date
        public let label: String
        public let total: Double
        public let transactionCount: Int
        public let isCurrentMonth: Bool

        public init(monthStart: Date, label: String, total: Double, transactionCount: Int, isCurrentMonth: Bool) {
            self.monthStart = monthStart
            self.label = label
            self.total = total
            self.transactionCount = transactionCount
            self.isCurrentMonth = isCurrentMonth
        }
    }

    public let monthLabel: String
    public let totalExpense: Double
    public let transactionCount: Int
    public let topMerchants: [String]
    public let topMerchantMetrics: [MerchantMetric]
    public let categoryBreakdown: [CategoryMetric]
    public let monthlyTrend: [MonthlyTrendMetric]

    public var topMerchant: String { topMerchants.first ?? "暂无" }
    public var topMerchantMetric: MerchantMetric? { topMerchantMetrics.first }

    public init(
        monthLabel: String,
        totalExpense: Double,
        transactionCount: Int,
        topMerchants: [String],
        topMerchantMetrics: [MerchantMetric],
        categoryBreakdown: [CategoryMetric],
        monthlyTrend: [MonthlyTrendMetric]
    ) {
        self.monthLabel = monthLabel
        self.totalExpense = totalExpense
        self.transactionCount = transactionCount
        self.topMerchants = topMerchants
        self.topMerchantMetrics = topMerchantMetrics
        self.categoryBreakdown = categoryBreakdown
        self.monthlyTrend = monthlyTrend
    }

    public static func build(from transactions: [Transaction], referenceDate: Date) -> MonthlySnapshot {
        let monthTransactions = transactions.filter {
            AppFormatters.calendar.isDate($0.occurredAt, equalTo: referenceDate, toGranularity: .month) &&
            AppFormatters.calendar.isDate($0.occurredAt, equalTo: referenceDate, toGranularity: .year)
        }

        let total = monthTransactions.reduce(0) { $0 + $1.amount }
        let merchantMetrics = Dictionary(grouping: monthTransactions, by: \.merchant)
            .map { merchant, entries in
                let merchantTotal = entries.reduce(0) { $0 + $1.amount }
                return MerchantMetric(
                    merchant: merchant,
                    total: merchantTotal,
                    transactionCount: entries.count,
                    ratio: total > 0 ? merchantTotal / total : 0
                )
            }
            .sorted(by: { lhs, rhs in
                if lhs.total == rhs.total {
                    return lhs.merchant < rhs.merchant
                }
                return lhs.total > rhs.total
            })

        let categoryTotals = Dictionary(grouping: monthTransactions, by: \.category)
            .map { categoryID, entries in
                let categoryTotal = entries.reduce(0) { $0 + $1.amount }
                let builtInCategory = TransactionCategory(rawValue: categoryID)
                return CategoryMetric(
                    id: categoryID,
                    title: builtInCategory?.title ?? entries.first?.categoryTitle ?? categoryID,
                    category: builtInCategory,
                    total: categoryTotal,
                    ratio: total > 0 ? categoryTotal / total : 0
                )
            }
            .sorted(by: { lhs, rhs in
                if lhs.total == rhs.total {
                    return lhs.title < rhs.title
                }
                return lhs.total > rhs.total
            })

        let trendMetrics = buildMonthlyTrend(from: transactions, referenceDate: referenceDate)

        return MonthlySnapshot(
            monthLabel: AppFormatters.month(referenceDate),
            totalExpense: total,
            transactionCount: monthTransactions.count,
            topMerchants: merchantMetrics.map(\.merchant),
            topMerchantMetrics: merchantMetrics,
            categoryBreakdown: categoryTotals,
            monthlyTrend: trendMetrics
        )
    }

    private static func buildMonthlyTrend(from transactions: [Transaction], referenceDate: Date) -> [MonthlyTrendMetric] {
        guard let currentMonthStart = AppFormatters.calendar.dateInterval(of: .month, for: referenceDate)?.start else {
            return []
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"

        return (0..<6).reversed().compactMap { offset in
            guard
                let monthStart = AppFormatters.calendar.date(byAdding: .month, value: -offset, to: currentMonthStart),
                let monthInterval = AppFormatters.calendar.dateInterval(of: .month, for: monthStart)
            else {
                return nil
            }

            let entries = transactions.filter {
                monthInterval.contains($0.occurredAt)
            }
            let total = entries.reduce(0) { $0 + $1.amount }

            return MonthlyTrendMetric(
                monthStart: monthStart,
                label: formatter.string(from: monthStart),
                total: total,
                transactionCount: entries.count,
                isCurrentMonth: AppFormatters.calendar.isDate(monthStart, equalTo: currentMonthStart, toGranularity: .month)
            )
        }
    }
}
