import AutoLedgerCore
import Foundation

struct AnomalyAlert: Identifiable, Sendable {
    let id: String
    let categoryID: String
    let categoryTitle: String
    let currentTotal: Double
    let baselineAverage: Double
    let ratio: Double
    let thresholdPercent: Double

    var ratioPercent: Int {
        Int((ratio * 100).rounded())
    }
}

struct MonthlyInsightService: Sendable {
    func detectAnomalies(
        transactions: [Transaction],
        referenceDate: Date = .now,
        thresholdPercent: Double
    ) -> [AnomalyAlert] {
        guard
            let currentMonth = AppFormatters.calendar.dateInterval(of: .month, for: referenceDate),
            thresholdPercent > 0
        else {
            return []
        }

        let currentTransactions = transactions.filter { currentMonth.contains($0.occurredAt) }
        let currentTotals = categoryTotals(for: currentTransactions)
        guard !currentTotals.isEmpty else { return [] }

        let baselineTotals = previousMonthCategoryTotals(
            transactions: transactions,
            currentMonthStart: currentMonth.start,
            monthCount: 3
        )

        let thresholdMultiplier = thresholdPercent / 100

        return currentTotals.compactMap { categoryID, currentTotal in
            guard let monthlyTotals = baselineTotals[categoryID],
                  monthlyTotals.contains(where: { $0 > 0 })
            else {
                return nil
            }

            let baselineAverage = monthlyTotals.reduce(0, +) / Double(monthlyTotals.count)
            guard baselineAverage > 0 else { return nil }

            let ratio = currentTotal / baselineAverage
            guard ratio >= thresholdMultiplier else { return nil }

            let builtInCategory = TransactionCategory(rawValue: categoryID)
            let categoryTitle = builtInCategory?.title
                ?? currentTransactions.first(where: { $0.category == categoryID })?.categoryTitle
                ?? categoryID

            return AnomalyAlert(
                id: categoryID,
                categoryID: categoryID,
                categoryTitle: categoryTitle,
                currentTotal: currentTotal,
                baselineAverage: baselineAverage,
                ratio: ratio,
                thresholdPercent: thresholdPercent
            )
        }
        .sorted { lhs, rhs in
            if lhs.ratio == rhs.ratio {
                return lhs.currentTotal > rhs.currentTotal
            }
            return lhs.ratio > rhs.ratio
        }
    }

    private func previousMonthCategoryTotals(
        transactions: [Transaction],
        currentMonthStart: Date,
        monthCount: Int
    ) -> [String: [Double]] {
        let monthIntervals = (1...monthCount).compactMap { offset -> DateInterval? in
            guard let monthStart = AppFormatters.calendar.date(byAdding: .month, value: -offset, to: currentMonthStart) else {
                return nil
            }
            return AppFormatters.calendar.dateInterval(of: .month, for: monthStart)
        }

        var totals: [String: [Double]] = [:]

        for (index, interval) in monthIntervals.enumerated() {
            let entries = transactions.filter { interval.contains($0.occurredAt) }
            for (categoryID, total) in categoryTotals(for: entries) {
                var categoryTotals = totals[categoryID] ?? Array(repeating: 0, count: monthIntervals.count)
                categoryTotals[index] = total
                totals[categoryID] = categoryTotals
            }
        }

        return totals
    }

    private func categoryTotals(for transactions: [Transaction]) -> [String: Double] {
        Dictionary(grouping: transactions, by: \.category)
            .mapValues { entries in entries.reduce(0) { $0 + $1.amount } }
    }
}
