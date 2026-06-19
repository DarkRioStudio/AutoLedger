import Foundation

public struct ExternalReceiptAssistCacheRecord: Codable, Equatable, Sendable {
    public let cacheKey: String
    public let provider: ExternalReceiptAssistProvider
    public let modelName: String?
    public let endpointFingerprint: String?
    public let source: ReceiptSource
    public let suggestion: ExternalReceiptAssistSuggestion
    public let createdAt: Date
    public let expiresAt: Date

    public init(
        cacheKey: String,
        provider: ExternalReceiptAssistProvider,
        modelName: String?,
        endpointFingerprint: String?,
        source: ReceiptSource,
        suggestion: ExternalReceiptAssistSuggestion,
        createdAt: Date,
        expiresAt: Date
    ) {
        self.cacheKey = cacheKey
        self.provider = provider
        self.modelName = modelName
        self.endpointFingerprint = endpointFingerprint
        self.source = source
        self.suggestion = suggestion
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

public struct ExternalReceiptAssistCachePolicy: Sendable {
    public static let defaultTTL: TimeInterval = 24 * 60 * 60
    public static let maximumRecordCount = 80

    public init() {}

    public func makeCacheKey(
        payload: ExternalReceiptAssistPayload,
        configuration: ExternalReceiptAssistConfiguration,
        sanitizedTextHash: String,
        endpointFingerprint: String?
    ) -> String {
        [
            "v1",
            payload.source.rawValue,
            configuration.provider.rawValue,
            normalized(configuration.modelName),
            normalized(endpointFingerprint),
            sanitizedTextHash
        ].joined(separator: "|")
    }

    public func makeRecord(
        suggestion: ExternalReceiptAssistSuggestion,
        cacheKey: String,
        payload: ExternalReceiptAssistPayload,
        configuration: ExternalReceiptAssistConfiguration,
        endpointFingerprint: String?,
        createdAt: Date,
        ttl: TimeInterval = Self.defaultTTL
    ) -> ExternalReceiptAssistCacheRecord {
        ExternalReceiptAssistCacheRecord(
            cacheKey: cacheKey,
            provider: configuration.provider,
            modelName: normalized(configuration.modelName),
            endpointFingerprint: normalized(endpointFingerprint),
            source: payload.source,
            suggestion: suggestion,
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(max(0, ttl))
        )
    }

    public func usableSuggestion(
        from record: ExternalReceiptAssistCacheRecord?,
        expectedCacheKey: String,
        now: Date
    ) -> ExternalReceiptAssistSuggestion? {
        guard let record,
              record.cacheKey == expectedCacheKey,
              record.expiresAt > now else {
            return nil
        }
        return record.suggestion
    }

    public func pruned(
        _ records: [String: ExternalReceiptAssistCacheRecord],
        now: Date,
        maximumRecordCount: Int = Self.maximumRecordCount
    ) -> [String: ExternalReceiptAssistCacheRecord] {
        let liveRecords = records
            .filter { $0.value.expiresAt > now }
            .sorted { lhs, rhs in
                if lhs.value.createdAt == rhs.value.createdAt {
                    return lhs.key < rhs.key
                }
                return lhs.value.createdAt > rhs.value.createdAt
            }

        return Dictionary(uniqueKeysWithValues: liveRecords.prefix(max(0, maximumRecordCount)).map { ($0.key, $0.value) })
    }

    private func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
