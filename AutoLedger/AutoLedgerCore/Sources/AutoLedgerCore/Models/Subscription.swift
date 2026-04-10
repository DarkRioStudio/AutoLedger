import Foundation

// MARK: - SubscriptionPeriod

public enum SubscriptionPeriod: String, Codable, CaseIterable, Sendable {
    case weekly
    case monthly
    case yearly

    public var title: String {
        switch self {
        case .weekly:  return "每周"
        case .monthly: return "每月"
        case .yearly:  return "每年"
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

// MARK: - Subscription

public struct Subscription: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let merchant: String
    public let planName: String
    public let period: SubscriptionPeriod
    public let amount: Double
    public let lastChargedAt: Date
    public let nextChargedAt: Date
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        merchant: String,
        planName: String,
        period: SubscriptionPeriod,
        amount: Double,
        lastChargedAt: Date,
        nextChargedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id           = id
        self.merchant     = merchant
        self.planName     = planName
        self.period       = period
        self.amount       = amount
        self.lastChargedAt = lastChargedAt
        self.nextChargedAt = nextChargedAt ?? period.nextDate(from: lastChargedAt)
        self.createdAt    = createdAt
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
            createdAt: createdAt
        )
    }
}
