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

    private let parser: ReceiptParser
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
    }

    var monthlySnapshot: MonthlySnapshot {
        MonthlySnapshot.build(from: transactions, referenceDate: .now)
    }

    func importSample(_ sample: SampleReceipt) {
        importRecognizedText(
            sample.rawText,
            preferredSource: sample.source,
            fallbackMerchant: sample.title,
            notePrefix: "来自 \(sample.source.title) 示例导入"
        )
    }

    func importRecognizedText(
        _ text: String,
        preferredSource: ReceiptSource? = nil,
        fallbackMerchant: String? = nil,
        notePrefix: String = "来自真实截图 OCR 导入"
    ) {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = preferredSource ?? ReceiptSource.infer(from: normalizedText)

        lastRecognizedText = normalizedText
        lastParsedReceipt = nil

        guard let receipt = parser.parse(
            text: normalizedText,
            source: source,
            fallbackMerchant: fallbackMerchant
        ) else {
            let summary = "OCR 已完成，但还没解析出可入账字段。"
            lastImportSummary = summary
            recordDebugEvent(
                stage: .parseFailed,
                source: source,
                rawText: normalizedText,
                parsedReceipt: nil,
                summary: summary
            )
            return
        }

        lastParsedReceipt = receipt
        persistReceipt(receipt, rawText: normalizedText, notePrefix: notePrefix)
    }

    func prepareForLiveImport() {
        lastRecognizedText = ""
        lastParsedReceipt = nil
    }

    func setImportError(_ summary: String, source: ReceiptSource = .manual) {
        lastImportSummary = summary
        lastParsedReceipt = nil
        recordDebugEvent(
            stage: .ocrFailed,
            source: source,
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

    private func persistReceipt(_ receipt: ImportedReceipt, rawText: String, notePrefix: String) {
        if hasDuplicate(receipt) {
            let summary = "\(receipt.merchant) 已存在同日同金额记录，账本未重复写入。"
            lastImportSummary = summary
            recordDebugEvent(
                stage: .duplicateSkipped,
                source: receipt.source,
                rawText: rawText,
                parsedReceipt: receipt,
                summary: summary
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
                rawText: rawText,
                parsedReceipt: receipt,
                summary: summary
            )
            return
        }

        let summary = "已导入 \(receipt.merchant)，金额 \(AppFormatters.currency(receipt.amount))。"
        lastImportSummary = summary
        recordDebugEvent(
            stage: .persisted,
            source: receipt.source,
            rawText: rawText,
            parsedReceipt: receipt,
            summary: summary
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
        rawText: String,
        parsedReceipt: ImportedReceipt?,
        summary: String
    ) {
        debugRecords.insert(
            ImportDebugRecord(
                createdAt: .now,
                stage: stage,
                source: source,
                rawText: rawText,
                parsedReceipt: parsedReceipt,
                summary: summary
            ),
            at: 0
        )
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
