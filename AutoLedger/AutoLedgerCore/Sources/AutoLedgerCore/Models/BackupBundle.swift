import Foundation

public struct BackupBundle: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let bundleId: UUID
    public let exportedAt: Date
    public let app: BackupAppInfo
    public let device: BackupDeviceInfo
    public let summary: BackupSummary
    public let transactions: [BackupTransaction]
    public let subscriptions: [Subscription]
    public let hotelStayRecords: [HotelStayRecord]
    public let hotelStayDrafts: [HotelStayDraft]
    public let categoryCorrections: [BackupCategoryCorrection]
    public let customCategories: [String]
    public let customSources: [String]
    public let merchantAliases: [String: String]
    public let ledgerProfiles: [LedgerProfile]
    public let defaultWriteLedgerID: String?
    public let subscriptionMetadata: BackupSubscriptionMetadata
    public let pendingActionDecisions: [String: PendingActionDecision]
    public let appSettings: BackupAppSettings

    public init(
        schemaVersion: Int = 1,
        bundleId: UUID = UUID(),
        exportedAt: Date = .now,
        app: BackupAppInfo,
        device: BackupDeviceInfo,
        summary: BackupSummary,
        transactions: [BackupTransaction],
        subscriptions: [Subscription],
        hotelStayRecords: [HotelStayRecord] = [],
        hotelStayDrafts: [HotelStayDraft] = [],
        categoryCorrections: [BackupCategoryCorrection],
        customCategories: [String],
        customSources: [String],
        merchantAliases: [String: String],
        ledgerProfiles: [LedgerProfile] = [],
        defaultWriteLedgerID: String? = nil,
        subscriptionMetadata: BackupSubscriptionMetadata,
        pendingActionDecisions: [String: PendingActionDecision] = [:],
        appSettings: BackupAppSettings
    ) {
        self.schemaVersion = schemaVersion
        self.bundleId = bundleId
        self.exportedAt = exportedAt
        self.app = app
        self.device = device
        self.summary = summary
        self.transactions = transactions
        self.subscriptions = subscriptions
        self.hotelStayRecords = hotelStayRecords
        self.hotelStayDrafts = hotelStayDrafts
        self.categoryCorrections = categoryCorrections
        self.customCategories = customCategories
        self.customSources = customSources
        self.merchantAliases = merchantAliases
        self.ledgerProfiles = ledgerProfiles
        self.defaultWriteLedgerID = defaultWriteLedgerID
        self.subscriptionMetadata = subscriptionMetadata
        self.pendingActionDecisions = PendingActionDecision.normalizedDictionary(pendingActionDecisions)
        self.appSettings = appSettings
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case bundleId
        case exportedAt
        case app
        case device
        case summary
        case transactions
        case subscriptions
        case hotelStayRecords
        case hotelStayDrafts
        case categoryCorrections
        case customCategories
        case customSources
        case merchantAliases
        case ledgerProfiles
        case defaultWriteLedgerID
        case subscriptionMetadata
        case pendingActionDecisions
        case appSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        bundleId = try container.decode(UUID.self, forKey: .bundleId)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        app = try container.decode(BackupAppInfo.self, forKey: .app)
        device = try container.decode(BackupDeviceInfo.self, forKey: .device)
        summary = try container.decode(BackupSummary.self, forKey: .summary)
        transactions = try container.decode([BackupTransaction].self, forKey: .transactions)
        subscriptions = try container.decode([Subscription].self, forKey: .subscriptions)
        hotelStayRecords = try container.decodeIfPresent([HotelStayRecord].self, forKey: .hotelStayRecords) ?? []
        hotelStayDrafts = try container.decodeIfPresent([HotelStayDraft].self, forKey: .hotelStayDrafts) ?? []
        categoryCorrections = try container.decode([BackupCategoryCorrection].self, forKey: .categoryCorrections)
        customCategories = try container.decode([String].self, forKey: .customCategories)
        customSources = try container.decode([String].self, forKey: .customSources)
        merchantAliases = try container.decode([String: String].self, forKey: .merchantAliases)
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
}

public struct BackupAppInfo: Codable, Equatable, Sendable {
    public let name: String
    public let version: String
    public let build: String

    public init(name: String, version: String, build: String) {
        self.name = name
        self.version = version
        self.build = build
    }
}

public struct BackupDeviceInfo: Codable, Equatable, Sendable {
    public let model: String
    public let systemName: String
    public let systemVersion: String

    public init(model: String, systemName: String, systemVersion: String) {
        self.model = model
        self.systemName = systemName
        self.systemVersion = systemVersion
    }
}

public struct BackupSummary: Codable, Equatable, Sendable {
    public let transactionCount: Int
    public let deletedTransactionCount: Int
    public let subscriptionCount: Int
    public let categoryCorrectionCount: Int
    public let customCategoryCount: Int
    public let customSourceCount: Int
    public let merchantAliasCount: Int
    public let hotelStayRecordCount: Int
    public let hotelStayDraftCount: Int
    public let ledgerProfileCount: Int

    public init(
        transactionCount: Int,
        deletedTransactionCount: Int,
        subscriptionCount: Int,
        categoryCorrectionCount: Int,
        customCategoryCount: Int,
        customSourceCount: Int,
        merchantAliasCount: Int,
        hotelStayRecordCount: Int = 0,
        hotelStayDraftCount: Int = 0,
        ledgerProfileCount: Int = 0
    ) {
        self.transactionCount = transactionCount
        self.deletedTransactionCount = deletedTransactionCount
        self.subscriptionCount = subscriptionCount
        self.categoryCorrectionCount = categoryCorrectionCount
        self.customCategoryCount = customCategoryCount
        self.customSourceCount = customSourceCount
        self.merchantAliasCount = merchantAliasCount
        self.hotelStayRecordCount = hotelStayRecordCount
        self.hotelStayDraftCount = hotelStayDraftCount
        self.ledgerProfileCount = ledgerProfileCount
    }

    private enum CodingKeys: String, CodingKey {
        case transactionCount
        case deletedTransactionCount
        case subscriptionCount
        case categoryCorrectionCount
        case customCategoryCount
        case customSourceCount
        case merchantAliasCount
        case hotelStayRecordCount
        case hotelStayDraftCount
        case ledgerProfileCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transactionCount = try container.decode(Int.self, forKey: .transactionCount)
        deletedTransactionCount = try container.decode(Int.self, forKey: .deletedTransactionCount)
        subscriptionCount = try container.decode(Int.self, forKey: .subscriptionCount)
        categoryCorrectionCount = try container.decode(Int.self, forKey: .categoryCorrectionCount)
        customCategoryCount = try container.decode(Int.self, forKey: .customCategoryCount)
        customSourceCount = try container.decode(Int.self, forKey: .customSourceCount)
        merchantAliasCount = try container.decode(Int.self, forKey: .merchantAliasCount)
        hotelStayRecordCount = try container.decodeIfPresent(Int.self, forKey: .hotelStayRecordCount) ?? 0
        hotelStayDraftCount = try container.decodeIfPresent(Int.self, forKey: .hotelStayDraftCount) ?? 0
        ledgerProfileCount = try container.decodeIfPresent(Int.self, forKey: .ledgerProfileCount) ?? 0
    }
}

public struct BackupTransaction: Codable, Equatable, Sendable {
    public let id: UUID
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
    public let deletedAt: Date?
    public let syncMetadata: TransactionSyncMetadata?

    public init(
        id: UUID,
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
        deletedAt: Date?,
        syncMetadata: TransactionSyncMetadata? = nil
    ) {
        self.id = id
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
        self.deletedAt = deletedAt
        self.syncMetadata = syncMetadata
    }

    public init(transaction: Transaction, deletedAt: Date? = nil) {
        self.init(
            id: transaction.id,
            merchant: transaction.merchant,
            amount: transaction.amount,
            occurredAt: transaction.occurredAt,
            category: transaction.category,
            source: transaction.source,
            note: transaction.note,
            ledgerID: transaction.ledgerID,
            hotelStayRecordID: transaction.hotelStayRecordID,
            ledgerCurrencyCode: transaction.ledgerCurrencyCode,
            originalAmount: transaction.originalAmount,
            originalCurrencyCode: transaction.originalCurrencyCode,
            exchangeRate: transaction.exchangeRate,
            exchangeRateDate: transaction.exchangeRateDate,
            exchangeRateProvider: transaction.exchangeRateProvider,
            deletedAt: deletedAt
        )
    }

    public var transaction: Transaction {
        Transaction(
            id: id,
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
        )
    }
}

public struct BackupCategoryCorrection: Codable, Equatable, Sendable {
    public let merchant: String
    public let category: TransactionCategory

    public init(merchant: String, category: TransactionCategory) {
        self.merchant = merchant
        self.category = category
    }
}

public struct BackupSubscriptionMetadata: Codable, Equatable, Sendable {
    public let annualPriceOverrides: [String: Double]
    public let notes: [String: String]
    public let anomalyDecisions: [String: SubscriptionAnomalyDecisionRecord]

    public init(
        annualPriceOverrides: [String: Double] = [:],
        notes: [String: String] = [:],
        anomalyDecisions: [String: SubscriptionAnomalyDecisionRecord] = [:]
    ) {
        self.annualPriceOverrides = annualPriceOverrides
        self.notes = notes
        self.anomalyDecisions = anomalyDecisions
    }

    private enum CodingKeys: String, CodingKey {
        case annualPriceOverrides
        case notes
        case anomalyDecisions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        annualPriceOverrides = try container.decodeIfPresent([String: Double].self, forKey: .annualPriceOverrides) ?? [:]
        notes = try container.decodeIfPresent([String: String].self, forKey: .notes) ?? [:]
        anomalyDecisions = try container.decodeIfPresent(
            [String: SubscriptionAnomalyDecisionRecord].self,
            forKey: .anomalyDecisions
        ) ?? [:]
    }
}

public struct BackupAppSettings: Codable, Equatable, Sendable {
    public let subscriptionReminderEnabled: Bool
    public let monthlyAnomalyThresholdPercent: Double
    public let llmEnhancementEnabled: Bool
    public let autoClipboardImportEnabled: Bool
    public let iCloudBackupEnabled: Bool

    public init(
        subscriptionReminderEnabled: Bool,
        monthlyAnomalyThresholdPercent: Double,
        llmEnhancementEnabled: Bool,
        autoClipboardImportEnabled: Bool,
        iCloudBackupEnabled: Bool
    ) {
        self.subscriptionReminderEnabled = subscriptionReminderEnabled
        self.monthlyAnomalyThresholdPercent = monthlyAnomalyThresholdPercent
        self.llmEnhancementEnabled = llmEnhancementEnabled
        self.autoClipboardImportEnabled = autoClipboardImportEnabled
        self.iCloudBackupEnabled = iCloudBackupEnabled
    }
}

public enum BackupValidationError: LocalizedError, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case duplicateTransactionId(UUID)
    case duplicateSubscriptionId(UUID)
    case duplicateHotelStayRecordId(UUID)
    case duplicateHotelStayDraftId(UUID)
    case duplicateLedgerProfileId(String)
    case emptyBundle

    public var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            return "备份格式版本 \(version) 暂不支持。"
        case let .duplicateTransactionId(id):
            return "备份中存在重复账单 ID：\(id.uuidString)。"
        case let .duplicateSubscriptionId(id):
            return "备份中存在重复订阅 ID：\(id.uuidString)。"
        case let .duplicateHotelStayRecordId(id):
            return "备份中存在重复酒店消费 ID：\(id.uuidString)。"
        case let .duplicateHotelStayDraftId(id):
            return "备份中存在重复酒店水单草稿 ID：\(id.uuidString)。"
        case let .duplicateLedgerProfileId(id):
            return "备份中存在重复账本 ID：\(id)。"
        case .emptyBundle:
            return "备份文件中没有可恢复的数据。"
        }
    }
}

public enum BackupValidator {
    public static func validate(_ bundle: BackupBundle) throws {
        guard bundle.schemaVersion == 1 else {
            throw BackupValidationError.unsupportedSchemaVersion(bundle.schemaVersion)
        }

        var transactionIds = Set<UUID>()
        for transaction in bundle.transactions {
            guard transactionIds.insert(transaction.id).inserted else {
                throw BackupValidationError.duplicateTransactionId(transaction.id)
            }
        }

        var subscriptionIds = Set<UUID>()
        for subscription in bundle.subscriptions {
            guard subscriptionIds.insert(subscription.id).inserted else {
                throw BackupValidationError.duplicateSubscriptionId(subscription.id)
            }
        }

        var hotelStayRecordIds = Set<UUID>()
        for record in bundle.hotelStayRecords {
            guard hotelStayRecordIds.insert(record.id).inserted else {
                throw BackupValidationError.duplicateHotelStayRecordId(record.id)
            }
        }

        var hotelStayDraftIds = Set<UUID>()
        for draft in bundle.hotelStayDrafts {
            guard hotelStayDraftIds.insert(draft.id).inserted else {
                throw BackupValidationError.duplicateHotelStayDraftId(draft.id)
            }
        }

        var ledgerProfileIds = Set<String>()
        for profile in bundle.ledgerProfiles {
            guard ledgerProfileIds.insert(profile.id).inserted else {
                throw BackupValidationError.duplicateLedgerProfileId(profile.id)
            }
        }

        if bundle.transactions.isEmpty &&
            bundle.subscriptions.isEmpty &&
            bundle.hotelStayRecords.isEmpty &&
            bundle.hotelStayDrafts.isEmpty &&
            bundle.categoryCorrections.isEmpty &&
            bundle.customCategories.isEmpty &&
            bundle.customSources.isEmpty &&
            bundle.merchantAliases.isEmpty &&
            bundle.ledgerProfiles.isEmpty {
            throw BackupValidationError.emptyBundle
        }
    }
}
