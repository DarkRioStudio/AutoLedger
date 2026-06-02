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
    case recordSaveRejected(recordName: String, fieldSummary: String, message: String)
    case recordDeleteRejected(recordName: String, message: String)

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
        case let .recordSaveRejected(recordName, fieldSummary, message):
            return "CloudKit rejected record save \(recordName). Fields: \(fieldSummary). Error: \(message)"
        case let .recordDeleteRejected(recordName, message):
            return "CloudKit rejected record delete \(recordName). Error: \(message)"
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

        var savedRecordNames: [String] = []
        var deletedRecordNames: [String] = []

        for record in recordsToSave {
            let partial: LedgerCloudKitPushResult
            do {
                partial = try await modifyRecords(
                    recordsToSave: [record],
                    recordIDsToDelete: [],
                    dryRunResult: dryRunResult
                )
            } catch {
                throw LedgerCloudKitSyncError.recordSaveRejected(
                    recordName: record.recordID.recordName,
                    fieldSummary: Self.fieldSummary(for: record),
                    message: Self.describe(error)
                )
            }
            savedRecordNames.append(contentsOf: partial.savedRecordNames)
        }

        for recordID in recordIDsToDelete {
            let partial: LedgerCloudKitPushResult
            do {
                partial = try await modifyRecords(
                    recordsToSave: [],
                    recordIDsToDelete: [recordID],
                    dryRunResult: dryRunResult
                )
            } catch {
                throw LedgerCloudKitSyncError.recordDeleteRejected(
                    recordName: recordID.recordName,
                    message: Self.describe(error)
                )
            }
            deletedRecordNames.append(contentsOf: partial.deletedRecordNames)
        }

        return LedgerCloudKitPushResult(
            savedRecordNames: savedRecordNames.sorted(),
            deletedRecordNames: deletedRecordNames.sorted(),
            upsertCount: dryRunResult.upsertCount,
            tombstoneCount: dryRunResult.tombstoneCount,
            expiredTombstoneCount: dryRunResult.expiredTombstoneCount
        )
    }

    func fetchAllTransactionRecords() async throws -> [LedgerTransactionSyncPayload] {
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

        return try await fetchTransactionRecords(cursor: nil, accumulated: [])
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

    static func describe(_ error: Error) -> String {
        if let syncError = error as? LedgerCloudKitSyncError,
           let description = syncError.errorDescription {
            return description
        }

        let nsError = error as NSError
        var parts: [String] = []

        if nsError.domain == CKError.errorDomain,
           let code = CKError.Code(rawValue: nsError.code) {
            parts.append("CKError \(nsError.code) (\(Self.ckErrorName(code)))")
        } else {
            parts.append("\(nsError.domain) \(nsError.code)")
        }

        if !nsError.localizedDescription.isEmpty {
            parts.append(nsError.localizedDescription)
        }
        if let failureReason = nsError.localizedFailureReason, !failureReason.isEmpty {
            parts.append(failureReason)
        }
        if let serverDescription = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
           serverDescription != nsError.localizedDescription {
            parts.append(serverDescription)
        }
        if let partialErrors = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
           let first = partialErrors.first {
            let key = String(describing: first.key)
            parts.append("partial[\(key)]: \(describe(first.value))")
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            parts.append("underlying: \(describe(underlying))")
        }

        return parts.joined(separator: " | ")
    }

    private static func fieldSummary(for record: CKRecord) -> String {
        record.allKeys().sorted().map { key in
            let value = record[key]
            if let string = value as? NSString {
                return "\(key)=String(\(string.length))"
            }
            if let number = value as? NSNumber {
                return "\(key)=Number(\(String(cString: number.objCType)))"
            }
            if value is NSDate {
                return "\(key)=Date"
            }
            if let value {
                return "\(key)=\(String(describing: type(of: value)))"
            } else {
                return "\(key)=nil"
            }
        }.joined(separator: ", ")
    }

    private static func ckErrorName(_ code: CKError.Code) -> String {
        switch code {
        case .internalError: return "internalError"
        case .partialFailure: return "partialFailure"
        case .networkUnavailable: return "networkUnavailable"
        case .networkFailure: return "networkFailure"
        case .badContainer: return "badContainer"
        case .serviceUnavailable: return "serviceUnavailable"
        case .requestRateLimited: return "requestRateLimited"
        case .missingEntitlement: return "missingEntitlement"
        case .notAuthenticated: return "notAuthenticated"
        case .permissionFailure: return "permissionFailure"
        case .unknownItem: return "unknownItem"
        case .invalidArguments: return "invalidArguments"
        case .resultsTruncated: return "resultsTruncated"
        case .serverRecordChanged: return "serverRecordChanged"
        case .serverRejectedRequest: return "serverRejectedRequest"
        case .assetFileNotFound: return "assetFileNotFound"
        case .assetFileModified: return "assetFileModified"
        case .incompatibleVersion: return "incompatibleVersion"
        case .constraintViolation: return "constraintViolation"
        case .operationCancelled: return "operationCancelled"
        case .changeTokenExpired: return "changeTokenExpired"
        case .batchRequestFailed: return "batchRequestFailed"
        case .zoneBusy: return "zoneBusy"
        case .badDatabase: return "badDatabase"
        case .quotaExceeded: return "quotaExceeded"
        case .zoneNotFound: return "zoneNotFound"
        case .limitExceeded: return "limitExceeded"
        case .userDeletedZone: return "userDeletedZone"
        case .tooManyParticipants: return "tooManyParticipants"
        case .alreadyShared: return "alreadyShared"
        case .referenceViolation: return "referenceViolation"
        case .managedAccountRestricted: return "managedAccountRestricted"
        case .participantMayNeedVerification: return "participantMayNeedVerification"
        case .serverResponseLost: return "serverResponseLost"
        case .assetNotAvailable: return "assetNotAvailable"
        @unknown default: return "unknown(\(code.rawValue))"
        }
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

    private func fetchTransactionRecords(
        cursor: CKQueryOperation.Cursor?,
        accumulated: [LedgerTransactionSyncPayload]
    ) async throws -> [LedgerTransactionSyncPayload] {
        try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                let query = CKQuery(
                    recordType: CloudLedgerSyncSchema.RecordType.transaction,
                    predicate: NSPredicate(value: true)
                )
                operation = CKQueryOperation(query: query)
            }

            var records = accumulated
            operation.recordFetchedBlock = { record in
                if let payload = Self.mapPayload(from: record) {
                    records.append(payload)
                }
            }
            operation.queryCompletionBlock = { cursor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let cursor {
                    Task {
                        do {
                            let next = try await fetchTransactionRecords(cursor: cursor, accumulated: records)
                            continuation.resume(returning: next)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } else {
                    continuation.resume(returning: records)
                }
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

    private static func mapPayload(from record: CKRecord) -> LedgerTransactionSyncPayload? {
        guard
            let transactionIDString = record[CloudLedgerSyncSchema.Field.transactionID] as? String,
            let transactionID = UUID(uuidString: transactionIDString),
            let merchant = record[CloudLedgerSyncSchema.Field.merchant] as? String,
            let amountNumber = record[CloudLedgerSyncSchema.Field.amount] as? NSNumber,
            let occurredAt = record[CloudLedgerSyncSchema.Field.occurredAt] as? Date,
            let category = record[CloudLedgerSyncSchema.Field.category] as? String,
            let source = record[CloudLedgerSyncSchema.Field.source] as? String,
            let note = record[CloudLedgerSyncSchema.Field.note] as? String,
            let updatedAt = record[CloudLedgerSyncSchema.Field.updatedAt] as? Date,
            let syncRevisionNumber = record[CloudLedgerSyncSchema.Field.syncRevision] as? NSNumber,
            let deviceID = record[CloudLedgerSyncSchema.Field.deviceID] as? String,
            let conflictStateString = record[CloudLedgerSyncSchema.Field.conflictState] as? String
        else {
            return nil
        }

        return LedgerTransactionSyncPayload(
            recordName: record.recordID.recordName,
            transactionID: transactionID,
            merchant: merchant,
            amount: amountNumber.doubleValue,
            occurredAt: occurredAt,
            category: category,
            source: source,
            note: note,
            updatedAt: updatedAt,
            syncRevision: syncRevisionNumber.intValue,
            deviceID: deviceID,
            idempotencyKey: record[CloudLedgerSyncSchema.Field.idempotencyKey] as? String,
            deletedAt: record[CloudLedgerSyncSchema.Field.deletedAt] as? Date,
            conflictState: SyncConflictState(rawValue: conflictStateString) ?? .clean
        )
    }
}
