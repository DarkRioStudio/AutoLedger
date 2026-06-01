import Foundation

/// Watch 侧轻量账单模型（不依赖 AutoLedgerCore，仅用于 Watch UI 展示与消息传递）。
struct WatchTransaction: Identifiable, Hashable {
    let id: UUID
    let merchant: String
    let amount: Double
    let category: String
    let source: String
    let note: String
    let occurredAt: Date

    init(
        id: UUID = UUID(),
        merchant: String,
        amount: Double,
        category: String = "",
        source: String = "",
        note: String = "",
        occurredAt: Date = .now
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
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
        self.category = dict["category"] as? String ?? ""
        self.source = dict["source"] as? String ?? ""
        self.note = dict["note"] as? String ?? ""
        self.occurredAt = Date(timeIntervalSince1970: ts)
    }

    var formattedAmount: String {
        String(format: "¥%.2f", amount)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: occurredAt)
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: occurredAt)
    }

    var formattedDetailDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: occurredAt)
    }

    var relativeDateText: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(occurredAt) {
            return String(localized: "watch.date.today")
        }
        if calendar.isDateInYesterday(occurredAt) {
            return String(localized: "watch.date.yesterday")
        }
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f.string(from: occurredAt)
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
    var transactionCount: Int
    var recentDisplayName: String?
    var updatedAt: Date?

    static let empty = WatchTodaySummary(
        ledgerName: String(localized: "watch.today.default_ledger"),
        totalExpense: 0,
        transactionCount: 0,
        recentDisplayName: nil,
        updatedAt: nil
    )

    init(
        ledgerName: String,
        totalExpense: Double,
        transactionCount: Int,
        recentDisplayName: String?,
        updatedAt: Date?
    ) {
        self.ledgerName = ledgerName
        self.totalExpense = totalExpense
        self.transactionCount = transactionCount
        self.recentDisplayName = recentDisplayName
        self.updatedAt = updatedAt
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
        self.transactionCount = transactionCount

        let recent = (dict["recentDisplayName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.recentDisplayName = recent?.isEmpty == false ? recent : nil

        if let ts = dict["updatedAt"] as? Double {
            self.updatedAt = Date(timeIntervalSince1970: ts)
        } else {
            self.updatedAt = nil
        }
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
            transactionCount: today.count,
            recentDisplayName: today.first?.merchant,
            updatedAt: today.isEmpty ? nil : Date()
        )
    }

    var isEmpty: Bool {
        transactionCount == 0
    }

    var formattedAmount: String {
        String(format: "¥%.2f", totalExpense)
    }

    var formattedUpdatedAt: String? {
        guard let updatedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: updatedAt)
    }
}
