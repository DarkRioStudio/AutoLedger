import Foundation

public struct LedgerProfile: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let iconName: String?
    public let colorName: String?
    public let currency: String?
    public let isDefault: Bool
    public let sortOrder: Int
    public let archivedAt: Date?
    public let createdAt: Date
    public let updatedAt: Date

    public var isArchived: Bool {
        archivedAt != nil
    }

    public init(
        id: String,
        name: String,
        iconName: String? = nil,
        colorName: String? = nil,
        currency: String? = nil,
        isDefault: Bool = false,
        sortOrder: Int = 0,
        archivedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorName = colorName
        self.currency = currency
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func defaultLocal(createdAt: Date = .now) -> LedgerProfile {
        LedgerProfile(
            id: TodaySpendingSummary.defaultLedgerID,
            name: TodaySpendingSummary.defaultLedgerName,
            iconName: "wallet.pass",
            colorName: "accent",
            currency: nil,
            isDefault: true,
            sortOrder: 0,
            archivedAt: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}
