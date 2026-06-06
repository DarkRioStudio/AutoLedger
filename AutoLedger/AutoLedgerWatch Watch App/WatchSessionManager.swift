import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// Watch 侧 WatchConnectivity 会话管理器。
/// 负责：
///  - 接收来自 iPhone 的 syncTransactions 推送（今日支出摘要与近期账单列表）
///  - 向 iPhone 发送新记账草稿，支持离线 pending 队列与重试
@Observable
@MainActor
final class WatchSessionManager: NSObject {

    static let shared = WatchSessionManager()

    // MARK: - State

    /// 最近从 iPhone 同步的账单摘要（用于 Watch 列表展示）
    private(set) var recentTransactions: [WatchTransaction] = []

    /// 今日支出摘要（用于 Watch 首屏展示）
    private(set) var todaySummary: WatchTodaySummary = .empty

    /// iPhone 端用户自定义分类。
    private(set) var customCategories: [String] = []

    /// iPhone 是否可达
    private(set) var isReachable: Bool = false

    /// 待同步草稿（pending / failed，已 synced 的自动移除）
    private(set) var pendingDrafts: [WatchLedgerDraft] = []

    var pendingCount: Int { pendingDrafts.count }

    @ObservationIgnored
    var onStateChanged: (() -> Void)?

    // MARK: - Private constants

    private static let pendingKey = "WatchLedgerDraftsPending"
    private static let backgroundFetchInterval: TimeInterval = 60
    private static let widgetAppGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let widgetSummaryKey = "WatchLedgerWidget.todaySummary"
    private static let watchDailyWidgetKind = "AutoLedgerWatchDailyExpenseWidget"
    private static let watchCornerTextWidgetKind = "AutoLedgerWatchCornerTextWidget"

    private var lastBackgroundFetchRequestAt: Date?

    // MARK: - Init

    private override init() {
        super.init()
        loadPending()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Public API

    /// 将草稿加入队列并尝试立即发送（离线时暂存，稍后重试）。
    func enqueue(_ draft: WatchLedgerDraft) {
        pendingDrafts.append(draft)
        savePending()
        notifyStateChanged()
        if WCSession.default.isReachable {
            flushPending()
        }
    }

    /// 向 iPhone 请求同步最近账单列表
    func requestRecentTransactions(allowBackgroundFallback: Bool = true) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }

        if !WCSession.default.isReachable {
            if allowBackgroundFallback {
                enqueueBackgroundFetchRequest(force: false)
            }
            return
        }

        WCSession.default.sendMessage(["action": "fetchRecent"], replyHandler: { [weak self] reply in
            Task { @MainActor in
                self?.handleRecentTransactionsReply(reply)
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in
                self?.isReachable = false
                if allowBackgroundFallback {
                    self?.enqueueBackgroundFetchRequest(force: true)
                }
                self?.notifyStateChanged()
            }
        })
    }

    /// Watch 列表为空或分类为空时，主动向 iPhone 拉取一次同步数据。
    func requestInitialSyncIfNeeded() {
        guard recentTransactions.isEmpty || customCategories.isEmpty || todaySummary.updatedAt == nil else { return }
        requestRecentTransactions(allowBackgroundFallback: true)
    }

    /// Watch App 回到前台时，先从表盘小组件共用的 App Group 快照恢复今日支出。
    ///
    /// WidgetKit timeline 可能已经读取到最新快照，但 Watch App 仍停留在旧的
    /// `WatchSessionManager` 内存态；先回灌本地快照，再请求 iPhone 增量同步，可避免
    /// 小组件有数据而 App 首屏显示 0 的短暂分叉。
    func refreshFromWidgetSnapshot() {
        guard
            let defaults = UserDefaults(suiteName: Self.widgetAppGroupIdentifier),
            let snapshot = defaults.dictionary(forKey: Self.widgetSummaryKey),
            let summary = WatchTodaySummary(from: snapshot)
        else { return }

        let snapshotUpdatedAt = summary.updatedAt ?? Date.distantPast
        let currentUpdatedAt = todaySummary.updatedAt ?? Date.distantPast
        guard snapshotUpdatedAt >= currentUpdatedAt || todaySummary.isEmpty else { return }

        todaySummary = summary
        notifyStateChanged()
    }

    // MARK: - Flush / Retry

    /// 当 iPhone 可达时，将所有 pending/failed 草稿重新发送。
    func retryPending() {
        guard !pendingDrafts.isEmpty, WCSession.default.isReachable else { return }
        // Reset failed → pending before flush
        for idx in pendingDrafts.indices where pendingDrafts[idx].syncStatus == .failed {
            pendingDrafts[idx].syncStatus = .pending
        }
        savePending()
        notifyStateChanged()
        flushPending()
    }

    private func flushPending() {
        let toSend = pendingDrafts.filter { $0.syncStatus == .pending }
        for draft in toSend {
            WCSession.default.sendMessage(
                draft.asDictionary(),
                replyHandler: { [weak self] _ in
                    Task { @MainActor in self?.markSynced(draftId: draft.id) }
                },
                errorHandler: { [weak self] _ in
                    Task { @MainActor in self?.markFailed(draftId: draft.id) }
                }
            )
        }
    }

    // MARK: - Status helpers

    private func markSynced(draftId: UUID) {
        pendingDrafts.removeAll { $0.id == draftId }
        savePending()
        notifyStateChanged()
    }

    private func markFailed(draftId: UUID) {
        guard let idx = pendingDrafts.firstIndex(where: { $0.id == draftId }) else { return }
        pendingDrafts[idx].syncStatus = .failed
        pendingDrafts[idx].retryCount += 1
        savePending()
        notifyStateChanged()
    }

    // MARK: - Persistence

    private func savePending() {
        guard let data = try? JSONEncoder().encode(pendingDrafts) else { return }
        UserDefaults.standard.set(data, forKey: Self.pendingKey)
    }

    private func loadPending() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.pendingKey),
            let drafts = try? JSONDecoder().decode([WatchLedgerDraft].self, from: data)
        else { return }
        // 过滤 synced，重置 failed → pending
        pendingDrafts = drafts
            .filter { $0.syncStatus != .synced }
            .map { d in
                var copy = d
                if copy.syncStatus == .failed { copy.syncStatus = .pending }
                return copy
            }
    }

    // MARK: - Private

    private func handleRecentTransactionsReply(_ reply: [String: Any]) {
        guard let list = reply["transactions"] as? [[String: Any]] else { return }
        recentTransactions = list.compactMap { WatchTransaction(from: $0) }
        todaySummary = makeTodaySummary(from: reply)
        customCategories = reply["customCategories"] as? [String] ?? customCategories
        saveWidgetSnapshot()
        notifyStateChanged()
    }

    private func handleSyncPayload(_ payload: [String: Any]) {
        if let list = payload["transactions"] as? [[String: Any]] {
            recentTransactions = list.compactMap { WatchTransaction(from: $0) }
        }
        todaySummary = makeTodaySummary(from: payload)
        customCategories = payload["customCategories"] as? [String] ?? customCategories
        saveWidgetSnapshot()
        notifyStateChanged()
    }

    private func makeTodaySummary(from payload: [String: Any]) -> WatchTodaySummary {
        if let dict = payload["todaySummary"] as? [String: Any],
           let summary = WatchTodaySummary(from: dict) {
            return summary
        }
        return WatchTodaySummary.fallback(from: recentTransactions)
    }

    private func enqueueBackgroundFetchRequest(force: Bool) {
        let now = Date()
        if !force,
           let lastBackgroundFetchRequestAt,
           now.timeIntervalSince(lastBackgroundFetchRequestAt) < Self.backgroundFetchInterval {
            return
        }
        lastBackgroundFetchRequestAt = now
        WCSession.default.transferUserInfo([
            "action": "fetchRecent",
            "requestedAt": now.timeIntervalSince1970
        ])
    }

    private func saveWidgetSnapshot() {
        guard let defaults = UserDefaults(suiteName: Self.widgetAppGroupIdentifier) else { return }
        var snapshot: [String: Any] = [
            "ledgerName": todaySummary.ledgerName,
            "totalExpense": todaySummary.totalExpense,
            "transactionCount": todaySummary.transactionCount,
            "isSnapshotStale": todaySummary.isSnapshotStale,
            "savedAt": Date().timeIntervalSince1970
        ]
        if let recentDisplayName = todaySummary.recentDisplayName {
            snapshot["recentDisplayName"] = recentDisplayName
        }
        if let updatedAt = todaySummary.updatedAt {
            snapshot["updatedAt"] = updatedAt.timeIntervalSince1970
        }
        defaults.set(snapshot, forKey: Self.widgetSummaryKey)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.watchDailyWidgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.watchCornerTextWidgetKind)
    }

    private func notifyStateChanged() {
        onStateChanged?()
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if session.isReachable {
                self.retryPending()
                self.requestRecentTransactions()
            } else {
                self.requestInitialSyncIfNeeded()
            }
            self.notifyStateChanged()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if session.isReachable {
                self.retryPending()
                self.requestRecentTransactions()
            } else {
                self.requestInitialSyncIfNeeded()
            }
            self.notifyStateChanged()
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        if action == "syncTransactions" {
           Task { @MainActor in
                self.handleSyncPayload(message)
            }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let action = applicationContext["action"] as? String,
              action == "syncTransactions" else { return }
        Task { @MainActor in
            self.handleSyncPayload(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let action = userInfo["action"] as? String,
              action == "syncTransactions" else { return }
        Task { @MainActor in
            self.handleSyncPayload(userInfo)
        }
    }
}
