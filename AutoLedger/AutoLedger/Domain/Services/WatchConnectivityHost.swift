import AutoLedgerCore
import Foundation
import WatchConnectivity

/// iPhone 侧 WatchConnectivity 会话主机。
///
/// 职责：
/// 1. 接收来自 Apple Watch 的 `addTransaction` 消息，直接构建 `Transaction` 并写入 `LedgerStore`。
/// 2. 响应 Watch 的 `fetchRecent` 请求，返回今日支出摘要与最近 20 条账单。
/// 3. 在 App 进入前台时主动向 Watch 推送 `syncTransactions` 消息。
@MainActor
final class WatchConnectivityHost: NSObject {

    static let shared = WatchConnectivityHost()
    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let ledgerSnapshotUpdatedAtKey = "ledgerSnapshotUpdatedAt"
    private static let lastSuccessfulCloudKitSyncAtKey = "lastSuccessfulCloudKitSyncAt"
    private static let ledgerCloudSyncEnabledKey = "ledgerCloudSyncEnabled"

    // MARK: - Init

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Public API

    /// App 进入前台或账单变化时调用：将最近 20 条账单同步给 Watch。
    func pushRecentTransactionsIfReachable() {
        guard canPushSnapshotToWatch else { return }
        recordFallbackSnapshotUpdatedAtIfNeeded()
        let payload = makeSyncPayload()

        do {
            try WCSession.default.updateApplicationContext(payload)
        } catch {
            // sendMessage below still covers the foreground reachable case.
        }

        queueBackgroundSnapshotTransfer(payload)

        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            payload,
            replyHandler: nil,
            errorHandler: nil
        )
    }

    // MARK: - Private helpers

    private var canPushSnapshotToWatch: Bool {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else {
            return false
        }

        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else {
            return false
        }
        #endif

        return true
    }

    /// 将 Transaction 序列化为 Watch 侧 WatchTransaction.init?(from:) 可反序列化的字典。
    private func serialize(_ t: Transaction) -> [String: Any] {
        [
            "merchant": t.merchant,
            "amount": t.amount,
            "category": t.categoryTitle,
            "source": t.sourceTitle,
            "note": t.note,
            "occurredAt": t.occurredAt.timeIntervalSince1970
        ]
    }

    private func makeRecentPayload() -> [[String: Any]] {
        currentTransactions().prefix(20).map { serialize($0) }
    }

    private func makeTodaySummaryPayload() -> [String: Any] {
        let summary = TodaySpendingSummary.build(from: currentTransactions(), referenceDate: .now)
        let metadata = makeSnapshotMetadata()
        let snapshotUpdatedAt = metadata["snapshotUpdatedAt"] as? Double ?? Date().timeIntervalSince1970
        var payload: [String: Any] = [
            "ledgerName": summary.ledgerName,
            "totalExpense": summary.totalExpense,
            "transactionCount": summary.transactionCount,
            "updatedAt": snapshotUpdatedAt,
            "isSnapshotStale": metadata["isSnapshotStale"] as? Bool ?? false
        ]

        if let lastCloudSyncAt = metadata["lastCloudSyncAt"] as? Double {
            payload["lastCloudSyncAt"] = lastCloudSyncAt
        }

        if let recentDisplayName = summary.recentDisplayName {
            payload["recentDisplayName"] = recentDisplayName
        }

        return payload
    }

    private func makeSyncPayload() -> [String: Any] {
        [
            "action": "syncTransactions",
            "transactions": makeRecentPayload(),
            "todaySummary": makeTodaySummaryPayload(),
            "customCategories": currentCustomCategories()
        ]
    }

    private func currentTransactions() -> [Transaction] {
        if let store = LedgerStore.shared {
            return store.transactions
        }
        return ((try? SQLiteTransactionStore().loadTransactions()) ?? [])
            .sorted { lhs, rhs in
                return lhs.occurredAt > rhs.occurredAt
            }
    }

    private func currentCustomCategories() -> [String] {
        if let store = LedgerStore.shared {
            return store.customCategories
        }
        return UserDefaults.standard.stringArray(forKey: "customCategories") ?? []
    }

    private func makeSnapshotMetadata(referenceDate: Date = Date()) -> [String: Any] {
        if let store = LedgerStore.shared {
            return store.ledgerDisplaySnapshotMetadata
        }

        let defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
        let snapshotUpdatedAt = defaults?.object(forKey: Self.ledgerSnapshotUpdatedAtKey) as? Date ?? referenceDate
        let lastCloudSyncAt = defaults?.object(forKey: Self.lastSuccessfulCloudKitSyncAtKey) as? Date
        let syncEnabled = defaults?.bool(forKey: Self.ledgerCloudSyncEnabledKey) ?? UserDefaults.standard.bool(forKey: Self.ledgerCloudSyncEnabledKey)
        let isSnapshotStale = syncEnabled && (lastCloudSyncAt.map { referenceDate.timeIntervalSince($0) > 12 * 60 * 60 } ?? true)
        var metadata: [String: Any] = [
            "snapshotUpdatedAt": snapshotUpdatedAt.timeIntervalSince1970,
            "isSnapshotStale": isSnapshotStale
        ]
        if let lastCloudSyncAt {
            metadata["lastCloudSyncAt"] = lastCloudSyncAt.timeIntervalSince1970
        }
        return metadata
    }

    private func recordFallbackSnapshotUpdatedAtIfNeeded(_ date: Date = Date()) {
        guard LedgerStore.shared == nil else { return }
        UserDefaults.standard.set(date, forKey: Self.ledgerSnapshotUpdatedAtKey)
        let defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
        defaults?.set(date, forKey: Self.ledgerSnapshotUpdatedAtKey)
        defaults?.set(UserDefaults.standard.bool(forKey: Self.ledgerCloudSyncEnabledKey), forKey: Self.ledgerCloudSyncEnabledKey)
    }

    private func queueBackgroundSnapshotTransfer(_ payload: [String: Any]) {
        _ = WCSession.default.transferUserInfo(payload)
        guard WCSession.default.remainingComplicationUserInfoTransfers > 0 else { return }
        _ = WCSession.default.transferCurrentComplicationUserInfo(payload)
    }

    /// 将 Watch 发来的 addTransaction 字典转换为 Transaction 并保存。
    /// 使用 draftId 作为 Transaction.id 以实现幂等去重（重试不重复入库）。
    private func handleAddTransaction(_ message: [String: Any]) {
        guard
            let merchant = message["merchant"] as? String,
            let amount = message["amount"] as? Double,
            let ts = message["occurredAt"] as? Double
        else { return }

        // 幂等 UUID：draftId → 相同草稿重发时 UUID 相同，SQLite 主键冲突自动去重
        let draftIdStr = message["draftId"] as? String ?? ""
        let txId = UUID(uuidString: draftIdStr) ?? UUID()

        let note = message["note"] as? String ?? ""
        let categoryLabel = message["category"] as? String ?? TransactionCategory.other.rawValue

        let transaction = Transaction(
            id: txId,
            merchant: merchant,
            amount: amount,
            occurredAt: Date(timeIntervalSince1970: ts),
            categoryLabel: categoryLabel,
            sourceLabel: ReceiptSource.manual.rawValue,
            note: note.isEmpty ? "[Watch]" : "[Watch] \(note)"
        )
        LedgerStore.shared?.addTransaction(transaction)
        pushRecentTransactionsIfReachable()
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityHost: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        Task { @MainActor in
            self.pushRecentTransactionsIfReachable()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // 重新激活（用户切换 Apple Watch 后）
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in
            self.pushRecentTransactionsIfReachable()
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        if action == "addTransaction" {
            Task { @MainActor in
                self.handleAddTransaction(message)
            }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        guard let action = message["action"] as? String else {
            replyHandler([:])
            return
        }
        if action == "fetchRecent" {
            Task { @MainActor in
                replyHandler(self.makeSyncPayload())
            }
        } else {
            replyHandler([:])
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        guard let action = userInfo["action"] as? String else { return }
        if action == "fetchRecent" {
            Task { @MainActor in
                self.pushRecentTransactionsIfReachable()
            }
        }
    }
}
