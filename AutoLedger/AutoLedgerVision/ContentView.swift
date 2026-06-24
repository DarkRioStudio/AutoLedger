//
//  ContentView.swift
//  AutoLedgerVision
//
//  Created by 张津铖 on 2026/6/4.
//

import AutoLedgerCore
import CloudKit
import SwiftUI

private typealias LedgerTransaction = AutoLedgerCore.Transaction

struct ContentView: View {
    @State private var loadState: VisionLedgerLoadState = .loading
    @State private var privacyMode = false
    @State private var screenshotScene = VisionScreenshotScene.current

    var body: some View {
        ZStack {
            VisionDashboardTheme.background
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header

                        Group {
                            switch loadState {
                            case .loading:
                                VisionLoadingView()
                            case let .unavailable(message):
                                VisionUnavailableView(message: message) {
                                    Task { await load() }
                                }
                            case let .ready(snapshot):
                                if snapshot.isEmpty {
                                    VisionEmptyLedgerView(updatedAt: snapshot.generatedAt) {
                                        Task { await load() }
                                    }
                                } else {
                                    dashboard(snapshot, availableWidth: proxy.size.width - 84)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(42)
                }
            }
        }
        .task {
            await load()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("AutoLedger")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                Text(screenshotScene.title)
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                privacyMode.toggle()
            } label: {
                Label(privacyMode ? "显示金额" : "隐藏金额", systemImage: privacyMode ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(privacyMode ? .orange : .green, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                Task { await load() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.10), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func dashboard(_ snapshot: VisionLedgerDashboardSnapshot, availableWidth: CGFloat) -> some View {
        if availableWidth >= 1320 {
            wideDashboard(snapshot)
        } else {
            compactDashboard(snapshot)
        }
    }

    private func compactDashboard(_ snapshot: VisionLedgerDashboardSnapshot) -> some View {
        VStack(spacing: 28) {
            HStack(alignment: .top, spacing: 28) {
                VisionMonthlyBoard(snapshot: snapshot, privacyMode: privacyMode)
                    .frame(minWidth: 520, maxWidth: .infinity, minHeight: 360)

                VisionCategoryCloud(snapshot: snapshot, privacyMode: privacyMode)
                    .frame(width: 380)
                    .frame(minHeight: 360)
            }

            HStack(alignment: .top, spacing: 28) {
                VisionYearTimelineWall(snapshot: snapshot, privacyMode: privacyMode)
                    .frame(minWidth: 520, maxWidth: .infinity, minHeight: 300)

                VisionRecentRail(snapshot: snapshot, privacyMode: privacyMode)
                    .frame(width: 380)
                    .frame(minHeight: 300)
            }
        }
    }

    private func wideDashboard(_ snapshot: VisionLedgerDashboardSnapshot) -> some View {
        Group {
            switch screenshotScene {
            case .dashboard:
                HStack(alignment: .top, spacing: 28) {
                    monthlyBoard(snapshot)
                    timelineAndRecent(snapshot)
                    categoryCloud(snapshot)
                }
            case .categories:
                HStack(alignment: .top, spacing: 28) {
                    VisionCategoryCloud(snapshot: snapshot, privacyMode: privacyMode)
                        .frame(width: 560)
                        .frame(minHeight: 640)
                        .rotation3DEffect(.degrees(-2.4), axis: (x: 0, y: 1, z: 0), anchor: .trailing)
                        .shadow(color: .black.opacity(0.26), radius: 36, x: 10, y: 24)
                    monthlyBoard(snapshot)
                    VisionRecentRail(snapshot: snapshot, privacyMode: privacyMode)
                        .frame(width: 390)
                        .frame(minHeight: 640)
                        .offset(y: 40)
                        .rotation3DEffect(.degrees(2.6), axis: (x: 0, y: 1, z: 0), anchor: .leading)
                }
            case .timeline:
                HStack(alignment: .top, spacing: 28) {
                    VisionYearTimelineWall(snapshot: snapshot, privacyMode: privacyMode)
                        .frame(minWidth: 620, maxWidth: .infinity, minHeight: 640)
                        .rotation3DEffect(.degrees(-2.0), axis: (x: 0, y: 1, z: 0), anchor: .trailing)
                        .shadow(color: .black.opacity(0.24), radius: 34, x: 10, y: 22)
                    monthlyBoard(snapshot)
                    categoryCloud(snapshot)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 710, alignment: .topLeading)
    }

    private func monthlyBoard(_ snapshot: VisionLedgerDashboardSnapshot) -> some View {
        VisionMonthlyBoard(snapshot: snapshot, privacyMode: privacyMode)
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 640)
            .rotation3DEffect(.degrees(-2.2), axis: (x: 0, y: 1, z: 0), anchor: .trailing)
            .shadow(color: .black.opacity(0.24), radius: 34, x: 10, y: 22)
    }

    private func timelineAndRecent(_ snapshot: VisionLedgerDashboardSnapshot) -> some View {
        VStack(spacing: 24) {
            VisionYearTimelineWall(snapshot: snapshot, privacyMode: privacyMode)
                .frame(height: 306)
                .rotation3DEffect(.degrees(1.4), axis: (x: 0, y: 1, z: 0), anchor: .center)

            VisionRecentRail(snapshot: snapshot, privacyMode: privacyMode)
                .frame(height: 310)
                .rotation3DEffect(.degrees(1.8), axis: (x: 0, y: 1, z: 0), anchor: .leading)
        }
        .frame(width: 430)
        .offset(y: 18)
        .shadow(color: .black.opacity(0.18), radius: 26, x: 0, y: 18)
    }

    private func categoryCloud(_ snapshot: VisionLedgerDashboardSnapshot) -> some View {
        VisionCategoryCloud(snapshot: snapshot, privacyMode: privacyMode)
            .frame(width: 360)
            .frame(minHeight: 640)
            .offset(y: 46)
            .rotation3DEffect(.degrees(3.2), axis: (x: 0, y: 1, z: 0), anchor: .leading)
            .shadow(color: .black.opacity(0.26), radius: 36, x: -8, y: 24)
    }

    @MainActor
    private func load() async {
        loadState = .loading

        do {
            let transactions = try await Self.loadTransactions()
            let now = Date()
            loadState = .ready(
                VisionLedgerDashboardSnapshot(
                    transactions: transactions,
                    referenceDate: now,
                    generatedAt: now
                )
            )
        } catch {
            loadState = .unavailable(error.localizedDescription)
        }
    }

    nonisolated private static func loadTransactions() async throws -> [LedgerTransaction] {
        #if DEBUG
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--screenshot-mode") {
            return sortForDashboard(VisionDashboardSimulatorData.transactions(referenceDate: Date()))
        }
        #endif
        #endif

        if let snapshot = try? await VisionDashboardCloudSnapshotClient.fetchSnapshot() {
            return sortForDashboard(snapshot.displayTransactions)
        }

        #if DEBUG
        #if targetEnvironment(simulator)
        return sortForDashboard(VisionDashboardSimulatorData.transactions(referenceDate: Date()))
        #endif
        #endif

        return []
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

private enum VisionScreenshotScene {
    case dashboard
    case categories
    case timeline

    static var current: VisionScreenshotScene {
        guard
            ProcessInfo.processInfo.arguments.contains("--screenshot-mode"),
            let rawValue = ProcessInfo.processInfo.argumentValue(after: "--screenshot-scene")
        else {
            return .dashboard
        }

        switch rawValue {
        case "categories": return .categories
        case "timeline": return .timeline
        default: return .dashboard
        }
    }

    var title: String {
        switch self {
        case .dashboard: return "月度支出空间看板"
        case .categories: return "分类支出卡片"
        case .timeline: return "年度消费时间线"
        }
    }
}

private extension ProcessInfo {
    func argumentValue(after key: String) -> String? {
        guard let index = arguments.firstIndex(of: key) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }
}

private enum VisionDashboardSimulatorData {
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
                note: "visionOS 模拟器演示数据"
            )
        }
    }
}

private enum VisionDashboardCloudSnapshotClient {
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

private enum VisionLedgerLoadState {
    case loading
    case ready(VisionLedgerDashboardSnapshot)
    case unavailable(String)
}

private struct VisionLedgerDashboardSnapshot {
    let generatedAt: Date
    let monthlySnapshot: MonthlySnapshot
    let todaySummary: TodaySpendingSummary
    let yearlyTotal: Double
    let recentTransactions: [LedgerTransaction]
    let yearTimeline: [VisionMonthMetric]

    var isEmpty: Bool {
        monthlySnapshot.transactionCount == 0 && recentTransactions.isEmpty
    }

    var averageDailyExpense: Double {
        let day = Calendar.autoupdatingCurrent.component(.day, from: generatedAt)
        return day > 0 ? monthlySnapshot.totalExpense / Double(day) : 0
    }

    init(transactions: [LedgerTransaction], referenceDate: Date, generatedAt: Date) {
        self.generatedAt = generatedAt
        self.monthlySnapshot = MonthlySnapshot.build(from: transactions, referenceDate: referenceDate)
        self.todaySummary = TodaySpendingSummary.build(from: transactions, referenceDate: referenceDate)
        self.yearlyTotal = Self.totalForCurrentYear(transactions, referenceDate: referenceDate)
        self.recentTransactions = Array(transactions.prefix(6))
        self.yearTimeline = Self.buildYearTimeline(from: transactions, referenceDate: referenceDate)
    }

    private static func totalForCurrentYear(_ transactions: [LedgerTransaction], referenceDate: Date) -> Double {
        guard let interval = Calendar.autoupdatingCurrent.dateInterval(of: .year, for: referenceDate) else {
            return 0
        }
        return transactions
            .filter { interval.contains($0.occurredAt) }
            .reduce(0) { $0 + $1.amount }
    }

    private static func buildYearTimeline(from transactions: [LedgerTransaction], referenceDate: Date) -> [VisionMonthMetric] {
        let calendar = Calendar.autoupdatingCurrent
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: referenceDate)?.start else {
            return []
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"

        let metrics = (0..<12).reversed().compactMap { offset -> VisionMonthMetric? in
            guard
                let monthStart = calendar.date(byAdding: .month, value: -offset, to: currentMonthStart),
                let interval = calendar.dateInterval(of: .month, for: monthStart)
            else {
                return nil
            }

            let entries = transactions.filter { interval.contains($0.occurredAt) }
            let total = entries.reduce(0) { $0 + $1.amount }
            return VisionMonthMetric(
                monthStart: monthStart,
                label: formatter.string(from: monthStart),
                total: total,
                transactionCount: entries.count,
                isCurrentMonth: calendar.isDate(monthStart, equalTo: currentMonthStart, toGranularity: .month)
            )
        }

        let maxTotal = max(metrics.map(\.total).max() ?? 0, 1)
        return metrics.map { metric in
            VisionMonthMetric(
                monthStart: metric.monthStart,
                label: metric.label,
                total: metric.total,
                transactionCount: metric.transactionCount,
                isCurrentMonth: metric.isCurrentMonth,
                ratio: metric.total / maxTotal
            )
        }
    }
}

private struct VisionMonthMetric: Identifiable {
    var id: Date { monthStart }
    let monthStart: Date
    let label: String
    let total: Double
    let transactionCount: Int
    let isCurrentMonth: Bool
    let ratio: Double

    init(
        monthStart: Date,
        label: String,
        total: Double,
        transactionCount: Int,
        isCurrentMonth: Bool,
        ratio: Double = 0
    ) {
        self.monthStart = monthStart
        self.label = label
        self.total = total
        self.transactionCount = transactionCount
        self.isCurrentMonth = isCurrentMonth
        self.ratio = ratio
    }
}

private struct VisionMonthlyBoard: View {
    let snapshot: VisionLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        VisionGlassPanel {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(snapshot.monthlySnapshot.monthLabel)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.64))
                        Text(privacyMode ? "已隐藏" : VisionFormatters.currency(snapshot.monthlySnapshot.totalExpense))
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("正式账本")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                        Text(VisionFormatters.time.string(from: snapshot.generatedAt))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 16) {
                    VisionMetricTile(title: "今日支出", value: privacyMode ? "***" : VisionFormatters.currency(snapshot.todaySummary.totalExpense), iconName: "sun.max.fill", tint: .yellow)
                    VisionMetricTile(title: "本月笔数", value: "\(snapshot.monthlySnapshot.transactionCount)", iconName: "list.bullet.rectangle.fill", tint: .cyan)
                    VisionMetricTile(title: "年度累计", value: privacyMode ? "***" : VisionFormatters.currency(snapshot.yearlyTotal), iconName: "sparkles", tint: .purple)
                }

                HStack(spacing: 14) {
                    VisionSignalPill(title: "Top 商户", value: privacyMode ? "已隐藏" : snapshot.monthlySnapshot.topMerchant, iconName: "storefront.fill")
                    VisionSignalPill(title: "日均", value: privacyMode ? "***" : VisionFormatters.currency(snapshot.averageDailyExpense), iconName: "calendar")
                }
            }
        }
    }
}

private struct VisionCategoryCloud: View {
    let snapshot: VisionLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        VisionGlassPanel {
            VStack(alignment: .leading, spacing: 18) {
                Text("分类支出卡片")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if snapshot.monthlySnapshot.categoryBreakdown.isEmpty {
                    VisionMutedText("暂无分类数据")
                } else {
                    ForEach(Array(snapshot.monthlySnapshot.categoryBreakdown.prefix(5).enumerated()), id: \.element.id) { index, metric in
                        VisionCategoryFloatingCard(
                            index: index,
                            metric: metric,
                            value: privacyMode ? "***" : VisionFormatters.currency(metric.total)
                        )
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct VisionYearTimelineWall: View {
    let snapshot: VisionLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        VisionGlassPanel {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("年度消费时间线墙")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("最近 12 个月")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.52))
                }

                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(snapshot.yearTimeline) { metric in
                        VisionTimelineColumn(metric: metric, privacyMode: privacyMode)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

private struct VisionRecentRail: View {
    let snapshot: VisionLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        VisionGlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("最近账单悬浮列表")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if snapshot.recentTransactions.isEmpty || privacyMode {
                    VisionMutedText(privacyMode ? "最近账单已隐藏" : "暂无最近账单")
                } else {
                    ForEach(snapshot.recentTransactions.prefix(5)) { transaction in
                        VisionRecentTransactionRow(transaction: transaction)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct VisionMetricTile: View {
    let title: String
    let value: String
    let iconName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct VisionSignalPill: View {
    let title: String
    let value: String
    let iconName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text(value)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.07), in: Capsule())
    }
}

private struct VisionCategoryFloatingCard: View {
    let index: Int
    let metric: MonthlySnapshot.CategoryMetric
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: metric.iconName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(tint)
                Text(metric.title)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                Spacer()
            }

            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.10))
                    Capsule()
                        .fill(VisionDashboardTheme.metricGradient)
                        .frame(width: max(8, proxy.size.width * metric.ratio))
                }
            }
            .frame(height: 8)
        }
        .padding(18)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .offset(x: index.isMultiple(of: 2) ? 0 : 18)
    }

    private var tint: Color {
        VisionDashboardTheme.categoryTints[index % VisionDashboardTheme.categoryTints.count]
    }
}

private struct VisionTimelineColumn: View {
    let metric: VisionMonthMetric
    let privacyMode: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(privacyMode ? "***" : compactAmount)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(metric.isCurrentMonth ? .green : .white.opacity(0.58))
                .frame(height: 20)

            Capsule()
                .fill(metric.isCurrentMonth ? VisionDashboardTheme.metricGradient : VisionDashboardTheme.timelineGradient)
                .frame(height: max(16, 160 * metric.ratio))
                .shadow(color: .green.opacity(metric.isCurrentMonth ? 0.32 : 0), radius: 16, y: 8)

            Text(metric.label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(metric.isCurrentMonth ? 0.86 : 0.46))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var compactAmount: String {
        metric.total >= 10_000
            ? String(format: "%.1f万", metric.total / 10_000)
            : String(format: "%.0f", metric.total)
    }
}

private struct VisionRecentTransactionRow: View {
    let transaction: LedgerTransaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.categoryEnum.iconName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchant.isEmpty ? transaction.categoryTitle : transaction.merchant)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(VisionFormatters.shortDate.string(from: transaction.occurredAt))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Text(VisionFormatters.currency(transaction.amount))
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct VisionLoadingView: View {
    var body: some View {
        VisionGlassPanel {
            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                Text("正在读取本机正式账本")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, minHeight: 420)
        }
    }
}

private struct VisionEmptyLedgerView: View {
    let updatedAt: Date
    let retry: () -> Void

    var body: some View {
        VisionGlassPanel {
            VStack(spacing: 18) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.green)
                Text("暂无可展示的账本数据")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("visionOS 首版只读展示本机正式账本，不读取候选账单、OCR 原文或截图。")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                Text("检查时间 \(VisionFormatters.time.string(from: updatedAt))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                Button("重新读取", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            }
            .frame(maxWidth: .infinity, minHeight: 420)
        }
    }
}

private struct VisionUnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VisionGlassPanel {
            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(.orange)
                Text("账本暂时不可用")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                Button("重试", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
            .frame(maxWidth: .infinity, minHeight: 420)
        }
    }
}

private struct VisionMutedText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.48))
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
    }
}

private struct VisionGlassPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(26)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 30, y: 18)
    }
}

private enum VisionDashboardTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.03, green: 0.06, blue: 0.07),
            Color(red: 0.06, green: 0.12, blue: 0.12),
            Color(red: 0.05, green: 0.05, blue: 0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let metricGradient = LinearGradient(
        colors: [.green, .cyan],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let timelineGradient = LinearGradient(
        colors: [.white.opacity(0.24), .white.opacity(0.08)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let categoryTints: [Color] = [.green, .cyan, .orange, .purple, .yellow]
}

private enum VisionFormatters {
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

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

    static func currency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "¥%.2f", value)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
