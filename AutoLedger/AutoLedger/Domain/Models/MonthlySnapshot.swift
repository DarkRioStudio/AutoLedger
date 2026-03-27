import Foundation

struct MonthlySnapshot {
    struct CategoryMetric: Identifiable {
        let id = UUID()
        let category: TransactionCategory
        let total: Double
        let ratio: Double
    }

    let monthLabel: String
    let totalExpense: Double
    let transactionCount: Int
    let topMerchant: String
    let categoryBreakdown: [CategoryMetric]

    static func build(from transactions: [Transaction], referenceDate: Date) -> MonthlySnapshot {
        let monthTransactions = transactions.filter {
            AppFormatters.calendar.isDate($0.occurredAt, equalTo: referenceDate, toGranularity: .month) &&
            AppFormatters.calendar.isDate($0.occurredAt, equalTo: referenceDate, toGranularity: .year)
        }

        let total = monthTransactions.reduce(0) { $0 + $1.amount }
        let merchant = Dictionary(grouping: monthTransactions, by: \.merchant)
            .mapValues { entries in entries.reduce(0) { $0 + $1.amount } }
            .max { $0.value < $1.value }?
            .key ?? "暂无"

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
            topMerchant: merchant,
            categoryBreakdown: categoryTotals
        )
    }
}
