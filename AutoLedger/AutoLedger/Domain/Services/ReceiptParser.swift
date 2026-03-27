import Foundation

struct ReceiptParser {
    func parse(text: String, source: ReceiptSource, fallbackMerchant: String? = nil) -> ImportedReceipt? {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let amount = extractAmount(from: normalized) else {
            return nil
        }

        let merchant = extractMerchant(from: normalized, source: source) ?? fallbackMerchant ?? "待确认商户"
        let date = extractDate(from: normalized) ?? .now
        let category = TransactionCategory.infer(from: "\(merchant)\n\(normalized)")

        return ImportedReceipt(
            source: source,
            merchant: merchant,
            amount: amount,
            occurredAt: date,
            rawText: normalized,
            summary: "\(source.title) OCR 解析草稿",
            confidence: 0.82,
            suggestedCategory: category
        )
    }

    private func extractAmount(from text: String) -> Double? {
        let keywords = ["金额", "支付", "总计", "总额", "实际支付", "Price", "Total", "CNY", "RMB", "¥", "￥"]
        let prioritizedLines = text
            .components(separatedBy: .newlines)
            .filter {
                let line = $0.lowercased()
                return keywords.contains { line.contains($0.lowercased()) }
            }

        for line in prioritizedLines where !line.isEmpty {
            if let amount = amountCandidate(in: line) {
                return amount
            }
        }

        for line in text.components(separatedBy: .newlines) {
            if let amount = amountCandidate(in: line) {
                return amount
            }
        }

        return nil
    }

    private func amountCandidate(in line: String) -> Double? {
        let pattern = #"(?:(?:¥|￥|RMB|CNY)\s*)?([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = regex.matches(in: line, range: nsRange)

        let candidates = matches.compactMap { match -> Double? in
            guard let range = Range(match.range(at: 1), in: line) else {
                return nil
            }
            return Double(String(line[range]))
        }

        return candidates
            .filter { $0 < 100000 }
            .sorted(by: >)
            .first
    }

    private func extractMerchant(from text: String, source: ReceiptSource) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let merchantPrefixes = ["收款方", "商户", "Merchant", "项目", "商品"]
        for line in lines {
            for prefix in merchantPrefixes where line.contains(prefix) {
                let parts = line.components(separatedBy: CharacterSet(charactersIn: ":："))
                if let candidate = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines), !candidate.isEmpty, candidate != prefix {
                    return candidate
                }
            }
        }

        if source == .appStore, let appStoreLine = lines.first(where: { $0.lowercased().contains("apple") }) {
            return appStoreLine
        }

        return lines.first(where: { line in
            !line.contains("成功") &&
            !line.contains("金额") &&
            !line.contains("时间") &&
            !line.contains("Total") &&
            amountCandidate(in: line) == nil
        })
    }

    private func extractDate(from text: String) -> Date? {
        let lines = text.components(separatedBy: .newlines)
        let patterns = [
            #"(20[0-9]{2}[年/-][0-9]{1,2}[月/-][0-9]{1,2}[日]?\s+[0-9]{1,2}:[0-9]{2})"#,
            #"(20[0-9]{2}[年/-][0-9]{1,2}[月/-][0-9]{1,2}[日]?)"#
        ]

        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else {
                    continue
                }
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                guard let match = regex.firstMatch(in: line, range: nsRange),
                      let range = Range(match.range(at: 1), in: line) else {
                    continue
                }

                if let date = AppFormatters.parseFlexibleDate(String(line[range])) {
                    return date
                }
            }
        }

        return nil
    }
}
