import Foundation

public struct LedgerTextInterpreterCore: Sendable {
    private let relevanceGate = BillRelevanceGate()
    private let voiceParser = VoiceLedgerParser()

    private struct AmountCandidate {
        let value: Double
        let line: String
        let lineIndex: Int
        let hasCurrencyPrefix: Bool
        let hasUnitSuffix: Bool
        let hasDecimal: Bool
        let hasPriorityKeyword: Bool
        let score: Int
    }

    public init() {}

    public func interpret(_ input: InterpretInput) -> InterpretResult {
        let normalizedText = input.rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedText.isEmpty else {
            return InterpretResult(
                draft: nil,
                confidence: .low,
                needsReview: true,
                warnings: [.emptyOCRText],
                debugTrace: ["empty_text"]
            )
        }

        if input.sourceType == .voice || input.sourceType == .siri || input.hints.sourceHint == .sentence {
            return interpretSentence(normalizedText, input: input)
        }

        let relevance = relevanceGate.evaluate(normalizedText, sourceHint: input.hints.sourceHint)
        guard relevance.isRelevant else {
            return InterpretResult(
                draft: nil,
                confidence: .low,
                needsReview: true,
                warnings: [.nonBillImage],
                debugTrace: ["non_bill_image score=\(relevance.score) negative=\(relevance.negativeSignals.joined(separator: ","))"]
            )
        }

        guard let amount = extractBestAmount(from: normalizedText) else {
            return InterpretResult(
                draft: nil,
                confidence: .low,
                needsReview: true,
                warnings: [.missingAmount],
                debugTrace: ["bill_relevant_but_missing_amount score=\(relevance.score)"]
            )
        }

        let merchant = extractMerchant(from: normalizedText)
        let category = TransactionCategory.infer(from: merchant.isEmpty ? normalizedText : merchant).rawValue
        let draft = TransactionDraft(
            amount: amount,
            merchant: merchant.isEmpty ? "待确认商户" : merchant,
            category: category,
            occurredAt: Date(),
            sourceType: input.sourceType,
            inputText: normalizedText,
            parseMethod: .rule
        )

        return InterpretResult(
            draft: draft,
            confidence: merchant.isEmpty ? .medium : .high,
            needsReview: merchant.isEmpty,
            warnings: merchant.isEmpty ? [.multipleAmountsNeedsReview] : [],
            debugTrace: ["bill_relevant score=\(relevance.score) positive=\(relevance.positiveSignals.joined(separator: ","))"]
        )
    }

    public func relevance(for rawText: String, sourceHint: LedgerSourceHint = .unknown) -> BillRelevanceResult {
        relevanceGate.evaluate(rawText, sourceHint: sourceHint)
    }

    private func interpretSentence(_ text: String, input: InterpretInput) -> InterpretResult {
        let corrections = input.categoryCorrections.reduce(into: [String: TransactionCategory]()) { partial, entry in
            if let category = TransactionCategory(rawValue: entry.value) {
                partial[entry.key] = category
            }
        }
        let parsed = voiceParser.parse(text, corrections: corrections)
        guard let amount = parsed.amount, parsed.failureReason == nil else {
            let warning: InterpretWarning = parsed.failureReason == .noAmount ? .missingAmount : .nonBillImage
            return InterpretResult(
                draft: nil,
                confidence: .low,
                needsReview: true,
                warnings: [warning],
                debugTrace: ["sentence_parse_failed reason=\(parsed.failureReason?.rawValue ?? "unknown")"]
            )
        }

        let draft = TransactionDraft(
            amount: amount,
            merchant: parsed.merchant.isEmpty ? "待确认商户" : parsed.merchant,
            category: parsed.category.rawValue,
            occurredAt: parsed.occurredAt,
            sourceType: input.sourceType,
            inputText: parsed.inputText,
            parseMethod: .rule
        )
        return InterpretResult(
            draft: draft,
            confidence: parsed.confidence == .high ? .high : .medium,
            needsReview: parsed.confidence != .high,
            warnings: parsed.confidence == .high ? [] : [.multipleAmountsNeedsReview],
            debugTrace: ["sentence_parse confidence=\(parsed.confidence.rawValue) method=\(parsed.parseMethod)"]
        )
    }

    private func extractAmounts(from text: String) -> [Double] {
        let pattern = #"(?:¥|￥|\$|€|£)?\s*([0-9]+(?:[.,][0-9]{1,2})?)\s*(?:元|块|rmb|RMB)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[range].replacingOccurrences(of: ",", with: "."))
        }
    }

    private func extractBestAmount(from text: String) -> Double? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let candidates = lines.enumerated().flatMap { index, line in
            amountCandidates(in: line, lineIndex: index)
        }

        if let priorityCandidate = candidates
            .filter({ $0.hasPriorityKeyword && isPlausibleAmountCandidate($0) })
            .sorted(by: amountCandidateSort)
            .first {
            return priorityCandidate.value
        }

        if let explicitCandidate = candidates
            .filter({ ($0.hasCurrencyPrefix || $0.hasUnitSuffix || $0.hasDecimal) && isPlausibleAmountCandidate($0) })
            .sorted(by: amountCandidateSort)
            .first {
            return explicitCandidate.value
        }

        return candidates
            .filter(isPlausibleAmountCandidate)
            .sorted(by: amountCandidateSort)
            .first?
            .value
    }

    private func amountCandidates(in line: String, lineIndex: Int) -> [AmountCandidate] {
        let pattern = #"(?<![A-Za-z0-9])([¥￥$€£])?\s*([0-9]+(?:[.,][0-9]{1,2})?)\s*(元|块|rmb|RMB)?(?![A-Za-z0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        let priorityKeywords = [
            "支付金额", "交易金额", "订单金额", "付款金额", "实付", "应付",
            "合计", "总计", "总额", "金额", "total", "grand total", "amount"
        ]
        let hasPriorityKeyword = priorityKeywords.contains { line.localizedCaseInsensitiveContains($0) }

        return regex.matches(in: line, range: nsRange).compactMap { match in
            guard let numberRange = Range(match.range(at: 2), in: line) else { return nil }
            let rawNumber = String(line[numberRange])
            guard let value = Double(rawNumber.replacingOccurrences(of: ",", with: ".")) else { return nil }
            let hasCurrencyPrefix = match.range(at: 1).location != NSNotFound
            let hasUnitSuffix = match.range(at: 3).location != NSNotFound
            let hasDecimal = rawNumber.contains(".") || rawNumber.contains(",")

            var score = 0
            if hasPriorityKeyword { score += 8 }
            if hasCurrencyPrefix { score += 5 }
            if hasDecimal { score += 4 }
            if hasUnitSuffix { score += 3 }
            if lineLooksLikeIdentifier(line) { score -= 8 }
            if lineLooksLikeDateOrTime(line) { score -= 6 }
            if !hasPriorityKeyword && !hasCurrencyPrefix && !hasUnitSuffix && !hasDecimal { score -= 4 }

            return AmountCandidate(
                value: value,
                line: line,
                lineIndex: lineIndex,
                hasCurrencyPrefix: hasCurrencyPrefix,
                hasUnitSuffix: hasUnitSuffix,
                hasDecimal: hasDecimal,
                hasPriorityKeyword: hasPriorityKeyword,
                score: score
            )
        }
    }

    private func isPlausibleAmountCandidate(_ candidate: AmountCandidate) -> Bool {
        guard candidate.value > 0, candidate.value < 100_000 else { return false }
        if lineLooksLikeQuantityOnly(candidate.line),
           !candidate.hasCurrencyPrefix,
           !candidate.hasUnitSuffix,
           !candidate.hasDecimal,
           !candidate.hasPriorityKeyword {
            return false
        }
        if candidate.score < 0 {
            return false
        }
        return true
    }

    private func amountCandidateSort(_ lhs: AmountCandidate, _ rhs: AmountCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        if lhs.lineIndex != rhs.lineIndex {
            return lhs.lineIndex > rhs.lineIndex
        }
        return lhs.value > rhs.value
    }

    private func lineLooksLikeIdentifier(_ line: String) -> Bool {
        let keywords = ["订单号", "商户单号", "交易单号", "流水号", "券号", "编号", "单号", "id", "no."]
        return keywords.contains { line.localizedCaseInsensitiveContains($0) }
    }

    private func lineLooksLikeDateOrTime(_ line: String) -> Bool {
        let patterns = [
            #"\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}"#,
            #"\d{1,2}:\d{2}(?::\d{2})?"#
        ]
        return patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            return regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil
        }
    }

    private func lineLooksLikeQuantityOnly(_ line: String) -> Bool {
        let keywords = ["数量", "件", "个", "qty", "quantity", "x"]
        return keywords.contains { line.localizedCaseInsensitiveContains($0) }
    }

    private func extractMerchant(from text: String) -> String {
        if let labeledMerchant = extractLabeledMerchant(from: text) {
            return labeledMerchant
        }

        let skipKeywords = [
            "付款成功", "支付成功", "交易成功", "交易详情", "订单详情", "支付金额",
            "交易金额", "合计", "小计", "total", "subtotal", "amount", "receipt"
        ]
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.first { line in
            !skipKeywords.contains { line.localizedCaseInsensitiveContains($0) } &&
            extractAmounts(from: line).isEmpty &&
            line.count >= 2
        } ?? ""
    }

    private func extractLabeledMerchant(from text: String) -> String? {
        let labels = ["商户名称", "商户名", "商户", "收款方", "店铺", "门店"]
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for (index, line) in lines.enumerated() {
            for label in labels where line.localizedCaseInsensitiveContains(label) {
                let separators = ["：", ":"]
                for separator in separators {
                    if let range = line.range(of: separator) {
                        let value = line[range.upperBound...]
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !value.isEmpty, extractAmounts(from: value).isEmpty {
                            return value
                        }
                    }
                }

                let nextIndex = index + 1
                if nextIndex < lines.count {
                    let value = lines[nextIndex]
                    if extractAmounts(from: value).isEmpty {
                        return value
                    }
                }
            }
        }
        return nil
    }
}
