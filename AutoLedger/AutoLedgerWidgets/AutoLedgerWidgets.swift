import Foundation
import SQLite3
import SwiftUI
import WidgetKit

private enum WidgetCopy {
    static var todayExpenseTitle: String { localized(zh: "今日支出", ja: "今日の支出", en: "Today's Spend") }
    static var monthReportTitle: String { localized(zh: "当月月报", ja: "今月のレポート", en: "Monthly Report") }
    static var topMerchantTitle: String { localized(zh: "Top 商户", ja: "上位店舗", en: "Top Merchant") }
    static var topCategoryTitle: String { localized(zh: "Top 分类", ja: "上位カテゴリ", en: "Top Category") }
    static var latestExpenseTitle: String { localized(zh: "最近一笔", ja: "直近", en: "Latest") }
    static var noExpenseTitle: String { localized(zh: "今天还没记账", ja: "今日はまだ記録がありません", en: "No expenses today") }
    static var noExpenseDetail: String { localized(zh: "打开 App 记录今天的第一笔支出", ja: "App を開いて今日の支出を記録", en: "Open the app to log your first expense") }
    static var noMonthDataTitle: String { localized(zh: "本月还没有账单", ja: "今月の記録はまだありません", en: "No entries this month") }
    static var noMonthDataDetail: String { localized(zh: "开始记录后，这里会显示月度摘要", ja: "記録を始めると月次サマリーが表示されます", en: "Your monthly summary will appear here") }
    static var updatedPrefix: String { localized(zh: "更新于", ja: "更新", en: "Updated") }
    static var thisMonthLabel: String { localized(zh: "本月", ja: "今月", en: "This Month") }
    static var recentTransactionsTitle: String { localized(zh: "最近账单", ja: "最近の記録", en: "Recent") }
    static var noRecentTransactionTitle: String { localized(zh: "暂无账单", ja: "記録なし", en: "No Recent Entries") }
    static var upcomingSubscriptionsTitle: String { localized(zh: "即将续费", ja: "まもなく更新", en: "Upcoming") }
    static var noUpcomingSubscriptionTitle: String { localized(zh: "暂无续费", ja: "更新予定なし", en: "No Upcoming Bills") }
    static var quickAddTitle: String { localized(zh: "快速记一笔", ja: "すばやく記録", en: "Quick Add") }
    static var monthSummaryCountFormat: String { localized(zh: "%d 笔记录", ja: "%d 件の記録", en: "%d entries") }
    static var todaySummaryCountFormat: String { localized(zh: "今日共 %d 笔", ja: "今日 %d 件", en: "%d today") }
    static var todayCountCompactFormat: String { localized(zh: "%d 笔", ja: "%d 件", en: "%d items") }
    static var watchAccessoryInlineFormat: String { localized(zh: "今日支出 %@", ja: "今日 %@", en: "Today %@") }
    static var watchAccessoryCountFormat: String { localized(zh: "%d 笔", ja: "%d 件", en: "%d entries") }
    static var fallbackMerchant: String { localized(zh: "暂无", ja: "なし", en: "None") }
    static var fallbackCategory: String { localized(zh: "暂无", ja: "なし", en: "None") }
    static var staleSnapshotShort: String { localized(zh: "较旧", ja: "古い", en: "Stale") }
    static var staleSnapshotUpdatedPrefix: String { localized(zh: "较旧", ja: "古い", en: "Stale") }

    static func localized(zh: String, ja: String, en: String) -> String {
        if isChinese { return zh }
        if isJapanese { return ja }
        return en
    }

    fileprivate static var isChinese: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
    }

    fileprivate static var isJapanese: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("ja") == true
    }
}

private enum WidgetDeepLink {
    static let todayLedgerURL = URL(string: "autoledger://ledger/today")
    static let ledgerURL = URL(string: "autoledger://ledger")!
    static let quickAddURL = URL(string: "autoledger://quick-add")!
    static let subscriptionsURL = URL(string: "autoledger://subscriptions")!
}

private struct WidgetLedgerMetrics {
    let ledgerScope: WidgetLedgerScope
    let todayTotal: Double
    let todayCount: Int
    let latestMerchant: String?
    let monthTotal: Double
    let monthCount: Int
    let recentTransactions: [WidgetTransaction]
    let upcomingSubscriptions: [WidgetSubscription]
    let topMerchant: String?
    let topCategory: String?
    let updatedAt: Date
    let isSnapshotStale: Bool

    static let empty = WidgetLedgerMetrics(
        ledgerScope: .defaultLocal,
        todayTotal: 0,
        todayCount: 0,
        latestMerchant: nil,
        monthTotal: 0,
        monthCount: 0,
        recentTransactions: [],
        upcomingSubscriptions: [],
        topMerchant: nil,
        topCategory: nil,
        updatedAt: .now,
        isSnapshotStale: false
    )
}

private struct WidgetLedgerScope {
    let id: String
    let name: String

    static let defaultLedgerID = "default-local-ledger"
    static let defaultLocal = WidgetLedgerScope(id: defaultLedgerID, name: WidgetCopy.localized(zh: "本地账本", ja: "ローカル台帳", en: "Local Ledger"))
}

private enum WidgetLedgerStore {
    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let databaseFolder = "AutoLedger"
    private static let databaseFilename = "autoledger.sqlite3"
    private static let ledgerSnapshotUpdatedAtKey = "ledgerSnapshotUpdatedAt"
    private static let lastSuccessfulCloudKitSyncAtKey = "lastSuccessfulCloudKitSyncAt"
    private static let ledgerCloudSyncEnabledKey = "ledgerCloudSyncEnabled"
    private static let defaultWriteLedgerIDKey = "defaultWriteLedgerID"

    static func loadMetrics(referenceDate: Date = .now) -> WidgetLedgerMetrics {
        let metadata = loadSnapshotMetadata(referenceDate: referenceDate)
        guard let dbURL = databaseURL(),
              FileManager.default.fileExists(atPath: dbURL.path) else {
            return WidgetLedgerMetrics(
                ledgerScope: .defaultLocal,
                todayTotal: 0,
                todayCount: 0,
                latestMerchant: nil,
                monthTotal: 0,
                monthCount: 0,
                recentTransactions: [],
                upcomingSubscriptions: [],
                topMerchant: nil,
                topCategory: nil,
                updatedAt: metadata.updatedAt,
                isSnapshotStale: metadata.isStale
            )
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return WidgetLedgerMetrics(
                ledgerScope: .defaultLocal,
                todayTotal: 0,
                todayCount: 0,
                latestMerchant: nil,
                monthTotal: 0,
                monthCount: 0,
                recentTransactions: [],
                upcomingSubscriptions: [],
                topMerchant: nil,
                topCategory: nil,
                updatedAt: metadata.updatedAt,
                isSnapshotStale: metadata.isStale
            )
        }
        defer { sqlite3_close(db) }

        let calendar = Calendar.autoupdatingCurrent
        let todayInterval = calendar.dateInterval(of: .day, for: referenceDate)
        let todayStart = todayInterval?.start ?? calendar.startOfDay(for: referenceDate)
        let tomorrowStart = todayInterval?.end ?? calendar.date(byAdding: .day, value: 1, to: todayStart) ?? referenceDate
        let monthInterval = calendar.dateInterval(of: .month, for: referenceDate)
        let monthStart = monthInterval?.start ?? todayStart
        let monthEnd = monthInterval?.end ?? tomorrowStart

        let ledgerScope = loadLedgerScope(db: db)
        let todayTransactions = loadTransactions(db: db, from: todayStart, to: tomorrowStart, ledgerID: ledgerScope.id, positiveOnly: true)
        let monthTransactions = loadTransactions(db: db, from: monthStart, to: monthEnd, ledgerID: ledgerScope.id)
        let recentTransactions = loadRecentTransactions(db: db, referenceDate: referenceDate, ledgerID: ledgerScope.id)
        let upcomingSubscriptions = loadUpcomingSubscriptions(db: db, referenceDate: referenceDate)

        let todayTotal = todayTransactions.reduce(0) { $0 + $1.amount }
        let monthTotal = monthTransactions.reduce(0) { $0 + $1.amount }
        let topMerchant = groupedTopName(from: monthTransactions, keyPath: \.merchant)
        let topCategory = groupedTopName(from: monthTransactions, keyPath: \.category).map(categoryTitle)

        return WidgetLedgerMetrics(
            ledgerScope: ledgerScope,
            todayTotal: todayTotal,
            todayCount: todayTransactions.count,
            latestMerchant: todayTransactions.first.map(displayName(for:)),
            monthTotal: monthTotal,
            monthCount: monthTransactions.count,
            recentTransactions: recentTransactions,
            upcomingSubscriptions: upcomingSubscriptions,
            topMerchant: topMerchant,
            topCategory: topCategory,
            updatedAt: metadata.updatedAt,
            isSnapshotStale: metadata.isStale
        )
    }

    private static func loadLedgerScope(db: OpaquePointer?) -> WidgetLedgerScope {
        let requestedLedgerID = UserDefaults(suiteName: appGroupIdentifier)?
            .string(forKey: defaultWriteLedgerIDKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackID = requestedLedgerID?.isEmpty == false ? requestedLedgerID! : WidgetLedgerScope.defaultLedgerID
        let sql = """
        SELECT id, name
        FROM ledger_profiles
        WHERE id = ?
          AND archived_at IS NULL
        LIMIT 1;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return WidgetLedgerScope(id: fallbackID, name: WidgetLedgerScope.defaultLocal.name)
        }

        sqlite3_bind_text(statement, 1, fallbackID, -1, sqliteTransient)
        guard sqlite3_step(statement) == SQLITE_ROW,
              let idCString = sqlite3_column_text(statement, 0),
              let nameCString = sqlite3_column_text(statement, 1) else {
            return fallbackID == WidgetLedgerScope.defaultLedgerID
                ? .defaultLocal
                : WidgetLedgerScope(id: fallbackID, name: WidgetLedgerScope.defaultLocal.name)
        }

        return WidgetLedgerScope(id: String(cString: idCString), name: String(cString: nameCString))
    }

    private static func loadSnapshotMetadata(referenceDate: Date) -> (updatedAt: Date, isStale: Bool) {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let snapshotUpdatedAt = defaults?.object(forKey: ledgerSnapshotUpdatedAtKey) as? Date ?? referenceDate
        let syncEnabled = defaults?.bool(forKey: ledgerCloudSyncEnabledKey) ?? false
        guard syncEnabled else {
            return (snapshotUpdatedAt, false)
        }
        guard let lastSyncAt = defaults?.object(forKey: lastSuccessfulCloudKitSyncAtKey) as? Date else {
            return (snapshotUpdatedAt, true)
        }
        return (snapshotUpdatedAt, referenceDate.timeIntervalSince(lastSyncAt) > 12 * 60 * 60)
    }

    private static func databaseURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(databaseFolder, isDirectory: true)
            .appendingPathComponent(databaseFilename)
    }

    private static func loadTransactions(
        db: OpaquePointer?,
        from start: Date,
        to end: Date,
        ledgerID: String,
        positiveOnly: Bool = false
    ) -> [WidgetTransaction] {
        let defaultLedgerID = WidgetLedgerScope.defaultLedgerID
        let ledgerFilter = ledgerID == defaultLedgerID
            ? "AND (ledger_id IS NULL OR ledger_id = ?)"
            : "AND ledger_id = ?"
        let sql = """
        SELECT merchant, amount, category, source, occurred_at
        FROM transactions
        WHERE deleted_at IS NULL
          \(positiveOnly ? "AND amount > 0" : "")
          AND occurred_at >= ?
          AND occurred_at < ?
          \(ledgerFilter)
        ORDER BY occurred_at DESC, created_at DESC;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        sqlite3_bind_text(statement, 1, storageDateTime(start), -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, storageDateTime(end), -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, ledgerID, -1, sqliteTransient)

        var items: [WidgetTransaction] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let merchantCString = sqlite3_column_text(statement, 0),
                let categoryCString = sqlite3_column_text(statement, 2),
                let sourceCString = sqlite3_column_text(statement, 3),
                let occurredCString = sqlite3_column_text(statement, 4)
            else {
                continue
            }

            let merchant = String(cString: merchantCString)
            let category = String(cString: categoryCString)
            let source = String(cString: sourceCString)
            let amount = sqlite3_column_double(statement, 1)
            let occurredAt = parseStorageDate(String(cString: occurredCString)) ?? start

            items.append(
                WidgetTransaction(
                    merchant: merchant,
                    amount: amount,
                    category: category,
                    source: source,
                    occurredAt: occurredAt
                )
            )
        }

        return items
    }

    private static func loadRecentTransactions(db: OpaquePointer?, referenceDate: Date, ledgerID: String) -> [WidgetTransaction] {
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? referenceDate.addingTimeInterval(-365 * 86_400)
        let end = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate.addingTimeInterval(86_400)
        return Array(loadTransactions(db: db, from: start, to: end, ledgerID: ledgerID, positiveOnly: true).prefix(3))
    }

    private static func loadUpcomingSubscriptions(db: OpaquePointer?, referenceDate: Date) -> [WidgetSubscription] {
        let end = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 14, to: referenceDate) ?? referenceDate.addingTimeInterval(14 * 86_400)
        let sql = """
        SELECT merchant, plan_name, amount, next_charged_at
        FROM subscriptions
        WHERE status = 'active'
          AND next_charged_at >= ?
          AND next_charged_at < ?
        ORDER BY next_charged_at ASC
        LIMIT 2;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        sqlite3_bind_text(statement, 1, storageDateTime(referenceDate), -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, storageDateTime(end), -1, sqliteTransient)

        var items: [WidgetSubscription] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let merchantCString = sqlite3_column_text(statement, 0),
                let planCString = sqlite3_column_text(statement, 1),
                let nextCString = sqlite3_column_text(statement, 3)
            else {
                continue
            }

            items.append(
                WidgetSubscription(
                    merchant: String(cString: merchantCString),
                    planName: String(cString: planCString),
                    amount: sqlite3_column_double(statement, 2),
                    nextChargedAt: parseStorageDate(String(cString: nextCString)) ?? referenceDate
                )
            )
        }

        return items
    }

    private static func groupedTopName(from items: [WidgetTransaction], keyPath: KeyPath<WidgetTransaction, String>) -> String? {
        Dictionary(grouping: items, by: { $0[keyPath: keyPath] })
            .map { key, entries in (name: key, total: entries.reduce(0) { $0 + $1.amount }) }
            .sorted { lhs, rhs in
                if lhs.total == rhs.total {
                    return lhs.name < rhs.name
                }
                return lhs.total > rhs.total
            }
            .first?
            .name
    }

    private static func storageDateTime(_ date: Date) -> String {
        storageFormatter.string(from: date)
    }

    private static func parseStorageDate(_ value: String) -> Date? {
        if let storageDate = storageFormatter.date(from: value) {
            return storageDate
        }

        let legacyFormatter = DateFormatter()
        legacyFormatter.locale = Locale(identifier: "en_US_POSIX")
        legacyFormatter.timeZone = .current
        legacyFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return legacyFormatter.date(from: value)
    }

    private static func categoryTitle(_ rawValue: String) -> String {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "groceries", "grocery", "超市":
            return WidgetCopy.localized(zh: "日用杂货", ja: "日用品", en: "Groceries")
        case "dining", "food", "meal", "restaurant", "餐饮", "餐飲", "吃饭", "吃飯":
            return WidgetCopy.localized(zh: "餐饮", ja: "飲食", en: "Dining")
        case "transport", "transportation", "transit", "交通", "出行":
            return WidgetCopy.localized(zh: "出行", ja: "交通", en: "Transport")
        case "hotel", "hotels", "lodging", "accommodation", "accommodations", "酒店", "酒店住宿", "住宿", "宾馆", "賓館", "飯店", "旅馆", "旅館", "ホテル", "宿泊", "宿泊費":
            return WidgetCopy.localized(zh: "酒店", ja: "ホテル", en: "Hotel")
        case "shopping", "购物", "購物":
            return WidgetCopy.localized(zh: "购物", ja: "買い物", en: "Shopping")
        case "digital", "subscription", "订阅", "訂閱":
            return WidgetCopy.localized(zh: "数字服务", ja: "デジタル", en: "Digital")
        case "utilities", "utility", "生活缴费", "生活繳費":
            return WidgetCopy.localized(zh: "生活缴费", ja: "公共料金", en: "Utilities")
        case "entertainment", "娱乐", "娛樂":
            return WidgetCopy.localized(zh: "娱乐", ja: "エンタメ", en: "Entertainment")
        case "other":
            return WidgetCopy.localized(zh: "其他", ja: "その他", en: "Other")
        default: return rawValue
        }
    }

    private static func sourceTitle(_ rawValue: String) -> String {
        switch rawValue {
        case "wechat": return WidgetCopy.localized(zh: "微信支付", ja: "WeChat Pay", en: "WeChat Pay")
        case "alipay": return WidgetCopy.localized(zh: "支付宝", ja: "Alipay", en: "Alipay")
        case "unionPay": return WidgetCopy.localized(zh: "云闪付", ja: "UnionPay", en: "UnionPay")
        case "appStore": return "App Store"
        case "manual": return WidgetCopy.localized(zh: "手动记录", ja: "手動記録", en: "Manual")
        case "shortcut": return WidgetCopy.localized(zh: "快捷指令", ja: "ショートカット", en: "Shortcuts")
        case "clipboard": return WidgetCopy.localized(zh: "剪贴板", ja: "クリップボード", en: "Clipboard")
        case "camera": return WidgetCopy.localized(zh: "拍照识别", ja: "カメラ認識", en: "Camera")
        default: return rawValue
        }
    }

    private static func displayName(for transaction: WidgetTransaction) -> String {
        let merchant = transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if !merchant.isEmpty {
            return merchant
        }

        let category = categoryTitle(transaction.category).trimmingCharacters(in: .whitespacesAndNewlines)
        if !category.isEmpty {
            return category
        }

        let source = sourceTitle(transaction.source).trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty {
            return source
        }

        return WidgetCopy.localized(zh: "待确认", ja: "確認待ち", en: "Needs Review")
    }

    nonisolated(unsafe) private static let storageFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct WidgetTransaction {
    let merchant: String
    let amount: Double
    let category: String
    let source: String
    let occurredAt: Date
}

private struct WidgetSubscription {
    let merchant: String
    let planName: String
    let amount: Double
    let nextChargedAt: Date

    var displayName: String {
        let trimmedPlan = planName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPlan.isEmpty ? merchant : "\(merchant) \(trimmedPlan)"
    }
}

private struct DailyExpenseEntry: TimelineEntry {
    let date: Date
    let metrics: WidgetLedgerMetrics
}

private struct MonthlyReportEntry: TimelineEntry {
    let date: Date
    let metrics: WidgetLedgerMetrics
}

private struct DailyExpenseProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyExpenseEntry {
        DailyExpenseEntry(
            date: .now,
            metrics: WidgetLedgerMetrics(
                ledgerScope: .defaultLocal,
                todayTotal: 68.5,
                todayCount: 3,
                latestMerchant: "Example Supermarket",
                monthTotal: 1250.8,
                monthCount: 26,
                recentTransactions: [
                    WidgetTransaction(merchant: "Example Supermarket", amount: 68.5, category: "groceries", source: "manual", occurredAt: .now)
                ],
                upcomingSubscriptions: [
                    WidgetSubscription(merchant: "iCloud+", planName: "2 TB", amount: 68, nextChargedAt: .now.addingTimeInterval(86_400 * 3))
                ],
                topMerchant: "Example Supermarket",
                topCategory: "日用杂货",
                updatedAt: .now,
                isSnapshotStale: false
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyExpenseEntry) -> Void) {
        completion(DailyExpenseEntry(date: .now, metrics: WidgetLedgerStore.loadMetrics()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyExpenseEntry>) -> Void) {
        let entry = DailyExpenseEntry(date: .now, metrics: WidgetLedgerStore.loadMetrics())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private struct MonthlyReportProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthlyReportEntry {
        MonthlyReportEntry(
            date: .now,
            metrics: WidgetLedgerMetrics(
                ledgerScope: .defaultLocal,
                todayTotal: 68.5,
                todayCount: 3,
                latestMerchant: "Example Supermarket",
                monthTotal: 1250.8,
                monthCount: 26,
                recentTransactions: [
                    WidgetTransaction(merchant: "Example Supermarket", amount: 68.5, category: "groceries", source: "manual", occurredAt: .now)
                ],
                upcomingSubscriptions: [
                    WidgetSubscription(merchant: "iCloud+", planName: "2 TB", amount: 68, nextChargedAt: .now.addingTimeInterval(86_400 * 3))
                ],
                topMerchant: "Example Supermarket",
                topCategory: "日用杂货",
                updatedAt: .now,
                isSnapshotStale: false
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthlyReportEntry) -> Void) {
        completion(MonthlyReportEntry(date: .now, metrics: WidgetLedgerStore.loadMetrics()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthlyReportEntry>) -> Void) {
        let entry = MonthlyReportEntry(date: .now, metrics: WidgetLedgerStore.loadMetrics())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private struct DailyExpenseWidgetView: View {
    let entry: DailyExpenseEntry
    @Environment(\.widgetFamily) private var family

    @ViewBuilder
    var body: some View {
        switch family {
        case .accessoryInline:
            accessoryInline
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        default:
            systemSmall
        }
    }

    private var accessoryInline: some View {
        Text(String(format: WidgetCopy.watchAccessoryInlineFormat, compactCurrency(entry.metrics.todayTotal)))
            .widgetAccentable()
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Text(compactCurrency(entry.metrics.todayTotal))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(String(format: WidgetCopy.watchAccessoryCountFormat, entry.metrics.todayCount))
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(4)
        }
        .widgetAccentable()
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(WidgetCopy.todayExpenseTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(compactCurrency(entry.metrics.todayTotal))
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(String(format: WidgetCopy.todaySummaryCountFormat, entry.metrics.todayCount))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .widgetAccentable()
    }

    private var systemSmall: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let compact = size.height < 160
            let horizontalPadding = compact ? 12.0 : 14.0
            let topPadding = compact ? 8.0 : 9.0
            let bottomPadding = compact ? 10.0 : 12.0
            let headerFont = compact ? 13.0 : 14.0
            let amountFont = compact ? 26.0 : 30.0
            let merchantFont = compact ? 13.0 : 15.0
            let cardPaddingX = compact ? 9.0 : 10.0
            let cardPaddingY = compact ? 6.0 : 8.0

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.075, green: 0.13, blue: 0.245), Color(red: 0.10, green: 0.34, blue: 0.47)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: compact ? 96 : 120, height: compact ? 96 : 120)
                        .blur(radius: compact ? 14 : 18)
                        .offset(x: -22, y: compact ? -36 : -44)
                }

                VStack(alignment: .leading, spacing: compact ? 7 : 9) {
                    HStack(spacing: 8) {
                        Text(WidgetCopy.todayExpenseTitle)
                            .font(.system(size: headerFont, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 4)
                        smallBadge(
                            icon: entry.metrics.isSnapshotStale ? "exclamationmark.icloud" : "list.bullet.clipboard.fill",
                            text: entry.metrics.isSnapshotStale
                                ? WidgetCopy.staleSnapshotShort
                                : String(format: WidgetCopy.todayCountCompactFormat, max(entry.metrics.todayCount, 0)),
                            compact: compact
                        )
                    }

                    Spacer(minLength: compact ? 1 : 2)

                    if entry.metrics.todayCount == 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(WidgetCopy.noExpenseTitle)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text(WidgetCopy.noExpenseDetail)
                                .font(.system(size: compact ? 11 : 12))
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(compact ? 2 : 3)
                        }
                    } else {
                        Text(currency(entry.metrics.todayTotal))
                            .font(.system(size: amountFont, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.64)
                            .lineLimit(1)

                        if let latestMerchant = entry.metrics.latestMerchant, !latestMerchant.isEmpty {
                            VStack(alignment: .leading, spacing: compact ? 4 : 5) {
                                Text(WidgetCopy.latestExpenseTitle)
                                    .font(.system(size: compact ? 10 : 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.68))
                                    .lineLimit(1)
                                Text(latestMerchant)
                                    .font(.system(size: merchantFont, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.96))
                                    .lineLimit(compact ? 2 : 3)
                                    .minimumScaleFactor(0.74)
                            }
                            .padding(.horizontal, cardPaddingX)
                            .padding(.vertical, cardPaddingY)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.075, green: 0.13, blue: 0.245), Color(red: 0.10, green: 0.34, blue: 0.47)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func compactCurrency(_ value: Double) -> String {
        if value >= 10_000 {
            return String(format: "¥%.1f万", value / 10_000)
        }
        if value >= 1_000 {
            return String(format: "¥%.0f", value)
        }
        return String(format: "¥%.0f", value)
    }

    private func smallBadge(icon: String, text: String, compact: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
            Text(text)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, compact ? 7 : 8)
        .padding(.vertical, compact ? 4 : 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "¥0.00"
    }
}

private struct MonthlyReportWidgetView: View {
    let entry: MonthlyReportEntry

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let compact = size.height < 170 || size.width < 340
            let horizontalPadding = compact ? 14.0 : 16.0
            let topPadding = compact ? 12.0 : 14.0
            let bottomPadding = compact ? 12.0 : 14.0
            let amountSize = compact ? 28.0 : 33.0
            let cardSpacing = compact ? 8.0 : 10.0
            let contentSpacing = compact ? 9.0 : 11.0

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.98, green: 0.985, blue: 1.0), Color(red: 0.92, green: 0.95, blue: 0.99)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color(red: 0.21, green: 0.50, blue: 0.89).opacity(0.10))
                        .frame(width: compact ? 136 : 170, height: compact ? 136 : 170)
                        .blur(radius: compact ? 18 : 22)
                        .offset(x: compact ? 28 : 36, y: compact ? -38 : -48)
                }

                VStack(alignment: .leading, spacing: contentSpacing) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WidgetCopy.monthReportTitle)
                                .font(.system(size: compact ? 25 : 29, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.88))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }

                        Spacer(minLength: 6)

                        VStack(alignment: .trailing, spacing: 5) {
                            quickAddButton(compact: compact)

                            Text(shortUpdateTime(entry.metrics.updatedAt, isStale: entry.metrics.isSnapshotStale))
                                .font(.system(size: compact ? 9 : 10, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.48))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }

                    if entry.metrics.monthCount == 0 {
                        Spacer()
                        VStack(alignment: .leading, spacing: 6) {
                            Text(WidgetCopy.noMonthDataTitle)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.black.opacity(0.86))
                            Text(WidgetCopy.noMonthDataDetail)
                                .font(.caption)
                                .foregroundStyle(Color.black.opacity(0.55))
                                .lineLimit(2)
                        }
                        Spacer()
                    } else {
                        HStack(alignment: .bottom, spacing: 12) {
                            VStack(alignment: .leading, spacing: compact ? 5 : 6) {
                                Text(currency(entry.metrics.monthTotal))
                                    .font(.system(size: amountSize, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.black.opacity(0.94))
                                    .minimumScaleFactor(0.68)
                                    .lineLimit(1)

                                Text(String(format: WidgetCopy.monthSummaryCountFormat, entry.metrics.monthCount))
                                    .font(.system(size: compact ? 13 : 14, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.52))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }

                        HStack(spacing: cardSpacing) {
                            compactMetric(
                                title: WidgetCopy.topCategoryTitle,
                                value: topCategorySummary,
                                icon: "tag.fill",
                                accent: Color(red: 0.17, green: 0.44, blue: 0.77),
                                compact: compact
                            )
                            compactMetric(
                                title: WidgetCopy.recentTransactionsTitle,
                                value: recentTransactionSummary,
                                icon: "list.bullet.rectangle.portrait",
                                accent: Color(red: 0.10, green: 0.58, blue: 0.50),
                                compact: compact
                            )
                            compactMetric(
                                title: WidgetCopy.upcomingSubscriptionsTitle,
                                value: upcomingSubscriptionSummary,
                                icon: "calendar.badge.clock",
                                accent: Color(red: 0.66, green: 0.35, blue: 0.12),
                                compact: compact
                            )
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.985, blue: 1.0), Color(red: 0.92, green: 0.95, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func quickAddButton(compact: Bool) -> some View {
        Link(destination: WidgetDeepLink.quickAddURL) {
            HStack(spacing: compact ? 4 : 5) {
                Image(systemName: "plus")
                    .font(.system(size: compact ? 8 : 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: compact ? 16 : 18, height: compact ? 16 : 18)
                    .background(
                        Circle()
                            .fill(Color(red: 0.10, green: 0.45, blue: 0.36))
                    )

                Text(WidgetCopy.quickAddTitle)
                    .font(.system(size: compact ? 10 : 11, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Image(systemName: "chevron.right")
                    .font(.system(size: compact ? 7 : 8, weight: .bold))
                    .opacity(0.78)
            }
            .foregroundStyle(Color(red: 0.08, green: 0.36, blue: 0.29))
            .padding(.leading, compact ? 6 : 7)
            .padding(.trailing, compact ? 7 : 8)
            .padding(.vertical, compact ? 5 : 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(red: 0.86, green: 0.98, blue: 0.91).opacity(0.98))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color(red: 0.43, green: 0.74, blue: 0.58).opacity(0.34), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0.09, green: 0.35, blue: 0.28).opacity(0.18), radius: 8, x: 0, y: 3)
            )
        }
        .accessibilityLabel(WidgetCopy.quickAddTitle)
    }

    private var topCategorySummary: String {
        entry.metrics.topCategory ?? WidgetCopy.fallbackCategory
    }

    private var recentTransactionSummary: String {
        guard let transaction = entry.metrics.recentTransactions.first else {
            return WidgetCopy.noRecentTransactionTitle
        }
        let merchant = transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return merchant.isEmpty ? currency(transaction.amount) : merchant
    }

    private var upcomingSubscriptionSummary: String {
        guard let subscription = entry.metrics.upcomingSubscriptions.first else {
            return WidgetCopy.noUpcomingSubscriptionTitle
        }
        return "\(subscription.displayName) \(shortDate(subscription.nextChargedAt))"
    }

    private func compactMetric(title: String, value: String, icon: String, accent: Color, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 9 : 10, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: compact ? 9 : 10, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Text(value)
                .font(.system(size: compact ? 12 : 13, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 7 : 8)
        .background(
            RoundedRectangle(cornerRadius: compact ? 11 : 13, style: .continuous)
                .fill(.white.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 11 : 13, style: .continuous)
                        .stroke(.white.opacity(0.55), lineWidth: 1)
                )
        )
    }

    private func summaryBlock(title: String, value: String, icon: String, accent: Color, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(.system(size: compact ? 15 : 17, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(accent)
                .frame(height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 9 : 11)
        .background(
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                .fill(.white.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                        .stroke(.white.opacity(0.55), lineWidth: 1)
                )
        )
    }

    private func shortUpdateTime(_ date: Date, isStale: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm"
        let prefix = isStale ? WidgetCopy.staleSnapshotUpdatedPrefix : WidgetCopy.updatedPrefix
        return "\(prefix) \(formatter.string(from: date))"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "¥0.00"
    }
}

struct DailyExpenseWidget: Widget {
    let kind = "top.darkrio326.AutoLedger.widgets.daily-expense"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyExpenseProvider()) { entry in
            DailyExpenseWidgetView(entry: entry)
                .widgetURL(WidgetDeepLink.todayLedgerURL)
        }
        .configurationDisplayName(WidgetCopy.todayExpenseTitle)
        .description(WidgetCopy.todayExpenseTitle)
        .supportedFamilies([.systemSmall, .accessoryInline, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct MonthlyReportWidget: Widget {
    let kind = "top.darkrio326.AutoLedger.widgets.monthly-report"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthlyReportProvider()) { entry in
            MonthlyReportWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetCopy.monthReportTitle)
        .description(WidgetCopy.monthReportTitle)
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    DailyExpenseWidget()
} timeline: {
    DailyExpenseEntry(
        date: .now,
        metrics: WidgetLedgerMetrics(
            ledgerScope: .defaultLocal,
            todayTotal: 68.5,
            todayCount: 3,
            latestMerchant: "Example Supermarket",
            monthTotal: 1250.8,
            monthCount: 26,
            recentTransactions: [
                WidgetTransaction(merchant: "Example Supermarket", amount: 68.5, category: "groceries", source: "manual", occurredAt: .now)
            ],
            upcomingSubscriptions: [
                WidgetSubscription(merchant: "iCloud+", planName: "2 TB", amount: 68, nextChargedAt: .now.addingTimeInterval(86_400 * 3))
            ],
            topMerchant: "Example Supermarket",
            topCategory: "日用杂货",
            updatedAt: .now,
            isSnapshotStale: false
        )
    )
}

#Preview(as: .accessoryRectangular) {
    DailyExpenseWidget()
} timeline: {
    DailyExpenseEntry(
        date: .now,
        metrics: WidgetLedgerMetrics(
            ledgerScope: .defaultLocal,
            todayTotal: 68.5,
            todayCount: 3,
            latestMerchant: "Example Supermarket",
            monthTotal: 1250.8,
            monthCount: 26,
            recentTransactions: [
                WidgetTransaction(merchant: "Example Supermarket", amount: 68.5, category: "groceries", source: "manual", occurredAt: .now)
            ],
            upcomingSubscriptions: [
                WidgetSubscription(merchant: "iCloud+", planName: "2 TB", amount: 68, nextChargedAt: .now.addingTimeInterval(86_400 * 3))
            ],
            topMerchant: "Example Supermarket",
            topCategory: "日用杂货",
            updatedAt: .now,
            isSnapshotStale: false
        )
    )
}

#Preview(as: .systemMedium) {
    MonthlyReportWidget()
} timeline: {
    MonthlyReportEntry(
        date: .now,
        metrics: WidgetLedgerMetrics(
            ledgerScope: .defaultLocal,
            todayTotal: 68.5,
            todayCount: 3,
            latestMerchant: "Example Supermarket",
            monthTotal: 1250.8,
            monthCount: 26,
            recentTransactions: [
                WidgetTransaction(merchant: "Example Supermarket", amount: 68.5, category: "groceries", source: "manual", occurredAt: .now)
            ],
            upcomingSubscriptions: [
                WidgetSubscription(merchant: "iCloud+", planName: "2 TB", amount: 68, nextChargedAt: .now.addingTimeInterval(86_400 * 3))
            ],
            topMerchant: "Example Supermarket",
            topCategory: "日用杂货",
            updatedAt: .now,
            isSnapshotStale: false
        )
    )
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
