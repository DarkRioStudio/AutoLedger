import Foundation

public enum CloudLedgerSyncSchema {
    public enum RecordType {
        public static let transaction = "LedgerTransaction"
        public static let configuration = "LedgerConfiguration"
        public static let dashboardSnapshot = "LedgerDashboardSnapshot"
        public static let hotelStayRecord = "LedgerHotelStayRecord"
        public static let hotelStayDraft = "LedgerHotelStayDraft"
    }

    public enum Field {
        public static let transactionID = "transactionID"
        public static let hotelStayID = "hotelStayID"
        public static let hotelStayDraftID = "hotelStayDraftID"
        public static let merchant = "merchant"
        public static let amount = "amount"
        public static let occurredAt = "occurredAt"
        public static let category = "category"
        public static let source = "source"
        public static let note = "note"
        public static let ledgerID = "ledgerID"
        public static let hotelStayRecordID = "hotelStayRecordID"
        public static let ledgerCurrencyCode = "ledgerCurrencyCode"
        public static let originalAmount = "originalAmount"
        public static let originalCurrencyCode = "originalCurrencyCode"
        public static let exchangeRate = "exchangeRate"
        public static let exchangeRateDate = "exchangeRateDate"
        public static let exchangeRateProvider = "exchangeRateProvider"
        public static let updatedAt = "updatedAt"
        public static let syncRevision = "syncRevision"
        public static let deviceID = "deviceID"
        public static let idempotencyKey = "idempotencyKey"
        public static let deletedAt = "deletedAt"
        public static let conflictState = "conflictState"
        public static let payloadJSON = "payloadJSON"
        public static let sourcePDFAsset = "sourcePDFAsset"
    }

    public static func recordName(for transactionID: UUID) -> String {
        "transaction-\(transactionID.uuidString.lowercased())"
    }

    public static func hotelStayRecordName(for hotelStayID: UUID) -> String {
        "hotel-stay-\(hotelStayID.uuidString.lowercased())"
    }

    public static func hotelStayDraftRecordName(for draftID: UUID) -> String {
        "hotel-stay-draft-\(draftID.uuidString.lowercased())"
    }

    public static func configurationRecordName() -> String {
        "ledger-configuration-default"
    }

    public static func syncManifestRecordName() -> String {
        "ledger-sync-manifest-default"
    }

    public static func dashboardSnapshotRecordName() -> String {
        "ledger-dashboard-snapshot-default"
    }
}

public struct LedgerCloudSyncManifest: Codable, Equatable, Sendable {
    public let recordName: String
    public let updatedAt: Date
    public let deviceID: String
    public let transactionRecordNames: [String]
    public let hotelStayRecordNames: [String]
    public let hotelStayDraftRecordNames: [String]

    public init(
        recordName: String = CloudLedgerSyncSchema.syncManifestRecordName(),
        updatedAt: Date,
        deviceID: String,
        transactionRecordNames: [String],
        hotelStayRecordNames: [String],
        hotelStayDraftRecordNames: [String]
    ) {
        self.recordName = recordName
        self.updatedAt = updatedAt
        self.deviceID = deviceID
        self.transactionRecordNames = Self.normalizedRecordNames(transactionRecordNames)
        self.hotelStayRecordNames = Self.normalizedRecordNames(hotelStayRecordNames)
        self.hotelStayDraftRecordNames = Self.normalizedRecordNames(hotelStayDraftRecordNames)
    }

    public func merged(with remote: LedgerCloudSyncManifest?) -> LedgerCloudSyncManifest {
        guard let remote else { return self }
        return LedgerCloudSyncManifest(
            recordName: recordName,
            updatedAt: updatedAt >= remote.updatedAt ? updatedAt : remote.updatedAt,
            deviceID: deviceID,
            transactionRecordNames: transactionRecordNames + remote.transactionRecordNames,
            hotelStayRecordNames: hotelStayRecordNames + remote.hotelStayRecordNames,
            hotelStayDraftRecordNames: hotelStayDraftRecordNames + remote.hotelStayDraftRecordNames
        )
    }

    private static func normalizedRecordNames(_ names: [String]) -> [String] {
        Array(Set(names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
            .sorted()
    }
}

public struct LedgerConfigurationSyncPayload: Codable, Equatable, Sendable {
    public let recordName: String
    public let updatedAt: Date
    public let deviceID: String
    public let subscriptions: [Subscription]
    public let categoryCorrections: [BackupCategoryCorrection]
    public let customCategories: [String]
    public let customSources: [String]
    public let merchantAliases: [String: String]
    public let merchantAliasDeletedKeys: [String]
    public let ledgerProfiles: [LedgerProfile]
    public let defaultWriteLedgerID: String?
    public let subscriptionMetadata: BackupSubscriptionMetadata
    public let pendingActionDecisions: [String: PendingActionDecision]
    public let appSettings: BackupAppSettings

    public init(
        recordName: String = CloudLedgerSyncSchema.configurationRecordName(),
        updatedAt: Date,
        deviceID: String,
        subscriptions: [Subscription],
        categoryCorrections: [BackupCategoryCorrection],
        customCategories: [String],
        customSources: [String],
        merchantAliases: [String: String],
        merchantAliasDeletedKeys: [String] = [],
        ledgerProfiles: [LedgerProfile] = [],
        defaultWriteLedgerID: String? = nil,
        subscriptionMetadata: BackupSubscriptionMetadata,
        pendingActionDecisions: [String: PendingActionDecision] = [:],
        appSettings: BackupAppSettings
    ) {
        self.recordName = recordName
        self.updatedAt = updatedAt
        self.deviceID = deviceID
        self.subscriptions = subscriptions
        self.categoryCorrections = categoryCorrections
        self.customCategories = customCategories
        self.customSources = customSources
        self.merchantAliases = merchantAliases
        self.merchantAliasDeletedKeys = Self.normalizedMerchantAliasDeletedKeys(merchantAliasDeletedKeys)
        self.ledgerProfiles = ledgerProfiles
        self.defaultWriteLedgerID = defaultWriteLedgerID
        self.subscriptionMetadata = subscriptionMetadata
        self.pendingActionDecisions = PendingActionDecision.normalizedDictionary(pendingActionDecisions)
        self.appSettings = appSettings
    }

    private enum CodingKeys: String, CodingKey {
        case recordName
        case updatedAt
        case deviceID
        case subscriptions
        case categoryCorrections
        case customCategories
        case customSources
        case merchantAliases
        case merchantAliasDeletedKeys
        case ledgerProfiles
        case defaultWriteLedgerID
        case subscriptionMetadata
        case pendingActionDecisions
        case appSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordName = try container.decode(String.self, forKey: .recordName)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deviceID = try container.decode(String.self, forKey: .deviceID)
        subscriptions = try container.decode([Subscription].self, forKey: .subscriptions)
        categoryCorrections = try container.decode([BackupCategoryCorrection].self, forKey: .categoryCorrections)
        customCategories = try container.decode([String].self, forKey: .customCategories)
        customSources = try container.decode([String].self, forKey: .customSources)
        merchantAliases = try container.decode([String: String].self, forKey: .merchantAliases)
        merchantAliasDeletedKeys = Self.normalizedMerchantAliasDeletedKeys(
            try container.decodeIfPresent([String].self, forKey: .merchantAliasDeletedKeys) ?? []
        )
        ledgerProfiles = try container.decodeIfPresent([LedgerProfile].self, forKey: .ledgerProfiles) ?? []
        defaultWriteLedgerID = try container.decodeIfPresent(String.self, forKey: .defaultWriteLedgerID)
        subscriptionMetadata = try container.decode(BackupSubscriptionMetadata.self, forKey: .subscriptionMetadata)
        pendingActionDecisions = PendingActionDecision.normalizedDictionary(
            try container.decodeIfPresent(
                [String: PendingActionDecision].self,
                forKey: .pendingActionDecisions
            ) ?? [:]
        )
        appSettings = try container.decode(BackupAppSettings.self, forKey: .appSettings)
    }

    private static func normalizedMerchantAliasDeletedKeys(_ keys: [String]) -> [String] {
        Array(Set(keys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
            .sorted()
    }
}

public enum LedgerConfigurationSyncPolicy {
    public static func shouldPreserveLocalConfiguration(
        local: LedgerConfigurationSyncPayload,
        remote: LedgerConfigurationSyncPayload
    ) -> Bool {
        local.hasUserConfigurationContent && !remote.hasUserConfigurationContent
    }

    public static func merge(
        local: LedgerConfigurationSyncPayload,
        remote: LedgerConfigurationSyncPayload,
        updatedAt: Date? = nil
    ) -> LedgerConfigurationSyncPayload {
        let ledgerProfiles = mergeLedgerProfiles(local.ledgerProfiles, remote.ledgerProfiles)
        let defaultWriteLedgerID = resolvedDefaultWriteLedgerID(
            preferred: remote.defaultWriteLedgerID,
            fallback: local.defaultWriteLedgerID,
            profiles: ledgerProfiles
        )

        let merchantAliasDeletedKeys = mergeStrings(local.merchantAliasDeletedKeys, remote.merchantAliasDeletedKeys)

        return LedgerConfigurationSyncPayload(
            recordName: remote.recordName,
            updatedAt: updatedAt ?? remote.updatedAt,
            deviceID: remote.deviceID,
            subscriptions: mergeSubscriptions(local.subscriptions, remote.subscriptions),
            categoryCorrections: mergeCategoryCorrections(local.categoryCorrections, remote.categoryCorrections),
            customCategories: mergeStrings(local.customCategories, remote.customCategories),
            customSources: mergeStrings(local.customSources, remote.customSources),
            merchantAliases: mergeMerchantAliases(
                local.merchantAliases,
                remote.merchantAliases,
                deletedKeys: merchantAliasDeletedKeys
            ),
            merchantAliasDeletedKeys: merchantAliasDeletedKeys,
            ledgerProfiles: ledgerProfiles,
            defaultWriteLedgerID: defaultWriteLedgerID,
            subscriptionMetadata: BackupSubscriptionMetadata(
                annualPriceOverrides: mergeDictionaries(
                    local.subscriptionMetadata.annualPriceOverrides,
                    remote.subscriptionMetadata.annualPriceOverrides
                ),
                notes: mergeDictionaries(local.subscriptionMetadata.notes, remote.subscriptionMetadata.notes),
                anomalyDecisions: mergeSubscriptionAnomalyDecisions(
                    local.subscriptionMetadata.anomalyDecisions,
                    remote.subscriptionMetadata.anomalyDecisions
                )
            ),
            pendingActionDecisions: mergePendingActionDecisions(
                local.pendingActionDecisions,
                remote.pendingActionDecisions
            ),
            appSettings: remote.appSettings
        )
    }

    public static func hasDifferentUserConfigurationContent(
        _ lhs: LedgerConfigurationSyncPayload,
        _ rhs: LedgerConfigurationSyncPayload
    ) -> Bool {
        lhs.subscriptions != rhs.subscriptions ||
            lhs.categoryCorrections != rhs.categoryCorrections ||
            lhs.customCategories != rhs.customCategories ||
            lhs.customSources != rhs.customSources ||
            lhs.merchantAliases != rhs.merchantAliases ||
            lhs.merchantAliasDeletedKeys != rhs.merchantAliasDeletedKeys ||
            lhs.ledgerProfiles != rhs.ledgerProfiles ||
            lhs.defaultWriteLedgerID != rhs.defaultWriteLedgerID ||
            lhs.subscriptionMetadata != rhs.subscriptionMetadata ||
            lhs.pendingActionDecisions != rhs.pendingActionDecisions
    }

    private static func mergeLedgerProfiles(
        _ local: [LedgerProfile],
        _ remote: [LedgerProfile]
    ) -> [LedgerProfile] {
        var merged: [String: LedgerProfile] = [:]
        for profile in local + remote {
            let id = profile.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { continue }

            if let existing = merged[id], existing.updatedAt > profile.updatedAt {
                continue
            }
            merged[id] = profile
        }

        if merged.isEmpty {
            merged[TodaySpendingSummary.defaultLedgerID] = LedgerProfile.defaultLocal(
                createdAt: Date(timeIntervalSince1970: 0)
            )
        }

        if merged.values.allSatisfy(\.isArchived) {
            let createdAt = merged.values.map(\.createdAt).min() ?? Date(timeIntervalSince1970: 0)
            merged[TodaySpendingSummary.defaultLedgerID] = LedgerProfile.defaultLocal(createdAt: createdAt)
        }

        let defaultCandidates = merged.values.filter { $0.isDefault && !$0.isArchived }
        let selectedDefaultID: String? = {
            if let newestDefault = defaultCandidates.max(by: { $0.updatedAt < $1.updatedAt }) {
                return newestDefault.id
            }
            if merged[TodaySpendingSummary.defaultLedgerID]?.isArchived == false {
                return TodaySpendingSummary.defaultLedgerID
            }
            return merged.values
                .filter { !$0.isArchived }
                .sorted(by: compareLedgerProfiles)
                .first?
                .id
        }()

        return merged.values
            .map { profile in
                ledgerProfile(
                    profile,
                    isDefault: selectedDefaultID == profile.id && !profile.isArchived
                )
            }
            .sorted(by: compareLedgerProfiles)
    }

    private static func resolvedDefaultWriteLedgerID(
        preferred: String?,
        fallback: String?,
        profiles: [LedgerProfile]
    ) -> String? {
        let activeIDs = Set(profiles.filter { !$0.isArchived }.map(\.id))
        for candidate in [preferred, fallback] {
            let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if activeIDs.contains(trimmed) {
                return trimmed
            }
        }
        if activeIDs.contains(TodaySpendingSummary.defaultLedgerID) {
            return TodaySpendingSummary.defaultLedgerID
        }
        return profiles.first { $0.isDefault && !$0.isArchived }?.id ??
            profiles.first { !$0.isArchived }?.id
    }

    private static func compareLedgerProfiles(_ lhs: LedgerProfile, _ rhs: LedgerProfile) -> Bool {
        if lhs.sortOrder == rhs.sortOrder {
            if lhs.createdAt == rhs.createdAt {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.sortOrder < rhs.sortOrder
    }

    private static func ledgerProfile(_ profile: LedgerProfile, isDefault: Bool) -> LedgerProfile {
        LedgerProfile(
            id: profile.id,
            name: profile.name,
            iconName: profile.iconName,
            colorName: profile.colorName,
            currency: profile.currency,
            isDefault: isDefault,
            sortOrder: profile.sortOrder,
            archivedAt: profile.archivedAt,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt
        )
    }

    private static func mergeSubscriptions(
        _ local: [Subscription],
        _ remote: [Subscription]
    ) -> [Subscription] {
        var merged = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for subscription in remote {
            merged[subscription.id] = subscription
        }
        return merged.values.sorted { lhs, rhs in
            if lhs.nextChargedAt == rhs.nextChargedAt {
                return lhs.merchant < rhs.merchant
            }
            return lhs.nextChargedAt < rhs.nextChargedAt
        }
    }

    private static func mergeCategoryCorrections(
        _ local: [BackupCategoryCorrection],
        _ remote: [BackupCategoryCorrection]
    ) -> [BackupCategoryCorrection] {
        var merged = Dictionary(uniqueKeysWithValues: local.map { ($0.merchant, $0.category) })
        for correction in remote {
            merged[correction.merchant] = correction.category
        }
        return merged
            .map { BackupCategoryCorrection(merchant: $0.key, category: $0.value) }
            .sorted { $0.merchant < $1.merchant }
    }

    private static func mergeStrings(_ local: [String], _ remote: [String]) -> [String] {
        var seen: Set<String> = []
        return (local + remote)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    private static func mergeDictionaries<Value>(
        _ local: [String: Value],
        _ remote: [String: Value]
    ) -> [String: Value] {
        var merged = local
        for (key, value) in remote {
            merged[key] = value
        }
        return merged
    }

    private static func mergeSubscriptionAnomalyDecisions(
        _ local: [String: SubscriptionAnomalyDecisionRecord],
        _ remote: [String: SubscriptionAnomalyDecisionRecord]
    ) -> [String: SubscriptionAnomalyDecisionRecord] {
        var merged = local
        for (id, remoteDecision) in remote {
            guard let localDecision = merged[id] else {
                merged[id] = remoteDecision
                continue
            }
            if remoteDecision.updatedAt >= localDecision.updatedAt {
                merged[id] = remoteDecision
            }
        }
        return merged
    }

    private static func mergePendingActionDecisions(
        _ local: [String: PendingActionDecision],
        _ remote: [String: PendingActionDecision]
    ) -> [String: PendingActionDecision] {
        var merged = local
        for (id, remoteDecision) in remote {
            guard let localDecision = merged[id] else {
                merged[id] = remoteDecision
                continue
            }
            if remoteDecision.isPreferred(over: localDecision) {
                merged[id] = remoteDecision
            }
        }
        return merged
    }

    private static func mergeMerchantAliases(
        _ local: [String: String],
        _ remote: [String: String],
        deletedKeys: [String]
    ) -> [String: String] {
        let deleted = Set(deletedKeys)
        var merged = local
        for (key, value) in remote where !deleted.contains(key) {
            merged[key] = value
        }
        for key in deleted {
            merged.removeValue(forKey: key)
        }
        return merged
    }
}

public extension LedgerConfigurationSyncPayload {
    var hasUserConfigurationContent: Bool {
        !subscriptions.isEmpty ||
            !categoryCorrections.isEmpty ||
            !customCategories.isEmpty ||
            !customSources.isEmpty ||
            !merchantAliases.isEmpty ||
            !merchantAliasDeletedKeys.isEmpty ||
            ledgerProfiles.contains { profile in
                profile.id != TodaySpendingSummary.defaultLedgerID ||
                    profile.name != TodaySpendingSummary.defaultLedgerName ||
                    profile.iconName != "wallet.pass" ||
                    profile.colorName != "accent" ||
                    profile.currency != nil ||
                    !profile.isDefault ||
                    profile.sortOrder != 0 ||
                    profile.archivedAt != nil
            } ||
            (defaultWriteLedgerID != nil && defaultWriteLedgerID != TodaySpendingSummary.defaultLedgerID) ||
            !subscriptionMetadata.annualPriceOverrides.isEmpty ||
            !subscriptionMetadata.notes.isEmpty ||
            !subscriptionMetadata.anomalyDecisions.isEmpty ||
            !pendingActionDecisions.isEmpty
    }
}

public struct LedgerHotelStayRecordSyncPayload: Codable, Equatable, Sendable {
    public let recordName: String
    public let hotelStayID: UUID
    public let hotelStayRecord: HotelStayRecord?
    public let updatedAt: Date
    public let deviceID: String
    public let deletedAt: Date?

    public init(
        recordName: String,
        hotelStayID: UUID,
        hotelStayRecord: HotelStayRecord?,
        updatedAt: Date,
        deviceID: String,
        deletedAt: Date? = nil
    ) {
        self.recordName = recordName
        self.hotelStayID = hotelStayID
        self.hotelStayRecord = hotelStayRecord
        self.updatedAt = updatedAt
        self.deviceID = deviceID
        self.deletedAt = deletedAt
    }

    public init(record: HotelStayRecord, deviceID: String) {
        self.init(
            recordName: CloudLedgerSyncSchema.hotelStayRecordName(for: record.id),
            hotelStayID: record.id,
            hotelStayRecord: record,
            updatedAt: record.updatedAt,
            deviceID: deviceID,
            deletedAt: nil
        )
    }

    public static func tombstone(
        id: UUID,
        deletedAt: Date,
        deviceID: String
    ) -> LedgerHotelStayRecordSyncPayload {
        LedgerHotelStayRecordSyncPayload(
            recordName: CloudLedgerSyncSchema.hotelStayRecordName(for: id),
            hotelStayID: id,
            hotelStayRecord: nil,
            updatedAt: deletedAt,
            deviceID: deviceID,
            deletedAt: deletedAt
        )
    }

    public var isTombstone: Bool {
        deletedAt != nil
    }
}

public struct LedgerHotelStayDraftSyncPayload: Codable, Equatable, Sendable {
    public let recordName: String
    public let draftID: UUID
    public let hotelStayDraft: HotelStayDraft?
    public let updatedAt: Date
    public let deviceID: String
    public let deletedAt: Date?

    public init(
        recordName: String,
        draftID: UUID,
        hotelStayDraft: HotelStayDraft?,
        updatedAt: Date,
        deviceID: String,
        deletedAt: Date? = nil
    ) {
        self.recordName = recordName
        self.draftID = draftID
        self.hotelStayDraft = hotelStayDraft
        self.updatedAt = updatedAt
        self.deviceID = deviceID
        self.deletedAt = deletedAt
    }

    public init(draft: HotelStayDraft, deviceID: String) {
        self.init(
            recordName: CloudLedgerSyncSchema.hotelStayDraftRecordName(for: draft.id),
            draftID: draft.id,
            hotelStayDraft: draft,
            updatedAt: draft.updatedAt,
            deviceID: deviceID,
            deletedAt: nil
        )
    }

    public static func tombstone(
        id: UUID,
        deletedAt: Date,
        deviceID: String
    ) -> LedgerHotelStayDraftSyncPayload {
        LedgerHotelStayDraftSyncPayload(
            recordName: CloudLedgerSyncSchema.hotelStayDraftRecordName(for: id),
            draftID: id,
            hotelStayDraft: nil,
            updatedAt: deletedAt,
            deviceID: deviceID,
            deletedAt: deletedAt
        )
    }

    public var isTombstone: Bool {
        deletedAt != nil
    }
}

public struct LedgerTransactionSyncPayload: Codable, Equatable, Sendable {
    public let recordName: String
    public let transactionID: UUID
    public let merchant: String
    public let amount: Double
    public let occurredAt: Date
    public let category: String
    public let source: String
    public let note: String
    public let ledgerID: String?
    public let hotelStayRecordID: UUID?
    public let ledgerCurrencyCode: String?
    public let originalAmount: Double?
    public let originalCurrencyCode: String?
    public let exchangeRate: Double?
    public let exchangeRateDate: String?
    public let exchangeRateProvider: String?
    public let updatedAt: Date
    public let syncRevision: Int
    public let deviceID: String
    public let idempotencyKey: String?
    public let deletedAt: Date?
    public let conflictState: SyncConflictState

    public init(
        recordName: String,
        transactionID: UUID,
        merchant: String,
        amount: Double,
        occurredAt: Date,
        category: String,
        source: String,
        note: String,
        ledgerID: String? = nil,
        hotelStayRecordID: UUID? = nil,
        ledgerCurrencyCode: String? = nil,
        originalAmount: Double? = nil,
        originalCurrencyCode: String? = nil,
        exchangeRate: Double? = nil,
        exchangeRateDate: String? = nil,
        exchangeRateProvider: String? = nil,
        updatedAt: Date,
        syncRevision: Int,
        deviceID: String,
        idempotencyKey: String?,
        deletedAt: Date?,
        conflictState: SyncConflictState
    ) {
        self.recordName = recordName
        self.transactionID = transactionID
        self.merchant = merchant
        self.amount = amount
        self.occurredAt = occurredAt
        self.category = category
        self.source = source
        self.note = note
        self.ledgerID = ledgerID
        self.hotelStayRecordID = hotelStayRecordID
        self.ledgerCurrencyCode = ledgerCurrencyCode
        self.originalAmount = originalAmount
        self.originalCurrencyCode = originalCurrencyCode
        self.exchangeRate = exchangeRate
        self.exchangeRateDate = exchangeRateDate
        self.exchangeRateProvider = exchangeRateProvider
        self.updatedAt = updatedAt
        self.syncRevision = syncRevision
        self.deviceID = deviceID
        self.idempotencyKey = idempotencyKey
        self.deletedAt = deletedAt
        self.conflictState = conflictState
    }

    public init(record: TransactionSyncRecord) {
        self.recordName = CloudLedgerSyncSchema.recordName(for: record.transaction.id)
        self.transactionID = record.transaction.id
        self.merchant = record.transaction.merchant
        self.amount = record.transaction.amount
        self.occurredAt = record.transaction.occurredAt
        self.category = record.transaction.category
        self.source = record.transaction.source
        self.note = record.transaction.note
        self.ledgerID = record.transaction.ledgerID
        self.hotelStayRecordID = record.transaction.hotelStayRecordID
        self.ledgerCurrencyCode = record.transaction.ledgerCurrencyCode
        self.originalAmount = record.transaction.originalAmount
        self.originalCurrencyCode = record.transaction.originalCurrencyCode
        self.exchangeRate = record.transaction.exchangeRate
        self.exchangeRateDate = record.transaction.exchangeRateDate
        self.exchangeRateProvider = record.transaction.exchangeRateProvider
        self.updatedAt = record.metadata.updatedAt
        self.syncRevision = record.metadata.syncRevision
        self.deviceID = record.metadata.deviceID
        self.idempotencyKey = record.metadata.idempotencyKey
        self.deletedAt = record.metadata.deletedAt
        self.conflictState = record.metadata.conflictState
    }

    public var isTombstone: Bool {
        deletedAt != nil
    }

    public var syncRecord: TransactionSyncRecord {
        TransactionSyncRecord(
            transaction: Transaction(
                id: transactionID,
                merchant: merchant,
                amount: amount,
                occurredAt: occurredAt,
                categoryLabel: category,
                sourceLabel: source,
                note: note,
                ledgerID: ledgerID,
                hotelStayRecordID: hotelStayRecordID,
                ledgerCurrencyCode: ledgerCurrencyCode,
                originalAmount: originalAmount,
                originalCurrencyCode: originalCurrencyCode,
                exchangeRate: exchangeRate,
                exchangeRateDate: exchangeRateDate,
                exchangeRateProvider: exchangeRateProvider
            ),
            metadata: TransactionSyncMetadata(
                transactionID: transactionID,
                updatedAt: updatedAt,
                syncRevision: syncRevision,
                deviceID: deviceID,
                idempotencyKey: idempotencyKey,
                deletedAt: deletedAt,
                conflictState: conflictState
            )
        )
    }
}

public struct LedgerSyncPushBatch: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let changedAfter: Date?
    public let upserts: [LedgerTransactionSyncPayload]
    public let tombstones: [LedgerTransactionSyncPayload]
    public let expiredTombstoneIDs: [UUID]

    public var isEmpty: Bool {
        upserts.isEmpty && tombstones.isEmpty && expiredTombstoneIDs.isEmpty
    }
}

public enum LedgerSyncPlanner {
    public static func makePushBatch(
        from records: [TransactionSyncRecord],
        changedAfter: Date? = nil,
        tombstoneRetentionDays: Int = 30,
        referenceDate: Date = .now
    ) -> LedgerSyncPushBatch {
        let changedRecords = records.filter { record in
            guard let changedAfter else { return true }
            return record.metadata.updatedAt >= changedAfter
        }

        let retentionSeconds = TimeInterval(max(tombstoneRetentionDays, 0) * 24 * 60 * 60)
        let retentionStart = referenceDate.addingTimeInterval(-retentionSeconds)

        var upserts: [LedgerTransactionSyncPayload] = []
        var tombstones: [LedgerTransactionSyncPayload] = []
        var expiredTombstoneIDs: [UUID] = []

        for record in changedRecords {
            let payload = LedgerTransactionSyncPayload(record: record)
            if let deletedAt = payload.deletedAt {
                if deletedAt < retentionStart {
                    expiredTombstoneIDs.append(payload.transactionID)
                } else {
                    tombstones.append(payload)
                }
            } else {
                upserts.append(payload)
            }
        }

        return LedgerSyncPushBatch(
            generatedAt: referenceDate,
            changedAfter: changedAfter,
            upserts: upserts.sorted { $0.updatedAt < $1.updatedAt },
            tombstones: tombstones.sorted { $0.updatedAt < $1.updatedAt },
            expiredTombstoneIDs: expiredTombstoneIDs.sorted { $0.uuidString < $1.uuidString }
        )
    }
}
