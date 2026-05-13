import Foundation
import WatchConnectivity

/// Watch 侧 WatchConnectivity 会话管理器。
/// 负责：
///  - 接收来自 iPhone 的 syncTransactions 推送（近期账单列表）
///  - 向 iPhone 发送新记账草稿，支持离线 pending 队列与重试
@Observable
@MainActor
final class WatchSessionManager: NSObject {

    static let shared = WatchSessionManager()

    // MARK: - State

    /// 最近从 iPhone 同步的账单摘要（用于 Watch 列表展示）
    private(set) var recentTransactions: [WatchTransaction] = []

    /// iPhone 是否可达
    private(set) var isReachable: Bool = false

    /// 待同步草稿（pending / failed，已 synced 的自动移除）
    private(set) var pendingDrafts: [WatchLedgerDraft] = []

    var pendingCount: Int { pendingDrafts.count }

    // MARK: - Private constants

    private static let pendingKey = "WatchLedgerDraftsPending"

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
        if WCSession.default.isReachable {
            flushPending()
        }
    }

    /// 向 iPhone 请求同步最近账单列表
    func requestRecentTransactions() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["action": "fetchRecent"], replyHandler: { [weak self] reply in
            Task { @MainActor in
                self?.handleRecentTransactionsReply(reply)
            }
        }, errorHandler: nil)
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
    }

    private func markFailed(draftId: UUID) {
        guard let idx = pendingDrafts.firstIndex(where: { $0.id == draftId }) else { return }
        pendingDrafts[idx].syncStatus = .failed
        pendingDrafts[idx].retryCount += 1
        savePending()
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
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if session.isReachable { self.retryPending() }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if session.isReachable { self.retryPending() }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        if action == "syncTransactions",
           let list = message["transactions"] as? [[String: Any]] {
            let parsed = list.compactMap { WatchTransaction(from: $0) }
            Task { @MainActor in
                self.recentTransactions = parsed
            }
        }
    }
}
