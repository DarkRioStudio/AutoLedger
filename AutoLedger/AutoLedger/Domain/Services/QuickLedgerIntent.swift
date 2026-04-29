import AppIntents
import AutoLedgerCore
import Foundation
import OSLog
import UniformTypeIdentifiers
import WidgetKit

nonisolated(unsafe) private let intentLogger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "QuickLedgerIntent")

struct QuickLedgerIntent: AppIntent {
    static var title: LocalizedStringResource = "quick_ledger.intent.title"
    static var description: IntentDescription = IntentDescription("quick_ledger.intent.description")
    /// 后台完成快捷指令记账，成功后仅发通知；用户点通知时再进入 App。
    static var openAppWhenRun: Bool = false

    @Parameter(title: "quick_ledger.screenshot.title", description: "quick_ledger.screenshot.description", supportedContentTypes: [.image])
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
            return .result(value: String(localized: "quick_ledger.read_screenshot_failed"))
        }

        // 1. OCR 与模型预加载并行
        let selectedProvider = await LLMProvider.userSelected
        let enhancementOn = await LLMProvider.isEnhancementEnabled

        // 模型增强关闭时跳过所有模型加载逻辑
        let gemmaReady: Bool
        let modelAlreadyReady: Bool
        if enhancementOn {
            gemmaReady = await GemmaService.shared.isModelReady
            modelAlreadyReady = selectedProvider == .gemma && gemmaReady
        } else {
            gemmaReady = false
            modelAlreadyReady = false
        }

        // 冷启动时后台异步加载模型（与 OCR 并行）；已就绪时跳过，避免重复进入加载流程
        if enhancementOn && !modelAlreadyReady && selectedProvider == .gemma {
            Task { await GemmaService.shared.ensureLoaded() }
        }

        let ocrService = OCRService()
        let ocrResult: OCRResult
        do {
            ocrResult = try ocrService.recognizeTextWithConfidence(from: imageData)
        } catch {
            writeDebugEvent(stage: .ocrFailed, source: .manual, rawText: "", summary: "快捷指令 OCR 失败：\(error.localizedDescription)")
            return .result(value: String(localized: "quick_ledger.recognition_failed"))
        }
        let text = ocrResult.text

        // 模型就绪策略（解决冷启动推理报错）：
        // ⓪ 模型增强关闭 → 纯规则解析
        // ① 已在内存 → 直接推理，零等待
        // ② 未加载   → 最多等 4 秒；超时则本次降级纯规则解析，后台 loadTask 继续预热
        // ③ 非 Gemma → 直接走 SmartReceiptParser（其内部处理可用性）
        let useModelInference: Bool
        if !enhancementOn {
            useModelInference = false
        } else if modelAlreadyReady {
            useModelInference = true
        } else if selectedProvider == .gemma, await GemmaService.shared.isModelDownloaded {
            let deadline = Date(timeIntervalSinceNow: 4)
            while !Task.isCancelled && Date() < deadline {
                if await GemmaService.shared.isModelReady { break }
                try? await Task.sleep(nanoseconds: 200_000_000) // 200 ms
            }
            let ready = await GemmaService.shared.isModelReady
            if !ready {
                intentLogger.info("[Intent] Gemma 模型未在 4 秒内就绪（冷启动），本次降级规则解析")
            }
            useModelInference = ready
        } else {
            useModelInference = true
        }

        // 2. 智能解析（规则 + LLM）
        let source = ReceiptSource.infer(from: text)
        let smartParser = await SmartReceiptParser()
        let cleanedText = await OCRTextCleaner.clean(text)
        let ruleParser = ReceiptParser()

        // 多账单检测
        let multiReceipt = ruleParser.detectMultipleReceipts(text: cleanedText)
        if let diagnostics = ruleParser.receiptDiagnostics(text: cleanedText) {
            intentLogger.info("[Intent][Receipt] \(diagnostics.debugSummary)")
        }

        let result: SmartReceiptParser.SmartResult?
        if useModelInference {
            result = await smartParser.parse(text: cleanedText, source: source,
                                             imageData: imageData,
                                             ocrMinConfidence: ocrResult.minimumWordConfidence,
                                             provider: selectedProvider)
        } else {
            // 冷启动模型超时 → 纯规则兜底，保留完整 SmartResult 包装
            if let ruleReceipt = await smartParser.parseWithRules(text: cleanedText, source: source, imageData: imageData) {
                result = SmartReceiptParser.SmartResult(receipt: ruleReceipt,
                                                        llmTrace: nil,
                                                        usedRuleFallback: true)
            } else {
                result = nil
            }
        }

        guard let result else {
            writeDebugEvent(stage: .parseFailed, source: source, rawText: text, summary: "快捷指令解析失败")
            return .result(value: String(localized: "quick_ledger.recognition_failed"))
        }
        let receipt = result.receipt

        if let diagnostics = receipt.parseDiagnostics,
           diagnostics.isMultiItemReceipt,
           !diagnostics.totalMatched {
            let msg = localizedMessage(
                "receipt.multi_item_total_missing",
                fallback: "Multi-item receipt detected, but the total amount could not be reliably recognized. Please retake the receipt including the total section."
            )
            writeDebugEvent(stage: .parseFailed, source: source, rawText: text, receipt: receipt, summary: "\(msg)\n调试：\(diagnostics.debugSummary)", llmTrace: result.llmTrace)
            return .result(value: msg)
        }

        // 3. 去重 + 入账
        let store: SQLiteTransactionStore
        do {
            store = try SQLiteTransactionStore()
        } catch {
            return .result(value: String(localized: "quick_ledger.database_failed"))
        }

        let existing = (try? store.loadTransactions()) ?? []
        let isDuplicate = existing.contains {
            $0.merchant == receipt.merchant &&
            abs($0.amount - receipt.amount) < 0.01 &&
            abs($0.occurredAt.timeIntervalSince(receipt.occurredAt)) < 60
        }

        // OCR 文本 Jaccard 相似度去重
        let isOCRDuplicate: Bool = {
            ImportDuplicateDetector.hasOCRTextDuplicate(
                rawText: text,
                debugRecords: (try? store.loadDebugEvents()) ?? [],
                activeTransactionIDs: Set(existing.map(\.id)),
                threshold: 0.8
            )
        }()

        if isDuplicate || isOCRDuplicate {
            let reason = isOCRDuplicate
                ? String(localized: "quick_ledger.duplicate.reason.ocr")
                : String(localized: "quick_ledger.duplicate.reason.fields")
            let msg = String(
                format: String(localized: "quick_ledger.duplicate_format"),
                receipt.merchant,
                receipt.amount,
                reason
            )
            writeDebugEvent(stage: .duplicateSkipped, source: source, rawText: text, receipt: receipt, summary: msg, llmTrace: result.llmTrace)
            return .result(value: msg)
        }

        let transaction = Transaction(
            merchant: receipt.merchant,
            amount: receipt.amount,
            occurredAt: receipt.occurredAt,
            category: receipt.suggestedCategory,
            source: receipt.source,
            note: String(localized: "quick_ledger.note")
        )

        do {
            try store.save(transaction: transaction)
        } catch {
            writeDebugEvent(stage: .persistenceFailed, source: source, rawText: text, receipt: receipt, summary: "快捷指令入账失败：\(error.localizedDescription)", llmTrace: result.llmTrace)
            return .result(value: String(localized: "quick_ledger.persistence_failed"))
        }

        WidgetCenter.shared.reloadAllTimelines()

        // 通知 App 内 LedgerStore 刷新（Intent 直写 SQLite，绕过了 LedgerStore）
        await MainActor.run {
            NotificationCenter.default.post(name: NotificationService.didSaveTransactionFromIntent, object: nil)
        }

        await NotificationService.shared.scheduleQuickLedgerSuccessNotification(
            merchant: receipt.merchant,
            amount: receipt.amount,
            transactionID: transaction.id
        )

        var msg = String(
            format: String(localized: "quick_ledger.saved_format"),
            receipt.merchant,
            receipt.amount
        )
        if let diagnostics = receipt.parseDiagnostics,
           diagnostics.isMultiItemReceipt,
           diagnostics.totalMatched {
            msg += "\n" + localizedMessage(
                "receipt.multi_item_single_expense_notice",
                fallback: "Multi-item receipt detected. The current version will record the total amount as a single expense."
            )
        }
        if multiReceipt {
            msg += String(localized: "quick_ledger.multi_receipt_warning")
        }
        writeDebugEvent(stage: .persisted, source: source, rawText: text, receipt: receipt, summary: msg, llmTrace: result.llmTrace, transactionID: transaction.id)
        return .result(value: msg)
    }

    nonisolated private func writeDebugEvent(
        stage: ImportDebugStage,
        source: ReceiptSource,
        rawText: String,
        receipt: ImportedReceipt? = nil,
        summary: String,
        llmTrace: SmartReceiptParser.LLMTrace? = nil,
        transactionID: UUID? = nil
    ) {
        let record = ImportDebugRecord(
            stage: stage,
            source: source,
            imageSource: .shortcutIntent,
            rawText: rawText,
            parsedReceipt: receipt,
            summary: summary,
            llmPrompt: llmTrace?.prompt,
            llmResponse: llmTrace?.response,
            transactionID: transactionID
        )
        guard let store = try? SQLiteTransactionStore() else { return }
        try? store.saveDebugEvent(record)
    }
}

private func localizedMessage(_ key: String, fallback: String) -> String {
    let value = String(localized: String.LocalizationValue(key))
    return value == key ? fallback : value
}

struct AutoLedgerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLedgerIntent(),
            phrases: [
                "用 \(.applicationName) 记一笔",
                "用 \(.applicationName) 记账",
                "\(.applicationName) 快速记账",
                "Log with \(.applicationName)",
                "Quick ledger with \(.applicationName)"
            ],
            shortTitle: "quick_ledger.intent.short_title",
            systemImageName: "doc.text.viewfinder"
        )
        AppShortcut(
            intent: ClipboardImportIntent(),
            phrases: [
                "用 \(.applicationName) 从剪切板记账",
                "\(.applicationName) 剪切板记账",
                "Import from clipboard with \(.applicationName)",
                "Clipboard ledger with \(.applicationName)"
            ],
            shortTitle: "quick_ledger.clipboard.short_title",
            systemImageName: "doc.on.clipboard"
        )
        AppShortcut(
            intent: VoiceLedgerIntent(),
            phrases: [
                "用 \(.applicationName) 语音记账",
                "用 \(.applicationName) 语音记一笔",
                "\(.applicationName) 语音记账",
                "Voice ledger with \(.applicationName)"
            ],
            shortTitle: "voice_ledger.intent.short_title",
            systemImageName: "waveform"
        )
    }
}
