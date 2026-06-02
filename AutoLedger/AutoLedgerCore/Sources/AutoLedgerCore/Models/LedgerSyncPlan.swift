import Foundation

public enum CloudLedgerSyncSchema {
    public enum RecordType {
        public static let transaction = "LedgerTransaction"
    }

    public enum Field {
        public static let transactionID = "transactionID"
        public static let merchant = "merchant"
        public static let amount = "amount"
        public static let occurredAt = "occurredAt"
        public static let category = "category"
        public static let source = "source"
        public static let note = "note"
        public static let updatedAt = "updatedAt"
        public static let syncRevision = "syncRevision"
        public static let deviceID = "deviceID"
        public static let idempotencyKey = "idempotencyKey"
        public static let deletedAt = "deletedAt"
        public static let conflictState = "conflictState"
    }

    public static func recordName(for transactionID: UUID) -> String {
        "transaction-\(transactionID.uuidString.lowercased())"
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
                note: note
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
            return record.metadata.updatedAt > changedAfter
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
