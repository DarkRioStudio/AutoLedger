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
        guard let selectedMonth = AppFormatters.calendar.dateInterval(of: .month, for: referenceDate) else {
            return MonthlySnapshot(
                monthLabel: AppFormatters.month(referenceDate),
                totalExpense: 0,
                transactionCount: 0,
                topMerchants: [],
                topMerchantMetrics: [],
                categoryBreakdown: [],
                monthlyTrend: []
            )
        }

        let trendMonths = buildTrendMonths(referenceDate: referenceDate)
        let trendMonthStarts = Set(trendMonths.map(\.monthStart))
        var monthTransactions: [Transaction] = []
        var trendTotals: [Date: (total: Double, count: Int)] = [:]

        for transaction in transactions {
            if selectedMonth.contains(transaction.occurredAt) {
                monthTransactions.append(transaction)
            }

            guard let transactionMonthStart = AppFormatters.calendar.dateInterval(of: .month, for: transaction.occurredAt)?.start,
                  trendMonthStarts.contains(transactionMonthStart)
            else {
                continue
            }
            let current = trendTotals[transactionMonthStart] ?? (0, 0)
            trendTotals[transactionMonthStart] = (current.total + transaction.amount, current.count + 1)
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

        let trendMetrics = buildMonthlyTrend(from: trendMonths, totals: trendTotals)

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

    private static func buildTrendMonths(referenceDate: Date) -> [(monthStart: Date, isCurrentMonth: Bool)] {
        guard let currentMonthStart = AppFormatters.calendar.dateInterval(of: .month, for: referenceDate)?.start else {
            return []
        }

        return (0..<6).reversed().compactMap { offset in
            guard let monthStart = AppFormatters.calendar.date(byAdding: .month, value: -offset, to: currentMonthStart) else {
                return nil
            }
            return (
                monthStart: monthStart,
                isCurrentMonth: AppFormatters.calendar.isDate(monthStart, equalTo: currentMonthStart, toGranularity: .month)
            )
        }
    }

    private static func buildMonthlyTrend(
        from trendMonths: [(monthStart: Date, isCurrentMonth: Bool)],
        totals: [Date: (total: Double, count: Int)]
    ) -> [MonthlyTrendMetric] {
        return trendMonths.map { month in
            let metric = totals[month.monthStart] ?? (0, 0)
            return MonthlyTrendMetric(
                monthStart: month.monthStart,
                label: AppFormatters.shortMonth(month.monthStart),
                total: metric.total,
                transactionCount: metric.count,
                isCurrentMonth: month.isCurrentMonth
            )
        }
    }
}
