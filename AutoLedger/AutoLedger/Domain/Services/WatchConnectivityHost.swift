import AutoLedgerCore
import Foundation
import WatchConnectivity

/// iPhone 侧 WatchConnectivity 会话主机。
///
/// 职责：
/// 1. 接收来自 Apple Watch 的 `addTransaction` 消息，直接构建 `Transaction` 并写入 `LedgerStore`。
/// 2. 响应 Watch 的 `fetchRecent` 请求，返回今日支出摘要与最近 20 条账单。
/// 3. 在 App 进入前台或账单变化时发布最新 `syncTransactions` 快照。
@MainActor
final class WatchConnectivityHost: NSObject {

    static let shared = WatchConnectivityHost()
    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let ledgerSnapshotUpdatedAtKey = "ledgerSnapshotUpdatedAt"
    private static let lastSuccessfulCloudKitSyncAtKey = "lastSuccessfulCloudKitSyncAt"
    private static let ledgerCloudSyncEnabledKey = "ledgerCloudSyncEnabled"
    private static let defaultWriteLedgerIDKey = "defaultWriteLedgerID"

    private var lastApplicationContextDigest: String?
    private var lastQueuedBackgroundDigest: String?

    // MARK: - Init

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Public API

    /// App 进入前台或账单变化时调用：发布最近 20 条账单给 Watch。
    func publishLatestLedgerSnapshot() {
        guard canPublishSnapshotToWatch else { return }
        recordFallbackSnapshotUpdatedAtIfNeeded()

        var payload = makeSyncPayload()
        let digest = makeSnapshotDigest(from: payload)
        payload["syncID"] = digest
        payload["sentAt"] = Date().timeIntervalSince1970

        publishApplicationContext(payload, digest: digest)
        queueBackgroundSnapshotTransfer(payload, digest: digest)

        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            payload,
            replyHandler: nil,
            errorHandler: nil
        )
    }

    /// 兼容旧调用名：当前实现不只依赖 reachable，也会排队后台快照。
    func pushRecentTransactionsIfReachable() {
        publishLatestLedgerSnapshot()
    }

    // MARK: - Private helpers

    private var canPublishSnapshotToWatch: Bool {
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

    private func publishApplicationContext(_ payload: [String: Any], digest: String) {
        guard digest != lastApplicationContextDigest else { return }
        do {
            try WCSession.default.updateApplicationContext(payload)
            lastApplicationContextDigest = digest
        } catch {
            // Foreground reachable sendMessage and background userInfo still cover the next delivery chance.
        }
    }

    /// 将 Transaction 序列化为 Watch 侧 WatchTransaction.init?(from:) 可反序列化的字典。
    private func serialize(_ t: Transaction) -> [String: Any] {
        [
            "merchant": t.merchant,
            "amount": t.amount,
            "currencyCode": t.ledgerCurrencyCode ?? currentLedgerCurrencyCode(),
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
        let ledgerID = currentLedgerID()
        let summary = TodaySpendingSummary.build(
            from: currentTransactions(),
            referenceDate: .now,
            ledgerID: ledgerID,
            ledgerName: currentLedgerName(for: ledgerID)
        )
        let metadata = makeSnapshotMetadata()
        let snapshotUpdatedAt = metadata["snapshotUpdatedAt"] as? Double ?? Date().timeIntervalSince1970
        var payload: [String: Any] = [
            "ledgerName": summary.ledgerName,
            "totalExpense": summary.totalExpense,
            "currencyCode": currentLedgerCurrencyCode(),
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
        let todaySummary = makeTodaySummaryPayload()
        return [
            "action": "syncTransactions",
            "transactions": makeRecentPayload(),
            "todaySummary": todaySummary,
            "snapshotUpdatedAt": todaySummary["updatedAt"] as? Double ?? Date().timeIntervalSince1970,
            "customCategories": currentCustomCategories()
        ]
    }

    private func makeSnapshotDigest(from payload: [String: Any]) -> String {
        let transactions = payload["transactions"] as? [[String: Any]] ?? []
        let transactionDigest = transactions.map { transaction in
            [
                transaction["occurredAt"] as? Double ?? 0,
                transaction["amount"] as? Double ?? 0,
                transaction["currencyCode"] as? String ?? "",
                transaction["merchant"] as? String ?? "",
                transaction["category"] as? String ?? "",
                transaction["source"] as? String ?? "",
                transaction["note"] as? String ?? ""
            ].map { String(describing: $0) }.joined(separator: ",")
        }.joined(separator: "|")

        let todaySummary = payload["todaySummary"] as? [String: Any] ?? [:]
        let categories = (payload["customCategories"] as? [String] ?? []).joined(separator: "|")
        return [
            String(describing: payload["snapshotUpdatedAt"] as? Double ?? 0),
            String(describing: todaySummary["totalExpense"] as? Double ?? 0),
            todaySummary["currencyCode"] as? String ?? "",
            String(describing: todaySummary["transactionCount"] as? Int ?? 0),
            todaySummary["ledgerName"] as? String ?? "",
            todaySummary["recentDisplayName"] as? String ?? "",
            categories,
            transactionDigest
        ].joined(separator: "#")
    }

    private func currentTransactions() -> [Transaction] {
        let ledgerID = currentLedgerID()
        if let store = LedgerStore.shared {
            return store.transactions.filter { $0.resolvedLedgerID() == ledgerID }
        }
        return ((try? SQLiteTransactionStore().loadTransactions()) ?? [])
            .filter { $0.resolvedLedgerID() == ledgerID }
            .sorted { lhs, rhs in
                return lhs.occurredAt > rhs.occurredAt
            }
    }

    private func currentLedgerID() -> String {
        if let store = LedgerStore.shared {
            return store.defaultWriteLedgerID
        }
        let defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
        let candidate = defaults?.string(forKey: Self.defaultWriteLedgerIDKey) ??
            UserDefaults.standard.string(forKey: Self.defaultWriteLedgerIDKey)
        let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? TodaySpendingSummary.defaultLedgerID : trimmed
    }

    private func currentLedgerName(for ledgerID: String) -> String {
        LedgerStore.shared?.ledgerName(for: ledgerID) ?? TodaySpendingSummary.defaultLedgerName
    }

    private func currentLedgerCurrencyCode() -> String {
        if let store = LedgerStore.shared {
            return store.ledgerCurrencyCode(for: store.defaultWriteLedgerID)
        }
        return ExpenseCurrencyPreference.currentCode
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

    private func queueBackgroundSnapshotTransfer(_ payload: [String: Any], digest: String) {
        guard digest != lastQueuedBackgroundDigest else { return }
        WCSession.default.outstandingUserInfoTransfers
            .filter { ($0.userInfo["action"] as? String) == "syncTransactions" }
            .forEach { $0.cancel() }
        _ = WCSession.default.transferUserInfo(payload)
        lastQueuedBackgroundDigest = digest
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
            note: note.isEmpty ? "[Watch]" : "[Watch] \(note)",
            ledgerID: currentLedgerID(),
            ledgerCurrencyCode: currentLedgerCurrencyCode()
        )
        LedgerStore.shared?.addTransaction(transaction)
        publishLatestLedgerSnapshot()
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityHost: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        Task { @MainActor in
            self.publishLatestLedgerSnapshot()
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
            self.publishLatestLedgerSnapshot()
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
                self.publishLatestLedgerSnapshot()
            }
        }
    }
}
