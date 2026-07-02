import Foundation

public enum VoiceLedgerConfidence: String, Sendable {
    case high
    case needsReview
    case failed
}

public enum VoiceLedgerFailureReason: String, Sendable {
    case emptyInput
    case noAmount
    case multipleAmounts
    case unsupportedIncomeOrTransfer
    case ambiguousDescription
    case invalidAmount
    case tooLong
}

public struct VoiceLedgerParseResult: Sendable {
    public let inputText: String
    public let merchant: String
    public let amount: Double?
    public let occurredAt: Date
    public let category: TransactionCategory
    public let confidence: VoiceLedgerConfidence
    public let failureReason: VoiceLedgerFailureReason?
    public let parseMethod: String

    public var isSaveable: Bool {
        amount != nil && failureReason == nil
    }

    public var receiptConfidence: Double {
        switch confidence {
        case .high: return 0.95
        case .needsReview: return 0.65
        case .failed: return 0.2
        }
    }

    public func makeReceipt() -> ImportedReceipt? {
        guard let amount else { return nil }
        return ImportedReceipt(
            source: .voice,
            merchant: merchant.isEmpty ? "语音记账" : merchant,
            amount: amount,
            currencyCode: ReceiptCurrencyDetector.detectCode(in: inputText),
            occurredAt: occurredAt,
            rawText: inputText,
            summary: "语音记账：\(inputText)",
            confidence: receiptConfidence,
            suggestedCategory: category
        )
    }
}

public struct VoiceLedgerParser: Sendable {
    private struct AmountMatch {
        let value: Double
        let range: Range<String.Index>
    }

    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(calendar: Calendar = .current, now: @escaping @Sendable () -> Date = { Date() }) {
        self.calendar = calendar
        self.now = now
    }

    public func parse(_ text: String, corrections: [String: TransactionCategory] = [:]) -> VoiceLedgerParseResult {
        let normalized = normalize(text)
        let referenceDate = now()

        guard !normalized.isEmpty else {
            return failed(inputText: normalized, occurredAt: referenceDate, reason: .emptyInput)
        }
        guard normalized.count <= 80 else {
            return failed(inputText: normalized, occurredAt: referenceDate, reason: .tooLong)
        }
        guard !containsUnsupportedSemantic(normalized) else {
            return failed(inputText: normalized, occurredAt: referenceDate, reason: .unsupportedIncomeOrTransfer)
        }

        let amounts = extractAmounts(from: normalized)
        guard !amounts.isEmpty else {
            return failed(inputText: normalized, occurredAt: referenceDate, reason: .noAmount)
        }
        guard amounts.count == 1 else {
            return failed(inputText: normalized, occurredAt: referenceDate, reason: .multipleAmounts)
        }
        guard amounts[0].value > 0 else {
            return failed(inputText: normalized, occurredAt: referenceDate, reason: .invalidAmount)
        }

        let merchant = extractMerchant(from: normalized, amountRange: amounts[0].range)
        let occurredAt = inferDate(from: normalized, referenceDate: referenceDate)
        let category = TransactionCategory.infer(from: merchant.isEmpty ? normalized : merchant, corrections: corrections)

        if merchant.isEmpty || merchant.count <= 1 {
            return VoiceLedgerParseResult(
                inputText: normalized,
                merchant: merchant,
                amount: amounts[0].value,
                occurredAt: occurredAt,
                category: category,
                confidence: .needsReview,
                failureReason: .ambiguousDescription,
                parseMethod: "rule"
            )
        }

        return VoiceLedgerParseResult(
            inputText: normalized,
            merchant: merchant,
            amount: amounts[0].value,
            occurredAt: occurredAt,
            category: category,
            confidence: .high,
            failureReason: nil,
            parseMethod: "rule"
        )
    }

    private func failed(inputText: String, occurredAt: Date, reason: VoiceLedgerFailureReason) -> VoiceLedgerParseResult {
        VoiceLedgerParseResult(
            inputText: inputText,
            merchant: "",
            amount: nil,
            occurredAt: occurredAt,
            category: .other,
            confidence: .failed,
            failureReason: reason,
            parseMethod: "rule"
        )
    }

    private func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "，", with: " ")
            .replacingOccurrences(of: "。", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "：", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "￥", with: "¥")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsUnsupportedSemantic(_ text: String) -> Bool {
        let keywords = [
            "收入", "工资", "奖金", "报销", "退款", "退回", "转账", "转我", "转给",
            "收款", "收到", "还款", "借我", "借给", "提现", "入账"
        ]
        return keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func extractAmounts(from text: String) -> [AmountMatch] {
        let pattern = #"(?<![A-Za-z0-9])(?:¥\s*)?([0-9]+(?:\.[0-9]{1,2})?)\s*(?:元|块|块钱|人民币|rmb|RMB)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let numberRange = Range(match.range(at: 1), in: text),
                  let fullRange = Range(match.range, in: text),
                  let value = Double(text[numberRange]) else {
                return nil
            }
            return AmountMatch(value: value, range: fullRange)
        }
    }

    private func extractMerchant(from text: String, amountRange: Range<String.Index>) -> String {
        var cleaned = text
        cleaned.removeSubrange(amountRange)

        let removableTokens = [
            "帮我记一笔", "帮我记", "记一笔", "记账", "语音记账", "用 AutoLedger",
            "用AutoLedger", "花了", "消费", "支出", "付款", "支付", "今天", "昨天",
            "前天", "刚刚", "现在", "中午", "晚上", "早上", "上午", "下午"
        ]
        for token in removableTokens {
            cleaned = cleaned.replacingOccurrences(of: token, with: " ")
        }

        return cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func inferDate(from text: String, referenceDate: Date) -> Date {
        if text.contains("前天") {
            return calendar.date(byAdding: .day, value: -2, to: referenceDate) ?? referenceDate
        }
        if text.contains("昨天") {
            return calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        }
        return referenceDate
    }
}
