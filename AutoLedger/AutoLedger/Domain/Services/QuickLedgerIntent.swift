import AppIntents
import AutoLedgerCore
import Foundation
import OSLog
import UniformTypeIdentifiers

nonisolated(unsafe) private let intentLogger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "QuickLedgerIntent")

struct QuickLedgerIntent: AppIntent {
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
        if !modelAlreadyReady && selectedProvider == .gemma {
            Task { await GemmaService.shared.ensureLoaded() }
        }

        let ocrService = OCRService()
        let ocrResult: OCRResult
        do {
            ocrResult = try ocrService.recognizeTextWithConfidence(from: imageData)
        } catch {
            writeDebugEvent(stage: .ocrFailed, source: .manual, rawText: "", summary: "快捷指令 OCR 失败：\(error.localizedDescription)")
            return .result(value: "识别失败，请打开 App 确认")
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

        // 多账单检测
        let multiReceipt = ReceiptParser().detectMultipleReceipts(text: cleanedText)

        let result: SmartReceiptParser.SmartResult?
        if useModelInference {
            result = await smartParser.parse(text: cleanedText, source: source,
                                             ocrMinConfidence: ocrResult.minimumWordConfidence,
                                             provider: selectedProvider)
        } else {
            // 冷启动模型超时 → 纯规则兜底，保留完整 SmartResult 包装
            if let ruleReceipt = await smartParser.parseWithRules(text: cleanedText, source: source) {
                result = SmartReceiptParser.SmartResult(receipt: ruleReceipt,
                                                        llmTrace: nil,
                                                        usedRuleFallback: true)
            } else {
                result = nil
            }
        }

        guard let result else {
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
            abs($0.occurredAt.timeIntervalSince(receipt.occurredAt)) < 60
        }

        // OCR 文本 Jaccard 相似度去重
        let isOCRDuplicate: Bool = {
            guard !text.isEmpty else { return false }
            let recentTexts = ((try? store.loadDebugEvents()) ?? [])
                .filter { $0.stage == .persisted }
                .prefix(30)
                .map(\.rawText)
            return recentTexts.contains { !$0.isEmpty && TextSimilarity.jaccard(text, $0) > 0.8 }
        }()

        if isDuplicate || isOCRDuplicate {
            let reason = isOCRDuplicate ? "OCR文本高度相似" : "同商户同金额"
            let msg = "\(receipt.merchant) ¥\(String(format: "%.2f", receipt.amount)) 已存在（\(reason)），未重复记录"
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

        // 通知 App 内 LedgerStore 刷新（Intent 直写 SQLite，绕过了 LedgerStore）
        await MainActor.run {
            NotificationCenter.default.post(name: NotificationService.didSaveTransactionFromIntent, object: nil)
        }

        await NotificationService.shared.scheduleQuickLedgerSuccessNotification(
            merchant: receipt.merchant,
            amount: receipt.amount,
            transactionID: transaction.id
        )

        var msg = "已记好：\(receipt.merchant) ¥\(String(format: "%.2f", receipt.amount))"
        if multiReceipt {
            msg += "\n⚠️ 图片中可能有多笔账单，仅识别了一笔，建议单独截图"
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
