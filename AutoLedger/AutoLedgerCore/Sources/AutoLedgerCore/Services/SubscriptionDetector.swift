import Foundation

/// 从 OCR 文本或历史账单中检测订阅。
///
/// - ``detectFromText(_:)``：针对续期邮件截图，提取结构化订阅字段（高置信路径）
/// - ``detectFromHistory(_:)``：扫描历史交易，按时间间隔方差 + 金额稳定性判断周期性订阅
public struct SubscriptionDetector: Sendable {

    public init() {}

    // MARK: - From OCR Text

    /// 从 OCR 文本检测是否为订阅续期邮件。
    /// 命中高置信特征时返回填充好的 `Subscription`，否则返回 `nil`。
    public func detectFromText(_ text: String) -> Subscription? {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard isHighConfidenceRenewal(normalized) else { return nil }
        guard let amount = extractAmount(from: normalized) else { return nil }

        let period     = extractPeriod(from: normalized)
        let merchant   = extractMerchant(from: normalized)
        let planName   = extractPlanName(from: normalized)
        let chargedAt  = extractDate(from: normalized) ?? .now

        return Subscription(
            merchant: merchant,
            planName: planName,
            period: period,
            amount: amount,
            lastChargedAt: chargedAt
        )
    }

    // MARK: - From Historical Transactions

    /// 扫描历史账单，返回检测到的周期性订阅列表。
    /// 同商户需至少 2 笔记录，且间隔变异系数 < 20%、金额波动 < 5%。
    public func detectFromHistory(_ transactions: [Transaction]) -> [Subscription] {
        let grouped = Dictionary(grouping: transactions) { $0.merchant }
        return grouped.compactMap { merchant, txs -> Subscription? in
            guard txs.count >= 2 else { return nil }
            let sorted = txs.sorted { $0.occurredAt < $1.occurredAt }
            return detectPeriodic(merchant: merchant, transactions: sorted)
        }
    }

    // MARK: - Private: High-Confidence Detection

    private func isHighConfidenceRenewal(_ text: String) -> Bool {
        let lowered = text.lowercased()

        let keywords = [
            "自动续期", "自动扣款", "订阅将以", "订阅已续期", "已自动续费", "已续订", "续费成功",
            "auto-renew", "auto renew", "subscription renewed", "your subscription",
            "recurring charge", "renewal receipt",
        ]
        if keywords.contains(where: { lowered.contains($0) }) { return true }

        // 正则：「订阅将以 XX 元/月 续期」等模糊匹配
        let regexPatterns = [
            #"订阅将以.{1,20}续期"#,
            #"将以.{1,10}[¥￥\$].{1,5}续"#,
        ]
        for pattern in regexPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Private: Field Extraction

    private func extractAmount(from text: String) -> Double? {
        let patterns = [
            #"[¥￥]\s*([0-9]+(?:\.[0-9]{1,2})?)"#,
            #"([0-9]+(?:\.[0-9]{1,2})?)\s*元"#,
            #"\$\s*([0-9]+(?:\.[0-9]{2})?)"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let val = Double(String(text[range])), val > 0 {
                return val
            }
        }
        return nil
    }

    private func extractPeriod(from text: String) -> SubscriptionPeriod {
        let lowered = text.lowercased()
        if lowered.contains("年") || lowered.contains("yearly") || lowered.contains("annual")
            || lowered.contains("/yr") || lowered.contains("/year") { return .yearly }
        if lowered.contains("周") || lowered.contains("weekly")
            || lowered.contains("/wk") || lowered.contains("/week") { return .weekly }
        return .monthly
    }

    private func extractMerchant(from text: String) -> String {
        let lowered = text.lowercased()
        let knownMap: [(String, String)] = [
            ("icloud",      "iCloud+"),
            ("apple",       "Apple"),
            ("netflix",     "Netflix"),
            ("spotify",     "Spotify"),
            ("腾讯视频",    "腾讯视频"),
            ("爱奇艺",      "爱奇艺"),
            ("优酷",        "优酷"),
            ("哔哩哔哩",    "哔哩哔哩"),
            ("bilibili",    "哔哩哔哩"),
            ("youtube",     "YouTube Premium"),
            ("disney",      "Disney+"),
            ("chatgpt",     "ChatGPT"),
            ("openai",      "OpenAI"),
            ("microsoft",   "Microsoft 365"),
        ]
        for (keyword, name) in knownMap where lowered.contains(keyword) { return name }

        // 回退：取第一条有意义的非空行（前 30 字）
        let firstLine = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.count > 1 }) ?? "待确认"
        return String(firstLine.prefix(30))
    }

    private func extractPlanName(from text: String) -> String {
        let lowered = text.lowercased()
        let knownPlans: [(String, String)] = [
            ("50gb",    "iCloud+ 50GB"),
            ("200gb",   "iCloud+ 200GB"),
            ("2tb",     "iCloud+ 2TB"),
            ("家庭版",  "家庭版"),
            ("family",  "家庭版"),
            ("个人版",  "个人版"),
            ("student", "学生版"),
            ("premium", "Premium"),
        ]
        for (keyword, plan) in knownPlans where lowered.contains(keyword) { return plan }

        // 正则提取：「XXX方案 / XXX计划 / XXX套餐 / XXX Plus / Pro / Max」
        let planPattern = #"(\S{1,20}(?:方案|计划|版|套餐|plan|tier|plus|pro|max))"#
        if let regex = try? NSRegularExpression(pattern: planPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return ""
    }

    private func extractDate(from text: String) -> Date? {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current

        // yyyy年M月d日 / yyyy-MM-dd / yyyy/MM/dd
        let ymdPattern = #"(\d{4})[年\-/](\d{1,2})[月\-/](\d{1,2})"#
        if let regex = try? NSRegularExpression(pattern: ymdPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let r1 = Range(match.range(at: 1), in: text),
           let r2 = Range(match.range(at: 2), in: text),
           let r3 = Range(match.range(at: 3), in: text) {
            var c = DateComponents()
            c.year  = Int(text[r1])
            c.month = Int(text[r2])
            c.day   = Int(text[r3])
            return cal.date(from: c)
        }
        return nil
    }

    // MARK: - Private: Periodic Pattern Detection

    private func detectPeriodic(merchant: String, transactions: [Transaction]) -> Subscription? {
        let dates = transactions.map { $0.occurredAt }
        var intervals: [Double] = []
        for i in 1..<dates.count {
            intervals.append(dates[i].timeIntervalSince(dates[i - 1]))
        }

        let mean = intervals.reduce(0, +) / Double(intervals.count)
        guard mean > 0 else { return nil }

        let variance = intervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intervals.count)
        let cv = sqrt(variance) / mean  // 变异系数
        guard cv < 0.20 else { return nil }     // 间隔规律性：变异系数 < 20%

        // 金额一致性：波动 < 5%
        let amounts  = transactions.map { $0.amount }
        let meanAmt  = amounts.reduce(0, +) / Double(amounts.count)
        let amtStd   = sqrt(amounts.map { pow($0 - meanAmt, 2) }.reduce(0, +) / Double(amounts.count))
        let amtCV    = meanAmt > 0 ? amtStd / meanAmt : 1.0
        guard amtCV < 0.05 else { return nil }

        let days = mean / 86_400
        let period: SubscriptionPeriod
        switch days {
        case ..<10:   period = .weekly
        case ..<60:   period = .monthly
        case ..<400:  period = .yearly
        default: return nil
        }

        let last = transactions.last!
        return Subscription(
            merchant: merchant,
            planName: "",
            period: period,
            amount: meanAmt,
            lastChargedAt: last.occurredAt
        )
    }
}
