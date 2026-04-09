import Foundation

struct ReceiptParser: Sendable {
    func parse(text: String, source: ReceiptSource, fallbackMerchant: String? = nil) -> ImportedReceipt? {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let amount = extractAmount(from: normalized) else {
            return nil
        }

        let cleanedLines = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let wechatDetail = parseWeChatDetailBlock(lines: cleanedLines)

        let merchant = wechatDetail?.merchant
            ?? extractMerchant(from: normalized, source: source)
            ?? fallbackMerchant
            ?? "待确认商户"
        let date = wechatDetail?.date
            ?? extractDate(from: normalized)
            ?? .now
        let category = TransactionCategory.infer(from: "\(merchant)\n\(normalized)")

        return ImportedReceipt(
            source: source,
            merchant: merchant,
            amount: amount,
            occurredAt: date,
            rawText: normalized,
            summary: "\(source.title) OCR 解析草稿",
            confidence: wechatDetail != nil ? 0.90 : 0.82,
            suggestedCategory: category
        )
    }

    private func extractAmount(from text: String) -> Double? {
        let lines = text.components(separatedBy: .newlines)

        // 微信支付格式优先：独立行 "-XX.XX" 就是实际支付金额
        let wechatNegPattern = #"^\s*-([0-9]+(?:\.[0-9]{1,2})?)\s*$"#
        if let negRegex = try? NSRegularExpression(pattern: wechatNegPattern) {
            for line in lines {
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = negRegex.firstMatch(in: line, range: nsRange),
                   let range = Range(match.range(at: 1), in: line),
                   let amount = Double(String(line[range])),
                   amount > 0 {
                    return amount
                }
            }
        }

        // 带 ¥/￥ 前缀的行优先
        let currencyPrefixPattern = #"[¥￥]\s*([0-9]+(?:\.[0-9]{1,2})?)"#

        // 实付/实际支付行最优先（外卖、电商常有优惠前金额干扰）
        let actualPayKeywords = ["实付", "实际支付", "实际付款", "合计支付"]
        if let cpRegex = try? NSRegularExpression(pattern: currencyPrefixPattern) {
            for line in lines where actualPayKeywords.contains(where: { line.contains($0) }) {
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = cpRegex.firstMatch(in: line, range: nsRange),
                   let range = Range(match.range(at: 1), in: line),
                   let amount = Double(String(line[range])),
                   amount > 0 && amount < 100000 {
                    return amount
                }
            }
        }

        // 普通 ¥ 前缀行
        if let cpRegex = try? NSRegularExpression(pattern: currencyPrefixPattern) {
            for line in lines {
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = cpRegex.firstMatch(in: line, range: nsRange),
                   let range = Range(match.range(at: 1), in: line),
                   let amount = Double(String(line[range])),
                   amount > 0 && amount < 100000 {
                    return amount
                }
            }
        }

        // 关键词行回退
        let keywords = ["金额", "支付", "总计", "总额", "实际支付", "Price", "Total", "CNY", "RMB"]
        let prioritizedLines = lines.filter {
            let line = $0.lowercased()
            return keywords.contains { line.contains($0.lowercased()) }
        }

        for line in prioritizedLines where !line.isEmpty {
            if let amount = amountCandidate(in: line) {
                return amount
            }
        }

        // 全文兜底
        for line in lines {
            if let amount = amountCandidate(in: line) {
                return amount
            }
        }

        return nil
    }

    private func amountCandidate(in line: String) -> Double? {
        // 跳过疑似状态栏时间/信号格式，如 "10:131" 或 "9:41"
        let timeOnlyPattern = #"^\s*\d{1,2}:\d{2,3}\s*$"#
        if (try? NSRegularExpression(pattern: timeOnlyPattern))?
            .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil {
            return nil
        }

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

        // 这些是微信支付等平台的字段标签名，不是商户名
        let fieldLabels: Set<String> = [
            "商户全称", "收单机构", "支付方式", "交易单号", "商户单号",
            "当前状态", "支付时间", "商品", "备注", "附言"
        ]

        let merchantPrefixes = ["收款方", "商户", "Merchant", "项目", "商品"]
        for line in lines {
            for prefix in merchantPrefixes where line.contains(prefix) {
                let parts = line.components(separatedBy: CharacterSet(charactersIn: ":："))
                if let candidate = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !candidate.isEmpty,
                   candidate != prefix,
                   !fieldLabels.contains(candidate) {
                    return candidate
                }
            }
        }

        if source == .appStore {
            // Apple 收据：找 "（自动续期）" 或 "（每年/每月）" 等订阅行
            if let subLine = lines.first(where: {
                $0.contains("自动续期") || $0.contains("每年") || $0.contains("每月")
                || $0.contains("Subscription") || $0.contains("subscription")
            }) {
                return subLine
            }
            // 回退：找 "App Store" 后面的应用行（跳过 App Store 自身和文稿编号等）
            let skipKeywords: Set<String> = ["app store", "文稿编号", "订单号", "apple", "apple 账户", "收据", "详情"]
            if let appLine = lines.first(where: {
                !skipKeywords.contains($0.lowercased().trimmingCharacters(in: .whitespaces))
                && !$0.contains("@") && !$0.contains("支付") && !$0.contains("如需")
                && !$0.contains("了解") && !$0.contains("Copyright")
                && $0.lowercased().contains("apple")
            }) {
                return appLine
            }
        }

        // 外卖平台："闪购 XXX店" / "外卖 XXX店" 格式
        let deliveryPrefixes = ["闪购", "外卖"]
        for line in lines {
            for prefix in deliveryPrefixes where line.hasPrefix(prefix) {
                let candidate = line
                    .replacingOccurrences(of: prefix, with: "")
                    .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "＞>》")))
                if !candidate.isEmpty {
                    return candidate
                }
            }
        }

        // 微信支付格式回退：负数金额行（如 -36.90）的下一行通常是商品/商户名
        let wechatNegativeAmountPattern = #"^-[0-9]+(?:\.[0-9]{1,2})?$"#
        if let negLineIdx = lines.indices.first(where: { i in
            let line = lines[i]
            return (try? NSRegularExpression(pattern: wechatNegativeAmountPattern))?
                .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil
        }), negLineIdx + 1 < lines.count {
            let candidate = lines[negLineIdx + 1]
            if !candidate.isEmpty && !fieldLabels.contains(candidate) && amountCandidate(in: candidate) == nil {
                return candidate
            }
        }

        // 跳过纯时间、纯数字、极短行
        let timePattern = #"^\s*\d{1,2}:\d{2,3}\s*$"#
        let pureNumberPattern = #"^\s*\d{1,5}\s*$"#
        return lines.first(where: { line in
            !line.contains("成功") &&
            !line.contains("金额") &&
            !line.contains("时间") &&
            !line.contains("Total") &&
            line.count >= 2 &&
            amountCandidate(in: line) == nil &&
            (try? NSRegularExpression(pattern: timePattern))?
                .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) == nil &&
            (try? NSRegularExpression(pattern: pureNumberPattern))?
                .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) == nil
        })
    }

    private func extractDate(from text: String) -> Date? {
        let lines = text.components(separatedBy: .newlines)
        let patterns = [
            #"(20[0-9]{2}[年/-][0-9]{1,2}[月/-][0-9]{1,2}[日]?\s+[0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?)"#,
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

    private func parseWeChatDetailBlock(lines: [String]) -> (merchant: String?, date: Date?)? {
        guard lines.contains(where: { $0.contains("交易详情") }) else { return nil }

        let knownLabels: Set<String> = [
            "当前状态", "支付时间", "商品", "商户全称", "收单机构",
            "支付方式", "交易单号", "商户单号", "备注"
        ]

        var bestRun: [(index: Int, label: String)] = []
        var currentRun: [(index: Int, label: String)] = []

        for (i, line) in lines.enumerated() {
            if knownLabels.contains(line) {
                currentRun.append((i, line))
            } else {
                if currentRun.count > bestRun.count { bestRun = currentRun }
                currentRun = []
            }
        }
        if currentRun.count > bestRun.count { bestRun = currentRun }

        guard bestRun.count >= 3, let lastLabelIdx = bestRun.last?.index else { return nil }

        let valueStart = lastLabelIdx + 1
        var merchant: String?
        var date: Date?

        for (offset, item) in bestRun.enumerated() {
            let valueIdx = valueStart + offset
            guard valueIdx < lines.count else { break }
            let value = lines[valueIdx]

            if item.label == "商户全称" && !value.isEmpty {
                merchant = value
            }
            if item.label == "支付时间" && !value.isEmpty {
                date = AppFormatters.parseFlexibleDate(value)
            }
        }

        return (merchant, date)
    }
}
