import Foundation

public struct DataCleaningAssistPayload: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let privacyMode: String
    public let generatedAt: Date
    public let transactionCount: Int
    public let merchantFeatureCount: Int
    public let aliasRuleCount: Int
    public let categoryCorrectionCount: Int
    public let merchantFeatures: [DataCleaningMerchantFeature]

    public init(
        schemaVersion: Int = 1,
        privacyMode: String = "hashed_aggregate_v1",
        generatedAt: Date,
        transactionCount: Int,
        merchantFeatureCount: Int,
        aliasRuleCount: Int,
        categoryCorrectionCount: Int,
        merchantFeatures: [DataCleaningMerchantFeature]
    ) {
        self.schemaVersion = schemaVersion
        self.privacyMode = privacyMode
        self.generatedAt = generatedAt
        self.transactionCount = transactionCount
        self.merchantFeatureCount = merchantFeatureCount
        self.aliasRuleCount = aliasRuleCount
        self.categoryCorrectionCount = categoryCorrectionCount
        self.merchantFeatures = merchantFeatures
    }
}

public struct DataCleaningMerchantFeature: Codable, Equatable, Sendable {
    public let merchantKeyHash: String
    public let normalizedLength: Int
    public let transactionCount: Int
    public let categoryCounts: [String: Int]
    public let sourceCounts: [String: Int]
    public let amountBuckets: [String: Int]
    public let prefixHashes: [DataCleaningMerchantPrefixHash]
    public let aliasTargetHash: String?
    public let correctedCategory: String?

    public init(
        merchantKeyHash: String,
        normalizedLength: Int,
        transactionCount: Int,
        categoryCounts: [String: Int],
        sourceCounts: [String: Int],
        amountBuckets: [String: Int],
        prefixHashes: [DataCleaningMerchantPrefixHash],
        aliasTargetHash: String? = nil,
        correctedCategory: String? = nil
    ) {
        self.merchantKeyHash = merchantKeyHash
        self.normalizedLength = normalizedLength
        self.transactionCount = transactionCount
        self.categoryCounts = categoryCounts
        self.sourceCounts = sourceCounts
        self.amountBuckets = amountBuckets
        self.prefixHashes = prefixHashes
        self.aliasTargetHash = aliasTargetHash
        self.correctedCategory = correctedCategory
    }
}

public struct DataCleaningMerchantPrefixHash: Codable, Equatable, Sendable {
    public let length: Int
    public let hash: String

    public init(length: Int, hash: String) {
        self.length = length
        self.hash = hash
    }
}

public struct DataCleaningAssistResponse: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let privacyMode: String
    public let suggestions: [DataCleaningAssistSuggestion]

    public init(
        schemaVersion: Int = 1,
        privacyMode: String = "hashed_suggestions_v1",
        suggestions: [DataCleaningAssistSuggestion]
    ) {
        self.schemaVersion = schemaVersion
        self.privacyMode = privacyMode
        self.suggestions = suggestions
    }
}

public enum DataCleaningAssistSuggestionKind: String, Codable, Sendable {
    case merchantNormalization
}

public struct DataCleaningAssistSuggestion: Codable, Equatable, Sendable {
    public let kind: DataCleaningAssistSuggestionKind
    public let candidateMerchantHash: String
    public let targetMerchantHash: String
    public let confidence: Double
    public let reasonCode: String

    public init(
        kind: DataCleaningAssistSuggestionKind,
        candidateMerchantHash: String,
        targetMerchantHash: String,
        confidence: Double,
        reasonCode: String
    ) {
        self.kind = kind
        self.candidateMerchantHash = candidateMerchantHash
        self.targetMerchantHash = targetMerchantHash
        self.confidence = confidence
        self.reasonCode = reasonCode
    }
}

public struct DataCleaningAssistRequestContext: Equatable, Sendable {
    public let userEnabledCloudAssist: Bool
    public let isProActive: Bool
    public let lastRequestedAt: Date?
    public let backoffUntil: Date?
    public let forceRefresh: Bool

    public init(
        userEnabledCloudAssist: Bool,
        isProActive: Bool,
        lastRequestedAt: Date? = nil,
        backoffUntil: Date? = nil,
        forceRefresh: Bool = false
    ) {
        self.userEnabledCloudAssist = userEnabledCloudAssist
        self.isProActive = isProActive
        self.lastRequestedAt = lastRequestedAt
        self.backoffUntil = backoffUntil
        self.forceRefresh = forceRefresh
    }
}

public enum DataCleaningAssistRequestDecisionReason: String, Codable, Equatable, Sendable {
    case allowed
    case disabledByUser
    case requiresPro
    case insufficientHistory
    case coolingDown
    case backoffActive
}

public struct DataCleaningAssistRequestDecision: Equatable, Sendable {
    public let isAllowed: Bool
    public let reason: DataCleaningAssistRequestDecisionReason
    public let nextEligibleAt: Date?

    public init(
        isAllowed: Bool,
        reason: DataCleaningAssistRequestDecisionReason,
        nextEligibleAt: Date? = nil
    ) {
        self.isAllowed = isAllowed
        self.reason = reason
        self.nextEligibleAt = nextEligibleAt
    }
}

public struct DataCleaningAssistRequestPolicy: Equatable, Sendable {
    public let minimumTransactionCount: Int
    public let cooldownInterval: TimeInterval

    public init(
        minimumTransactionCount: Int = 8,
        cooldownInterval: TimeInterval = 21_600
    ) {
        self.minimumTransactionCount = max(1, minimumTransactionCount)
        self.cooldownInterval = max(0, cooldownInterval)
    }

    public func evaluate(
        payload: DataCleaningAssistPayload,
        context: DataCleaningAssistRequestContext,
        now: Date = Date()
    ) -> DataCleaningAssistRequestDecision {
        guard context.userEnabledCloudAssist else {
            return blocked(.disabledByUser)
        }
        guard context.isProActive else {
            return blocked(.requiresPro)
        }
        guard payload.schemaVersion == 1,
              payload.privacyMode == "hashed_aggregate_v1",
              payload.transactionCount >= minimumTransactionCount,
              payload.merchantFeatureCount > 0 else {
            return blocked(.insufficientHistory)
        }
        if let backoffUntil = context.backoffUntil, backoffUntil > now {
            return blocked(.backoffActive, nextEligibleAt: backoffUntil)
        }
        if !context.forceRefresh,
           let lastRequestedAt = context.lastRequestedAt,
           cooldownInterval > 0 {
            let nextEligibleAt = lastRequestedAt.addingTimeInterval(cooldownInterval)
            if nextEligibleAt > now {
                return blocked(.coolingDown, nextEligibleAt: nextEligibleAt)
            }
        }
        return DataCleaningAssistRequestDecision(isAllowed: true, reason: .allowed)
    }

    private func blocked(
        _ reason: DataCleaningAssistRequestDecisionReason,
        nextEligibleAt: Date? = nil
    ) -> DataCleaningAssistRequestDecision {
        DataCleaningAssistRequestDecision(
            isAllowed: false,
            reason: reason,
            nextEligibleAt: nextEligibleAt
        )
    }
}

public struct DataCleaningAssistSuggestionMapper: Sendable {
    private let minimumConfidence: Double
    private let minimumTargetTransactionCount: Int

    public init(
        minimumConfidence: Double = 0.75,
        minimumTargetTransactionCount: Int = 2
    ) {
        self.minimumConfidence = minimumConfidence
        self.minimumTargetTransactionCount = minimumTargetTransactionCount
    }

    public func map(
        response: DataCleaningAssistResponse,
        transactions: [Transaction],
        ignoredPreviewIDs: Set<String> = []
    ) -> DataCleaningPreviewSnapshot {
        guard response.schemaVersion == 1, response.privacyMode == "hashed_suggestions_v1" else {
            return DataCleaningPreviewSnapshot(items: [])
        }

        let grouped = Dictionary(grouping: transactions) { transaction in
            DataCleaningAssistFingerprint.merchantHash(transaction.merchant)
        }
        var seenIDs: Set<String> = []
        let items = response.suggestions.compactMap { suggestion -> DataCleaningPreviewItem? in
            guard suggestion.kind == .merchantNormalization,
                  suggestion.confidence >= minimumConfidence,
                  suggestion.candidateMerchantHash != suggestion.targetMerchantHash,
                  let candidateTransactions = grouped[suggestion.candidateMerchantHash],
                  let targetTransactions = grouped[suggestion.targetMerchantHash],
                  targetTransactions.count >= minimumTargetTransactionCount else {
                return nil
            }

            let id = "workerMerchantNormalization:\(suggestion.candidateMerchantHash)->\(suggestion.targetMerchantHash)"
            guard !ignoredPreviewIDs.contains(id), !seenIDs.contains(id) else { return nil }
            seenIDs.insert(id)

            let currentMerchant = representativeMerchant(from: candidateTransactions)
            let targetMerchant = representativeMerchant(from: targetTransactions)
            guard currentMerchant != targetMerchant else { return nil }

            let affectedIDs = candidateTransactions
                .sorted { lhs, rhs in
                    if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                .map(\.id)

            return DataCleaningPreviewItem(
                id: id,
                kind: .merchantAlias,
                title: currentMerchant,
                subtitle: "\(affectedIDs.count)",
                currentValue: currentMerchant,
                proposedValue: targetMerchant,
                affectedTransactionIDs: affectedIDs,
                score: suggestion.confidence,
                reason: "worker assist merchant normalization"
            )
        }

        return DataCleaningPreviewSnapshot(items: items)
    }

    private func representativeMerchant(from transactions: [Transaction]) -> String {
        let counts = Dictionary(grouping: transactions) { transaction in
            transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return counts
            .filter { !$0.key.isEmpty }
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
                if lhs.key.count != rhs.key.count { return lhs.key.count < rhs.key.count }
                return lhs.key < rhs.key
            }
            .first?.key ?? ""
    }
}

public struct DataCleaningAssistPayloadBuilder: Sendable {
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    public func build(
        transactions: [Transaction],
        merchantAliases: [String: String],
        categoryCorrections: [String: TransactionCategory]
    ) -> DataCleaningAssistPayload {
        let merchantGroups = Dictionary(grouping: transactions) { transaction in
            DataCleaningAssistFingerprint.normalizedMerchantKey(transaction.merchant)
        }
        let aliasHashes = hashedAliasTargets(merchantAliases)
        let categoryCorrectionsByHash = hashedCategoryCorrections(categoryCorrections)

        let features = merchantGroups
            .filter { !$0.key.isEmpty }
            .map { normalizedKey, groupedTransactions in
                merchantFeature(
                    normalizedKey: normalizedKey,
                    transactions: groupedTransactions,
                    aliasTargetHash: aliasHashes[DataCleaningAssistFingerprint.stableHashID(normalizedKey)],
                    correctedCategory: categoryCorrectionsByHash[DataCleaningAssistFingerprint.stableHashID(normalizedKey)]
                )
            }
            .sorted { lhs, rhs in
                if lhs.transactionCount != rhs.transactionCount {
                    return lhs.transactionCount > rhs.transactionCount
                }
                return lhs.merchantKeyHash < rhs.merchantKeyHash
            }

        return DataCleaningAssistPayload(
            generatedAt: now(),
            transactionCount: transactions.count,
            merchantFeatureCount: features.count,
            aliasRuleCount: merchantAliases.count,
            categoryCorrectionCount: categoryCorrections.count,
            merchantFeatures: features
        )
    }

    private func merchantFeature(
        normalizedKey: String,
        transactions: [Transaction],
        aliasTargetHash: String?,
        correctedCategory: String?
    ) -> DataCleaningMerchantFeature {
        DataCleaningMerchantFeature(
            merchantKeyHash: DataCleaningAssistFingerprint.stableHashID(normalizedKey),
            normalizedLength: normalizedKey.count,
            transactionCount: transactions.count,
            categoryCounts: counted(transactions.map(\.category)),
            sourceCounts: counted(transactions.map(\.source)),
            amountBuckets: counted(transactions.map { amountBucket(for: $0.amount) }),
            prefixHashes: prefixHashes(for: normalizedKey),
            aliasTargetHash: aliasTargetHash,
            correctedCategory: correctedCategory
        )
    }

    private func hashedAliasTargets(_ aliases: [String: String]) -> [String: String] {
        let pairs: [(String, String)] = aliases.compactMap { original, alias in
            let originalKey = DataCleaningAssistFingerprint.normalizedMerchantKey(original)
            let aliasKey = DataCleaningAssistFingerprint.normalizedMerchantKey(alias)
            guard !originalKey.isEmpty, !aliasKey.isEmpty else { return nil }
            return (
                DataCleaningAssistFingerprint.stableHashID(originalKey),
                DataCleaningAssistFingerprint.stableHashID(aliasKey)
            )
        }
        return Dictionary(pairs, uniquingKeysWith: stablePreferredValue)
    }

    private func hashedCategoryCorrections(_ corrections: [String: TransactionCategory]) -> [String: String] {
        let pairs: [(String, String)] = corrections.compactMap { merchant, category in
            let key = DataCleaningAssistFingerprint.normalizedMerchantKey(merchant)
            guard !key.isEmpty else { return nil }
            return (DataCleaningAssistFingerprint.stableHashID(key), category.rawValue)
        }
        return Dictionary(pairs, uniquingKeysWith: stablePreferredValue)
    }

    private func stablePreferredValue(_ lhs: String, _ rhs: String) -> String {
        lhs <= rhs ? lhs : rhs
    }

    private func prefixHashes(for normalizedKey: String) -> [DataCleaningMerchantPrefixHash] {
        guard normalizedKey.count >= 4 else { return [] }
        return (4...normalizedKey.count).map { length in
            let prefix = String(normalizedKey.prefix(length))
            return DataCleaningMerchantPrefixHash(length: length, hash: DataCleaningAssistFingerprint.stableHashID(prefix))
        }
    }

    private func amountBucket(for amount: Double) -> String {
        let value = abs(amount)
        switch value {
        case ..<10:
            return "0_10"
        case ..<30:
            return "10_30"
        case ..<100:
            return "30_100"
        case ..<500:
            return "100_500"
        default:
            return "500_plus"
        }
    }

    private func counted(_ values: [String]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            counts[normalized, default: 0] += 1
        }
        return counts
    }

}

private enum DataCleaningAssistFingerprint {
    static func merchantHash(_ merchant: String) -> String {
        stableHashID(normalizedMerchantKey(merchant))
    }

    static func normalizedMerchantKey(_ merchant: String) -> String {
        merchant
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    static func stableHashID(_ value: String) -> String {
        "m_" + stableHashHex(Data(value.utf8))
    }

    private static func stableHashHex(_ data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", CUnsignedLongLong(hash))
    }
}
