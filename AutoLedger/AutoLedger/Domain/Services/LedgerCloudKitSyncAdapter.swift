import AutoLedgerCore
import CloudKit
import Foundation

enum LedgerCloudKitSyncMode: Equatable {
    case disabled
    case dryRun
    case live
}

enum LedgerCloudKitSyncError: LocalizedError, Equatable {
    case disabled
    case liveModeRequired
    case liveModeRequiresManualValidation
    case accountUnavailable(LedgerCloudKitAccountState)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Ledger sync is disabled."
        case .liveModeRequired:
            return "CloudKit push requires live sync mode."
        case .liveModeRequiresManualValidation:
            return "CloudKit live sync requires capability, provisioning, and Xcode Cloud validation first."
        case let .accountUnavailable(state):
            return "CloudKit account is unavailable: \(state.rawValue)."
        }
    }
}

enum LedgerCloudKitAccountState: String, Equatable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine
    case unknown
}

struct LedgerCloudKitAccountCheck: Equatable {
    let state: LedgerCloudKitAccountState
    let message: String

    var canUsePrivateDatabase: Bool {
        state == .available
    }
}

enum LedgerCloudKitFieldValue: Equatable {
    case string(String)
    case double(Double)
    case int(Int)
    case date(Date)
}

struct LedgerCloudKitMappedRecord: Equatable {
    let recordType: String
    let recordName: String
    let fields: [String: LedgerCloudKitFieldValue]
}

struct LedgerCloudKitDryRunResult: Equatable {
    let mode: LedgerCloudKitSyncMode
    let upsertCount: Int
    let tombstoneCount: Int
    let expiredTombstoneCount: Int
    let mappedRecords: [LedgerCloudKitMappedRecord]
}

struct LedgerCloudKitPushResult: Equatable {
    let savedRecordNames: [String]
    let deletedRecordNames: [String]
    let upsertCount: Int
    let tombstoneCount: Int
    let expiredTombstoneCount: Int
}

@MainActor
struct LedgerCloudKitSyncAdapter {
    let mode: LedgerCloudKitSyncMode
    let allowsLiveCloudKitWrites: Bool

    private let container: CKContainer
    private let databaseScope: CKDatabase.Scope

    init(
        mode: LedgerCloudKitSyncMode = .disabled,
        allowsLiveCloudKitWrites: Bool = false,
        container: CKContainer = .default(),
        databaseScope: CKDatabase.Scope = .private
    ) {
        self.mode = mode
        self.allowsLiveCloudKitWrites = allowsLiveCloudKitWrites
        self.container = container
        self.databaseScope = databaseScope
    }

    func preparePush(batch: LedgerSyncPushBatch) throws -> LedgerCloudKitDryRunResult {
        switch mode {
        case .disabled:
            throw LedgerCloudKitSyncError.disabled
        case .live:
            guard allowsLiveCloudKitWrites else {
                throw LedgerCloudKitSyncError.liveModeRequiresManualValidation
            }
            return makeDryRunResult(for: batch)
        case .dryRun:
            return makeDryRunResult(for: batch)
        }
    }

    func checkAccountStatus() async -> LedgerCloudKitAccountCheck {
        do {
            let status = try await container.accountStatus()
            return Self.mapAccountStatus(status)
        } catch {
            return LedgerCloudKitAccountCheck(
                state: .couldNotDetermine,
                message: "CloudKit account status could not be determined."
            )
        }
    }

    func push(batch: LedgerSyncPushBatch) async throws -> LedgerCloudKitPushResult {
        guard mode == .live else {
            throw LedgerCloudKitSyncError.liveModeRequired
        }
        guard allowsLiveCloudKitWrites else {
            throw LedgerCloudKitSyncError.liveModeRequiresManualValidation
        }

        let accountCheck = await checkAccountStatus()
        guard accountCheck.canUsePrivateDatabase else {
            throw LedgerCloudKitSyncError.accountUnavailable(accountCheck.state)
        }

        let dryRunResult = makeDryRunResult(for: batch)
        let recordsToSave = dryRunResult.mappedRecords.map(makeCKRecord)
        let recordIDsToDelete = batch.expiredTombstoneIDs.map {
            CKRecord.ID(recordName: CloudLedgerSyncSchema.recordName(for: $0))
        }

        guard !recordsToSave.isEmpty || !recordIDsToDelete.isEmpty else {
            return LedgerCloudKitPushResult(
                savedRecordNames: [],
                deletedRecordNames: [],
                upsertCount: dryRunResult.upsertCount,
                tombstoneCount: dryRunResult.tombstoneCount,
                expiredTombstoneCount: dryRunResult.expiredTombstoneCount
            )
        }

        return try await modifyRecords(
            recordsToSave: recordsToSave,
            recordIDsToDelete: recordIDsToDelete,
            dryRunResult: dryRunResult
        )
    }

    func makeCKRecord(from mappedRecord: LedgerCloudKitMappedRecord) -> CKRecord {
        let recordID = CKRecord.ID(recordName: mappedRecord.recordName)
        let record = CKRecord(recordType: mappedRecord.recordType, recordID: recordID)

        for (key, value) in mappedRecord.fields {
            switch value {
            case let .string(string):
                record[key] = string as NSString
            case let .double(double):
                record[key] = NSNumber(value: double)
            case let .int(int):
                record[key] = NSNumber(value: int)
            case let .date(date):
                record[key] = date as NSDate
            }
        }

        return record
    }

    private var database: CKDatabase {
        switch databaseScope {
        case .private:
            return container.privateCloudDatabase
        case .public:
            return container.publicCloudDatabase
        case .shared:
            return container.sharedCloudDatabase
        @unknown default:
            return container.privateCloudDatabase
        }
    }

    private func makeDryRunResult(for batch: LedgerSyncPushBatch) -> LedgerCloudKitDryRunResult {
        let records = (batch.upserts + batch.tombstones).map(Self.mapRecord)
        return LedgerCloudKitDryRunResult(
            mode: mode,
            upsertCount: batch.upserts.count,
            tombstoneCount: batch.tombstones.count,
            expiredTombstoneCount: batch.expiredTombstoneIDs.count,
            mappedRecords: records
        )
    }

    private func modifyRecords(
        recordsToSave: [CKRecord],
        recordIDsToDelete: [CKRecord.ID],
        dryRunResult: LedgerCloudKitDryRunResult
    ) async throws -> LedgerCloudKitPushResult {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(
                recordsToSave: recordsToSave,
                recordIDsToDelete: recordIDsToDelete
            )
            operation.savePolicy = .changedKeys
            operation.isAtomic = false
            operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let savedRecordNames = (savedRecords ?? []).map(\.recordID.recordName).sorted()
                let deletedRecordNames = (deletedRecordIDs ?? []).map(\.recordName).sorted()
                continuation.resume(returning: LedgerCloudKitPushResult(
                    savedRecordNames: savedRecordNames,
                    deletedRecordNames: deletedRecordNames,
                    upsertCount: dryRunResult.upsertCount,
                    tombstoneCount: dryRunResult.tombstoneCount,
                    expiredTombstoneCount: dryRunResult.expiredTombstoneCount
                ))
            }

            database.add(operation)
        }
    }

    private static func mapRecord(_ payload: LedgerTransactionSyncPayload) -> LedgerCloudKitMappedRecord {
        var fields: [String: LedgerCloudKitFieldValue] = [
            CloudLedgerSyncSchema.Field.transactionID: .string(payload.transactionID.uuidString),
            CloudLedgerSyncSchema.Field.merchant: .string(payload.merchant),
            CloudLedgerSyncSchema.Field.amount: .double(payload.amount),
            CloudLedgerSyncSchema.Field.occurredAt: .date(payload.occurredAt),
            CloudLedgerSyncSchema.Field.category: .string(payload.category),
            CloudLedgerSyncSchema.Field.source: .string(payload.source),
            CloudLedgerSyncSchema.Field.note: .string(payload.note),
            CloudLedgerSyncSchema.Field.updatedAt: .date(payload.updatedAt),
            CloudLedgerSyncSchema.Field.syncRevision: .int(payload.syncRevision),
            CloudLedgerSyncSchema.Field.deviceID: .string(payload.deviceID),
            CloudLedgerSyncSchema.Field.conflictState: .string(payload.conflictState.rawValue)
        ]

        if let idempotencyKey = payload.idempotencyKey {
            fields[CloudLedgerSyncSchema.Field.idempotencyKey] = .string(idempotencyKey)
        }
        if let deletedAt = payload.deletedAt {
            fields[CloudLedgerSyncSchema.Field.deletedAt] = .date(deletedAt)
        }

        return LedgerCloudKitMappedRecord(
            recordType: CloudLedgerSyncSchema.RecordType.transaction,
            recordName: payload.recordName,
            fields: fields
        )
    }

    private static func mapAccountStatus(_ status: CKAccountStatus) -> LedgerCloudKitAccountCheck {
        switch status {
        case .available:
            return LedgerCloudKitAccountCheck(
                state: .available,
                message: "CloudKit account is available."
            )
        case .noAccount:
            return LedgerCloudKitAccountCheck(
                state: .noAccount,
                message: "No iCloud account is available on this device."
            )
        case .restricted:
            return LedgerCloudKitAccountCheck(
                state: .restricted,
                message: "The iCloud account is restricted."
            )
        case .temporarilyUnavailable:
            return LedgerCloudKitAccountCheck(
                state: .temporarilyUnavailable,
                message: "CloudKit is temporarily unavailable."
            )
        case .couldNotDetermine:
            return LedgerCloudKitAccountCheck(
                state: .couldNotDetermine,
                message: "CloudKit account status could not be determined."
            )
        @unknown default:
            return LedgerCloudKitAccountCheck(
                state: .unknown,
                message: "CloudKit account status is unknown."
            )
        }
    }
}
