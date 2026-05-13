import Foundation

/// Watch 侧轻量账单模型（不依赖 AutoLedgerCore，仅用于 Watch UI 展示与消息传递）。
struct WatchTransaction: Identifiable, Hashable {
    let id: UUID
    let merchant: String
    let amount: Double
    let note: String
    let occurredAt: Date

    init(id: UUID = UUID(), merchant: String, amount: Double, note: String = "", occurredAt: Date = .now) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
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
}
