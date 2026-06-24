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
    public let hotelStayRecordID: UUID?

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

    /// 向后兼容的初始化方法，接受内置枚举类型（内部存为 rawValue）。
    public init(
        id: UUID = UUID(),
        merchant: String,
        amount: Double,
        occurredAt: Date,
        category: TransactionCategory,
        source: ReceiptSource,
        note: String,
        hotelStayRecordID: UUID? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.occurredAt = occurredAt
        self.category = category.rawValue
        self.source = source.rawValue
        self.note = note
        self.hotelStayRecordID = hotelStayRecordID
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
        hotelStayRecordID: UUID? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.occurredAt = occurredAt
        self.category = categoryLabel
        self.source = sourceLabel
        self.note = note
        self.hotelStayRecordID = hotelStayRecordID
    }
}
