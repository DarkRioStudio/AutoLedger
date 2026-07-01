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
    @State private var selectedPage: TVDashboardPage = .screenshotInitialPage
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
                Text(TVDashboardCopy.current.heroSubtitle)
                    .font(.system(size: 50, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                privacyMode.toggle()
            } label: {
                Label(
                    privacyMode ? TVDashboardCopy.current.showAmounts : TVDashboardCopy.current.hideAmounts,
                    systemImage: privacyMode ? "eye.slash.fill" : "eye.fill"
                )
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(privacyMode ? .orange : .green)

            Button {
                store.load()
            } label: {
                Label(TVDashboardCopy.current.refresh, systemImage: "arrow.clockwise")
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
        case .overview: return TVDashboardCopy.current.overview
        case .categories: return TVDashboardCopy.current.categories
        case .trend: return TVDashboardCopy.current.trend
        case .summary: return TVDashboardCopy.current.summary
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

    static var screenshotInitialPage: TVDashboardPage {
        guard
            ProcessInfo.processInfo.arguments.contains("--screenshot-mode"),
            let rawValue = ProcessInfo.processInfo.argumentValue(after: "--screenshot-scene")
        else {
            return .overview
        }

        switch rawValue {
        case "overview": return .overview
        case "categories": return .categories
        case "trend", "trends": return .trend
        case "summary": return .summary
        default: return .overview
        }
    }
}

private struct TVDashboardCopy {
    let languageCode: String

    static var current: TVDashboardCopy {
        let locale = (ProcessInfo.processInfo.argumentValue(after: "-AppleLocale")
            ?? Locale.preferredLanguages.first
            ?? "zh-Hans").lowercased()
        if locale.hasPrefix("en") {
            return TVDashboardCopy(languageCode: "en")
        }
        if locale.hasPrefix("ja") {
            return TVDashboardCopy(languageCode: "ja")
        }
        if locale.hasPrefix("zh_hant") || locale.hasPrefix("zh-hant") || locale.hasPrefix("zh_tw") {
            return TVDashboardCopy(languageCode: "zh-Hant")
        }
        return TVDashboardCopy(languageCode: "zh-Hans")
    }

    var localeIdentifier: String {
        switch languageCode {
        case "en": return "en_US"
        case "ja": return "ja_JP"
        case "zh-Hant": return "zh_TW"
        default: return "zh_CN"
        }
    }

    var heroSubtitle: String { text("家庭大屏只读账本", "家庭大螢幕只讀帳本", "Read-only ledger for Apple TV", "Apple TV の読み取り専用台帳") }
    var showAmounts: String { text("显示金额", "顯示金額", "Show amounts", "金額を表示") }
    var hideAmounts: String { text("隐藏金额", "隱藏金額", "Hide amounts", "金額を非表示") }
    var refresh: String { text("刷新", "重新整理", "Refresh", "更新") }
    var overview: String { text("总览", "總覽", "Overview", "概要") }
    var categories: String { text("分类", "分類", "Categories", "カテゴリ") }
    var trend: String { text("趋势", "趨勢", "Trends", "推移") }
    var summary: String { text("摘要", "摘要", "Summary", "サマリー") }
    var hidden: String { text("已隐藏", "已隱藏", "Hidden", "非表示") }
    var none: String { text("暂无", "暫無", "None", "なし") }
    var loadingTitle: String { text("正在读取账本快照", "正在讀取帳本快照", "Loading ledger snapshot", "台帳スナップショットを読み込み中") }
    var loadingSubtitle: String { text("tvOS 首版只展示正式账本的只读数据。", "tvOS 首版只展示正式帳本的唯讀資料。", "The tvOS app shows read-only saved ledger data.", "tvOS では保存済み台帳を読み取り専用で表示します。") }
    var emptyTitle: String { text("等待账本数据", "等待帳本資料", "Waiting for ledger data", "台帳データを待機中") }
    var emptySubtitle: String { text("当前 Apple TV 本机还没有可展示的正式账单。后续接入 iCloud 只读快照后，这里会显示同步后的月度看板。", "目前 Apple TV 本機還沒有可展示的正式帳單。接入 iCloud 唯讀快照後，這裡會顯示同步後的月度看板。", "This Apple TV does not have saved ledger data to show yet. Once an iCloud read-only snapshot is available, the monthly dashboard appears here.", "この Apple TV には表示できる保存済み台帳がまだありません。iCloud の読み取り専用スナップショットが利用可能になると、月次ダッシュボードが表示されます。") }
    var unavailableTitle: String { text("账本快照不可用", "帳本快照不可用", "Ledger snapshot unavailable", "台帳スナップショットを利用できません") }
    var retry: String { text("重试", "重試", "Retry", "再試行") }
    var reload: String { text("重新读取", "重新讀取", "Reload", "再読み込み") }

    func text(_ zhHans: String, _ zhHant: String, _ en: String, _ ja: String) -> String {
        switch languageCode {
        case "en": return en
        case "ja": return ja
        case "zh-Hant": return zhHant
        default: return zhHans
        }
    }

    func categoryTitle(_ category: TransactionCategory?) -> String {
        guard let category else { return none }
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

    func recordsCount(_ count: Int) -> String {
        switch languageCode {
        case "en": return "\(count) records"
        case "ja": return "\(count) 件"
        case "zh-Hant": return "\(count) 筆"
        default: return "\(count) 笔"
        }
    }

    func checkTime(_ date: Date) -> String {
        text(
            "检查时间 \(TVFormatters.time.string(from: date))",
            "檢查時間 \(TVFormatters.time.string(from: date))",
            "Checked at \(TVFormatters.time.string(from: date))",
            "確認時刻 \(TVFormatters.time.string(from: date))"
        )
    }

    func monthDelta(_ delta: Double) -> String {
        if abs(delta) < 0.01 {
            return text("与上月基本持平", "與上月大致持平", "About the same as last month", "先月とほぼ同じ")
        }
        if delta > 0 {
            return text("较上月多 ", "較上月多 ", "Up ", "先月より ") + TVFormatters.currency(abs(delta))
        }
        return text("较上月少 ", "較上月少 ", "Down ", "先月より少ない ") + TVFormatters.currency(abs(delta))
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
        #if DEBUG
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--screenshot-mode") {
            return sortForDashboard(TVDashboardSimulatorData.transactions(referenceDate: Date()))
        }
        #endif
        #endif

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
        let copy = TVDashboardCopy.current
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
                note: copy.text("tvOS 模拟器演示数据", "tvOS 模擬器展示資料", "tvOS simulator demo data", "tvOS シミュレーターデモデータ")
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
            categoryLabel: (record[CloudLedgerSyncSchema.Field.category] as? String) ?? TransactionCategory.other.rawValue,
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
                        Text(TVFormatters.month.string(from: snapshot.generatedAt))
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
                    TVMetricCard(title: TVDashboardCopy.current.text("今日支出", "今日支出", "Today", "今日"), value: privacyMode ? "***" : TVFormatters.currency(snapshot.todaySummary.totalExpense), iconName: "sun.max.fill", tint: .yellow)
                    TVMetricCard(title: TVDashboardCopy.current.text("本月笔数", "本月筆數", "Records", "記録数"), value: "\(snapshot.monthlySnapshot.transactionCount)", iconName: "list.bullet.rectangle.fill", tint: .cyan)
                    TVMetricCard(title: TVDashboardCopy.current.text("日均支出", "日均支出", "Daily avg.", "日平均"), value: privacyMode ? "***" : TVFormatters.currency(snapshot.averageDailyExpense), iconName: "calendar", tint: .green)
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
            return TVDashboardCopy.current.monthDelta(delta)
        }
        return TVDashboardCopy.current.monthDelta(delta)
    }
}

private struct TVCategoryPage: View {
    let snapshot: TVLedgerDashboardSnapshot
    let privacyMode: Bool

    var body: some View {
        HStack(spacing: TVDashboardLayout.columnSpacing) {
            TVPanel {
                VStack(alignment: .leading, spacing: 24) {
                    Text(TVDashboardCopy.current.text("本月分类占比", "本月分類占比", "This month's categories", "今月のカテゴリ"))
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(TVDashboardCopy.current.text(
                        "按正式账单金额排序，最多展示前 6 类。",
                        "依正式帳單金額排序，最多展示前 6 類。",
                        "Sorted by saved ledger amount, showing up to six categories.",
                        "保存済み台帳の金額順に最大 6 件まで表示します。"
                    ))
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
                TVMetricCard(title: TVDashboardCopy.current.text("Top 分类", "Top 分類", "Top category", "上位カテゴリ"), value: TVDashboardCopy.current.categoryTitle(snapshot.monthlySnapshot.categoryBreakdown.first?.category), iconName: "chart.pie.fill", tint: .orange)
                TVMetricCard(title: TVDashboardCopy.current.text("分类数量", "分類數量", "Categories", "カテゴリ数"), value: "\(snapshot.monthlySnapshot.categoryBreakdown.count)", iconName: "square.grid.2x2.fill", tint: .green)
                TVMetricCard(title: TVDashboardCopy.current.text("本月总额", "本月總額", "Monthly total", "今月の合計"), value: privacyMode ? "***" : TVFormatters.currency(snapshot.monthlySnapshot.totalExpense), iconName: "yensign.circle.fill", tint: .cyan)
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
                    Text(TVDashboardCopy.current.text("最近 7 天趋势", "最近 7 天趨勢", "Last 7 days", "直近 7 日"))
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(TVDashboardCopy.current.text(
                        "只读展示正式账单，不包含候选账单和调试记录。",
                        "唯讀展示正式帳單，不包含候選帳單和除錯記錄。",
                        "Read-only saved records, without candidates or debug entries.",
                        "候補やデバッグ記録を除いた保存済み記録を表示します。"
                    ))
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
                    Text(TVDashboardCopy.current.text("近 6 个月", "近 6 個月", "Last 6 months", "直近 6 か月"))
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
                TVMetricCard(title: TVDashboardCopy.current.text("年度累计", "年度累計", "Year total", "年間合計"), value: privacyMode ? "***" : TVFormatters.currency(snapshot.yearlyTotal), iconName: "sparkles", tint: .yellow)
                TVMetricCard(title: TVDashboardCopy.current.text("本月累计", "本月累計", "Month total", "月間合計"), value: privacyMode ? "***" : TVFormatters.currency(snapshot.monthlySnapshot.totalExpense), iconName: "calendar.badge.clock", tint: .green)
                TVMetricCard(title: TVDashboardCopy.current.text("Top 商户", "Top 商家", "Top merchant", "上位加盟店"), value: privacyMode ? TVDashboardCopy.current.hidden : snapshot.monthlySnapshot.topMerchant, iconName: "storefront.fill", tint: .orange)
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
                Text(TVDashboardCopy.current.text("分类结构", "分類結構", "Category mix", "カテゴリ構成"))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if snapshot.monthlySnapshot.categoryBreakdown.isEmpty {
                    TVMutedText(TVDashboardCopy.current.text("暂无分类数据", "暫無分類資料", "No category data yet", "カテゴリデータはまだありません"))
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
                Text(TVDashboardCopy.current.text("常用商户", "常用商家", "Frequent merchants", "よく使う加盟店"))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if snapshot.monthlySnapshot.topMerchantMetrics.isEmpty || privacyMode {
                    TVMutedText(privacyMode ? TVDashboardCopy.current.text("商户信息已隐藏", "商家資訊已隱藏", "Merchant details hidden", "加盟店情報は非表示です") : TVDashboardCopy.current.text("暂无商户数据", "暫無商家資料", "No merchant data yet", "加盟店データはまだありません"))
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
                                Text(TVDashboardCopy.current.recordsCount(metric.transactionCount))
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
                Text(TVDashboardCopy.current.text("最近账单", "最近帳單", "Recent records", "最近の記録"))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if transactions.isEmpty || privacyMode {
                    TVMutedText(privacyMode ? TVDashboardCopy.current.text("最近账单已隐藏", "最近帳單已隱藏", "Recent records hidden", "最近の記録は非表示です") : TVDashboardCopy.current.text("暂无最近账单", "暫無最近帳單", "No recent records yet", "最近の記録はまだありません"))
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

                Label(TVDashboardCopy.current.categoryTitle(metric.category), systemImage: metric.iconName)
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
                Text(TVDashboardCopy.current.recordsCount(metric.transactionCount))
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
            Text(TVDashboardCopy.current.loadingTitle)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(TVDashboardCopy.current.loadingSubtitle)
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
                Text(TVDashboardCopy.current.emptyTitle)
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(TVDashboardCopy.current.emptySubtitle)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: 760)
                Text(TVDashboardCopy.current.checkTime(updatedAt))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Button(TVDashboardCopy.current.reload, action: retry)
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
                Text(TVDashboardCopy.current.unavailableTitle)
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: 800)
                Button(TVDashboardCopy.current.retry, action: retry)
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
    static var locale: Locale {
        Locale(identifier: TVDashboardCopy.current.localeIdentifier)
    }

    static let month: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
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

    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "E"
        return formatter
    }()

    static func currency(_ value: Double) -> String {
        "¥" + String(format: "%.2f", value)
    }

    static func compactCurrency(_ value: Double) -> String {
        if value >= 10_000 {
            switch TVDashboardCopy.current.languageCode {
            case "en":
                return "¥" + String(format: "%.1fK", value / 1_000)
            default:
                return "¥" + String(format: "%.1f万", value / 10_000)
            }
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
