import Foundation

public struct Transaction: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let merchant: String
    public let amount: Double
    public let occurredAt: Date
    /// 存储 `TransactionCategory` 的 rawValue 字符串，或用户自定义分类名。
    public let category: String
    /// 存储 `ReceiptSource` 的 rawValue 字符串，或用户自定义来源名。
    public let source: String
    public let note: String
    public let ledgerID: String?
    public let hotelStayRecordID: UUID?
    /// 写入账本后的目标币种；`amount` 始终表示该币种下的入账金额。
    public let ledgerCurrencyCode: String?
    /// 识别到的原始金额，仅在原始币种与目标账本币种不同或需要保留凭证金额时写入。
    public let originalAmount: Double?
    public let originalCurrencyCode: String?
    /// `amount = originalAmount * exchangeRate`，即 1 单位原币种对应多少目标账本币种。
    public let exchangeRate: Double?
    /// 汇率生效日期，使用 `yyyy-MM-dd`，通常对应账单发生日或 API 返回的最近可用交易日。
    public let exchangeRateDate: String?
    public let exchangeRateProvider: String?

    /// 映射到内置分类枚举；自定义分类回退为 `.other`。
    public var categoryEnum: TransactionCategory {
        TransactionCategory(rawValue: category) ?? .other
    }

    /// 映射到内置来源枚举；自定义来源回退为 `.manual`。
    public var sourceEnum: ReceiptSource {
        ReceiptSource(rawValue: source) ?? .manual
    }

    /// 显示用标题：内置分类显示本地化名称，自定义分类原样显示。
    public var categoryTitle: String {
        TransactionCategory(rawValue: category)?.title ?? category
    }

    /// 显示用标题：内置来源显示本地化名称，自定义来源原样显示。
    public var sourceTitle: String {
        ReceiptSource(rawValue: source)?.title ?? source
    }

    public func resolvedLedgerID(defaultLedgerID: String = TodaySpendingSummary.defaultLedgerID) -> String {
        if let trimmedLedgerID = ledgerID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmedLedgerID.isEmpty {
            return trimmedLedgerID
        }
        return defaultLedgerID
    }

    public func assigningLedgerIDIfMissing(_ defaultLedgerID: String = TodaySpendingSummary.defaultLedgerID) -> Transaction {
        guard ledgerID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else {
            return self
        }

        return Transaction(
            id: id,
            merchant: merchant,
            amount: amount,
            occurredAt: occurredAt,
            categoryLabel: category,
            sourceLabel: source,
            note: note,
            ledgerID: defaultLedgerID,
            hotelStayRecordID: hotelStayRecordID,
            ledgerCurrencyCode: ledgerCurrencyCode,
            originalAmount: originalAmount,
            originalCurrencyCode: originalCurrencyCode,
            exchangeRate: exchangeRate,
            exchangeRateDate: exchangeRateDate,
            exchangeRateProvider: exchangeRateProvider
        )
    }

    /// 向后兼容的初始化方法，接受内置枚举类型（内部存为 rawValue）。
    public init(
        id: UUID = UUID(),
        merchant: String,
        amount: Double,
        occurredAt: Date,
        category: TransactionCategory,
        source: ReceiptSource,
        note: String,
        ledgerID: String? = nil,
        hotelStayRecordID: UUID? = nil,
        ledgerCurrencyCode: String? = nil,
        originalAmount: Double? = nil,
        originalCurrencyCode: String? = nil,
        exchangeRate: Double? = nil,
        exchangeRateDate: String? = nil,
        exchangeRateProvider: String? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.occurredAt = occurredAt
        self.category = category.rawValue
        self.source = source.rawValue
        self.note = note
        self.ledgerID = ledgerID
        self.hotelStayRecordID = hotelStayRecordID
        self.ledgerCurrencyCode = ledgerCurrencyCode
        self.originalAmount = originalAmount
        self.originalCurrencyCode = originalCurrencyCode
        self.exchangeRate = exchangeRate
        self.exchangeRateDate = exchangeRateDate
        self.exchangeRateProvider = exchangeRateProvider
    }

    /// 支持自定义分类/来源的字符串初始化方法。
    public init(
        id: UUID = UUID(),
        merchant: String,
        amount: Double,
        occurredAt: Date,
        categoryLabel: String,
        sourceLabel: String,
        note: String,
        ledgerID: String? = nil,
        hotelStayRecordID: UUID? = nil,
        ledgerCurrencyCode: String? = nil,
        originalAmount: Double? = nil,
        originalCurrencyCode: String? = nil,
        exchangeRate: Double? = nil,
        exchangeRateDate: String? = nil,
        exchangeRateProvider: String? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.occurredAt = occurredAt
        self.category = categoryLabel
        self.source = sourceLabel
        self.note = note
        self.ledgerID = ledgerID
        self.hotelStayRecordID = hotelStayRecordID
        self.ledgerCurrencyCode = ledgerCurrencyCode
        self.originalAmount = originalAmount
        self.originalCurrencyCode = originalCurrencyCode
        self.exchangeRate = exchangeRate
        self.exchangeRateDate = exchangeRateDate
        self.exchangeRateProvider = exchangeRateProvider
    }
}
