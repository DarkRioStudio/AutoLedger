import Foundation
import SQLite3
import SwiftUI
import WidgetKit

private enum WidgetCopy {
    static var todayExpenseTitle: String { isChinese ? "今日支出" : "Today's Spend" }
    static var monthReportTitle: String { isChinese ? "当月月报" : "Monthly Report" }
    static var topMerchantTitle: String { isChinese ? "Top 商户" : "Top Merchant" }
    static var topCategoryTitle: String { isChinese ? "Top 分类" : "Top Category" }
    static var latestExpenseTitle: String { isChinese ? "最近一笔" : "Latest" }
    static var noExpenseTitle: String { isChinese ? "今天还没记账" : "No expenses today" }
    static var noExpenseDetail: String { isChinese ? "打开 App 记录今天的第一笔支出" : "Open the app to log your first expense" }
    static var noMonthDataTitle: String { isChinese ? "本月还没有账单" : "No entries this month" }
    static var noMonthDataDetail: String { isChinese ? "开始记录后，这里会显示月度摘要" : "Your monthly summary will appear here" }
    static var updatedPrefix: String { isChinese ? "更新于" : "Updated" }
    static var thisMonthLabel: String { isChinese ? "本月" : "This Month" }
    static var monthSummaryCountFormat: String { isChinese ? "%d 笔记录" : "%d entries" }
    static var todaySummaryCountFormat: String { isChinese ? "今日共 %d 笔" : "%d today" }
    static var todayCountCompactFormat: String { isChinese ? "%d 笔" : "%d items" }
    static var fallbackMerchant: String { isChinese ? "暂无" : "None" }
    static var fallbackCategory: String { isChinese ? "暂无" : "None" }

    fileprivate static var isChinese: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
    }
}

private struct WidgetLedgerMetrics {
    let todayTotal: Double
    let todayCount: Int
    let latestMerchant: String?
    let monthTotal: Double
    let monthCount: Int
    let topMerchant: String?
    let topCategory: String?
    let updatedAt: Date

    static let empty = WidgetLedgerMetrics(
        todayTotal: 0,
        todayCount: 0,
        latestMerchant: nil,
        monthTotal: 0,
        monthCount: 0,
        topMerchant: nil,
        topCategory: nil,
        updatedAt: .now
    )
}

private enum WidgetLedgerStore {
    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let databaseFolder = "AutoLedger"
    private static let databaseFilename = "autoledger.sqlite3"

    static func loadMetrics(referenceDate: Date = .now) -> WidgetLedgerMetrics {
        guard let dbURL = databaseURL(),
              FileManager.default.fileExists(atPath: dbURL.path) else {
            return .empty
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return .empty
        }
        defer { sqlite3_close(db) }

        let calendar = Calendar(identifier: .gregorian)
        let todayStart = calendar.startOfDay(for: referenceDate)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? referenceDate
        let monthInterval = calendar.dateInterval(of: .month, for: referenceDate)
        let monthStart = monthInterval?.start ?? todayStart
        let monthEnd = monthInterval?.end ?? tomorrowStart

        let todayTransactions = loadTransactions(db: db, from: todayStart, to: tomorrowStart)
        let monthTransactions = loadTransactions(db: db, from: monthStart, to: monthEnd)

        let todayTotal = todayTransactions.reduce(0) { $0 + $1.amount }
        let monthTotal = monthTransactions.reduce(0) { $0 + $1.amount }
        let topMerchant = groupedTopName(from: monthTransactions, keyPath: \.merchant)
        let topCategory = groupedTopName(from: monthTransactions, keyPath: \.category).map(categoryTitle)

        return WidgetLedgerMetrics(
            todayTotal: todayTotal,
            todayCount: todayTransactions.count,
            latestMerchant: todayTransactions.first?.merchant,
            monthTotal: monthTotal,
            monthCount: monthTransactions.count,
            topMerchant: topMerchant,
            topCategory: topCategory,
            updatedAt: referenceDate
        )
    }

    private static func databaseURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(databaseFolder, isDirectory: true)
            .appendingPathComponent(databaseFilename)
    }

    private static func loadTransactions(db: OpaquePointer?, from start: Date, to end: Date) -> [WidgetTransaction] {
        let sql = """
        SELECT merchant, amount, category, occurred_at
        FROM transactions
        WHERE deleted_at IS NULL
          AND occurred_at >= ?
          AND occurred_at < ?
        ORDER BY occurred_at DESC, created_at DESC;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        sqlite3_bind_text(statement, 1, storageDateTime(start), -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, storageDateTime(end), -1, sqliteTransient)

        var items: [WidgetTransaction] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let merchantCString = sqlite3_column_text(statement, 0),
                let categoryCString = sqlite3_column_text(statement, 2),
                let occurredCString = sqlite3_column_text(statement, 3)
            else {
                continue
            }

            let merchant = String(cString: merchantCString)
            let category = String(cString: categoryCString)
            let amount = sqlite3_column_double(statement, 1)
            let occurredAt = parseStorageDate(String(cString: occurredCString)) ?? start

            items.append(
                WidgetTransaction(
                    merchant: merchant,
                    amount: amount,
                    category: category,
                    occurredAt: occurredAt
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private static func parseStorageDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }

    private static func categoryTitle(_ rawValue: String) -> String {
        switch rawValue {
        case "groceries": return WidgetCopy.isChinese ? "日用杂货" : "Groceries"
        case "dining": return WidgetCopy.isChinese ? "餐饮" : "Dining"
        case "transport": return WidgetCopy.isChinese ? "出行" : "Transport"
        case "shopping": return WidgetCopy.isChinese ? "购物" : "Shopping"
        case "digital": return WidgetCopy.isChinese ? "数字服务" : "Digital"
        case "utilities": return WidgetCopy.isChinese ? "生活缴费" : "Utilities"
        case "entertainment": return WidgetCopy.isChinese ? "娱乐" : "Entertainment"
        case "other": return WidgetCopy.isChinese ? "其他" : "Other"
        default: return rawValue
        }
    }
}

private struct WidgetTransaction {
    let merchant: String
    let amount: Double
    let category: String
    let occurredAt: Date
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
                todayTotal: 68.5,
                todayCount: 3,
                latestMerchant: "盒马鲜生",
                monthTotal: 1250.8,
                monthCount: 26,
                topMerchant: "盒马鲜生",
                topCategory: "日用杂货",
                updatedAt: .now
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
                todayTotal: 68.5,
                todayCount: 3,
                latestMerchant: "盒马鲜生",
                monthTotal: 1250.8,
                monthCount: 26,
                topMerchant: "盒马鲜生",
                topCategory: "日用杂货",
                updatedAt: .now
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

    var body: some View {
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
                            icon: "list.bullet.clipboard.fill",
                            text: String(format: WidgetCopy.todayCountCompactFormat, max(entry.metrics.todayCount, 0)),
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

                VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WidgetCopy.monthReportTitle)
                                .font(.system(size: compact ? 25 : 29, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.88))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }

                        Spacer(minLength: 6)

                        Text(shortUpdateTime(entry.metrics.updatedAt))
                            .font(.system(size: compact ? 10 : 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.48))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, compact ? 7 : 8)
                            .padding(.vertical, compact ? 4 : 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(.white.opacity(0.72))
                            )
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
                            VStack(alignment: .leading, spacing: compact ? 6 : 7) {
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
                            summaryBlock(
                                title: WidgetCopy.topMerchantTitle,
                                value: entry.metrics.topMerchant ?? WidgetCopy.fallbackMerchant,
                                icon: "building.2.crop.circle",
                                accent: Color(red: 0.17, green: 0.44, blue: 0.77),
                                compact: compact
                            )
                            summaryBlock(
                                title: WidgetCopy.topCategoryTitle,
                                value: entry.metrics.topCategory ?? WidgetCopy.fallbackCategory,
                                icon: "square.grid.2x2.fill",
                                accent: Color(red: 0.10, green: 0.58, blue: 0.50),
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

    private func shortUpdateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm"
        return "\(WidgetCopy.updatedPrefix) \(formatter.string(from: date))"
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
        }
        .configurationDisplayName(WidgetCopy.todayExpenseTitle)
        .description(WidgetCopy.todayExpenseTitle)
        .supportedFamilies([.systemSmall])
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
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    DailyExpenseWidget()
} timeline: {
    DailyExpenseEntry(
        date: .now,
        metrics: WidgetLedgerMetrics(
            todayTotal: 68.5,
            todayCount: 3,
            latestMerchant: "盒马鲜生",
            monthTotal: 1250.8,
            monthCount: 26,
            topMerchant: "盒马鲜生",
            topCategory: "日用杂货",
            updatedAt: .now
        )
    )
}

#Preview(as: .systemMedium) {
    MonthlyReportWidget()
} timeline: {
    MonthlyReportEntry(
        date: .now,
        metrics: WidgetLedgerMetrics(
            todayTotal: 68.5,
            todayCount: 3,
            latestMerchant: "盒马鲜生",
            monthTotal: 1250.8,
            monthCount: 26,
            topMerchant: "盒马鲜生",
            topCategory: "日用杂货",
            updatedAt: .now
        )
    )
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
