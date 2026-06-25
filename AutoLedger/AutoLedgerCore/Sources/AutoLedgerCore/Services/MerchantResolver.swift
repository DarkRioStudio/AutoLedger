import Foundation

public enum MerchantCandidateSource: String, Sendable {
    case labeled
    case rule
    case alias
    case external
}

public struct MerchantCandidate: Sendable {
    public let name: String
    public let source: MerchantCandidateSource
    public let confidence: Double
    public let lineIndex: Int?
    public let evidence: String
    public let ruleName: String

    public init(
        name: String,
        source: MerchantCandidateSource,
        confidence: Double,
        lineIndex: Int?,
        evidence: String,
        ruleName: String
    ) {
        self.name = name
        self.source = source
        self.confidence = confidence
        self.lineIndex = lineIndex
        self.evidence = evidence
        self.ruleName = ruleName
    }
}

public struct MerchantResolutionResult: Sendable {
    public let merchant: String
    public let candidates: [MerchantCandidate]
    public let selectedCandidate: MerchantCandidate?
    public let confidence: Double
    public let debugTrace: [String]

    public init(
        merchant: String,
        candidates: [MerchantCandidate],
        selectedCandidate: MerchantCandidate?,
        confidence: Double,
        debugTrace: [String]
    ) {
        self.merchant = merchant
        self.candidates = candidates
        self.selectedCandidate = selectedCandidate
        self.confidence = confidence
        self.debugTrace = debugTrace
    }
}

public struct MerchantNormalizer: Sendable {
    public init() {}

    public func normalize(_ value: String, labels: [String] = []) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let labelPrefixes = labels.flatMap { ["\($0)：", "\($0):"] }
        for prefix in ["商户名称：", "商户名称:", "商户名：", "商户名:", "商户：", "商户:", "收款方：", "收款方:",
                       "店铺：", "店铺:", "门店：", "门店:", "商品说明：", "商品说明:",
                       "merchant name:", "merchant:", "store:"] + labelPrefixes {
            if normalized.lowercased().hasPrefix(prefix.lowercased()) {
                normalized = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        normalized = normalized.replacingOccurrences(of: #"[\s　]+"#, with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "外卖订单", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized
    }
}

public struct RuleMerchantExtractor: Sendable {
    private let normalizer = MerchantNormalizer()
    private let languagePack: LedgerRecognitionLanguagePack?

    private static let labels = ["商户名称", "商户名", "商户", "收款方", "店铺", "门店", "商品说明", "merchant", "merchant name", "store"]
    private static let blacklistPrefixes = [
        "微信支付", "支付宝", "云闪付", "银联", "apple pay", "wechat pay", "alipay", "unionpay",
        "支付成功", "交易成功", "付款成功", "收款成功", "支付详情", "账单详情",
        "回首页", "付款方式",
        "tax invoice", "simplified tax invoice", "invoice", "receipt", "cash bill", "cash sale",
        "thank you", "please come again", "goods sold", "gst summary",
        "change", "change due", "cash", "cash tendered",
        "total", "grand total", "subtotal", "sub total", "total sales", "amount due",
        "rounding adjustment", "rounding", "document no", "doc no", "invoice no",
        "member", "cashier", "salesperson", "date", "time", "ref", "qty", "item",
        "description", "price", "amount", "discount"
    ]
    private static let identifierKeywords = [
        "订单号", "商户单号", "交易单号", "流水号", "券号", "编号", "单号", "id", "no.", "doc no",
        "document no", "invoice no", "receipt#", "inv#", "ref no"
    ]

    private static let shortCodePattern = try? NSRegularExpression(pattern: #"^[A-Za-z0-9]{2,8}$"#)
    private static let productCodePattern = try? NSRegularExpression(pattern: #"^[A-Za-z][A-Za-z0-9]{1,5}:\d+[A-Za-z]?$"#)
    private static let amountRegex = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])([¥￥$€£])?\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)\s*(元|块|rmb|RMB|RM)?(?![A-Za-z0-9./])"#,
        options: [.caseInsensitive]
    )

    public init(localeIdentifier: String? = nil, languagePackSet: LedgerRecognitionLanguagePackSet = .builtIn) {
        self.languagePack = languagePackSet.mergedPack(for: localeIdentifier)
    }

    public func extractCandidates(from rawText: String) -> [MerchantCandidate] {
        let lines = rawText.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var candidates: [MerchantCandidate] = []
        candidates.append(contentsOf: labeledCandidates(from: lines))
        candidates.append(contentsOf: lineCandidates(from: lines))

        var seen = Set<String>()
        return candidates.filter { candidate in
            let key = candidate.name.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private func labeledCandidates(from lines: [String]) -> [MerchantCandidate] {
        var candidates: [MerchantCandidate] = []
        for (index, line) in lines.enumerated() {
            for label in merchantLabelKeywords where line.localizedCaseInsensitiveContains(label) {
                for separator in ["：", ":"] {
                    if let range = line.range(of: separator) {
                        let value = normalizer.normalize(
                            String(line[range.upperBound...]),
                            labels: merchantLabelKeywords
                        )
                        if isUsableMerchantLine(value) {
                            candidates.append(MerchantCandidate(
                                name: value,
                                source: .labeled,
                                confidence: 0.97,
                                lineIndex: index,
                                evidence: line,
                                ruleName: "labeled_inline"
                            ))
                        }
                    }
                }

                let nextIndex = index + 1
                if nextIndex < lines.count {
                    let value = normalizer.normalize(lines[nextIndex], labels: merchantLabelKeywords)
                    if isUsableMerchantLine(value) {
                        candidates.append(MerchantCandidate(
                            name: value,
                            source: .labeled,
                            confidence: 0.93,
                            lineIndex: nextIndex,
                            evidence: "\(line) -> \(lines[nextIndex])",
                            ruleName: "labeled_next_line"
                        ))
                    }
                }
            }
        }
        return candidates
    }

    private func lineCandidates(from lines: [String]) -> [MerchantCandidate] {
        lines.enumerated().compactMap { index, line in
            let value = normalizer.normalize(line, labels: merchantLabelKeywords)
            guard isUsableMerchantLine(value) else { return nil }
            return MerchantCandidate(
                name: value,
                source: .rule,
                confidence: score(line: value, index: index, lines: lines),
                lineIndex: index,
                evidence: line,
                ruleName: "line_candidate"
            )
        }
    }

    private func score(line: String, index: Int, lines: [String]) -> Double {
        let lowered = line.lowercased()
        var score = 0.60

        if lowered.contains("sdn bhd") || lowered.contains("enterprise") || lowered.contains("market") ||
            lowered.contains("coffee") || lowered.contains("cafe") || lowered.contains("store") {
            score += 0.20
        }
        if looksLikeStoreName(line) { score += 0.22 }

        if line.range(of: #"[A-Z]{3,}"#, options: .regularExpression) != nil { score += 0.08 }
        if distanceToLabel(from: index, lines: lines) <= 1 { score += 0.14 }
        if lineLooksLikeCampaignOrReward(line) { score -= 0.45 }
        if looksLikeAddress(line) { score -= 0.25 }

        let positionPenalty = min(Double(index) * 0.015, 0.20)
        return min(max(score - positionPenalty, 0.10), 0.90)
    }

    private func distanceToLabel(from index: Int, lines: [String]) -> Int {
        var best = Int.max
        for (lineIndex, line) in lines.enumerated() {
            guard merchantLabelKeywords.contains(where: { line.localizedCaseInsensitiveContains($0) }) else { continue }
            best = min(best, abs(lineIndex - index))
        }
        return best
    }

    private func isUsableMerchantLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        guard trimmed.count >= 3 else { return false }
        guard !blacklistPrefixes.contains(where: { lowered.hasPrefix($0.lowercased()) || lowered == $0.lowercased() }) else { return false }
        guard !lineLooksLikeCampaignOrReward(trimmed) else { return false }
        guard !lineLooksLikeRegistrationNumber(trimmed) else { return false }
        guard !lineContainsAmount(trimmed) else { return false }
        guard !lineLooksLikeDateOrTime(trimmed) else { return false }
        guard !lineLooksLikeIdentifierLine(trimmed) else { return false }
        guard !lineLooksLikeQtyLine(trimmed) else { return false }
        guard !lineLooksLikeShortCode(trimmed) else { return false }
        guard !lineLooksLikeProductCode(trimmed) else { return false }
        guard !lineLooksLikeItemCodeLine(trimmed) else { return false }
        return true
    }

    private func lineContainsAmount(_ line: String) -> Bool {
        guard let regex = Self.amountRegex else { return false }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.firstMatch(in: line, range: range) != nil
    }

    private func lineLooksLikeShortCode(_ line: String) -> Bool {
        guard let regex = Self.shortCodePattern else { return false }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.firstMatch(in: line, range: range) != nil
    }

    private func lineLooksLikeProductCode(_ line: String) -> Bool {
        guard let regex = Self.productCodePattern else { return false }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.firstMatch(in: line, range: range) != nil
    }

    private func lineLooksLikeRegistrationNumber(_ line: String) -> Bool {
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
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                if regex.firstMatch(in: line, range: range) != nil { return true }
            }
        }
        if line.range(of: #"^(TAX REG|TAX INV)"#, options: [.caseInsensitive, .regularExpression]) != nil { return true }
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
        let lowered = line.lowercased()
        return identifierKeywords.contains {
            let keyword = $0.lowercased()
            return lowered.hasPrefix(keyword) || lowered.contains(keyword)
        }
    }

    private func lineLooksLikeItemCodeLine(_ line: String) -> Bool {
        if line.range(of: #"^\d{5,10}\s+-\s+"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^\d{5,10}\s{1,}"#, options: .regularExpression) != nil {
            if line.range(of: #"^\d{5,10}\s+\D"#, options: .regularExpression) != nil { return true }
        }
        if line.range(of: #"^\d{5,10}$"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^RM\d{4,}(?:[#\s]|$)"#, options: [.caseInsensitive, .regularExpression]) != nil { return true }
        return false
    }

    private func lineLooksLikeQtyLine(_ line: String) -> Bool {
        if line.range(of: #"^\d+\s*[Xx]\s*\d+"#, options: .regularExpression) != nil { return true }
        let lowered = line.lowercased()
        if lowered.hasPrefix("qty") || lowered.hasPrefix("total qty") { return true }
        return false
    }

    private func lineLooksLikeCampaignOrReward(_ line: String) -> Bool {
        let keywords = [
            "立减", "优惠", "红包", "折扣", "满减", "返现", "券后", "优惠券", "代金券",
            "待领取", "立即领取", "去领取", "森林能量", "葵花籽", "限量发放", "限时享",
            "当前有", "点餐红包", "特价", "指定商品"
        ]
        return keywords.contains { line.contains($0) }
    }

    private func looksLikeStoreName(_ line: String) -> Bool {
        let keywords = [
            "便利", "便利店", "超市", "商店", "门店", "店", "分店", "餐厅", "咖啡",
            "饭店", "药房", "药店", "生活馆", "生鲜", "市场", "market", "store",
            "mart", "restaurant", "cafe", "coffee"
        ]
        return keywords.contains { line.localizedCaseInsensitiveContains($0) } ||
            (line.contains("（") && line.contains("）")) ||
            (line.contains("(") && line.contains(")"))
    }

    private func looksLikeAddress(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return lowered.hasPrefix("no.") || lowered.contains(" jalan ") || lowered.hasPrefix("jalan ") ||
            lowered.contains(" road") || lowered.contains(" lot ") || lowered.hasPrefix("lot ")
    }

    private var merchantLabelKeywords: [String] {
        Self.labels + (languagePack?.merchantLabels ?? [])
    }

    private var blacklistPrefixes: [String] {
        Self.blacklistPrefixes + (languagePack?.nonMerchantKeywords ?? [])
    }

    private var identifierKeywords: [String] {
        Self.identifierKeywords + (languagePack?.nonMerchantKeywords ?? [])
    }
}

public struct MerchantResolver: Sendable {
    public init() {}

    public func resolve(candidates: [MerchantCandidate], text: String) -> MerchantResolutionResult {
        guard let selected = candidates.sorted(by: { lhs, rhs in
            if abs(lhs.confidence - rhs.confidence) > 0.001 { return lhs.confidence > rhs.confidence }
            return (lhs.lineIndex ?? Int.max) < (rhs.lineIndex ?? Int.max)
        }).first else {
            return MerchantResolutionResult(
                merchant: "",
                candidates: candidates,
                selectedCandidate: nil,
                confidence: 0,
                debugTrace: ["merchant_source=none"]
            )
        }

        return MerchantResolutionResult(
            merchant: selected.name,
            candidates: candidates,
            selectedCandidate: selected,
            confidence: selected.confidence,
            debugTrace: ["merchant_source=\(selected.ruleName)", "merchant_confidence=\(String(format: "%.2f", selected.confidence))"]
        )
    }
}
