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
            normalizedMerchantKey(transaction.merchant)
        }
        let aliasHashes = hashedAliasTargets(merchantAliases)
        let categoryCorrectionsByHash = hashedCategoryCorrections(categoryCorrections)

        let features = merchantGroups
            .filter { !$0.key.isEmpty }
            .map { normalizedKey, groupedTransactions in
                merchantFeature(
                    normalizedKey: normalizedKey,
                    transactions: groupedTransactions,
                    aliasTargetHash: aliasHashes[stableHashID(normalizedKey)],
                    correctedCategory: categoryCorrectionsByHash[stableHashID(normalizedKey)]
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
            merchantKeyHash: stableHashID(normalizedKey),
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
        Dictionary(
            uniqueKeysWithValues: aliases.compactMap { original, alias in
                let originalKey = normalizedMerchantKey(original)
                let aliasKey = normalizedMerchantKey(alias)
                guard !originalKey.isEmpty, !aliasKey.isEmpty else { return nil }
                return (stableHashID(originalKey), stableHashID(aliasKey))
            }
        )
    }

    private func hashedCategoryCorrections(_ corrections: [String: TransactionCategory]) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: corrections.compactMap { merchant, category in
                let key = normalizedMerchantKey(merchant)
                guard !key.isEmpty else { return nil }
                return (stableHashID(key), category.rawValue)
            }
        )
    }

    private func prefixHashes(for normalizedKey: String) -> [DataCleaningMerchantPrefixHash] {
        guard normalizedKey.count >= 4 else { return [] }
        return (4...normalizedKey.count).map { length in
            let prefix = String(normalizedKey.prefix(length))
            return DataCleaningMerchantPrefixHash(length: length, hash: stableHashID(prefix))
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

    private func normalizedMerchantKey(_ merchant: String) -> String {
        merchant
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func stableHashID(_ value: String) -> String {
        "m_" + stableHashHex(Data(value.utf8))
    }

    private func stableHashHex(_ data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", CUnsignedLongLong(hash))
    }
}
