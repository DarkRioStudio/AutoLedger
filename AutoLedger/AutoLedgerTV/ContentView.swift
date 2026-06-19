//
//  ContentView.swift
//  AutoLedgerTV
//
//  Created by 张津铖 on 2026/6/4.
//

import AutoLedgerCore
import Combine
import SwiftUI

private typealias LedgerTransaction = AutoLedgerCore.Transaction

struct ContentView: View {
    @StateObject private var store = TVLedgerDashboardStore()
    @State private var selectedPage: TVDashboardPage = .overview
    @State private var privacyMode = false

    var body: some View {
        ZStack {
            TVDashboardTheme.background
                .ignoresSafeArea()

            VStack(spacing: 30) {
                header

                TVDashboardTabs(
                    selectedPage: $selectedPage,
                    pages: TVDashboardPage.allCases
                )

                Group {
                    switch store.state {
                    case .loading:
                        TVLoadingView()
                    case let .unavailable(message):
                        TVUnavailableView(message: message) {
                            store.load()
                        }
                    case let .ready(snapshot):
                        if snapshot.isEmpty {
                            TVEmptyLedgerView(updatedAt: snapshot.generatedAt) {
                                store.load()
                            }
                        } else {
                            dashboard(snapshot)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 76)
            .padding(.vertical, 48)
        }
        .onAppear {
            store.load()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("AutoLedger")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Text("家庭大屏只读账本")
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                privacyMode.toggle()
            } label: {
                Label(privacyMode ? "已隐藏金额" : "标准显示", systemImage: privacyMode ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(privacyMode ? .orange : .green)

            Button {
                store.load()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }

    @ViewBuilder
    private func dashboard(_ snapshot: TVLedgerDashboardSnapshot) -> some View {
        switch selectedPage {
        case .overview:
            TVOverviewPage(snapshot: snapshot, privacyMode: privacyMode)
        case .categories:
            TVCategoryPage(snapshot: snapshot, privacyMode: privacyMode)
        case .trend:
            TVTrendPage(snapshot: snapshot, privacyMode: privacyMode)
        case .summary:
            TVSummaryPage(snapshot: snapshot, privacyMode: privacyMode)
        }
    }
}

private enum TVDashboardPage: String, CaseIterable, Identifiable {
    case overview
    case categories
    case trend
    case summary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "总览"
        case .categories: return "分类"
        case .trend: return "趋势"
        case .summary: return "摘要"
        }
    }

    var iconName: String {
        switch self {
        case .overview: return "rectangle.grid.2x2.fill"
        case .categories: return "chart.pie.fill"
        case .trend: return "chart.xyaxis.line"
        case .summary: return "sparkles.rectangle.stack.fill"
        }
    }
}

@MainActor
private final class TVLedgerDashboardStore: ObservableObject {
    enum LoadState {
        case loading
        case ready(TVLedgerDashboardSnapshot)
        case unavailable(String)
    }

    @Published private(set) var state: LoadState = .loading

    func load() {
        state = .loading

        Task {
            do {
                let transactions = try await Self.loadTransactions()
                let now = Date()
                let snapshot = TVLedgerDashboardSnapshot(
                    transactions: transactions,
                    referenceDate: now,
                    generatedAt: now
                )
                state = .ready(snapshot)
            } catch {
                state = .unavailable(error.localizedDescription)
            }
        }
    }

    nonisolated private static func loadTransactions() async throws -> [LedgerTransaction] {
        try await Task.detached(priority: .userInitiated) {
            let store = try SQLiteTransactionStore()
            return try store.loadTransactions()
                .filter { $0.amount > 0 }
                .sorted { lhs, rhs in
                    if lhs.occurredAt == rhs.occurredAt {
                        return lhs.merchant < rhs.merchant
                    }
                    return lhs.occurredAt > rhs.occurredAt
                }
        }.value
    }
}

private struct TVLedgerDashboardSnapshot: Sendable {
    let generatedAt: Date
    let monthlySnapshot: MonthlySnapshot
    let todaySummary: TodaySpendingSummary
    let previousMonthTotal: Double
    let yearlyTotal: Double
    let recentTransactions: [LedgerTransaction]
    let dailyTrend: [TVDailyMetric]

    var isEmpty: Bool {
        monthlySnapshot.transactionCount == 0 && recentTransactions.isEmpty
    }

    var monthOverMonthDelta: Double {
        monthlySnapshot.totalExpense - previousMonthTotal
    }

    var averageDailyExpense: Double {
        let day = Calendar.autoupdatingCurrent.component(.day, from: generatedAt)
        return day > 0 ? monthlySnapshot.totalExpense / Double(day) : 0
    }

    init(transactions: [LedgerTransaction], referenceDate: Date, generatedAt: Date) {
        self.generatedAt = generatedAt
        self.monthlySnapshot = MonthlySnapshot.build(from: transactions, referenceDate: referenceDate)
        self.todaySummary = TodaySpendingSummary.build(from: transactions, referenceDate: referenceDate)
        self.previousMonthTotal = Self.totalForPreviousMonth(transactions, referenceDate: referenceDate)
        self.yearlyTotal = Self.totalForCurrentYear(transactions, referenceDate: referenceDate)
        self.recentTransactions = Array(transactions.prefix(6))
        self.dailyTrend = Self.buildDailyTrend(from: transactions, referenceDate: referenceDate)
    }

    private static func totalForPreviousMonth(_ transactions: [LedgerTransaction], referenceDate: Date) -> Double {
        let calendar = Calendar.autoupdatingCurrent
        guard
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: referenceDate),
            let interval = calendar.dateInterval(of: .month, for: previousMonth)
        else {
            return 0
        }

        return transactions
            .filter { interval.contains($0.occurredAt) }
            .reduce(0) { $0 + $1.amount }
    }

    private static func totalForCurrentYear(_ transactions: [LedgerTransaction], referenceDate: Date) -> Double {
        guard let interval = Calendar.autoupdatingCurrent.dateInterval(of: .year, for: referenceDate) else {
            return 0
        }

        return transactions
            .filter { interval.contains($0.occurredAt) }
            .reduce(0) { $0 + $1.amount }
    }

    private static func buildDailyTrend(from transactions: [LedgerTransaction], referenceDate: Date) -> [TVDailyMetric] {
        let calendar = Calendar.autoupdatingCurrent
        let days = (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: referenceDate)
        }
        let totals = days.map { day -> TVDailyMetric in
            guard let interval = calendar.dateInterval(of: .day, for: day) else {
                return TVDailyMetric(date: day, label: TVFormatters.weekday.string(from: day), total: 0)
            }

            let total = transactions
                .filter { interval.contains($0.occurredAt) }
                .reduce(0) { $0 + $1.amount }

            return TVDailyMetric(date: day, label: TVFormatters.weekday.string(from: day), total: total)
        }

        let maxTotal = max(totals.map(\.total).max() ?? 0, 1)
        return totals.map { metric in
            TVDailyMetric(date: metric.date, label: metric.label, total: metric.total, ratio: metric.total / maxTotal)
        }
    }
}

private struct TVDailyMetric: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let label: String
    let total: Double
    let ratio: Double

    init(date: Date, label: String, total: Double, ratio: Double = 0) {
        self.date = date
        self.label = label
        self.total = total
        self.ratio = ratio
    }
}

private struct TVDashboardTabs: View {
    @Binding var selectedPage: TVDashboardPage
    let pages: [TVDashboardPage]

    var body: some View {
        HStack(spacing: 18) {
            ForEach(pages) { page in
                Button {
                    selectedPage = page
                } label: {
                    Label(page.title, systemImage: page.iconName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .frame(width: 220, height: 72)
                }
                .buttonStyle(TVTabButtonStyle(isSelected: selectedPage == page))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TVOverviewPage: View {
    let snapshot: TVLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        HStack(spacing: 26) {
            VStack(alignment: .leading, spacing: 22) {
                TVPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(snapshot.monthlySnapshot.monthLabel)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(privacyMode ? "***" : TVFormatters.currency(snapshot.monthlySnapshot.totalExpense))
                            .font(.system(size: 86, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(.white)
                        Text(monthDeltaText)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(snapshot.monthOverMonthDelta > 0 ? .orange : .green)
                    }
                }
                .frame(height: 280)

                HStack(spacing: 22) {
                    TVMetricCard(title: "今日支出", value: privacyMode ? "***" : TVFormatters.currency(snapshot.todaySummary.totalExpense), iconName: "sun.max.fill", tint: .yellow)
                    TVMetricCard(title: "本月笔数", value: "\(snapshot.monthlySnapshot.transactionCount)", iconName: "list.bullet.rectangle.fill", tint: .cyan)
                    TVMetricCard(title: "日均支出", value: privacyMode ? "***" : TVFormatters.currency(snapshot.averageDailyExpense), iconName: "calendar", tint: .green)
                }
            }

            VStack(spacing: 22) {
                TVTopCategoryPanel(snapshot: snapshot, privacyMode: privacyMode)
                TVRecentPanel(transactions: snapshot.recentTransactions, privacyMode: privacyMode)
            }
            .frame(width: 560)
        }
    }

    private var monthDeltaText: String {
        let delta = snapshot.monthOverMonthDelta
        if abs(delta) < 0.01 {
            return "与上月基本持平"
        }
        let prefix = delta > 0 ? "较上月多 " : "较上月少 "
        return prefix + TVFormatters.currency(abs(delta))
    }
}

private struct TVCategoryPage: View {
    let snapshot: TVLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        HStack(spacing: 28) {
            TVPanel {
                VStack(alignment: .leading, spacing: 24) {
                    Text("本月分类占比")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("按正式账单金额排序，最多展示前 6 类。")
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))

                    VStack(spacing: 18) {
                        ForEach(Array(snapshot.monthlySnapshot.categoryBreakdown.prefix(6).enumerated()), id: \.element.id) { index, metric in
                            TVCategoryBarRow(
                                rank: index + 1,
                                metric: metric,
                                value: privacyMode ? "***" : TVFormatters.currency(metric.total)
                            )
                        }
                    }
                    Spacer()
                }
            }

            VStack(spacing: 22) {
                TVMetricCard(title: "Top 分类", value: snapshot.monthlySnapshot.categoryBreakdown.first?.title ?? "暂无", iconName: "chart.pie.fill", tint: .orange)
                TVMetricCard(title: "分类数量", value: "\(snapshot.monthlySnapshot.categoryBreakdown.count)", iconName: "square.grid.2x2.fill", tint: .green)
                TVMetricCard(title: "本月总额", value: privacyMode ? "***" : TVFormatters.currency(snapshot.monthlySnapshot.totalExpense), iconName: "yensign.circle.fill", tint: .cyan)
            }
            .frame(width: 430)
        }
    }
}

private struct TVTrendPage: View {
    let snapshot: TVLedgerDashboardSnapshot
    let privacyMode: Bool

    private var maxMonthTotal: Double {
        max(snapshot.monthlySnapshot.monthlyTrend.map(\.total).max() ?? 0, 1)
    }

    var body: some View {
        HStack(spacing: 28) {
            TVPanel {
                VStack(alignment: .leading, spacing: 24) {
                    Text("最近 7 天趋势")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("只读展示正式账单，不包含候选账单和调试记录。")
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))

                    HStack(alignment: .bottom, spacing: 18) {
                        ForEach(snapshot.dailyTrend) { metric in
                            TVTrendColumn(metric: metric, privacyMode: privacyMode)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }

            TVPanel {
                VStack(alignment: .leading, spacing: 24) {
                    Text("近 6 个月")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    ForEach(snapshot.monthlySnapshot.monthlyTrend) { metric in
                        TVMonthlyTrendRow(metric: metric, maxTotal: maxMonthTotal, privacyMode: privacyMode)
                    }
                    Spacer()
                }
            }
            .frame(width: 470)
        }
    }
}

private struct TVSummaryPage: View {
    let snapshot: TVLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        HStack(spacing: 28) {
            VStack(spacing: 22) {
                TVMetricCard(title: "年度累计", value: privacyMode ? "***" : TVFormatters.currency(snapshot.yearlyTotal), iconName: "sparkles", tint: .yellow)
                TVMetricCard(title: "本月累计", value: privacyMode ? "***" : TVFormatters.currency(snapshot.monthlySnapshot.totalExpense), iconName: "calendar.badge.clock", tint: .green)
                TVMetricCard(title: "Top 商户", value: privacyMode ? "已隐藏" : snapshot.monthlySnapshot.topMerchant, iconName: "storefront.fill", tint: .orange)
            }
            .frame(width: 430)

            TVTopMerchantPanel(snapshot: snapshot, privacyMode: privacyMode)
            TVRecentPanel(transactions: snapshot.recentTransactions, privacyMode: privacyMode)
                .frame(width: 470)
        }
    }
}

private struct TVTopCategoryPanel: View {
    let snapshot: TVLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        TVPanel {
            VStack(alignment: .leading, spacing: 18) {
                Text("分类结构")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if snapshot.monthlySnapshot.categoryBreakdown.isEmpty {
                    TVMutedText("暂无分类数据")
                } else {
                    ForEach(snapshot.monthlySnapshot.categoryBreakdown.prefix(4)) { metric in
                        TVCategoryBarRow(
                            rank: nil,
                            metric: metric,
                            value: privacyMode ? "***" : TVFormatters.currency(metric.total)
                        )
                    }
                }
            }
        }
    }
}

private struct TVTopMerchantPanel: View {
    let snapshot: TVLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        TVPanel {
            VStack(alignment: .leading, spacing: 20) {
                Text("常用商户")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if snapshot.monthlySnapshot.topMerchantMetrics.isEmpty || privacyMode {
                    TVMutedText(privacyMode ? "商户信息已隐藏" : "暂无商户数据")
                } else {
                    ForEach(Array(snapshot.monthlySnapshot.topMerchantMetrics.prefix(6).enumerated()), id: \.element.id) { index, metric in
                        HStack(spacing: 16) {
                            Text("\(index + 1)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(metric.merchant)
                                    .font(.system(size: 27, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundStyle(.white)
                                Text("\(metric.transactionCount) 笔")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Text(TVFormatters.currency(metric.total))
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()
            }
        }
    }
}

private struct TVRecentPanel: View {
    let transactions: [LedgerTransaction]
    let privacyMode: Bool

    var body: some View {
        TVPanel {
            VStack(alignment: .leading, spacing: 18) {
                Text("最近账单")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if transactions.isEmpty || privacyMode {
                    TVMutedText(privacyMode ? "最近账单已隐藏" : "暂无最近账单")
                } else {
                    ForEach(transactions.prefix(5)) { transaction in
                        HStack(spacing: 16) {
                            Image(systemName: transaction.categoryEnum.iconName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.green)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(transaction.merchant.isEmpty ? transaction.categoryTitle : transaction.merchant)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundStyle(.white)
                                Text(TVFormatters.shortDate.string(from: transaction.occurredAt))
                                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.48))
                            }
                            Spacer()
                            Text(TVFormatters.currency(transaction.amount))
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }
}

private struct TVMetricCard: View {
    let title: String
    let value: String
    let iconName: String
    let tint: Color

    var body: some View {
        TVPanel {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                Text(value)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 190)
    }
}

private struct TVCategoryBarRow: View {
    let rank: Int?
    let metric: MonthlySnapshot.CategoryMetric
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                if let rank {
                    Text("\(rank)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 32)
                }

                Label(metric.title, systemImage: metric.iconName)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.green)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.10))
                    Capsule()
                        .fill(TVDashboardTheme.metricGradient)
                        .frame(width: max(16, proxy.size.width * metric.ratio))
                }
            }
            .frame(height: 12)
        }
    }
}

private struct TVTrendColumn: View {
    let metric: TVDailyMetric
    let privacyMode: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(privacyMode ? "***" : TVFormatters.compactCurrency(metric.total))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(TVDashboardTheme.metricGradient)
                .frame(width: 72, height: max(18, 260 * metric.ratio))
            Text(metric.label)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

private struct TVMonthlyTrendRow: View {
    let metric: MonthlySnapshot.MonthlyTrendMetric
    let maxTotal: Double
    let privacyMode: Bool

    var body: some View {
        HStack(spacing: 16) {
            Text(metric.label)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(metric.isCurrentMonth ? .green : .white.opacity(0.62))
                .frame(width: 72, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(metric.isCurrentMonth ? Color.green.opacity(0.9) : Color.white.opacity(0.20))
                        .frame(width: max(18, proxy.size.width * monthRatio))
                }
                .frame(height: 12)
                Text("\(metric.transactionCount) 笔")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Text(privacyMode ? "***" : TVFormatters.compactCurrency(metric.total))
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 96, alignment: .trailing)
        }
    }

    private var monthRatio: Double {
        min(max(metric.total / max(maxTotal, 1), 0.08), 1)
    }
}

private struct TVLoadingView: View {
    var body: some View {
        VStack(spacing: 22) {
            ProgressView()
                .scaleEffect(1.4)
            Text("正在读取账本快照")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("tvOS 首版只展示正式账本的只读数据。")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

private struct TVEmptyLedgerView: View {
    let updatedAt: Date
    let retry: () -> Void

    var body: some View {
        TVPanel {
            VStack(spacing: 24) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.green)
                Text("等待账本数据")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("当前 Apple TV 本机还没有可展示的正式账单。后续接入 iCloud 只读快照后，这里会显示同步后的月度看板。")
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: 760)
                Text("检查时间 \(TVFormatters.time.string(from: updatedAt))")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Button("重新读取", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: 980, maxHeight: 560)
    }
}

private struct TVUnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        TVPanel {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.orange)
                Text("账本快照不可用")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: 800)
                Button("重试", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: 980, maxHeight: 560)
    }
}

private struct TVPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.white.opacity(0.105))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    )
            )
    }
}

private struct TVMutedText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct TVTabButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .black : .white)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(configuration.isPressed ? 0.22 : 0.10))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private enum TVDashboardTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.07, blue: 0.06),
            Color(red: 0.09, green: 0.16, blue: 0.13),
            Color(red: 0.17, green: 0.12, blue: 0.07)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let metricGradient = LinearGradient(
        colors: [
            Color(red: 0.24, green: 0.74, blue: 0.45),
            Color(red: 0.96, green: 0.67, blue: 0.18),
            Color(red: 0.96, green: 0.28, blue: 0.28)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

private enum TVFormatters {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "E"
        return formatter
    }()

    static func currency(_ value: Double) -> String {
        "¥" + String(format: "%.2f", value)
    }

    static func compactCurrency(_ value: Double) -> String {
        if value >= 10_000 {
            return "¥" + String(format: "%.1f万", value / 10_000)
        }
        if value >= 1_000 {
            return "¥" + String(format: "%.0f", value)
        }
        return currency(value)
    }
}

#Preview {
    ContentView()
}
