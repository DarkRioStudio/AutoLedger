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
    @Published var merchantAliases: [String: String] = [:]

    private let parser: ReceiptParser
    private let smartParser = SmartReceiptParser()
    private let subscriptionDetector = SubscriptionDetector()
    private let transactionStore: TransactionStore?
    private var lastPasteboardChangeCount: Int
    private var pendingBackupTask: Task<Void, Never>?
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
        self.merchantAliases = UserDefaults.standard.dictionary(forKey: "merchantAliases") as? [String: String] ?? [:]
        self.lastPasteboardChangeCount = UIPasteboard.general.changeCount
        LedgerStore.shared = self
    }

    var monthlySnapshot: MonthlySnapshot {
        MonthlySnapshot.build(from: transactions, referenceDate: .now)
    }

    func saveCustomSources() {
        UserDefaults.standard.set(customSources, forKey: "customSources")
        requestAutomaticBackup()
    }

    func saveCustomCategories() {
        UserDefaults.standard.set(customCategories, forKey: "customCategories")
        requestAutomaticBackup()
    }

    func saveMerchantAliases() {
        UserDefaults.standard.set(merchantAliases, forKey: "merchantAliases")
        requestAutomaticBackup()
    }

    /// 如果商户名命中别名映射则返回别名，否则原样返回
    func resolveMerchant(_ merchant: String) -> String {
        merchantAliases[merchant] ?? merchant
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
        let source = preferredSource ?? ReceiptSource.infer(from: normalizedText)
        let resolvedNotePrefix = notePrefix ?? localizedMessage("note.photo_import", fallback: "支付截图照片导入")

        lastRecognizedText = normalizedText
        lastParsedReceipt = nil

        // 尝试智能解析（异步）
        Task { @MainActor in
            // 高置信订阅续期邮件检测（优先于普通交易解析）
            if let subscription = subscriptionDetector.detectFromText(normalizedText) {
                upsertSubscription(subscription)
                lastImportSummary = "已识别为订阅：\(subscription.merchant) \(AppFormatters.currency(subscription.amount))/\(subscription.period.title)"
                return
            }

            // OCR 文本预清洗（去噪 + 缩短 token）
            let cleanedText = OCRTextCleaner.clean(normalizedText)

            // 多账单检测：在解析前检查是否疑似包含多笔交易
            let multiReceiptDetected = self.parser.detectMultipleReceipts(text: cleanedText)
            if multiReceiptDetected {
                logger.info("[解析] 检测到疑似多笔账单")
            }
            let receiptDiagnostics = self.parser.receiptDiagnostics(text: cleanedText)
            if let receiptDiagnostics {
                logger.info("[小票] \(receiptDiagnostics.debugSummary)")
            }

            let selectedProvider = LLMProvider.userSelected
            let enhancementOn = LLMProvider.isEnhancementEnabled
            logger.info("[解析] 使用模型: \(selectedProvider.displayName), 增强: \(enhancementOn ? "开" : "关")")

            let result: SmartReceiptParser.SmartResult?
            if enhancementOn {
                result = await smartParser.parse(
                    text: cleanedText,
                    source: source,
                    fallbackMerchant: fallbackMerchant,
                    ocrMinConfidence: ocrMinConfidence,
                    provider: selectedProvider
                )
            } else {
                // 模型增强关闭 → 纯规则解析
                if let ruleReceipt = smartParser.parseWithRules(text: cleanedText, source: source, fallbackMerchant: fallbackMerchant) {
                    result = SmartReceiptParser.SmartResult(receipt: ruleReceipt, llmTrace: nil, usedRuleFallback: true)
                } else {
                    result = nil
                }
            }

            guard let result else {
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
                return
            }

            if let diagnostics = result.receipt.parseDiagnostics,
               diagnostics.isMultiItemReceipt,
               !diagnostics.totalMatched {
                let summary = localizedMessage(
                    "receipt.multi_item_total_missing",
                    fallback: "检测到多商品小票，但未能可靠识别总金额，请重新拍摄包含合计区域的小票"
                )
                logger.warning("[小票] 多商品小票未可靠命中 total，不自动入账。\(diagnostics.debugSummary)")
                lastParsedReceipt = result.receipt
                lastImportSummary = summary
                recordDebugEvent(
                    stage: .parseFailed,
                    source: source,
                    imageSource: imageSource,
                    rawText: normalizedText,
                    parsedReceipt: result.receipt,
                    summary: "\(summary)\n调试：\(diagnostics.debugSummary)",
                    llmPrompt: result.llmTrace?.prompt,
                    llmResponse: result.llmTrace?.response,
                    llmProvider: result.llmTrace?.provider.rawValue,
                    llmLatencyMs: result.llmTrace?.latencyMs,
                    llmConfidence: result.receipt.confidence,
                    usedRuleFallback: result.usedRuleFallback
                )
                return
            }

            lastParsedReceipt = result.receipt
            let providerName = result.llmTrace?.provider.displayName ?? "规则"
            let latency = result.llmTrace?.latencyMs ?? 0
            logger.info("[解析] 模型=\(providerName) 耗时=\(latency)ms 商户=\(result.receipt.merchant) 金额=\(result.receipt.amount) 时间=\(AppFormatters.exportDateTime(result.receipt.occurredAt)) 分类=\(result.receipt.suggestedCategory.title) 规则兜底=\(result.usedRuleFallback ? "是" : "否")")
            persistReceipt(
                result.receipt,
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
                if let existing = lastImportSummary {
                    lastImportSummary = existing + "\n" + notice
                } else {
                    lastImportSummary = notice
                }
            }

            // 多账单提示：入账后追加警告，让用户知道可能有遗漏
            if multiReceiptDetected {
                let warning = "⚠️ 检测到图片中可能包含多笔账单，当前仅识别了一笔。建议将每笔账单单独截图后分别导入。"
                if let existing = lastImportSummary {
                    lastImportSummary = existing + "\n" + warning
                } else {
                    lastImportSummary = warning
                }
            }
        }
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
        }
        loadShareExtensionResult()
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
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
    }

    /// 手动新增账单（账本右上角 + 入口）
    func addTransaction(_ transaction: Transaction) {
        guard let store = transactionStore else {
            // 无持久化层（预览/测试场景）：直接更新内存
            transactions.insert(transaction, at: 0)
            sortTransactions()
            lastImportSummary = "已手动记账：\(transaction.merchant) \(AppFormatters.currency(transaction.amount))。"
            reloadWidgets()
            return
        }

        do {
            try store.save(transaction: transaction)
        } catch {
            lastImportSummary = "记账失败：\(error.localizedDescription)"
            return
        }

        transactions.insert(transaction, at: 0)
        sortTransactions()
        lastImportSummary = "已手动记账：\(transaction.merchant) \(AppFormatters.currency(transaction.amount))。"
        reloadWidgets()
        requestAutomaticBackup()
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

        if hasDuplicate(receipt, rawText: rawText) {
            let summary = String(
                format: localizedMessage("voice_ledger_duplicate", fallback: "%@ ¥%.2f 已存在，未重复记录"),
                merchant,
                amount
            )
            lastImportSummary = summary
            recordDebugEvent(
                stage: .duplicateSkipped,
                source: .voice,
                imageSource: .voiceIntent,
                rawText: rawText,
                parsedReceipt: receipt,
                summary: summary
            )
            return
        }

        let transaction = Transaction(
            merchant: merchant,
            amount: amount,
            occurredAt: occurredAt,
            category: category,
            source: .voice,
            note: localizedMessage("voice_ledger_note", fallback: "语音记账")
        )

        guard let store = transactionStore else {
            transactions.insert(transaction, at: 0)
            sortTransactions()
            lastImportSummary = String(format: localizedMessage("voice_ledger_success", fallback: "已记好：%@ ¥%.2f"), merchant, amount)
            reloadWidgets()
            return
        }

        do {
            try store.save(transaction: transaction)
        } catch {
            let summary = localizedMessage("voice_ledger_persistence_failed", fallback: "语音记账保存失败：") + error.localizedDescription
            lastImportSummary = summary
            recordDebugEvent(
                stage: .persistenceFailed,
                source: .voice,
                imageSource: .voiceIntent,
                rawText: rawText,
                parsedReceipt: receipt,
                summary: summary
            )
            return
        }

        transactions.insert(transaction, at: 0)
        sortTransactions()
        lastImportSummary = String(format: localizedMessage("voice_ledger_success", fallback: "已记好：%@ ¥%.2f"), merchant, amount)
        reloadWidgets()
        requestAutomaticBackup()
        recordDebugEvent(
            stage: .persisted,
            source: .voice,
            imageSource: .voiceIntent,
            rawText: rawText,
            parsedReceipt: receipt,
            summary: lastImportSummary ?? "",
            transactionID: transaction.id
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

    func updateTransaction(_ transaction: Transaction) {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else {
            return
        }

        let original = transactions[index]

        // 检测分类修正——仅对内置分类记录用户偏好（自定义分类直接以字符串存储在 Transaction）
        if original.category != transaction.category,
           let builtIn = TransactionCategory(rawValue: transaction.category) {
            recordCategoryCorrection(merchant: transaction.merchant, category: builtIn)
        }

        transactions[index] = transaction
        sortTransactions()

        do {
            try transactionStore?.update(transaction: transaction)
            lastImportSummary = "已保存 \(transaction.merchant) 的修正。"
            reloadWidgets()
            requestAutomaticBackup()
        } catch {
            lastImportSummary = "账单已更新到界面，但写入本地存储失败：\(error.localizedDescription)"
        }
    }

    private func persistReceipt(_ inReceipt: ImportedReceipt, rawText: String, notePrefix: String, imageSource: ImageSource = .unknown, llmTrace: SmartReceiptParser.LLMTrace? = nil, usedRuleFallback: Bool = true) {
        // 商户别名映射
        let resolvedMerchant = resolveMerchant(inReceipt.merchant)
        let receipt: ImportedReceipt
        if resolvedMerchant != inReceipt.merchant {
            logger.info("[别名] \(inReceipt.merchant) → \(resolvedMerchant)")
            receipt = ImportedReceipt(
                source: inReceipt.source,
                merchant: resolvedMerchant,
                amount: inReceipt.amount,
                occurredAt: inReceipt.occurredAt,
                rawText: inReceipt.rawText,
                summary: inReceipt.summary,
                confidence: inReceipt.confidence,
                suggestedCategory: TransactionCategory.infer(from: "\(resolvedMerchant)\n\(rawText)", corrections: categoryCorrections),
                parseDiagnostics: inReceipt.parseDiagnostics
            )
        } else if let correctedCategory = categoryCorrections[inReceipt.merchant] {
            receipt = ImportedReceipt(
                source: inReceipt.source,
                merchant: inReceipt.merchant,
                amount: inReceipt.amount,
                occurredAt: inReceipt.occurredAt,
                rawText: inReceipt.rawText,
                summary: inReceipt.summary,
                confidence: inReceipt.confidence,
                suggestedCategory: correctedCategory,
                parseDiagnostics: inReceipt.parseDiagnostics
            )
        } else if let correctedCategory = categoryCorrections[inReceipt.merchant] {
            receipt = ImportedReceipt(
                source: inReceipt.source,
                merchant: inReceipt.merchant,
                amount: inReceipt.amount,
                occurredAt: inReceipt.occurredAt,
                rawText: inReceipt.rawText,
                summary: inReceipt.summary,
                confidence: inReceipt.confidence,
                suggestedCategory: correctedCategory,
                parseDiagnostics: inReceipt.parseDiagnostics
            )
        } else {
            receipt = inReceipt
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
        // 注意：排除已被用户删除的账单对应的调试记录，避免删除后重试被误判为重复
        guard !rawText.isEmpty else { return false }
        let activeTransactionIDs = Set(transactions.map(\.id))
        let recentTexts = debugRecords
            .filter {
                $0.stage == .persisted &&
                ($0.transactionID.map { activeTransactionIDs.contains($0) } ?? true)
            }
            .prefix(30)
            .map(\.rawText)
        for existingText in recentTexts where !existingText.isEmpty {
            if TextSimilarity.jaccard(rawText, existingText) > 0.8 {
                logger.info("[去重] OCR Jaccard 相似度命中（>0.8），判定为重复来源")
                return true
            }
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
        requestAutomaticBackup()
    }

    func deleteSubscription(_ sub: Subscription) {
        subscriptions.removeAll { $0.id == sub.id }
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.deleteSubscription(id: sub.id)
        }
        NotificationService.shared.scheduleUpcomingChargeReminders(for: subscriptions)
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
        requestAutomaticBackup()
    }

    func deleteCategoryCorrection(merchant: String) {
        categoryCorrections.removeValue(forKey: merchant)
        if let sqlStore = transactionStore as? SQLiteTransactionStore {
            try? sqlStore.deleteCategoryCorrection(merchant: merchant)
        }
        requestAutomaticBackup()
    }

    private static func loadInitialCategoryCorrections(using store: TransactionStore?) -> [String: TransactionCategory] {
        guard let sqlStore = store as? SQLiteTransactionStore else { return [:] }
        return (try? sqlStore.loadCategoryCorrections()) ?? [:]
    }
}

extension LedgerStore {
    private static let annualPriceKey = "subscriptionAnnualPriceOverrides"
    private static let subscriptionNotesKey = "subscriptionNotes"
    private static let iCloudBackupEnabledKey = "iCloudBackupEnabled"
    private static let lastBackupAtKey = "lastBackupAt"
    private static let lastBackupBundleIdKey = "lastBackupBundleId"
    private static let lastBackupErrorKey = "lastBackupError"

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
        get { UserDefaults.standard.bool(forKey: Self.iCloudBackupEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.iCloudBackupEnabledKey)
            if newValue { requestAutomaticBackup(delayNanoseconds: 0) }
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
                categoryCorrections: bundle.categoryCorrections
            )
        } else {
            transactions = bundle.transactions.filter { $0.deletedAt == nil }.map(\.transaction)
            deletedTransactions = bundle.transactions.filter { $0.deletedAt != nil }.map(\.transaction)
            subscriptions = bundle.subscriptions
            categoryCorrections = Dictionary(uniqueKeysWithValues: bundle.categoryCorrections.map { ($0.merchant, $0.category) })
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
