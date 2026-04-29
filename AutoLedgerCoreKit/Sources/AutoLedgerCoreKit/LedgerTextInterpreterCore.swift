import Foundation

public struct LedgerTextInterpreterCore: Sendable {
    private let relevanceGate = BillRelevanceGate()
    private let voiceParser = VoiceLedgerParser()

    private static let totalKeywords: [String] = [
        "合计", "总计", "总金额", "总额", "小计", "实付", "实收", "应付", "付款金额",
        "total", "grand total", "subtotal", "amount due", "total due", "total rounded",
        "total incl", "total inclusive", "amount", "rounded total", "total sales",
        "jumlah", "jumlah besar", "jumlah bayaran",
        "合計"
    ]

    private static let nonMerchantBlacklist: Set<String> = [
        "tan woon yann", "tan woon yarn", "tan chay yee", "cash sale", "tax invoice", "simplified tax invoice",
        "invoice", "receipt", "cash bill",
        "thank you", "thank you please come again", "please come again",
        "goods sold are not returnable", "goods sold are not refundable",
        "gst reg", "gst id", "gst summary",
        "change", "change due", "cash", "cash tendered",
        "total", "grand total", "subtotal", "sub total",
        "rounding adjustment", "rounding", "document no", "doc no", "invoice no",
        "member", "cashier", "salesperson", "date", "time", "ref", "qty", "item",
        "description", "price", "amount", "discount",
        "gst summary", "tax code", "tax invoice"
    ]

    private static let shortCodePattern = try? NSRegularExpression(pattern: #"^[A-Za-z0-9]{2,8}$"#)
    private static let productCodePattern = try? NSRegularExpression(pattern: #"^[A-Za-z][A-Za-z0-9]{1,5}:\d+[A-Za-z]?$"#)

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

        let amountResult = extractBestAmount(from: normalizedText, lines: lines)
        guard let amount = amountResult.amount else {
            return InterpretResult(draft: nil, confidence: .low, needsReview: true, warnings: [.missingAmount],
                debugTrace: ["bill_relevant_but_missing_amount score=\(relevance.score)"])
        }

        let (merchant, merchantWarning) = extractMerchant(from: normalizedText, lines: lines)
        let category = Self.inferCategory(from: merchant.isEmpty ? normalizedText : merchant)

        var warnings: [InterpretWarning] = []
        if let mw = merchantWarning { warnings.append(mw) }
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
                "amount_source=\(amountResult.source)"
            ])
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

    // MARK: - Amount Extraction

    private static let rmAmountRegex = try? NSRegularExpression(pattern: #"(?<![A-Za-z0-9])RM[_\s]*([0-9]+(?:[.,][0-9]{1,2})?)(?![A-Za-z0-9])"#, options: [.caseInsensitive])
    private static let currencyAmountRegex = try? NSRegularExpression(pattern: #"(?<![A-Za-z0-9])([¥￥$€£])?\s*([0-9]+(?:[.,][0-9]{1,2})?)\s*(元|块|rmb|RMB)?(?![A-Za-z0-9./])"#, options: [.caseInsensitive])

    struct AmountResult { let amount: Double?; let source: String; let isApproximate: Bool }

    private func extractBestAmount(from text: String, lines: [String]) -> AmountResult {
        if let rmResult = extractRMAmounts(from: text, lines: lines) { return rmResult }

        if let totalResult = extractFromTotalLines(lines) {
            return AmountResult(amount: totalResult, source: "total_line", isApproximate: false)
        }

        let totalNextResult = extractFromTotalNextLine(lines)
        if let amount = totalNextResult {
            return AmountResult(amount: amount, source: "total_next_line", isApproximate: false)
        }

        let lastExplicit = extractLastExplicitAmount(lines)
        if let amount = lastExplicit {
            return AmountResult(amount: amount, source: "last_explicit", isApproximate: false)
        }

        let lastAny = extractLastAnyAmount(lines)
        if let amount = lastAny {
            return AmountResult(amount: amount, source: "last_fallback", isApproximate: true)
        }

        return AmountResult(amount: nil, source: "none", isApproximate: false)
    }

    private func extractRMAmounts(from text: String, lines: [String]) -> AmountResult? {
        guard let regex = Self.rmAmountRegex else { return nil }
        var candidates: [(value: Double, lineIndex: Int, line: String)] = []

        for (index, line) in lines.enumerated() {
            if lineLooksLikeChangeOrCashLine(line) { continue }
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, range: nsRange)
            for match in matches {
                guard let numberRange = Range(match.range(at: 1), in: line) else { continue }
                let raw = String(line[numberRange]).replacingOccurrences(of: ",", with: ".")
                guard let value = Double(raw), value > 0, value < 100_000 else { continue }
                if raw.range(of: #"^\d{4,}$"#, options: .regularExpression) != nil, raw.range(of: #"\."#) == nil {
                    continue
                }
                candidates.append((value, index, line))
            }
        }

        guard !candidates.isEmpty else { return nil }

        let totalKeywordCandidates = candidates.filter { totalLineScore($0.line) > 0 }
        if totalKeywordCandidates.isEmpty {
            let nearTotal = candidates.filter { c in
                distanceToNearestTotalKeyword(at: c.lineIndex, lines: lines) <= 2
            }
            if let bestNear = (nearTotal.isEmpty ? candidates : nearTotal).max(by: { $0.value < $1.value }) {
                return AmountResult(amount: bestNear.value, source: "rm_near_total", isApproximate: false)
            }
            let best = candidates.sorted { $0.lineIndex > $1.lineIndex }.first!
            return AmountResult(amount: best.value, source: "rm_last", isApproximate: false)
        }
        let best = totalKeywordCandidates
            .sorted { a, b in
                let aScore = totalLineScore(a.line)
                let bScore = totalLineScore(b.line)
                if aScore != bScore { return aScore > bScore }
                return a.lineIndex > b.lineIndex
            }.first!
        return AmountResult(amount: best.value, source: "rm_total_line", isApproximate: false)
    }

    private func extractFromTotalLines(_ lines: [String]) -> Double? {
        let kwLines = lines.enumerated().filter { totalLineScore($0.element) > 0 }
        guard !kwLines.isEmpty else { return nil }
        for (_, line) in kwLines.reversed() {
            if let amount = extractAmountFromLine(line) { return amount }
        }
        return nil
    }

    private func extractFromTotalNextLine(_ lines: [String]) -> Double? {
        for (index, line) in lines.enumerated() {
            guard totalLineScore(line) > 0 else { continue }
            guard extractAmountFromLine(line) == nil else { continue }
            let nextIdx = index + 1
            guard nextIdx < lines.count else { continue }
            let nextLine = lines[nextIdx]
            if lineLooksLikeChangeOrCashLine(nextLine) { continue }
            if lineLooksLikeItemCodeLine(nextLine) { continue }
            if lineLooksLikeQtyLine(nextLine) { continue }
            if lineLooksLikeIdentifierLine(nextLine) { continue }
            if lineLooksLikeDateOrTime(nextLine) { continue }
            if let amount = extractAmountFromLine(nextLine) { return amount }
        }
        return nil
    }

    private func extractLastExplicitAmount(_ lines: [String]) -> Double? {
        for line in lines.reversed() {
            if lineLooksLikeRegistrationNumber(line) { continue }
            if lineLooksLikeDateOrTime(line) { continue }
            if lineLooksLikeIdentifierLine(line) { continue }
            if lineLooksLikeQtyLine(line) { continue }
            if lineLooksLikeChangeOrCashLine(line) { continue }
            if lineLooksLikeGstOrTaxLine(line) { continue }
            if lineLooksLikeRoundingLine(line) { continue }
            if lineLooksLikeItemCodeLine(line) { continue }
            guard let amount = extractAmountFromLine(line) else { continue }
            if amount < 0.5 || amount > 10000 { continue }
            return amount
        }
        return nil
    }

    private func extractLastAnyAmount(_ lines: [String]) -> Double? {
        for line in lines.reversed() {
            if lineLooksLikeRegistrationNumber(line) { continue }
            if lineLooksLikeDateOrTime(line) { continue }
            if lineLooksLikeItemCodeLine(line) { continue }
            guard let amount = extractAmountFromLine(line) else { continue }
            if amount < 0.01 || amount > 1000000 { continue }
            return amount
        }
        return nil
    }

    private func extractAmountFromLine(_ line: String) -> Double? {
        guard let regex = Self.currencyAmountRegex else { return nil }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = regex.matches(in: line, range: nsRange)
        var values: [Double] = []
        for match in matches {
            guard let numberRange = Range(match.range(at: 2), in: line) else { continue }
            let raw = String(line[numberRange]).replacingOccurrences(of: ",", with: ".")
            guard let value = Double(raw), value > 0, value < 100_000 else { continue }
            values.append(value)
        }
        if values.count == 1 { return values[0] }
        if values.count > 1, let max = values.max(), max < 100_000 { return max }
        return nil
    }

    private func distanceToNearestTotalKeyword(at index: Int, lines: [String]) -> Int {
        var bestDist = Int.max
        for (i, line) in lines.enumerated() where totalLineScore(line) > 0 {
            let dist = abs(i - index)
            if dist < bestDist { bestDist = dist }
        }
        return bestDist
    }

    private func totalLineScore(_ line: String) -> Int {
        let score = Self.totalKeywords.filter { line.localizedCaseInsensitiveContains($0) }.count
        if line.localizedCaseInsensitiveContains("total") && !line.localizedCaseInsensitiveContains("subtotal") { return score + 2 }
        if line.localizedCaseInsensitiveContains("jumlah") { return score + 2 }
        return score
    }

    // MARK: - Line Classifiers

    private func lineLooksLikeChangeOrCashLine(_ line: String) -> Bool {
        let lowered = line.lowercased().trimmingCharacters(in: .whitespaces)
        if lowered.hasPrefix("change") || lowered.hasPrefix("cash") || lowered.hasPrefix("change due") { return true }
        if lowered == "change" || lowered == "cash" { return true }
        return false
    }

    private func lineLooksLikeGstOrTaxLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
        guard extractAmountFromLine(line) != nil else { return false }
        if lowered.contains("gst") || lowered.contains("tax") || lowered.contains("sr @") || lowered.contains("zrl") { return true }
        return false
    }

    private func lineLooksLikeRoundingLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return lowered.contains("rounding") || lowered.contains("round")
    }

    // MARK: - Merchant Extraction

    private func extractMerchant(from text: String, lines: [String]) -> (String, InterpretWarning?) {
        if let labeled = extractLabeledMerchant(from: lines) { return (labeled, nil) }

        let candidatePool = lines.count > 6
            ? Array(lines[0..<(lines.count / 2)])
            : lines

        let filtered = candidatePool.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowered = trimmed.lowercased()
            guard !lowered.isEmpty, trimmed.count >= 3 else { return false }
            guard !Self.nonMerchantBlacklist.contains(where: { lowered.hasPrefix($0) || lowered == $0 }) else { return false }
            guard !lineLooksLikeRegistrationNumber(line) else { return false }
            guard extractAmountFromLine(line) == nil else { return false }
            guard !lineLooksLikeDateOrTime(line) else { return false }
            guard !lineLooksLikeIdentifierLine(line) else { return false }
            guard !lineLooksLikeQtyLine(line) else { return false }
            guard !lineLooksLikeShortCode(line) else { return false }
            guard !lineLooksLikeProductCode(line) else { return false }
            guard !lineLooksLikeItemCodeLine(line) else { return false }
            return true
        }

        if let good = filtered.first { return (good, nil) }

        let broadFiltered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowered = trimmed.lowercased()
            guard !lowered.isEmpty, trimmed.count >= 2 else { return false }
            guard extractAmountFromLine(line) == nil else { return false }
            guard !lineLooksLikeDateOrTime(line) else { return false }
            guard !lineLooksLikeShortCode(line) else { return false }
            guard !lineLooksLikeItemCodeLine(line) else { return false }
            return true
        }

        if let best = broadFiltered.first { return (best, .merchantMissing) }

        return ("", .merchantMissing)
    }

    private func extractLabeledMerchant(from lines: [String]) -> String? {
        let labels = ["商户名称", "商户名", "商户", "收款方", "店铺", "门店", "merchant", "merchant name"]
        for (index, line) in lines.enumerated() {
            for label in labels where line.localizedCaseInsensitiveContains(label) {
                for separator in ["：", ":"] {
                    if let range = line.range(of: separator) {
                        let value = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !value.isEmpty, extractAmountFromLine(value) == nil { return value }
                    }
                }
                let nextIndex = index + 1
                if nextIndex < lines.count {
                    let value = lines[nextIndex]
                    if extractAmountFromLine(value) == nil { return value }
                }
            }
        }
        return nil
    }

    private func lineLooksLikeRegistrationNumber(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let exactPatterns = [
            #"^\d{5,10}[-\s][A-Z]$"#,
            #"^[A-Z]{2}\d{6,8}$"#,
            #"^\d{5,10}-[A-Za-z0-9]+$"#,
            #"^\(CO\.REG:[\d-]+[A-Z]?\)$"#,
            #"^（CO\.REG:[\d-]+[A-Z]?）$"#,
            #"^\(JM\d{6,}\)$"#,
            #"^（JM\d{6,}）$"#,
            #"^GST ID:?\s*\d+$"#,
            #"^GST Reg:?\s*\.?\d+$"#,
            #"^GST Reg\.?:?\s*\d+$"#,
            #"^（\d{6,10}-\w）$"#,
            #"^\(\d{6,10}-\w\)$"#,
        ]
        for pattern in exactPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if regex.firstMatch(in: trimmed, range: nsRange) != nil { return true }
            }
        }
        if trimmed.range(of: #"^(TAX REG|TAX INV)"#, options: [.caseInsensitive, .regularExpression]) != nil { return true }
        return false
    }

    private func lineLooksLikeShortCode(_ line: String) -> Bool {
        guard let regex = Self.shortCodePattern else { return false }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return regex.firstMatch(in: trimmed, range: nsRange) != nil
    }

    private func lineLooksLikeProductCode(_ line: String) -> Bool {
        guard let regex = Self.productCodePattern else { return false }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return regex.firstMatch(in: trimmed, range: nsRange) != nil
    }

    private func lineLooksLikeDateOrTime(_ line: String) -> Bool {
        let patterns = [#"\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}"#, #"\d{1,2}:\d{2}(?::\d{2})?"#, #"\d{1,2}/\d{1,2}/\d{4}"#]
        return patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            return regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil
        }
    }

    private func lineLooksLikeIdentifierLine(_ line: String) -> Bool {
        let keywords = ["订单号", "商户单号", "交易单号", "流水号", "券号", "编号", "单号", "id", "no.", "doc no",
                        "document no", "invoice no", "receipt#", "inv#", "ref no"]
        let lowered = line.lowercased()
        return keywords.contains { lowered.hasPrefix($0) || lowered.contains($0) }
    }

    private func lineLooksLikeItemCodeLine(_ line: String) -> Bool {
        if line.range(of: #"^\d{5,10}\s+-\s+"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^\d{5,10}\s{1,}"#, options: .regularExpression) != nil {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.range(of: #"^\d{5,10}\s+\D"#, options: .regularExpression) != nil { return true }
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.range(of: #"^\d{5,10}$"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"^RM\d{4,}(?:[#\s]|$)"#, options: [.caseInsensitive, .regularExpression]) != nil { return true }
        return false
    }

    private func lineLooksLikeQtyLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.range(of: #"^\d+\s*[Xx]\s*\d+"#, options: .regularExpression) != nil { return true }
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("qty") || lowered.hasPrefix("total qty") { return true }
        return false
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
