import AutoLedgerCore
import Foundation

/// Watch 侧记账草稿，支持离线暂存与重试。
struct WatchLedgerDraft: Identifiable, Codable, Sendable {

    let id: UUID
    var merchant: String
    var amount: Double
    var categoryRaw: String
    var note: String
    var occurredAt: Date
    var syncStatus: SyncStatus
    var retryCount: Int

    enum SyncStatus: String, Codable, Sendable {
        case pending
        case synced
        case failed
    }

    var category: TransactionCategory {
        TransactionCategory(rawValue: categoryRaw) ?? .other
    }

    var categoryTitle: String {
        TransactionCategory(rawValue: categoryRaw)?.title ?? categoryRaw
    }

    init(
        merchant: String,
        amount: Double,
        category: TransactionCategory,
        note: String = "",
        occurredAt: Date = .now
    ) {
        self.init(
            merchant: merchant,
            amount: amount,
            categoryRaw: category.rawValue,
            note: note,
            occurredAt: occurredAt
        )
    }

    init(
        merchant: String,
        amount: Double,
        categoryRaw: String,
        note: String = "",
        occurredAt: Date = .now
    ) {
        self.id = UUID()
        self.merchant = merchant
        self.amount = amount
        self.categoryRaw = categoryRaw
        self.note = note
        self.occurredAt = occurredAt
        self.syncStatus = .pending
        self.retryCount = 0
    }

    /// 序列化为 WatchConnectivity 消息字典（iPhone 侧可用 draftId 做幂等去重）。
    func asDictionary() -> [String: Any] {
        [
            "action": "addTransaction",
            "draftId": id.uuidString,
            "merchant": merchant,
            "amount": amount,
            "category": categoryRaw,
            "note": note,
            "occurredAt": occurredAt.timeIntervalSince1970
        ]
    }
}
