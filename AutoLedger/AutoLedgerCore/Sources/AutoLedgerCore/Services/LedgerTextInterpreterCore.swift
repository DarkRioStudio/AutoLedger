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

        let lines = normalizedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let transit = parseTransitStoredValueReceipt(lines: lines, rawText: normalizedText, input: input) {
            return transit
        }

        let relevance = relevanceGate.evaluate(
            normalizedText,
            sourceHint: input.hints.sourceHint,
            localeIdentifier: input.localeIdentifier
        )
        guard relevance.isRelevant else {
            return InterpretResult(draft: nil, confidence: .low, needsReview: true, warnings: [.nonBillImage],
                debugTrace: ["non_bill_image score=\(relevance.score) negative=\(relevance.negativeSignals.joined(separator: ","))"])
        }

        let amountResult = PaymentAmountExtractor().extract(from: normalizedText, lines: lines)
        guard let amount = amountResult.paidAmount else {
            return InterpretResult(draft: nil, confidence: .low, needsReview: true, warnings: [.missingAmount],
                debugTrace: ["bill_relevant_but_missing_amount score=\(relevance.score)"])
        }

        let merchantResult = extractMerchant(from: normalizedText)
        let merchant = merchantResult.merchant
        let categoryResult = CategoryResolver().resolveDetailed(text: merchant.isEmpty ? normalizedText : merchant)
        let category = categoryResult.category

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
            ] + amountResult.debugTrace + merchantResult.debugTrace + categoryResult.debugTrace)
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

    // MARK: - Transit Stored Value Receipts

    private func parseTransitStoredValueReceipt(
        lines: [String],
        rawText: String,
        input: InterpretInput
    ) -> InterpretResult? {
        let transitLabels: Set<String> = ["地铁", "公交"]

        for (index, line) in lines.enumerated() {
            guard let colonRange = line.rangeOfCharacter(from: CharacterSet(charactersIn: ":：")) else {
                continue
            }

            let label = String(line[..<colonRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard transitLabels.contains(label) else { continue }

            let inlinePart = String(line[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let amount = transitAmount(in: inlinePart)
                ?? lines.dropFirst(index + 1).prefix(3).compactMap(transitAmount(in:)).first
            guard let amount else { continue }

            let stationText: String?
            if !inlinePart.isEmpty && transitAmount(in: inlinePart) == nil {
                stationText = inlinePart
            } else {
                stationText = lines.dropFirst(index + 1).first(where: isTransitRouteLine(_:))
            }
            guard let stationText else { continue }

            let merchant = "\(label)：\(normalizedTransitRoute(stationText))"
            let draft = TransactionDraft(
                amount: amount,
                merchant: merchant,
                category: TransactionCategory.transport.rawValue,
                occurredAt: Date(),
                sourceType: input.sourceType,
                inputText: rawText,
                parseMethod: .rule
            )
            return InterpretResult(
                draft: draft,
                confidence: .high,
                needsReview: false,
                warnings: [],
                debugTrace: [
                    "transit_stored_value label=\(label)",
                    "transit_amount=\(amount)",
                    "transit_route=\(merchant)"
                ]
            )
        }

        return nil
    }

    private func transitAmount(in line: String) -> Double? {
        let pattern = #"(?i)(?:CN¥|CN￥|CNY|RMB|¥|￥)\s*([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: nsRange),
              let range = Range(match.range(at: 1), in: line),
              let amount = Double(String(line[range])),
              amount > 0,
              amount < 1000 else {
            return nil
        }
        return amount
    }

    private func isTransitRouteLine(_ line: String) -> Bool {
        guard transitAmount(in: line) == nil else { return false }
        guard line.count >= 3 else { return false }

        let skipContains = [
            "余额", "推荐", "相关搜索", "评论", "裁判", "现在", "小红书",
            "付款", "支付", "成功", "通知", "城市卡"
        ]
        guard !skipContains.contains(where: { line.contains($0) }) else { return false }

        return line.contains("→")
            || line.contains("->")
            || line.contains("-")
            || line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count >= 2
    }

    private func normalizedTransitRoute(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("→") {
            return trimmed
        }
        if trimmed.contains("->") {
            return trimmed.replacingOccurrences(of: "->", with: "→")
        }

        let stations = trimmed
            .components(separatedBy: CharacterSet(charactersIn: "- "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return stations.count >= 2 ? stations.joined(separator: "→") : trimmed
    }

    // MARK: - Merchant Extraction

    private func extractMerchant(from text: String) -> MerchantResolutionResult {
        let candidates = RuleMerchantExtractor().extractCandidates(from: text)
        return MerchantResolver().resolve(candidates: candidates, text: text)
    }

    // MARK: - Category Inference

    public static func inferCategory(from text: String) -> TransactionCategory {
        CategoryResolver().resolve(text: text)
    }
}
