import Foundation

public enum StructuredLedgerJSONError: Error, Equatable, Sendable {
    case emptyInput
    case invalidJSON
    case missingAmount
    case invalidAmount
    case missingMerchant
    case lowConfidence(Double)
}

public enum StructuredLedgerJSONDecision: String, Codable, Sendable {
    case autoSave
    case needsConfirmation
}

public struct StructuredLedgerJSONDraft: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public var merchant: String
    public var amount: Double
    public var categoryLabel: String
    public var occurredAt: Date
    public var note: String
    public var currency: String?
    public var confidence: Double

    public init(
        id: UUID = UUID(),
        merchant: String,
        amount: Double,
        categoryLabel: String,
        occurredAt: Date,
        note: String,
        currency: String?,
        confidence: Double
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.categoryLabel = categoryLabel
        self.occurredAt = occurredAt
        self.note = note
        self.currency = currency
        self.confidence = confidence
    }

    public var categoryEnum: TransactionCategory {
        TransactionCategory(rawValue: categoryLabel) ?? .other
    }
}

public struct StructuredLedgerJSONParseResult: Equatable, Sendable {
    public let draft: StructuredLedgerJSONDraft
    public let decision: StructuredLedgerJSONDecision
}

public struct StructuredLedgerJSONParser: Sendable {
    public let autoSaveThreshold: Double
    public let reviewThreshold: Double
    private let now: @Sendable () -> Date

    public init(
        autoSaveThreshold: Double = 0.85,
        reviewThreshold: Double = 0.50,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.autoSaveThreshold = autoSaveThreshold
        self.reviewThreshold = reviewThreshold
        self.now = now
    }

    public func parse(_ jsonText: String) throws -> StructuredLedgerJSONParseResult {
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StructuredLedgerJSONError.emptyInput }

        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            throw StructuredLedgerJSONError.invalidJSON
        }

        guard let amount = amount(from: dictionary) else {
            throw StructuredLedgerJSONError.missingAmount
        }
        guard amount > 0 else {
            throw StructuredLedgerJSONError.invalidAmount
        }

        let merchant = stringValue(
            from: dictionary,
            keys: ["merchant", "merchant_name", "merchantName", "store", "store_name", "payee", "商户", "商家", "店铺", "收款方"]
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merchant.isEmpty else {
            throw StructuredLedgerJSONError.missingMerchant
        }

        let confidence = normalizedConfidence(from: dictionary)
        guard confidence >= reviewThreshold else {
            throw StructuredLedgerJSONError.lowConfidence(confidence)
        }

        let categoryInput = stringValue(
            from: dictionary,
            keys: ["category", "category_raw", "categoryRaw", "expense_type", "expenseType", "分类", "类型"]
        )
        let categoryLabel = normalizeCategory(categoryInput, merchant: merchant)
        let occurredAt = dateValue(from: dictionary) ?? now()
        let note = stringValue(from: dictionary, keys: ["note", "memo", "description", "remark", "备注", "说明"])
        let currency = stringValue(from: dictionary, keys: ["currency", "currency_code", "currencyCode", "币种"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let draft = StructuredLedgerJSONDraft(
            merchant: merchant,
            amount: amount,
            categoryLabel: categoryLabel,
            occurredAt: occurredAt,
            note: note,
            currency: currency.isEmpty ? nil : currency.uppercased(),
            confidence: confidence
        )
        let decision: StructuredLedgerJSONDecision = confidence >= autoSaveThreshold ? .autoSave : .needsConfirmation
        return StructuredLedgerJSONParseResult(draft: draft, decision: decision)
    }

    private func amount(from dictionary: [String: Any]) -> Double? {
        for key in ["amount", "total", "price", "金额", "总额", "支付金额"] {
            guard let raw = dictionary[key] else { continue }
            if let number = raw as? NSNumber { return number.doubleValue }
            if let text = raw as? String {
                let cleaned = text
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: "¥", with: "")
                    .replacingOccurrences(of: "￥", with: "")
                    .replacingOccurrences(of: "元", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let value = Double(cleaned) { return value }
            }
        }
        return nil
    }

    private func normalizedConfidence(from dictionary: [String: Any]) -> Double {
        let raw = dictionary["confidence"] ?? dictionary["置信度"] ?? dictionary["score"]
        let value: Double?
        if let number = raw as? NSNumber {
            value = number.doubleValue
        } else if let text = raw as? String {
            value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            value = nil
        }

        guard let value else { return reviewThreshold }
        if value > 1, value <= 100 {
            return min(max(value / 100, 0), 1)
        }
        return min(max(value, 0), 1)
    }

    private func dateValue(from dictionary: [String: Any]) -> Date? {
        for key in ["occurredAt", "occurred_at", "date", "time", "paid_at", "paidAt", "日期", "时间", "支付时间"] {
            guard let raw = dictionary[key] else { continue }
            if let date = raw as? Date { return date }
            if let number = raw as? NSNumber {
                return Date(timeIntervalSince1970: number.doubleValue)
            }
            if let text = raw as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let date = ISO8601DateFormatter().date(from: trimmed) {
                    return date
                }
                if let date = AppFormatters.parseFlexibleDate(trimmed) {
                    return date
                }
            }
        }
        return nil
    }

    private func stringValue(from dictionary: [String: Any], keys: [String]) -> String {
        for key in keys {
            guard let raw = dictionary[key] else { continue }
            if let text = raw as? String { return text }
            if let number = raw as? NSNumber { return number.stringValue }
        }
        return ""
    }

    private func normalizeCategory(_ text: String, merchant: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TransactionCategory.infer(from: merchant).rawValue
        }

        if let exact = TransactionCategory(rawValue: trimmed) {
            return exact.rawValue
        }

        let lowered = trimmed.lowercased()
        let aliases: [String: TransactionCategory] = [
            "food": .dining,
            "meal": .dining,
            "restaurant": .dining,
            "餐饮": .dining,
            "餐飲": .dining,
            "吃饭": .dining,
            "吃飯": .dining,
            "交通": .transport,
            "出行": .transport,
            "transportation": .transport,
            "shopping": .shopping,
            "购物": .shopping,
            "購物": .shopping,
            "grocery": .groceries,
            "groceries": .groceries,
            "超市": .groceries,
            "digital": .digital,
            "subscription": .digital,
            "订阅": .digital,
            "訂閱": .digital,
            "utility": .utilities,
            "utilities": .utilities,
            "水电": .utilities,
            "水電": .utilities,
            "entertainment": .entertainment,
            "娱乐": .entertainment,
            "娛樂": .entertainment
        ]

        if let category = aliases[lowered] {
            return category.rawValue
        }
        return trimmed
    }
}
