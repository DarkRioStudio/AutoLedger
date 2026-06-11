import Foundation

public struct LedgerTextInterpreterCore: Sendable {
    private let relevanceGate = BillRelevanceGate()
    private let voiceParser = VoiceLedgerParser()

    public init() {}

    public func interpret(_ input: InterpretInput) -> InterpretResult {
        let normalizedText = input.rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedText.isEmpty else {
            return InterpretResult(draft: nil, confidence: .low, needsReview: true, warnings: [.emptyOCRText], debugTrace: ["empty_text"])
        }

        if input.sourceType == .voice || input.sourceType == .siri || input.hints.sourceHint == .sentence {
            return interpretSentence(normalizedText, input: input)
        }

        let relevance = relevanceGate.evaluate(normalizedText, sourceHint: input.hints.sourceHint)
        guard relevance.isRelevant else {
            return InterpretResult(draft: nil, confidence: .low, needsReview: true, warnings: [.nonBillImage],
                debugTrace: ["non_bill_image score=\(relevance.score) negative=\(relevance.negativeSignals.joined(separator: ","))"])
        }

        let lines = normalizedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let amountResult = PaymentAmountExtractor().extract(from: normalizedText, lines: lines)
        guard let amount = amountResult.paidAmount else {
            return InterpretResult(draft: nil, confidence: .low, needsReview: true, warnings: [.missingAmount],
                debugTrace: ["bill_relevant_but_missing_amount score=\(relevance.score)"])
        }

        let merchantResult = extractMerchant(from: normalizedText)
        let merchant = merchantResult.merchant
        let category = Self.inferCategory(from: merchant.isEmpty ? normalizedText : merchant)

        var warnings: [InterpretWarning] = []
        if merchant.isEmpty { warnings.append(.merchantMissing) }
        if amountResult.isApproximate { warnings.append(.missingReliableTotal) }

        let draft = TransactionDraft(
            amount: amount,
            merchant: merchant.isEmpty ? "待确认商户" : merchant,
            category: category.rawValue,
            occurredAt: Date(),
            sourceType: input.sourceType,
            inputText: normalizedText,
            parseMethod: .rule
        )

        return InterpretResult(draft: draft, confidence: merchant.isEmpty ? .medium : .high,
            needsReview: merchant.isEmpty || amountResult.isApproximate, warnings: warnings,
            debugTrace: [
                "bill_relevant score=\(relevance.score) positive=\(relevance.positiveSignals.joined(separator: ","))",
            ] + amountResult.debugTrace + merchantResult.debugTrace)
    }

    public func relevance(for rawText: String, sourceHint: LedgerSourceHint = .unknown) -> BillRelevanceResult {
        relevanceGate.evaluate(rawText, sourceHint: sourceHint)
    }

    private func interpretSentence(_ text: String, input: InterpretInput) -> InterpretResult {
        let corrections = input.categoryCorrections.reduce(into: [String: TransactionCategory]()) { partial, entry in
            if let category = TransactionCategory(rawValue: entry.value) { partial[entry.key] = category }
        }
        let parsed = voiceParser.parse(text, corrections: corrections)
        guard let amount = parsed.amount, parsed.failureReason == nil else {
            let w: InterpretWarning = parsed.failureReason == .noAmount ? .missingAmount : .nonBillImage
            return InterpretResult(draft: nil, confidence: .low, needsReview: true, warnings: [w],
                debugTrace: ["sentence_parse_failed reason=\(parsed.failureReason?.rawValue ?? "unknown")"])
        }
        let draft = TransactionDraft(amount: amount, merchant: parsed.merchant.isEmpty ? "待确认商户" : parsed.merchant,
            category: parsed.category.rawValue, occurredAt: parsed.occurredAt, sourceType: input.sourceType,
            inputText: parsed.inputText, parseMethod: .rule)
        return InterpretResult(draft: draft, confidence: parsed.confidence == .high ? .high : .medium,
            needsReview: parsed.confidence != .high,
            warnings: parsed.confidence == .high ? [] : [.multipleAmountsNeedsReview],
            debugTrace: ["sentence_parse confidence=\(parsed.confidence.rawValue) method=\(parsed.parseMethod)"])
    }

    // MARK: - Merchant Extraction

    private func extractMerchant(from text: String) -> MerchantResolutionResult {
        let candidates = RuleMerchantExtractor().extractCandidates(from: text)
        return MerchantResolver().resolve(candidates: candidates, text: text)
    }

    // MARK: - Category Inference

    private static let merchantCategoryMap: [(keywords: [String], category: TransactionCategory)] = [
        (["mr d.i.y.", "mr diy", "mr. d.i.y."], .shopping),
        (["perniagaan zheng hui", "sin nathamby", "yongfatt", "abc ho trading"], .shopping),
        (["soon huat machinery", "indah gift", "ted heng", "fy eagle"], .shopping),
        (["mynews retail", "mynews"], .shopping),
        (["pasar nine jin seng", "pasar"], .groceries),
        (["ntuc fairprice", "walmart", "supermarket", "fairprice", "tesco", "aeon", "lotus"], .groceries),
        (["7-eleven", "seven eleven", "7 eleven", "family mart", "罗森", "便利店"], .groceries),
        (["mcdonald", "gerbang alaf restaurants", "golden arches"], .dining),
        (["kfc", "burger king", "pizza hut", "starbucks", "subway"], .dining),
        (["sheraton", "marriott", "hilton", "hyatt", "hotel"], .entertainment),
        (["滴滴", "didi", "grab", "gojek", "uber"], .transport),
        (["shell", "petronas", "caltex", "esso", "汽油", "加油站"], .transport),
        (["apple services", "apple.com", "app store", "spotify", "netflix"], .digital),
        (["icloud", "google one", "chatgpt", "openai"], .digital),
    ]

    public static func inferCategory(from text: String) -> TransactionCategory {
        let lowered = text.lowercased()
        for (keywords, category) in merchantCategoryMap {
            for kw in keywords {
                if lowered.contains(kw) { return category }
            }
        }
        return TransactionCategory.infer(from: text)
    }
}
