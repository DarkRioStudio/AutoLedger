import Foundation

public enum SubscriptionAnomalyKind: String, Codable, CaseIterable, Sendable {
    case priceIncrease
    case duplicateCharge
    case billingCycleDrift
}

public enum SubscriptionAnomalySeverity: String, Codable, Sendable {
    case info
    case warning
    case critical
}

public enum SubscriptionAnomalyDisposition: String, Codable, Sendable {
    case confirmed
    case ignored
}

public struct SubscriptionAnomalyDecisionRecord: Codable, Equatable, Sendable {
    public let disposition: SubscriptionAnomalyDisposition
    public let updatedAt: Date

    public init(disposition: SubscriptionAnomalyDisposition, updatedAt: Date = .now) {
        self.disposition = disposition
        self.updatedAt = updatedAt
    }
}

public struct SubscriptionAnomaly: Identifiable, Codable, Equatable, Sendable {
    public let kind: SubscriptionAnomalyKind
    public let severity: SubscriptionAnomalySeverity
    public let subscriptionID: UUID
    public let merchant: String
    public let currentAmount: Double?
    public let previousAmount: Double?
    public let currencyCode: String
    public let expectedDate: Date?
    public let actualDate: Date?
    public let relatedTransactionIDs: [UUID]
    public let detectedAt: Date

    public var id: String {
        var components = [
            kind.rawValue,
            subscriptionID.uuidString,
            relatedTransactionIDs.map(\.uuidString).joined(separator: "-")
        ]
        if kind == .billingCycleDrift {
            components.append(expectedDate.map { String(Int($0.timeIntervalSince1970)) } ?? "none")
            components.append(actualDate.map { String(Int($0.timeIntervalSince1970)) } ?? "none")
        }
        return components.joined(separator: ":")
    }

    public init(
        kind: SubscriptionAnomalyKind,
        severity: SubscriptionAnomalySeverity,
        subscriptionID: UUID,
        merchant: String,
        currentAmount: Double? = nil,
        previousAmount: Double? = nil,
        currencyCode: String,
        expectedDate: Date? = nil,
        actualDate: Date? = nil,
        relatedTransactionIDs: [UUID] = [],
        detectedAt: Date = Date()
    ) {
        self.kind = kind
        self.severity = severity
        self.subscriptionID = subscriptionID
        self.merchant = merchant
        self.currentAmount = currentAmount
        self.previousAmount = previousAmount
        self.currencyCode = currencyCode
        self.expectedDate = expectedDate
        self.actualDate = actualDate
        self.relatedTransactionIDs = relatedTransactionIDs
        self.detectedAt = detectedAt
    }
}

public struct SubscriptionRenewalPressure: Identifiable, Codable, Equatable, Sendable {
    public let windowDays: Int
    public let currencyCode: String
    public let totalAmount: Double
    public let subscriptionCount: Int
    public let dueSubscriptionIDs: [UUID]

    public var id: String {
        "\(windowDays)-\(currencyCode)"
    }

    public init(windowDays: Int, currencyCode: String, totalAmount: Double, subscriptionCount: Int, dueSubscriptionIDs: [UUID]) {
        self.windowDays = windowDays
        self.currencyCode = currencyCode
        self.totalAmount = totalAmount
        self.subscriptionCount = subscriptionCount
        self.dueSubscriptionIDs = dueSubscriptionIDs
    }
}

public struct SubscriptionAnomalySummary: Codable, Equatable, Sendable {
    public let anomalies: [SubscriptionAnomaly]
    public let renewalPressure: [SubscriptionRenewalPressure]

    public init(anomalies: [SubscriptionAnomaly], renewalPressure: [SubscriptionRenewalPressure]) {
        self.anomalies = anomalies
        self.renewalPressure = renewalPressure
    }

    public func filteringHandledAnomalies(withIDs handledIDs: Set<String>) -> SubscriptionAnomalySummary {
        guard !handledIDs.isEmpty else { return self }
        return SubscriptionAnomalySummary(
            anomalies: anomalies.filter { !handledIDs.contains($0.id) },
            renewalPressure: renewalPressure
        )
    }
}

public struct SubscriptionAnomalyDetector: Sendable {
    public var priceIncreaseThreshold: Double
    public var duplicateWindowDays: Double

    public init(priceIncreaseThreshold: Double = 0.05, duplicateWindowDays: Double = 3) {
        self.priceIncreaseThreshold = priceIncreaseThreshold
        self.duplicateWindowDays = duplicateWindowDays
    }

    public func analyze(
        subscriptions: [Subscription],
        transactions: [Transaction],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SubscriptionAnomalySummary {
        let activeSubscriptions = subscriptions.filter { $0.status.isActive }
        var anomalies: [SubscriptionAnomaly] = []

        for subscription in activeSubscriptions {
            let relatedTransactions = transactions
                .filter { matches($0, subscription: subscription) }
                .sorted { $0.occurredAt < $1.occurredAt }

            if let priceIncrease = detectPriceIncrease(for: subscription, transactions: relatedTransactions, now: now) {
                anomalies.append(priceIncrease)
            }
            if let duplicateCharge = detectDuplicateCharge(for: subscription, transactions: relatedTransactions, now: now) {
                anomalies.append(duplicateCharge)
            }
            if let cycleDrift = detectBillingCycleDrift(for: subscription, now: now, calendar: calendar) {
                anomalies.append(cycleDrift)
            }
        }

        return SubscriptionAnomalySummary(
            anomalies: anomalies.sorted { lhs, rhs in
                if lhs.severity != rhs.severity {
                    return severityRank(lhs.severity) > severityRank(rhs.severity)
                }
                return lhs.merchant < rhs.merchant
            },
            renewalPressure: renewalPressure(for: activeSubscriptions, now: now)
        )
    }

    private func detectPriceIncrease(
        for subscription: Subscription,
        transactions: [Transaction],
        now: Date
    ) -> SubscriptionAnomaly? {
        guard let latest = transactions.last else { return nil }
        let baseline = transactions.dropLast().reversed().first {
            abs($0.amount - latest.amount) > max(0.01, latest.amount * 0.01)
        }
        guard let baseline,
              latest.amount > baseline.amount * (1 + priceIncreaseThreshold) else {
            return nil
        }

        return SubscriptionAnomaly(
            kind: .priceIncrease,
            severity: .warning,
            subscriptionID: subscription.id,
            merchant: subscription.merchant,
            currentAmount: latest.amount,
            previousAmount: baseline.amount,
            currencyCode: latest.ledgerCurrencyCode ?? subscription.currencyCode,
            relatedTransactionIDs: [baseline.id, latest.id],
            detectedAt: now
        )
    }

    private func detectDuplicateCharge(
        for subscription: Subscription,
        transactions: [Transaction],
        now: Date
    ) -> SubscriptionAnomaly? {
        guard transactions.count >= 2 else { return nil }
        let duplicateWindow = duplicateWindowDays * 86_400
        for index in 1..<transactions.count {
            let current = transactions[index]
            let previous = transactions[index - 1]
            guard current.occurredAt.timeIntervalSince(previous.occurredAt) <= duplicateWindow else {
                continue
            }
            let amountTolerance = max(0.01, max(current.amount, previous.amount) * 0.02)
            guard abs(current.amount - previous.amount) <= amountTolerance else {
                continue
            }
            return SubscriptionAnomaly(
                kind: .duplicateCharge,
                severity: .critical,
                subscriptionID: subscription.id,
                merchant: subscription.merchant,
                currentAmount: current.amount,
                previousAmount: previous.amount,
                currencyCode: current.ledgerCurrencyCode ?? subscription.currencyCode,
                relatedTransactionIDs: [previous.id, current.id],
                detectedAt: now
            )
        }
        return nil
    }

    private func detectBillingCycleDrift(
        for subscription: Subscription,
        now: Date,
        calendar: Calendar
    ) -> SubscriptionAnomaly? {
        let expected = subscription.period.nextDate(from: subscription.lastChargedAt)
        let driftDays = abs(subscription.nextChargedAt.timeIntervalSince(expected)) / 86_400
        guard driftDays > cycleToleranceDays(for: subscription.period) else { return nil }
        return SubscriptionAnomaly(
            kind: .billingCycleDrift,
            severity: .warning,
            subscriptionID: subscription.id,
            merchant: subscription.merchant,
            currencyCode: subscription.currencyCode,
            expectedDate: expected,
            actualDate: subscription.nextChargedAt,
            detectedAt: now
        )
    }

    private func renewalPressure(for subscriptions: [Subscription], now: Date) -> [SubscriptionRenewalPressure] {
        [7, 30, 90].flatMap { windowDays -> [SubscriptionRenewalPressure] in
            let windowEnd = now.addingTimeInterval(Double(windowDays) * 86_400)
            let due = subscriptions.filter { subscription in
                subscription.nextChargedAt >= now && subscription.nextChargedAt <= windowEnd
            }
            let groupedByCurrency = Dictionary(grouping: due) { $0.currencyCode }
            return groupedByCurrency.map { currencyCode, subscriptions in
                SubscriptionRenewalPressure(
                    windowDays: windowDays,
                    currencyCode: currencyCode,
                    totalAmount: subscriptions.reduce(0) { $0 + $1.amount },
                    subscriptionCount: subscriptions.count,
                    dueSubscriptionIDs: subscriptions.map(\.id).sorted { $0.uuidString < $1.uuidString }
                )
            }
        }
        .sorted {
            if $0.windowDays != $1.windowDays {
                return $0.windowDays < $1.windowDays
            }
            return $0.currencyCode < $1.currencyCode
        }
    }

    private func matches(_ transaction: Transaction, subscription: Subscription) -> Bool {
        normalized(transaction.merchant) == normalized(subscription.merchant)
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cycleToleranceDays(for period: SubscriptionPeriod) -> Double {
        switch period {
        case .weekly: return 2
        case .monthly: return 7
        case .yearly: return 30
        }
    }

    private func severityRank(_ severity: SubscriptionAnomalySeverity) -> Int {
        switch severity {
        case .info: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }
}
