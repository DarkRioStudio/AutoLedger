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
    case recordSaveRejected(recordName: String, fieldSummary: String, probeSummary: String, message: String)
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
        case let .recordSaveRejected(recordName, fieldSummary, probeSummary, message):
            return "CloudKit rejected record save \(recordName). Probe: \(probeSummary). Fields: \(fieldSummary). Error: \(message)"
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
    case assetData(Data, filename: String)
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
    var assetFallbackRecordNames: [String] = []
}

@MainActor
struct LedgerCloudKitSyncAdapter {
    private static let operationRecordLimit = 100

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
        let recordsToSave = try dryRunResult.mappedRecords.map(makeCKRecord)
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

        for chunk in recordsToSave.chunked(into: Self.operationRecordLimit) {
            let partial: LedgerCloudKitPushResult
            do {
                partial = try await modifyRecords(
                    recordsToSave: chunk,
                    recordIDsToDelete: [],
                    dryRunResult: dryRunResult
                )
            } catch {
                let firstRecord = chunk[0]
                let probeSummary = await diagnoseMinimalSave(for: firstRecord, dryRunResult: dryRunResult)
                throw LedgerCloudKitSyncError.recordSaveRejected(
                    recordName: firstRecord.recordID.recordName,
                    fieldSummary: Self.fieldSummary(for: firstRecord),
                    probeSummary: probeSummary,
                    message: Self.describe(error)
                )
            }
            savedRecordNames.append(contentsOf: partial.savedRecordNames)
        }

        for chunk in recordIDsToDelete.chunked(into: Self.operationRecordLimit) {
            let partial: LedgerCloudKitPushResult
            do {
                partial = try await modifyRecords(
                    recordsToSave: [],
                    recordIDsToDelete: chunk,
                    dryRunResult: dryRunResult
                )
            } catch {
                throw LedgerCloudKitSyncError.recordDeleteRejected(
                    recordName: chunk[0].recordName,
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

        let manifest = try await fetchSyncManifest()
        return try await fetchAllTransactionRecords(recordNames: manifest?.transactionRecordNames ?? [])
    }

    func fetchAllTransactionRecords(recordNames: [String]) async throws -> [LedgerTransactionSyncPayload] {
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

        return try await fetchRecordsByID(
            recordNames: recordNames,
            mapRecord: Self.mapPayload
        )
    }

    func pushConfiguration(_ payload: LedgerConfigurationSyncPayload) async throws -> LedgerCloudKitPushResult {
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

        let mappedRecord = try Self.mapConfigurationRecord(payload)
        let dryRunResult = LedgerCloudKitDryRunResult(
            mode: mode,
            upsertCount: 1,
            tombstoneCount: 0,
            expiredTombstoneCount: 0,
            mappedRecords: [mappedRecord]
        )

        do {
            let record = try makeCKRecord(from: mappedRecord)
            return try await modifyRecords(
                recordsToSave: [record],
                recordIDsToDelete: [],
                dryRunResult: dryRunResult
            )
        } catch {
            throw LedgerCloudKitSyncError.recordSaveRejected(
                recordName: payload.recordName,
                fieldSummary: Self.fieldSummary(for: mappedRecord),
                probeSummary: "configuration-save",
                message: Self.describe(error)
            )
        }
    }

    func fetchConfigurationRecord() async throws -> LedgerConfigurationSyncPayload? {
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

        let recordID = CKRecord.ID(recordName: CloudLedgerSyncSchema.configurationRecordName())
        do {
            let record = try await database.record(for: recordID)
            return Self.mapConfigurationPayload(from: record)
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .unknownItem {
                return nil
            }
            throw error
        }
    }

    func pushSyncManifest(_ payload: LedgerCloudSyncManifest) async throws -> LedgerCloudKitPushResult {
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

        let mappedRecord = try Self.mapSyncManifestRecord(payload)
        let dryRunResult = LedgerCloudKitDryRunResult(
            mode: mode,
            upsertCount: 1,
            tombstoneCount: 0,
            expiredTombstoneCount: 0,
            mappedRecords: [mappedRecord]
        )

        do {
            let record = try makeCKRecord(from: mappedRecord)
            return try await modifyRecords(
                recordsToSave: [record],
                recordIDsToDelete: [],
                dryRunResult: dryRunResult
            )
        } catch {
            throw LedgerCloudKitSyncError.recordSaveRejected(
                recordName: payload.recordName,
                fieldSummary: Self.fieldSummary(for: mappedRecord),
                probeSummary: "sync-manifest-save",
                message: Self.describe(error)
            )
        }
    }

    func fetchSyncManifest() async throws -> LedgerCloudSyncManifest? {
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

        let recordID = CKRecord.ID(recordName: CloudLedgerSyncSchema.syncManifestRecordName())
        do {
            let record = try await database.record(for: recordID)
            return Self.mapSyncManifestPayload(from: record)
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .unknownItem {
                return nil
            }
            throw error
        }
    }

    func pushHotelStayArchive(
        records: [LedgerHotelStayRecordSyncPayload],
        drafts: [LedgerHotelStayDraftSyncPayload]
    ) async throws -> LedgerCloudKitPushResult {
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

        let mappedRecords = try records.map(Self.mapHotelStayRecord) + drafts.map(Self.mapHotelStayDraft)
        let dryRunResult = LedgerCloudKitDryRunResult(
            mode: mode,
            upsertCount: records.filter { !$0.isTombstone }.count + drafts.filter { !$0.isTombstone }.count,
            tombstoneCount: records.filter { $0.isTombstone }.count + drafts.filter { $0.isTombstone }.count,
            expiredTombstoneCount: 0,
            mappedRecords: mappedRecords
        )

        guard !mappedRecords.isEmpty else {
            return LedgerCloudKitPushResult(
                savedRecordNames: [],
                deletedRecordNames: [],
                upsertCount: 0,
                tombstoneCount: 0,
                expiredTombstoneCount: 0
            )
        }

        var savedRecordNames: [String] = []
        var assetFallbackRecordNames: [String] = []
        for chunk in mappedRecords.chunked(into: Self.operationRecordLimit) {
            let recordsToSave: [CKRecord]
            do {
                recordsToSave = try chunk.map { try makeCKRecord(from: $0) }
            } catch {
                let firstRecord = chunk[0]
                throw LedgerCloudKitSyncError.recordSaveRejected(
                    recordName: firstRecord.recordName,
                    fieldSummary: Self.fieldSummary(for: firstRecord),
                    probeSummary: "hotel-stay-archive-record-build",
                    message: Self.describe(error)
                )
            }

            do {
                let partial = try await modifyRecords(
                    recordsToSave: recordsToSave,
                    recordIDsToDelete: [],
                    dryRunResult: dryRunResult
                )
                savedRecordNames.append(contentsOf: partial.savedRecordNames)
            } catch {
                let firstRecord = chunk[0]
                let probeSummary = await diagnoseMinimalSave(for: recordsToSave[0], dryRunResult: dryRunResult)
                if Self.shouldRetryHotelStayArchiveWithoutPDFAssets(error, mappedRecords: chunk) {
                    do {
                        let fallback = try await retryHotelStayArchiveChunkWithoutPDFAssets(
                            chunk,
                            dryRunResult: dryRunResult
                        )
                        savedRecordNames.append(contentsOf: fallback.savedRecordNames)
                        assetFallbackRecordNames.append(contentsOf: fallback.assetFallbackRecordNames)
                        continue
                    } catch {
                        throw LedgerCloudKitSyncError.recordSaveRejected(
                            recordName: firstRecord.recordName,
                            fieldSummary: Self.fieldSummary(for: firstRecord),
                            probeSummary: "\(probeSummary); asset-fallback failed",
                            message: Self.describe(error)
                        )
                    }
                }
                throw LedgerCloudKitSyncError.recordSaveRejected(
                    recordName: firstRecord.recordName,
                    fieldSummary: Self.fieldSummary(for: firstRecord),
                    probeSummary: probeSummary,
                    message: Self.describe(error)
                )
            }
        }

        return LedgerCloudKitPushResult(
            savedRecordNames: savedRecordNames.sorted(),
            deletedRecordNames: [],
            upsertCount: dryRunResult.upsertCount,
            tombstoneCount: dryRunResult.tombstoneCount,
            expiredTombstoneCount: 0,
            assetFallbackRecordNames: assetFallbackRecordNames.sorted()
        )
    }

    func fetchAllHotelStayRecords() async throws -> [LedgerHotelStayRecordSyncPayload] {
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

        let manifest = try await fetchSyncManifest()
        return try await fetchAllHotelStayRecords(recordNames: manifest?.hotelStayRecordNames ?? [])
    }

    func fetchAllHotelStayRecords(recordNames: [String]) async throws -> [LedgerHotelStayRecordSyncPayload] {
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

        return try await fetchRecordsByID(
            recordNames: recordNames,
            mapRecord: Self.mapHotelStayRecordPayload
        )
    }

    func fetchAllHotelStayDrafts() async throws -> [LedgerHotelStayDraftSyncPayload] {
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

        let manifest = try await fetchSyncManifest()
        return try await fetchAllHotelStayDrafts(recordNames: manifest?.hotelStayDraftRecordNames ?? [])
    }

    func fetchAllHotelStayDrafts(recordNames: [String]) async throws -> [LedgerHotelStayDraftSyncPayload] {
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

        return try await fetchRecordsByID(
            recordNames: recordNames,
            mapRecord: Self.mapHotelStayDraftPayload
        )
    }

    func pushDashboardSnapshot(_ payload: LedgerDashboardCloudSnapshot) async throws -> LedgerCloudKitPushResult {
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

        let mappedRecord = try Self.mapDashboardSnapshotRecord(payload)
        let dryRunResult = LedgerCloudKitDryRunResult(
            mode: mode,
            upsertCount: 1,
            tombstoneCount: 0,
            expiredTombstoneCount: 0,
            mappedRecords: [mappedRecord]
        )

        do {
            let record = try makeCKRecord(from: mappedRecord)
            return try await modifyRecords(
                recordsToSave: [record],
                recordIDsToDelete: [],
                dryRunResult: dryRunResult
            )
        } catch {
            throw LedgerCloudKitSyncError.recordSaveRejected(
                recordName: payload.recordName,
                fieldSummary: Self.fieldSummary(for: mappedRecord),
                probeSummary: "dashboard-snapshot-save",
                message: Self.describe(error)
            )
        }
    }

    func makeCKRecord(from mappedRecord: LedgerCloudKitMappedRecord) throws -> CKRecord {
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
            case let .assetData(data, filename):
                let fileURL = try Self.writeTemporaryAssetFile(data: data, filename: filename)
                record[key] = CKAsset(fileURL: fileURL)
            }
        }

        return record
    }

    nonisolated static func describe(_ error: Error) -> String {
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
        if let partialSummary = Self.partialErrorSummary(from: nsError) {
            parts.append(partialSummary)
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            parts.append("underlying: \(describe(underlying))")
        }

        return parts.joined(separator: " | ")
    }

    nonisolated private static func partialErrorSummary(from error: NSError) -> String? {
        guard let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
              !partialErrors.isEmpty else {
            return nil
        }

        let samples = partialErrors.prefix(3).map { key, value in
            "\(String(describing: key)): \(describe(value))"
        }
        let suffix = partialErrors.count > samples.count
            ? "; +\(partialErrors.count - samples.count) more"
            : ""
        return "partial[\(partialErrors.count)]: \(samples.joined(separator: "; "))\(suffix)"
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
            if let asset = value as? CKAsset {
                let byteCount = asset.fileURL.flatMap { (try? Data(contentsOf: $0))?.count }
                return "\(key)=CKAsset(\(byteCount ?? 0))"
            }
            if let value {
                return "\(key)=\(String(describing: type(of: value)))"
            } else {
                return "\(key)=nil"
            }
        }.joined(separator: ", ")
    }

    private static func fieldSummary(for mappedRecord: LedgerCloudKitMappedRecord) -> String {
        mappedRecord.fields.keys.sorted().map { key in
            guard let value = mappedRecord.fields[key] else {
                return "\(key)=nil"
            }
            switch value {
            case let .string(string):
                return "\(key)=String(\(string.count))"
            case .double:
                return "\(key)=Double"
            case .int:
                return "\(key)=Int"
            case .date:
                return "\(key)=Date"
            case let .assetData(data, _):
                return "\(key)=CKAsset(\(data.count))"
            }
        }.joined(separator: ", ")
    }

    private static func writeTemporaryAssetFile(data: Data, filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerCloudKitAssets", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let sanitizedFilename = filename
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedFilename = sanitizedFilename.isEmpty ? "hotel-folio.pdf" : sanitizedFilename
        let fileURL = directory.appendingPathComponent("\(UUID().uuidString)-\(resolvedFilename)")
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    nonisolated private static func ckErrorName(_ code: CKError.Code) -> String {
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
            operation.savePolicy = .allKeys
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

    private func diagnoseMinimalSave(
        for record: CKRecord,
        dryRunResult: LedgerCloudKitDryRunResult
    ) async -> String {
        let probeRecordName = "\(record.recordID.recordName)-probe"
        let probe = CKRecord(
            recordType: record.recordType,
            recordID: CKRecord.ID(recordName: probeRecordName)
        )

        if let transactionID = record[CloudLedgerSyncSchema.Field.transactionID] as? NSString {
            probe[CloudLedgerSyncSchema.Field.transactionID] = transactionID
        }
        probe[CloudLedgerSyncSchema.Field.updatedAt] = Date() as NSDate

        do {
            _ = try await modifyRecords(
                recordsToSave: [probe],
                recordIDsToDelete: [],
                dryRunResult: dryRunResult
            )
        } catch {
            return "minimal-save failed (\(Self.describe(error)))"
        }

        do {
            _ = try await modifyRecords(
                recordsToSave: [],
                recordIDsToDelete: [probe.recordID],
                dryRunResult: dryRunResult
            )
            return "minimal-save succeeded and probe deleted"
        } catch {
            return "minimal-save succeeded but probe delete failed (\(Self.describe(error)))"
        }
    }

    private func retryHotelStayArchiveChunkWithoutPDFAssets(
        _ chunk: [LedgerCloudKitMappedRecord],
        dryRunResult: LedgerCloudKitDryRunResult
    ) async throws -> LedgerCloudKitPushResult {
        let strippedRecords = chunk.map(Self.removingHotelPDFAssets)
        let recordsToSave = try strippedRecords.map { try makeCKRecord(from: $0) }
        let result = try await modifyRecords(
            recordsToSave: recordsToSave,
            recordIDsToDelete: [],
            dryRunResult: dryRunResult
        )

        return LedgerCloudKitPushResult(
            savedRecordNames: result.savedRecordNames,
            deletedRecordNames: result.deletedRecordNames,
            upsertCount: result.upsertCount,
            tombstoneCount: result.tombstoneCount,
            expiredTombstoneCount: result.expiredTombstoneCount,
            assetFallbackRecordNames: chunk
                .filter { $0.fields[CloudLedgerSyncSchema.Field.sourcePDFAsset] != nil }
                .map(\.recordName)
                .sorted()
        )
    }

    private static func removingHotelPDFAssets(from mappedRecord: LedgerCloudKitMappedRecord) -> LedgerCloudKitMappedRecord {
        var fields = mappedRecord.fields
        fields.removeValue(forKey: CloudLedgerSyncSchema.Field.sourcePDFAsset)
        return LedgerCloudKitMappedRecord(
            recordType: mappedRecord.recordType,
            recordName: mappedRecord.recordName,
            fields: fields
        )
    }

    nonisolated private static func shouldRetryHotelStayArchiveWithoutPDFAssets(
        _ error: Error,
        mappedRecords: [LedgerCloudKitMappedRecord]
    ) -> Bool {
        guard mappedRecords.contains(where: {
            $0.fields[CloudLedgerSyncSchema.Field.sourcePDFAsset] != nil
        }) else {
            return false
        }

        return isCloudKitRecordSchemaOrAssetRejection(error)
    }

    nonisolated private static func isCloudKitRecordSchemaOrAssetRejection(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == CKError.errorDomain,
              let code = CKError.Code(rawValue: nsError.code) else {
            return false
        }

        switch code {
        case .invalidArguments,
             .serverRejectedRequest,
             .constraintViolation,
             .limitExceeded,
             .quotaExceeded,
             .assetFileNotFound,
             .assetFileModified:
            return true
        case .partialFailure:
            guard let partialErrors = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
                  !partialErrors.isEmpty else {
                return true
            }
            return partialErrors.values.contains { isCloudKitRecordSchemaOrAssetRejection($0) }
        default:
            return false
        }
    }

    private func fetchRecordsByID<Payload>(
        recordNames: [String],
        mapRecord: @escaping (CKRecord) -> Payload?
    ) async throws -> [Payload] {
        let recordIDs = Array(Set(recordNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
            .sorted()
            .map { CKRecord.ID(recordName: $0) }

        guard !recordIDs.isEmpty else { return [] }

        var payloads: [Payload] = []
        for chunk in recordIDs.chunked(into: Self.operationRecordLimit) {
            let chunkPayloads = try await fetchRecordIDChunk(chunk, mapRecord: mapRecord)
            payloads.append(contentsOf: chunkPayloads)
        }
        return payloads
    }

    private func fetchRecordIDChunk<Payload>(
        _ recordIDs: [CKRecord.ID],
        mapRecord: @escaping (CKRecord) -> Payload?
    ) async throws -> [Payload] {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
            operation.fetchRecordsCompletionBlock = { recordMap, error in
                let records = (recordMap ?? [:])
                    .sorted { $0.key.recordName < $1.key.recordName }
                    .compactMap { mapRecord($0.value) }

                if let error {
                    if Self.isRecoverableFetchRecordsError(error) {
                        continuation.resume(returning: records)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                continuation.resume(returning: records)
            }

            database.add(operation)
        }
    }

    nonisolated private static func isRecoverableFetchRecordsError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == CKError.errorDomain,
              let code = CKError.Code(rawValue: nsError.code) else {
            return false
        }

        if code == .unknownItem {
            return true
        }

        guard code == .partialFailure,
              let partialErrors = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
              !partialErrors.isEmpty else {
            return false
        }

        return partialErrors.values.allSatisfy { error in
            let nsError = error as NSError
            return nsError.domain == CKError.errorDomain &&
                CKError.Code(rawValue: nsError.code) == .unknownItem
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
        if let ledgerID = payload.ledgerID {
            fields[CloudLedgerSyncSchema.Field.ledgerID] = .string(ledgerID)
        }
        if let hotelStayRecordID = payload.hotelStayRecordID {
            fields[CloudLedgerSyncSchema.Field.hotelStayRecordID] = .string(hotelStayRecordID.uuidString)
        }

        return LedgerCloudKitMappedRecord(
            recordType: CloudLedgerSyncSchema.RecordType.transaction,
            recordName: payload.recordName,
            fields: fields
        )
    }

    private static func mapConfigurationRecord(_ payload: LedgerConfigurationSyncPayload) throws -> LedgerCloudKitMappedRecord {
        let encoded = try JSONEncoder.ledgerSyncEncoder.encode(payload)
        guard let json = String(data: encoded, encoding: .utf8) else {
            throw LedgerCloudKitSyncError.recordSaveRejected(
                recordName: payload.recordName,
                fieldSummary: "payloadJSON=encodingFailed",
                probeSummary: "configuration-encode",
                message: "Configuration payload could not be encoded as UTF-8."
            )
        }

        return LedgerCloudKitMappedRecord(
            recordType: CloudLedgerSyncSchema.RecordType.configuration,
            recordName: payload.recordName,
            fields: [
                CloudLedgerSyncSchema.Field.updatedAt: .date(payload.updatedAt),
                CloudLedgerSyncSchema.Field.deviceID: .string(payload.deviceID),
                CloudLedgerSyncSchema.Field.payloadJSON: .string(json)
            ]
        )
    }

    private static func mapSyncManifestRecord(_ payload: LedgerCloudSyncManifest) throws -> LedgerCloudKitMappedRecord {
        let encoded = try JSONEncoder.ledgerSyncEncoder.encode(payload)
        guard let json = String(data: encoded, encoding: .utf8) else {
            throw LedgerCloudKitSyncError.recordSaveRejected(
                recordName: payload.recordName,
                fieldSummary: "payloadJSON=encodingFailed",
                probeSummary: "sync-manifest-encode",
                message: "Sync manifest payload could not be encoded as UTF-8."
            )
        }

        return LedgerCloudKitMappedRecord(
            recordType: CloudLedgerSyncSchema.RecordType.configuration,
            recordName: payload.recordName,
            fields: [
                CloudLedgerSyncSchema.Field.updatedAt: .date(payload.updatedAt),
                CloudLedgerSyncSchema.Field.deviceID: .string(payload.deviceID),
                CloudLedgerSyncSchema.Field.payloadJSON: .string(json)
            ]
        )
    }

    private static func mapDashboardSnapshotRecord(_ payload: LedgerDashboardCloudSnapshot) throws -> LedgerCloudKitMappedRecord {
        let encoded = try JSONEncoder.ledgerSyncEncoder.encode(payload)
        guard let json = String(data: encoded, encoding: .utf8) else {
            throw LedgerCloudKitSyncError.recordSaveRejected(
                recordName: payload.recordName,
                fieldSummary: "payloadJSON=encodingFailed",
                probeSummary: "dashboard-snapshot-encode",
                message: "Dashboard snapshot payload could not be encoded as UTF-8."
            )
        }

        return LedgerCloudKitMappedRecord(
            recordType: CloudLedgerSyncSchema.RecordType.dashboardSnapshot,
            recordName: payload.recordName,
            fields: [
                CloudLedgerSyncSchema.Field.updatedAt: .date(payload.generatedAt),
                CloudLedgerSyncSchema.Field.deviceID: .string(payload.deviceID),
                CloudLedgerSyncSchema.Field.payloadJSON: .string(json)
            ]
        )
    }

    private static func mapHotelStayRecord(_ payload: LedgerHotelStayRecordSyncPayload) throws -> LedgerCloudKitMappedRecord {
        let payloadWithoutPDF = LedgerHotelStayRecordSyncPayload(
            recordName: payload.recordName,
            hotelStayID: payload.hotelStayID,
            hotelStayRecord: payload.hotelStayRecord.map {
                hotelStayRecord($0, sourcePDFData: nil)
            },
            updatedAt: payload.updatedAt,
            deviceID: payload.deviceID,
            deletedAt: payload.deletedAt
        )
        let encoded = try JSONEncoder.ledgerSyncEncoder.encode(payloadWithoutPDF)
        guard let json = String(data: encoded, encoding: .utf8) else {
            throw LedgerCloudKitSyncError.recordSaveRejected(
                recordName: payload.recordName,
                fieldSummary: "payloadJSON=encodingFailed",
                probeSummary: "hotel-stay-record-encode",
                message: "Hotel stay record payload could not be encoded as UTF-8."
            )
        }

        var fields: [String: LedgerCloudKitFieldValue] = [
            CloudLedgerSyncSchema.Field.hotelStayID: .string(payload.hotelStayID.uuidString),
            CloudLedgerSyncSchema.Field.updatedAt: .date(payload.updatedAt),
            CloudLedgerSyncSchema.Field.deviceID: .string(payload.deviceID),
            CloudLedgerSyncSchema.Field.payloadJSON: .string(json)
        ]
        if let deletedAt = payload.deletedAt {
            fields[CloudLedgerSyncSchema.Field.deletedAt] = .date(deletedAt)
        }
        if let sourcePDFData = payload.hotelStayRecord?.sourcePDFData,
           !sourcePDFData.isEmpty {
            fields[CloudLedgerSyncSchema.Field.sourcePDFAsset] = .assetData(
                sourcePDFData,
                filename: payload.hotelStayRecord?.sourceFileName ?? "\(payload.hotelStayID.uuidString).pdf"
            )
        }

        return LedgerCloudKitMappedRecord(
            recordType: CloudLedgerSyncSchema.RecordType.hotelStayRecord,
            recordName: payload.recordName,
            fields: fields
        )
    }

    private static func mapHotelStayDraft(_ payload: LedgerHotelStayDraftSyncPayload) throws -> LedgerCloudKitMappedRecord {
        let payloadWithoutPDF = LedgerHotelStayDraftSyncPayload(
            recordName: payload.recordName,
            draftID: payload.draftID,
            hotelStayDraft: payload.hotelStayDraft.map {
                hotelStayDraft($0, sourcePDFData: nil)
            },
            updatedAt: payload.updatedAt,
            deviceID: payload.deviceID,
            deletedAt: payload.deletedAt
        )
        let encoded = try JSONEncoder.ledgerSyncEncoder.encode(payloadWithoutPDF)
        guard let json = String(data: encoded, encoding: .utf8) else {
            throw LedgerCloudKitSyncError.recordSaveRejected(
                recordName: payload.recordName,
                fieldSummary: "payloadJSON=encodingFailed",
                probeSummary: "hotel-stay-draft-encode",
                message: "Hotel stay draft payload could not be encoded as UTF-8."
            )
        }

        var fields: [String: LedgerCloudKitFieldValue] = [
            CloudLedgerSyncSchema.Field.hotelStayDraftID: .string(payload.draftID.uuidString),
            CloudLedgerSyncSchema.Field.updatedAt: .date(payload.updatedAt),
            CloudLedgerSyncSchema.Field.deviceID: .string(payload.deviceID),
            CloudLedgerSyncSchema.Field.payloadJSON: .string(json)
        ]
        if let deletedAt = payload.deletedAt {
            fields[CloudLedgerSyncSchema.Field.deletedAt] = .date(deletedAt)
        }
        if let sourcePDFData = payload.hotelStayDraft?.sourcePDFData,
           !sourcePDFData.isEmpty {
            fields[CloudLedgerSyncSchema.Field.sourcePDFAsset] = .assetData(
                sourcePDFData,
                filename: payload.hotelStayDraft?.sourceFileName ?? "\(payload.draftID.uuidString).pdf"
            )
        }

        return LedgerCloudKitMappedRecord(
            recordType: CloudLedgerSyncSchema.RecordType.hotelStayDraft,
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
            ledgerID: record[CloudLedgerSyncSchema.Field.ledgerID] as? String,
            hotelStayRecordID: (record[CloudLedgerSyncSchema.Field.hotelStayRecordID] as? String).flatMap(UUID.init(uuidString:)),
            updatedAt: updatedAt,
            syncRevision: syncRevisionNumber.intValue,
            deviceID: deviceID,
            idempotencyKey: record[CloudLedgerSyncSchema.Field.idempotencyKey] as? String,
            deletedAt: record[CloudLedgerSyncSchema.Field.deletedAt] as? Date,
            conflictState: SyncConflictState(rawValue: conflictStateString) ?? .clean
        )
    }

    private static func assetData(from record: CKRecord, key: String) -> Data? {
        guard let asset = record[key] as? CKAsset,
              let fileURL = asset.fileURL else {
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }

    private static func hotelStayRecord(_ record: HotelStayRecord, sourcePDFData: Data?) -> HotelStayRecord {
        HotelStayRecord(
            id: record.id,
            ledgerID: record.ledgerID,
            linkedTransactionID: record.linkedTransactionID,
            hotelName: record.hotelName,
            hotelGroup: record.hotelGroup,
            hotelBrand: record.hotelBrand,
            city: record.city,
            country: record.country,
            checkInDate: record.checkInDate,
            checkOutDate: record.checkOutDate,
            nights: record.nights,
            roomType: record.roomType,
            confirmationNumber: record.confirmationNumber,
            currency: record.currency,
            roomCharge: record.roomCharge,
            taxAmount: record.taxAmount,
            serviceCharge: record.serviceCharge,
            foodBeverageAmount: record.foodBeverageAmount,
            otherAmount: record.otherAmount,
            totalAmount: record.totalAmount,
            paymentMethod: record.paymentMethod,
            sourceType: record.sourceType,
            sourceFileName: record.sourceFileName,
            sourcePDFData: sourcePDFData,
            localizedData: record.localizedData,
            confidence: record.confidence,
            rawText: record.rawText,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    private static func hotelStayDraft(_ draft: HotelStayDraft, sourcePDFData: Data?) -> HotelStayDraft {
        HotelStayDraft(
            id: draft.id,
            sourceType: draft.sourceType,
            targetLedgerID: draft.targetLedgerID,
            sourceFileName: draft.sourceFileName,
            sourcePDFData: sourcePDFData,
            sourceEmailSubject: draft.sourceEmailSubject,
            sourceEmailFrom: draft.sourceEmailFrom,
            sourceEmailUID: draft.sourceEmailUID,
            sourceEmailMessageIDHash: draft.sourceEmailMessageIDHash,
            sourceEmailAttachmentHash: draft.sourceEmailAttachmentHash,
            sourceEmailDateText: draft.sourceEmailDateText,
            rawText: draft.rawText,
            parsedPayload: draft.parsedPayload,
            localizedData: draft.localizedData,
            confidence: draft.confidence,
            status: draft.status,
            createdAt: draft.createdAt,
            updatedAt: draft.updatedAt
        )
    }

    private static func mapConfigurationPayload(from record: CKRecord) -> LedgerConfigurationSyncPayload? {
        guard
            let json = record[CloudLedgerSyncSchema.Field.payloadJSON] as? String,
            let data = json.data(using: .utf8),
            var payload = try? JSONDecoder.ledgerSyncDecoder.decode(LedgerConfigurationSyncPayload.self, from: data)
        else {
            return nil
        }

        if let updatedAt = record[CloudLedgerSyncSchema.Field.updatedAt] as? Date,
           updatedAt != payload.updatedAt {
            payload = LedgerConfigurationSyncPayload(
                recordName: record.recordID.recordName,
                updatedAt: updatedAt,
                deviceID: payload.deviceID,
                subscriptions: payload.subscriptions,
                categoryCorrections: payload.categoryCorrections,
                customCategories: payload.customCategories,
                customSources: payload.customSources,
                merchantAliases: payload.merchantAliases,
                merchantAliasDeletedKeys: payload.merchantAliasDeletedKeys,
                ledgerProfiles: payload.ledgerProfiles,
                defaultWriteLedgerID: payload.defaultWriteLedgerID,
                subscriptionMetadata: payload.subscriptionMetadata,
                appSettings: payload.appSettings
            )
        }

        return payload
    }

    private static func mapSyncManifestPayload(from record: CKRecord) -> LedgerCloudSyncManifest? {
        guard
            let json = record[CloudLedgerSyncSchema.Field.payloadJSON] as? String,
            let data = json.data(using: .utf8),
            var payload = try? JSONDecoder.ledgerSyncDecoder.decode(LedgerCloudSyncManifest.self, from: data)
        else {
            return nil
        }

        if let updatedAt = record[CloudLedgerSyncSchema.Field.updatedAt] as? Date,
           updatedAt != payload.updatedAt {
            payload = LedgerCloudSyncManifest(
                recordName: record.recordID.recordName,
                updatedAt: updatedAt,
                deviceID: payload.deviceID,
                transactionRecordNames: payload.transactionRecordNames,
                hotelStayRecordNames: payload.hotelStayRecordNames,
                hotelStayDraftRecordNames: payload.hotelStayDraftRecordNames
            )
        }

        return payload
    }

    private static func mapHotelStayRecordPayload(from record: CKRecord) -> LedgerHotelStayRecordSyncPayload? {
        guard
            let json = record[CloudLedgerSyncSchema.Field.payloadJSON] as? String,
            let data = json.data(using: .utf8),
            var payload = try? JSONDecoder.ledgerSyncDecoder.decode(LedgerHotelStayRecordSyncPayload.self, from: data)
        else {
            return nil
        }

        let assetData = assetData(from: record, key: CloudLedgerSyncSchema.Field.sourcePDFAsset)
        let hotelStayRecord: HotelStayRecord? = {
            guard let hotelStayRecord = payload.hotelStayRecord,
                  let assetData else {
                return payload.hotelStayRecord
            }
            return Self.hotelStayRecord(hotelStayRecord, sourcePDFData: assetData)
        }()
        let updatedAt = (record[CloudLedgerSyncSchema.Field.updatedAt] as? Date) ?? payload.updatedAt
        return LedgerHotelStayRecordSyncPayload(
            recordName: record.recordID.recordName,
            hotelStayID: payload.hotelStayID,
            hotelStayRecord: hotelStayRecord,
            updatedAt: updatedAt,
            deviceID: payload.deviceID,
            deletedAt: record[CloudLedgerSyncSchema.Field.deletedAt] as? Date ?? payload.deletedAt
        )
    }

    private static func mapHotelStayDraftPayload(from record: CKRecord) -> LedgerHotelStayDraftSyncPayload? {
        guard
            let json = record[CloudLedgerSyncSchema.Field.payloadJSON] as? String,
            let data = json.data(using: .utf8),
            var payload = try? JSONDecoder.ledgerSyncDecoder.decode(LedgerHotelStayDraftSyncPayload.self, from: data)
        else {
            return nil
        }

        let assetData = assetData(from: record, key: CloudLedgerSyncSchema.Field.sourcePDFAsset)
        let hotelStayDraft: HotelStayDraft? = {
            guard let hotelStayDraft = payload.hotelStayDraft,
                  let assetData else {
                return payload.hotelStayDraft
            }
            return Self.hotelStayDraft(hotelStayDraft, sourcePDFData: assetData)
        }()
        let updatedAt = (record[CloudLedgerSyncSchema.Field.updatedAt] as? Date) ?? payload.updatedAt
        return LedgerHotelStayDraftSyncPayload(
            recordName: record.recordID.recordName,
            draftID: payload.draftID,
            hotelStayDraft: hotelStayDraft,
            updatedAt: updatedAt,
            deviceID: payload.deviceID,
            deletedAt: record[CloudLedgerSyncSchema.Field.deletedAt] as? Date ?? payload.deletedAt
        )
    }
}

private extension JSONEncoder {
    static var ledgerSyncEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var ledgerSyncDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
