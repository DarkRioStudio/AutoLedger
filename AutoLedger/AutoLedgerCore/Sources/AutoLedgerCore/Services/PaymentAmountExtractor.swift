import Foundation

public enum AmountRole: String, Sendable {
    case actualPaid
    case total
    case subtotal
    case discount
    case deposit
    case refund
    case cash
    case change
    case tax
    case quantity
    case identifier
    case unknown
}

public struct AmountCandidate: Sendable {
    public let amount: Double
    public let role: AmountRole
    public let confidence: Double
    public let lineIndex: Int?
    public let evidence: String
    public let ruleName: String
    public let isApproximate: Bool

    public init(
        amount: Double,
        role: AmountRole,
        confidence: Double,
        lineIndex: Int?,
        evidence: String,
        ruleName: String,
        isApproximate: Bool
    ) {
        self.amount = amount
        self.role = role
        self.confidence = confidence
        self.lineIndex = lineIndex
        self.evidence = evidence
        self.ruleName = ruleName
        self.isApproximate = isApproximate
    }
}

public struct AmountExtractionResult: Sendable {
    public let paidAmount: Double?
    public let candidates: [AmountCandidate]
    public let confidence: Double
    public let selectedCandidate: AmountCandidate?
    public let debugTrace: [String]
    public let isApproximate: Bool

    public init(
        paidAmount: Double?,
        candidates: [AmountCandidate],
        confidence: Double,
        selectedCandidate: AmountCandidate?,
        debugTrace: [String],
        isApproximate: Bool
    ) {
        self.paidAmount = paidAmount
        self.candidates = candidates
        self.confidence = confidence
        self.selectedCandidate = selectedCandidate
        self.debugTrace = debugTrace
        self.isApproximate = isApproximate
    }
}

public struct PaymentAmountExtractor: Sendable {
    private let languagePack: LedgerRecognitionLanguagePack?

    private static let totalKeywords: [String] = [
        "合计", "总计", "总金额", "总额", "小计", "实付", "实收", "应付", "付款金额",
        "total", "grand total", "subtotal", "amount due", "total due", "total rounded",
        "total incl", "total inclusive", "amount", "rounded total", "total sales",
        "jumlah", "jumlah besar", "jumlah bayaran",
        "合計"
    ]

    private static let rmAmountRegex = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])RM[_\s]*([0-9]+(?:[.,][0-9]{1,2})?)(?![A-Za-z0-9])"#,
        options: [.caseInsensitive]
    )

    private static let currencyAmountRegex = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])([¥￥$€£₩])?\s*([0-9]{1,3}(?:[,.][0-9]{3})+(?:[,.][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)\s*(元|块|원|rmb|RMB|krw|KRW|[¥￥$€£₩])?(?![A-Za-z0-9./])"#,
        options: [.caseInsensitive]
    )

    public init(localeIdentifier: String? = nil, languagePackSet: LedgerRecognitionLanguagePackSet = .builtIn) {
        self.languagePack = languagePackSet.mergedPack(for: localeIdentifier)
    }

    public func extract(from rawText: String) -> AmountExtractionResult {
        let normalizedText = rawText.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalizedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return extract(from: normalizedText, lines: lines)
    }

    func extract(from text: String, lines: [String]) -> AmountExtractionResult {
        let candidates = collectCandidates(from: lines)

        if let result = extractRMAmounts(from: text, lines: lines, candidates: candidates) {
            return result
        }

        if let candidate = extractFromTotalLines(lines, candidates: candidates) {
            return result(selecting: candidate, candidates: candidates, debug: "total_line")
        }

        if let candidate = extractFromTotalNextLine(lines, candidates: candidates) {
            return result(selecting: candidate, candidates: candidates, debug: "total_next_line")
        }

        if let candidate = extractLastExplicitAmount(lines, candidates: candidates) {
            return result(selecting: candidate, candidates: candidates, debug: "last_explicit")
        }

        if let candidate = extractLastAnyAmount(lines, candidates: candidates) {
            return result(selecting: candidate, candidates: candidates, debug: "last_fallback", approximate: true)
        }

        return AmountExtractionResult(
            paidAmount: nil,
            candidates: candidates,
            confidence: 0,
            selectedCandidate: nil,
            debugTrace: ["amount_source=none"],
            isApproximate: false
        )
    }

    private func result(
        selecting candidate: AmountCandidate,
        candidates: [AmountCandidate],
        debug: String,
        approximate: Bool? = nil
    ) -> AmountExtractionResult {
        let isApproximate = approximate ?? candidate.isApproximate
        return AmountExtractionResult(
            paidAmount: candidate.amount,
            candidates: candidates,
            confidence: candidate.confidence,
            selectedCandidate: candidate,
            debugTrace: ["amount_source=\(debug)"],
            isApproximate: isApproximate
        )
    }

    private func collectCandidates(from lines: [String]) -> [AmountCandidate] {
        lines.enumerated().flatMap { index, line in
            extractAmounts(from: line, lineIndex: index).map { amount in
                let role = role(for: line)
                return AmountCandidate(
                    amount: amount,
                    role: role,
                    confidence: confidence(for: role, line: line),
                    lineIndex: index,
                    evidence: line,
                    ruleName: "line_amount",
                    isApproximate: role == .unknown
                )
            }
        }
    }

    private func extractRMAmounts(from text: String, lines: [String], candidates: [AmountCandidate]) -> AmountExtractionResult? {
        guard let regex = Self.rmAmountRegex else { return nil }
        var rmCandidates: [AmountCandidate] = []

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
                let role = role(for: line)
                rmCandidates.append(
                    AmountCandidate(
                        amount: value,
                        role: role,
                        confidence: confidence(for: role, line: line),
                        lineIndex: index,
                        evidence: line,
                        ruleName: "rm_amount",
                        isApproximate: false
                    )
                )
            }
        }

        guard !rmCandidates.isEmpty else { return nil }

        let totalKeywordCandidates = rmCandidates.filter { totalLineScore($0.evidence) > 0 }
        if totalKeywordCandidates.isEmpty {
            let nearTotal = rmCandidates.filter { candidate in
                guard let index = candidate.lineIndex else { return false }
                return distanceToNearestTotalKeyword(at: index, lines: lines) <= 2
            }
            if let bestNear = (nearTotal.isEmpty ? rmCandidates : nearTotal).max(by: { $0.amount < $1.amount }) {
                return result(selecting: bestNear, candidates: candidates + rmCandidates, debug: "rm_near_total")
            }
            if let best = rmCandidates.sorted(by: { ($0.lineIndex ?? 0) > ($1.lineIndex ?? 0) }).first {
                return result(selecting: best, candidates: candidates + rmCandidates, debug: "rm_last")
            }
        }

        let best = totalKeywordCandidates
            .sorted { a, b in
                let aScore = totalLineScore(a.evidence)
                let bScore = totalLineScore(b.evidence)
                if aScore != bScore { return aScore > bScore }
                return (a.lineIndex ?? 0) > (b.lineIndex ?? 0)
            }.first!
        return result(selecting: best, candidates: candidates + rmCandidates, debug: "rm_total_line")
    }

    private func extractFromTotalLines(_ lines: [String], candidates: [AmountCandidate]) -> AmountCandidate? {
        let kwLines = lines.enumerated().filter { totalLineScore($0.element) > 0 }
        guard !kwLines.isEmpty else { return nil }
        for (index, line) in kwLines.reversed() {
            if let amount = extractAmountFromLine(line) {
                return candidate(amount: amount, role: role(for: line), lineIndex: index, evidence: line, ruleName: "total_line")
            }
        }
        return nil
    }

    private func extractFromTotalNextLine(_ lines: [String], candidates: [AmountCandidate]) -> AmountCandidate? {
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
            if let amount = extractAmountFromLine(nextLine) {
                return candidate(amount: amount, role: .total, lineIndex: nextIdx, evidence: nextLine, ruleName: "total_next_line")
            }
        }
        return nil
    }

    private func extractLastExplicitAmount(_ lines: [String], candidates: [AmountCandidate]) -> AmountCandidate? {
        for (index, line) in lines.enumerated().reversed() {
            if lineLooksLikeRegistrationNumber(line) { continue }
            if lineLooksLikeDateOrTime(line) { continue }
            if lineLooksLikeIdentifierLine(line) { continue }
            if lineLooksLikeQtyLine(line) { continue }
            if lineLooksLikeChangeOrCashLine(line) { continue }
            if lineLooksLikeGstOrTaxLine(line) { continue }
            if lineLooksLikeRoundingLine(line) { continue }
            if lineLooksLikeItemCodeLine(line) { continue }
            guard let amount = extractAmountFromLine(line) else { continue }
            if amount < 0.5 || amount > 10_000 { continue }
            let role = role(for: line)
            if shouldSkipAsPaidFallback(role) { continue }
            return candidate(amount: amount, role: role, lineIndex: index, evidence: line, ruleName: "last_explicit")
        }
        return nil
    }

    private func extractLastAnyAmount(_ lines: [String], candidates: [AmountCandidate]) -> AmountCandidate? {
        for (index, line) in lines.enumerated().reversed() {
            if lineLooksLikeRegistrationNumber(line) { continue }
            if lineLooksLikeDateOrTime(line) { continue }
            if lineLooksLikeItemCodeLine(line) { continue }
            guard let amount = extractAmountFromLine(line) else { continue }
            if amount < 0.01 || amount > 1_000_000 { continue }
            let role = role(for: line)
            if shouldSkipAsPaidFallback(role) { continue }
            return AmountCandidate(
                amount: amount,
                role: role,
                confidence: 0.55,
                lineIndex: index,
                evidence: line,
                ruleName: "last_fallback",
                isApproximate: true
            )
        }
        return nil
    }

    private func candidate(
        amount: Double,
        role: AmountRole,
        lineIndex: Int,
        evidence: String,
        ruleName: String
    ) -> AmountCandidate {
        AmountCandidate(
            amount: amount,
            role: role,
            confidence: confidence(for: role, line: evidence),
            lineIndex: lineIndex,
            evidence: evidence,
            ruleName: ruleName,
            isApproximate: role == .unknown
        )
    }

    private func extractAmountFromLine(_ line: String) -> Double? {
        let values = extractAmounts(from: line, lineIndex: nil)
        if values.count == 1 { return values[0] }
        if values.count > 1, let max = values.max(), max < 100_000 { return max }
        return nil
    }

    private func extractAmounts(from line: String, lineIndex: Int?) -> [Double] {
        guard let regex = Self.currencyAmountRegex else { return [] }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = regex.matches(in: line, range: nsRange)
        var values: [Double] = []
        for match in matches {
            guard let numberRange = Range(match.range(at: 2), in: line) else { continue }
            let raw = normalizeAmountLiteral(String(line[numberRange]))
            guard let value = Double(raw), value > 0, value < 100_000 else { continue }
            values.append(value)
        }
        return values
    }

    private func role(for line: String) -> AmountRole {
        let lowered = line.lowercased()
        if lineLooksLikeIdentifierLine(line) { return .identifier }
        if lineLooksLikeQtyLine(line) { return .quantity }
        if lowered.contains("change") { return .change }
        if containsAny(changeKeywords, in: line) { return .change }
        if lowered.hasPrefix("cash") || lowered.contains("cash tendered") { return .cash }
        if containsAny(discountKeywords, in: line) { return .discount }
        if containsAny(depositKeywords, in: line) { return .deposit }
        if lowered.contains("refund") || lowered.contains("退款") || lowered.contains("退货") || containsAny(refundKeywords, in: line) { return .refund }
        if containsAny(taxKeywords, in: line) { return .tax }
        if containsAny(subtotalKeywords, in: line) { return .subtotal }
        if totalLineScore(line) > 0 { return .total }
        if containsAny(actualPaidKeywords, in: line) { return .actualPaid }
        return .unknown
    }

    private func confidence(for role: AmountRole, line: String) -> Double {
        switch role {
        case .actualPaid: return 0.96
        case .total: return 0.94
        case .subtotal: return 0.82
        case .unknown: return totalLineScore(line) > 0 ? 0.9 : 0.65
        case .cash, .change, .discount, .deposit, .refund, .tax, .quantity, .identifier:
            return 0.35
        }
    }

    private func shouldSkipAsPaidFallback(_ role: AmountRole) -> Bool {
        switch role {
        case .cash, .change, .discount, .deposit, .refund, .tax, .quantity, .identifier:
            return true
        case .actualPaid, .total, .subtotal, .unknown:
            return false
        }
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
        if containsAny(subtotalKeywords, in: line) { return 0 }
        let score = allTotalKeywords.filter { line.localizedCaseInsensitiveContains($0) }.count
        if line.localizedCaseInsensitiveContains("total") && !line.localizedCaseInsensitiveContains("subtotal") { return score + 2 }
        if line.localizedCaseInsensitiveContains("jumlah") { return score + 2 }
        return score
    }

    private var allTotalKeywords: [String] {
        Self.totalKeywords + (languagePack?.amountLabelSet.total ?? languagePack?.totalLabels ?? [])
    }

    private var actualPaidKeywords: [String] {
        Self.actualPaidKeywords + (languagePack?.amountLabels ?? []) + (languagePack?.amountLabelSet.actualPaid ?? [])
    }

    private var discountKeywords: [String] {
        Self.discountKeywords + (languagePack?.discountLabels ?? []) + (languagePack?.amountLabelSet.discount ?? [])
    }

    private var taxKeywords: [String] {
        Self.taxKeywords + (languagePack?.taxLabels ?? []) + (languagePack?.amountLabelSet.tax ?? []) + (languagePack?.amountLabelSet.serviceCharge ?? [])
    }

    private var subtotalKeywords: [String] {
        let packSubtotals = languagePack?.totalLabels.filter { label in
            label.localizedCaseInsensitiveContains("小计")
                || label.localizedCaseInsensitiveContains("小計")
                || label.localizedCaseInsensitiveContains("subtotal")
        } ?? []
        return Self.subtotalKeywords + packSubtotals + (languagePack?.amountLabelSet.subtotal ?? [])
    }

    private var depositKeywords: [String] {
        Self.depositKeywords + (languagePack?.amountLabelSet.deposit ?? [])
    }

    private var refundKeywords: [String] {
        Self.refundKeywords + (languagePack?.amountLabelSet.refund ?? [])
    }

    private var changeKeywords: [String] {
        Self.changeKeywords + (languagePack?.amountLabelSet.change ?? [])
    }

    private static let actualPaidKeywords = ["实付", "金额", "付款金额", "支付金额"]
    private static let discountKeywords = ["discount", "优惠", "折扣"]
    private static let taxKeywords = ["gst", "tax", "税"]
    private static let subtotalKeywords = ["subtotal", "sub total", "小计"]
    private static let depositKeywords = ["deposit", "押金"]
    private static let refundKeywords = ["refund", "退款", "退货"]
    private static let changeKeywords = ["change", "change due", "找零"]

    private func containsAny(_ keywords: [String], in line: String) -> Bool {
        keywords.contains { line.localizedCaseInsensitiveContains($0) }
    }

    private func normalizeAmountLiteral(_ raw: String) -> String {
        let amountFormat = languagePack?.amountFormat ?? .generic
        if let groupingSeparator = amountFormat.groupingSeparator,
           isGroupedAmount(raw, groupingSeparator: groupingSeparator, decimalSeparator: amountFormat.decimalSeparator) {
            return raw
                .replacingOccurrences(of: groupingSeparator, with: "")
                .replacingOccurrences(of: amountFormat.decimalSeparator, with: ".")
        }
        if amountFormat.decimalSeparator != ".", raw.contains(amountFormat.decimalSeparator) {
            return raw.replacingOccurrences(of: amountFormat.decimalSeparator, with: ".")
        }
        if raw.range(of: #"^\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?$"#, options: .regularExpression) != nil {
            return raw.replacingOccurrences(of: ",", with: "")
        }
        return raw.replacingOccurrences(of: ",", with: ".")
    }

    private func isGroupedAmount(_ raw: String, groupingSeparator: String, decimalSeparator: String) -> Bool {
        let grouping = NSRegularExpression.escapedPattern(for: groupingSeparator)
        let decimal = NSRegularExpression.escapedPattern(for: decimalSeparator)
        let pattern = #"^\d{1,3}(?:"# + grouping + #"\d{3})+(?:"# + decimal + #"\d{1,2})?$"#
        return raw.range(of: pattern, options: .regularExpression) != nil
    }

    private func lineLooksLikeChangeOrCashLine(_ line: String) -> Bool {
        let lowered = line.lowercased().trimmingCharacters(in: .whitespaces)
        if lowered.hasPrefix("change") || lowered.hasPrefix("cash") || lowered.hasPrefix("change due") { return true }
        if lowered == "change" || lowered == "cash" { return true }
        if containsAny(changeKeywords, in: line) { return true }
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
}
