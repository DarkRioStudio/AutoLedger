import AutoLedgerCore
import Combine
import Foundation
import os.log
import UIKit
import WidgetKit

// Combine.Subscription 与 AutoLedgerCore.Subscription 同名，显式消歧义
typealias Subscription = AutoLedgerCore.Subscription

private let logger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "LedgerStore")

final class LedgerStore: ObservableObject {
    static var shared: LedgerStore?
    static var watchSyncHandler: (() -> Void)?

    @Published private(set) var transactions: [Transaction]
    @Published private(set) var deletedTransactions: [Transaction] = []
    @Published private(set) var subscriptions: [Subscription] = []
    @Published private(set) var categoryCorrections: [String: TransactionCategory] = [:]
    @Published private(set) var recentImports: [ImportedReceipt] = []
    @Published private(set) var debugRecords: [ImportDebugRecord] = []
    @Published private(set) var sampleReceipts: [SampleReceipt]
    @Published private(set) var lastRecognizedText = ""
    @Published private(set) var lastParsedReceipt: ImportedReceipt?
    @Published var lastImportSummary: String?
    @Published private(set) var lastBackupSummary: String?
    @Published var detectedICloudBackup: BackupBundle?
    @Published var customSources: [String] = []
    @Published var customCategories: [String] = []
    @Published private(set) var merchantAliases: [String: String] = [:]
    @Published private(set) var ledgerCloudSyncStatus: String?
    @Published private(set) var ledgerCloudSyncLog: [String] = []
    @Published private(set) var isLedgerCloudSyncEnabled: Bool
    @Published private(set) var isLedgerCloudSyncRunning = false

    private let parser: ReceiptParser
    private let smartParser = SmartReceiptParser()
    private let subscriptionDetector = SubscriptionDetector()
    private let textInterpreter = LedgerTextInterpreter()
    private let transactionStore: TransactionStore?
    private var lastPasteboardChangeCount: Int
    private var pendingBackupTask: Task<Void, Never>?
    private var pendingCloudKitPushTask: Task<Void, Never>?
    private var didRunLaunchCloudKitSync = false
    private let iCloudBackupService = ICloudBackupService()

    init(
        parser: ReceiptParser = ReceiptParser(),
        sampleProvider: SampleReceiptProviding = SampleReceiptProvider(),
        transactionStore: TransactionStore? = try? SQLiteTransactionStore()
    ) {
        self.parser = parser
        self.sampleReceipts = sampleProvider.samples
        self.transactionStore = transactionStore
        self.transactions = LedgerStore.loadInitialTransactions(using: transactionStore)
        self.deletedTransactions = LedgerStore.loadInitialDeletedTransactions(using: transactionStore)
        self.subscriptions = LedgerStore.loadInitialSubscriptions(using: transactionStore)
        self.categoryCorrections = LedgerStore.loadInitialCategoryCorrections(using: transactionStore)
        self.debugRecords = LedgerStore.loadInitialDebugRecords(using: transactionStore)
        self.customSources = UserDefaults.standard.stringArray(forKey: "customSources") ?? []
        self.customCategories = UserDefaults.standard.stringArray(forKey: "customCategories") ?? []
        self.merchantAliases = LedgerStore.loadInitialMerchantAliases(using: transactionStore)
        self.isLedgerCloudSyncEnabled = UserDefaults.standard.bool(forKey: Self.ledgerCloudSyncEnabledKey)
        self.lastPasteboardChangeCount = UIPasteboard.general.changeCount
        LedgerStore.shared = self
    }

    var monthlySnapshot: MonthlySnapshot {
        MonthlySnapshot.build(from: transactions, referenceDate: .now)
    }

    var todaySpendingSummary: TodaySpendingSummary {
        TodaySpendingSummary.build(from: transactions, referenceDate: .now)
    }

    func saveCustomSources() {
        UserDefaults.standard.set(customSources, forKey: "customSources")
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    func saveCustomCategories() {
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
            lastImportSummary = "已更新商户别名，并刷新 \(updatedCount) 笔历史账单。"
            scheduleCloudKitPushAfterLocalLedgerChange()
        }
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    func recordMerchantAlias(original: String, alias: String) {
        merchantAliases[original] = alias
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
            if let sqlStore = transactionStore as? SQLiteTransactionStore {
                try? sqlStore.deleteMerchantAlias(original: original)
            }
        }
        saveMerchantAliases()
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
            lastImportSummary = "示例解析失败。"
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
        ocrMinConfidence: Float? = nil
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
                lastImportSummary = "已识别为订阅：\(subscription.merchant) \(AppFormatters.currency(subscription.amount))/\(subscription.period.title)"

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
                    llmProvider: result.llmTrace?.provider.rawValue,
                    llmLatencyMs: result.llmTrace?.latencyMs,
                    llmConfidence: result.receipt.confidence,
                    usedRuleFallback: result.usedRuleFallback
                )

            case .transaction(let result, let normalizedText, _, let multiReceiptDetected):
                lastParsedReceipt = result.receipt
                let providerName = result.llmTrace?.provider.displayName ?? "规则"
                let latency = result.llmTrace?.latencyMs ?? 0
                logger.info("[解析] 模型=\(providerName) 耗时=\(latency)ms 商户=\(result.receipt.merchant) 金额=\(result.receipt.amount) 时间=\(AppFormatters.exportDateTime(result.receipt.occurredAt)) 分类=\(result.receipt.suggestedCategory.title) 规则兜底=\(result.usedRuleFallback ? "是" : "否")")
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
    }

    func setImportError(_ summary: String, source: ReceiptSource = .manual, imageSource: ImageSource = .unknown) {
        lastImportSummary = summary
        lastParsedReceipt = nil
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

    /// 从 SQLite 重新加载全部账单和调试记录（用于 App 回到前台后同步 Intent 入账记录）
    func refreshFromStore() {
        guard let store = transactionStore else { return }
        do {
            transactions = try store.loadTransactions()
        } catch {
            // 静默失败，保留内存中的数据
        }
        if let sqlStore = store as? SQLiteTransactionStore {
            deletedTransactions = (try? sqlStore.loadDeletedTransactions())  ?? deletedTransactions
            debugRecords        = (try? sqlStore.loadDebugEvents())          ?? debugRecords
            subscriptions       = (try? sqlStore.loadSubscriptions())        ?? subscriptions
            categoryCorrections = (try? sqlStore.loadCategoryCorrections())  ?? categoryCorrections
            merchantAliases     = (try? sqlStore.loadMerchantAliases())      ?? merchantAliases
        }
        loadShareExtensionResult()
    }

    private func reloadWidgets() {
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
            lastImportSummary = "已删除 \(transaction.merchant) 的记录。"
            reloadWidgets()
            return
        }

        do {
            try store.delete(transactionID: transaction.id)
        } catch {
            lastImportSummary = "删除失败：\(error.localizedDescription)"
            return
        }

        transactions.removeAll { $0.id == transaction.id }
        // 保留最近 50 条已删除记录，供用户恢复；SQLite 中会持久化 deleted_at。
        deletedTransactions.insert(transaction, at: 0)
        if deletedTransactions.count > 50 {
            deletedTransactions = Array(deletedTransactions.prefix(50))
        }
        lastImportSummary = "已删除 \(transaction.merchant) 的记录。"
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
            lastImportSummary = "已恢复 \(transaction.merchant) 的记录。"
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
            lastImportSummary = "恢复失败：\(error.localizedDescription)"
            return
        }

        deletedTransactions.removeAll { $0.id == transaction.id }
        transactions.insert(transaction, at: 0)
        sortTransactions()
        lastImportSummary = "已恢复 \(transaction.merchant) 的记录。"
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
    }

    /// 从回收站永久删除（不再可恢复）
    func permanentlyDeleteTransaction(_ transaction: Transaction) {
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            do {
                try sqlStore.permanentlyDeleteTransaction(id: transaction.id)
            } catch {
                lastImportSummary = "彻底删除失败：\(error.localizedDescription)"
                return
            }
        }
        deletedTransactions.removeAll { $0.id == transaction.id }
        lastImportSummary = "已彻底删除 \(transaction.merchant) 的记录。"
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
    }

    /// 手动新增账单（账本右上角 + 入口）
    func addTransaction(_ transaction: Transaction) {
        let resolvedTransaction = MerchantAliasResolver.applyingAlias(
            to: transaction,
            aliases: merchantAliases
        )

        guard let store = transactionStore else {
            // 无持久化层（预览/测试场景）：直接更新内存
            transactions.insert(resolvedTransaction, at: 0)
            sortTransactions()
            lastImportSummary = "已手动记账：\(resolvedTransaction.merchant) \(AppFormatters.currency(resolvedTransaction.amount))。"
            reloadWidgets()
            return
        }

        do {
            try store.save(transaction: resolvedTransaction)
        } catch {
            lastImportSummary = "记账失败：\(error.localizedDescription)"
            return
        }

        transactions.insert(resolvedTransaction, at: 0)
        sortTransactions()
        lastImportSummary = "已手动记账：\(resolvedTransaction.merchant) \(AppFormatters.currency(resolvedTransaction.amount))。"
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
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
            lastImportSummary = "已导入 \(merchant)，金额 \(AppFormatters.currency(amount))。"
        }
    }

    func updateTransaction(_ transaction: Transaction, refreshSameMerchantCategory: Bool = false) {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else {
            return
        }

        let original = transactions[index]
        let categoryChanged = original.category != transaction.category
        learnMerchantAliasIfNeeded(from: original, to: transaction)

        // 检测分类修正——仅对内置分类记录用户偏好（自定义分类直接以字符串存储在 Transaction）
        if categoryChanged,
           let builtIn = TransactionCategory(rawValue: transaction.category) {
            recordCategoryCorrection(merchant: transaction.merchant, category: builtIn)
        }

        transactions[index] = transaction

        do {
            try transactionStore?.update(transaction: transaction)
            let refreshedCount = refreshSameMerchantCategory && categoryChanged
                ? applyCategoryToExistingTransactions(
                    merchant: transaction.merchant,
                    category: transaction.category,
                    excluding: transaction.id
                )
                : 0
            sortTransactions()
            if refreshedCount > 0 {
                lastImportSummary = "已保存 \(transaction.merchant) 的修正，并刷新 \(refreshedCount) 笔同商户账单分类。"
            } else {
                lastImportSummary = "已保存 \(transaction.merchant) 的修正。"
            }
            reloadWidgets()
            requestAutomaticBackup()
            scheduleCloudKitPushAfterLocalLedgerChange()
        } catch {
            sortTransactions()
            lastImportSummary = "账单已更新到界面，但写入本地存储失败：\(error.localizedDescription)"
        }
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
            lastImportSummary = "已将 \(updatedCount) 笔历史账单商户名刷新为 \(alias)。"
            requestAutomaticBackup()
        } else {
            lastImportSummary = "没有需要刷新的 \(trimmedOriginal) 账单。"
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
                lastImportSummary = "商户别名已保存，但刷新 \(transaction.merchant) 时写入本地存储失败：\(error.localizedDescription)"
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
                lastImportSummary = "商户别名已保存，但刷新最近删除账单 \(transaction.merchant) 时写入本地存储失败：\(error.localizedDescription)"
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
                lastImportSummary = "分类偏好已保存，但刷新 \(transaction.merchant) 时写入本地存储失败：\(error.localizedDescription)"
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
                lastImportSummary = "分类偏好已保存，但刷新最近删除账单 \(transaction.merchant) 时写入本地存储失败：\(error.localizedDescription)"
            }
        }

        if updatedCount > 0 {
            sortTransactions()
            reloadWidgets()
        }
        return updatedCount
    }

    private func learnMerchantAliasIfNeeded(from original: Transaction, to updated: Transaction) {
        let originalMerchant = original.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedMerchant = updated.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard originalMerchant != updatedMerchant else { return }
        recordMerchantAlias(original: originalMerchant, alias: updatedMerchant)
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

    private func persistReceipt(_ inReceipt: ImportedReceipt, rawText: String, notePrefix: String, imageSource: ImageSource = .unknown, llmTrace: SmartReceiptParser.LLMTrace? = nil, usedRuleFallback: Bool = true) {
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
                llmProvider: llmTrace?.provider.rawValue,
                llmLatencyMs: llmTrace?.latencyMs,
                llmConfidence: receipt.confidence,
                usedRuleFallback: usedRuleFallback
            )
            return
        }

        let transaction = Transaction(
            merchant: receipt.merchant,
            amount: receipt.amount,
            occurredAt: receipt.occurredAt,
            category: receipt.suggestedCategory,
            source: receipt.source,
            note: notePrefix
        )
        recentImports.insert(receipt, at: 0)
        transactions.insert(transaction, at: 0)
        sortTransactions()

        do {
            try transactionStore?.save(transaction: transaction)
        } catch {
            let summary = "账单已导入，但写入本地存储失败：\(error.localizedDescription)"
            lastImportSummary = summary
            recordDebugEvent(
                stage: .persistenceFailed,
                source: receipt.source,
                imageSource: imageSource,
                rawText: rawText,
                parsedReceipt: receipt,
                summary: summary,
                llmPrompt: llmTrace?.prompt,
                llmResponse: llmTrace?.response,
                llmProvider: llmTrace?.provider.rawValue,
                llmLatencyMs: llmTrace?.latencyMs,
                llmConfidence: receipt.confidence,
                usedRuleFallback: usedRuleFallback
            )
            return
        }

        let summary = "已导入 \(receipt.merchant)，金额 \(AppFormatters.currency(receipt.amount))。"
        let debugSummary = receipt.parseDiagnostics.map { "\(summary)\n调试：\($0.debugSummary)" } ?? summary
        lastImportSummary = summary
        reloadWidgets()
        requestAutomaticBackup()
        scheduleCloudKitPushAfterLocalLedgerChange()
        recordDebugEvent(
            stage: .persisted,
            source: receipt.source,
            imageSource: imageSource,
            rawText: rawText,
            parsedReceipt: receipt,
            summary: debugSummary,
            llmPrompt: llmTrace?.prompt,
            llmResponse: llmTrace?.response,
            transactionID: transaction.id,
            llmProvider: llmTrace?.provider.rawValue,
            llmLatencyMs: llmTrace?.latencyMs,
            llmConfidence: receipt.confidence,
            usedRuleFallback: usedRuleFallback
        )
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

    private func localizedMessage(_ key: String, fallback: String) -> String {
        let value = NSLocalizedString(key, comment: "")
        return value == key ? fallback : value
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
        debugRecords.insert(record, at: 0)
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.saveDebugEvent(record)
        }
    }

    private static func loadInitialDebugRecords(using store: TransactionStore?) -> [ImportDebugRecord] {
        guard let sqlStore = store as? SQLiteTransactionStore else { return [] }
        return (try? sqlStore.loadDebugEvents()) ?? []
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
                amount: sub.amount
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

    func deleteSubscription(_ sub: Subscription) {
        subscriptions.removeAll { $0.id == sub.id }
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.deleteSubscription(id: sub.id)
        }
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

    func recordSubscriptionMetadataChanged() {
        markLedgerConfigurationChanged()
        scheduleCloudKitPushAfterLocalLedgerChange()
        requestAutomaticBackup()
    }

    /// 扫描全部历史账单，自动识别并保存周期性订阅
    func detectAndUpsertSubscriptions() {
        let detected = subscriptionDetector.detectFromHistory(transactions)
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
}

private extension Transaction {
    func applyingMerchantAlias(original: String, alias: String) -> Transaction? {
        guard merchant == original, alias != merchant else { return nil }
        return Transaction(
            id: id,
            merchant: alias,
            amount: amount,
            occurredAt: occurredAt,
            categoryLabel: category,
            sourceLabel: source,
            note: note
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
            note: note
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
    private static let ledgerConfigurationUpdatedAtKey = "ledgerConfigurationUpdatedAt"
    private static let pendingIntentLedgerCloudPushKey = "pendingIntentLedgerCloudPush"
    private static let syncDeviceIDKey = "top.darkrio326.AutoLedger.syncDeviceID"

    var isLocalDataEmptyForRestore: Bool {
        transactions.isEmpty &&
        deletedTransactions.isEmpty &&
        subscriptions.isEmpty &&
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

    func makeBackupBundle() throws -> BackupBundle {
        let backupTransactions: [BackupTransaction]
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            backupTransactions = try sqlStore.loadBackupTransactions()
        } else {
            backupTransactions = transactions.map { BackupTransaction(transaction: $0) } +
                deletedTransactions.map { BackupTransaction(transaction: $0, deletedAt: .now) }
        }

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
            merchantAliasCount: merchantAliases.count
        )

        return BackupBundle(
            app: BackupAppInfo(
                name: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "AutoLedger",
                version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3.0",
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
            categoryCorrections: corrections,
            customCategories: customCategories,
            customSources: customSources,
            merchantAliases: merchantAliases,
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
        lastBackupSummary = "已生成 JSON 备份：\(summaryText(for: bundle))"
        return url
    }

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
            customCategories = bundle.customCategories
            customSources = bundle.customSources
            merchantAliases = bundle.merchantAliases
            saveRestoredUserDefaults(from: bundle)
            clearCloudKitPushCheckpoint()
            refreshFromStore()
            reloadWidgets()
            lastImportSummary = "已从备份恢复：\(summaryText(for: bundle))"
            requestAutomaticBackup()
        } catch {
            try? applyBackupBundle(safetyBundle)
            customCategories = safetyBundle.customCategories
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
        lastBackupSummary = "已备份到 iCloud：\(summaryText(for: bundle))"
    }

    func setLedgerCloudSyncEnabled(_ enabled: Bool) async {
        guard enabled != isLedgerCloudSyncEnabled else { return }
        isLedgerCloudSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.ledgerCloudSyncEnabledKey)

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
        await pullLedgerFromCloudKitIfEnabled(reason: "App 启动，开始后台拉取 iCloud 数据。")
    }

    func syncLedgerWithCloudKitNow(forceFull: Bool = false) async {
        guard !isLedgerCloudSyncRunning else { return }
        isLedgerCloudSyncRunning = true
        updateLedgerCloudSyncStatus(forceFull ? "正在强制刷新 iCloud 数据..." : "正在同步 iCloud...")
        defer { isLedgerCloudSyncRunning = false }

        do {
            guard let sqlStore = transactionStore as? SQLiteTransactionStore else {
                updateLedgerCloudSyncStatus("iCloud 同步需要 SQLite 账本。")
                return
            }

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
            let pullResult = try await pullRemoteLedgerChanges(sqlStore: sqlStore, adapter: adapter)
            let configurationResult = try await pullRemoteLedgerConfiguration(sqlStore: sqlStore, adapter: adapter)

            refreshFromStore()
            reloadWidgets()
            updateLedgerCloudSyncStatus("iCloud 同步完成：\(pushResult.pushMode)推送 \(pushResult.savedCount) 条，配置\(pushResult.configurationSaved ? "已推送" : "无需推送")；拉取 \(pullResult.remoteCount) 条，新增 \(pullResult.inserted)，更新 \(pullResult.updated)，删除 \(pullResult.deleted)，保留本地 \(pullResult.keptLocal)，冲突 \(pullResult.conflicts)，配置\(configurationResult.applied ? "已更新" : "无更新")。")
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
            guard let sqlStore = transactionStore as? SQLiteTransactionStore else {
                updateLedgerCloudSyncStatus("iCloud 同步需要 SQLite 账本。")
                return
            }

            let adapter = LedgerCloudKitSyncAdapter(mode: .live, allowsLiveCloudKitWrites: true)
            updateLedgerCloudSyncStatus("1/3 正在检查 iCloud 账号状态...")
            let accountCheck = await adapter.checkAccountStatus()
            guard accountCheck.canUsePrivateDatabase else {
                updateLedgerCloudSyncStatus("iCloud 不可用：\(accountCheck.message)")
                return
            }

            let result = try await pullRemoteLedgerChanges(sqlStore: sqlStore, adapter: adapter)
            let configurationResult = try await pullRemoteLedgerConfiguration(sqlStore: sqlStore, adapter: adapter)
            refreshFromStore()
            reloadWidgets()
            updateLedgerCloudSyncStatus("iCloud 拉取完成：拉取 \(result.remoteCount) 条，新增 \(result.inserted)，更新 \(result.updated)，删除 \(result.deleted)，保留本地 \(result.keptLocal)，冲突 \(result.conflicts)，配置\(configurationResult.applied ? "已更新" : "无更新")。")
        } catch {
            updateLedgerCloudSyncStatus("iCloud 拉取失败：\(LedgerCloudKitSyncAdapter.describe(error))")
        }
    }

    func pushPendingIntentLedgerSaveIfNeeded(reason: String = "检测到快捷指令账单待推送，开始同步到 iCloud。") async {
        guard UserDefaults.standard.bool(forKey: Self.pendingIntentLedgerCloudPushKey) else { return }
        let didPush = await pushLedgerChangesToCloudKitIfEnabled(reason: reason)
        if didPush {
            UserDefaults.standard.removeObject(forKey: Self.pendingIntentLedgerCloudPushKey)
        }
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
            guard let sqlStore = transactionStore as? SQLiteTransactionStore else {
                updateLedgerCloudSyncStatus("iCloud 同步需要 SQLite 账本。")
                return false
            }

            let adapter = LedgerCloudKitSyncAdapter(mode: .live, allowsLiveCloudKitWrites: true)
            updateLedgerCloudSyncStatus("1/2 正在检查 iCloud 账号状态...")
            let accountCheck = await adapter.checkAccountStatus()
            guard accountCheck.canUsePrivateDatabase else {
                updateLedgerCloudSyncStatus("iCloud 不可用：\(accountCheck.message)")
                return false
            }

            let result = try await pushLocalLedgerChanges(sqlStore: sqlStore, adapter: adapter, forceFull: false)
            updateLedgerCloudSyncStatus("iCloud 推送完成：\(result.pushMode)推送 \(result.savedCount) 条，配置\(result.configurationSaved ? "已推送" : "无需推送")。")
            return true
        } catch {
            updateLedgerCloudSyncStatus("iCloud 推送失败：\(LedgerCloudKitSyncAdapter.describe(error))")
            return false
        }
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
    ) async throws -> (pushMode: String, savedCount: Int, configurationSaved: Bool) {
        if forceFull {
            clearCloudKitPushCheckpoint()
        }

        let lastPushAt = forceFull ? nil : lastSuccessfulCloudKitPushAt
        let localRecords = try sqlStore.loadTransactionSyncRecords(includeDeleted: true)
        let batch = LedgerSyncPlanner.makePushBatch(from: localRecords, changedAfter: lastPushAt)
        let pushMode = lastPushAt == nil ? "全量" : "增量"
        updateLedgerCloudSyncStatus("正在\(pushMode)推送 \(batch.upserts.count) 条账单和 \(batch.tombstones.count) 条删除记录...")
        let pushResult = try await adapter.push(batch: batch)

        let shouldPushConfiguration = forceFull || lastPushAt == nil || ledgerConfigurationUpdatedAt > lastPushAt!
        var configurationSaved = false
        if shouldPushConfiguration {
            updateLedgerCloudSyncStatus("正在推送订阅、商户别名和用户配置...")
            let configurationResult = try await adapter.pushConfiguration(makeLedgerConfigurationPayload())
            configurationSaved = !configurationResult.savedRecordNames.isEmpty
        }

        recordCloudKitPushCheckpoint(batch.generatedAt)
        return (
            pushMode: pushMode,
            savedCount: pushResult.savedRecordNames.count,
            configurationSaved: configurationSaved
        )
    }

    private func pullRemoteLedgerChanges(
        sqlStore: SQLiteTransactionStore,
        adapter: LedgerCloudKitSyncAdapter
    ) async throws -> (remoteCount: Int, inserted: Int, updated: Int, deleted: Int, keptLocal: Int, conflicts: Int) {
        updateLedgerCloudSyncStatus("正在拉取远端账单...")
        let remotePayloads = try await adapter.fetchAllTransactionRecords()

        var inserted = 0
        var updated = 0
        var deleted = 0
        var keptLocal = 0
        var conflicts = 0

        updateLedgerCloudSyncStatus("拉取完成，正在写入本地账本...")
        for payload in remotePayloads {
            switch try sqlStore.applyRemoteSyncRecord(payload.syncRecord) {
            case .inserted:
                inserted += 1
            case .updated:
                updated += 1
            case .deleted:
                deleted += 1
            case .keptLocal:
                keptLocal += 1
            case .conflictPendingReview:
                conflicts += 1
            }
        }
        return (
            remoteCount: remotePayloads.count,
            inserted: inserted,
            updated: updated,
            deleted: deleted,
            keptLocal: keptLocal,
            conflicts: conflicts
        )
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

        try sqlStore.replaceConfigurationForSync(
            subscriptions: remote.subscriptions,
            categoryCorrections: remote.categoryCorrections,
            merchantAliases: remote.merchantAliases
        )

        subscriptions = remote.subscriptions.sorted { $0.nextChargedAt < $1.nextChargedAt }
        categoryCorrections = Dictionary(uniqueKeysWithValues: remote.categoryCorrections.map { ($0.merchant, $0.category) })
        customCategories = remote.customCategories
        customSources = remote.customSources
        merchantAliases = remote.merchantAliases

        UserDefaults.standard.set(customCategories, forKey: "customCategories")
        UserDefaults.standard.set(customSources, forKey: "customSources")
        UserDefaults.standard.set(merchantAliases, forKey: "merchantAliases")
        UserDefaults.standard.set(remote.subscriptionMetadata.annualPriceOverrides, forKey: Self.annualPriceKey)
        UserDefaults.standard.set(remote.subscriptionMetadata.notes, forKey: Self.subscriptionNotesKey)
        UserDefaults.standard.set(remote.appSettings.subscriptionReminderEnabled, forKey: "subscriptionReminder")
        UserDefaults.standard.set(remote.appSettings.monthlyAnomalyThresholdPercent, forKey: "monthlyAnomalyThresholdPercent")
        UserDefaults.standard.set(remote.appSettings.llmEnhancementEnabled, forKey: "llmEnhancementEnabled")
        UserDefaults.standard.set(remote.appSettings.autoClipboardImportEnabled, forKey: "autoClipboardImport")
        UserDefaults.standard.set(false, forKey: Self.iCloudBackupEnabledKey)
        UserDefaults.standard.set(remote.updatedAt, forKey: Self.ledgerConfigurationUpdatedAtKey)

        NotificationService.shared.scheduleUpcomingChargeReminders(for: subscriptions)
        Self.watchSyncHandler?()
        return (remoteFound: true, applied: true)
    }

    private func makeLedgerConfigurationPayload() -> LedgerConfigurationSyncPayload {
        let updatedAt = ensureLedgerConfigurationUpdatedAt()
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
        if ledgerCloudSyncLog.count > 12 {
            ledgerCloudSyncLog.removeFirst(ledgerCloudSyncLog.count - 12)
        }
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
                    self?.lastBackupSummary = "iCloud 自动备份失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func backupOnAppBackground() {
        requestAutomaticBackup(delayNanoseconds: 0)
    }

    func summaryText(for bundle: BackupBundle) -> String {
        "\(bundle.summary.transactionCount) 笔账单，\(bundle.summary.deletedTransactionCount) 笔最近删除，\(bundle.summary.subscriptionCount) 个订阅，\(bundle.summary.merchantAliasCount) 个商户别名"
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
    }

    private func recordBackupSuccess(_ bundle: BackupBundle) {
        UserDefaults.standard.set(bundle.exportedAt, forKey: Self.lastBackupAtKey)
        UserDefaults.standard.set(bundle.bundleId.uuidString, forKey: Self.lastBackupBundleIdKey)
        UserDefaults.standard.removeObject(forKey: Self.lastBackupErrorKey)
    }

    private func applyBackupBundle(_ bundle: BackupBundle) throws {
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try sqlStore.replaceForRestore(
                transactions: bundle.transactions,
                subscriptions: bundle.subscriptions,
                categoryCorrections: bundle.categoryCorrections,
                merchantAliases: bundle.merchantAliases
            )
        } else {
            transactions = bundle.transactions.filter { $0.deletedAt == nil }.map(\.transaction)
            deletedTransactions = bundle.transactions.filter { $0.deletedAt != nil }.map(\.transaction)
            subscriptions = bundle.subscriptions
            categoryCorrections = Dictionary(uniqueKeysWithValues: bundle.categoryCorrections.map { ($0.merchant, $0.category) })
            merchantAliases = bundle.merchantAliases
        }
    }
}

private extension LedgerStore {
    static func loadInitialTransactions(using transactionStore: TransactionStore?) -> [Transaction] {
        do {
            return try transactionStore?.bootstrapIfNeeded(with: seedTransactions) ?? seedTransactions
        } catch {
            return seedTransactions
        }
    }

    static let seedTransactions: [Transaction] = []
}
