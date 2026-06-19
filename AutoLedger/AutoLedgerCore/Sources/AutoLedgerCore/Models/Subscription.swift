import Foundation

// MARK: - SubscriptionPeriod

public enum SubscriptionPeriod: String, Codable, CaseIterable, Sendable {
    case weekly
    case monthly
    case yearly

    public var title: String {
        switch self {
        case .weekly:  return NSLocalizedString("subscription.period.weekly", comment: "")
        case .monthly: return NSLocalizedString("subscription.period.monthly", comment: "")
        case .yearly:  return NSLocalizedString("subscription.period.yearly", comment: "")
        }
    }

    /// 用于周期检测的名义天数
    public var nominalDays: Double {
        switch self {
        case .weekly:  return 7
        case .monthly: return 30.44
        case .yearly:  return 365.25
        }
    }

    /// 按日历精确计算下次扣费日期
    public func nextDate(from date: Date) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        switch self {
        case .weekly:  return cal.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly: return cal.date(byAdding: .month,      value: 1, to: date) ?? date
        case .yearly:  return cal.date(byAdding: .year,       value: 1, to: date) ?? date
        }
    }
}

// MARK: - SubscriptionStatus

public enum SubscriptionStatus: String, Codable, CaseIterable, Sendable {
    case active
    case paused
    case canceled

    public var title: String {
        switch self {
        case .active:   return NSLocalizedString("subscription.status.active", comment: "")
        case .paused:   return NSLocalizedString("subscription.status.paused", comment: "")
        case .canceled: return NSLocalizedString("subscription.status.canceled", comment: "")
        }
    }

    public var isActive: Bool {
        self == .active
    }
}

// MARK: - Subscription

public struct Subscription: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let merchant: String
    public let planName: String
    public let period: SubscriptionPeriod
    public let amount: Double
    public let lastChargedAt: Date
    public let nextChargedAt: Date
    public let status: SubscriptionStatus
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case merchant
        case planName
        case period
        case amount
        case lastChargedAt
        case nextChargedAt
        case status
        case createdAt
    }

    public init(
        id: UUID = UUID(),
        merchant: String,
        planName: String,
        period: SubscriptionPeriod,
        amount: Double,
        lastChargedAt: Date,
        nextChargedAt: Date? = nil,
        status: SubscriptionStatus = .active,
        createdAt: Date = .now
    ) {
        self.id           = id
        self.merchant     = merchant
        self.planName     = planName
        self.period       = period
        self.amount       = amount
        self.lastChargedAt = lastChargedAt
        self.nextChargedAt = nextChargedAt ?? period.nextDate(from: lastChargedAt)
        self.status       = status
        self.createdAt    = createdAt
    }

    public static func draft(
        from transaction: Transaction,
        period: SubscriptionPeriod = .monthly,
        planName: String = ""
    ) -> Subscription {
        Subscription(
            merchant: transaction.merchant,
            planName: planName,
            period: period,
            amount: transaction.amount,
            lastChargedAt: transaction.occurredAt,
            status: .active
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.merchant = try container.decode(String.self, forKey: .merchant)
        self.planName = try container.decode(String.self, forKey: .planName)
        self.period = try container.decode(SubscriptionPeriod.self, forKey: .period)
        self.amount = try container.decode(Double.self, forKey: .amount)
        self.lastChargedAt = try container.decode(Date.self, forKey: .lastChargedAt)
        self.nextChargedAt = try container.decode(Date.self, forKey: .nextChargedAt)
        self.status = try container.decodeIfPresent(SubscriptionStatus.self, forKey: .status) ?? .active
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(merchant, forKey: .merchant)
        try container.encode(planName, forKey: .planName)
        try container.encode(period, forKey: .period)
        try container.encode(amount, forKey: .amount)
        try container.encode(lastChargedAt, forKey: .lastChargedAt)
        try container.encode(nextChargedAt, forKey: .nextChargedAt)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
    }

    /// 更新扣费日期，保留原始 id / createdAt / planName / period
    public func updated(lastChargedAt newDate: Date, amount newAmount: Double? = nil) -> Subscription {
        Subscription(
            id: id,
            merchant: merchant,
            planName: planName,
            period: period,
            amount: newAmount ?? amount,
            lastChargedAt: newDate,
            nextChargedAt: period.nextDate(from: newDate),
            status: status,
            createdAt: createdAt
        )
    }

    public func updated(status newStatus: SubscriptionStatus) -> Subscription {
        Subscription(
            id: id,
            merchant: merchant,
            planName: planName,
            period: period,
            amount: amount,
            lastChargedAt: lastChargedAt,
            nextChargedAt: nextChargedAt,
            status: newStatus,
            createdAt: createdAt
        )
    }
}
