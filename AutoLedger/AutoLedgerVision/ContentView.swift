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
                Label(
                    privacyMode ? VisionDashboardCopy.current.showAmounts : VisionDashboardCopy.current.hideAmounts,
                    systemImage: privacyMode ? "eye.slash.fill" : "eye.fill"
                )
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
                Label(VisionDashboardCopy.current.refresh, systemImage: "arrow.clockwise")
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
            let transactions = sortForDashboard(snapshot.displayTransactions)
            if !transactions.isEmpty {
                return transactions
            }
        }

        return sortForDashboard(VisionDashboardSimulatorData.transactions(referenceDate: Date()))
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
        case .dashboard: return VisionDashboardCopy.current.text("月度支出空间看板", "月度支出空間看板", "Spatial monthly dashboard", "空間月次ダッシュボード")
        case .categories: return VisionDashboardCopy.current.text("分类支出卡片", "分類支出卡片", "Category cards", "カテゴリカード")
        case .timeline: return VisionDashboardCopy.current.text("年度消费时间线", "年度消費時間線", "Yearly spending timeline", "年間支出タイムライン")
        }
    }
}

private struct VisionDashboardCopy {
    let languageCode: String

    static var current: VisionDashboardCopy {
        let locale = (ProcessInfo.processInfo.argumentValue(after: "-AppleLocale")
            ?? Locale.preferredLanguages.first
            ?? "zh-Hans").lowercased()
        if locale.hasPrefix("en") {
            return VisionDashboardCopy(languageCode: "en")
        }
        if locale.hasPrefix("ja") {
            return VisionDashboardCopy(languageCode: "ja")
        }
        if locale.hasPrefix("zh_hant") || locale.hasPrefix("zh-hant") || locale.hasPrefix("zh_tw") {
            return VisionDashboardCopy(languageCode: "zh-Hant")
        }
        return VisionDashboardCopy(languageCode: "zh-Hans")
    }

    var localeIdentifier: String {
        switch languageCode {
        case "en": return "en_US"
        case "ja": return "ja_JP"
        case "zh-Hant": return "zh_TW"
        default: return "zh_CN"
        }
    }

    var showAmounts: String { text("显示金额", "顯示金額", "Show amounts", "金額を表示") }
    var hideAmounts: String { text("隐藏金额", "隱藏金額", "Hide amounts", "金額を非表示") }
    var refresh: String { text("刷新", "重新整理", "Refresh", "更新") }
    var hidden: String { text("已隐藏", "已隱藏", "Hidden", "非表示") }
    var loadingTitle: String { text("正在读取本机正式账本", "正在讀取本機正式帳本", "Loading saved ledger data", "保存済み台帳を読み込み中") }
    var emptyTitle: String { text("暂无可展示的账本数据", "暫無可展示的帳本資料", "No ledger data to show yet", "表示できる台帳データはまだありません") }
    var emptySubtitle: String { text("visionOS 首版只读展示本机正式账本，不读取候选账单、OCR 原文或截图。", "visionOS 首版唯讀展示本機正式帳本，不讀取候選帳單、OCR 原文或截圖。", "The visionOS app shows read-only saved ledger data, not candidates, OCR text, or screenshots.", "visionOS では候補、OCR テキスト、スクリーンショットではなく、保存済み台帳を読み取り専用で表示します。") }
    var unavailableTitle: String { text("账本暂时不可用", "帳本暫時不可用", "Ledger temporarily unavailable", "台帳を一時的に利用できません") }
    var reload: String { text("重新读取", "重新讀取", "Reload", "再読み込み") }
    var retry: String { text("重试", "重試", "Retry", "再試行") }

    func text(_ zhHans: String, _ zhHant: String, _ en: String, _ ja: String) -> String {
        switch languageCode {
        case "en": return en
        case "ja": return ja
        case "zh-Hant": return zhHant
        default: return zhHans
        }
    }

    func categoryTitle(_ category: TransactionCategory?) -> String {
        guard let category else {
            return text("暂无", "暫無", "None", "なし")
        }
        switch category {
        case .groceries: return text("日用杂货", "日用雜貨", "Groceries", "食料品")
        case .dining: return text("餐饮", "餐飲", "Dining", "外食")
        case .transport: return text("出行", "出行", "Transport", "交通")
        case .hotel: return text("酒店", "酒店", "Hotel", "ホテル")
        case .shopping: return text("购物", "購物", "Shopping", "買い物")
        case .digital: return text("数字服务", "數位服務", "Digital", "デジタル")
        case .utilities: return text("生活缴费", "生活繳費", "Utilities", "公共料金")
        case .entertainment: return text("娱乐", "娛樂", "Entertainment", "エンタメ")
        case .other: return text("其他", "其他", "Other", "その他")
        }
    }

    func checkTime(_ date: Date) -> String {
        text(
            "检查时间 \(VisionFormatters.time.string(from: date))",
            "檢查時間 \(VisionFormatters.time.string(from: date))",
            "Checked at \(VisionFormatters.time.string(from: date))",
            "確認時刻 \(VisionFormatters.time.string(from: date))"
        )
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
        let copy = VisionDashboardCopy.current
        let transitMerchant = copy.text(
            "地铁：Example Station → Example Airport",
            "地鐵：Example Station → Example Airport",
            "Metro: Example Station → Example Airport",
            "地下鉄：Example Station → Example Airport"
        )
        let specs: [(String, Double, Int, TransactionCategory, ReceiptSource)] = [
            ("Sample Harbor Hotel", 369.39, 0, .hotel, .manual),
            ("Demo Coffee", 18.00, 0, .dining, .wechat),
            ("Example Market", 86.50, 0, .shopping, .unionPay),
            (transitMerchant, 4.00, 1, .transport, .alipay),
            ("Sample Cinema", 45.00, 2, .entertainment, .manual),
            ("Sample Books", 39.00, 4, .shopping, .manual),
            ("Mobile Carrier", 50.00, 8, .utilities, .manual),
            ("Lunch Bistro", 28.00, 12, .dining, .voice),
            ("Takeout Sample", 32.00, 16, .dining, .manual)
        ]

        return specs.enumerated().map { index, spec in
            LedgerTransaction(
                id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1)) ?? UUID(),
                merchant: spec.0,
                amount: spec.1,
                occurredAt: calendar.date(byAdding: .day, value: -spec.2, to: referenceDate) ?? referenceDate,
                categoryLabel: spec.3.rawValue,
                sourceLabel: spec.4.rawValue,
                note: copy.text("visionOS 示例看板数据", "visionOS 範例看板資料", "visionOS sample dashboard data", "visionOS サンプルダッシュボードデータ")
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
        formatter.locale = VisionFormatters.locale
        formatter.setLocalizedDateFormatFromTemplate("MMM")

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
                        Text(VisionFormatters.month.string(from: snapshot.generatedAt))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.64))
                        Text(privacyMode ? VisionDashboardCopy.current.hidden : VisionFormatters.currency(snapshot.monthlySnapshot.totalExpense))
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text(VisionDashboardCopy.current.text("正式账本", "正式帳本", "Saved ledger", "保存済み台帳"))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                        Text(VisionFormatters.time.string(from: snapshot.generatedAt))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 16) {
                    VisionMetricTile(title: VisionDashboardCopy.current.text("今日支出", "今日支出", "Today", "今日"), value: privacyMode ? "***" : VisionFormatters.currency(snapshot.todaySummary.totalExpense), iconName: "sun.max.fill", tint: .yellow)
                    VisionMetricTile(title: VisionDashboardCopy.current.text("本月笔数", "本月筆數", "Records", "記録数"), value: "\(snapshot.monthlySnapshot.transactionCount)", iconName: "list.bullet.rectangle.fill", tint: .cyan)
                    VisionMetricTile(title: VisionDashboardCopy.current.text("年度累计", "年度累計", "Year total", "年間合計"), value: privacyMode ? "***" : VisionFormatters.currency(snapshot.yearlyTotal), iconName: "sparkles", tint: .purple)
                }

                HStack(spacing: 14) {
                    VisionSignalPill(title: VisionDashboardCopy.current.text("Top 商户", "Top 商家", "Top merchant", "上位加盟店"), value: privacyMode ? VisionDashboardCopy.current.hidden : snapshot.monthlySnapshot.topMerchant, iconName: "storefront.fill")
                    VisionSignalPill(title: VisionDashboardCopy.current.text("日均", "日均", "Daily avg.", "日平均"), value: privacyMode ? "***" : VisionFormatters.currency(snapshot.averageDailyExpense), iconName: "calendar")
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
                Text(VisionDashboardCopy.current.text("分类支出卡片", "分類支出卡片", "Category cards", "カテゴリカード"))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if snapshot.monthlySnapshot.categoryBreakdown.isEmpty {
                    VisionMutedText(VisionDashboardCopy.current.text("暂无分类数据", "暫無分類資料", "No category data yet", "カテゴリデータはまだありません"))
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
                    Text(VisionDashboardCopy.current.text("年度消费时间线墙", "年度消費時間線牆", "Yearly spending timeline", "年間支出タイムライン"))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(VisionDashboardCopy.current.text("最近 12 个月", "最近 12 個月", "Last 12 months", "直近 12 か月"))
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
                Text(VisionDashboardCopy.current.text("最近账单悬浮列表", "最近帳單懸浮列表", "Recent records", "最近の記録"))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if snapshot.recentTransactions.isEmpty || privacyMode {
                    VisionMutedText(privacyMode ? VisionDashboardCopy.current.text("最近账单已隐藏", "最近帳單已隱藏", "Recent records hidden", "最近の記録は非表示です") : VisionDashboardCopy.current.text("暂无最近账单", "暫無最近帳單", "No recent records yet", "最近の記録はまだありません"))
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
                Text(VisionDashboardCopy.current.categoryTitle(metric.category))
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
        VisionFormatters.compactCurrency(metric.total)
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
                Text(VisionDashboardCopy.current.loadingTitle)
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
                Text(VisionDashboardCopy.current.emptyTitle)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(VisionDashboardCopy.current.emptySubtitle)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                Text(VisionDashboardCopy.current.checkTime(updatedAt))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                Button(VisionDashboardCopy.current.reload, action: retry)
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
                Text(VisionDashboardCopy.current.unavailableTitle)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                Button(VisionDashboardCopy.current.retry, action: retry)
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
    static var locale: Locale {
        Locale(identifier: VisionDashboardCopy.current.localeIdentifier)
    }

    static let month: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter
    }()

    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd HH:mm")
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func currency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "¥%.2f", value)
    }

    static func compactCurrency(_ value: Double) -> String {
        if value >= 10_000 {
            switch VisionDashboardCopy.current.languageCode {
            case "en":
                return "¥" + String(format: "%.1fK", value / 1_000)
            default:
                return "¥" + String(format: "%.1f万", value / 10_000)
            }
        }
        return "¥" + String(format: "%.0f", value)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
