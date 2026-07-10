import AutoLedgerCore
import Combine
import Foundation
import os.log
import UIKit
import WidgetKit

// Combine.Subscription 与 AutoLedgerCore.Subscription 同名，显式消歧义
typealias Subscription = AutoLedgerCore.Subscription

private let logger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "LedgerStore")

private struct LedgerPersistenceUnavailableError: LocalizedError, Sendable {
    let underlyingDescription: String

    var errorDescription: String? {
        String(
            format: String(localized: "ledger.persistence.unavailable_format"),
            underlyingDescription
        )
    }
}

private struct UnavailableTransactionStore: TransactionStore {
    let error: LedgerPersistenceUnavailableError

    func loadTransactions() throws -> [Transaction] { throw error }
    func save(transaction: Transaction) throws { throw error }
    func update(transaction: Transaction) throws { throw error }
    func delete(transactionID: UUID) throws { throw error }
    func bootstrapIfNeeded(with transactions: [Transaction]) throws -> [Transaction] { throw error }
}

struct DataCleaningApplicationResult: Identifiable, Equatable {
    let id = UUID()
    let previewID: String
    let kind: DataCleaningPreviewKind
    let updatedCount: Int
    let deletedCount: Int
    let skippedCount: Int
    let canUndo: Bool
}

struct DataCleaningApplicationHistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var previewID: String
    var kind: DataCleaningPreviewKind
    var previewCount: Int
    var previewTitles: [String]
    var updatedCount: Int
    var deletedCount: Int
    var skippedCount: Int
    var appliedAt: Date
    var undoneAt: Date?

    init(
        id: UUID = UUID(),
        previewID: String,
        kind: DataCleaningPreviewKind,
        previewCount: Int,
        previewTitles: [String],
        updatedCount: Int,
        deletedCount: Int,
        skippedCount: Int,
        appliedAt: Date = Date(),
        undoneAt: Date? = nil
    ) {
        self.id = id
        self.previewID = previewID
        self.kind = kind
        self.previewCount = previewCount
        self.previewTitles = previewTitles
        self.updatedCount = updatedCount
        self.deletedCount = deletedCount
        self.skippedCount = skippedCount
        self.appliedAt = appliedAt
        self.undoneAt = undoneAt
    }
}

private struct DataCleaningUndoSnapshot {
    let previewID: String
    let kind: DataCleaningPreviewKind
    let previousActiveTransactions: [Transaction]
    let previousDeletedTransactions: [Transaction]
    let previousMerchantAliases: [String: String]
    let previousMerchantAliasDeletedKeys: Set<String>
    let updatedCount: Int
    let deletedCount: Int
}

private enum HotelStayDraftDuplicateState {
    case pending
    case rejected
    case posted
}

private struct MonthlyReportCacheKey: Hashable {
    let monthStart: Date
    let ledgerScopeID: String
}

private struct MonthlyAnomalyCacheKey: Hashable {
    let monthStart: Date
    let ledgerScopeID: String
    let thresholdPercent: Double
}

struct ReceiptImportReviewDraft: Identifiable {
    let id = UUID()
    let receipt: ImportedReceipt
    let rawText: String
    let notePrefix: String
    let imageSource: ImageSource
    let llmTrace: SmartReceiptParser.LLMTrace?
    let usedRuleFallback: Bool
    let multiReceiptDetected: Bool
}

final class LedgerStore: ObservableObject {
    static var shared: LedgerStore?
    static var watchSyncHandler: (() -> Void)?

    @Published private(set) var transactions: [Transaction] {
        didSet { invalidateMonthlyReportCaches() }
    }
    @Published private(set) var deletedTransactions: [Transaction] = []
    @Published private(set) var subscriptions: [Subscription] = []
    @Published private(set) var categoryCorrections: [String: TransactionCategory] = [:]
    @Published private(set) var recentImports: [ImportedReceipt] = []
    @Published private(set) var debugRecords: [ImportDebugRecord] = []
    @Published private(set) var sampleReceipts: [SampleReceipt]
    @Published private(set) var hotelStayRecords: [HotelStayRecord] = []
    @Published private(set) var hotelStayDrafts: [HotelStayDraft] = []
    @Published private(set) var lastRecognizedText = ""
    @Published private(set) var lastParsedReceipt: ImportedReceipt?
    @Published private(set) var pendingReceiptReview: ReceiptImportReviewDraft?
    @Published var lastImportSummary: String?
    @Published private(set) var lastBackupSummary: String?
    @Published var detectedICloudBackup: BackupBundle?
    @Published var customSources: [String] = []
    @Published var customCategories: [String] = []
    @Published private(set) var merchantAliases: [String: String] = [:]
    @Published private(set) var ledgerProfiles: [LedgerProfile] = []
    @Published private(set) var selectedLedgerID = TodaySpendingSummary.defaultLedgerID {
        didSet {
            if oldValue != selectedLedgerID {
                invalidateMonthlyReportCaches()
            }
        }
    }
    @Published private(set) var defaultWriteLedgerID = TodaySpendingSummary.defaultLedgerID
    @Published private(set) var isShowingAllLedgers = false {
        didSet {
            if oldValue != isShowingAllLedgers {
                invalidateMonthlyReportCaches()
            }
        }
    }
    @Published private(set) var ledgerCloudSyncStatus: String?
    @Published private(set) var ledgerCloudSyncLog: [String] = []
    @Published private(set) var ledgerSyncConflictRecords: [TransactionSyncRecord] = []
    @Published private(set) var isLedgerCloudSyncEnabled: Bool
    @Published private(set) var isLedgerCloudSyncRunning = false
    @Published private(set) var persistenceInitializationErrorMessage: String?
    @Published private(set) var lastDataCleaningApplicationResult: DataCleaningApplicationResult?
    @Published private(set) var dataCleaningApplicationHistory: [DataCleaningApplicationHistoryEntry] = []
    @Published private(set) var ignoredDataCleaningPreviewIDs: Set<String> = []

    private let parser: ReceiptParser
    private let smartParser = SmartReceiptParser()
    private let subscriptionDetector = SubscriptionDetector()
    private let textInterpreter = LedgerTextInterpreter()
    private let transactionStore: TransactionStore?
    private var lastPasteboardChangeCount: Int
    private var pendingBackupTask: Task<Void, Never>?
    private var pendingCloudKitPushTask: Task<Void, Never>?
    private var didRunLaunchCloudKitSync = false
    private var recentlyEditedTransactionIDs: [UUID: Date] = [:]
    private var merchantAliasDeletedKeys: Set<String> = []
    private var lastDataCleaningUndoSnapshot: DataCleaningUndoSnapshot?
    private let iCloudBackupService = ICloudBackupService()
    private let monthlyInsightService = MonthlyInsightService()
    private var monthlySnapshotCache: [MonthlyReportCacheKey: MonthlySnapshot] = [:]
    private var monthlyAnomalyCache: [MonthlyAnomalyCacheKey: [AnomalyAlert]] = [:]
    private var reportMonthOptionsCache: [String: [Date]] = [:]

    convenience init() {
        do {
            self.init(transactionStore: try SQLiteTransactionStore())
        } catch {
            let unavailableError = LedgerPersistenceUnavailableError(
                underlyingDescription: error.localizedDescription
            )
            self.init(
                transactionStore: UnavailableTransactionStore(error: unavailableError),
                persistenceInitializationErrorMessage: unavailableError.localizedDescription
            )
        }
    }

    func dismissPersistenceInitializationError() {
        persistenceInitializationErrorMessage = nil
    }

    init(
        parser: ReceiptParser = ReceiptParser(),
        sampleProvider: SampleReceiptProviding = SampleReceiptProvider(),
        transactionStore: TransactionStore?,
        persistenceInitializationErrorMessage: String? = nil
    ) {
        self.parser = parser
        self.sampleReceipts = sampleProvider.samples
        self.transactionStore = transactionStore
        self.persistenceInitializationErrorMessage = persistenceInitializationErrorMessage
        self.transactions = LedgerStore.loadInitialTransactions(using: transactionStore)
        self.deletedTransactions = LedgerStore.loadInitialDeletedTransactions(using: transactionStore)
        self.subscriptions = LedgerStore.loadInitialSubscriptions(using: transactionStore)
        self.categoryCorrections = LedgerStore.loadInitialCategoryCorrections(using: transactionStore)
        self.debugRecords = LedgerStore.loadInitialDebugRecords(using: transactionStore)
        self.hotelStayRecords = LedgerStore.loadInitialHotelStayRecords(using: transactionStore)
        self.hotelStayDrafts = LedgerStore.loadInitialHotelStayDrafts(using: transactionStore)
        self.ledgerSyncConflictRecords = LedgerStore.loadInitialLedgerSyncConflictRecords(using: transactionStore)
        self.dataCleaningApplicationHistory = Self.loadDataCleaningApplicationHistory()
        self.customSources = UserDefaults.standard.stringArray(forKey: "customSources") ?? []
        let storedCustomCategories = UserDefaults.standard.stringArray(forKey: "customCategories") ?? []
        let normalizedCustomCategories = Self.normalizedCustomCategories(storedCustomCategories)
        self.customCategories = normalizedCustomCategories
        if normalizedCustomCategories != storedCustomCategories {
            UserDefaults.standard.set(normalizedCustomCategories, forKey: "customCategories")
        }
        self.merchantAliases = LedgerStore.loadInitialMerchantAliases(using: transactionStore)
        self.merchantAliasDeletedKeys = Self.loadMerchantAliasDeletedKeys()
        self.ignoredDataCleaningPreviewIDs = Self.loadIgnoredDataCleaningPreviewIDs()
        let initialLedgerProfiles = LedgerStore.loadInitialLedgerProfiles(using: transactionStore)
        self.ledgerProfiles = initialLedgerProfiles
        self.selectedLedgerID = LedgerStore.loadInitialSelectedLedgerID(from: initialLedgerProfiles)
        self.defaultWriteLedgerID = LedgerStore.loadInitialDefaultWriteLedgerID(from: initialLedgerProfiles)
        self.isShowingAllLedgers = UserDefaults.standard.bool(forKey: Self.showAllLedgersKey)
        self.isLedgerCloudSyncEnabled = UserDefaults.standard.bool(forKey: Self.ledgerCloudSyncEnabledKey)
        self.lastPasteboardChangeCount = UIPasteboard.general.changeCount
        seedLegacyLedgerConfigurationTimestampIfNeeded()
        normalizeHotelLinkedTransactionCategories(persist: true)
        LedgerStore.shared = self
    }

    var monthlySnapshot: MonthlySnapshot {
        monthlySnapshot(for: .now)
    }

    func monthlySnapshot(for referenceDate: Date) -> MonthlySnapshot {
        guard let key = monthlyReportCacheKey(for: referenceDate) else {
            return MonthlySnapshot.build(from: visibleTransactions, referenceDate: referenceDate)
        }
        if let cached = monthlySnapshotCache[key] {
            return cached
        }
        let snapshot = MonthlySnapshot.build(from: visibleTransactions, referenceDate: referenceDate)
        monthlySnapshotCache[key] = snapshot
        return snapshot
    }

    func monthlyAnomalyAlerts(for referenceDate: Date = .now, thresholdPercent: Double) -> [AnomalyAlert] {
        guard let monthStart = AppFormatters.calendar.dateInterval(of: .month, for: referenceDate)?.start else {
            return []
        }
        let key = MonthlyAnomalyCacheKey(
            monthStart: monthStart,
            ledgerScopeID: currentLedgerScopeID,
            thresholdPercent: thresholdPercent
        )
        if let cached = monthlyAnomalyCache[key] {
            return cached
        }
        let alerts = monthlyInsightService.detectAnomalies(
            transactions: visibleTransactions,
            referenceDate: referenceDate,
            thresholdPercent: thresholdPercent
        )
        monthlyAnomalyCache[key] = alerts
        return alerts
    }

    func reportMonthOptions() -> [Date] {
        let ledgerScopeID = currentLedgerScopeID
        if let cached = reportMonthOptionsCache[ledgerScopeID] {
            return cached
        }

        let calendar = AppFormatters.calendar
        var monthStarts = Set<Date>()
        if let currentMonthStart = calendar.dateInterval(of: .month, for: .now)?.start {
            monthStarts.insert(currentMonthStart)
        }
        for transaction in visibleTransactions {
            if let monthStart = calendar.dateInterval(of: .month, for: transaction.occurredAt)?.start {
                monthStarts.insert(monthStart)
            }
        }

        let sortedMonths = monthStarts.sorted(by: >)
        reportMonthOptionsCache[ledgerScopeID] = sortedMonths
        return sortedMonths
    }

    var todaySpendingSummary: TodaySpendingSummary {
        TodaySpendingSummary.build(
            from: visibleTransactions,
            referenceDate: .now,
            ledgerID: currentLedgerScopeID,
            ledgerName: currentLedgerScopeName
        )
    }

    private func monthlyReportCacheKey(for referenceDate: Date) -> MonthlyReportCacheKey? {
        guard let monthStart = AppFormatters.calendar.dateInterval(of: .month, for: referenceDate)?.start else {
            return nil
        }
        return MonthlyReportCacheKey(monthStart: monthStart, ledgerScopeID: currentLedgerScopeID)
    }

    private func invalidateMonthlyReportCaches() {
        monthlySnapshotCache.removeAll()
        monthlyAnomalyCache.removeAll()
        reportMonthOptionsCache.removeAll()
    }

    var activeLedgerProfiles: [LedgerProfile] {
        ledgerProfiles.filter { !$0.isArchived }
    }

    var defaultLedgerProfile: LedgerProfile {
        activeLedgerProfiles.first { $0.isDefault } ?? LedgerProfile.defaultLocal()
    }

    var defaultWriteLedgerProfile: LedgerProfile {
        activeLedgerProfiles.first { $0.id == defaultWriteLedgerID } ?? LedgerProfile.defaultLocal()
    }

    var visibleTransactions: [Transaction] {
        transactionsForCurrentLedger(transactions)
    }

    var visibleSubscriptions: [Subscription] {
        subscriptionsForCurrentLedger(subscriptions)
    }

    func dataCleaningPreviewSnapshot() -> DataCleaningPreviewSnapshot {
        DataCleaningPreviewPlanner().buildSnapshot(
            transactions: visibleTransactions,
            merchantAliases: merchantAliases,
            categoryCorrections: categoryCorrections,
            ignoredPreviewIDs: ignoredDataCleaningPreviewIDs
        )
    }

    func ignoreDataCleaningPreview(id: String) {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty,
              !ignoredDataCleaningPreviewIDs.contains(trimmedID) else {
            return
        }
        ignoredDataCleaningPreviewIDs.insert(trimmedID)
        persistIgnoredDataCleaningPreviewIDs()
    }

    func restoreIgnoredDataCleaningPreview(id: String) {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ignoredDataCleaningPreviewIDs.remove(trimmedID) != nil else {
            return
        }
        persistIgnoredDataCleaningPreviewIDs()
    }

    var targetLedgerIDForNewTransactions: String {
        defaultWriteLedgerID
    }

    var currentLedgerTitle: String {
        currentLedgerScopeName
    }

    func transactionsForCurrentLedger(_ source: [Transaction]) -> [Transaction] {
        guard !isShowingAllLedgers else { return source }
        return source.filter { $0.resolvedLedgerID() == selectedLedgerID }
    }

    func subscriptionsForCurrentLedger(_ source: [Subscription]) -> [Subscription] {
        guard !isShowingAllLedgers else { return source }
        let currentMerchants = Set(visibleTransactions.map { normalizedMerchantKey($0.merchant) })
        guard !currentMerchants.isEmpty else { return [] }
        return source.filter { currentMerchants.contains(normalizedMerchantKey($0.merchant)) }
    }

    func detectSubscriptionsForCurrentLedger() -> [Subscription] {
        subscriptionDetector.detectFromHistory(visibleTransactions)
    }

    func upcomingSubscriptionsForCurrentLedger(referenceDate: Date = .now, days: Int = 7) -> [Subscription] {
        let upperBound = Calendar.current.date(byAdding: .day, value: days, to: referenceDate) ?? referenceDate
        return visibleSubscriptions.filter {
            $0.status.isActive &&
            $0.nextChargedAt <= upperBound &&
            $0.nextChargedAt >= referenceDate
        }
    }

    func selectLedgerProfile(_ profile: LedgerProfile) {
        guard !profile.isArchived else { return }
        selectedLedgerID = profile.id
        isShowingAllLedgers = false
        saveLedgerSelection()
    }

    func selectAllLedgers() {
        isShowingAllLedgers = true
        saveLedgerSelection()
    }

    func showSelectedLedgerOnly() {
        guard isShowingAllLedgers else {
            normalizeLedgerSelection()
            return
        }
        isShowingAllLedgers = false
        normalizeLedgerSelection()
    }

    func ledgerName(for ledgerID: String?) -> String {
        let resolvedID = ledgerID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetID = resolvedID?.isEmpty == false ? resolvedID : TodaySpendingSummary.defaultLedgerID
        return ledgerProfiles.first { $0.id == targetID }?.name ?? TodaySpendingSummary.defaultLedgerName
    }

    func ledgerCurrencyCode(for ledgerID: String?) -> String {
        let resolvedID = ledgerID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetID = resolvedID?.isEmpty == false ? resolvedID : TodaySpendingSummary.defaultLedgerID
        let currency = ledgerProfiles.first { $0.id == targetID }?.currency
        return LedgerCurrencyOption.supportedCode(matching: currency)
    }

    private var currentLedgerScopeID: String {
        isShowingAllLedgers ? Self.allLedgersScopeID : selectedLedgerID
    }

    private var currentLedgerScopeName: String {
        isShowingAllLedgers
            ? localizedMessage("ledger.scope.all", fallback: "全部账本")
            : ledgerName(for: selectedLedgerID)
    }

    func saveCustomSources() {
        UserDefaults.standard.set(customSources, forKey: "customSources")
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    func saveCustomCategories() {
        customCategories = Self.normalizedCustomCategories(customCategories)
        UserDefaults.standard.set(customCategories, forKey: "customCategories")
        Self.watchSyncHandler?()
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    func saveMerchantAliases() {
        UserDefaults.standard.set(merchantAliases, forKey: "merchantAliases")
        let updatedCount = applyMerchantAliasesToExistingTransactions()
        if updatedCount > 0 {
            lastImportSummary = localizedFormat(
                "ledger.status.aliases_refreshed_format",
                fallback: "已更新商户别名，并刷新 %d 笔历史账单。",
                updatedCount
            )
            scheduleCloudKitPushAfterLocalLedgerChange()
        }
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    func recordMerchantAlias(original: String, alias: String) {
        merchantAliases[original] = alias
        merchantAliasDeletedKeys.remove(original)
        merchantAliasDeletedKeys.remove(original.trimmingCharacters(in: .whitespacesAndNewlines))
        persistMerchantAliasDeletedKeys()
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.saveMerchantAlias(original: original, alias: alias)
        }
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    /// 如果商户名命中别名映射则返回别名，否则原样返回
    func resolveMerchant(_ merchant: String) -> String {
        MerchantAliasResolver.resolvedMerchant(for: merchant, aliases: merchantAliases)
    }

    func setMerchantAlias(original: String, alias: String) {
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty,
              !trimmedAlias.isEmpty,
              trimmedOriginal != trimmedAlias else {
            return
        }

        recordMerchantAlias(original: trimmedOriginal, alias: trimmedAlias)
        saveMerchantAliases()
    }

    func deleteMerchantAliases(for originals: [String]) {
        for original in originals {
            merchantAliases.removeValue(forKey: original)
            let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedOriginal.isEmpty {
                merchantAliasDeletedKeys.insert(trimmedOriginal)
            }
            if let sqlStore = transactionStore as? SQLiteTransactionStore {
                try? sqlStore.deleteMerchantAlias(original: original)
            }
        }
        persistMerchantAliasDeletedKeys()
        saveMerchantAliases()
    }

    @discardableResult
    func createLedgerProfile(
        name: String,
        iconName: String? = nil,
        colorName: String? = nil,
        currency: String? = nil
    ) -> LedgerProfile? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let now = Date()
        let nextSortOrder = ((ledgerProfiles.map(\.sortOrder).max() ?? 0) + 10)
        let normalizedCurrency = currency?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let profile = LedgerProfile(
            id: UUID().uuidString,
            name: trimmedName,
            iconName: iconName,
            colorName: colorName,
            currency: normalizedCurrency?.isEmpty == true ? nil : normalizedCurrency,
            isDefault: false,
            sortOrder: nextSortOrder,
            createdAt: now,
            updatedAt: now
        )

        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.saveLedgerProfile(profile)
            reloadLedgerProfiles()
        } else {
            ledgerProfiles.append(profile)
            sortLedgerProfiles()
        }
        recordLedgerProfileConfigurationChanged()
        return ledgerProfiles.first { $0.id == profile.id }
    }

    func renameLedgerProfile(_ profile: LedgerProfile, name: String) {
        updateLedgerProfile(profile, name: name, currency: profile.currency)
    }

    func updateLedgerProfile(_ profile: LedgerProfile, name: String, currency: String?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let updatedAt = Date()
        let normalizedCurrency = currency?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let updatedProfile = profile.replacing(
            name: trimmedName,
            currency: normalizedCurrency?.isEmpty == true ? nil : normalizedCurrency,
            updatedAt: updatedAt
        )
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.saveLedgerProfile(updatedProfile)
            reloadLedgerProfiles()
        } else {
            replaceLedgerProfile(updatedProfile)
        }
        recordLedgerProfileConfigurationChanged()
    }

    func archiveLedgerProfile(_ profile: LedgerProfile) {
        guard profile.id != TodaySpendingSummary.defaultLedgerID else { return }

        let archivedAt = Date()
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.archiveLedgerProfile(id: profile.id, archivedAt: archivedAt)
            reloadLedgerProfiles()
        } else {
            replaceLedgerProfile(profile.replacing(isDefault: false, archivedAt: archivedAt, updatedAt: archivedAt))
            if ledgerProfiles.filter({ $0.isDefault && !$0.isArchived }).isEmpty {
                setDefaultLedgerProfile(LedgerProfile.defaultLocal(createdAt: archivedAt))
                return
            }
        }
        normalizeDefaultWriteLedger()
        normalizeLedgerSelection()
        recordLedgerProfileConfigurationChanged()
    }

    func setDefaultLedgerProfile(_ profile: LedgerProfile) {
        let updatedAt = Date()
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.setDefaultLedgerProfile(id: profile.id, updatedAt: updatedAt)
            reloadLedgerProfiles()
        } else {
            ledgerProfiles = ledgerProfiles.map {
                $0.replacing(
                    isDefault: $0.id == profile.id,
                    archivedAt: $0.id == profile.id ? nil : $0.archivedAt,
                    updatedAt: $0.id == profile.id ? updatedAt : $0.updatedAt
                )
            }
            sortLedgerProfiles()
        }
        recordLedgerProfileConfigurationChanged()
    }

    func setDefaultWriteLedgerProfile(_ profile: LedgerProfile) {
        guard !profile.isArchived else { return }
        defaultWriteLedgerID = profile.id
        saveDefaultWriteLedger()
        recordLedgerProfileConfigurationChanged()
    }

    func importSample(_ sample: SampleReceipt) {
        let normalizedText = sample.rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = sample.source

        guard let receipt = parser.parse(
            text: normalizedText,
            source: source,
            fallbackMerchant: sample.title
        ) else {
            lastImportSummary = localizedMessage("ledger.status.sample_parse_failed", fallback: "示例解析失败。")
            return
        }

        lastParsedReceipt = receipt
        persistReceipt(receipt, rawText: normalizedText, notePrefix: localizedMessage("note.sample_import", fallback: "示例导入"))
    }

    func importRecognizedText(
        _ text: String,
        preferredSource: ReceiptSource? = nil,
        fallbackMerchant: String? = nil,
        notePrefix: String? = nil,
        imageSource: ImageSource = .photoLibrary,
        ocrMinConfidence: Float? = nil,
        requiresConfirmation: Bool = false
    ) {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNotePrefix = notePrefix ?? localizedMessage("note.photo_import", fallback: "支付截图照片导入")

        lastRecognizedText = normalizedText
        lastParsedReceipt = nil

        Task { @MainActor in
            let interpretation = await textInterpreter.interpret(
                LedgerTextInterpretationInput(
                    text: normalizedText,
                    preferredSource: preferredSource,
                    fallbackMerchant: fallbackMerchant,
                    ocrMinConfidence: ocrMinConfidence
                )
            )

            switch interpretation {
            case .voice:
                lastImportSummary = localizedMessage("voice_ledger_unclear", fallback: "还没听清这笔账，请补充商户和金额。")

            case .nonBillImage(let normalizedText, let source, let debugTrace):
                let summary = localizedMessage(
                    "receipt.non_bill_image",
                    fallback: "图片没有有效的账单信息，请换一张支付截图或小票照片。"
                )
                logger.warning("[解析] OCR 文本缺少有效账单信号：\(debugTrace.joined(separator: " | "))")
                lastImportSummary = summary
                recordDebugEvent(
                    stage: .parseFailed,
                    source: source,
                    imageSource: imageSource,
                    rawText: normalizedText,
                    parsedReceipt: nil,
                    summary: debugTrace.isEmpty ? summary : "\(summary)\n调试：\(debugTrace.joined(separator: " | "))"
                )

            case .subscription(let subscription, _, _):
                upsertSubscription(subscription)
                lastImportSummary = localizedFormat(
                    "ledger.status.subscription_recognized_format",
                    fallback: "已识别为订阅：%@ %@/%@",
                    subscription.merchant,
                    AppFormatters.currency(subscription.amount, code: subscription.currencyCode),
                    subscription.period.title
                )

            case .parseFailed(let normalizedText, let source):
                let summary = "OCR 已完成，但还没解析出可入账字段。"
                logger.warning("[解析] 智能解析失败，无可入账字段")
                lastImportSummary = summary
                recordDebugEvent(
                    stage: .parseFailed,
                    source: source,
                    imageSource: imageSource,
                    rawText: normalizedText,
                    parsedReceipt: nil,
                    summary: summary
                )

            case .multiItemTotalMissing(let result, let normalizedText, let source):
                let diagnostics = result.receipt.parseDiagnostics
                let diagnosticSummary = diagnostics?.debugSummary ?? ""

                let summary = localizedMessage(
                    "receipt.multi_item_total_missing",
                    fallback: "检测到多商品小票，但未能可靠识别总金额，请重新拍摄包含合计区域的小票"
                )
                logger.warning("[小票] 多商品小票未可靠命中 total，不自动入账。\(diagnosticSummary)")
                lastParsedReceipt = result.receipt
                lastImportSummary = summary
                recordDebugEvent(
                    stage: .parseFailed,
                    source: source,
                    imageSource: imageSource,
                    rawText: normalizedText,
                    parsedReceipt: result.receipt,
                    summary: diagnosticSummary.isEmpty ? summary : "\(summary)\n调试：\(diagnosticSummary)",
                    llmPrompt: result.llmTrace?.prompt,
                    llmResponse: result.llmTrace?.response,
                    llmProvider: result.llmTrace?.providerID,
                    llmLatencyMs: result.llmTrace?.latencyMs,
                    llmConfidence: result.receipt.confidence,
                    usedRuleFallback: result.usedRuleFallback
                )

            case .transaction(let result, let normalizedText, _, let multiReceiptDetected):
                lastParsedReceipt = result.receipt
                let providerName = result.llmTrace?.providerDisplayName ?? "规则"
                let latency = result.llmTrace?.latencyMs ?? 0
                logger.info("[解析] 模型=\(providerName) 耗时=\(latency)ms 商户=\(result.receipt.merchant) 金额=\(result.receipt.amount) 时间=\(AppFormatters.exportDateTime(result.receipt.occurredAt)) 分类=\(result.receipt.suggestedCategory.title) 规则兜底=\(result.usedRuleFallback ? "是" : "否")")
                if requiresConfirmation {
                    pendingReceiptReview = ReceiptImportReviewDraft(
                        receipt: result.receipt,
                        rawText: normalizedText,
                        notePrefix: resolvedNotePrefix,
                        imageSource: imageSource,
                        llmTrace: result.llmTrace,
                        usedRuleFallback: result.usedRuleFallback,
                        multiReceiptDetected: multiReceiptDetected
                    )
                    lastImportSummary = localizedMessage(
                        "receipt_confirm.pending_summary",
                        fallback: "已识别到账单信息，请确认后保存。"
                    )
                    if multiReceiptDetected {
                        appendImportSummary(localizedMessage(
                            "receipt_confirm.multi_receipt_notice",
                            fallback: "检测到图片中可能包含多笔账单，当前仅识别了一笔。建议将每笔账单单独截图后分别导入。"
                        ))
                    }
                    return
                }
                createTransaction(
                    from: result.receipt,
                    rawText: normalizedText,
                    notePrefix: resolvedNotePrefix,
                    imageSource: imageSource,
                    llmTrace: result.llmTrace,
                    usedRuleFallback: result.usedRuleFallback
                )

                if let diagnostics = result.receipt.parseDiagnostics,
                   diagnostics.isMultiItemReceipt,
                   diagnostics.totalMatched {
                    let notice = localizedMessage(
                        "receipt.multi_item_single_expense_notice",
                        fallback: "检测到多商品小票，当前版本将按总金额记录为一笔支出"
                    )
                    appendImportSummary(notice)
                }

                if multiReceiptDetected {
                    appendImportSummary("⚠️ 检测到图片中可能包含多笔账单，当前仅识别了一笔。建议将每笔账单单独截图后分别导入。")
                }
            }
        }
    }

    func interpretVoiceText(_ text: String) async -> VoiceLedgerParseResult {
        let interpretation = await textInterpreter.interpret(
            LedgerTextInterpretationInput(
                text: text,
                preferredSource: .voice,
                fallbackMerchant: nil,
                ocrMinConfidence: nil,
                categoryCorrections: categoryCorrections
            )
        )

        if case .voice(let result, _, _) = interpretation {
            return result
        }

        return VoiceLedgerParser().parse(text, corrections: categoryCorrections)
    }

    func prepareForLiveImport() {
        lastRecognizedText = ""
        lastParsedReceipt = nil
        pendingReceiptReview = nil
    }

    func clearPendingReceiptReview() {
        pendingReceiptReview = nil
    }

    @discardableResult
    func saveReceiptReview(
        _ review: ReceiptImportReviewDraft,
        merchant: String,
        amount: Double,
        currencyCode: String,
        source: ReceiptSource,
        category: TransactionCategory,
        occurredAt: Date,
        note: String,
        conversionQuote: CurrencyConversionPreviewQuote?
    ) -> Bool {
        let updatedReceipt = ImportedReceipt(
            source: source,
            merchant: merchant,
            amount: amount,
            currencyCode: currencyCode,
            occurredAt: occurredAt,
            rawText: review.rawText,
            summary: review.receipt.summary,
            confidence: review.receipt.confidence,
            suggestedCategory: category,
            parseDiagnostics: review.receipt.parseDiagnostics
        )
        let didHandle = persistReceipt(
            updatedReceipt,
            rawText: review.rawText,
            notePrefix: note,
            imageSource: review.imageSource,
            llmTrace: review.llmTrace,
            usedRuleFallback: review.usedRuleFallback,
            conversionQuote: conversionQuote
        )
        if didHandle {
            pendingReceiptReview = nil
            if review.multiReceiptDetected {
                appendImportSummary(localizedMessage(
                    "receipt_confirm.multi_receipt_notice",
                    fallback: "检测到图片中可能包含多笔账单，当前仅识别了一笔。建议将每笔账单单独截图后分别导入。"
                ))
            }
        }
        return didHandle
    }

    func setImportError(_ summary: String, source: ReceiptSource = .manual, imageSource: ImageSource = .unknown) {
        lastImportSummary = summary
        lastParsedReceipt = nil
        pendingReceiptReview = nil
        recordDebugEvent(
            stage: .ocrFailed,
            source: source,
            imageSource: imageSource,
            rawText: "",
            parsedReceipt: nil,
            summary: summary
        )
    }

    func clearDebugRecords() {
        debugRecords.removeAll()
        lastRecognizedText = ""
        lastParsedReceipt = nil
        lastImportSummary = nil
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.clearDebugEvents()
        }
    }

    func recordHotelFolioDebugRecord(_ record: ImportDebugRecord) {
        appendDebugRecord(record)
    }

    func recordHotelFolioDebugRecords(_ records: [ImportDebugRecord]) {
        for record in records {
            appendDebugRecord(record)
        }
    }

    /// 从 SQLite 重新加载全部账单和调试记录（用于 App 回到前台后同步 Intent 入账记录）
    func refreshFromStore() {
        guard let store = transactionStore else { return }
        do {
            transactions = try store.loadTransactions()
        } catch {
            // 静默失败，保留内存中的数据
        }
        if let sqlStore = store as? SQLiteTransactionStore {
            refreshFromSQLiteStore(sqlStore)
        }
        if normalizeHotelLinkedTransactionCategories(persist: true) > 0 {
            reloadWidgets()
            scheduleCloudKitPushAfterLocalLedgerChange()
        }
        loadShareExtensionResult()
    }

    private func refreshFromSQLiteStore(_ sqlStore: SQLiteTransactionStore) {
        transactions        = (try? sqlStore.loadTransactions())             ?? transactions
        deletedTransactions = (try? sqlStore.loadDeletedTransactions())      ?? deletedTransactions
        debugRecords        = (try? sqlStore.loadDebugEvents())              ?? debugRecords
        subscriptions       = (try? sqlStore.loadSubscriptions())            ?? subscriptions
        categoryCorrections = (try? sqlStore.loadCategoryCorrections())      ?? categoryCorrections
        merchantAliases     = (try? sqlStore.loadMerchantAliases())          ?? merchantAliases
        hotelStayRecords    = (try? sqlStore.loadHotelStayRecords())         ?? hotelStayRecords
        hotelStayDrafts     = (try? sqlStore.loadHotelStayDrafts())          ?? hotelStayDrafts
        ledgerSyncConflictRecords = (try? sqlStore.loadConflictedTransactionSyncRecords()) ?? ledgerSyncConflictRecords
        ledgerProfiles      = (try? sqlStore.loadLedgerProfiles(includeArchived: true)) ?? ledgerProfiles
        if ledgerProfiles.isEmpty {
            ledgerProfiles = [LedgerProfile.defaultLocal()]
        }
        sortLedgerProfiles()
        normalizeDefaultWriteLedger()
        normalizeLedgerSelection()
    }

    private func reloadWidgets() {
        recordLedgerSnapshotUpdatedAt()
        WidgetCenter.shared.reloadAllTimelines()
        Self.watchSyncHandler?()
    }

    /// 从剪切板读取图片并尝试 OCR → 解析 → 记账
    /// - Parameter force: `true` 跳过 changeCount 去重（控制中心 / 快捷指令显式触发）
    func attemptClipboardImport(force: Bool = false) {
        if !force {
            let current = UIPasteboard.general.changeCount
            guard current != lastPasteboardChangeCount else { return }
            lastPasteboardChangeCount = current
        }

        guard UIPasteboard.general.hasImages else { return }
        guard let image = UIPasteboard.general.image,
              let data = image.pngData() else { return }

        lastPasteboardChangeCount = UIPasteboard.general.changeCount
        prepareForLiveImport()

        do {
            let ocrResult = try OCRService().recognizeTextWithConfidence(from: data)
            if ocrResult.minimumWordConfidence < 0.75 {
                logger.warning("[OCR] 剪贴板截图识别置信度偏低：\(String(format: "%.2f", ocrResult.minimumWordConfidence))，将启用 LLM 金额验证")
            }
            importRecognizedText(ocrResult.text, imageSource: .clipboard,
                                 ocrMinConfidence: ocrResult.minimumWordConfidence)
        } catch {
            setImportError(error.localizedDescription, imageSource: .clipboard)
        }
    }

    func deleteTransaction(_ transaction: Transaction) {
        // 先从持久化层删除，失败时回滚，避免内存与 SQLite 状态不一致
        guard let store = transactionStore else {
            // 无持久化层（预览/测试场景）：直接更新内存
            transactions.removeAll { $0.id == transaction.id }
            deletedTransactions.insert(transaction, at: 0)
            if deletedTransactions.count > 50 {
                deletedTransactions = Array(deletedTransactions.prefix(50))
            }
            lastImportSummary = localizedFormat("ledger.status.deleted_format", fallback: "已删除 %@ 的记录。", transaction.merchant)
            reloadWidgets()
            return
        }

        do {
            try store.delete(transactionID: transaction.id)
        } catch {
            lastImportSummary = localizedFormat("ledger.status.delete_failed_format", fallback: "删除失败：%@", error.localizedDescription)
            return
        }

        transactions.removeAll { $0.id == transaction.id }
        // 保留最近 50 条已删除记录，供用户恢复；SQLite 中会持久化 deleted_at。
        deletedTransactions.insert(transaction, at: 0)
        if deletedTransactions.count > 50 {
            deletedTransactions = Array(deletedTransactions.prefix(50))
        }
        lastImportSummary = localizedFormat("ledger.status.deleted_format", fallback: "已删除 %@ 的记录。", transaction.merchant)
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
    }

    /// 将已删除的账单恢复到账本
    func restoreTransaction(_ transaction: Transaction) {
        guard let store = transactionStore else {
            // 无持久化层（预览/测试场景）：直接更新内存
            deletedTransactions.removeAll { $0.id == transaction.id }
            transactions.insert(transaction, at: 0)
            sortTransactions()
            lastImportSummary = localizedFormat("ledger.status.restored_format", fallback: "已恢复 %@ 的记录。", transaction.merchant)
            reloadWidgets()
            return
        }

        do {
            if let sqlStore = store as? SQLiteTransactionStore {
                try sqlStore.restoreTransaction(id: transaction.id)
            } else {
                try store.save(transaction: transaction)
            }
        } catch {
            lastImportSummary = localizedFormat("ledger.status.restore_failed_format", fallback: "恢复失败：%@", error.localizedDescription)
            return
        }

        deletedTransactions.removeAll { $0.id == transaction.id }
        transactions.insert(transaction, at: 0)
        sortTransactions()
        lastImportSummary = localizedFormat("ledger.status.restored_format", fallback: "已恢复 %@ 的记录。", transaction.merchant)
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
    }

    /// 从回收站永久删除（不再可恢复）
    func permanentlyDeleteTransaction(_ transaction: Transaction) {
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            do {
                try sqlStore.permanentlyDeleteTransaction(id: transaction.id)
                try sqlStore.deleteDebugEvents(transactionID: transaction.id)
            } catch {
                lastImportSummary = localizedFormat("ledger.status.permanent_delete_failed_format", fallback: "彻底删除失败：%@", error.localizedDescription)
                return
            }
        }
        deletedTransactions.removeAll { $0.id == transaction.id }
        debugRecords.removeAll { $0.transactionID == transaction.id }
        lastImportSummary = localizedFormat("ledger.status.permanently_deleted_format", fallback: "已彻底删除 %@ 的记录。", transaction.merchant)
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
    }

    /// 手动新增账单（账本右上角 + 入口）
    @discardableResult
    func addTransaction(_ transaction: Transaction) -> Bool {
        let aliasedTransaction = MerchantAliasResolver.applyingAlias(
            to: transaction,
            aliases: merchantAliases
        )
        .assigningLedgerIDIfMissing(targetLedgerIDForNewTransactions)
        let resolvedTransaction = transactionPreparedForLedgerCurrency(aliasedTransaction)

        guard let store = transactionStore else {
            // 无持久化层（预览/测试场景）：直接更新内存
            transactions.insert(resolvedTransaction, at: 0)
            sortTransactions()
            lastImportSummary = localizedFormat(
                "ledger.status.manual_saved_format",
                fallback: "已手动记账：%@ %@。",
                resolvedTransaction.merchant,
                AppFormatters.currency(resolvedTransaction.amount)
            )
            reloadWidgets()
            return true
        }

        do {
            try store.save(transaction: resolvedTransaction)
        } catch {
            lastImportSummary = localizedFormat("ledger.status.save_failed_format", fallback: "记账失败：%@", error.localizedDescription)
            return false
        }

        transactions.insert(resolvedTransaction, at: 0)
        sortTransactions()
        lastImportSummary = localizedFormat(
            "ledger.status.manual_saved_format",
            fallback: "已手动记账：%@ %@。",
            resolvedTransaction.merchant,
            AppFormatters.currency(resolvedTransaction.amount)
        )
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        scheduleCurrencyConversionIfNeeded(for: resolvedTransaction.id)
        return true
    }

    private func transactionPreparedForLedgerCurrency(
        _ transaction: Transaction,
        sourceAmount: Double? = nil,
        sourceCurrencyCode: String? = nil
    ) -> Transaction {
        let resolvedLedgerID = transaction.resolvedLedgerID(defaultLedgerID: targetLedgerIDForNewTransactions)
        let targetCurrencyCode = ledgerCurrencyCode(for: resolvedLedgerID)
        let normalizedSourceCurrency = LedgerCurrencyOption.supportedCode(
            matching: sourceCurrencyCode ?? transaction.originalCurrencyCode ?? transaction.ledgerCurrencyCode ?? targetCurrencyCode
        )
        let originalAmount = sourceAmount ?? transaction.originalAmount ?? transaction.amount

        guard normalizedSourceCurrency != targetCurrencyCode else {
            return transaction.replacingCurrencyMetadata(
                ledgerCurrencyCode: targetCurrencyCode,
                originalAmount: nil,
                originalCurrencyCode: nil,
                exchangeRate: nil,
                exchangeRateDate: nil,
                exchangeRateProvider: nil
            )
        }

        return transaction.replacingCurrencyMetadata(
            ledgerCurrencyCode: targetCurrencyCode,
            originalAmount: originalAmount,
            originalCurrencyCode: normalizedSourceCurrency,
            exchangeRate: transaction.exchangeRate,
            exchangeRateDate: transaction.exchangeRateDate,
            exchangeRateProvider: transaction.exchangeRateProvider
        )
    }

    private func scheduleCurrencyConversionIfNeeded(for transactionID: UUID) {
        guard !Self.isOfflineRegression else { return }
        guard let transaction = transactions.first(where: { $0.id == transactionID }),
              transactionNeedsCurrencyConversion(transaction) else {
            return
        }

        Task { [weak self] in
            await self?.convertStoredTransactionCurrencyIfNeeded(transactionID: transactionID)
        }
    }

    private func transactionNeedsCurrencyConversion(_ transaction: Transaction) -> Bool {
        guard
            let originalAmount = transaction.originalAmount,
            originalAmount > 0,
            let originalCurrencyCode = transaction.originalCurrencyCode,
            let ledgerCurrencyCode = transaction.ledgerCurrencyCode
        else {
            return false
        }
        return originalCurrencyCode != ledgerCurrencyCode && transaction.exchangeRate == nil
    }

    private func convertStoredTransactionCurrencyIfNeeded(transactionID: UUID) async {
        guard let index = transactions.firstIndex(where: { $0.id == transactionID }) else { return }
        let transaction = transactions[index]
        guard transactionNeedsCurrencyConversion(transaction),
              let originalAmount = transaction.originalAmount,
              let originalCurrencyCode = transaction.originalCurrencyCode,
              let ledgerCurrencyCode = transaction.ledgerCurrencyCode else {
            return
        }

        do {
            let quote = try await CommonAPIExchangeRateService.quote(
                baseCurrencyCode: originalCurrencyCode,
                quoteCurrencyCode: ledgerCurrencyCode,
                date: transaction.occurredAt
            )
            let convertedAmount = (originalAmount * quote.rate * 100).rounded() / 100
            let updated = transaction.replacingCurrencyMetadata(
                amount: convertedAmount,
                ledgerCurrencyCode: quote.quoteCurrencyCode,
                originalAmount: originalAmount,
                originalCurrencyCode: quote.baseCurrencyCode,
                exchangeRate: quote.rate,
                exchangeRateDate: quote.date,
                exchangeRateProvider: quote.provider
            )

            try transactionStore?.update(transaction: updated)
            guard let latestIndex = transactions.firstIndex(where: { $0.id == transactionID }) else { return }
            transactions[latestIndex] = updated
            sortTransactions()
            reloadWidgets()
            requestAutomaticBackup()
            scheduleCloudKitPushAfterLocalLedgerChange()
        } catch {
            logger.warning("[Currency] exchange-rate conversion skipped for \(transactionID.uuidString): \(error.localizedDescription)")
        }
    }

    private static var isOfflineRegression: Bool {
        ProcessInfo.processInfo.environment["AUTOLEDGER_OFFLINE_REGRESSION"] == "1"
    }

    @discardableResult
    func duplicateTransaction(_ transaction: Transaction) -> Transaction? {
        let duplicated = Transaction(
            merchant: transaction.merchant,
            amount: transaction.amount,
            occurredAt: transaction.occurredAt,
            categoryLabel: transaction.category,
            sourceLabel: transaction.source,
            note: transaction.note,
            ledgerID: transaction.resolvedLedgerID(),
            hotelStayRecordID: nil,
            ledgerCurrencyCode: transaction.ledgerCurrencyCode,
            originalAmount: transaction.originalAmount,
            originalCurrencyCode: transaction.originalCurrencyCode,
            exchangeRate: transaction.exchangeRate,
            exchangeRateDate: transaction.exchangeRateDate,
            exchangeRateProvider: transaction.exchangeRateProvider
        )
        guard addTransaction(duplicated) else { return nil }
        lastImportSummary = String(
            format: localizedMessage(
                "ledger.action.copy.success_format",
                fallback: "已复制账单：%@ %@。"
            ),
            duplicated.merchant,
            AppFormatters.currency(duplicated.amount)
        )
        return duplicated
    }

    @discardableResult
    func moveTransaction(_ transaction: Transaction, toLedgerID ledgerID: String) -> Bool {
        let trimmedLedgerID = ledgerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLedgerID.isEmpty,
              activeLedgerProfiles.contains(where: { $0.id == trimmedLedgerID }) else {
            lastImportSummary = localizedMessage(
                "ledger.move.error.unavailable_target",
                fallback: "移动账单失败：目标账本不可用。"
            )
            return false
        }

        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else {
            lastImportSummary = localizedMessage(
                "ledger.move.error.not_found",
                fallback: "移动账单失败：未找到要移动的账单。"
            )
            return false
        }

        let existing = transactions[index]
        let sourceCurrencyCode = existing.ledgerCurrencyCode ?? ledgerCurrencyCode(for: existing.resolvedLedgerID())
        let updated = transactionPreparedForLedgerCurrency(
            existing.replacingLedgerID(trimmedLedgerID),
            sourceAmount: existing.amount,
            sourceCurrencyCode: sourceCurrencyCode
        )
        do {
            try transactionStore?.update(transaction: updated)
        } catch {
            lastImportSummary = String(
                format: localizedMessage(
                    "ledger.move.error.persistence_failed_format",
                    fallback: "移动账单失败：%@"
                ),
                error.localizedDescription
            )
            return false
        }

        transactions[index] = updated
        sortTransactions()
        lastImportSummary = String(
            format: localizedMessage(
                "ledger.move.success_format",
                fallback: "已将 %@ 移动到账本 %@。"
            ),
            updated.merchant,
            ledgerName(for: trimmedLedgerID)
        )
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        scheduleCurrencyConversionIfNeeded(for: updated.id)
        return true
    }

    /// 保存 App 内语音记账确认后的账单，并记录可追溯调试信息。
    func addVoiceTransaction(
        merchant: String,
        amount: Double,
        occurredAt: Date,
        category: TransactionCategory,
        rawText: String
    ) {
        let receipt = ImportedReceipt(
            source: .voice,
            merchant: merchant,
            amount: amount,
            occurredAt: occurredAt,
            rawText: rawText,
            summary: "语音记账：\(rawText)",
            confidence: 0.95,
            suggestedCategory: category
        )

        createTransaction(
            from: receipt,
            rawText: rawText,
            notePrefix: localizedMessage("voice_ledger_note", fallback: "语音记账"),
            imageSource: .voiceIntent,
            usedRuleFallback: true
        )
    }

    @discardableResult
    func saveHotelStayDraft(_ draft: HotelStayDraft) -> Bool {
        if let duplicateState = duplicateHotelStayDraftState(for: draft) {
            lastImportSummary = duplicateHotelStayDraftMessage(for: duplicateState)
            return false
        }

        do {
            if let sqlStore = transactionStore as? SQLiteTransactionStore {
                try sqlStore.save(hotelStayDraft: draft)
            }
        } catch {
            lastImportSummary = String(
                format: localizedMessage(
                    "hotel_stay.draft.error.persistence_failed_format",
                    fallback: "酒店水单草稿保存失败：%@"
                ),
                error.localizedDescription
            )
            return false
        }

        upsertHotelStayDraftInMemory(draft)
        recordHotelFolioDebugRecord(HotelFolioDebugTraceBuilder.makeDraftSavedRecord(draft: draft))
        lastImportSummary = localizedMessage(
            "hotel_stay.draft.saved",
            fallback: "酒店水单草稿已保存，等待确认。"
        )
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        return true
    }

    #if DEBUG
    func installScreenshotHotelStayFixtures(
        records: [HotelStayRecord],
        drafts: [HotelStayDraft],
        transactions fixtureTransactions: [Transaction]
    ) {
        let recordIDs = Set(records.map(\.id))
        hotelStayRecords.removeAll { recordIDs.contains($0.id) }
        hotelStayRecords.insert(contentsOf: records, at: 0)
        sortHotelStayRecords()

        let draftIDs = Set(drafts.map(\.id))
        hotelStayDrafts.removeAll { draftIDs.contains($0.id) }
        hotelStayDrafts.insert(contentsOf: drafts, at: 0)
        sortHotelStayDrafts()

        let transactionIDs = Set(fixtureTransactions.map(\.id))
        transactions.removeAll { transactionIDs.contains($0.id) }
        transactions.insert(contentsOf: fixtureTransactions, at: 0)
        sortTransactions()
    }
    #endif

    @discardableResult
    func rejectHotelStayDraft(_ draft: HotelStayDraft) -> Bool {
        var rejectedDraft = draft
        rejectedDraft.status = .rejected
        rejectedDraft.updatedAt = .now

        do {
            if let sqlStore = transactionStore as? SQLiteTransactionStore {
                try sqlStore.save(hotelStayDraft: rejectedDraft)
            }
        } catch {
            lastImportSummary = String(
                format: localizedMessage(
                    "hotel_stay.draft.error.persistence_failed_format",
                    fallback: "酒店水单草稿保存失败：%@"
                ),
                error.localizedDescription
            )
            return false
        }

        upsertHotelStayDraftInMemory(rejectedDraft)
        lastImportSummary = localizedMessage(
            "hotel_stay.import.status.rejected",
            fallback: "已拒绝本次酒店水单识别结果。"
        )
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        return true
    }

    @discardableResult
    func deleteHotelStayDraft(_ draft: HotelStayDraft) -> Bool {
        do {
            if let sqlStore = transactionStore as? SQLiteTransactionStore {
                try sqlStore.deleteHotelStayDraft(id: draft.id)
            }
        } catch {
            lastImportSummary = String(
                format: localizedMessage(
                    "hotel_stay.draft.delete.error_format",
                    fallback: "酒店水单草稿删除失败：%@"
                ),
                error.localizedDescription
            )
            return false
        }

        hotelStayDrafts.removeAll { $0.id == draft.id }
        recordHotelStayDraftTombstone(draft.id)
        lastImportSummary = localizedMessage(
            "hotel_stay.draft.delete.success",
            fallback: "已删除酒店水单草稿。"
        )
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        return true
    }

    @discardableResult
    func pruneStaleHotelStayDrafts(
        updatedBefore cutoffDate: Date,
        statuses: Set<HotelStayDraftStatus> = [.rejected, .postedToLedger]
    ) -> Int {
        var removedCount = 0
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            removedCount = (try? sqlStore.deleteHotelStayDrafts(
                statuses: statuses,
                updatedBefore: cutoffDate
            )) ?? 0
        }

        let removedIDs = Set(
            hotelStayDrafts
                .filter { statuses.contains($0.status) && $0.updatedAt < cutoffDate }
                .map(\.id)
        )
        if !removedIDs.isEmpty {
            hotelStayDrafts.removeAll { removedIDs.contains($0.id) }
            for id in removedIDs {
                recordHotelStayDraftTombstone(id)
            }
            requestAutomaticBackup()
            scheduleCloudKitPushAfterLocalLedgerChange()
        }
        return max(removedCount, removedIDs.count)
    }

    @discardableResult
    func postConfirmedHotelStayDraft(_ draft: HotelStayDraft) -> Bool {
        let postingService = HotelStayLedgerPostingService()
        let result: HotelStayLedgerPostingResult
        do {
            result = try postingService.post(draft)
        } catch {
            lastImportSummary = String(
                format: localizedMessage(
                    "hotel_stay.post.error.invalid_draft_format",
                    fallback: "酒店消费入账失败：%@"
                ),
                error.localizedDescription
            )
            return false
        }
        let transaction = transactionPreparedForLedgerCurrency(
            result.transaction,
            sourceAmount: result.transaction.originalAmount ?? result.transaction.amount,
            sourceCurrencyCode: result.transaction.originalCurrencyCode ?? result.hotelStayRecord.currency
        )
        var postedResult = result
        postedResult.transaction = transaction

        do {
            if let sqlStore = transactionStore as? SQLiteTransactionStore {
                try sqlStore.save(hotelStayRecord: result.hotelStayRecord, linkedTransaction: transaction)
            } else {
                try transactionStore?.save(transaction: transaction)
            }
        } catch {
            lastImportSummary = String(
                format: localizedMessage(
                    "hotel_stay.post.error.persistence_failed_format",
                    fallback: "酒店消费写入本地存储失败：%@"
                ),
                error.localizedDescription
            )
            return false
        }

        hotelStayRecords.insert(result.hotelStayRecord, at: 0)
        sortHotelStayRecords()
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.deleteHotelStayDraft(id: draft.id)
        }
        recordHotelStayDraftTombstone(draft.id)
        hotelStayDrafts.removeAll { $0.id == draft.id }
        transactions.insert(transaction, at: 0)
        sortTransactions()
        recordHotelFolioDebugRecord(HotelFolioDebugTraceBuilder.makePostedRecord(result: postedResult))
        lastImportSummary = String(
            format: localizedMessage(
                "hotel_stay.post.success_format",
                fallback: "已归档酒店消费：%@ %@ %.2f。"
            ),
            transaction.merchant,
            result.hotelStayRecord.localizedData?.currency ?? result.hotelStayRecord.currency,
            result.transaction.amount
        )
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        scheduleCurrencyConversionIfNeeded(for: transaction.id)
        return true
    }

    @discardableResult
    func deleteHotelStayRecord(_ record: HotelStayRecord) -> Bool {
        let linkedTransactions = transactions.filter { transaction in
            transaction.id == record.linkedTransactionID || transaction.hotelStayRecordID == record.id
        }

        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            do {
                try sqlStore.deleteHotelStayRecord(id: record.id)
            } catch {
                lastImportSummary = String(
                    format: localizedMessage(
                        "hotel_stay.delete.error_format",
                        fallback: "酒店消费删除失败：%@"
                    ),
                    error.localizedDescription
                )
                return false
            }
        } else if transactionStore != nil {
            lastImportSummary = localizedMessage(
                "hotel_stay.delete.error.unsupported_store",
                fallback: "当前存储暂不支持删除酒店消费。"
            )
            return false
        }

        hotelStayRecords.removeAll { $0.id == record.id }
        recordHotelStayRecordTombstone(record.id)
        if !linkedTransactions.isEmpty {
            let linkedIDs = Set(linkedTransactions.map(\.id))
            transactions.removeAll { linkedIDs.contains($0.id) }
            deletedTransactions.insert(contentsOf: linkedTransactions, at: 0)
            if deletedTransactions.count > 50 {
                deletedTransactions = Array(deletedTransactions.prefix(50))
            }
        }
        lastImportSummary = String(
            format: localizedMessage(
                "hotel_stay.delete.success_format",
                fallback: "已删除酒店消费：%@。"
            ),
            record.localizedData?.hotelName ?? record.hotelName
        )
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        return true
    }

    @discardableResult
    func updateHotelStayRecord(
        _ record: HotelStayRecord,
        linkedTransaction: Transaction?
    ) -> Bool {
        var updatedRecord = record
        updatedRecord.updatedAt = Date()

        let normalizedTransaction = linkedTransaction.map {
            transactionPreparedForLedgerCurrency(
                hotelLinkedTransaction($0, recordID: updatedRecord.id, ledgerID: updatedRecord.ledgerID),
                sourceAmount: $0.originalAmount ?? $0.amount,
                sourceCurrencyCode: updatedRecord.localizedData?.currency ?? updatedRecord.currency
            )
        }
        if let normalizedTransaction {
            updatedRecord.linkedTransactionID = normalizedTransaction.id
        }

        do {
            if let sqlStore = transactionStore as? SQLiteTransactionStore {
                if let normalizedTransaction {
                    if transactions.contains(where: { $0.id == normalizedTransaction.id }) {
                        try sqlStore.update(transaction: normalizedTransaction)
                    } else {
                        try sqlStore.save(transaction: normalizedTransaction)
                    }
                }
                try sqlStore.save(hotelStayRecord: updatedRecord)
            } else if let transactionStore {
                if let normalizedTransaction {
                    try transactionStore.update(transaction: normalizedTransaction)
                }
            }
        } catch {
            lastImportSummary = String(
                format: localizedMessage(
                    "hotel_stay.detail.save.error_format",
                    fallback: "酒店消费保存失败：%@"
                ),
                error.localizedDescription
            )
            return false
        }

        if let index = hotelStayRecords.firstIndex(where: { $0.id == updatedRecord.id }) {
            hotelStayRecords[index] = updatedRecord
        } else {
            hotelStayRecords.insert(updatedRecord, at: 0)
        }
        sortHotelStayRecords()

        if let normalizedTransaction {
            if let index = transactions.firstIndex(where: { $0.id == normalizedTransaction.id }) {
                transactions[index] = normalizedTransaction
            } else {
                transactions.insert(normalizedTransaction, at: 0)
            }
            sortTransactions()
        }

        lastImportSummary = String(
            format: localizedMessage(
                "hotel_stay.detail.save.success_format",
                fallback: "已保存酒店消费：%@。"
            ),
            updatedRecord.localizedData?.hotelName ?? updatedRecord.hotelName
        )
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        if let normalizedTransaction {
            scheduleCurrencyConversionIfNeeded(for: normalizedTransaction.id)
        }
        return true
    }

    /// 从 App Group UserDefaults 读取 Share Extension 最近一次导入的 OCR 文本和解析结果
    private func loadShareExtensionResult() {
        guard let defaults = UserDefaults(suiteName: "group.top.darkrio326.AutoLedger") else { return }
        defer {
            defaults.removeObject(forKey: "share_lastOCRText")
            defaults.removeObject(forKey: "share_lastReceipt")
        }

        if let ocrText = defaults.string(forKey: "share_lastOCRText"), !ocrText.isEmpty {
            lastRecognizedText = ocrText
        }

        if let dict = defaults.dictionary(forKey: "share_lastReceipt"),
           let merchant = dict["merchant"] as? String,
           let amount = dict["amount"] as? Double,
           let ts = dict["occurredAt"] as? Double,
           let sourceRaw = dict["source"] as? String,
           let rawText = dict["rawText"] as? String,
           let summary = dict["summary"] as? String,
           let confidence = dict["confidence"] as? Double,
           let categoryRaw = dict["category"] as? String {
            let receipt = ImportedReceipt(
                source: ReceiptSource(rawValue: sourceRaw) ?? .manual,
                merchant: merchant,
                amount: amount,
                occurredAt: Date(timeIntervalSince1970: ts),
                rawText: rawText,
                summary: summary,
                confidence: confidence,
                suggestedCategory: TransactionCategory(rawValue: categoryRaw) ?? .other
            )
            lastParsedReceipt = receipt
            lastImportSummary = localizedFormat(
                "ledger.status.imported_format",
                fallback: "已导入 %@，金额 %@。",
                merchant,
                AppFormatters.currency(amount)
            )
        }
    }

    @discardableResult
    func updateTransaction(
        _ transaction: Transaction,
        refreshSameMerchantCategory: Bool = false,
        saveMerchantAlias: Bool = false
    ) -> Bool {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else {
            lastImportSummary = localizedMessage(
                "ledger.status.update_missing",
                fallback: "账单保存失败：未找到要更新的账单。"
            )
            return false
        }

        let original = transactions[index]
        let ledgerAssignedTransaction = transaction.ledgerID == nil
            ? transaction.assigningLedgerIDIfMissing(original.resolvedLedgerID())
            : transaction
        let resolvedTransaction = transactionPreparedForLedgerCurrency(
            assigningHotelCategoryIfNeeded(ledgerAssignedTransaction)
        )
        let categoryChanged = original.category != resolvedTransaction.category
        let beforeMetadata = (transactionStore as? SQLiteTransactionStore)
            .flatMap { try? $0.loadTransactionSyncMetadata(transactionID: resolvedTransaction.id) }
        appendLedgerCloudSyncLog(
            "账单编辑开始：\(shortID(resolvedTransaction.id)) \(original.merchant) -> \(resolvedTransaction.merchant)，before=\(syncMetadataSummary(beforeMetadata))"
        )

        do {
            try transactionStore?.update(transaction: resolvedTransaction)
        } catch {
            lastImportSummary = localizedFormat(
                "ledger.status.update_failed_format",
                fallback: "账单保存失败：%@",
                error.localizedDescription
            )
            appendLedgerCloudSyncLog("账单编辑失败：\(shortID(resolvedTransaction.id)) \(error.localizedDescription)")
            return false
        }

        let afterMetadata = (transactionStore as? SQLiteTransactionStore)
            .flatMap { try? $0.loadTransactionSyncMetadata(transactionID: resolvedTransaction.id) }
        markRecentlyEdited(resolvedTransaction.id)
        appendLedgerCloudSyncLog(
            "账单编辑落盘：\(shortID(resolvedTransaction.id)) \(resolvedTransaction.merchant)，after=\(syncMetadataSummary(afterMetadata))，已加入本地保护窗口"
        )

        if saveMerchantAlias && shouldOfferMerchantAlias(from: original, to: resolvedTransaction) {
            learnMerchantAliasIfNeeded(from: original, to: resolvedTransaction)
        }

        // 检测分类修正——仅对内置分类记录用户偏好（自定义分类直接以字符串存储在 Transaction）
        if categoryChanged,
           let builtIn = TransactionCategory(rawValue: resolvedTransaction.category) {
            recordCategoryCorrection(merchant: resolvedTransaction.merchant, category: builtIn)
        }

        transactions[index] = resolvedTransaction

        let refreshedCount = refreshSameMerchantCategory && categoryChanged
            ? applyCategoryToExistingTransactions(
                merchant: resolvedTransaction.merchant,
                category: resolvedTransaction.category,
                excluding: resolvedTransaction.id
            )
            : 0
        sortTransactions()
        if refreshedCount > 0 {
            lastImportSummary = localizedFormat(
                "ledger.status.correction_refreshed_format",
                fallback: "已保存 %@ 的修正，并刷新 %d 笔同商户账单分类。",
                resolvedTransaction.merchant,
                refreshedCount
            )
        } else {
            lastImportSummary = localizedFormat(
                "ledger.status.correction_saved_format",
                fallback: "已保存 %@ 的修正。",
                resolvedTransaction.merchant
            )
        }
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        scheduleCurrencyConversionIfNeeded(for: resolvedTransaction.id)
        appendLedgerCloudSyncLog("账单编辑已安排 iCloud 推送：\(shortID(resolvedTransaction.id))")
        return true
    }

    func shouldOfferMerchantAlias(from original: Transaction, to updated: Transaction) -> Bool {
        isHighConfidenceGeneratedTransaction(original.id) &&
            merchantAliasCandidate(from: original, to: updated) != nil
    }

    @discardableResult
    func applyBatchTransactionEdits(
        transactionIDs: Set<UUID>,
        merchant: String? = nil,
        category: String? = nil
    ) -> Int {
        let targetMerchant = merchant?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let targetCategory = category?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldUpdateMerchant = targetMerchant?.isEmpty == false
        let shouldUpdateCategory = targetCategory?.isEmpty == false

        guard !transactionIDs.isEmpty,
              shouldUpdateMerchant || shouldUpdateCategory else {
            return 0
        }

        var updatedCount = 0
        var aliasPairs: [(original: String, alias: String)] = []
        var categoryCorrectionPairs: [(merchant: String, category: TransactionCategory)] = []

        for index in transactions.indices {
            let transaction = transactions[index]
            guard transactionIDs.contains(transaction.id) else { continue }

            let nextMerchant = shouldUpdateMerchant ? (targetMerchant ?? transaction.merchant) : transaction.merchant
            let nextCategory = shouldUpdateCategory ? (targetCategory ?? transaction.category) : transaction.category
            guard nextMerchant != transaction.merchant || nextCategory != transaction.category else { continue }

            let updated = Transaction(
                id: transaction.id,
                merchant: nextMerchant,
                amount: transaction.amount,
                occurredAt: transaction.occurredAt,
                categoryLabel: nextCategory,
                sourceLabel: transaction.source,
                note: transaction.note,
                ledgerID: transaction.resolvedLedgerID(),
                hotelStayRecordID: transaction.hotelStayRecordID,
                ledgerCurrencyCode: transaction.ledgerCurrencyCode,
                originalAmount: transaction.originalAmount,
                originalCurrencyCode: transaction.originalCurrencyCode,
                exchangeRate: transaction.exchangeRate,
                exchangeRateDate: transaction.exchangeRateDate,
                exchangeRateProvider: transaction.exchangeRateProvider
            )

            transactions[index] = updated
            do {
                try transactionStore?.update(transaction: updated)
                updatedCount += 1
                if nextMerchant != transaction.merchant {
                    aliasPairs.append((transaction.merchant, nextMerchant))
                }
                if nextCategory != transaction.category,
                   let builtIn = TransactionCategory(rawValue: nextCategory) {
                    categoryCorrectionPairs.append((nextMerchant, builtIn))
                }
            } catch {
                lastImportSummary = localizedFormat(
                    "ledger.status.batch_update_failed_format",
                    fallback: "批量更新 %@ 时写入本地存储失败：%@",
                    transaction.merchant,
                    error.localizedDescription
                )
            }
        }

        guard updatedCount > 0 else {
            lastImportSummary = localizedMessage("ledger.status.batch_update_empty", fallback: "没有需要批量更新的账单。")
            return 0
        }

        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            for pair in aliasPairs where pair.original != pair.alias {
                merchantAliases[pair.original] = pair.alias
                try? sqlStore.saveMerchantAlias(original: pair.original, alias: pair.alias)
            }
            for pair in categoryCorrectionPairs {
                categoryCorrections[pair.merchant] = pair.category
                try? sqlStore.saveCategoryCorrection(merchant: pair.merchant, category: pair.category)
            }
        } else {
            for pair in aliasPairs where pair.original != pair.alias {
                merchantAliases[pair.original] = pair.alias
            }
            for pair in categoryCorrectionPairs {
                categoryCorrections[pair.merchant] = pair.category
            }
        }

        if !aliasPairs.isEmpty || !categoryCorrectionPairs.isEmpty {
            UserDefaults.standard.set(merchantAliases, forKey: "merchantAliases")
            markLedgerConfigurationChanged()
        }

        sortTransactions()
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        lastImportSummary = localizedFormat("ledger.status.batch_updated_format", fallback: "已批量更新 %d 笔账单。", updatedCount)
        return updatedCount
    }

    @discardableResult
    private func applyMerchantAliasesToExistingTransactions() -> Int {
        guard !merchantAliases.isEmpty else { return 0 }

        var updatedCount = 0
        for (original, alias) in merchantAliases {
            updatedCount += applyMerchantAlias(original: original, alias: alias)
        }
        return updatedCount
    }

    @discardableResult
    func refreshTransactionsForMerchantAlias(original: String) -> Int {
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let alias = merchantAliases[trimmedOriginal] else { return 0 }

        let updatedCount = applyMerchantAlias(original: trimmedOriginal, alias: alias)
        if updatedCount > 0 {
            lastImportSummary = localizedFormat(
                "ledger.status.alias_history_refreshed_format",
                fallback: "已将 %d 笔历史账单商户名刷新为 %@。",
                updatedCount,
                alias
            )
            requestAutomaticBackup()
        } else {
            lastImportSummary = localizedFormat(
                "ledger.status.alias_history_empty_format",
                fallback: "没有需要刷新的 %@ 账单。",
                trimmedOriginal
            )
        }
        return updatedCount
    }

    @discardableResult
    private func applyMerchantAlias(original: String, alias: String) -> Int {
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty,
              !trimmedAlias.isEmpty,
              trimmedOriginal != trimmedAlias else {
            return 0
        }

        var updatedCount = 0
        for index in transactions.indices {
            let transaction = transactions[index]
            guard let updated = transaction.applyingMerchantAlias(original: trimmedOriginal, alias: trimmedAlias) else {
                continue
            }
            transactions[index] = updated
            do {
                try transactionStore?.update(transaction: updated)
                updatedCount += 1
            } catch {
                lastImportSummary = localizedFormat(
                    "ledger.status.alias_refresh_failed_format",
                    fallback: "商户别名已保存，但刷新 %@ 时写入本地存储失败：%@",
                    transaction.merchant,
                    error.localizedDescription
                )
            }
        }

        for index in deletedTransactions.indices {
            let transaction = deletedTransactions[index]
            guard let updated = transaction.applyingMerchantAlias(original: trimmedOriginal, alias: trimmedAlias) else {
                continue
            }
            deletedTransactions[index] = updated
            do {
                try transactionStore?.update(transaction: updated)
                updatedCount += 1
            } catch {
                lastImportSummary = localizedFormat(
                    "ledger.status.alias_deleted_refresh_failed_format",
                    fallback: "商户别名已保存，但刷新最近删除账单 %@ 时写入本地存储失败：%@",
                    transaction.merchant,
                    error.localizedDescription
                )
            }
        }

        if updatedCount > 0 {
            sortTransactions()
            reloadWidgets()
        }
        return updatedCount
    }

    @discardableResult
    private func applyCategoryToExistingTransactions(
        merchant: String,
        category: String,
        excluding transactionID: UUID? = nil
    ) -> Int {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMerchant.isEmpty else { return 0 }

        var updatedCount = 0
        for index in transactions.indices {
            let transaction = transactions[index]
            guard transaction.id != transactionID,
                  transaction.merchant == trimmedMerchant,
                  transaction.category != category else {
                continue
            }
            let updated = transaction.replacingCategory(category)
            transactions[index] = updated
            do {
                try transactionStore?.update(transaction: updated)
                updatedCount += 1
            } catch {
                lastImportSummary = localizedFormat(
                    "ledger.status.category_refresh_failed_format",
                    fallback: "分类偏好已保存，但刷新 %@ 时写入本地存储失败：%@",
                    transaction.merchant,
                    error.localizedDescription
                )
            }
        }

        for index in deletedTransactions.indices {
            let transaction = deletedTransactions[index]
            guard transaction.merchant == trimmedMerchant,
                  transaction.category != category else {
                continue
            }
            let updated = transaction.replacingCategory(category)
            deletedTransactions[index] = updated
            do {
                try transactionStore?.update(transaction: updated)
                updatedCount += 1
            } catch {
                lastImportSummary = localizedFormat(
                    "ledger.status.category_deleted_refresh_failed_format",
                    fallback: "分类偏好已保存，但刷新最近删除账单 %@ 时写入本地存储失败：%@",
                    transaction.merchant,
                    error.localizedDescription
                )
            }
        }

        if updatedCount > 0 {
            sortTransactions()
            reloadWidgets()
        }
        return updatedCount
    }

    @discardableResult
    func applyDataCleaningPreview(_ preview: DataCleaningPreviewItem) -> DataCleaningApplicationResult {
        applyDataCleaningPreviews(
            [preview],
            previewID: preview.id,
            kind: preview.kind
        )
    }

    @discardableResult
    func applyDataCleaningPreviews(_ previews: [DataCleaningPreviewItem]) -> DataCleaningApplicationResult {
        var seenIDs = Set<String>()
        let deduplicatedPreviews = previews.filter { preview in
            guard !seenIDs.contains(preview.id) else { return false }
            seenIDs.insert(preview.id)
            return true
        }
        guard let firstPreview = deduplicatedPreviews.first else {
            let result = DataCleaningApplicationResult(
                previewID: "batch:empty",
                kind: .merchantAlias,
                updatedCount: 0,
                deletedCount: 0,
                skippedCount: 0,
                canUndo: false
            )
            lastDataCleaningApplicationResult = result
            lastDataCleaningUndoSnapshot = nil
            lastImportSummary = localizedMessage("ledger.status.cleaning_empty", fallback: "没有需要应用的数据清洗项。")
            return result
        }

        let batchID = deduplicatedPreviews.count == 1
            ? firstPreview.id
            : "batch:\(deduplicatedPreviews.map(\.id).joined(separator: "|"))"
        return applyDataCleaningPreviews(
            deduplicatedPreviews,
            previewID: batchID,
            kind: firstPreview.kind
        )
    }

    @discardableResult
    private func applyDataCleaningPreviews(
        _ previews: [DataCleaningPreviewItem],
        previewID: String,
        kind: DataCleaningPreviewKind
    ) -> DataCleaningApplicationResult {
        let previousActive = transactions
        let previousDeleted = deletedTransactions
        let previousMerchantAliases = merchantAliases
        let previousMerchantAliasDeletedKeys = merchantAliasDeletedKeys
        var updatedCount = 0
        var deletedCount = 0
        var skippedCount = 0
        var ruleChanged = false

        do {
            for preview in previews {
                let affectedIDs = Set(preview.affectedTransactionIDs)
                switch preview.kind {
                case .merchantAlias:
                    let trimmedOriginal = preview.currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedAlias = preview.proposedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedOriginal.isEmpty,
                       !trimmedAlias.isEmpty,
                       trimmedOriginal != trimmedAlias,
                       merchantAliases[trimmedOriginal] != trimmedAlias {
                        recordMerchantAlias(original: trimmedOriginal, alias: trimmedAlias)
                        ruleChanged = true
                    }
                    for transaction in transactions where affectedIDs.contains(transaction.id) {
                        guard let updated = transaction.applyingMerchantAlias(
                            original: preview.currentValue,
                            alias: preview.proposedValue
                        ) else {
                            skippedCount += 1
                            continue
                        }
                        try updateTransactionForDataCleaning(updated)
                        updatedCount += 1
                    }

                case .categoryCorrection:
                    guard let categoryRawValue = categoryRawValue(from: preview) else {
                        skippedCount += preview.affectedTransactionIDs.count
                        continue
                    }
                    for transaction in transactions where affectedIDs.contains(transaction.id) {
                        guard transaction.category != categoryRawValue else {
                            skippedCount += 1
                            continue
                        }
                        try updateTransactionForDataCleaning(transaction.replacingCategory(categoryRawValue))
                        updatedCount += 1
                    }

                case .duplicateCandidate:
                    let affected = transactions
                        .filter { affectedIDs.contains($0.id) }
                        .sorted { $0.occurredAt > $1.occurredAt }
                    for transaction in affected.dropFirst() {
                        try softDeleteTransactionForDataCleaning(transaction)
                        deletedCount += 1
                    }
                    skippedCount += max(0, preview.affectedTransactionIDs.count - affected.count)
                }
            }
        } catch {
            restoreDataCleaningSnapshot(active: previousActive, deleted: previousDeleted)
            restoreMerchantAliasState(
                aliases: previousMerchantAliases,
                deletedKeys: previousMerchantAliasDeletedKeys
            )
            lastImportSummary = localizedFormat(
                "ledger.status.cleaning_failed_format",
                fallback: "数据清洗应用失败，已尝试恢复到应用前状态：%@",
                error.localizedDescription
            )
            let result = DataCleaningApplicationResult(
                previewID: previewID,
                kind: kind,
                updatedCount: 0,
                deletedCount: 0,
                skippedCount: previews.reduce(0) { $0 + $1.affectedTransactionIDs.count },
                canUndo: false
            )
            lastDataCleaningApplicationResult = result
            return result
        }

        let changedCount = updatedCount + deletedCount
        let canUndo = changedCount > 0 || ruleChanged
        let result = DataCleaningApplicationResult(
            previewID: previewID,
            kind: kind,
            updatedCount: updatedCount,
            deletedCount: deletedCount,
            skippedCount: skippedCount,
            canUndo: canUndo
        )
        lastDataCleaningApplicationResult = result

        if canUndo {
            lastDataCleaningUndoSnapshot = DataCleaningUndoSnapshot(
                previewID: previewID,
                kind: kind,
                previousActiveTransactions: previousActive,
                previousDeletedTransactions: previousDeleted,
                previousMerchantAliases: previousMerchantAliases,
                previousMerchantAliasDeletedKeys: previousMerchantAliasDeletedKeys,
                updatedCount: updatedCount,
                deletedCount: deletedCount
            )
            recordDataCleaningApplicationHistory(previews: previews, result: result)
            sortTransactions()
            lastImportSummary = localizedFormat(
                "ledger.status.cleaning_applied_format",
                fallback: "已应用数据清洗：更新 %d 笔，移入最近删除 %d 笔。",
                updatedCount,
                deletedCount
            )
            reloadWidgets()
            requestAutomaticBackup()
            scheduleCloudKitPushAfterLocalLedgerChange()
        } else {
            lastDataCleaningUndoSnapshot = nil
            lastImportSummary = localizedMessage("ledger.status.cleaning_empty", fallback: "没有需要应用的数据清洗项。")
        }

        return result
    }

    @discardableResult
    func undoLastDataCleaningApplication() -> DataCleaningApplicationResult? {
        guard let snapshot = lastDataCleaningUndoSnapshot else {
            lastImportSummary = localizedMessage("ledger.status.cleaning_nothing_to_undo", fallback: "没有可撤销的数据清洗操作。")
            return nil
        }

        restoreDataCleaningSnapshot(
            active: snapshot.previousActiveTransactions,
            deleted: snapshot.previousDeletedTransactions
        )
        restoreMerchantAliasState(
            aliases: snapshot.previousMerchantAliases,
            deletedKeys: snapshot.previousMerchantAliasDeletedKeys
        )
        let result = DataCleaningApplicationResult(
            previewID: snapshot.previewID,
            kind: snapshot.kind,
            updatedCount: snapshot.updatedCount,
            deletedCount: snapshot.deletedCount,
            skippedCount: 0,
            canUndo: false
        )
        lastDataCleaningApplicationResult = result
        lastDataCleaningUndoSnapshot = nil
        markDataCleaningApplicationHistoryUndone(previewID: snapshot.previewID)
        lastImportSummary = localizedMessage("ledger.status.cleaning_undone", fallback: "已撤销上一次数据清洗操作。")
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        return result
    }

    private func updateTransactionForDataCleaning(_ transaction: Transaction) throws {
        let resolvedTransaction: Transaction
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            resolvedTransaction = transaction.ledgerID == nil
                ? transaction.assigningLedgerIDIfMissing(transactions[index].resolvedLedgerID())
                : transaction
            transactions[index] = resolvedTransaction
        } else if let index = deletedTransactions.firstIndex(where: { $0.id == transaction.id }) {
            resolvedTransaction = transaction.ledgerID == nil
                ? transaction.assigningLedgerIDIfMissing(deletedTransactions[index].resolvedLedgerID())
                : transaction
            deletedTransactions[index] = resolvedTransaction
        } else {
            resolvedTransaction = transaction.assigningLedgerIDIfMissing()
        }
        try transactionStore?.update(transaction: resolvedTransaction)
    }

    private func softDeleteTransactionForDataCleaning(_ transaction: Transaction) throws {
        try transactionStore?.delete(transactionID: transaction.id)
        transactions.removeAll { $0.id == transaction.id }
        deletedTransactions.removeAll { $0.id == transaction.id }
        deletedTransactions.insert(transaction, at: 0)
        if deletedTransactions.count > 50 {
            deletedTransactions = Array(deletedTransactions.prefix(50))
        }
    }

    private func categoryRawValue(from preview: DataCleaningPreviewItem) -> String? {
        if let category = TransactionCategory.allCases.first(where: { $0.title == preview.proposedValue }) {
            return category.rawValue
        }
        guard let rawValue = preview.id.components(separatedBy: "->").last,
              TransactionCategory(rawValue: rawValue) != nil else {
            return nil
        }
        return rawValue
    }

    private func restoreDataCleaningSnapshot(active: [Transaction], deleted: [Transaction]) {
        let previousByID = Dictionary(uniqueKeysWithValues: (active + deleted).map { ($0.id, $0) })
        let activeIDs = Set(active.map(\.id))
        let deletedIDs = Set(deleted.map(\.id))
        let currentByID = Dictionary(uniqueKeysWithValues: (transactions + deletedTransactions).map { ($0.id, $0) })
        let currentDeletedIDs = Set(deletedTransactions.map(\.id))
        let currentActiveIDs = Set(transactions.map(\.id))

        for id in activeIDs {
            guard let transaction = previousByID[id] else { continue }
            guard currentByID[id] != transaction || currentDeletedIDs.contains(id) else { continue }
            do {
                if deletedTransactions.contains(where: { $0.id == id }),
                   let sqlStore = transactionStore as? SQLiteTransactionStore {
                    try sqlStore.restoreTransaction(id: id)
                }
                try transactionStore?.update(transaction: transaction)
            } catch {
                lastImportSummary = localizedFormat("ledger.status.cleaning_restore_failed_format", fallback: "恢复数据清洗快照时写入失败：%@", error.localizedDescription)
            }
        }

        for id in deletedIDs {
            guard let transaction = previousByID[id] else { continue }
            guard currentByID[id] != transaction || currentActiveIDs.contains(id) else { continue }
            do {
                try transactionStore?.update(transaction: transaction)
                try transactionStore?.delete(transactionID: id)
            } catch {
                lastImportSummary = localizedFormat("ledger.status.cleaning_restore_deleted_failed_format", fallback: "恢复最近删除状态时写入失败：%@", error.localizedDescription)
            }
        }

        for id in currentByID.keys where previousByID[id] == nil {
            do {
                try transactionStore?.delete(transactionID: id)
            } catch {
                lastImportSummary = localizedFormat("ledger.status.cleaning_restore_new_failed_format", fallback: "恢复数据清洗快照时处理新增账单失败：%@", error.localizedDescription)
            }
        }

        transactions = active
        deletedTransactions = Array(deleted.prefix(50))
        sortTransactions()
    }

    private func restoreMerchantAliasState(aliases: [String: String], deletedKeys: Set<String>) {
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            let currentKeys = Set(merchantAliases.keys)
            let restoredKeys = Set(aliases.keys)
            for removedKey in currentKeys.subtracting(restoredKeys) {
                try? sqlStore.deleteMerchantAlias(original: removedKey)
            }
            for (original, alias) in aliases {
                try? sqlStore.saveMerchantAlias(original: original, alias: alias)
            }
        }
        merchantAliases = aliases
        merchantAliasDeletedKeys = deletedKeys
        UserDefaults.standard.set(merchantAliases, forKey: "merchantAliases")
        persistMerchantAliasDeletedKeys()
        markLedgerConfigurationChanged()
    }

    private func recordDataCleaningApplicationHistory(
        previews: [DataCleaningPreviewItem],
        result: DataCleaningApplicationResult
    ) {
        let entry = DataCleaningApplicationHistoryEntry(
            previewID: result.previewID,
            kind: result.kind,
            previewCount: previews.count,
            previewTitles: previews.map(\.title),
            updatedCount: result.updatedCount,
            deletedCount: result.deletedCount,
            skippedCount: result.skippedCount
        )
        dataCleaningApplicationHistory.insert(entry, at: 0)
        if dataCleaningApplicationHistory.count > Self.dataCleaningApplicationHistoryLimit {
            dataCleaningApplicationHistory = Array(dataCleaningApplicationHistory.prefix(Self.dataCleaningApplicationHistoryLimit))
        }
        persistDataCleaningApplicationHistory()
    }

    private func markDataCleaningApplicationHistoryUndone(previewID: String) {
        guard let index = dataCleaningApplicationHistory.firstIndex(where: {
            $0.previewID == previewID && $0.undoneAt == nil
        }) else {
            return
        }
        dataCleaningApplicationHistory[index].undoneAt = Date()
        persistDataCleaningApplicationHistory()
    }

    private func learnMerchantAliasIfNeeded(from original: Transaction, to updated: Transaction) {
        guard let candidate = merchantAliasCandidate(from: original, to: updated) else { return }
        recordMerchantAlias(original: candidate.original, alias: candidate.alias)
    }

    private func merchantAliasCandidate(from original: Transaction, to updated: Transaction) -> (original: String, alias: String)? {
        let originalMerchant = original.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedMerchant = updated.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !originalMerchant.isEmpty,
              !updatedMerchant.isEmpty,
              originalMerchant != updatedMerchant,
              merchantAliases[originalMerchant] != updatedMerchant else {
            return nil
        }
        return (originalMerchant, updatedMerchant)
    }

    private func isHighConfidenceGeneratedTransaction(_ id: UUID) -> Bool {
        debugRecords.contains {
            $0.stage == .persisted &&
            $0.transactionID == id &&
            ($0.llmConfidence ?? $0.parsedReceipt?.confidence ?? 0) >= 0.7
        }
    }

    private func createTransaction(
        from receipt: ImportedReceipt,
        rawText: String,
        notePrefix: String,
        imageSource: ImageSource = .unknown,
        llmTrace: SmartReceiptParser.LLMTrace? = nil,
        usedRuleFallback: Bool = true
    ) {
        persistReceipt(
            receipt,
            rawText: rawText,
            notePrefix: notePrefix,
            imageSource: imageSource,
            llmTrace: llmTrace,
            usedRuleFallback: usedRuleFallback
        )
    }

    @discardableResult
    private func persistReceipt(
        _ inReceipt: ImportedReceipt,
        rawText: String,
        notePrefix: String,
        imageSource: ImageSource = .unknown,
        llmTrace: SmartReceiptParser.LLMTrace? = nil,
        usedRuleFallback: Bool = true,
        conversionQuote: CurrencyConversionPreviewQuote? = nil
    ) -> Bool {
        let receipt = MerchantAliasResolver.applyingAlias(
            to: inReceipt,
            aliases: merchantAliases,
            categoryCorrections: categoryCorrections,
            contextText: rawText
        )
        if receipt.merchant != inReceipt.merchant {
            logger.info("[别名] \(inReceipt.merchant) → \(receipt.merchant)")
        }

        if hasDuplicate(receipt, rawText: rawText) {
            let summary = "\(receipt.merchant) 已存在同日同金额记录或 OCR 文本高度相似，账本未重复写入。"
            lastImportSummary = summary
            recordDebugEvent(
                stage: .duplicateSkipped,
                source: receipt.source,
                imageSource: imageSource,
                rawText: rawText,
                parsedReceipt: receipt,
                summary: summary,
                llmPrompt: llmTrace?.prompt,
                llmResponse: llmTrace?.response,
                llmProvider: llmTrace?.providerID,
                llmLatencyMs: llmTrace?.latencyMs,
                llmConfidence: receipt.confidence,
                usedRuleFallback: usedRuleFallback
            )
            return true
        }

        let sourceCurrencyCode = LedgerCurrencyOption.supportedCode(matching: receipt.currencyCode ?? ExpenseCurrencyPreference.currentCode)
        let resolvedReceipt = receipt.replacingCurrencyCode(sourceCurrencyCode)
        let targetLedgerID = targetLedgerIDForNewTransactions
        let targetCurrencyCode = ledgerCurrencyCode(for: targetLedgerID)
        let usableQuote = usableConversionQuote(
            conversionQuote,
            sourceAmount: resolvedReceipt.amount,
            sourceCurrencyCode: sourceCurrencyCode,
            targetCurrencyCode: targetCurrencyCode
        )
        let baseTransaction = Transaction(
            merchant: resolvedReceipt.merchant,
            amount: usableQuote?.convertedAmount ?? resolvedReceipt.amount,
            occurredAt: resolvedReceipt.occurredAt,
            category: resolvedReceipt.suggestedCategory,
            source: resolvedReceipt.source,
            note: notePrefix,
            ledgerID: targetLedgerID,
            ledgerCurrencyCode: targetCurrencyCode,
            originalAmount: sourceCurrencyCode == targetCurrencyCode ? nil : resolvedReceipt.amount,
            originalCurrencyCode: sourceCurrencyCode == targetCurrencyCode ? nil : sourceCurrencyCode,
            exchangeRate: usableQuote?.rate,
            exchangeRateDate: usableQuote?.rateDate,
            exchangeRateProvider: usableQuote?.provider
        )
        let transaction = usableQuote == nil
            ? transactionPreparedForLedgerCurrency(baseTransaction, sourceAmount: resolvedReceipt.amount, sourceCurrencyCode: sourceCurrencyCode)
            : baseTransaction
        do {
            try transactionStore?.save(transaction: transaction)
        } catch {
            let summary = "账单已导入，但写入本地存储失败：\(error.localizedDescription)"
            lastImportSummary = summary
            recordDebugEvent(
                stage: .persistenceFailed,
                source: resolvedReceipt.source,
                imageSource: imageSource,
                rawText: rawText,
                parsedReceipt: resolvedReceipt,
                summary: summary,
                llmPrompt: llmTrace?.prompt,
                llmResponse: llmTrace?.response,
                llmProvider: llmTrace?.providerID,
                llmLatencyMs: llmTrace?.latencyMs,
                llmConfidence: resolvedReceipt.confidence,
                usedRuleFallback: usedRuleFallback
            )
            return false
        }

        recentImports.insert(resolvedReceipt, at: 0)
        transactions.insert(transaction, at: 0)
        sortTransactions()

        let summary = "已导入 \(resolvedReceipt.merchant)，金额 \(AppFormatters.currency(resolvedReceipt.amount, code: sourceCurrencyCode))。"
        let debugSummary = resolvedReceipt.parseDiagnostics.map { "\(summary)\n调试：\($0.debugSummary)" } ?? summary
        lastImportSummary = summary
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        scheduleCurrencyConversionIfNeeded(for: transaction.id)
        recordDebugEvent(
            stage: .persisted,
            source: resolvedReceipt.source,
            imageSource: imageSource,
            rawText: rawText,
            parsedReceipt: resolvedReceipt,
            summary: debugSummary,
            llmPrompt: llmTrace?.prompt,
            llmResponse: llmTrace?.response,
            transactionID: transaction.id,
            llmProvider: llmTrace?.providerID,
            llmLatencyMs: llmTrace?.latencyMs,
            llmConfidence: resolvedReceipt.confidence,
            usedRuleFallback: usedRuleFallback
        )
        return true
    }

    private func usableConversionQuote(
        _ quote: CurrencyConversionPreviewQuote?,
        sourceAmount: Double,
        sourceCurrencyCode: String,
        targetCurrencyCode: String
    ) -> CurrencyConversionPreviewQuote? {
        guard let quote,
              quote.sourceCurrencyCode == sourceCurrencyCode,
              quote.targetCurrencyCode == targetCurrencyCode,
              abs(quote.sourceAmount - sourceAmount) < 0.001
        else {
            return nil
        }
        return quote
    }

    private func hasDuplicate(_ receipt: ImportedReceipt, rawText: String = "") -> Bool {
        // 原有策略：60s 窗口 + 同商户同金额
        let windowMatch = transactions.contains {
            $0.merchant == receipt.merchant &&
            abs($0.amount - receipt.amount) < 0.01 &&
            abs($0.occurredAt.timeIntervalSince(receipt.occurredAt)) < 60
        }
        if windowMatch { return true }

        // 增强策略：OCR 文本 Jaccard 相似度 > 0.8 视为同一来源
        // 注意：只使用仍指向活跃账单的调试记录，避免删除/彻底删除后重试被误判为重复。
        // 旧版本调试记录可能没有 transactionID，这类记录无法证明账单仍然存在，因此不参与 OCR 相似度去重。
        if ImportDuplicateDetector.hasOCRTextDuplicate(
            rawText: rawText,
            debugRecords: debugRecords,
            activeTransactionIDs: Set(transactions.map(\.id)),
            parsedAmount: receipt.amount,
            threshold: 0.8
        ) {
            logger.info("[去重] OCR Jaccard 相似度命中（>0.8），判定为重复来源")
            return true
        }
        return false
    }

    private func sortTransactions() {
        transactions.sort { lhs, rhs in
            if lhs.occurredAt == rhs.occurredAt {
                return lhs.id.uuidString > rhs.id.uuidString
            }
            return lhs.occurredAt > rhs.occurredAt
        }
    }

    @discardableResult
    private func normalizeHotelLinkedTransactionCategories(persist: Bool) -> Int {
        var updatedTransactions: [Transaction] = []
        for index in transactions.indices {
            let transaction = transactions[index]
            let normalized = assigningHotelCategoryIfNeeded(transaction)
            guard normalized != transaction else { continue }
            transactions[index] = normalized
            updatedTransactions.append(normalized)
        }

        guard !updatedTransactions.isEmpty else { return 0 }
        sortTransactions()

        if persist {
            for transaction in updatedTransactions {
                try? transactionStore?.update(transaction: transaction)
            }
        }
        return updatedTransactions.count
    }

    private func assigningHotelCategoryIfNeeded(_ transaction: Transaction) -> Transaction {
        guard let linkedHotelStayRecordID = linkedHotelStayRecordID(for: transaction),
              transaction.category != TransactionCategory.hotel.rawValue ||
              transaction.hotelStayRecordID != linkedHotelStayRecordID else {
            return transaction
        }

        return Transaction(
            id: transaction.id,
            merchant: transaction.merchant,
            amount: transaction.amount,
            occurredAt: transaction.occurredAt,
            categoryLabel: TransactionCategory.hotel.rawValue,
            sourceLabel: transaction.source,
            note: transaction.note,
            ledgerID: transaction.resolvedLedgerID(),
            hotelStayRecordID: linkedHotelStayRecordID,
            ledgerCurrencyCode: transaction.ledgerCurrencyCode,
            originalAmount: transaction.originalAmount,
            originalCurrencyCode: transaction.originalCurrencyCode,
            exchangeRate: transaction.exchangeRate,
            exchangeRateDate: transaction.exchangeRateDate,
            exchangeRateProvider: transaction.exchangeRateProvider
        )
    }

    private func hotelLinkedTransaction(
        _ transaction: Transaction,
        recordID: UUID,
        ledgerID: String
    ) -> Transaction {
        Transaction(
            id: transaction.id,
            merchant: transaction.merchant,
            amount: transaction.amount,
            occurredAt: transaction.occurredAt,
            categoryLabel: TransactionCategory.hotel.rawValue,
            sourceLabel: transaction.source,
            note: transaction.note,
            ledgerID: transaction.resolvedLedgerID(defaultLedgerID: ledgerID),
            hotelStayRecordID: recordID,
            ledgerCurrencyCode: transaction.ledgerCurrencyCode,
            originalAmount: transaction.originalAmount,
            originalCurrencyCode: transaction.originalCurrencyCode,
            exchangeRate: transaction.exchangeRate,
            exchangeRateDate: transaction.exchangeRateDate,
            exchangeRateProvider: transaction.exchangeRateProvider
        )
    }

    private func linkedHotelStayRecordID(for transaction: Transaction) -> UUID? {
        if let hotelStayRecordID = transaction.hotelStayRecordID {
            return hotelStayRecordID
        }
        return hotelStayRecords.first { $0.linkedTransactionID == transaction.id }?.id
    }

    private func sortHotelStayRecords() {
        hotelStayRecords.sort { lhs, rhs in
            let lhsDate = lhs.checkOutDate ?? ""
            let rhsDate = rhs.checkOutDate ?? ""
            if lhsDate == rhsDate {
                return lhs.createdAt > rhs.createdAt
            }
            return lhsDate > rhsDate
        }
    }

    private func upsertHotelStayDraftInMemory(_ draft: HotelStayDraft) {
        if let index = hotelStayDrafts.firstIndex(where: { $0.id == draft.id }) {
            hotelStayDrafts[index] = draft
        } else {
            hotelStayDrafts.insert(draft, at: 0)
        }
        sortHotelStayDrafts()
    }

    private func sortHotelStayDrafts() {
        hotelStayDrafts.sort { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func duplicateHotelStayDraftState(for draft: HotelStayDraft) -> HotelStayDraftDuplicateState? {
        for existingDraft in hotelStayDrafts where existingDraft.id != draft.id {
            guard hotelStayDraftFingerprintMatches(draft, existingDraft) else { continue }
            switch existingDraft.status {
            case .rejected:
                continue
            case .confirmed, .postedToLedger:
                return .posted
            case .imported, .textExtracted, .parsed, .needsReview:
                return .pending
            }
        }

        if hotelStayRecords.contains(where: { hotelStayRecordFingerprintMatches(record: $0, draft: draft) }) {
            return .posted
        }
        return nil
    }

    private func hotelStayDraftFingerprintMatches(_ lhs: HotelStayDraft, _ rhs: HotelStayDraft) -> Bool {
        if let lhsHash = lhs.sourceEmailAttachmentHash?.nilIfEmptyForLedgerStore,
           let rhsHash = rhs.sourceEmailAttachmentHash?.nilIfEmptyForLedgerStore,
           lhsHash == rhsHash {
            return true
        }

        if let lhsMessageHash = lhs.sourceEmailMessageIDHash?.nilIfEmptyForLedgerStore,
           let rhsMessageHash = rhs.sourceEmailMessageIDHash?.nilIfEmptyForLedgerStore,
           lhsMessageHash == rhsMessageHash {
            let lhsFileName = normalizedHotelDraftFileName(lhs.sourceFileName)
            let rhsFileName = normalizedHotelDraftFileName(rhs.sourceFileName)
            if lhsFileName == nil || rhsFileName == nil || lhsFileName == rhsFileName {
                return true
            }
        }

        if let lhsData = lhs.sourcePDFData,
           let rhsData = rhs.sourcePDFData,
           !lhsData.isEmpty,
           lhsData == rhsData {
            return true
        }
        return false
    }

    private func hotelStayRecordFingerprintMatches(record: HotelStayRecord, draft: HotelStayDraft) -> Bool {
        if let attachmentHash = draft.sourceEmailAttachmentHash?.nilIfEmptyForLedgerStore,
           let recordData = record.sourcePDFData,
           HotelFolioEmailFingerprint.attachmentHash(recordData) == attachmentHash {
            return true
        }

        if let draftData = draft.sourcePDFData,
           let recordData = record.sourcePDFData,
           !draftData.isEmpty,
           draftData == recordData {
            return true
        }

        let draftFileName = normalizedHotelDraftFileName(draft.sourceFileName)
        let recordFileName = normalizedHotelDraftFileName(record.sourceFileName)
        if let draftFileName,
           draftFileName == recordFileName,
           !draft.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           draft.rawText == record.rawText {
            return true
        }
        return false
    }

    private func normalizedHotelDraftFileName(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .nilIfEmptyForLedgerStore
    }

    private func duplicateHotelStayDraftMessage(for state: HotelStayDraftDuplicateState) -> String {
        switch state {
        case .pending:
            return localizedMessage(
                "hotel_stay.draft.duplicate.pending",
                fallback: "这份酒店水单已在待确认队列。"
            )
        case .rejected:
            return localizedMessage(
                "hotel_stay.draft.duplicate.rejected",
                fallback: "这份酒店水单此前已拒绝，本次不会重复导入。"
            )
        case .posted:
            return localizedMessage(
                "hotel_stay.draft.duplicate.posted",
                fallback: "这份酒店水单已经入账，本次不会重复导入。"
            )
        }
    }

    private func localizedMessage(_ key: String, fallback: String) -> String {
        guard
            let path = Bundle.main.path(forResource: ledgerStatusLanguageKey, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
        }
        return bundle.localizedString(forKey: key, value: fallback, table: nil)
    }

    private func localizedFormat(_ key: String, fallback: String, _ arguments: CVarArg...) -> String {
        String(
            format: localizedMessage(key, fallback: fallback),
            locale: ledgerStatusLocale,
            arguments: arguments
        )
    }

    private var ledgerStatusLanguageKey: String {
        let preference = UserDefaults.standard.string(forKey: "appLanguagePreference") ?? "system"
        if ["zh-Hans", "zh-Hant", "en", "ja", "ko"].contains(preference) {
            return preference
        }
        let normalized = Locale.autoupdatingCurrent.identifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        if normalized.hasPrefix("ja") { return "ja" }
        if normalized.hasPrefix("ko") { return "ko" }
        if normalized.contains("hant") || normalized.contains("-tw") || normalized.contains("-hk") || normalized.contains("-mo") {
            return "zh-Hant"
        }
        if normalized.hasPrefix("zh") { return "zh-Hans" }
        return "en"
    }

    private var ledgerStatusLocale: Locale {
        Locale(identifier: ledgerStatusLanguageKey)
    }

    private func appendImportSummary(_ text: String) {
        if let existing = lastImportSummary {
            lastImportSummary = existing + "\n" + text
        } else {
            lastImportSummary = text
        }
    }

    private func recordDebugEvent(
        stage: ImportDebugStage,
        source: ReceiptSource,
        imageSource: ImageSource = .unknown,
        rawText: String,
        parsedReceipt: ImportedReceipt?,
        summary: String,
        llmPrompt: String? = nil,
        llmResponse: String? = nil,
        transactionID: UUID? = nil,
        llmProvider: String? = nil,
        llmLatencyMs: Int? = nil,
        llmConfidence: Double? = nil,
        usedRuleFallback: Bool = true
    ) {
        let record = ImportDebugRecord(
            createdAt: .now,
            stage: stage,
            source: source,
            imageSource: imageSource,
            rawText: rawText,
            parsedReceipt: parsedReceipt,
            summary: summary,
            llmPrompt: llmPrompt,
            llmResponse: llmResponse,
            transactionID: transactionID,
            llmProvider: llmProvider,
            llmLatencyMs: llmLatencyMs,
            llmConfidence: llmConfidence,
            usedRuleFallback: usedRuleFallback
        )
        appendDebugRecord(record)
    }

    private func appendDebugRecord(_ record: ImportDebugRecord) {
        debugRecords.insert(record, at: 0)
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.saveDebugEvent(record)
        }
    }

    private static func loadInitialDebugRecords(using store: TransactionStore?) -> [ImportDebugRecord] {
        guard let sqlStore = store as? SQLiteTransactionStore else { return [] }
        return (try? sqlStore.loadDebugEvents()) ?? []
    }

    private static func loadInitialHotelStayRecords(using store: TransactionStore?) -> [HotelStayRecord] {
        guard let sqlStore = store as? SQLiteTransactionStore else { return [] }
        return (try? sqlStore.loadHotelStayRecords()) ?? []
    }

    private static func loadInitialHotelStayDrafts(using store: TransactionStore?) -> [HotelStayDraft] {
        guard let sqlStore = store as? SQLiteTransactionStore else { return [] }
        return (try? sqlStore.loadHotelStayDrafts()) ?? []
    }

    private static func loadInitialLedgerSyncConflictRecords(using store: TransactionStore?) -> [TransactionSyncRecord] {
        guard let sqlStore = store as? SQLiteTransactionStore else { return [] }
        return (try? sqlStore.loadConflictedTransactionSyncRecords()) ?? []
    }

    // MARK: - Subscriptions

    /// 新增或更新订阅（去重：同商户 + 同周期命中时更新，否则新增）
    func upsertSubscription(_ sub: Subscription) {
        guard let sqlStore = transactionStore as? SQLiteTransactionStore else { return }

        if let idx = subscriptions.firstIndex(where: {
            $0.merchant == sub.merchant && $0.period == sub.period
        }) {
            guard sub.lastChargedAt >= subscriptions[idx].lastChargedAt else { return }
            let updated = subscriptions[idx].updated(
                lastChargedAt: sub.lastChargedAt,
                amount: sub.amount,
                currencyCode: sub.currencyCode
            )
            subscriptions[idx] = updated
            try? sqlStore.updateSubscription(updated)
        } else {
            subscriptions.append(sub)
            subscriptions.sort { $0.nextChargedAt < $1.nextChargedAt }
            try? sqlStore.saveSubscription(sub)
        }
        NotificationService.shared.scheduleUpcomingChargeReminders(for: subscriptions)
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    func createSubscription(_ sub: Subscription) {
        guard let sqlStore = transactionStore as? SQLiteTransactionStore else { return }
        subscriptions.append(sub)
        subscriptions.sort { $0.nextChargedAt < $1.nextChargedAt }
        try? sqlStore.saveSubscription(sub)
        NotificationService.shared.scheduleUpcomingChargeReminders(for: subscriptions)
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    func deleteSubscription(_ sub: Subscription) {
        subscriptions.removeAll { $0.id == sub.id }
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.deleteSubscription(id: sub.id)
        }
        NotificationService.shared.cancelSubscriptionReminder(id: sub.id)
        NotificationService.shared.scheduleUpcomingChargeReminders(for: subscriptions)
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    func updateSubscription(_ sub: Subscription) {
        guard let idx = subscriptions.firstIndex(where: { $0.id == sub.id }) else { return }
        subscriptions[idx] = sub
        subscriptions.sort { $0.nextChargedAt < $1.nextChargedAt }
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.updateSubscription(sub)
        }
        NotificationService.shared.scheduleUpcomingChargeReminders(for: subscriptions)
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    func updateSubscriptionStatus(_ sub: Subscription, status: SubscriptionStatus) {
        updateSubscription(sub.updated(status: status))
    }

    func recordSubscriptionMetadataChanged() {
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    /// 扫描全部历史账单，自动识别并保存周期性订阅
    func detectAndUpsertSubscriptions() {
        let detected = detectSubscriptionsForCurrentLedger()
        for sub in detected { upsertSubscription(sub) }
    }

    private static func loadInitialSubscriptions(using store: TransactionStore?) -> [Subscription] {
        guard let sqlStore = store as? SQLiteTransactionStore else { return [] }
        return (try? sqlStore.loadSubscriptions()) ?? []
    }

    private static func loadInitialDeletedTransactions(using store: TransactionStore?) -> [Transaction] {
        guard let sqlStore = store as? SQLiteTransactionStore else { return [] }
        return (try? sqlStore.loadDeletedTransactions()) ?? []
    }

    // MARK: - Category Corrections

    func recordCategoryCorrection(merchant: String, category: TransactionCategory) {
        categoryCorrections[merchant] = category
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.saveCategoryCorrection(merchant: merchant, category: category)
        }
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    func deleteCategoryCorrection(merchant: String) {
        categoryCorrections.removeValue(forKey: merchant)
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.deleteCategoryCorrection(merchant: merchant)
        }
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    private static func loadInitialCategoryCorrections(using store: TransactionStore?) -> [String: TransactionCategory] {
        guard let sqlStore = store as? SQLiteTransactionStore else { return [:] }
        return (try? sqlStore.loadCategoryCorrections()) ?? [:]
    }

    private static func loadInitialMerchantAliases(using store: TransactionStore?) -> [String: String] {
        guard let sqlStore = store as? SQLiteTransactionStore else {
            return UserDefaults.standard.dictionary(forKey: "merchantAliases") as? [String: String] ?? [:]
        }
        let fromSQL = (try? sqlStore.loadMerchantAliases()) ?? [:]
        if fromSQL.isEmpty {
            // 首次升级迁移：将 UserDefaults 中的旧数据写入 SQLite
            let fromDefaults = UserDefaults.standard.dictionary(forKey: "merchantAliases") as? [String: String] ?? [:]
            for (original, alias) in fromDefaults {
                try? sqlStore.saveMerchantAlias(original: original, alias: alias)
            }
            return fromDefaults
        }
        return fromSQL
    }

    private static func loadInitialLedgerProfiles(using store: TransactionStore?) -> [LedgerProfile] {
        guard let sqlStore = store as? SQLiteTransactionStore else {
            return [LedgerProfile.defaultLocal()]
        }
        let profiles = (try? sqlStore.loadLedgerProfiles(includeArchived: true)) ?? []
        return profiles.isEmpty ? [LedgerProfile.defaultLocal()] : profiles
    }

    private static func loadInitialSelectedLedgerID(from profiles: [LedgerProfile]) -> String {
        let activeProfiles = profiles.filter { !$0.isArchived }
        let activeIDs = Set(activeProfiles.map(\.id))
        if let saved = UserDefaults.standard.string(forKey: Self.selectedLedgerIDKey),
           activeIDs.contains(saved) {
            return saved
        }
        return activeProfiles.first { $0.isDefault }?.id ?? TodaySpendingSummary.defaultLedgerID
    }

    private static func loadInitialDefaultWriteLedgerID(from profiles: [LedgerProfile]) -> String {
        resolvedDefaultWriteLedgerID(
            UserDefaults.standard.string(forKey: Self.defaultWriteLedgerIDKey),
            from: profiles
        )
    }

    private static func loadMerchantAliasDeletedKeys() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.merchantAliasDeletedKeysKey) ?? [])
    }

    private func persistMerchantAliasDeletedKeys() {
        UserDefaults.standard.set(merchantAliasDeletedKeys.sorted(), forKey: Self.merchantAliasDeletedKeysKey)
    }

    private static func loadIgnoredDataCleaningPreviewIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.ignoredDataCleaningPreviewIDsKey) ?? [])
    }

    private func persistIgnoredDataCleaningPreviewIDs() {
        UserDefaults.standard.set(ignoredDataCleaningPreviewIDs.sorted(), forKey: Self.ignoredDataCleaningPreviewIDsKey)
    }

    private static func loadDataCleaningApplicationHistory() -> [DataCleaningApplicationHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: Self.dataCleaningApplicationHistoryKey),
              let entries = try? JSONDecoder().decode([DataCleaningApplicationHistoryEntry].self, from: data) else {
            return []
        }
        return Array(entries.prefix(Self.dataCleaningApplicationHistoryLimit))
    }

    private func persistDataCleaningApplicationHistory() {
        guard let data = try? JSONEncoder().encode(dataCleaningApplicationHistory) else { return }
        UserDefaults.standard.set(data, forKey: Self.dataCleaningApplicationHistoryKey)
    }

    private static func resolvedDefaultWriteLedgerID(_ candidate: String?, from profiles: [LedgerProfile]) -> String {
        let activeProfiles = profiles.filter { !$0.isArchived }
        let activeIDs = Set(activeProfiles.map(\.id))
        let trimmedCandidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if activeIDs.contains(trimmedCandidate) {
            return trimmedCandidate
        }
        if activeIDs.contains(TodaySpendingSummary.defaultLedgerID) {
            return TodaySpendingSummary.defaultLedgerID
        }
        return activeProfiles.first { $0.isDefault }?.id ??
            activeProfiles.first?.id ??
            TodaySpendingSummary.defaultLedgerID
    }

    private func reloadLedgerProfiles() {
        guard let sqlStore = transactionStore as? SQLiteTransactionStore else {
            sortLedgerProfiles()
            return
        }
        ledgerProfiles = ((try? sqlStore.loadLedgerProfiles(includeArchived: true)) ?? ledgerProfiles)
        if ledgerProfiles.isEmpty {
            ledgerProfiles = [LedgerProfile.defaultLocal()]
        }
        sortLedgerProfiles()
        normalizeDefaultWriteLedger()
        normalizeLedgerSelection()
    }

    private func sortLedgerProfiles() {
        ledgerProfiles.sort {
            if $0.sortOrder == $1.sortOrder {
                if $0.createdAt == $1.createdAt {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.createdAt < $1.createdAt
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    private func replaceLedgerProfile(_ profile: LedgerProfile) {
        if let index = ledgerProfiles.firstIndex(where: { $0.id == profile.id }) {
            ledgerProfiles[index] = profile
        } else {
            ledgerProfiles.append(profile)
        }
        sortLedgerProfiles()
    }

    private func recordLedgerProfileConfigurationChanged() {
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    private func normalizeLedgerSelection() {
        let activeIDs = Set(activeLedgerProfiles.map(\.id))
        guard !activeIDs.contains(selectedLedgerID) else {
            saveLedgerSelection()
            return
        }
        selectedLedgerID = defaultLedgerProfile.id
        isShowingAllLedgers = false
        saveLedgerSelection()
    }

    private func normalizeDefaultWriteLedger() {
        defaultWriteLedgerID = Self.resolvedDefaultWriteLedgerID(defaultWriteLedgerID, from: ledgerProfiles)
        saveDefaultWriteLedger()
    }

    private func saveLedgerSelection() {
        UserDefaults.standard.set(selectedLedgerID, forKey: Self.selectedLedgerIDKey)
        UserDefaults.standard.set(isShowingAllLedgers, forKey: Self.showAllLedgersKey)
    }

    private func saveDefaultWriteLedger() {
        UserDefaults.standard.set(defaultWriteLedgerID, forKey: Self.defaultWriteLedgerIDKey)
        Self.appGroupDefaults?.set(defaultWriteLedgerID, forKey: Self.defaultWriteLedgerIDKey)
    }

    private func normalizedMerchantKey(_ merchant: String) -> String {
        merchant
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private extension Transaction {
    func replacingCurrencyMetadata(
        amount newAmount: Double? = nil,
        ledgerCurrencyCode: String?,
        originalAmount: Double?,
        originalCurrencyCode: String?,
        exchangeRate: Double?,
        exchangeRateDate: String?,
        exchangeRateProvider: String?
    ) -> Transaction {
        Transaction(
            id: id,
            merchant: merchant,
            amount: newAmount ?? amount,
            occurredAt: occurredAt,
            categoryLabel: category,
            sourceLabel: source,
            note: note,
            ledgerID: ledgerID,
            hotelStayRecordID: hotelStayRecordID,
            ledgerCurrencyCode: ledgerCurrencyCode,
            originalAmount: originalAmount,
            originalCurrencyCode: originalCurrencyCode,
            exchangeRate: exchangeRate,
            exchangeRateDate: exchangeRateDate,
            exchangeRateProvider: exchangeRateProvider
        )
    }

    func applyingMerchantAlias(original: String, alias: String) -> Transaction? {
        guard merchant == original, alias != merchant else { return nil }
        return Transaction(
            id: id,
            merchant: alias,
            amount: amount,
            occurredAt: occurredAt,
            categoryLabel: category,
            sourceLabel: source,
            note: note,
            ledgerID: ledgerID,
            hotelStayRecordID: hotelStayRecordID,
            ledgerCurrencyCode: ledgerCurrencyCode,
            originalAmount: originalAmount,
            originalCurrencyCode: originalCurrencyCode,
            exchangeRate: exchangeRate,
            exchangeRateDate: exchangeRateDate,
            exchangeRateProvider: exchangeRateProvider
        )
    }

    func replacingCategory(_ category: String) -> Transaction {
        Transaction(
            id: id,
            merchant: merchant,
            amount: amount,
            occurredAt: occurredAt,
            categoryLabel: category,
            sourceLabel: source,
            note: note,
            ledgerID: ledgerID,
            hotelStayRecordID: hotelStayRecordID,
            ledgerCurrencyCode: ledgerCurrencyCode,
            originalAmount: originalAmount,
            originalCurrencyCode: originalCurrencyCode,
            exchangeRate: exchangeRate,
            exchangeRateDate: exchangeRateDate,
            exchangeRateProvider: exchangeRateProvider
        )
    }

    func replacingLedgerID(_ ledgerID: String) -> Transaction {
        Transaction(
            id: id,
            merchant: merchant,
            amount: amount,
            occurredAt: occurredAt,
            categoryLabel: category,
            sourceLabel: source,
            note: note,
            ledgerID: ledgerID,
            hotelStayRecordID: hotelStayRecordID,
            ledgerCurrencyCode: ledgerCurrencyCode,
            originalAmount: originalAmount,
            originalCurrencyCode: originalCurrencyCode,
            exchangeRate: exchangeRate,
            exchangeRateDate: exchangeRateDate,
            exchangeRateProvider: exchangeRateProvider
        )
    }
}

private extension LedgerProfile {
    func replacing(
        name: String? = nil,
        currency: String?? = nil,
        isDefault: Bool? = nil,
        archivedAt: Date?? = nil,
        updatedAt: Date? = nil
    ) -> LedgerProfile {
        LedgerProfile(
            id: id,
            name: name ?? self.name,
            iconName: iconName,
            colorName: colorName,
            currency: currency ?? self.currency,
            isDefault: isDefault ?? self.isDefault,
            sortOrder: sortOrder,
            archivedAt: archivedAt ?? self.archivedAt,
            createdAt: createdAt,
            updatedAt: updatedAt ?? self.updatedAt
        )
    }
}

extension LedgerStore {
    private static let annualPriceKey = "subscriptionAnnualPriceOverrides"
    private static let subscriptionNotesKey = "subscriptionNotes"
    private static let iCloudBackupEnabledKey = "iCloudBackupEnabled"
    private static let lastBackupAtKey = "lastBackupAt"
    private static let lastBackupBundleIdKey = "lastBackupBundleId"
    private static let lastBackupErrorKey = "lastBackupError"
    private static let ledgerCloudSyncEnabledKey = "ledgerCloudSyncEnabled"
    private static let lastSuccessfulCloudKitPushAtKey = "lastSuccessfulCloudKitPushAt"
    private static let lastSuccessfulCloudKitSyncAtKey = "lastSuccessfulCloudKitSyncAt"
    private static let ledgerSnapshotUpdatedAtKey = "ledgerSnapshotUpdatedAt"
    private static let ledgerConfigurationUpdatedAtKey = "ledgerConfigurationUpdatedAt"
    private static let allLedgersScopeID = "all-ledgers"
    private static let selectedLedgerIDKey = "selectedLedgerID"
    private static let defaultWriteLedgerIDKey = "defaultWriteLedgerID"
    private static let showAllLedgersKey = "showAllLedgers"
    private static let pendingIntentLedgerCloudPushKey = "pendingIntentLedgerCloudPush"
    private static let hotelStayRecordTombstonesKey = "hotelStayRecordCloudTombstones"
    private static let hotelStayDraftTombstonesKey = "hotelStayDraftCloudTombstones"
    private static let merchantAliasDeletedKeysKey = "merchantAliasDeletedKeys"
    private static let ignoredDataCleaningPreviewIDsKey = "ignoredDataCleaningPreviewIDs"
    private static let dataCleaningApplicationHistoryKey = "dataCleaningApplicationHistory"
    private static let dataCleaningApplicationHistoryLimit = 20
    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let syncDeviceIDKey = "top.darkrio326.AutoLedger.syncDeviceID"
    private static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    var isLocalDataEmptyForRestore: Bool {
        transactions.isEmpty &&
        deletedTransactions.isEmpty &&
        subscriptions.isEmpty &&
        hotelStayRecords.isEmpty &&
        hotelStayDrafts.isEmpty &&
        categoryCorrections.isEmpty &&
        customCategories.isEmpty &&
        customSources.isEmpty &&
        merchantAliases.isEmpty
    }

    var iCloudBackupEnabled: Bool {
        get { false }
        set {
            UserDefaults.standard.set(false, forKey: Self.iCloudBackupEnabledKey)
        }
    }

    var lastBackupAt: Date? {
        UserDefaults.standard.object(forKey: Self.lastBackupAtKey) as? Date
    }

    var ledgerDisplaySnapshotMetadata: [String: Any] {
        let snapshotUpdatedAt = Self.appGroupDefaults?.object(forKey: Self.ledgerSnapshotUpdatedAtKey) as? Date ?? Date()
        let lastCloudSyncAt = Self.appGroupDefaults?.object(forKey: Self.lastSuccessfulCloudKitSyncAtKey) as? Date
        var metadata: [String: Any] = [
            "snapshotUpdatedAt": snapshotUpdatedAt.timeIntervalSince1970,
            "isSnapshotStale": isLedgerCloudSyncEnabled && isCloudKitSnapshotStale(referenceDate: Date())
        ]
        if let lastCloudSyncAt {
            metadata["lastCloudSyncAt"] = lastCloudSyncAt.timeIntervalSince1970
        }
        return metadata
    }

    func makeBackupBundle() throws -> BackupBundle {
        let rawBackupTransactions: [BackupTransaction]
        let backupHotelStayRecords: [HotelStayRecord]
        let backupHotelStayDrafts: [HotelStayDraft]
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            rawBackupTransactions = try sqlStore.loadBackupTransactions()
            backupHotelStayRecords = try sqlStore.loadHotelStayRecords()
            backupHotelStayDrafts = try sqlStore.loadHotelStayDrafts()
        } else {
            rawBackupTransactions = transactions.map { BackupTransaction(transaction: $0) } +
                deletedTransactions.map { BackupTransaction(transaction: $0, deletedAt: .now) }
            backupHotelStayRecords = hotelStayRecords
            backupHotelStayDrafts = hotelStayDrafts
        }
        let backupTransactions = Self.normalizedHotelLinkedBackupTransactions(
            rawBackupTransactions,
            hotelStayRecords: backupHotelStayRecords
        )

        let annualPrices = UserDefaults.standard.dictionary(forKey: Self.annualPriceKey) as? [String: Double] ?? [:]
        let subscriptionNotes = UserDefaults.standard.dictionary(forKey: Self.subscriptionNotesKey) as? [String: String] ?? [:]
        let corrections = categoryCorrections
            .map { BackupCategoryCorrection(merchant: $0.key, category: $0.value) }
            .sorted { $0.merchant < $1.merchant }
        let summary = BackupSummary(
            transactionCount: backupTransactions.filter { $0.deletedAt == nil }.count,
            deletedTransactionCount: backupTransactions.filter { $0.deletedAt != nil }.count,
            subscriptionCount: subscriptions.count,
            categoryCorrectionCount: corrections.count,
            customCategoryCount: customCategories.count,
            customSourceCount: customSources.count,
            merchantAliasCount: merchantAliases.count,
            hotelStayRecordCount: backupHotelStayRecords.count,
            hotelStayDraftCount: backupHotelStayDrafts.count,
            ledgerProfileCount: ledgerProfiles.count
        )

        return BackupBundle(
            app: BackupAppInfo(
                name: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "AutoLedger",
                version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.5.0",
                build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev"
            ),
            device: BackupDeviceInfo(
                model: UIDevice.current.model,
                systemName: UIDevice.current.systemName,
                systemVersion: UIDevice.current.systemVersion
            ),
            summary: summary,
            transactions: backupTransactions,
            subscriptions: subscriptions,
            hotelStayRecords: backupHotelStayRecords,
            hotelStayDrafts: backupHotelStayDrafts,
            categoryCorrections: corrections,
            customCategories: customCategories,
            customSources: customSources,
            merchantAliases: merchantAliases,
            ledgerProfiles: ledgerProfiles,
            defaultWriteLedgerID: defaultWriteLedgerID,
            subscriptionMetadata: BackupSubscriptionMetadata(annualPriceOverrides: annualPrices, notes: subscriptionNotes),
            appSettings: BackupAppSettings(
                subscriptionReminderEnabled: UserDefaults.standard.bool(forKey: "subscriptionReminder"),
                monthlyAnomalyThresholdPercent: UserDefaults.standard.double(forKey: "monthlyAnomalyThresholdPercent"),
                llmEnhancementEnabled: UserDefaults.standard.bool(forKey: "llmEnhancementEnabled"),
                autoClipboardImportEnabled: UserDefaults.standard.bool(forKey: "autoClipboardImport"),
                iCloudBackupEnabled: iCloudBackupEnabled
            )
        )
    }

    func writeManualBackupFile() throws -> URL {
        let bundle = try makeBackupBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "AutoLedger_backup_\(formatter.string(from: bundle.exportedAt)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic])
        recordBackupSuccess(bundle)
        lastBackupSummary = localizedFormat(
            "ledger.status.json_backup_ready_format",
            fallback: "已生成 JSON 备份：%@",
            summaryText(for: bundle)
        )
        return url
    }

    func writeCSVExportFile() throws -> URL {
        let data = try LedgerCSVCodec.encode(transactions: transactions)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "AutoLedger_transactions_\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic])
        lastBackupSummary = localizedFormat(
            "ledger.status.csv_ready_format",
            fallback: "已生成 CSV：%d 条正式账单",
            transactions.count
        )
        return url
    }

    func writeMonthlyExportPackage(referenceDate: Date, redactSensitiveFields: Bool = true) throws -> [URL] {
        let scopedLedgerID = isShowingAllLedgers ? nil : selectedLedgerID

        let package = MonthlyExportPackageBuilder().build(
            transactions: transactions,
            hotelStayRecords: hotelStayRecords,
            referenceDate: referenceDate,
            options: MonthlyExportPackageOptions(
                ledgerID: scopedLedgerID,
                redactSensitiveFields: redactSensitiveFields,
                includeHotelAttachmentIndex: true
            )
        )

        let exportToken = Self.monthlyExportFileToken(for: package.generatedAt)
        let folderName = "AutoLedger_monthly_export_\(exportToken)"
        let folderURL = FileManager.default.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
        if FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.removeItem(at: folderURL)
        }
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        for file in package.files {
            let exportFile = monthlyExportWritableFile(from: file)
            let url = folderURL.appendingPathComponent(exportFile.fileName)
            try exportFile.data.write(to: url, options: [.atomic])
        }
        lastBackupSummary = String(
            format: String(localized: "report.monthly_export.status_ready_format"),
            1
        )
        let zipURL = try zipMonthlyExportPackage(at: folderURL, exportToken: exportToken)
        try? FileManager.default.removeItem(at: folderURL)
        return [zipURL]
    }

    private func monthlyExportWritableFile(from file: MonthlyExportPackageFile) -> (fileName: String, data: Data) {
        switch file.kind {
        case .printableReport:
            #if canImport(UIKit)
            let pdfName = file.fileName.replacingOccurrences(of: ".md", with: ".pdf")
            return (pdfName, Self.renderMonthlyExportPDF(from: file.text))
            #else
            return (file.fileName, file.data)
            #endif

        case .manifestJSON:
            let manifestText = file.text.replacingOccurrences(of: "_monthly_report.md", with: "_monthly_report.pdf")
            return (file.fileName, Data(manifestText.utf8))

        case .excelCSV, .hotelAttachmentIndex:
            return (file.fileName, file.data)
        }
    }

    private static func monthlyExportFileToken(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: date)
    }

    private func zipMonthlyExportPackage(at folderURL: URL, exportToken: String) throws -> URL {
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedger_monthly_export_\(exportToken).zip")
        try? FileManager.default.removeItem(at: zipURL)

        var coordinatorError: NSError?
        var innerError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folderURL, options: .forUploading, error: &coordinatorError) { tempZip in
            do {
                try FileManager.default.copyItem(at: tempZip, to: zipURL)
            } catch {
                innerError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let innerError { throw innerError }
        return zipURL
    }

    #if canImport(UIKit)
    private static func renderMonthlyExportPDF(from markdownText: String) -> Data {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 44
        let textWidth = pageBounds.width - margin * 2
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.label,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byWordWrapping
                style.lineSpacing = 2
                return style
            }()
        ]
        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let lines = markdownText.components(separatedBy: .newlines)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        return renderer.pdfData { context in
            var index = 0
            repeat {
                context.beginPage()
                var y = margin
                while index < lines.count {
                    let rawLine = lines[index]
                    let printableLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : rawLine
                    let attributes: [NSAttributedString.Key: Any]
                    if printableLine.hasPrefix("#") {
                        attributes = titleAttributes
                    } else if printableLine.hasPrefix("-") {
                        attributes = bodyAttributes
                    } else {
                        attributes = captionAttributes
                    }
                    let boundingRect = printableLine.boundingRect(
                        with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attributes,
                        context: nil
                    )
                    let lineHeight = max(14, ceil(boundingRect.height) + 7)
                    if y + lineHeight > pageBounds.maxY - margin, y > margin {
                        break
                    }
                    printableLine.draw(
                        with: CGRect(x: margin, y: y, width: textWidth, height: lineHeight),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attributes,
                        context: nil
                    )
                    y += lineHeight
                    index += 1
                }
            } while index < lines.count
        }
    }
    #endif

    func importBackup(from url: URL) throws {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(BackupBundle.self, from: data)
        try restoreBackup(bundle)
    }

    func restoreBackup(_ bundle: BackupBundle) throws {
        try BackupValidator.validate(bundle)
        let safetyBundle = try makeBackupBundle()

        do {
            try applyBackupBundle(bundle)
            customCategories = Self.normalizedCustomCategories(bundle.customCategories)
            customSources = bundle.customSources
            merchantAliases = bundle.merchantAliases
            saveRestoredUserDefaults(from: bundle)
            clearCloudKitPushCheckpoint()
            refreshFromStore()
            reloadWidgets()
            lastImportSummary = localizedFormat(
                "ledger.status.backup_restored_format",
                fallback: "已从备份恢复：%@",
                summaryText(for: bundle)
            )
            requestAutomaticBackup()
            scheduleCloudKitPushAfterLocalLedgerChange()
        } catch {
            try? applyBackupBundle(safetyBundle)
            customCategories = Self.normalizedCustomCategories(safetyBundle.customCategories)
            customSources = safetyBundle.customSources
            merchantAliases = safetyBundle.merchantAliases
            saveRestoredUserDefaults(from: safetyBundle)
            clearCloudKitPushCheckpoint()
            refreshFromStore()
            throw error
        }
    }

    func backupToICloudNow() throws {
        let bundle = try makeBackupBundle()
        _ = try iCloudBackupService.write(bundle: bundle)
        recordBackupSuccess(bundle)
        lastBackupSummary = localizedFormat(
            "ledger.status.icloud_backup_ready_format",
            fallback: "已备份到 iCloud：%@",
            summaryText(for: bundle)
        )
    }

    func setLedgerCloudSyncEnabled(_ enabled: Bool) async {
        guard enabled != isLedgerCloudSyncEnabled else { return }
        isLedgerCloudSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.ledgerCloudSyncEnabledKey)
        Self.appGroupDefaults?.set(enabled, forKey: Self.ledgerCloudSyncEnabledKey)

        if enabled {
            clearCloudKitPushCheckpoint()
            updateLedgerCloudSyncStatus("iCloud 同步已启用，开始首次全量同步。")
            await syncLedgerWithCloudKitNow(forceFull: true)
        } else {
            updateLedgerCloudSyncStatus("iCloud 同步已关闭。")
        }
    }

    func syncLedgerWithCloudKitOnLaunchIfNeeded() async {
        guard isLedgerCloudSyncEnabled else { return }
        guard !didRunLaunchCloudKitSync else { return }
        didRunLaunchCloudKitSync = true
        let didPush = await pushLedgerChangesToCloudKitIfEnabled(reason: "App 启动，先推送本地增量到 iCloud。")
        guard didPush else {
            updateLedgerCloudSyncStatus("App 启动同步已暂停：本地增量未成功推送，暂不拉取远端数据。")
            return
        }
        clearPendingExternalLedgerCloudPush()
        await pullLedgerFromCloudKitIfEnabled(reason: "App 启动，本地增量推送完成，开始拉取 iCloud 数据。")
    }

    func syncLedgerWithCloudKitNow(forceFull: Bool = false) async {
        guard !isLedgerCloudSyncRunning else { return }
        isLedgerCloudSyncRunning = true
        updateLedgerCloudSyncStatus(forceFull ? "正在强制刷新 iCloud 数据..." : "正在同步 iCloud...")
        defer { isLedgerCloudSyncRunning = false }

        do {
            let sqlStore = try sqliteStoreForCloudSync()

            let adapter = LedgerCloudKitSyncAdapter(mode: .live, allowsLiveCloudKitWrites: true)
            updateLedgerCloudSyncStatus("1/4 正在检查 iCloud 账号状态...")
            let accountCheck = await adapter.checkAccountStatus()
            guard accountCheck.canUsePrivateDatabase else {
                updateLedgerCloudSyncStatus("iCloud 不可用：\(accountCheck.message)")
                return
            }

            let pushResult = try await pushLocalLedgerChanges(
                sqlStore: sqlStore,
                adapter: adapter,
                forceFull: forceFull
            )
            let syncManifest = try await adapter.fetchSyncManifest()
            let pullResult = try await pullRemoteLedgerChanges(
                sqlStore: sqlStore,
                adapter: adapter,
                manifest: syncManifest
            )
            let hotelResult = try await pullRemoteHotelStayArchive(
                sqlStore: sqlStore,
                adapter: adapter,
                manifest: syncManifest
            )
            let configurationResult = try await pullRemoteLedgerConfiguration(sqlStore: sqlStore, adapter: adapter)

            refreshFromStore()
            let dashboardSnapshotSaved = await publishDashboardSnapshot(adapter: adapter)
            recordCloudKitSyncSuccess()
            reloadWidgets()
            updateLedgerCloudSyncStatus("iCloud 同步完成：\(pushResult.pushMode)推送 \(pushResult.savedCount) 条账单、\(pushResult.hotelSavedCount) 条酒店数据，清单\(pushResult.manifestSaved ? "已更新" : "无更新")，配置\(pushResult.configurationSaved ? "已推送" : "无需推送")；拉取 \(pullResult.remoteCount) 条账单，新增 \(pullResult.inserted)，更新 \(pullResult.updated)，删除 \(pullResult.deleted)，保留本地 \(pullResult.keptLocal)，冲突 \(pullResult.conflicts)；酒店新增/更新 \(hotelResult.upserted)，删除 \(hotelResult.deleted)，保留本地 \(hotelResult.keptLocal)；配置\(configurationResult.applied ? "已更新" : "无更新")；大屏快照\(dashboardSnapshotSaved ? "已发布" : "未发布")。")
        } catch {
            updateLedgerCloudSyncStatus("iCloud 同步失败：\(LedgerCloudKitSyncAdapter.describe(error))")
        }
    }

    func pullLedgerFromCloudKitIfEnabled(reason: String = "正在拉取 iCloud 数据...") async {
        guard isLedgerCloudSyncEnabled else {
            refreshFromStore()
            return
        }
        guard !isLedgerCloudSyncRunning else {
            updateLedgerCloudSyncStatus("已有 iCloud 同步正在运行，跳过本次拉取。")
            return
        }

        isLedgerCloudSyncRunning = true
        updateLedgerCloudSyncStatus(reason)
        defer { isLedgerCloudSyncRunning = false }

        do {
            let sqlStore = try sqliteStoreForCloudSync()

            let adapter = LedgerCloudKitSyncAdapter(mode: .live, allowsLiveCloudKitWrites: true)
            updateLedgerCloudSyncStatus("1/3 正在检查 iCloud 账号状态...")
            let accountCheck = await adapter.checkAccountStatus()
            guard accountCheck.canUsePrivateDatabase else {
                updateLedgerCloudSyncStatus("iCloud 不可用：\(accountCheck.message)")
                return
            }

            let syncManifest = try await adapter.fetchSyncManifest()
            let result = try await pullRemoteLedgerChanges(
                sqlStore: sqlStore,
                adapter: adapter,
                manifest: syncManifest
            )
            let hotelResult = try await pullRemoteHotelStayArchive(
                sqlStore: sqlStore,
                adapter: adapter,
                manifest: syncManifest
            )
            let configurationResult = try await pullRemoteLedgerConfiguration(sqlStore: sqlStore, adapter: adapter)
            refreshFromStore()
            let dashboardSnapshotSaved = await publishDashboardSnapshot(adapter: adapter)
            recordCloudKitSyncSuccess()
            reloadWidgets()
            updateLedgerCloudSyncStatus("iCloud 拉取完成：拉取 \(result.remoteCount) 条账单，新增 \(result.inserted)，更新 \(result.updated)，删除 \(result.deleted)，保留本地 \(result.keptLocal)，冲突 \(result.conflicts)；酒店新增/更新 \(hotelResult.upserted)，删除 \(hotelResult.deleted)，保留本地 \(hotelResult.keptLocal)；配置\(configurationResult.applied ? "已更新" : "无更新")；大屏快照\(dashboardSnapshotSaved ? "已发布" : "未发布")。")
        } catch {
            updateLedgerCloudSyncStatus("iCloud 拉取失败：\(LedgerCloudKitSyncAdapter.describe(error))")
        }
    }

    @discardableResult
    func keepLocalVersionForLedgerSyncConflict(transactionID: UUID) -> Bool {
        guard let sqlStore = transactionStore as? SQLiteTransactionStore else {
            updateLedgerCloudSyncStatus("同步冲突暂时无法处理：当前账本不是 SQLite 本地账本。")
            return false
        }

        do {
            let beforeMetadata = try sqlStore.loadTransactionSyncMetadata(transactionID: transactionID)
            try sqlStore.resolveTransactionSyncConflictKeepingLocal(transactionID: transactionID)
            let afterMetadata = try sqlStore.loadTransactionSyncMetadata(transactionID: transactionID)
            markRecentlyEdited(transactionID)
            refreshFromSQLiteStore(sqlStore)
            reloadWidgets()
            clearCloudKitPushCheckpoint()
            updateLedgerCloudSyncStatus(
                "已保留本机账单并清除同步冲突：\(shortID(transactionID))，before=\(syncMetadataSummary(beforeMetadata))，after=\(syncMetadataSummary(afterMetadata))"
            )
            scheduleCloudKitPushAfterLocalLedgerChange()
            return true
        } catch {
            updateLedgerCloudSyncStatus("同步冲突处理失败：\(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func keepLocalVersionsForAllLedgerSyncConflicts() -> Int {
        guard let sqlStore = transactionStore as? SQLiteTransactionStore else {
            updateLedgerCloudSyncStatus("同步冲突暂时无法处理：当前账本不是 SQLite 本地账本。")
            return 0
        }

        let conflictIDs = ledgerSyncConflictRecords.map(\.transaction.id)
        guard !conflictIDs.isEmpty else { return 0 }

        var resolvedCount = 0
        do {
            for transactionID in conflictIDs {
                try sqlStore.resolveTransactionSyncConflictKeepingLocal(transactionID: transactionID)
                markRecentlyEdited(transactionID)
                resolvedCount += 1
            }
            refreshFromSQLiteStore(sqlStore)
            reloadWidgets()
            clearCloudKitPushCheckpoint()
            updateLedgerCloudSyncStatus("已保留本机版本并清除 \(resolvedCount) 条同步冲突。")
            scheduleCloudKitPushAfterLocalLedgerChange()
            return resolvedCount
        } catch {
            refreshFromSQLiteStore(sqlStore)
            updateLedgerCloudSyncStatus("同步冲突批量处理失败：已处理 \(resolvedCount) 条，错误：\(error.localizedDescription)")
            scheduleCloudKitPushAfterLocalLedgerChange()
            return resolvedCount
        }
    }

    func pushPendingIntentLedgerSaveIfNeeded(reason: String = "检测到外部入口账单待推送，开始同步到 iCloud。") async {
        guard hasPendingExternalLedgerCloudPush else { return }
        let didPush = await pushLedgerChangesToCloudKitIfEnabled(reason: reason)
        if didPush {
            clearPendingExternalLedgerCloudPush()
        }
    }

    private var hasPendingExternalLedgerCloudPush: Bool {
        UserDefaults.standard.bool(forKey: Self.pendingIntentLedgerCloudPushKey) ||
            (Self.appGroupDefaults?.bool(forKey: Self.pendingIntentLedgerCloudPushKey) ?? false)
    }

    private func clearPendingExternalLedgerCloudPush() {
        UserDefaults.standard.removeObject(forKey: Self.pendingIntentLedgerCloudPushKey)
        Self.appGroupDefaults?.removeObject(forKey: Self.pendingIntentLedgerCloudPushKey)
    }

    @discardableResult
    func pushLedgerChangesToCloudKitIfEnabled(reason: String = "本地账单已变化，开始增量推送。") async -> Bool {
        guard isLedgerCloudSyncEnabled else { return false }
        guard !isLedgerCloudSyncRunning else {
            updateLedgerCloudSyncStatus("已有 iCloud 同步正在运行，稍后重试推送本地变更。")
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await self?.pushLedgerChangesToCloudKitIfEnabled(reason: reason)
            }
            return false
        }

        isLedgerCloudSyncRunning = true
        updateLedgerCloudSyncStatus(reason)
        defer { isLedgerCloudSyncRunning = false }

        do {
            let sqlStore = try sqliteStoreForCloudSync()

            let adapter = LedgerCloudKitSyncAdapter(mode: .live, allowsLiveCloudKitWrites: true)
            updateLedgerCloudSyncStatus("1/2 正在检查 iCloud 账号状态...")
            let accountCheck = await adapter.checkAccountStatus()
            guard accountCheck.canUsePrivateDatabase else {
                updateLedgerCloudSyncStatus("iCloud 不可用：\(accountCheck.message)")
                return false
            }

            let result = try await pushLocalLedgerChanges(sqlStore: sqlStore, adapter: adapter, forceFull: false)
            let dashboardSnapshotSaved = await publishDashboardSnapshot(adapter: adapter)
            recordCloudKitSyncSuccess()
            updateLedgerCloudSyncStatus("iCloud 推送完成：\(result.pushMode)推送 \(result.savedCount) 条账单、\(result.hotelSavedCount) 条酒店数据，清单\(result.manifestSaved ? "已更新" : "无更新")，配置\(result.configurationSaved ? "已推送" : "无需推送")；大屏快照\(dashboardSnapshotSaved ? "已发布" : "未发布")。")
            return true
        } catch {
            updateLedgerCloudSyncStatus("iCloud 推送失败：\(LedgerCloudKitSyncAdapter.describe(error))")
            return false
        }
    }

    private func sqliteStoreForCloudSync() throws -> SQLiteTransactionStore {
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            return sqlStore
        }

        appendLedgerCloudSyncLog("当前同步状态未持有 SQLite 实例，正在重新打开默认本地账本。")
        let sqlStore = try SQLiteTransactionStore()
        refreshFromSQLiteStore(sqlStore)
        return sqlStore
    }

    private func scheduleCloudKitPushAfterLocalLedgerChange() {
        guard isLedgerCloudSyncEnabled else { return }
        pendingCloudKitPushTask?.cancel()
        pendingCloudKitPushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.pushLedgerChangesToCloudKitIfEnabled()
        }
    }

    private func pushLocalLedgerChanges(
        sqlStore: SQLiteTransactionStore,
        adapter: LedgerCloudKitSyncAdapter,
        forceFull: Bool
    ) async throws -> (pushMode: String, savedCount: Int, hotelSavedCount: Int, manifestSaved: Bool, configurationSaved: Bool) {
        if forceFull {
            clearCloudKitPushCheckpoint()
        }

        let lastPushAt = forceFull ? nil : lastSuccessfulCloudKitPushAt
        let localRecords = try sqlStore.loadTransactionSyncRecords(includeDeleted: true)
        let batch = LedgerSyncPlanner.makePushBatch(from: localRecords, changedAfter: lastPushAt)
        let pushMode = lastPushAt == nil ? "全量" : "增量"
        updateLedgerCloudSyncStatus("正在\(pushMode)推送 \(batch.upserts.count) 条账单和 \(batch.tombstones.count) 条删除记录...")
        let pushResult = try await adapter.push(batch: batch)
        let hotelPushPayloads = try makeHotelStayArchivePushPayloads(
            sqlStore: sqlStore,
            changedAfter: lastPushAt
        )
        updateLedgerCloudSyncStatus("正在\(pushMode)推送 \(hotelPushPayloads.records.count + hotelPushPayloads.drafts.count) 条酒店消费数据...")
        let hotelPushResult = try await adapter.pushHotelStayArchive(
            records: hotelPushPayloads.records,
            drafts: hotelPushPayloads.drafts
        )
        let manifestSaved = try await pushSyncManifest(
            sqlStore: sqlStore,
            adapter: adapter,
            localRecords: localRecords,
            generatedAt: batch.generatedAt
        )

        let shouldPushConfiguration = forceFull || lastPushAt == nil || ledgerConfigurationUpdatedAt > lastPushAt!
        var configurationSaved = false
        if shouldPushConfiguration {
            updateLedgerCloudSyncStatus("正在推送订阅、商户别名和用户配置...")
            let configurationResult = try await adapter.pushConfiguration(makeLedgerConfigurationPayload())
            configurationSaved = !configurationResult.savedRecordNames.isEmpty
        }

        if hotelPushResult.assetFallbackRecordNames.isEmpty {
            recordCloudKitPushCheckpoint(batch.generatedAt)
        } else {
            clearCloudKitPushCheckpoint()
        }
        return (
            pushMode: pushMode,
            savedCount: pushResult.savedRecordNames.count,
            hotelSavedCount: hotelPushResult.savedRecordNames.count,
            manifestSaved: manifestSaved,
            configurationSaved: configurationSaved
        )
    }

    private func pushSyncManifest(
        sqlStore: SQLiteTransactionStore,
        adapter: LedgerCloudKitSyncAdapter,
        localRecords: [TransactionSyncRecord],
        generatedAt: Date
    ) async throws -> Bool {
        let allTransactionBatch = LedgerSyncPlanner.makePushBatch(
            from: localRecords,
            changedAfter: nil,
            referenceDate: generatedAt
        )
        let allHotelPushPayloads = try makeHotelStayArchivePushPayloads(
            sqlStore: sqlStore,
            changedAfter: nil
        )
        let localManifest = LedgerCloudSyncManifest(
            updatedAt: generatedAt,
            deviceID: localSyncDeviceID,
            transactionRecordNames: (allTransactionBatch.upserts + allTransactionBatch.tombstones).map(\.recordName),
            hotelStayRecordNames: allHotelPushPayloads.records.map(\.recordName),
            hotelStayDraftRecordNames: allHotelPushPayloads.drafts.map(\.recordName)
        )
        let remoteManifest = try await adapter.fetchSyncManifest()
        let mergedManifest = localManifest.merged(with: remoteManifest)
        updateLedgerCloudSyncStatus("正在更新 iCloud 同步清单：账单 \(mergedManifest.transactionRecordNames.count)，酒店 \(mergedManifest.hotelStayRecordNames.count)，草稿 \(mergedManifest.hotelStayDraftRecordNames.count)...")
        let result = try await adapter.pushSyncManifest(mergedManifest)
        return !result.savedRecordNames.isEmpty
    }

    private func makeHotelStayArchivePushPayloads(
        sqlStore: SQLiteTransactionStore,
        changedAfter: Date?
    ) throws -> (records: [LedgerHotelStayRecordSyncPayload], drafts: [LedgerHotelStayDraftSyncPayload]) {
        let recordTombstones = loadHotelStayRecordTombstones()
        let draftTombstones = loadHotelStayDraftTombstones()

        let records = try sqlStore.loadHotelStayRecords()
            .filter { record in
                guard let changedAfter else { return true }
                return record.updatedAt >= changedAfter
            }
            .map { LedgerHotelStayRecordSyncPayload(record: $0, deviceID: localSyncDeviceID) }

        let drafts = try sqlStore.loadHotelStayDrafts()
            .filter { draft in
                guard let changedAfter else { return true }
                return draft.updatedAt >= changedAfter
            }
            .map { LedgerHotelStayDraftSyncPayload(draft: $0, deviceID: localSyncDeviceID) }

        let recordDeletes = recordTombstones
            .filter { _, deletedAt in
                guard let changedAfter else { return true }
                return deletedAt >= changedAfter
            }
            .map { id, deletedAt in
                LedgerHotelStayRecordSyncPayload.tombstone(
                    id: id,
                    deletedAt: deletedAt,
                    deviceID: localSyncDeviceID
                )
            }

        let draftDeletes = draftTombstones
            .filter { _, deletedAt in
                guard let changedAfter else { return true }
                return deletedAt >= changedAfter
            }
            .map { id, deletedAt in
                LedgerHotelStayDraftSyncPayload.tombstone(
                    id: id,
                    deletedAt: deletedAt,
                    deviceID: localSyncDeviceID
                )
            }

        return (
            records: (records + recordDeletes).sorted { $0.updatedAt < $1.updatedAt },
            drafts: (drafts + draftDeletes).sorted { $0.updatedAt < $1.updatedAt }
        )
    }

    private func pullRemoteLedgerChanges(
        sqlStore: SQLiteTransactionStore,
        adapter: LedgerCloudKitSyncAdapter,
        manifest: LedgerCloudSyncManifest?
    ) async throws -> (remoteCount: Int, inserted: Int, updated: Int, deleted: Int, keptLocal: Int, conflicts: Int) {
        updateLedgerCloudSyncStatus("正在拉取远端账单...")
        let recordNames = manifest?.transactionRecordNames ?? []
        if recordNames.isEmpty {
            appendLedgerCloudSyncLog("远端同步清单中没有账单记录。")
        } else {
            appendLedgerCloudSyncLog("远端同步清单账单记录：\(recordNames.count) 条。")
        }
        let remotePayloads = try await adapter.fetchAllTransactionRecords(recordNames: recordNames)

        updateLedgerCloudSyncStatus("拉取完成，正在写入本地账本...")
        let protectedIDs = protectedRecentlyEditedTransactionIDs()
        if !protectedIDs.isEmpty {
            appendLedgerCloudSyncLog(
                "远端拉取保护：本机刚编辑 \(protectedIDs.map(shortID).sorted().joined(separator: ","))"
            )
        }
        let summary = try sqlStore.applyRemoteSyncRecords(
            remotePayloads.map(\.syncRecord),
            protectedLocalTransactionIDs: protectedIDs
        )
        if !protectedIDs.isEmpty {
            appendLedgerCloudSyncLog(
                "远端拉取保护结果：保留本地 \(summary.keptLocal)，冲突 \(summary.conflicts)"
            )
        }
        await Task.yield()
        return (
            remoteCount: remotePayloads.count,
            inserted: summary.inserted,
            updated: summary.updated,
            deleted: summary.deleted,
            keptLocal: summary.keptLocal,
            conflicts: summary.conflicts
        )
    }

    private func pullRemoteHotelStayArchive(
        sqlStore: SQLiteTransactionStore,
        adapter: LedgerCloudKitSyncAdapter,
        manifest: LedgerCloudSyncManifest?
    ) async throws -> (remoteCount: Int, upserted: Int, deleted: Int, keptLocal: Int) {
        updateLedgerCloudSyncStatus("正在拉取远端酒店消费...")
        let hotelRecordNames = manifest?.hotelStayRecordNames ?? []
        let hotelDraftNames = manifest?.hotelStayDraftRecordNames ?? []
        appendLedgerCloudSyncLog("远端同步清单酒店记录：\(hotelRecordNames.count) 条，草稿：\(hotelDraftNames.count) 条。")
        let remoteRecords = try await adapter.fetchAllHotelStayRecords(recordNames: hotelRecordNames)
        let remoteDrafts = try await adapter.fetchAllHotelStayDrafts(recordNames: hotelDraftNames)

        let localRecordsByID = Dictionary(uniqueKeysWithValues: (try sqlStore.loadHotelStayRecords()).map { ($0.id, $0) })
        let localDraftsByID = Dictionary(uniqueKeysWithValues: (try sqlStore.loadHotelStayDrafts()).map { ($0.id, $0) })
        var recordTombstones = loadHotelStayRecordTombstones()
        var draftTombstones = loadHotelStayDraftTombstones()

        var upserted = 0
        var deleted = 0
        var keptLocal = 0

        for remote in remoteRecords.sorted(by: { $0.updatedAt < $1.updatedAt }) {
            if let deletedAt = remote.deletedAt {
                recordTombstones[remote.hotelStayID] = max(recordTombstones[remote.hotelStayID] ?? .distantPast, deletedAt)
                if localRecordsByID[remote.hotelStayID] != nil {
                    try sqlStore.deleteHotelStayRecordForSync(id: remote.hotelStayID)
                    deleted += 1
                }
                continue
            }

            guard let record = remote.hotelStayRecord else { continue }
            if let localDeletedAt = recordTombstones[record.id],
               localDeletedAt >= remote.updatedAt {
                keptLocal += 1
                continue
            }
            if let local = localRecordsByID[record.id],
               local.updatedAt > remote.updatedAt {
                keptLocal += 1
                continue
            }

            let mergedRecord = mergeHotelStayRecordPreservingLocalPDF(
                remote: record,
                local: localRecordsByID[record.id]
            )
            try sqlStore.save(hotelStayRecord: mergedRecord)
            recordTombstones.removeValue(forKey: record.id)
            upserted += 1
        }

        for remote in remoteDrafts.sorted(by: { $0.updatedAt < $1.updatedAt }) {
            if let deletedAt = remote.deletedAt {
                draftTombstones[remote.draftID] = max(draftTombstones[remote.draftID] ?? .distantPast, deletedAt)
                if localDraftsByID[remote.draftID] != nil {
                    try sqlStore.deleteHotelStayDraft(id: remote.draftID)
                    deleted += 1
                }
                continue
            }

            guard let draft = remote.hotelStayDraft else { continue }
            if let localDeletedAt = draftTombstones[draft.id],
               localDeletedAt >= remote.updatedAt {
                keptLocal += 1
                continue
            }
            if let local = localDraftsByID[draft.id],
               local.updatedAt > remote.updatedAt {
                keptLocal += 1
                continue
            }

            let mergedDraft = mergeHotelStayDraftPreservingLocalPDF(
                remote: draft,
                local: localDraftsByID[draft.id]
            )
            try sqlStore.save(hotelStayDraft: mergedDraft)
            draftTombstones.removeValue(forKey: draft.id)
            upserted += 1
        }

        saveHotelStayTombstones(recordTombstones, key: Self.hotelStayRecordTombstonesKey)
        saveHotelStayTombstones(draftTombstones, key: Self.hotelStayDraftTombstonesKey)
        await Task.yield()
        return (
            remoteCount: remoteRecords.count + remoteDrafts.count,
            upserted: upserted,
            deleted: deleted,
            keptLocal: keptLocal
        )
    }

    private func mergeHotelStayRecordPreservingLocalPDF(
        remote record: HotelStayRecord,
        local: HotelStayRecord?
    ) -> HotelStayRecord {
        guard (record.sourcePDFData?.isEmpty ?? true),
              let localPDFData = local?.sourcePDFData,
              !localPDFData.isEmpty else {
            return record
        }

        var merged = record
        merged.sourcePDFData = localPDFData
        return merged
    }

    private func mergeHotelStayDraftPreservingLocalPDF(
        remote draft: HotelStayDraft,
        local: HotelStayDraft?
    ) -> HotelStayDraft {
        guard (draft.sourcePDFData?.isEmpty ?? true),
              let localPDFData = local?.sourcePDFData,
              !localPDFData.isEmpty else {
            return draft
        }

        var merged = draft
        merged.sourcePDFData = localPDFData
        return merged
    }

    private func publishDashboardSnapshot(adapter: LedgerCloudKitSyncAdapter) async -> Bool {
        updateLedgerCloudSyncStatus("正在发布 tvOS / visionOS 只读看板快照...")
        do {
            let now = Date()
            let payload = LedgerDashboardCloudSnapshot(
                transactions: transactions,
                generatedAt: now,
                referenceDate: now,
                deviceID: localSyncDeviceID
            )
            _ = try await adapter.pushDashboardSnapshot(payload)
            return true
        } catch {
            updateLedgerCloudSyncStatus("大屏只读快照发布失败：\(LedgerCloudKitSyncAdapter.describe(error))")
            return false
        }
    }

    private func pullRemoteLedgerConfiguration(
        sqlStore: SQLiteTransactionStore,
        adapter: LedgerCloudKitSyncAdapter
    ) async throws -> (remoteFound: Bool, applied: Bool) {
        updateLedgerCloudSyncStatus("正在拉取订阅、商户别名和用户配置...")
        guard let remote = try await adapter.fetchConfigurationRecord() else {
            return (remoteFound: false, applied: false)
        }

        guard remote.updatedAt > ledgerConfigurationUpdatedAt,
              remote.deviceID != localSyncDeviceID else {
            return (remoteFound: true, applied: false)
        }

        let local = makeLedgerConfigurationPayload(updatedAt: ledgerConfigurationUpdatedAt)
        if LedgerConfigurationSyncPolicy.shouldPreserveLocalConfiguration(local: local, remote: remote) {
            markLedgerConfigurationChanged()
            scheduleCloudKitPushAfterLocalLedgerChange()
            updateLedgerCloudSyncStatus("远端用户配置为空，已保留本地分类、商户别名和分类学习。")
            return (remoteFound: true, applied: false)
        }

        let merged = LedgerConfigurationSyncPolicy.merge(local: local, remote: remote)
        let shouldPushMergedConfiguration = LedgerConfigurationSyncPolicy
            .hasDifferentUserConfigurationContent(merged, remote)

        try sqlStore.replaceConfigurationForSync(
            subscriptions: merged.subscriptions,
            categoryCorrections: merged.categoryCorrections,
            merchantAliases: merged.merchantAliases,
            ledgerProfiles: merged.ledgerProfiles
        )

        subscriptions = merged.subscriptions.sorted { $0.nextChargedAt < $1.nextChargedAt }
        categoryCorrections = Dictionary(uniqueKeysWithValues: merged.categoryCorrections.map { ($0.merchant, $0.category) })
        customCategories = Self.normalizedCustomCategories(merged.customCategories)
        customSources = merged.customSources
        merchantAliases = merged.merchantAliases
        merchantAliasDeletedKeys = Set(merged.merchantAliasDeletedKeys)
        reloadLedgerProfiles()
        defaultWriteLedgerID = Self.resolvedDefaultWriteLedgerID(merged.defaultWriteLedgerID, from: ledgerProfiles)
        saveDefaultWriteLedger()
        normalizeLedgerSelection()

        UserDefaults.standard.set(customCategories, forKey: "customCategories")
        UserDefaults.standard.set(customSources, forKey: "customSources")
        UserDefaults.standard.set(merchantAliases, forKey: "merchantAliases")
        persistMerchantAliasDeletedKeys()
        UserDefaults.standard.set(merged.subscriptionMetadata.annualPriceOverrides, forKey: Self.annualPriceKey)
        UserDefaults.standard.set(merged.subscriptionMetadata.notes, forKey: Self.subscriptionNotesKey)
        UserDefaults.standard.set(merged.appSettings.subscriptionReminderEnabled, forKey: "subscriptionReminder")
        UserDefaults.standard.set(merged.appSettings.monthlyAnomalyThresholdPercent, forKey: "monthlyAnomalyThresholdPercent")
        UserDefaults.standard.set(merged.appSettings.llmEnhancementEnabled, forKey: "llmEnhancementEnabled")
        UserDefaults.standard.set(merged.appSettings.autoClipboardImportEnabled, forKey: "autoClipboardImport")
        UserDefaults.standard.set(false, forKey: Self.iCloudBackupEnabledKey)
        if shouldPushMergedConfiguration {
            markLedgerConfigurationChanged()
            scheduleCloudKitPushAfterLocalLedgerChange()
        } else {
            UserDefaults.standard.set(merged.updatedAt, forKey: Self.ledgerConfigurationUpdatedAtKey)
        }

        NotificationService.shared.scheduleUpcomingChargeReminders(for: subscriptions)
        Self.watchSyncHandler?()
        return (remoteFound: true, applied: true)
    }

    private func makeLedgerConfigurationPayload() -> LedgerConfigurationSyncPayload {
        makeLedgerConfigurationPayload(updatedAt: ensureLedgerConfigurationUpdatedAt())
    }

    private func makeLedgerConfigurationPayload(updatedAt: Date) -> LedgerConfigurationSyncPayload {
        let annualPrices = UserDefaults.standard.dictionary(forKey: Self.annualPriceKey) as? [String: Double] ?? [:]
        let subscriptionNotes = UserDefaults.standard.dictionary(forKey: Self.subscriptionNotesKey) as? [String: String] ?? [:]

        return LedgerConfigurationSyncPayload(
            updatedAt: updatedAt,
            deviceID: localSyncDeviceID,
            subscriptions: subscriptions.sorted { $0.id.uuidString < $1.id.uuidString },
            categoryCorrections: categoryCorrections
                .map { BackupCategoryCorrection(merchant: $0.key, category: $0.value) }
                .sorted { $0.merchant < $1.merchant },
            customCategories: customCategories,
            customSources: customSources,
            merchantAliases: merchantAliases,
            merchantAliasDeletedKeys: merchantAliasDeletedKeys.sorted(),
            ledgerProfiles: ledgerProfiles.sorted {
                if $0.sortOrder == $1.sortOrder {
                    if $0.createdAt == $1.createdAt {
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    return $0.createdAt < $1.createdAt
                }
                return $0.sortOrder < $1.sortOrder
            },
            defaultWriteLedgerID: defaultWriteLedgerID,
            subscriptionMetadata: BackupSubscriptionMetadata(
                annualPriceOverrides: annualPrices,
                notes: subscriptionNotes
            ),
            appSettings: BackupAppSettings(
                subscriptionReminderEnabled: UserDefaults.standard.bool(forKey: "subscriptionReminder"),
                monthlyAnomalyThresholdPercent: UserDefaults.standard.double(forKey: "monthlyAnomalyThresholdPercent"),
                llmEnhancementEnabled: UserDefaults.standard.bool(forKey: "llmEnhancementEnabled"),
                autoClipboardImportEnabled: UserDefaults.standard.bool(forKey: "autoClipboardImport"),
                iCloudBackupEnabled: false
            )
        )
    }

    private func seedLegacyLedgerConfigurationTimestampIfNeeded() {
        guard UserDefaults.standard.object(forKey: Self.ledgerConfigurationUpdatedAtKey) == nil else { return }
        let local = makeLedgerConfigurationPayload(updatedAt: .distantPast)
        guard local.hasUserConfigurationContent else { return }
        UserDefaults.standard.set(Date(), forKey: Self.ledgerConfigurationUpdatedAtKey)
    }

    private var ledgerConfigurationUpdatedAt: Date {
        UserDefaults.standard.object(forKey: Self.ledgerConfigurationUpdatedAtKey) as? Date ?? .distantPast
    }

    private func ensureLedgerConfigurationUpdatedAt() -> Date {
        if let existing = UserDefaults.standard.object(forKey: Self.ledgerConfigurationUpdatedAtKey) as? Date {
            return existing
        }
        let now = Date()
        UserDefaults.standard.set(now, forKey: Self.ledgerConfigurationUpdatedAtKey)
        return now
    }

    private func markLedgerConfigurationChanged() {
        UserDefaults.standard.set(Date(), forKey: Self.ledgerConfigurationUpdatedAtKey)
    }

    private func recordHotelStayRecordTombstone(_ id: UUID, deletedAt: Date = .now) {
        var tombstones = loadHotelStayRecordTombstones()
        tombstones[id] = max(tombstones[id] ?? .distantPast, deletedAt)
        saveHotelStayTombstones(tombstones, key: Self.hotelStayRecordTombstonesKey)
    }

    private func recordHotelStayDraftTombstone(_ id: UUID, deletedAt: Date = .now) {
        var tombstones = loadHotelStayDraftTombstones()
        tombstones[id] = max(tombstones[id] ?? .distantPast, deletedAt)
        saveHotelStayTombstones(tombstones, key: Self.hotelStayDraftTombstonesKey)
    }

    private func loadHotelStayRecordTombstones() -> [UUID: Date] {
        loadHotelStayTombstones(key: Self.hotelStayRecordTombstonesKey)
    }

    private func loadHotelStayDraftTombstones() -> [UUID: Date] {
        loadHotelStayTombstones(key: Self.hotelStayDraftTombstonesKey)
    }

    private func loadHotelStayTombstones(key: String) -> [UUID: Date] {
        let raw = UserDefaults.standard.dictionary(forKey: key) as? [String: TimeInterval] ?? [:]
        return Dictionary(uniqueKeysWithValues: raw.compactMap { idString, timestamp in
            guard let id = UUID(uuidString: idString) else { return nil }
            return (id, Date(timeIntervalSince1970: timestamp))
        })
    }

    private func saveHotelStayTombstones(_ tombstones: [UUID: Date], key: String) {
        let raw = Dictionary(uniqueKeysWithValues: tombstones.map { id, date in
            (id.uuidString, date.timeIntervalSince1970)
        })
        UserDefaults.standard.set(raw, forKey: key)
    }

    private var localSyncDeviceID: String {
        if let existing = UserDefaults.standard.string(forKey: Self.syncDeviceIDKey),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: Self.syncDeviceIDKey)
        return generated
    }

    private func updateLedgerCloudSyncStatus(_ message: String) {
        ledgerCloudSyncStatus = message
        appendLedgerCloudSyncLog(message)
    }

    private func appendLedgerCloudSyncLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: .now, dateStyle: .none, timeStyle: .medium)
        ledgerCloudSyncLog.append("[\(timestamp)] \(message)")
        if ledgerCloudSyncLog.count > 40 {
            ledgerCloudSyncLog.removeFirst(ledgerCloudSyncLog.count - 40)
        }
    }

    private func markRecentlyEdited(_ transactionID: UUID, now: Date = .now) {
        pruneRecentlyEditedTransactions(referenceDate: now)
        recentlyEditedTransactionIDs[transactionID] = now
    }

    private func protectedRecentlyEditedTransactionIDs(referenceDate: Date = .now) -> Set<UUID> {
        pruneRecentlyEditedTransactions(referenceDate: referenceDate)
        return Set(recentlyEditedTransactionIDs.keys)
    }

    private func pruneRecentlyEditedTransactions(referenceDate: Date = .now) {
        let retention: TimeInterval = 10 * 60
        recentlyEditedTransactionIDs = recentlyEditedTransactionIDs.filter { _, editedAt in
            referenceDate.timeIntervalSince(editedAt) <= retention
        }
    }

    private func shortID(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }

    private func syncMetadataSummary(_ metadata: TransactionSyncMetadata?) -> String {
        guard let metadata else { return "nil" }
        let deletedAt = metadata.deletedAt.map(AppFormatters.exportDateTime) ?? "nil"
        return "rev=\(metadata.syncRevision), device=\(metadata.deviceID.prefix(8)), updated=\(AppFormatters.exportDateTime(metadata.updatedAt)), deleted=\(deletedAt), conflict=\(metadata.conflictState.rawValue)"
    }

    private var lastSuccessfulCloudKitPushAt: Date? {
        UserDefaults.standard.object(forKey: Self.lastSuccessfulCloudKitPushAtKey) as? Date
    }

    private func recordCloudKitPushCheckpoint(_ date: Date) {
        UserDefaults.standard.set(date, forKey: Self.lastSuccessfulCloudKitPushAtKey)
    }

    private func clearCloudKitPushCheckpoint() {
        UserDefaults.standard.removeObject(forKey: Self.lastSuccessfulCloudKitPushAtKey)
    }

    private func recordCloudKitSyncSuccess(_ date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: Self.lastSuccessfulCloudKitSyncAtKey)
        Self.appGroupDefaults?.set(date, forKey: Self.lastSuccessfulCloudKitSyncAtKey)
    }

    private func recordLedgerSnapshotUpdatedAt(_ date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: Self.ledgerSnapshotUpdatedAtKey)
        Self.appGroupDefaults?.set(date, forKey: Self.ledgerSnapshotUpdatedAtKey)
        Self.appGroupDefaults?.set(isLedgerCloudSyncEnabled, forKey: Self.ledgerCloudSyncEnabledKey)
    }

    private func isCloudKitSnapshotStale(referenceDate: Date) -> Bool {
        guard isLedgerCloudSyncEnabled else { return false }
        guard let lastSyncAt = Self.appGroupDefaults?.object(forKey: Self.lastSuccessfulCloudKitSyncAtKey) as? Date ??
                UserDefaults.standard.object(forKey: Self.lastSuccessfulCloudKitSyncAtKey) as? Date else {
            return true
        }
        return referenceDate.timeIntervalSince(lastSyncAt) > 12 * 60 * 60
    }

    func detectICloudBackupForRestore() {
        do {
            detectedICloudBackup = try iCloudBackupService.readBundleIfAvailable()
        } catch {
            detectedICloudBackup = nil
            UserDefaults.standard.set(error.localizedDescription, forKey: Self.lastBackupErrorKey)
        }
    }

    func restoreDetectedICloudBackup() throws {
        guard let detectedICloudBackup else { return }
        try restoreBackup(detectedICloudBackup)
        self.detectedICloudBackup = nil
    }

    func requestAutomaticBackup(delayNanoseconds: UInt64 = 15_000_000_000) {
        guard iCloudBackupEnabled else { return }
        pendingBackupTask?.cancel()
        pendingBackupTask = Task { [weak self] in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                do {
                    try self?.backupToICloudNow()
                } catch {
                    UserDefaults.standard.set(error.localizedDescription, forKey: Self.lastBackupErrorKey)
                    self?.lastBackupSummary = self?.localizedFormat(
                        "ledger.status.icloud_backup_failed_format",
                        fallback: "iCloud 自动备份失败：%@",
                        error.localizedDescription
                    )
                }
            }
        }
    }

    func backupOnAppBackground() {
        requestAutomaticBackup(delayNanoseconds: 0)
    }

    func summaryText(for bundle: BackupBundle) -> String {
        "\(bundle.summary.transactionCount) 笔账单，\(bundle.summary.deletedTransactionCount) 笔最近删除，\(bundle.summary.subscriptionCount) 个订阅，\(bundle.summary.hotelStayRecordCount) 条酒店消费，\(bundle.summary.hotelStayDraftCount) 个酒店待确认，\(bundle.summary.ledgerProfileCount) 个账本，\(bundle.summary.merchantAliasCount) 个商户别名"
    }

    private func saveRestoredUserDefaults(from bundle: BackupBundle) {
        UserDefaults.standard.set(customSources, forKey: "customSources")
        UserDefaults.standard.set(customCategories, forKey: "customCategories")
        UserDefaults.standard.set(merchantAliases, forKey: "merchantAliases")
        UserDefaults.standard.set(bundle.subscriptionMetadata.annualPriceOverrides, forKey: Self.annualPriceKey)
        UserDefaults.standard.set(bundle.subscriptionMetadata.notes, forKey: Self.subscriptionNotesKey)
        UserDefaults.standard.set(bundle.appSettings.subscriptionReminderEnabled, forKey: "subscriptionReminder")
        UserDefaults.standard.set(bundle.appSettings.monthlyAnomalyThresholdPercent, forKey: "monthlyAnomalyThresholdPercent")
        UserDefaults.standard.set(bundle.appSettings.llmEnhancementEnabled, forKey: "llmEnhancementEnabled")
        UserDefaults.standard.set(bundle.appSettings.autoClipboardImportEnabled, forKey: "autoClipboardImport")
        UserDefaults.standard.set(bundle.appSettings.iCloudBackupEnabled, forKey: Self.iCloudBackupEnabledKey)
        let restoredLedgerProfiles = bundle.ledgerProfiles.isEmpty ? ledgerProfiles : bundle.ledgerProfiles
        defaultWriteLedgerID = Self.resolvedDefaultWriteLedgerID(bundle.defaultWriteLedgerID, from: restoredLedgerProfiles)
        saveDefaultWriteLedger()
    }

    private func recordBackupSuccess(_ bundle: BackupBundle) {
        UserDefaults.standard.set(bundle.exportedAt, forKey: Self.lastBackupAtKey)
        UserDefaults.standard.set(bundle.bundleId.uuidString, forKey: Self.lastBackupBundleIdKey)
        UserDefaults.standard.removeObject(forKey: Self.lastBackupErrorKey)
    }

    private func applyBackupBundle(_ bundle: BackupBundle) throws {
        let normalizedTransactions = Self.normalizedHotelLinkedBackupTransactions(
            bundle.transactions,
            hotelStayRecords: bundle.hotelStayRecords
        )
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try sqlStore.replaceForRestore(
                transactions: normalizedTransactions,
                subscriptions: bundle.subscriptions,
                categoryCorrections: bundle.categoryCorrections,
                merchantAliases: bundle.merchantAliases,
                ledgerProfiles: bundle.ledgerProfiles,
                hotelStayRecords: bundle.hotelStayRecords,
                hotelStayDrafts: bundle.hotelStayDrafts
            )
        } else {
            transactions = normalizedTransactions.filter { $0.deletedAt == nil }.map(\.transaction)
            deletedTransactions = normalizedTransactions.filter { $0.deletedAt != nil }.map(\.transaction)
            subscriptions = bundle.subscriptions
            hotelStayRecords = bundle.hotelStayRecords
            hotelStayDrafts = bundle.hotelStayDrafts
            categoryCorrections = Dictionary(uniqueKeysWithValues: bundle.categoryCorrections.map { ($0.merchant, $0.category) })
            merchantAliases = bundle.merchantAliases
            ledgerProfiles = bundle.ledgerProfiles.isEmpty ? [LedgerProfile.defaultLocal()] : bundle.ledgerProfiles
            normalizeDefaultWriteLedger()
            normalizeLedgerSelection()
        }
    }
}

private extension String {
    var nilIfEmptyForLedgerStore: String? {
        isEmpty ? nil : self
    }
}

private extension LedgerStore {
    static func normalizedCustomCategories(_ categories: [String]) -> [String] {
        var seen: Set<String> = []
        return categories.compactMap { rawCategory in
            let trimmed = rawCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !isBuiltInCategoryDuplicate(trimmed) else {
                return nil
            }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return trimmed
        }
    }

    static func isBuiltInCategoryDuplicate(_ category: String) -> Bool {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if TransactionCategory.allCases.contains(where: { builtIn in
            builtIn.rawValue == trimmed || builtIn.title == trimmed
        }) {
            return true
        }
        return TransactionCategory.normalizedBuiltInCategory(from: trimmed) == .hotel
    }

    static func normalizedHotelLinkedBackupTransactions(
        _ transactions: [BackupTransaction],
        hotelStayRecords: [HotelStayRecord]
    ) -> [BackupTransaction] {
        let linkedRecordIDsByTransactionID = hotelStayRecords.reduce(into: [UUID: UUID]()) { partial, record in
            guard let linkedTransactionID = record.linkedTransactionID,
                  partial[linkedTransactionID] == nil else { return }
            partial[linkedTransactionID] = record.id
        }

        return transactions.map { backup in
            let linkedHotelStayRecordID = backup.hotelStayRecordID ?? linkedRecordIDsByTransactionID[backup.id]
            guard let linkedHotelStayRecordID,
                  backup.category != TransactionCategory.hotel.rawValue ||
                  backup.hotelStayRecordID != linkedHotelStayRecordID else {
                return backup
            }

            return BackupTransaction(
                id: backup.id,
                merchant: backup.merchant,
                amount: backup.amount,
                occurredAt: backup.occurredAt,
                category: TransactionCategory.hotel.rawValue,
                source: backup.source,
                note: backup.note,
                ledgerID: backup.ledgerID,
                hotelStayRecordID: linkedHotelStayRecordID,
                ledgerCurrencyCode: backup.ledgerCurrencyCode,
                originalAmount: backup.originalAmount,
                originalCurrencyCode: backup.originalCurrencyCode,
                exchangeRate: backup.exchangeRate,
                exchangeRateDate: backup.exchangeRateDate,
                exchangeRateProvider: backup.exchangeRateProvider,
                deletedAt: backup.deletedAt,
                syncMetadata: backup.syncMetadata
            )
        }
    }

    static func loadInitialTransactions(using transactionStore: TransactionStore?) -> [Transaction] {
        do {
            return try transactionStore?.bootstrapIfNeeded(with: seedTransactions) ?? seedTransactions
        } catch {
            return seedTransactions
        }
    }

    static let seedTransactions: [Transaction] = []
}
