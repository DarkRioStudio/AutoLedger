import AutoLedgerCore
import Foundation

struct LedgerTextInterpretationInput {
    let text: String
    let preferredSource: ReceiptSource?
    let fallbackMerchant: String?
    let ocrMinConfidence: Float?
    let categoryCorrections: [String: TransactionCategory]

    init(
        text: String,
        preferredSource: ReceiptSource?,
        fallbackMerchant: String?,
        ocrMinConfidence: Float?,
        categoryCorrections: [String: TransactionCategory] = [:]
    ) {
        self.text = text
        self.preferredSource = preferredSource
        self.fallbackMerchant = fallbackMerchant
        self.ocrMinConfidence = ocrMinConfidence
        self.categoryCorrections = categoryCorrections
    }
}

enum LedgerTextInterpretation {
    case voice(VoiceLedgerParseResult, normalizedText: String, source: ReceiptSource)
    case nonBillImage(normalizedText: String, source: ReceiptSource, debugTrace: [String])
    case subscription(Subscription, normalizedText: String, source: ReceiptSource)
    case transaction(
        SmartReceiptParser.SmartResult,
        normalizedText: String,
        source: ReceiptSource,
        multiReceiptDetected: Bool
    )
    case multiItemTotalMissing(
        SmartReceiptParser.SmartResult,
        normalizedText: String,
        source: ReceiptSource
    )
    case parseFailed(normalizedText: String, source: ReceiptSource)
}

struct LedgerTextInterpreter {
    private let receiptParser = ReceiptParser()
    private let smartParser = SmartReceiptParser()
    private let subscriptionDetector = SubscriptionDetector()
    private let voiceParser = VoiceLedgerParser()
    private let coreInterpreter = LedgerTextInterpreterCore()

    @MainActor
    func interpret(_ input: LedgerTextInterpretationInput) async -> LedgerTextInterpretation {
        let normalizedText = input.text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = input.preferredSource ?? ReceiptSource.infer(from: normalizedText)

        if source == .voice {
            let result = voiceParser.parse(normalizedText, corrections: input.categoryCorrections)
            return .voice(result, normalizedText: normalizedText, source: source)
        }

        if let subscription = subscriptionDetector.detectFromText(normalizedText) {
            return .subscription(subscription, normalizedText: normalizedText, source: source)
        }

        let cleanedText = OCRTextCleaner.clean(normalizedText)
        let coreResult = coreInterpreter.interpret(
            InterpretInput(
                rawText: cleanedText,
                sourceType: source.ledgerInputSourceType,
                hints: LedgerInterpretHints(sourceHint: source.ledgerSourceHint),
                categoryCorrections: input.categoryCorrections.mapValues(\.rawValue)
            )
        )
        if coreResult.warnings.contains(.nonBillImage) {
            return .nonBillImage(
                normalizedText: normalizedText,
                source: source,
                debugTrace: coreResult.debugTrace
            )
        }
        if let transitResult = coreResult.transitStoredValueSmartResult(source: source, rawText: cleanedText) {
            return .transaction(
                transitResult,
                normalizedText: normalizedText,
                source: source,
                multiReceiptDetected: false
            )
        }

        let selectedProvider = LLMProvider.userSelected
        let enhancementOn = LLMProvider.isEnhancementEnabled

        let result: SmartReceiptParser.SmartResult?
        if ExternalReceiptAssistSettings.isEnabled {
            result = await smartParser.parseWithExternalAssist(
                text: cleanedText,
                source: source,
                fallbackMerchant: input.fallbackMerchant
            )
        } else if enhancementOn, #available(iOS 26.0, *) {
            result = await smartParser.parse(
                text: cleanedText,
                source: source,
                fallbackMerchant: input.fallbackMerchant,
                ocrMinConfidence: input.ocrMinConfidence,
                provider: selectedProvider
            )
        } else if let ruleReceipt = smartParser.parseWithRules(
            text: cleanedText,
            source: source,
            fallbackMerchant: input.fallbackMerchant
        ) {
            result = SmartReceiptParser.SmartResult(receipt: ruleReceipt, llmTrace: nil, usedRuleFallback: true)
        } else {
            result = nil
        }

        guard let result else {
            return .parseFailed(normalizedText: normalizedText, source: source)
        }

        if let diagnostics = result.receipt.parseDiagnostics,
           diagnostics.isMultiItemReceipt,
           !diagnostics.totalMatched {
            return .multiItemTotalMissing(result, normalizedText: normalizedText, source: source)
        }

        return .transaction(
            result,
            normalizedText: normalizedText,
            source: source,
            multiReceiptDetected: false
        )
    }
}

private extension InterpretResult {
    func transitStoredValueSmartResult(source: ReceiptSource, rawText: String) -> SmartReceiptParser.SmartResult? {
        guard debugTrace.contains(where: { $0.hasPrefix("transit_stored_value") }),
              let draft,
              let category = TransactionCategory(rawValue: draft.category) else {
            return nil
        }

        let receipt = ImportedReceipt(
            source: source,
            merchant: draft.merchant,
            amount: draft.amount,
            occurredAt: draft.occurredAt,
            rawText: rawText,
            summary: "\(source.title) 地铁/公交规则解析",
            confidence: confidence == .high ? 0.94 : 0.82,
            suggestedCategory: category
        )
        return SmartReceiptParser.SmartResult(receipt: receipt, llmTrace: nil, usedRuleFallback: true)
    }
}

private extension ReceiptSource {
    var ledgerInputSourceType: LedgerInputSourceType {
        switch self {
        case .voice:
            return .voice
        default:
            return .ocr
        }
    }

    var ledgerSourceHint: LedgerSourceHint {
        switch self {
        case .voice:
            return .sentence
        case .appStore:
            return .subscription
        default:
            return .payment
        }
    }
}
