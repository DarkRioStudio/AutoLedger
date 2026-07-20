import Foundation

/// Watch 侧轻量账单模型（不依赖 AutoLedgerCore，仅用于 Watch UI 展示与消息传递）。
struct WatchTransaction: Identifiable, Hashable {
    let id: UUID
    let merchant: String
    let amount: Double
    let currencyCode: String
    let category: String
    let source: String
    let note: String
    let occurredAt: Date

    init(
        id: UUID = UUID(),
        merchant: String,
        amount: Double,
        currencyCode: String = WatchLedgerFormatters.systemCurrencyCode,
        category: String = "",
        source: String = "",
        note: String = "",
        occurredAt: Date = .now
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.currencyCode = WatchLedgerFormatters.resolvedCurrencyCode(currencyCode)
        self.category = category
        self.source = source
        self.note = note
        self.occurredAt = occurredAt
    }

    /// 从 WatchConnectivity 消息字典反序列化。
    init?(from dict: [String: Any]) {
        guard
            let merchant = dict["merchant"] as? String,
            let amount = dict["amount"] as? Double,
            let ts = dict["occurredAt"] as? Double
        else { return nil }
        self.id = UUID()
        self.merchant = merchant
        self.amount = amount
        self.currencyCode = WatchLedgerFormatters.resolvedCurrencyCode(dict["currencyCode"] as? String)
        self.category = dict["category"] as? String ?? ""
        self.source = dict["source"] as? String ?? ""
        self.note = dict["note"] as? String ?? ""
        self.occurredAt = Date(timeIntervalSince1970: ts)
    }

    var formattedAmount: String {
        WatchLedgerFormatters.currency(amount, code: currencyCode)
    }

    var formattedDate: String {
        WatchLedgerFormatters.date(occurredAt, template: "Mdjm")
    }

    var formattedTime: String {
        WatchLedgerFormatters.date(occurredAt, template: "jm")
    }

    var formattedDetailDate: String {
        WatchLedgerFormatters.date(occurredAt, template: "yMMMdjm")
    }

    var relativeDateText: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(occurredAt) {
            return String(localized: "watch.date.today")
        }
        if calendar.isDateInYesterday(occurredAt) {
            return String(localized: "watch.date.yesterday")
        }
        return WatchLedgerFormatters.date(occurredAt, template: "Md")
    }

    var compactDateText: String {
        "\(relativeDateText) \(formattedTime)"
    }

    var displayCategory: String {
        category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(localized: "category.other.title")
            : category
    }

    var displaySource: String {
        source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(localized: "watch.transaction.source_unknown")
            : source
    }

    var displayNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(localized: "watch.transaction.no_note")
            : note
    }
}

/// Watch 侧今日支出摘要，来自 iPhone 的 WatchConnectivity payload。
struct WatchTodaySummary: Equatable, Hashable {
    var ledgerName: String
    var totalExpense: Double
    var currencyCode: String
    var transactionCount: Int
    var recentDisplayName: String?
    var updatedAt: Date?
    var isSnapshotStale: Bool

    static let empty = WatchTodaySummary(
        ledgerName: String(localized: "watch.today.default_ledger"),
        totalExpense: 0,
        currencyCode: WatchLedgerFormatters.systemCurrencyCode,
        transactionCount: 0,
        recentDisplayName: nil,
        updatedAt: nil,
        isSnapshotStale: false
    )

    init(
        ledgerName: String,
        totalExpense: Double,
        currencyCode: String = WatchLedgerFormatters.systemCurrencyCode,
        transactionCount: Int,
        recentDisplayName: String?,
        updatedAt: Date?,
        isSnapshotStale: Bool = false
    ) {
        self.ledgerName = ledgerName
        self.totalExpense = totalExpense
        self.currencyCode = WatchLedgerFormatters.resolvedCurrencyCode(currencyCode)
        self.transactionCount = transactionCount
        self.recentDisplayName = recentDisplayName
        self.updatedAt = updatedAt
        self.isSnapshotStale = isSnapshotStale
    }

    init?(from dict: [String: Any]) {
        guard
            let totalExpense = dict["totalExpense"] as? Double,
            let transactionCount = dict["transactionCount"] as? Int
        else { return nil }

        let ledgerName = (dict["ledgerName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.ledgerName = ledgerName == "本地账本" || ledgerName?.isEmpty != false
            ? String(localized: "watch.today.default_ledger")
            : ledgerName ?? String(localized: "watch.today.default_ledger")
        self.totalExpense = totalExpense
        self.currencyCode = WatchLedgerFormatters.resolvedCurrencyCode(dict["currencyCode"] as? String)
        self.transactionCount = transactionCount

        let recent = (dict["recentDisplayName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.recentDisplayName = recent?.isEmpty == false ? recent : nil

        if let ts = dict["updatedAt"] as? Double {
            self.updatedAt = Date(timeIntervalSince1970: ts)
        } else {
            self.updatedAt = nil
        }
        self.isSnapshotStale = dict["isSnapshotStale"] as? Bool ?? false
    }

    static func fallback(from transactions: [WatchTransaction], referenceDate: Date = .now) -> WatchTodaySummary {
        guard let day = Calendar.autoupdatingCurrent.dateInterval(of: .day, for: referenceDate) else {
            return .empty
        }

        let today = transactions
            .filter { $0.amount > 0 && $0.occurredAt >= day.start && $0.occurredAt < day.end }
            .sorted { $0.occurredAt > $1.occurredAt }

        return WatchTodaySummary(
            ledgerName: String(localized: "watch.today.default_ledger"),
            totalExpense: today.reduce(0) { $0 + $1.amount },
            currencyCode: today.first?.currencyCode ?? WatchLedgerFormatters.systemCurrencyCode,
            transactionCount: today.count,
            recentDisplayName: today.first?.merchant,
            updatedAt: today.isEmpty ? nil : Date(),
            isSnapshotStale: false
        )
    }

    var isEmpty: Bool {
        transactionCount == 0
    }

    var formattedAmount: String {
        WatchLedgerFormatters.currency(totalExpense, code: currencyCode)
    }

    var formattedUpdatedAt: String? {
        guard let updatedAt else { return nil }
        return WatchLedgerFormatters.date(updatedAt, template: "jm")
    }

    var snapshotStatusText: String? {
        guard isSnapshotStale else { return nil }
        return String(localized: "watch.today.snapshot_stale")
    }
}

enum WatchLedgerFormatters {
    static var systemCurrencyCode: String {
        Locale.autoupdatingCurrent.currency?.identifier.uppercased() ?? "USD"
    }

    static func resolvedCurrencyCode(_ value: String?) -> String {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        return normalized.count == 3 ? normalized : systemCurrencyCode
    }

    static func currency(_ amount: Double, code: String?) -> String {
        let resolvedCode = resolvedCurrencyCode(code)
        let digits = ["JPY", "KRW", "VND", "IDR"].contains(resolvedCode) ? 0 : 2
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .currency
        formatter.currencyCode = resolvedCode
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: amount)) ?? "\(resolvedCode) \(amount)"
    }

    static func currencySymbol(code: String?) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .currency
        formatter.currencyCode = resolvedCurrencyCode(code)
        return formatter.currencySymbol ?? resolvedCurrencyCode(code)
    }

    static func decimal(_ amount: Double, code: String?) -> String {
        let resolvedCode = resolvedCurrencyCode(code)
        let digits = ["JPY", "KRW", "VND", "IDR"].contains(resolvedCode) ? 0 : 2
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }

    static func date(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
