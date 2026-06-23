//
//  ContentView.swift
//  AutoLedgerTV
//
//  Created by 张津铖 on 2026/6/4.
//

import AutoLedgerCore
import CloudKit
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

            VStack(spacing: 22) {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 88)
            .padding(.top, 72)
            .padding(.bottom, 46)
        }
        .onAppear {
            store.load()
        }
        .onMoveCommand { direction in
            moveSelection(direction)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("AutoLedger")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Text("家庭大屏只读账本")
                    .font(.system(size: 50, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                privacyMode.toggle()
            } label: {
                Label(privacyMode ? "显示金额" : "隐藏金额", systemImage: privacyMode ? "eye.slash.fill" : "eye.fill")
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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 16)
                    .background(.white.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.24), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func dashboard(_ snapshot: TVLedgerDashboardSnapshot) -> some View {
        Group {
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
        .frame(
            maxWidth: .infinity,
            minHeight: TVDashboardLayout.contentHeight,
            maxHeight: TVDashboardLayout.contentHeight,
            alignment: .topLeading
        )
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        let pages = TVDashboardPage.allCases
        guard let currentIndex = pages.firstIndex(of: selectedPage) else { return }

        switch direction {
        case .left:
            selectedPage = pages[max(currentIndex - 1, pages.startIndex)]
        case .right:
            selectedPage = pages[min(currentIndex + 1, pages.index(before: pages.endIndex))]
        default:
            break
        }
    }
}

private enum TVDashboardPage: String, CaseIterable, Hashable, Identifiable {
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

private enum TVDashboardLayout {
    static let contentHeight: CGFloat = 704
    static let columnSpacing: CGFloat = 28
    static let rowSpacing: CGFloat = 22
    static let rightColumnWidth: CGFloat = 560
    static let overviewTopRightHeight: CGFloat = 330
    static let overviewRecentHeight: CGFloat = contentHeight - overviewTopRightHeight - rowSpacing
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
        var diagnostics: [String] = []

        do {
            let accountStatus = try await TVDashboardCloudDiagnostics.accountStatusDescription()
            diagnostics.append("iCloud 账号：\(accountStatus)")
        } catch {
            diagnostics.append("iCloud 账号检查失败：\(TVDashboardCloudDiagnostics.describe(error))")
        }

        do {
            if let snapshot = try await TVDashboardCloudSnapshotClient.fetchSnapshot() {
                let transactions = sortForDashboard(snapshot.displayTransactions)
                diagnostics.append("大屏快照读取成功：\(transactions.count) 条。")
                return transactions
            }
            diagnostics.append("大屏快照不存在：等待 iPhone / iPad / Mac 完成一次 iCloud 同步并发布快照。")
        } catch {
            diagnostics.append("大屏快照读取失败：\(TVDashboardCloudDiagnostics.describe(error))")
        }

        do {
            let cloudTransactions = sortForDashboard(try await TVDashboardCloudTransactionClient.fetchTransactions())
            diagnostics.append("远端账本兜底读取：\(cloudTransactions.count) 条。")
            if !cloudTransactions.isEmpty {
                return cloudTransactions
            }
        } catch {
            diagnostics.append("远端账本兜底读取失败：\(TVDashboardCloudDiagnostics.describe(error))")
        }

        #if DEBUG
        #if targetEnvironment(simulator)
        return TVDashboardSimulatorData.transactions(referenceDate: Date())
        #endif
        #endif

        throw TVDashboardCloudDataUnavailable(diagnostics: diagnostics)
    }

    nonisolated private static func sortForDashboard(_ transactions: [LedgerTransaction]) -> [LedgerTransaction] {
        transactions
            .filter { $0.amount > 0 }
            .sorted { lhs, rhs in
                if lhs.occurredAt == rhs.occurredAt {
                    return lhs.merchant < rhs.merchant
                }
                return lhs.occurredAt > rhs.occurredAt
            }
    }
}

private enum TVDashboardSimulatorData {
    static func transactions(referenceDate: Date) -> [LedgerTransaction] {
        let calendar = Calendar.autoupdatingCurrent
        let specs: [(String, Double, Int, String, String)] = [
            ("Demo Coffee", 18.00, 0, "餐饮", "截图识别"),
            ("Example Market", 86.50, 0, "购物", "剪贴板"),
            ("地铁：Example Station → Example Airport", 4.00, 1, "出行", "快捷指令"),
            ("Sample Cinema", 45.00, 2, "娱乐", "手动录入"),
            ("Sample Books", 39.00, 4, "学习", "截图识别"),
            ("Mobile Carrier", 50.00, 8, "通讯", "自动导入"),
            ("Lunch Bistro", 28.00, 12, "餐饮", "语音记账"),
            ("Takeout Sample", 32.00, 16, "餐饮", "分享导入")
        ]

        return specs.enumerated().map { index, spec in
            LedgerTransaction(
                id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1)) ?? UUID(),
                merchant: spec.0,
                amount: spec.1,
                occurredAt: calendar.date(byAdding: .day, value: -spec.2, to: referenceDate) ?? referenceDate,
                categoryLabel: spec.3,
                sourceLabel: spec.4,
                note: "tvOS 模拟器演示数据"
            )
        }
    }
}

private struct TVDashboardCloudDataUnavailable: LocalizedError {
    let diagnostics: [String]

    var errorDescription: String? {
        diagnostics.joined(separator: "\n")
    }
}

private enum TVDashboardCloudDiagnostics {
    nonisolated static func accountStatusDescription() async throws -> String {
        switch try await CKContainer.default().accountStatus() {
        case .available:
            return "可用"
        case .couldNotDetermine:
            return "无法确定，请确认 Apple TV 模拟器已登录 iCloud。"
        case .noAccount:
            return "未登录，请在 Apple TV 模拟器设置里登录同一个 Apple ID。"
        case .restricted:
            return "受限，当前账号或设备限制了 iCloud。"
        case .temporarilyUnavailable:
            return "暂时不可用，稍后重试。"
        @unknown default:
            return "未知状态"
        }
    }

    nonisolated static func describe(_ error: Error) -> String {
        if let ckError = error as? CKError {
            return "CKError \(ckError.errorCode) (\(ckError.code))：\(ckError.localizedDescription)"
        }
        return error.localizedDescription
    }
}

private enum TVDashboardCloudTransactionClient {
    static func fetchTransactions() async throws -> [LedgerTransaction] {
        let desiredKeys = [
            CloudLedgerSyncSchema.Field.transactionID,
            CloudLedgerSyncSchema.Field.merchant,
            CloudLedgerSyncSchema.Field.amount,
            CloudLedgerSyncSchema.Field.occurredAt,
            CloudLedgerSyncSchema.Field.category,
            CloudLedgerSyncSchema.Field.source,
            CloudLedgerSyncSchema.Field.note,
            CloudLedgerSyncSchema.Field.deletedAt
        ]
        let query = CKQuery(
            recordType: CloudLedgerSyncSchema.RecordType.transaction,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [
            NSSortDescriptor(key: CloudLedgerSyncSchema.Field.occurredAt, ascending: false)
        ]

        var records: [CKRecord] = []
        let database = CKContainer.default().privateCloudDatabase
        let firstPage = try await database.records(
            matching: query,
            desiredKeys: desiredKeys,
            resultsLimit: 500
        )
        records.append(contentsOf: decodedRecords(from: firstPage.matchResults))

        var cursor = firstPage.queryCursor
        while let currentCursor = cursor {
            let page = try await database.records(
                continuingMatchFrom: currentCursor,
                desiredKeys: desiredKeys,
                resultsLimit: 500
            )
            records.append(contentsOf: decodedRecords(from: page.matchResults))
            cursor = page.queryCursor
        }

        return records.compactMap(transaction(from:))
    }

    private static func decodedRecords(
        from results: [(CKRecord.ID, Result<CKRecord, Error>)]
    ) -> [CKRecord] {
        results.compactMap { _, result in
            try? result.get()
        }
    }

    private static func transaction(from record: CKRecord) -> LedgerTransaction? {
        guard
            record[CloudLedgerSyncSchema.Field.deletedAt] == nil,
            let transactionIDString = record[CloudLedgerSyncSchema.Field.transactionID] as? String,
            let transactionID = UUID(uuidString: transactionIDString),
            let merchant = record[CloudLedgerSyncSchema.Field.merchant] as? String,
            let amountNumber = record[CloudLedgerSyncSchema.Field.amount] as? NSNumber,
            let occurredAt = record[CloudLedgerSyncSchema.Field.occurredAt] as? Date
        else {
            return nil
        }

        return LedgerTransaction(
            id: transactionID,
            merchant: merchant,
            amount: amountNumber.doubleValue,
            occurredAt: occurredAt,
            categoryLabel: (record[CloudLedgerSyncSchema.Field.category] as? String) ?? "其他",
            sourceLabel: (record[CloudLedgerSyncSchema.Field.source] as? String) ?? "iCloud",
            note: (record[CloudLedgerSyncSchema.Field.note] as? String) ?? ""
        )
    }
}

private enum TVDashboardCloudSnapshotClient {
    static func fetchSnapshot() async throws -> LedgerDashboardCloudSnapshot? {
        let recordID = CKRecord.ID(recordName: CloudLedgerSyncSchema.dashboardSnapshotRecordName())

        do {
            let record = try await CKContainer.default().privateCloudDatabase.record(for: recordID)
            guard
                let json = record[CloudLedgerSyncSchema.Field.payloadJSON] as? String,
                let data = json.data(using: .utf8)
            else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(LedgerDashboardCloudSnapshot.self, from: data)
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .unknownItem {
                return nil
            }
            throw error
        }
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
    @FocusState private var focusedPage: TVDashboardPage?

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
                .focused($focusedPage, equals: page)
                .buttonStyle(TVTabButtonStyle(
                    isSelected: selectedPage == page,
                    isFocused: focusedPage == page
                ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            focusedPage = selectedPage
        }
        .onChange(of: selectedPage) { _, newValue in
            focusedPage = newValue
        }
    }
}

private struct TVOverviewPage: View {
    let snapshot: TVLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        HStack(spacing: TVDashboardLayout.columnSpacing) {
            VStack(alignment: .leading, spacing: 20) {
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
                .frame(height: 250)

                HStack(spacing: 22) {
                    TVMetricCard(title: "今日支出", value: privacyMode ? "***" : TVFormatters.currency(snapshot.todaySummary.totalExpense), iconName: "sun.max.fill", tint: .yellow)
                    TVMetricCard(title: "本月笔数", value: "\(snapshot.monthlySnapshot.transactionCount)", iconName: "list.bullet.rectangle.fill", tint: .cyan)
                    TVMetricCard(title: "日均支出", value: privacyMode ? "***" : TVFormatters.currency(snapshot.averageDailyExpense), iconName: "calendar", tint: .green)
                }
                .frame(height: 220)

                Spacer(minLength: 0)
            }

            VStack(spacing: TVDashboardLayout.rowSpacing) {
                TVTopCategoryPanel(snapshot: snapshot, privacyMode: privacyMode)
                    .frame(height: TVDashboardLayout.overviewTopRightHeight)
                TVRecentPanel(transactions: snapshot.recentTransactions, privacyMode: privacyMode)
                    .frame(height: TVDashboardLayout.overviewRecentHeight)
            }
            .frame(width: TVDashboardLayout.rightColumnWidth)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: TVDashboardLayout.contentHeight,
            maxHeight: TVDashboardLayout.contentHeight,
            alignment: .topLeading
        )
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
        HStack(spacing: TVDashboardLayout.columnSpacing) {
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

            VStack(spacing: TVDashboardLayout.rowSpacing) {
                TVMetricCard(title: "Top 分类", value: snapshot.monthlySnapshot.categoryBreakdown.first?.title ?? "暂无", iconName: "chart.pie.fill", tint: .orange)
                TVMetricCard(title: "分类数量", value: "\(snapshot.monthlySnapshot.categoryBreakdown.count)", iconName: "square.grid.2x2.fill", tint: .green)
                TVMetricCard(title: "本月总额", value: privacyMode ? "***" : TVFormatters.currency(snapshot.monthlySnapshot.totalExpense), iconName: "yensign.circle.fill", tint: .cyan)
            }
            .frame(width: TVDashboardLayout.rightColumnWidth)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: TVDashboardLayout.contentHeight,
            maxHeight: TVDashboardLayout.contentHeight,
            alignment: .topLeading
        )
    }
}

private struct TVTrendPage: View {
    let snapshot: TVLedgerDashboardSnapshot
    let privacyMode: Bool

    private var maxMonthTotal: Double {
        max(snapshot.monthlySnapshot.monthlyTrend.map(\.total).max() ?? 0, 1)
    }

    var body: some View {
        HStack(spacing: TVDashboardLayout.columnSpacing) {
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
            .frame(width: TVDashboardLayout.rightColumnWidth)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: TVDashboardLayout.contentHeight,
            maxHeight: TVDashboardLayout.contentHeight,
            alignment: .topLeading
        )
    }
}

private struct TVSummaryPage: View {
    let snapshot: TVLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        HStack(spacing: TVDashboardLayout.columnSpacing) {
            VStack(spacing: TVDashboardLayout.rowSpacing) {
                TVMetricCard(title: "年度累计", value: privacyMode ? "***" : TVFormatters.currency(snapshot.yearlyTotal), iconName: "sparkles", tint: .yellow)
                TVMetricCard(title: "本月累计", value: privacyMode ? "***" : TVFormatters.currency(snapshot.monthlySnapshot.totalExpense), iconName: "calendar.badge.clock", tint: .green)
                TVMetricCard(title: "Top 商户", value: privacyMode ? "已隐藏" : snapshot.monthlySnapshot.topMerchant, iconName: "storefront.fill", tint: .orange)
            }
            .frame(width: TVDashboardLayout.rightColumnWidth)

            TVTopMerchantPanel(snapshot: snapshot, privacyMode: privacyMode)
            TVRecentPanel(transactions: snapshot.recentTransactions, privacyMode: privacyMode)
                .frame(width: TVDashboardLayout.rightColumnWidth)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: TVDashboardLayout.contentHeight,
            maxHeight: TVDashboardLayout.contentHeight,
            alignment: .topLeading
        )
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
                    ForEach(transactions.prefix(4)) { transaction in
                        HStack(spacing: 16) {
                            Image(systemName: transaction.categoryEnum.iconName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.green)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(transaction.merchant.isEmpty ? transaction.categoryTitle : transaction.merchant)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundStyle(.white)
                                Text(TVFormatters.shortDate.string(from: transaction.occurredAt))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.48))
                            }
                            Spacer()
                            Text(TVFormatters.currency(transaction.amount))
                                .font(.system(size: 24, weight: .black, design: .rounded))
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
        .frame(height: 220)
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
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .black : .white)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isFocused ? Color.green : Color.white.opacity(0.18), lineWidth: isFocused ? 4 : 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.05 : 1))
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isFocused)
            .animation(.spring(response: 0.18, dampingFraction: 0.85), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isSelected {
            return .white
        }
        if isFocused {
            return Color.white.opacity(isPressed ? 0.30 : 0.22)
        }
        return Color.white.opacity(isPressed ? 0.22 : 0.10)
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
