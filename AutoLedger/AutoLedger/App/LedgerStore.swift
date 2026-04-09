import AutoLedgerCore
import Combine
import Foundation

final class LedgerStore: ObservableObject {
    @Published private(set) var transactions: [Transaction]
    @Published private(set) var recentImports: [ImportedReceipt] = []
    @Published private(set) var debugRecords: [ImportDebugRecord] = []
    @Published private(set) var sampleReceipts: [SampleReceipt]
    @Published private(set) var lastRecognizedText = ""
    @Published private(set) var lastParsedReceipt: ImportedReceipt?
    @Published var lastImportSummary: String?
    @Published var customSources: [String] = []
    @Published var customCategories: [String] = []

    private let parser: ReceiptParser
    private let smartParser = SmartReceiptParser()
    private let transactionStore: TransactionStore?

    init(
        parser: ReceiptParser = ReceiptParser(),
        sampleProvider: SampleReceiptProviding = SampleReceiptProvider(),
        transactionStore: TransactionStore? = try? SQLiteTransactionStore()
    ) {
        self.parser = parser
        self.sampleReceipts = sampleProvider.samples
        self.transactionStore = transactionStore
        self.transactions = LedgerStore.loadInitialTransactions(using: transactionStore)
        self.debugRecords = LedgerStore.loadInitialDebugRecords(using: transactionStore)
        self.customSources = UserDefaults.standard.stringArray(forKey: "customSources") ?? []
        self.customCategories = UserDefaults.standard.stringArray(forKey: "customCategories") ?? []
    }

    var monthlySnapshot: MonthlySnapshot {
        MonthlySnapshot.build(from: transactions, referenceDate: .now)
    }

    func saveCustomSources() {
        UserDefaults.standard.set(customSources, forKey: "customSources")
    }

    func saveCustomCategories() {
        UserDefaults.standard.set(customCategories, forKey: "customCategories")
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
        persistReceipt(receipt, rawText: normalizedText, notePrefix: "示例导入")
    }

    func importRecognizedText(
        _ text: String,
        preferredSource: ReceiptSource? = nil,
        fallbackMerchant: String? = nil,
        notePrefix: String = "支付截图照片导入",
        imageSource: ImageSource = .photoLibrary
    ) {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = preferredSource ?? ReceiptSource.infer(from: normalizedText)

        lastRecognizedText = normalizedText
        lastParsedReceipt = nil

        // 尝试智能解析（异步）
        Task { @MainActor in
            let result = await smartParser.parse(
                text: normalizedText,
                source: source,
                fallbackMerchant: fallbackMerchant
            )

            guard let result else {
                let summary = "OCR 已完成，但还没解析出可入账字段。"
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

            lastParsedReceipt = result.receipt
            persistReceipt(
                result.receipt,
                rawText: normalizedText,
                notePrefix: notePrefix,
                imageSource: imageSource,
                llmTrace: result.llmTrace
            )
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
            debugRecords = (try? sqlStore.loadDebugEvents()) ?? debugRecords
        }
        loadShareExtensionResult()
    }

    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }

        do {
            try transactionStore?.delete(transactionID: transaction.id)
            lastImportSummary = "已删除 \(transaction.merchant) 的记录。"
        } catch {
            lastImportSummary = "界面已移除，但本地存储删除失败：\(error.localizedDescription)"
        }
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

        transactions[index] = transaction
        sortTransactions()

        do {
            try transactionStore?.update(transaction: transaction)
            lastImportSummary = "已保存 \(transaction.merchant) 的修正。"
        } catch {
            lastImportSummary = "账单已更新到界面，但写入本地存储失败：\(error.localizedDescription)"
        }
    }

    private func persistReceipt(_ receipt: ImportedReceipt, rawText: String, notePrefix: String, imageSource: ImageSource = .unknown, llmTrace: SmartReceiptParser.LLMTrace? = nil) {
        if hasDuplicate(receipt) {
            let summary = "\(receipt.merchant) 已存在同日同金额记录，账本未重复写入。"
            lastImportSummary = summary
            recordDebugEvent(
                stage: .duplicateSkipped,
                source: receipt.source,
                imageSource: imageSource,
                rawText: rawText,
                parsedReceipt: receipt,
                summary: summary,
                llmPrompt: llmTrace?.prompt,
                llmResponse: llmTrace?.response
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
                llmResponse: llmTrace?.response
            )
            return
        }

        let summary = "已导入 \(receipt.merchant)，金额 \(AppFormatters.currency(receipt.amount))。"
        lastImportSummary = summary
        recordDebugEvent(
            stage: .persisted,
            source: receipt.source,
            imageSource: imageSource,
            rawText: rawText,
            parsedReceipt: receipt,
            summary: summary,
            llmPrompt: llmTrace?.prompt,
            llmResponse: llmTrace?.response
        )
    }

    private func hasDuplicate(_ receipt: ImportedReceipt) -> Bool {
        transactions.contains {
            $0.merchant == receipt.merchant &&
            abs($0.amount - receipt.amount) < 0.01 &&
            Calendar.current.isDate($0.occurredAt, inSameDayAs: receipt.occurredAt)
        }
    }

    private func sortTransactions() {
        transactions.sort { lhs, rhs in
            if lhs.occurredAt == rhs.occurredAt {
                return lhs.id.uuidString > rhs.id.uuidString
            }
            return lhs.occurredAt > rhs.occurredAt
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
        llmResponse: String? = nil
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
            llmResponse: llmResponse
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
}

private extension LedgerStore {
    static func loadInitialTransactions(using transactionStore: TransactionStore?) -> [Transaction] {
        do {
            return try transactionStore?.bootstrapIfNeeded(with: seedTransactions) ?? seedTransactions
        } catch {
            return seedTransactions
        }
    }

    static let seedTransactions: [Transaction] = [
        Transaction(
            merchant: "Example Supermarket",
            amount: 86.30,
            occurredAt: AppFormatters.calendar.date(byAdding: .day, value: -1, to: .now) ?? .now,
            category: .groceries,
            source: .manual,
            note: "冷启动样例数据"
        ),
        Transaction(
            merchant: "滴滴出行",
            amount: 23.80,
            occurredAt: AppFormatters.calendar.date(byAdding: .day, value: -2, to: .now) ?? .now,
            category: .transport,
            source: .manual,
            note: "冷启动样例数据"
        ),
        Transaction(
            merchant: "Apple Services",
            amount: 28.00,
            occurredAt: AppFormatters.calendar.date(byAdding: .day, value: -5, to: .now) ?? .now,
            category: .digital,
            source: .manual,
            note: "冷启动样例数据"
        )
    ]
}
