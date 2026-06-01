import AutoLedgerCore
import Foundation

/// Watch 侧主 ViewModel，协调 WatchSessionManager 与 UI 状态。
@Observable
@MainActor
final class WatchLedgerViewModel {

    // MARK: - Dependencies

    private let session: WatchSessionManager

    // MARK: - List State

    var recentTransactions: [WatchTransaction] = []
    var todaySummary: WatchTodaySummary = .empty
    var isReachable: Bool = false
    var pendingCount: Int = 0

    var customCategories: [String] = []

    /// 快速记账面板是否展开
    var isQuickAddPresented: Bool = false

    /// 最近提交结果反馈（短暂展示后置 nil）
    var lastFeedback: String? = nil

    // MARK: - Quick Add Input State

    /// 选中分类 rawValue 或自定义分类名称（默认餐饮，最高频）
    var quickAddCategoryRaw: String = TransactionCategory.dining.rawValue

    /// 金额字符串（TextField 绑定，提交时转 Double）
    var quickAddAmountText: String = ""

    /// 商户名（可选）
    var quickAddMerchant: String = ""

    /// 是否正在提交
    var isSubmitting: Bool = false

    // MARK: - Voice Add State

    /// 语音记账面板是否展开
    var isVoiceRecorderPresented: Bool = false

    /// 语音解析后的草稿（供 WatchVoiceConfirmView 使用）
    var voiceDraft: WatchLedgerDraft? = nil

    // MARK: - Init

    init(session: WatchSessionManager? = nil) {
        let resolvedSession = session ?? .shared
        self.session = resolvedSession
        guard !WatchScreenshotModeConfig.isEnabled else { return }
        resolvedSession.onStateChanged = { [weak self] in
            self?.syncFromSession()
        }
        syncFromSession()
        resolvedSession.requestInitialSyncIfNeeded()
        resolvedSession.retryPending()
    }

    // MARK: - Actions

    /// 拉取最近账单（下拉刷新触发）
    func refreshTransactions() {
        guard !WatchScreenshotModeConfig.isEnabled else { return }
        session.requestRecentTransactions()
        Task {
            try? await Task.sleep(for: .seconds(1))
            self.syncFromSession()
        }
    }

    /// Watch 首屏无账单或无自定义分类时，主动触发一次同步请求。
    func requestInitialSyncIfNeeded() {
        guard !WatchScreenshotModeConfig.isEnabled else { return }
        session.requestInitialSyncIfNeeded()
    }

    /// 快速记账提交（创建 WatchLedgerDraft，入 pending 队列）
    func submitDraftAdd() {
        let raw = quickAddAmountText
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "，", with: ".")
            .replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(raw), amount > 0 else { return }

        let merchant = quickAddMerchant.trimmingCharacters(in: .whitespaces)
        let draft = WatchLedgerDraft(
            merchant: merchant.isEmpty ? quickAddCategoryOption.title : merchant,
            amount: amount,
            categoryRaw: quickAddCategoryOption.rawValue
        )

        isSubmitting = true
        session.enqueue(draft)

        Task {
            try? await Task.sleep(for: .milliseconds(400))
            self.isSubmitting = false
            self.resetQuickAddInput()
            self.isQuickAddPresented = false
            self.syncFromSession()
            let offline = !self.isReachable
            self.lastFeedback = offline ? String(localized: "watch.feedback.queued") : String(localized: "watch.feedback.sent")
            try? await Task.sleep(for: .seconds(2.5))
            self.lastFeedback = nil
        }
    }

    // MARK: - Helpers

    func resetQuickAddInput() {
        quickAddAmountText = ""
        quickAddMerchant = ""
        quickAddCategoryRaw = TransactionCategory.dining.rawValue
    }

    var categoryOptions: [WatchCategoryOption] {
        WatchCategoryOption.all(customCategories: customCategories)
    }

    var quickAddCategoryOption: WatchCategoryOption {
        categoryOptions.first { $0.rawValue == quickAddCategoryRaw }
            ?? WatchCategoryOption(rawValue: TransactionCategory.dining.rawValue, title: TransactionCategory.dining.title, iconName: TransactionCategory.dining.iconName)
    }

    var quickAddAmountValid: Bool {
        let s = quickAddAmountText.trimmingCharacters(in: .whitespaces)
        return Double(s.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "，", with: ".")) != nil
            && !s.isEmpty
    }

    /// 保存语音解析草稿（WatchVoiceConfirmView 调用，分类已由用户确认）
    func submitVoiceDraft(_ draft: WatchLedgerDraft) {
        isSubmitting = true
        session.enqueue(draft)
        voiceDraft = nil

        Task {
            try? await Task.sleep(for: .milliseconds(400))
            self.isSubmitting = false
            self.isVoiceRecorderPresented = false
            self.syncFromSession()
            let offline = !self.isReachable
            self.lastFeedback = offline ? String(localized: "watch.feedback.queued") : String(localized: "watch.feedback.sent")
            try? await Task.sleep(for: .seconds(2.5))
            self.lastFeedback = nil
        }
    }

    private func syncFromSession() {
        recentTransactions = session.recentTransactions
        todaySummary = session.todaySummary
        isReachable = session.isReachable
        pendingCount = session.pendingCount
        customCategories = session.customCategories
    }
}
