import Foundation

public struct BillRelevanceResult: Sendable, Codable, Equatable {
    public let isRelevant: Bool
    public let score: Int
    public let positiveSignals: [String]
    public let negativeSignals: [String]

    public init(isRelevant: Bool, score: Int, positiveSignals: [String], negativeSignals: [String]) {
        self.isRelevant = isRelevant
        self.score = score
        self.positiveSignals = positiveSignals
        self.negativeSignals = negativeSignals
    }
}

public struct BillRelevanceGate: Sendable {
    private let amountPattern = #"(¥|￥|\$|€|£|₩)?\s*[0-9]+(?:[.,][0-9]{1,3})?\s*(元|块|원|rmb|RMB|krw|KRW)?"#
    private let languagePackSet: LedgerRecognitionLanguagePackSet

    public init(languagePackSet: LedgerRecognitionLanguagePackSet = .builtIn) {
        self.languagePackSet = languagePackSet
    }

    public func evaluate(
        _ rawText: String,
        sourceHint: LedgerSourceHint = .unknown,
        localeIdentifier: String? = nil
    ) -> BillRelevanceResult {
        let normalized = normalize(rawText)
        guard !normalized.isEmpty else {
            return BillRelevanceResult(
                isRelevant: false,
                score: 0,
                positiveSignals: [],
                negativeSignals: ["empty_text"]
            )
        }

        var score = 0
        var positives: [String] = []
        var negatives: [String] = []

        if normalized.count < 8 {
            negatives.append("too_short")
            score -= 2
        }

        if containsAmount(in: normalized) {
            positives.append("amount")
            score += 2
        }

        let languagePacks = languagePackSet.packs(for: localeIdentifier)
        let builtInPaymentKeywords = [
            "付款成功", "支付成功", "交易成功", "交易详情", "订单详情", "支付金额", "交易金额",
            "商户名称", "商户名", "收款方", "付款方式", "实付", "合计", "小计", "总计",
            "total", "grand total", "subtotal", "amount", "receipt", "invoice", "cashier", "tax"
        ]
        let languagePaymentKeywords = languagePacks.flatMap { pack in
            pack.billKeywords + pack.paymentKeywords + pack.amountLabels + pack.totalLabels + pack.taxLabels
        }
        let paymentKeywords = builtInPaymentKeywords + languagePaymentKeywords
        if containsAny(paymentKeywords, in: normalized) {
            positives.append("payment_or_receipt_keyword")
            score += 3
        }

        let platformKeywords = [
            "微信", "支付宝", "云闪付", "银联", "unionpay", "app store", "apple",
            "淘宝", "饿了么", "抖音", "美团", "滴滴"
        ]
        if containsAny(platformKeywords, in: normalized) {
            positives.append("known_platform")
            score += 2
        }

        let nonBillHints = [
            "聊天", "朋友圈", "微博", "新闻", "天气", "设置", "登录", "验证码", "广告"
        ] + languagePacks.flatMap { $0.nonMerchantKeywords }
        if containsAny(nonBillHints, in: normalized), positives.isEmpty {
            negatives.append("non_bill_context")
            score -= 2
        }

        switch sourceHint {
        case .receipt, .payment, .subscription:
            positives.append("source_hint")
            score += 1
        case .sentence:
            if containsAmount(in: normalized) {
                positives.append("sentence_with_amount")
                score += 1
            }
        case .unknown:
            break
        }

        let isRelevant = score >= 2 && !positives.isEmpty
        if !isRelevant, negatives.isEmpty {
            negatives.append("insufficient_bill_signals")
        }

        return BillRelevanceResult(
            isRelevant: isRelevant,
            score: score,
            positiveSignals: positives,
            negativeSignals: negatives
        )
    }

    private func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func containsAny(_ keywords: [String], in text: String) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func containsAmount(in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: amountPattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
