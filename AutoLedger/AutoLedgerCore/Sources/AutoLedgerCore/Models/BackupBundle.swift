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
    public let categoryCorrections: [BackupCategoryCorrection]
    public let customCategories: [String]
    public let customSources: [String]
    public let merchantAliases: [String: String]
    public let subscriptionMetadata: BackupSubscriptionMetadata
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
        categoryCorrections: [BackupCategoryCorrection],
        customCategories: [String],
        customSources: [String],
        merchantAliases: [String: String],
        subscriptionMetadata: BackupSubscriptionMetadata,
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
        self.categoryCorrections = categoryCorrections
        self.customCategories = customCategories
        self.customSources = customSources
        self.merchantAliases = merchantAliases
        self.subscriptionMetadata = subscriptionMetadata
        self.appSettings = appSettings
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

    public init(
        transactionCount: Int,
        deletedTransactionCount: Int,
        subscriptionCount: Int,
        categoryCorrectionCount: Int,
        customCategoryCount: Int,
        customSourceCount: Int,
        merchantAliasCount: Int
    ) {
        self.transactionCount = transactionCount
        self.deletedTransactionCount = deletedTransactionCount
        self.subscriptionCount = subscriptionCount
        self.categoryCorrectionCount = categoryCorrectionCount
        self.customCategoryCount = customCategoryCount
        self.customSourceCount = customSourceCount
        self.merchantAliasCount = merchantAliasCount
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
            note: note
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

    public init(annualPriceOverrides: [String: Double] = [:], notes: [String: String] = [:]) {
        self.annualPriceOverrides = annualPriceOverrides
        self.notes = notes
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
    case emptyBundle

    public var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            return "备份格式版本 \(version) 暂不支持。"
        case let .duplicateTransactionId(id):
            return "备份中存在重复账单 ID：\(id.uuidString)。"
        case let .duplicateSubscriptionId(id):
            return "备份中存在重复订阅 ID：\(id.uuidString)。"
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

        if bundle.transactions.isEmpty &&
            bundle.subscriptions.isEmpty &&
            bundle.categoryCorrections.isEmpty &&
            bundle.customCategories.isEmpty &&
            bundle.customSources.isEmpty &&
            bundle.merchantAliases.isEmpty {
            throw BackupValidationError.emptyBundle
        }
    }
}
