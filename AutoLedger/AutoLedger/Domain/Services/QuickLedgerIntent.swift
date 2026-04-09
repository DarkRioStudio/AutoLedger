import AppIntents
import AutoLedgerCore
import Foundation
import UniformTypeIdentifiers

struct QuickLedgerIntent: AppIntent, ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "快速记账"
    static var description: IntentDescription = IntentDescription("从截图中识别支付信息并自动记账")
    /// 需要前台运行以获取沙箱文件读取权限
    static var openAppWhenRun: Bool = true

    @Parameter(title: "截图", description: "微信支付成功页截图", supportedContentTypes: [.image])
    var screenshot: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("从 \(\.$screenshot) 识别并记账")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // 尽早读取文件数据——BackgroundShortcutRunner 沙箱扩展可能过期
        let imageData: Data
        do {
            let d = screenshot.data
            guard !d.isEmpty else {
                throw NSError(domain: "AutoLedger", code: -1, userInfo: [NSLocalizedDescriptionKey: "截图数据为空"])
            }
            imageData = d
        } catch {
            writeDebugEvent(stage: .ocrFailed, source: .manual, rawText: "", summary: "快捷指令读取截图失败：\(error.localizedDescription)")
            return .result(value: "读取截图失败，请打开 App 手动导入")
        }

        // 1. OCR
        let ocrService = OCRService()
        let text: String
        do {
            text = try ocrService.recognizeText(from: imageData)
        } catch {
            writeDebugEvent(stage: .ocrFailed, source: .manual, rawText: "", summary: "快捷指令 OCR 失败：\(error.localizedDescription)")
            return .result(value: "识别失败，请打开 App 确认")
        }

        // 2. 智能解析（规则 + LLM）
        let source = ReceiptSource.infer(from: text)
        let smartParser = SmartReceiptParser()
        guard let result = await smartParser.parse(text: text, source: source) else {
            writeDebugEvent(stage: .parseFailed, source: source, rawText: text, summary: "快捷指令解析失败")
            return .result(value: "识别失败，请打开 App 确认")
        }
        let receipt = result.receipt

        // 3. 去重 + 入账
        let store: SQLiteTransactionStore
        do {
            store = try SQLiteTransactionStore()
        } catch {
            return .result(value: "数据库打开失败，请打开 App 确认")
        }

        let existing = (try? store.loadTransactions()) ?? []
        let isDuplicate = existing.contains {
            $0.merchant == receipt.merchant &&
            abs($0.amount - receipt.amount) < 0.01 &&
            abs($0.occurredAt.timeIntervalSince(receipt.occurredAt)) < 300
        }

        if isDuplicate {
            let msg = "\(receipt.merchant) ¥\(String(format: "%.2f", receipt.amount)) 已存在，未重复记录"
            writeDebugEvent(stage: .duplicateSkipped, source: source, rawText: text, receipt: receipt, summary: msg, llmTrace: result.llmTrace)
            return .result(value: msg)
        }

        let transaction = Transaction(
            merchant: receipt.merchant,
            amount: receipt.amount,
            occurredAt: receipt.occurredAt,
            category: receipt.suggestedCategory,
            source: receipt.source,
            note: "快捷指令自动记账"
        )

        do {
            try store.save(transaction: transaction)
        } catch {
            writeDebugEvent(stage: .persistenceFailed, source: source, rawText: text, receipt: receipt, summary: "快捷指令入账失败：\(error.localizedDescription)", llmTrace: result.llmTrace)
            return .result(value: "入账失败，请打开 App 确认")
        }

        let msg = "已记好：\(receipt.merchant) ¥\(String(format: "%.2f", receipt.amount))"
        writeDebugEvent(stage: .persisted, source: source, rawText: text, receipt: receipt, summary: msg, llmTrace: result.llmTrace)
        return .result(value: msg)
    }

    private func writeDebugEvent(
        stage: ImportDebugStage,
        source: ReceiptSource,
        rawText: String,
        receipt: ImportedReceipt? = nil,
        summary: String,
        llmTrace: SmartReceiptParser.LLMTrace? = nil
    ) {
        let record = ImportDebugRecord(
            stage: stage,
            source: source,
            imageSource: .shortcutIntent,
            rawText: rawText,
            parsedReceipt: receipt,
            summary: summary,
            llmPrompt: llmTrace?.prompt,
            llmResponse: llmTrace?.response
        )
        guard let store = try? SQLiteTransactionStore() else { return }
        try? store.saveDebugEvent(record)
    }
}

struct AutoLedgerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLedgerIntent(),
            phrases: [
                "用 \(.applicationName) 记一笔",
                "用 \(.applicationName) 记账",
                "\(.applicationName) 快速记账"
            ],
            shortTitle: "快速记账",
            systemImageName: "doc.text.viewfinder"
        )
        AppShortcut(
            intent: ClipboardImportIntent(),
            phrases: [
                "用 \(.applicationName) 从剪切板记账",
                "\(.applicationName) 剪切板记账"
            ],
            shortTitle: "剪切板记账",
            systemImageName: "doc.on.clipboard"
        )
    }
}
