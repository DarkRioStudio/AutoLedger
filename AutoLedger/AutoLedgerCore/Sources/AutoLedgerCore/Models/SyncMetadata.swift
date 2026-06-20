import Foundation

public enum SyncConflictState: String, Codable, Equatable, Sendable {
    case clean
    case localPending
    case conflictPendingReview
}

public struct TransactionSyncMetadata: Codable, Equatable, Sendable {
    public let transactionID: UUID
    public let updatedAt: Date
    public let syncRevision: Int
    public let deviceID: String
    public let idempotencyKey: String?
    public let deletedAt: Date?
    public let conflictState: SyncConflictState

    public init(
        transactionID: UUID,
        updatedAt: Date,
        syncRevision: Int,
        deviceID: String,
        idempotencyKey: String? = nil,
        deletedAt: Date? = nil,
        conflictState: SyncConflictState = .clean
    ) {
        self.transactionID = transactionID
        self.updatedAt = updatedAt
        self.syncRevision = syncRevision
        self.deviceID = deviceID
        self.idempotencyKey = idempotencyKey
        self.deletedAt = deletedAt
        self.conflictState = conflictState
    }
}

public struct TransactionSyncRecord: Codable, Equatable, Sendable {
    public let transaction: Transaction
    public let metadata: TransactionSyncMetadata

    public init(transaction: Transaction, metadata: TransactionSyncMetadata) {
        self.transaction = transaction
        self.metadata = metadata
    }
}

public enum TransactionSyncResolution: Equatable, Sendable {
    case keepLocal
    case applyRemote
    case conflictPendingReview
}

public enum TransactionSyncApplyOutcome: Equatable, Sendable {
    case inserted
    case updated
    case deleted
    case keptLocal
    case conflictPendingReview
}

public struct TransactionSyncApplySummary: Equatable, Sendable {
    public var inserted: Int
    public var updated: Int
    public var deleted: Int
    public var keptLocal: Int
    public var conflicts: Int

    public init(
        inserted: Int = 0,
        updated: Int = 0,
        deleted: Int = 0,
        keptLocal: Int = 0,
        conflicts: Int = 0
    ) {
        self.inserted = inserted
        self.updated = updated
        self.deleted = deleted
        self.keptLocal = keptLocal
        self.conflicts = conflicts
    }

    public mutating func record(_ outcome: TransactionSyncApplyOutcome) {
        switch outcome {
        case .inserted:
            inserted += 1
        case .updated:
            updated += 1
        case .deleted:
            deleted += 1
        case .keptLocal:
            keptLocal += 1
        case .conflictPendingReview:
            conflicts += 1
        }
    }
}

public enum TransactionSyncConflictResolver {
    public static func resolve(
        local: TransactionSyncRecord,
        remote: TransactionSyncRecord
    ) -> TransactionSyncResolution {
        guard local.transaction.id == remote.transaction.id else {
            return .conflictPendingReview
        }

        if local.metadata.conflictState == .conflictPendingReview ||
            remote.metadata.conflictState == .conflictPendingReview {
            return .conflictPendingReview
        }

        if remote.metadata.updatedAt > local.metadata.updatedAt {
            return .applyRemote
        }
        if local.metadata.updatedAt > remote.metadata.updatedAt {
            return .keepLocal
        }

        if local.transaction == remote.transaction &&
            local.metadata.deletedAt == remote.metadata.deletedAt {
            return .keepLocal
        }

        if local.metadata.deviceID == remote.metadata.deviceID {
            if remote.metadata.syncRevision > local.metadata.syncRevision {
                return .applyRemote
            }
            if local.metadata.syncRevision > remote.metadata.syncRevision {
                return .keepLocal
            }
        }

        return .conflictPendingReview
    }
}
