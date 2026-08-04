import Foundation
import SQLite3

public enum SQLiteTransactionStoreError: LocalizedError {
    case openDatabase
    case prepareStatement(String)
    case executeStatement(String)

    public var errorDescription: String? {
        switch self {
        case .openDatabase:
            return "本地账本数据库打开失败。"
        case let .prepareStatement(sql):
            return "SQL 语句准备失败：\(sql)"
        case let .executeStatement(sql):
            return "SQL 执行失败：\(sql)"
        }
    }
}

/// A complete in-memory view of the persisted ledger state for UI hydration.
///
/// Callers that need to keep the main thread responsive should create a separate
/// reader with `makeSnapshotReader()` and load this value off the main actor.
public struct SQLiteLedgerSnapshot: Sendable {
    public let transactions: [Transaction]
    public let deletedTransactions: [Transaction]
    public let debugRecords: [ImportDebugRecord]
    public let subscriptions: [Subscription]
    public let categoryCorrections: [String: TransactionCategory]
    public let merchantAliases: [String: String]
    public let hotelStayRecords: [HotelStayRecord]
    public let hotelStayDrafts: [HotelStayDraft]
    public let ledgerSyncConflictRecords: [TransactionSyncRecord]
    public let ledgerProfiles: [LedgerProfile]
}

public final class SQLiteTransactionStore: TransactionStore, @unchecked Sendable {
    private var db: OpaquePointer?
    private let databaseURL: URL
    private let syncDeviceID: String
    // LedgerStore currently exposes synchronous writes. Keep lock recovery bounded below one second
    // so a Share Extension writer cannot freeze the MainActor for multiple seconds.
    private static let busyTimeoutMilliseconds: Int32 = 200
    private static let busyRetryDelays: [TimeInterval] = [0.025, 0.05, 0.1]
    private static let transactionReadColumns = """
    id, merchant, amount, occurred_at, category, source, note, ledger_id, hotel_stay_record_id,
    ledger_currency_code, original_amount, original_currency_code, exchange_rate, exchange_rate_date, exchange_rate_provider
    """

    public convenience init(
        baseDirectoryURL: URL? = nil,
        filename: String = "autoledger.sqlite3",
        syncDeviceID: String? = nil
    ) throws {
        let url = try Self.makeDatabaseURL(baseDirectoryURL: baseDirectoryURL, filename: filename)
        try self.init(databaseURL: url, syncDeviceID: syncDeviceID ?? Self.localSyncDeviceID())
    }

    private init(databaseURL: URL, syncDeviceID: String) throws {
        self.syncDeviceID = syncDeviceID
        self.databaseURL = databaseURL

        if sqlite3_open(databaseURL.path, &db) != SQLITE_OK {
            throw SQLiteTransactionStoreError.openDatabase
        }

        configureDatabaseConnection()
        try createTableIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    /// Opens an independent SQLite connection to the same database for a
    /// background snapshot read. The original store remains owned by the caller.
    public func makeSnapshotReader() throws -> SQLiteTransactionStore {
        try SQLiteTransactionStore(databaseURL: databaseURL, syncDeviceID: syncDeviceID)
    }

    /// Loads every persisted collection needed to hydrate `LedgerStore`.
    ///
    /// This intentionally uses one dedicated connection so row decoding and
    /// date parsing can run outside the UI actor without sharing `db` with
    /// synchronous writes from the live store.
    public func loadLedgerSnapshot(seedTransactions: [Transaction]) throws -> SQLiteLedgerSnapshot {
        SQLiteLedgerSnapshot(
            transactions: try bootstrapIfNeeded(with: seedTransactions),
            deletedTransactions: try loadDeletedTransactions(),
            debugRecords: try loadDebugEvents(),
            subscriptions: try loadSubscriptions(),
            categoryCorrections: try loadCategoryCorrections(),
            merchantAliases: try loadMerchantAliases(),
            hotelStayRecords: try loadHotelStayRecords(),
            hotelStayDrafts: try loadHotelStayDrafts(),
            ledgerSyncConflictRecords: try loadConflictedTransactionSyncRecords(),
            ledgerProfiles: try loadLedgerProfiles(includeArchived: true)
        )
    }

    public func loadTransactions() throws -> [Transaction] {
        let sql = """
        SELECT \(Self.transactionReadColumns)
        FROM transactions
        WHERE deleted_at IS NULL
        ORDER BY occurred_at DESC, created_at DESC;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        var items: [Transaction] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idCString = sqlite3_column_text(statement, 0),
                let merchantCString = sqlite3_column_text(statement, 1),
                let occurredCString = sqlite3_column_text(statement, 3),
                let categoryCString = sqlite3_column_text(statement, 4),
                let sourceCString = sqlite3_column_text(statement, 5),
                let noteCString = sqlite3_column_text(statement, 6),
                let id = UUID(uuidString: String(cString: idCString)),
                let occurredAt = Self.storageFormatter.date(from: String(cString: occurredCString))
            else {
                continue
            }

            let merchant = String(cString: merchantCString)
            let note = String(cString: noteCString)
            let amount = sqlite3_column_double(statement, 2)
            let category = String(cString: categoryCString)
            let source = String(cString: sourceCString)

            items.append(
                Transaction(
                    id: id,
                    merchant: merchant,
                    amount: amount,
                    occurredAt: occurredAt,
                    categoryLabel: category,
                    sourceLabel: source,
                    note: note,
                    ledgerID: Self.string(from: statement, index: 7),
                    hotelStayRecordID: Self.uuid(from: statement, index: 8),
                    ledgerCurrencyCode: Self.string(from: statement, index: 9),
                    originalAmount: Self.double(from: statement, index: 10),
                    originalCurrencyCode: Self.string(from: statement, index: 11),
                    exchangeRate: Self.double(from: statement, index: 12),
                    exchangeRateDate: Self.string(from: statement, index: 13),
                    exchangeRateProvider: Self.string(from: statement, index: 14)
                )
            )
        }

        return items
    }

    public func save(transaction: Transaction) throws {
        let sql = """
        INSERT INTO transactions (
            id, merchant, amount, occurred_at, category, source, note, created_at, updated_at,
            sync_revision, sync_device_id, sync_idempotency_key, sync_conflict_state, ledger_id, hotel_stay_record_id,
            ledger_currency_code, original_amount, original_currency_code, exchange_rate, exchange_rate_date, exchange_rate_provider
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw prepareStatementError(sql)
        }

        let now = Self.storageFormatter.string(from: .now)
        bind(transaction: transaction, to: statement, includeTimestamps: now)

        guard stepWithBusyRetry(statement, sql: sql) == SQLITE_DONE else {
            throw executeStatementError(sql)
        }
    }

    public func update(transaction: Transaction) throws {
        let sql = """
        UPDATE transactions
        SET merchant = ?, amount = ?, occurred_at = ?, category = ?, source = ?, note = ?, updated_at = ?,
            sync_revision = sync_revision + 1,
            sync_device_id = ?,
            sync_conflict_state = ?,
            ledger_id = ?,
            hotel_stay_record_id = ?,
            ledger_currency_code = ?,
            original_amount = ?,
            original_currency_code = ?,
            exchange_rate = ?,
            exchange_rate_date = ?,
            exchange_rate_provider = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        sqlite3_bind_text(statement, 1, transaction.merchant, -1, sqliteTransient)
        sqlite3_bind_double(statement, 2, transaction.amount)
        sqlite3_bind_text(statement, 3, Self.storageFormatter.string(from: transaction.occurredAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, transaction.category, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, transaction.source, -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, transaction.note, -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, Self.storageFormatter.string(from: .now), -1, sqliteTransient)
        sqlite3_bind_text(statement, 8, syncDeviceID, -1, sqliteTransient)
        sqlite3_bind_text(statement, 9, SyncConflictState.clean.rawValue, -1, sqliteTransient)
        bindOptionalString(transaction.ledgerID, to: statement, at: 10)
        bindOptionalUUID(transaction.hotelStayRecordID, to: statement, at: 11)
        bindTransactionCurrencyMetadata(transaction, to: statement, startingAt: 12)
        sqlite3_bind_text(statement, 18, transaction.id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    /// Freezes the unit of legacy transactions that predate transaction-level
    /// currency metadata. Amounts and sync metadata are deliberately untouched:
    /// this is a local compatibility backfill, not a currency conversion or a
    /// user edit that should win a CloudKit conflict.
    @discardableResult
    public func backfillMissingLedgerCurrencyCodes(
        defaultCurrencyCode: String,
        defaultLedgerID: String = TodaySpendingSummary.defaultLedgerID
    ) throws -> Int {
        let fallbackCurrencyCode = AppFormatters.normalizedCurrencyCode(defaultCurrencyCode) ?? "USD"
        let sql = """
        UPDATE transactions
        SET ledger_currency_code = COALESCE(
            (
                SELECT CASE
                    WHEN LENGTH(TRIM(currency)) = 3 THEN UPPER(TRIM(currency))
                    ELSE NULL
                END
                FROM ledger_profiles
                WHERE id = COALESCE(NULLIF(TRIM(transactions.ledger_id), ''), ?)
            ),
            ?
        )
        WHERE ledger_currency_code IS NULL OR TRIM(ledger_currency_code) = '';
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        sqlite3_bind_text(statement, 1, defaultLedgerID, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, fallbackCurrencyCode, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
        return Int(sqlite3_changes(db))
    }

    public func delete(transactionID: UUID) throws {
        let sql = """
        UPDATE transactions
        SET deleted_at = ?, updated_at = ?,
            sync_revision = sync_revision + 1,
            sync_device_id = ?,
            sync_conflict_state = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        let now = Self.storageFormatter.string(from: .now)
        sqlite3_bind_text(statement, 1, now, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, now, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, syncDeviceID, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, SyncConflictState.clean.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, transactionID.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func loadDeletedTransactions(limit: Int = 50) throws -> [Transaction] {
        let sql = """
        SELECT \(Self.transactionReadColumns)
        FROM transactions
        WHERE deleted_at IS NOT NULL
        ORDER BY deleted_at DESC, occurred_at DESC
        LIMIT ?;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        sqlite3_bind_int(statement, 1, Int32(limit))
        return try readTransactions(from: statement)
    }

    public func loadBackupTransactions() throws -> [BackupTransaction] {
        let sql = """
        SELECT id, merchant, amount, occurred_at, category, source, note, ledger_id, hotel_stay_record_id, deleted_at,
               updated_at, sync_revision, sync_device_id, sync_idempotency_key, sync_conflict_state,
               ledger_currency_code, original_amount, original_currency_code, exchange_rate, exchange_rate_date, exchange_rate_provider
        FROM transactions
        ORDER BY occurred_at DESC, created_at DESC;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        var items: [BackupTransaction] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idCString = sqlite3_column_text(statement, 0),
                let merchantCString = sqlite3_column_text(statement, 1),
                let occurredCString = sqlite3_column_text(statement, 3),
                let categoryCString = sqlite3_column_text(statement, 4),
                let sourceCString = sqlite3_column_text(statement, 5),
                let noteCString = sqlite3_column_text(statement, 6),
                let id = UUID(uuidString: String(cString: idCString)),
                let occurredAt = Self.storageFormatter.date(from: String(cString: occurredCString))
            else {
                continue
            }

            let ledgerID = Self.string(from: statement, index: 7)
            let hotelStayRecordID = Self.uuid(from: statement, index: 8)
            let deletedAt: Date? = {
                guard sqlite3_column_type(statement, 9) != SQLITE_NULL,
                      let deletedCString = sqlite3_column_text(statement, 9) else { return nil }
                return Self.storageFormatter.date(from: String(cString: deletedCString))
            }()
            guard
                let updatedCString = sqlite3_column_text(statement, 10),
                let updatedAt = Self.storageFormatter.date(from: String(cString: updatedCString)),
                let deviceCString = sqlite3_column_text(statement, 12),
                let conflictCString = sqlite3_column_text(statement, 14)
            else {
                continue
            }

            let idempotencyKey: String? = sqlite3_column_type(statement, 13) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 13))
                : nil
            let conflictState = SyncConflictState(rawValue: String(cString: conflictCString)) ?? .clean

            items.append(
                BackupTransaction(
                    id: id,
                    merchant: String(cString: merchantCString),
                    amount: sqlite3_column_double(statement, 2),
                    occurredAt: occurredAt,
                    category: String(cString: categoryCString),
                    source: String(cString: sourceCString),
                    note: String(cString: noteCString),
                    ledgerID: ledgerID,
                    hotelStayRecordID: hotelStayRecordID,
                    ledgerCurrencyCode: Self.string(from: statement, index: 15),
                    originalAmount: Self.double(from: statement, index: 16),
                    originalCurrencyCode: Self.string(from: statement, index: 17),
                    exchangeRate: Self.double(from: statement, index: 18),
                    exchangeRateDate: Self.string(from: statement, index: 19),
                    exchangeRateProvider: Self.string(from: statement, index: 20),
                    deletedAt: deletedAt,
                    syncMetadata: TransactionSyncMetadata(
                        transactionID: id,
                        updatedAt: updatedAt,
                        syncRevision: Int(sqlite3_column_int(statement, 11)),
                        deviceID: String(cString: deviceCString),
                        idempotencyKey: idempotencyKey,
                        deletedAt: deletedAt,
                        conflictState: conflictState
                    )
                )
            )
        }

        return items
    }

    public func replaceForRestore(
        transactions backupTransactions: [BackupTransaction],
        subscriptions: [Subscription],
        categoryCorrections: [BackupCategoryCorrection],
        merchantAliases: [String: String] = [:],
        ledgerProfiles: [LedgerProfile] = [],
        hotelStayRecords: [HotelStayRecord] = [],
        hotelStayDrafts: [HotelStayDraft] = []
    ) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try execute("DELETE FROM hotel_stay_drafts;")
            try execute("DELETE FROM hotel_stay_records;")
            try execute("DELETE FROM transactions;")
            try execute("DELETE FROM subscriptions;")
            try execute("DELETE FROM category_corrections;")
            try execute("DELETE FROM merchant_aliases;")
            try execute("DELETE FROM ledger_profiles;")

            for transaction in backupTransactions {
                try insertBackupTransaction(transaction)
            }
            try upsertLedgerProfilesForImport(ledgerProfiles)
            for record in hotelStayRecords {
                try upsertHotelStayRecord(record)
            }
            for draft in hotelStayDrafts {
                try save(hotelStayDraft: draft)
            }
            for subscription in subscriptions {
                try saveSubscription(subscription)
            }
            for correction in categoryCorrections {
                try saveCategoryCorrection(merchant: correction.merchant, category: correction.category)
            }
            for (original, alias) in merchantAliases {
                try saveMerchantAlias(original: original, alias: alias)
            }

            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public func replaceConfigurationForSync(
        subscriptions: [Subscription],
        categoryCorrections: [BackupCategoryCorrection],
        merchantAliases: [String: String],
        ledgerProfiles: [LedgerProfile] = []
    ) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try execute("DELETE FROM subscriptions;")
            try execute("DELETE FROM category_corrections;")
            try execute("DELETE FROM merchant_aliases;")

            for subscription in subscriptions {
                try saveSubscription(subscription)
            }
            for correction in categoryCorrections {
                try saveCategoryCorrection(merchant: correction.merchant, category: correction.category)
            }
            for (original, alias) in merchantAliases {
                try saveMerchantAlias(original: original, alias: alias)
            }
            try upsertLedgerProfilesForImport(ledgerProfiles)

            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public func restoreTransaction(id: UUID) throws {
        let sql = """
        UPDATE transactions
        SET deleted_at = NULL, updated_at = ?,
            sync_revision = sync_revision + 1,
            sync_device_id = ?,
            sync_conflict_state = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        sqlite3_bind_text(statement, 1, Self.storageFormatter.string(from: .now), -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, syncDeviceID, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, SyncConflictState.clean.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func permanentlyDeleteTransaction(id: UUID) throws {
        let sql = "DELETE FROM transactions WHERE id = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func deleteDebugEvents(transactionID: UUID) throws {
        let sql = "DELETE FROM debug_events WHERE transaction_id = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        sqlite3_bind_text(statement, 1, transactionID.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func bootstrapIfNeeded(with transactions: [Transaction]) throws -> [Transaction] {
        let existing = try loadTransactions()
        guard existing.isEmpty else {
            return existing
        }

        for transaction in transactions {
            try save(transaction: transaction)
        }
        return try loadTransactions()
    }

    // MARK: - Hotel Stays

    public func loadHotelStayRecords() throws -> [HotelStayRecord] {
        let sql = """
        SELECT id, ledger_id, linked_transaction_id, hotel_name, hotel_group, hotel_brand, city, country,
               check_in_date, check_out_date, nights, room_type, room_number, confirmation_number, currency,
               room_charge, tax_amount, service_charge, food_beverage_amount, other_amount, total_amount,
               payment_method, source_type, source_file_name, source_pdf_data, localized_data_json,
               confidence, raw_text, created_at, updated_at
        FROM hotel_stay_records
        ORDER BY check_out_date DESC, created_at DESC;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        var records: [HotelStayRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let record = Self.hotelStayRecord(from: statement) else { continue }
            records.append(record)
        }
        return records
    }

    public func save(hotelStayRecord record: HotelStayRecord) throws {
        try upsertHotelStayRecord(record)
    }

    public func save(hotelStayRecord record: HotelStayRecord, linkedTransaction transaction: Transaction) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try save(transaction: transaction)
            try upsertHotelStayRecord(record)
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public func deleteHotelStayRecord(id: UUID) throws {
        let linkedTransactionID = try loadLinkedTransactionIDForHotelStayRecord(id: id)

        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            if let linkedTransactionID {
                try delete(transactionID: linkedTransactionID)
            }
            try deleteHotelStayRecordOnly(id: id)
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public func deleteHotelStayRecordForSync(id: UUID) throws {
        try deleteHotelStayRecordOnly(id: id)
    }

    private func loadLinkedTransactionIDForHotelStayRecord(id: UUID) throws -> UUID? {
        let sql = "SELECT linked_transaction_id FROM hotel_stay_records WHERE id = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }
        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        return Self.uuid(from: statement, index: 0)
    }

    private func deleteHotelStayRecordOnly(id: UUID) throws {
        let sql = "DELETE FROM hotel_stay_records WHERE id = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }
        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    private func upsertHotelStayRecord(_ record: HotelStayRecord) throws {
        let sql = """
        INSERT INTO hotel_stay_records (
            id, ledger_id, linked_transaction_id, hotel_name, hotel_group, hotel_brand, city, country,
            check_in_date, check_out_date, nights, room_type, room_number, confirmation_number, currency,
            room_charge, tax_amount, service_charge, food_beverage_amount, other_amount, total_amount,
            payment_method, source_type, source_file_name, source_pdf_data, localized_data_json,
            confidence, raw_text, created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            ledger_id = excluded.ledger_id,
            linked_transaction_id = excluded.linked_transaction_id,
            hotel_name = excluded.hotel_name,
            hotel_group = excluded.hotel_group,
            hotel_brand = excluded.hotel_brand,
            city = excluded.city,
            country = excluded.country,
            check_in_date = excluded.check_in_date,
            check_out_date = excluded.check_out_date,
            nights = excluded.nights,
            room_type = excluded.room_type,
            room_number = excluded.room_number,
            confirmation_number = excluded.confirmation_number,
            currency = excluded.currency,
            room_charge = excluded.room_charge,
            tax_amount = excluded.tax_amount,
            service_charge = excluded.service_charge,
            food_beverage_amount = excluded.food_beverage_amount,
            other_amount = excluded.other_amount,
            total_amount = excluded.total_amount,
            payment_method = excluded.payment_method,
            source_type = excluded.source_type,
            source_file_name = excluded.source_file_name,
            source_pdf_data = excluded.source_pdf_data,
            localized_data_json = excluded.localized_data_json,
            confidence = excluded.confidence,
            raw_text = excluded.raw_text,
            updated_at = excluded.updated_at;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        bind(hotelStayRecord: record, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    // MARK: - Hotel Stay Drafts

    public func loadHotelStayDrafts() throws -> [HotelStayDraft] {
        let sql = """
        SELECT id, source_type, target_ledger_id, source_file_name, source_pdf_data,
               source_email_subject, source_email_from, source_email_uid, source_email_message_id_hash,
               source_email_attachment_hash, source_email_date_text, raw_text, parsed_payload_json,
               localized_data_json, confidence, status, created_at, updated_at
        FROM hotel_stay_drafts
        ORDER BY updated_at DESC, created_at DESC;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        var drafts: [HotelStayDraft] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let draft = Self.hotelStayDraft(from: statement) else { continue }
            drafts.append(draft)
        }
        return drafts
    }

    public func save(hotelStayDraft draft: HotelStayDraft) throws {
        let sql = """
        INSERT INTO hotel_stay_drafts (
            id, source_type, target_ledger_id, source_file_name, source_pdf_data,
            source_email_subject, source_email_from, source_email_uid, source_email_message_id_hash,
            source_email_attachment_hash, source_email_date_text, raw_text, parsed_payload_json,
            localized_data_json, confidence, status, created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            source_type = excluded.source_type,
            target_ledger_id = excluded.target_ledger_id,
            source_file_name = excluded.source_file_name,
            source_pdf_data = excluded.source_pdf_data,
            source_email_subject = excluded.source_email_subject,
            source_email_from = excluded.source_email_from,
            source_email_uid = excluded.source_email_uid,
            source_email_message_id_hash = excluded.source_email_message_id_hash,
            source_email_attachment_hash = excluded.source_email_attachment_hash,
            source_email_date_text = excluded.source_email_date_text,
            raw_text = excluded.raw_text,
            parsed_payload_json = excluded.parsed_payload_json,
            localized_data_json = excluded.localized_data_json,
            confidence = excluded.confidence,
            status = excluded.status,
            updated_at = excluded.updated_at;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        bind(hotelStayDraft: draft, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func deleteHotelStayDraft(id: UUID) throws {
        let sql = "DELETE FROM hotel_stay_drafts WHERE id = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }
        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    @discardableResult
    public func deleteHotelStayDrafts(
        statuses: Set<HotelStayDraftStatus>,
        updatedBefore cutoffDate: Date
    ) throws -> Int {
        guard !statuses.isEmpty else { return 0 }
        let orderedStatuses = statuses.map(\.rawValue).sorted()
        let placeholders = Array(repeating: "?", count: orderedStatuses.count).joined(separator: ", ")
        let sql = "DELETE FROM hotel_stay_drafts WHERE status IN (\(placeholders)) AND updated_at < ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        for (offset, status) in orderedStatuses.enumerated() {
            sqlite3_bind_text(statement, Int32(offset + 1), status, -1, sqliteTransient)
        }
        sqlite3_bind_text(
            statement,
            Int32(orderedStatuses.count + 1),
            Self.storageFormatter.string(from: cutoffDate),
            -1,
            sqliteTransient
        )

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
        return Int(sqlite3_changes(db))
    }

    // MARK: - Ledger Profiles

    public func loadLedgerProfiles(includeArchived: Bool = true) throws -> [LedgerProfile] {
        try ensureDefaultLedgerProfileIfNeeded()

        let archivedFilter = includeArchived ? "" : "WHERE archived_at IS NULL"
        let sql = """
        SELECT id, name, icon_name, color_name, currency, is_default, sort_order, archived_at, created_at, updated_at
        FROM ledger_profiles
        \(archivedFilter)
        ORDER BY sort_order ASC, created_at ASC, name COLLATE NOCASE ASC;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        var profiles: [LedgerProfile] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let profile = Self.ledgerProfile(from: statement) else { continue }
            profiles.append(profile)
        }
        return profiles
    }

    public func saveLedgerProfile(_ profile: LedgerProfile) throws {
        if profile.isDefault {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("UPDATE ledger_profiles SET is_default = 0;")
                try upsertLedgerProfile(profile)
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        } else {
            try upsertLedgerProfile(profile)
        }
    }

    public func renameLedgerProfile(id: String, name: String, updatedAt: Date = .now) throws {
        let sql = """
        UPDATE ledger_profiles
        SET name = ?, updated_at = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        sqlite3_bind_text(statement, 1, name, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, Self.storageFormatter.string(from: updatedAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, id, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func archiveLedgerProfile(id: String, archivedAt: Date = .now) throws {
        let sql = """
        UPDATE ledger_profiles
        SET archived_at = ?, is_default = 0, updated_at = ?
        WHERE id = ? AND id != ?;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        let archivedAtString = Self.storageFormatter.string(from: archivedAt)
        sqlite3_bind_text(statement, 1, archivedAtString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, archivedAtString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, id, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, TodaySpendingSummary.defaultLedgerID, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
        try ensureDefaultLedgerProfileIsSelected(updatedAt: archivedAt)
    }

    public func setDefaultLedgerProfile(id: String, updatedAt: Date = .now) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try execute("UPDATE ledger_profiles SET is_default = 0;")
            let sql = """
            UPDATE ledger_profiles
            SET is_default = 1, archived_at = NULL, updated_at = ?
            WHERE id = ?;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteTransactionStoreError.prepareStatement(sql)
            }

            sqlite3_bind_text(statement, 1, Self.storageFormatter.string(from: updatedAt), -1, sqliteTransient)
            sqlite3_bind_text(statement, 2, id, -1, sqliteTransient)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteTransactionStoreError.executeStatement(sql)
            }
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
        try ensureDefaultLedgerProfileIsSelected(updatedAt: updatedAt)
    }

    private func upsertLedgerProfilesForImport(_ profiles: [LedgerProfile]) throws {
        guard !profiles.isEmpty else { return }

        let normalizedProfiles = Self.normalizedLedgerProfilesForImport(profiles)
        if normalizedProfiles.contains(where: \.isDefault) {
            try execute("UPDATE ledger_profiles SET is_default = 0;")
        }
        for profile in normalizedProfiles {
            try upsertLedgerProfile(profile)
        }
    }

    private static func normalizedLedgerProfilesForImport(_ profiles: [LedgerProfile]) -> [LedgerProfile] {
        var merged: [String: LedgerProfile] = [:]
        for profile in profiles {
            let id = profile.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { continue }
            if let existing = merged[id], existing.updatedAt > profile.updatedAt {
                continue
            }
            merged[id] = profile
        }

        if merged.isEmpty || merged.values.allSatisfy(\.isArchived) {
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
                LedgerProfile(
                    id: profile.id,
                    name: profile.name,
                    iconName: profile.iconName,
                    colorName: profile.colorName,
                    currency: profile.currency,
                    isDefault: selectedDefaultID == profile.id && !profile.isArchived,
                    sortOrder: profile.sortOrder,
                    archivedAt: profile.archivedAt,
                    createdAt: profile.createdAt,
                    updatedAt: profile.updatedAt
                )
            }
            .sorted(by: compareLedgerProfiles)
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

    private func ensureDefaultLedgerProfileIfNeeded() throws {
        let sql = "SELECT COUNT(*) FROM ledger_profiles;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        let count: Int
        if sqlite3_step(statement) == SQLITE_ROW {
            count = Int(sqlite3_column_int(statement, 0))
        } else {
            count = 0
        }

        guard count == 0 else {
            return
        }
        try saveLedgerProfile(LedgerProfile.defaultLocal(createdAt: .now))
    }

    private func ensureDefaultLedgerProfileIsSelected(updatedAt: Date) throws {
        let sql = "SELECT COUNT(*) FROM ledger_profiles WHERE is_default = 1 AND archived_at IS NULL;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        let activeDefaultCount: Int
        if sqlite3_step(statement) == SQLITE_ROW {
            activeDefaultCount = Int(sqlite3_column_int(statement, 0))
        } else {
            activeDefaultCount = 0
        }

        guard activeDefaultCount == 0 else {
            return
        }
        try saveLedgerProfile(LedgerProfile.defaultLocal(createdAt: updatedAt))
    }

    private func upsertLedgerProfile(_ profile: LedgerProfile) throws {
        let sql = """
        INSERT INTO ledger_profiles (
            id, name, icon_name, color_name, currency, is_default, sort_order, archived_at, created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            icon_name = excluded.icon_name,
            color_name = excluded.color_name,
            currency = excluded.currency,
            is_default = excluded.is_default,
            sort_order = excluded.sort_order,
            archived_at = excluded.archived_at,
            updated_at = excluded.updated_at;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        bind(profile: profile, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    private func bind(profile: LedgerProfile, to statement: OpaquePointer?) {
        sqlite3_bind_text(statement, 1, profile.id, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, profile.name, -1, sqliteTransient)
        bindOptionalString(profile.iconName, to: statement, at: 3)
        bindOptionalString(profile.colorName, to: statement, at: 4)
        bindOptionalString(profile.currency, to: statement, at: 5)
        sqlite3_bind_int(statement, 6, profile.isDefault ? 1 : 0)
        sqlite3_bind_int(statement, 7, Int32(profile.sortOrder))
        if let archivedAt = profile.archivedAt {
            sqlite3_bind_text(statement, 8, Self.storageFormatter.string(from: archivedAt), -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 8)
        }
        sqlite3_bind_text(statement, 9, Self.storageFormatter.string(from: profile.createdAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 10, Self.storageFormatter.string(from: profile.updatedAt), -1, sqliteTransient)
    }

    private static func ledgerProfile(from statement: OpaquePointer?) -> LedgerProfile? {
        guard
            let idCString = sqlite3_column_text(statement, 0),
            let nameCString = sqlite3_column_text(statement, 1),
            let createdCString = sqlite3_column_text(statement, 8),
            let updatedCString = sqlite3_column_text(statement, 9),
            let createdAt = storageFormatter.date(from: String(cString: createdCString)),
            let updatedAt = storageFormatter.date(from: String(cString: updatedCString))
        else {
            return nil
        }

        let archivedAt: Date? = {
            guard sqlite3_column_type(statement, 7) != SQLITE_NULL,
                  let archivedCString = sqlite3_column_text(statement, 7) else {
                return nil
            }
            return storageFormatter.date(from: String(cString: archivedCString))
        }()

        return LedgerProfile(
            id: String(cString: idCString),
            name: String(cString: nameCString),
            iconName: string(from: statement, index: 2),
            colorName: string(from: statement, index: 3),
            currency: string(from: statement, index: 4),
            isDefault: sqlite3_column_int(statement, 5) != 0,
            sortOrder: Int(sqlite3_column_int(statement, 6)),
            archivedAt: archivedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func createTableIfNeeded() throws {
        let transactionSQL = """
        CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY,
            merchant TEXT NOT NULL,
            amount REAL NOT NULL,
            occurred_at TEXT NOT NULL,
            category TEXT NOT NULL,
            source TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            ledger_id TEXT,
            hotel_stay_record_id TEXT,
            ledger_currency_code TEXT,
            original_amount REAL,
            original_currency_code TEXT,
            exchange_rate REAL,
            exchange_rate_date TEXT,
            exchange_rate_provider TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """

        guard sqlite3_exec(db, transactionSQL, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(transactionSQL)
        }

        let transactionColumns = Self.columnNames(db: db, table: "transactions")
        if !transactionColumns.contains("deleted_at") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN deleted_at TEXT;", nil, nil, nil)
        }
        if !transactionColumns.contains("sync_revision") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN sync_revision INTEGER NOT NULL DEFAULT 0;", nil, nil, nil)
        }
        if !transactionColumns.contains("sync_device_id") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN sync_device_id TEXT NOT NULL DEFAULT '';", nil, nil, nil)
        }
        if !transactionColumns.contains("sync_idempotency_key") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN sync_idempotency_key TEXT;", nil, nil, nil)
        }
        if !transactionColumns.contains("sync_conflict_state") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN sync_conflict_state TEXT NOT NULL DEFAULT 'clean';", nil, nil, nil)
        }
        if !transactionColumns.contains("ledger_id") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN ledger_id TEXT;", nil, nil, nil)
        }
        if !transactionColumns.contains("hotel_stay_record_id") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN hotel_stay_record_id TEXT;", nil, nil, nil)
        }
        if !transactionColumns.contains("ledger_currency_code") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN ledger_currency_code TEXT;", nil, nil, nil)
        }
        if !transactionColumns.contains("original_amount") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN original_amount REAL;", nil, nil, nil)
        }
        if !transactionColumns.contains("original_currency_code") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN original_currency_code TEXT;", nil, nil, nil)
        }
        if !transactionColumns.contains("exchange_rate") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN exchange_rate REAL;", nil, nil, nil)
        }
        if !transactionColumns.contains("exchange_rate_date") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN exchange_rate_date TEXT;", nil, nil, nil)
        }
        if !transactionColumns.contains("exchange_rate_provider") {
            sqlite3_exec(db, "ALTER TABLE transactions ADD COLUMN exchange_rate_provider TEXT;", nil, nil, nil)
        }
        try backfillSyncMetadataDefaults()

        let ledgerProfilesSQL = """
        CREATE TABLE IF NOT EXISTS ledger_profiles (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon_name TEXT,
            color_name TEXT,
            currency TEXT,
            is_default INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            archived_at TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """

        guard sqlite3_exec(db, ledgerProfilesSQL, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(ledgerProfilesSQL)
        }

        let hotelStayRecordsSQL = """
        CREATE TABLE IF NOT EXISTS hotel_stay_records (
            id TEXT PRIMARY KEY,
            ledger_id TEXT NOT NULL,
            linked_transaction_id TEXT,
            hotel_name TEXT NOT NULL,
            hotel_group TEXT,
            hotel_brand TEXT,
            city TEXT,
            country TEXT,
            check_in_date TEXT,
            check_out_date TEXT,
            nights INTEGER,
            room_type TEXT,
            room_number TEXT,
            confirmation_number TEXT,
            currency TEXT NOT NULL,
            room_charge REAL NOT NULL DEFAULT 0,
            tax_amount REAL NOT NULL DEFAULT 0,
            service_charge REAL NOT NULL DEFAULT 0,
            food_beverage_amount REAL NOT NULL DEFAULT 0,
            other_amount REAL NOT NULL DEFAULT 0,
            total_amount REAL NOT NULL,
            payment_method TEXT,
            source_type TEXT NOT NULL,
            source_file_name TEXT,
            source_pdf_data BLOB,
            localized_data_json TEXT,
            confidence REAL NOT NULL DEFAULT 0,
            raw_text TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """

        guard sqlite3_exec(db, hotelStayRecordsSQL, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(hotelStayRecordsSQL)
        }
        let hotelStayColumns = Self.columnNames(db: db, table: "hotel_stay_records")
        if !hotelStayColumns.contains("source_pdf_data") {
            sqlite3_exec(db, "ALTER TABLE hotel_stay_records ADD COLUMN source_pdf_data BLOB;", nil, nil, nil)
        }
        if !hotelStayColumns.contains("localized_data_json") {
            sqlite3_exec(db, "ALTER TABLE hotel_stay_records ADD COLUMN localized_data_json TEXT;", nil, nil, nil)
        }
        if !hotelStayColumns.contains("room_number") {
            sqlite3_exec(db, "ALTER TABLE hotel_stay_records ADD COLUMN room_number TEXT;", nil, nil, nil)
        }

        let hotelStayDraftsSQL = """
        CREATE TABLE IF NOT EXISTS hotel_stay_drafts (
            id TEXT PRIMARY KEY,
            source_type TEXT NOT NULL,
            target_ledger_id TEXT,
            source_file_name TEXT,
            source_pdf_data BLOB,
            source_email_subject TEXT,
            source_email_from TEXT,
            source_email_uid TEXT,
            source_email_message_id_hash TEXT,
            source_email_attachment_hash TEXT,
            source_email_date_text TEXT,
            raw_text TEXT NOT NULL DEFAULT '',
            parsed_payload_json TEXT,
            localized_data_json TEXT,
            confidence REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """

        guard sqlite3_exec(db, hotelStayDraftsSQL, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(hotelStayDraftsSQL)
        }
        let hotelStayDraftColumns = Self.columnNames(db: db, table: "hotel_stay_drafts")
        for (name, type) in [
            ("source_email_uid", "TEXT"),
            ("source_email_message_id_hash", "TEXT"),
            ("source_email_attachment_hash", "TEXT"),
            ("source_email_date_text", "TEXT"),
            ("localized_data_json", "TEXT")
        ] where !hotelStayDraftColumns.contains(name) {
            sqlite3_exec(db, "ALTER TABLE hotel_stay_drafts ADD COLUMN \(name) \(type);", nil, nil, nil)
        }

        let debugSQL = """
        CREATE TABLE IF NOT EXISTS debug_events (
            id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL,
            stage TEXT NOT NULL,
            source TEXT NOT NULL,
            raw_text TEXT NOT NULL DEFAULT '',
            parsed_merchant TEXT,
            parsed_amount REAL,
            summary TEXT NOT NULL DEFAULT '',
            llm_prompt TEXT,
            llm_response TEXT,
            transaction_id TEXT
        );
        """

        guard sqlite3_exec(db, debugSQL, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(debugSQL)
        }

        // 安全迁移：为旧表添加新列（仅在列不存在时执行）
        let existingColumns = Self.columnNames(db: db, table: "debug_events")
        for col in ["llm_prompt", "llm_response", "image_source", "transaction_id",
                     "llm_provider", "llm_latency_ms", "llm_confidence", "used_rule_fallback"] {
            if !existingColumns.contains(col) {
                let colType: String
                switch col {
                case "llm_latency_ms": colType = "INTEGER"
                case "llm_confidence": colType = "REAL"
                case "used_rule_fallback": colType = "INTEGER DEFAULT 1"
                default: colType = "TEXT"
                }
                sqlite3_exec(db, "ALTER TABLE debug_events ADD COLUMN \(col) \(colType);", nil, nil, nil)
            }
        }

        let subscriptionsSQL = """
        CREATE TABLE IF NOT EXISTS subscriptions (
            id TEXT PRIMARY KEY,
            merchant TEXT NOT NULL,
            plan_name TEXT NOT NULL DEFAULT '',
            period TEXT NOT NULL,
            amount REAL NOT NULL,
            currency_code TEXT NOT NULL DEFAULT 'CNY',
            last_charged_at TEXT NOT NULL,
            next_charged_at TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """

        guard sqlite3_exec(db, subscriptionsSQL, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(subscriptionsSQL)
        }

        let subscriptionColumns = Self.columnNames(db: db, table: "subscriptions")
        if !subscriptionColumns.contains("status") {
            sqlite3_exec(db, "ALTER TABLE subscriptions ADD COLUMN status TEXT NOT NULL DEFAULT 'active';", nil, nil, nil)
        }
        if !subscriptionColumns.contains("currency_code") {
            sqlite3_exec(db, "ALTER TABLE subscriptions ADD COLUMN currency_code TEXT NOT NULL DEFAULT 'CNY';", nil, nil, nil)
        }

        let correctionsSQL = """
        CREATE TABLE IF NOT EXISTS category_corrections (
            merchant TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """

        guard sqlite3_exec(db, correctionsSQL, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(correctionsSQL)
        }

        let merchantAliasesSQL = """
        CREATE TABLE IF NOT EXISTS merchant_aliases (
            original TEXT PRIMARY KEY,
            alias TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """

        guard sqlite3_exec(db, merchantAliasesSQL, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(merchantAliasesSQL)
        }
    }

    private static func columnNames(db: OpaquePointer?, table: String) -> Set<String> {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table));", -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        var names = Set<String>()
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cName = sqlite3_column_text(stmt, 1) {
                names.insert(String(cString: cName))
            }
        }
        return names
    }

    public func loadTransactionSyncMetadata(transactionID: UUID) throws -> TransactionSyncMetadata? {
        try loadTransactionSyncRecords(includeDeleted: true).first { $0.transaction.id == transactionID }?.metadata
    }

    public func loadConflictedTransactionSyncRecords() throws -> [TransactionSyncRecord] {
        try loadTransactionSyncRecords(includeDeleted: true)
            .filter { $0.metadata.conflictState == .conflictPendingReview }
    }

    public func resolveTransactionSyncConflictKeepingLocal(transactionID: UUID) throws {
        let sql = """
        UPDATE transactions
        SET updated_at = ?,
            sync_revision = sync_revision + 1,
            sync_device_id = ?,
            sync_conflict_state = ?
        WHERE id = ? AND sync_conflict_state = ?;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        sqlite3_bind_text(statement, 1, Self.storageFormatter.string(from: .now), -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, syncDeviceID, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, SyncConflictState.clean.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, transactionID.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, SyncConflictState.conflictPendingReview.rawValue, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func loadTransactionSyncRecords(includeDeleted: Bool = true) throws -> [TransactionSyncRecord] {
        let deletedFilter = includeDeleted ? "" : "WHERE deleted_at IS NULL"
        let sql = """
        SELECT id, merchant, amount, occurred_at, category, source, note,
               updated_at, deleted_at, sync_revision, sync_device_id, sync_idempotency_key, sync_conflict_state,
               ledger_id, hotel_stay_record_id, ledger_currency_code, original_amount, original_currency_code,
               exchange_rate, exchange_rate_date, exchange_rate_provider
        FROM transactions
        \(deletedFilter)
        ORDER BY updated_at DESC, occurred_at DESC;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        var records: [TransactionSyncRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = try? mapTransactionSyncRecord(from: statement) {
                records.append(record)
            }
        }

        return records
    }

    private func mapTransactionSyncRecord(from statement: OpaquePointer?) throws -> TransactionSyncRecord? {
        guard
            let idCString = sqlite3_column_text(statement, 0),
            let merchantCString = sqlite3_column_text(statement, 1),
            let occurredCString = sqlite3_column_text(statement, 3),
            let categoryCString = sqlite3_column_text(statement, 4),
            let sourceCString = sqlite3_column_text(statement, 5),
            let noteCString = sqlite3_column_text(statement, 6),
            let updatedCString = sqlite3_column_text(statement, 7),
            let deviceCString = sqlite3_column_text(statement, 10),
            let conflictCString = sqlite3_column_text(statement, 12),
            let id = UUID(uuidString: String(cString: idCString)),
            let occurredAt = Self.storageFormatter.date(from: String(cString: occurredCString)),
            let updatedAt = Self.storageFormatter.date(from: String(cString: updatedCString))
        else {
            return nil
        }

        let deletedAt: Date? = {
            guard sqlite3_column_type(statement, 8) != SQLITE_NULL,
                  let deletedCString = sqlite3_column_text(statement, 8) else { return nil }
            return Self.storageFormatter.date(from: String(cString: deletedCString))
        }()
        let idempotencyKey: String? = sqlite3_column_type(statement, 11) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 11))
            : nil
        let conflictState = SyncConflictState(rawValue: String(cString: conflictCString)) ?? .clean
        let transaction = Transaction(
            id: id,
            merchant: String(cString: merchantCString),
            amount: sqlite3_column_double(statement, 2),
            occurredAt: occurredAt,
            categoryLabel: String(cString: categoryCString),
            sourceLabel: String(cString: sourceCString),
            note: String(cString: noteCString),
            ledgerID: Self.string(from: statement, index: 13),
            hotelStayRecordID: Self.uuid(from: statement, index: 14),
            ledgerCurrencyCode: Self.string(from: statement, index: 15),
            originalAmount: Self.double(from: statement, index: 16),
            originalCurrencyCode: Self.string(from: statement, index: 17),
            exchangeRate: Self.double(from: statement, index: 18),
            exchangeRateDate: Self.string(from: statement, index: 19),
            exchangeRateProvider: Self.string(from: statement, index: 20)
        )
        let metadata = TransactionSyncMetadata(
            transactionID: id,
            updatedAt: updatedAt,
            syncRevision: Int(sqlite3_column_int(statement, 9)),
            deviceID: String(cString: deviceCString),
            idempotencyKey: idempotencyKey,
            deletedAt: deletedAt,
            conflictState: conflictState
        )
        return TransactionSyncRecord(transaction: transaction, metadata: metadata)
    }

    public func applyRemoteSyncRecord(_ remote: TransactionSyncRecord) throws -> TransactionSyncApplyOutcome {
        let localRecord = try loadTransactionSyncRecords(includeDeleted: true)
            .first { $0.transaction.id == remote.transaction.id }

        return try applyRemoteSyncRecord(remote, localRecord: localRecord)
    }

    public func applyRemoteSyncRecords(
        _ remotes: [TransactionSyncRecord],
        protectedLocalTransactionIDs: Set<UUID> = []
    ) throws -> TransactionSyncApplySummary {
        let localRecords = try loadTransactionSyncRecords(includeDeleted: true)
        var localRecordsByID = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.transaction.id, $0) })
        var summary = TransactionSyncApplySummary()

        for remote in remotes {
            let outcome = try applyRemoteSyncRecord(
                remote,
                localRecord: localRecordsByID[remote.transaction.id],
                protectLocal: protectedLocalTransactionIDs.contains(remote.transaction.id)
            )
            summary.record(outcome)

            switch outcome {
            case .inserted, .updated, .deleted, .conflictPendingReview:
                if let updatedLocal = try loadTransactionSyncRecord(transactionID: remote.transaction.id) {
                    localRecordsByID[remote.transaction.id] = updatedLocal
                } else {
                    localRecordsByID.removeValue(forKey: remote.transaction.id)
                }
            case .keptLocal:
                break
            }
        }

        return summary
    }

    private func applyRemoteSyncRecord(
        _ remote: TransactionSyncRecord,
        localRecord: TransactionSyncRecord?,
        protectLocal: Bool = false
    ) throws -> TransactionSyncApplyOutcome {
        guard let localRecord else {
            guard remote.metadata.deletedAt == nil else {
                return .keptLocal
            }
            try insertRemoteSyncRecord(remote)
            return .inserted
        }

        if protectLocal,
           localRecord.metadata.deviceID != remote.metadata.deviceID {
            return .keptLocal
        }

        switch TransactionSyncConflictResolver.resolve(local: localRecord, remote: remote) {
        case .keepLocal:
            return .keptLocal
        case .conflictPendingReview:
            try markTransactionSyncConflict(transactionID: remote.transaction.id)
            return .conflictPendingReview
        case .applyRemote:
            try updateFromRemoteSyncRecord(remote)
            return remote.metadata.deletedAt == nil ? .updated : .deleted
        }
    }

    private func loadTransactionSyncRecord(transactionID: UUID) throws -> TransactionSyncRecord? {
        let sql = """
        SELECT id, merchant, amount, occurred_at, category, source, note,
               updated_at, deleted_at, sync_revision, sync_device_id, sync_idempotency_key, sync_conflict_state,
               ledger_id, hotel_stay_record_id
        FROM transactions
        WHERE id = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }
        sqlite3_bind_text(statement, 1, transactionID.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return try mapTransactionSyncRecord(from: statement)
    }

    private func backfillSyncMetadataDefaults() throws {
        try bindAndExecute(
            "UPDATE transactions SET sync_device_id = ? WHERE sync_device_id IS NULL OR sync_device_id = '';",
            syncDeviceID
        )
        guard sqlite3_exec(
            db,
            "UPDATE transactions SET sync_idempotency_key = 'transaction:' || id WHERE sync_idempotency_key IS NULL OR sync_idempotency_key = '';",
            nil,
            nil,
            nil
        ) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement("backfill sync_idempotency_key")
        }
        try bindAndExecute(
            "UPDATE transactions SET sync_conflict_state = ? WHERE sync_conflict_state IS NULL OR sync_conflict_state = '';",
            SyncConflictState.clean.rawValue
        )
    }

    private func bindAndExecute(_ sql: String, _ value: String) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }
        sqlite3_bind_text(statement, 1, value, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    private func insertRemoteSyncRecord(_ record: TransactionSyncRecord) throws {
        let sql = """
        INSERT INTO transactions (
            id, merchant, amount, occurred_at, category, source, note, created_at, updated_at, deleted_at,
            sync_revision, sync_device_id, sync_idempotency_key, sync_conflict_state, ledger_id, hotel_stay_record_id,
            ledger_currency_code, original_amount, original_currency_code, exchange_rate, exchange_rate_date, exchange_rate_provider
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        bindRemote(record: record, to: statement, includeCreatedAt: true)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    private func updateFromRemoteSyncRecord(_ record: TransactionSyncRecord) throws {
        let sql = """
        UPDATE transactions
        SET merchant = ?, amount = ?, occurred_at = ?, category = ?, source = ?, note = ?,
            updated_at = ?, deleted_at = ?, sync_revision = ?, sync_device_id = ?,
            sync_idempotency_key = ?, sync_conflict_state = ?, ledger_id = ?, hotel_stay_record_id = ?,
            ledger_currency_code = ?, original_amount = ?, original_currency_code = ?, exchange_rate = ?,
            exchange_rate_date = ?, exchange_rate_provider = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        sqlite3_bind_text(statement, 1, record.transaction.merchant, -1, sqliteTransient)
        sqlite3_bind_double(statement, 2, record.transaction.amount)
        sqlite3_bind_text(statement, 3, Self.storageFormatter.string(from: record.transaction.occurredAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, record.transaction.category, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, record.transaction.source, -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, record.transaction.note, -1, sqliteTransient)
        bindRemoteMetadata(record.metadata, to: statement, startingAt: 7)
        bindOptionalString(record.transaction.ledgerID, to: statement, at: 13)
        bindOptionalUUID(record.transaction.hotelStayRecordID, to: statement, at: 14)
        bindTransactionCurrencyMetadata(record.transaction, to: statement, startingAt: 15)
        sqlite3_bind_text(statement, 21, record.transaction.id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    private func markTransactionSyncConflict(transactionID: UUID) throws {
        let sql = "UPDATE transactions SET sync_conflict_state = ? WHERE id = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }
        sqlite3_bind_text(statement, 1, SyncConflictState.conflictPendingReview.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, transactionID.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    private func bindRemote(record: TransactionSyncRecord, to statement: OpaquePointer?, includeCreatedAt: Bool) {
        sqlite3_bind_text(statement, 1, record.transaction.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, record.transaction.merchant, -1, sqliteTransient)
        sqlite3_bind_double(statement, 3, record.transaction.amount)
        sqlite3_bind_text(statement, 4, Self.storageFormatter.string(from: record.transaction.occurredAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, record.transaction.category, -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, record.transaction.source, -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, record.transaction.note, -1, sqliteTransient)
        if includeCreatedAt {
            sqlite3_bind_text(statement, 8, Self.storageFormatter.string(from: .now), -1, sqliteTransient)
            bindRemoteMetadata(record.metadata, to: statement, startingAt: 9)
            bindOptionalString(record.transaction.ledgerID, to: statement, at: 15)
            bindOptionalUUID(record.transaction.hotelStayRecordID, to: statement, at: 16)
            bindTransactionCurrencyMetadata(record.transaction, to: statement, startingAt: 17)
        } else {
            bindRemoteMetadata(record.metadata, to: statement, startingAt: 8)
            bindOptionalString(record.transaction.ledgerID, to: statement, at: 14)
            bindOptionalUUID(record.transaction.hotelStayRecordID, to: statement, at: 15)
            bindTransactionCurrencyMetadata(record.transaction, to: statement, startingAt: 16)
        }
    }

    private func bindRemoteMetadata(_ metadata: TransactionSyncMetadata, to statement: OpaquePointer?, startingAt index: Int32) {
        sqlite3_bind_text(statement, index, Self.storageFormatter.string(from: metadata.updatedAt), -1, sqliteTransient)
        if let deletedAt = metadata.deletedAt {
            sqlite3_bind_text(statement, index + 1, Self.storageFormatter.string(from: deletedAt), -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, index + 1)
        }
        sqlite3_bind_int(statement, index + 2, Int32(metadata.syncRevision))
        sqlite3_bind_text(statement, index + 3, metadata.deviceID, -1, sqliteTransient)
        if let idempotencyKey = metadata.idempotencyKey {
            sqlite3_bind_text(statement, index + 4, idempotencyKey, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, index + 4)
        }
        sqlite3_bind_text(statement, index + 5, metadata.conflictState.rawValue, -1, sqliteTransient)
    }

    // MARK: - Debug Events

    public func saveDebugEvent(_ record: ImportDebugRecord) throws {
        let sql = """
        INSERT INTO debug_events (id, created_at, stage, source, raw_text, parsed_merchant, parsed_amount, summary, llm_prompt, llm_response, image_source, transaction_id, llm_provider, llm_latency_ms, llm_confidence, used_rule_fallback)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        sqlite3_bind_text(statement, 1, record.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, Self.storageFormatter.string(from: record.createdAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, record.stage.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, record.source.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, record.rawText, -1, sqliteTransient)
        if let merchant = record.parsedMerchant {
            sqlite3_bind_text(statement, 6, merchant, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 6)
        }
        if let amount = record.parsedAmount {
            sqlite3_bind_double(statement, 7, amount)
        } else {
            sqlite3_bind_null(statement, 7)
        }
        sqlite3_bind_text(statement, 8, record.summary, -1, sqliteTransient)
        if let prompt = record.llmPrompt {
            sqlite3_bind_text(statement, 9, prompt, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 9)
        }
        if let response = record.llmResponse {
            sqlite3_bind_text(statement, 10, response, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 10)
        }
        sqlite3_bind_text(statement, 11, record.imageSource.rawValue, -1, sqliteTransient)
        if let txID = record.transactionID {
            sqlite3_bind_text(statement, 12, txID.uuidString, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 12)
        }
        if let provider = record.llmProvider {
            sqlite3_bind_text(statement, 13, provider, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 13)
        }
        if let latency = record.llmLatencyMs {
            sqlite3_bind_int(statement, 14, Int32(latency))
        } else {
            sqlite3_bind_null(statement, 14)
        }
        if let confidence = record.llmConfidence {
            sqlite3_bind_double(statement, 15, confidence)
        } else {
            sqlite3_bind_null(statement, 15)
        }
        sqlite3_bind_int(statement, 16, record.usedRuleFallback ? 1 : 0)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func loadDebugEvents() throws -> [ImportDebugRecord] {
        let sql = """
        SELECT id, created_at, stage, source, raw_text, parsed_merchant, parsed_amount, summary, llm_prompt, llm_response, image_source, transaction_id, llm_provider, llm_latency_ms, llm_confidence, used_rule_fallback
        FROM debug_events
        ORDER BY created_at DESC;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        var items: [ImportDebugRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idCStr = sqlite3_column_text(statement, 0),
                let createdCStr = sqlite3_column_text(statement, 1),
                let stageCStr = sqlite3_column_text(statement, 2),
                let sourceCStr = sqlite3_column_text(statement, 3),
                let rawTextCStr = sqlite3_column_text(statement, 4),
                let summaryCStr = sqlite3_column_text(statement, 7),
                let id = UUID(uuidString: String(cString: idCStr)),
                let createdAt = Self.storageFormatter.date(from: String(cString: createdCStr)),
                let stage = ImportDebugStage(rawValue: String(cString: stageCStr)),
                let source = ReceiptSource(rawValue: String(cString: sourceCStr))
            else {
                continue
            }

            let rawText = String(cString: rawTextCStr)
            let summary = String(cString: summaryCStr)

            let parsedMerchant: String? = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 5))
                : nil
            let parsedAmount: Double? = sqlite3_column_type(statement, 6) != SQLITE_NULL
                ? sqlite3_column_double(statement, 6)
                : nil

            let llmPrompt: String? = sqlite3_column_type(statement, 8) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 8))
                : nil
            let llmResponse: String? = sqlite3_column_type(statement, 9) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 9))
                : nil

            let imageSource: ImageSource = {
                guard sqlite3_column_type(statement, 10) != SQLITE_NULL,
                      let cStr = sqlite3_column_text(statement, 10) else { return .unknown }
                return ImageSource(rawValue: String(cString: cStr)) ?? .unknown
            }()

            let transactionID: UUID? = {
                guard sqlite3_column_type(statement, 11) != SQLITE_NULL,
                      let cStr = sqlite3_column_text(statement, 11) else { return nil }
                return UUID(uuidString: String(cString: cStr))
            }()

            let llmProvider: String? = sqlite3_column_type(statement, 12) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 12))
                : nil
            let llmLatencyMs: Int? = sqlite3_column_type(statement, 13) != SQLITE_NULL
                ? Int(sqlite3_column_int(statement, 13))
                : nil
            let llmConfidence: Double? = sqlite3_column_type(statement, 14) != SQLITE_NULL
                ? sqlite3_column_double(statement, 14)
                : nil
            let usedRuleFallback: Bool = sqlite3_column_type(statement, 15) != SQLITE_NULL
                ? sqlite3_column_int(statement, 15) != 0
                : true

            var receipt: ImportedReceipt? = nil
            if let m = parsedMerchant, let a = parsedAmount {
                receipt = ImportedReceipt(
                    source: source,
                    merchant: m,
                    amount: a,
                    occurredAt: createdAt,
                    rawText: rawText,
                    summary: summary,
                    confidence: 0.0,
                    suggestedCategory: .other
                )
            }

            items.append(
                ImportDebugRecord(
                    id: id,
                    createdAt: createdAt,
                    stage: stage,
                    source: source,
                    imageSource: imageSource,
                    rawText: rawText,
                    parsedReceipt: receipt,
                    summary: summary,
                    llmPrompt: llmPrompt,
                    llmResponse: llmResponse,
                    transactionID: transactionID,
                    llmProvider: llmProvider,
                    llmLatencyMs: llmLatencyMs,
                    llmConfidence: llmConfidence,
                    usedRuleFallback: usedRuleFallback
                )
            )
        }

        return items
    }

    public func clearDebugEvents() throws {
        let sql = "DELETE FROM debug_events;"
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    private func bind(transaction: Transaction, to statement: OpaquePointer?, includeTimestamps now: String) {
        sqlite3_bind_text(statement, 1, transaction.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, transaction.merchant, -1, sqliteTransient)
        sqlite3_bind_double(statement, 3, transaction.amount)
        sqlite3_bind_text(statement, 4, Self.storageFormatter.string(from: transaction.occurredAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, transaction.category, -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, transaction.source, -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, transaction.note, -1, sqliteTransient)
        sqlite3_bind_text(statement, 8, now, -1, sqliteTransient)
        sqlite3_bind_text(statement, 9, now, -1, sqliteTransient)
        sqlite3_bind_int(statement, 10, 0)
        sqlite3_bind_text(statement, 11, syncDeviceID, -1, sqliteTransient)
        sqlite3_bind_text(statement, 12, Self.defaultIdempotencyKey(for: transaction.id), -1, sqliteTransient)
        sqlite3_bind_text(statement, 13, SyncConflictState.clean.rawValue, -1, sqliteTransient)
        bindOptionalString(transaction.ledgerID, to: statement, at: 14)
        bindOptionalUUID(transaction.hotelStayRecordID, to: statement, at: 15)
        bindTransactionCurrencyMetadata(transaction, to: statement, startingAt: 16)
    }

    private func insertBackupTransaction(_ transaction: BackupTransaction) throws {
        let sql = """
        INSERT INTO transactions (
            id, merchant, amount, occurred_at, category, source, note, created_at, updated_at, deleted_at,
            sync_revision, sync_device_id, sync_idempotency_key, sync_conflict_state, ledger_id, hotel_stay_record_id,
            ledger_currency_code, original_amount, original_currency_code, exchange_rate, exchange_rate_date, exchange_rate_provider
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        let now = Self.storageFormatter.string(from: .now)
        let syncMetadata = transaction.syncMetadata
        let updatedAt = syncMetadata?.updatedAt ?? .now
        sqlite3_bind_text(statement, 1, transaction.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, transaction.merchant, -1, sqliteTransient)
        sqlite3_bind_double(statement, 3, transaction.amount)
        sqlite3_bind_text(statement, 4, Self.storageFormatter.string(from: transaction.occurredAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, transaction.category, -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, transaction.source, -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, transaction.note, -1, sqliteTransient)
        sqlite3_bind_text(statement, 8, now, -1, sqliteTransient)
        sqlite3_bind_text(statement, 9, Self.storageFormatter.string(from: updatedAt), -1, sqliteTransient)
        if let deletedAt = transaction.deletedAt {
            sqlite3_bind_text(statement, 10, Self.storageFormatter.string(from: deletedAt), -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 10)
        }
        sqlite3_bind_int(statement, 11, Int32(syncMetadata?.syncRevision ?? 0))
        sqlite3_bind_text(statement, 12, syncMetadata?.deviceID ?? syncDeviceID, -1, sqliteTransient)
        sqlite3_bind_text(
            statement,
            13,
            syncMetadata?.idempotencyKey ?? Self.defaultIdempotencyKey(for: transaction.id),
            -1,
            sqliteTransient
        )
        sqlite3_bind_text(
            statement,
            14,
            syncMetadata?.conflictState.rawValue ?? SyncConflictState.clean.rawValue,
            -1,
            sqliteTransient
        )
        bindOptionalString(transaction.ledgerID, to: statement, at: 15)
        bindOptionalUUID(transaction.hotelStayRecordID, to: statement, at: 16)
        bindBackupTransactionCurrencyMetadata(transaction, to: statement, startingAt: 17)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    private func readTransactions(from statement: OpaquePointer?) throws -> [Transaction] {
        var items: [Transaction] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idCString = sqlite3_column_text(statement, 0),
                let merchantCString = sqlite3_column_text(statement, 1),
                let occurredCString = sqlite3_column_text(statement, 3),
                let categoryCString = sqlite3_column_text(statement, 4),
                let sourceCString = sqlite3_column_text(statement, 5),
                let noteCString = sqlite3_column_text(statement, 6),
                let id = UUID(uuidString: String(cString: idCString)),
                let occurredAt = Self.storageFormatter.date(from: String(cString: occurredCString))
            else {
                continue
            }

            items.append(
                Transaction(
                    id: id,
                    merchant: String(cString: merchantCString),
                    amount: sqlite3_column_double(statement, 2),
                    occurredAt: occurredAt,
                    categoryLabel: String(cString: categoryCString),
                    sourceLabel: String(cString: sourceCString),
                    note: String(cString: noteCString),
                    ledgerID: Self.string(from: statement, index: 7),
                    hotelStayRecordID: Self.uuid(from: statement, index: 8),
                    ledgerCurrencyCode: Self.string(from: statement, index: 9),
                    originalAmount: Self.double(from: statement, index: 10),
                    originalCurrencyCode: Self.string(from: statement, index: 11),
                    exchangeRate: Self.double(from: statement, index: 12),
                    exchangeRateDate: Self.string(from: statement, index: 13),
                    exchangeRateProvider: Self.string(from: statement, index: 14)
                )
            )
        }

        return items
    }

    private func bind(hotelStayRecord record: HotelStayRecord, to statement: OpaquePointer?) {
        sqlite3_bind_text(statement, 1, record.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, record.ledgerID, -1, sqliteTransient)
        bindOptionalUUID(record.linkedTransactionID, to: statement, at: 3)
        sqlite3_bind_text(statement, 4, record.hotelName, -1, sqliteTransient)
        bindOptionalString(record.hotelGroup, to: statement, at: 5)
        bindOptionalString(record.hotelBrand, to: statement, at: 6)
        bindOptionalString(record.city, to: statement, at: 7)
        bindOptionalString(record.country, to: statement, at: 8)
        bindOptionalString(record.checkInDate, to: statement, at: 9)
        bindOptionalString(record.checkOutDate, to: statement, at: 10)
        if let nights = record.nights {
            sqlite3_bind_int(statement, 11, Int32(nights))
        } else {
            sqlite3_bind_null(statement, 11)
        }
        bindOptionalString(record.roomType, to: statement, at: 12)
        bindOptionalString(record.roomNumber, to: statement, at: 13)
        bindOptionalString(record.confirmationNumber, to: statement, at: 14)
        sqlite3_bind_text(statement, 15, record.currency, -1, sqliteTransient)
        sqlite3_bind_double(statement, 16, record.roomCharge)
        sqlite3_bind_double(statement, 17, record.taxAmount)
        sqlite3_bind_double(statement, 18, record.serviceCharge)
        sqlite3_bind_double(statement, 19, record.foodBeverageAmount)
        sqlite3_bind_double(statement, 20, record.otherAmount)
        sqlite3_bind_double(statement, 21, record.totalAmount)
        bindOptionalString(record.paymentMethod, to: statement, at: 22)
        sqlite3_bind_text(statement, 23, record.sourceType.rawValue, -1, sqliteTransient)
        bindOptionalString(record.sourceFileName, to: statement, at: 24)
        bindOptionalData(record.sourcePDFData, to: statement, at: 25)
        bindOptionalLocalizedData(record.localizedData, to: statement, at: 26)
        sqlite3_bind_double(statement, 27, record.confidence)
        sqlite3_bind_text(statement, 28, record.rawText, -1, sqliteTransient)
        sqlite3_bind_text(statement, 29, Self.storageFormatter.string(from: record.createdAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 30, Self.storageFormatter.string(from: record.updatedAt), -1, sqliteTransient)
    }

    private static func hotelStayRecord(from statement: OpaquePointer?) -> HotelStayRecord? {
        guard
            let idCString = sqlite3_column_text(statement, 0),
            let ledgerCString = sqlite3_column_text(statement, 1),
            let hotelNameCString = sqlite3_column_text(statement, 3),
            let currencyCString = sqlite3_column_text(statement, 14),
            let sourceTypeCString = sqlite3_column_text(statement, 22),
            let rawTextCString = sqlite3_column_text(statement, 27),
            let createdCString = sqlite3_column_text(statement, 28),
            let updatedCString = sqlite3_column_text(statement, 29),
            let id = UUID(uuidString: String(cString: idCString)),
            let sourceType = HotelFolioSourceType(rawValue: String(cString: sourceTypeCString)),
            let createdAt = storageFormatter.date(from: String(cString: createdCString)),
            let updatedAt = storageFormatter.date(from: String(cString: updatedCString))
        else {
            return nil
        }

        let nights: Int? = sqlite3_column_type(statement, 10) == SQLITE_NULL
            ? nil
            : Int(sqlite3_column_int(statement, 10))

        return HotelStayRecord(
            id: id,
            ledgerID: String(cString: ledgerCString),
            linkedTransactionID: uuid(from: statement, index: 2),
            hotelName: String(cString: hotelNameCString),
            hotelGroup: string(from: statement, index: 4),
            hotelBrand: string(from: statement, index: 5),
            city: string(from: statement, index: 6),
            country: string(from: statement, index: 7),
            checkInDate: string(from: statement, index: 8),
            checkOutDate: string(from: statement, index: 9),
            nights: nights,
            roomType: string(from: statement, index: 11),
            roomNumber: string(from: statement, index: 12),
            confirmationNumber: string(from: statement, index: 13),
            currency: String(cString: currencyCString),
            roomCharge: sqlite3_column_double(statement, 15),
            taxAmount: sqlite3_column_double(statement, 16),
            serviceCharge: sqlite3_column_double(statement, 17),
            foodBeverageAmount: sqlite3_column_double(statement, 18),
            otherAmount: sqlite3_column_double(statement, 19),
            totalAmount: sqlite3_column_double(statement, 20),
            paymentMethod: string(from: statement, index: 21),
            sourceType: sourceType,
            sourceFileName: string(from: statement, index: 23),
            sourcePDFData: data(from: statement, index: 24),
            localizedData: localizedData(from: statement, index: 25),
            confidence: sqlite3_column_double(statement, 26),
            rawText: String(cString: rawTextCString),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func bind(hotelStayDraft draft: HotelStayDraft, to statement: OpaquePointer?) {
        sqlite3_bind_text(statement, 1, draft.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, draft.sourceType.rawValue, -1, sqliteTransient)
        bindOptionalString(draft.targetLedgerID, to: statement, at: 3)
        bindOptionalString(draft.sourceFileName, to: statement, at: 4)
        bindOptionalData(draft.sourcePDFData, to: statement, at: 5)
        bindOptionalString(draft.sourceEmailSubject, to: statement, at: 6)
        bindOptionalString(draft.sourceEmailFrom, to: statement, at: 7)
        bindOptionalString(draft.sourceEmailUID, to: statement, at: 8)
        bindOptionalString(draft.sourceEmailMessageIDHash, to: statement, at: 9)
        bindOptionalString(draft.sourceEmailAttachmentHash, to: statement, at: 10)
        bindOptionalString(draft.sourceEmailDateText, to: statement, at: 11)
        sqlite3_bind_text(statement, 12, draft.rawText, -1, sqliteTransient)
        if let parsedPayload = draft.parsedPayload,
           let data = try? JSONEncoder().encode(parsedPayload),
           let json = String(data: data, encoding: .utf8) {
            sqlite3_bind_text(statement, 13, json, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 13)
        }
        bindOptionalLocalizedData(draft.localizedData, to: statement, at: 14)
        sqlite3_bind_double(statement, 15, draft.confidence)
        sqlite3_bind_text(statement, 16, draft.status.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 17, Self.storageFormatter.string(from: draft.createdAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 18, Self.storageFormatter.string(from: draft.updatedAt), -1, sqliteTransient)
    }

    private static func hotelStayDraft(from statement: OpaquePointer?) -> HotelStayDraft? {
        guard
            let idCString = sqlite3_column_text(statement, 0),
            let sourceTypeCString = sqlite3_column_text(statement, 1),
            let rawTextCString = sqlite3_column_text(statement, 11),
            let statusCString = sqlite3_column_text(statement, 15),
            let createdCString = sqlite3_column_text(statement, 16),
            let updatedCString = sqlite3_column_text(statement, 17),
            let id = UUID(uuidString: String(cString: idCString)),
            let sourceType = HotelFolioSourceType(rawValue: String(cString: sourceTypeCString)),
            let status = HotelStayDraftStatus(rawValue: String(cString: statusCString)),
            let createdAt = storageFormatter.date(from: String(cString: createdCString)),
            let updatedAt = storageFormatter.date(from: String(cString: updatedCString))
        else {
            return nil
        }

        let parsedPayload: HotelFolioParsedPayload? = {
            guard let json = string(from: statement, index: 12),
                  let data = json.data(using: .utf8) else {
                return nil
            }
            return try? JSONDecoder().decode(HotelFolioParsedPayload.self, from: data)
        }()

        return HotelStayDraft(
            id: id,
            sourceType: sourceType,
            targetLedgerID: string(from: statement, index: 2),
            sourceFileName: string(from: statement, index: 3),
            sourcePDFData: data(from: statement, index: 4),
            sourceEmailSubject: string(from: statement, index: 5),
            sourceEmailFrom: string(from: statement, index: 6),
            sourceEmailUID: string(from: statement, index: 7),
            sourceEmailMessageIDHash: string(from: statement, index: 8),
            sourceEmailAttachmentHash: string(from: statement, index: 9),
            sourceEmailDateText: string(from: statement, index: 10),
            rawText: String(cString: rawTextCString),
            parsedPayload: parsedPayload,
            localizedData: localizedData(from: statement, index: 13),
            confidence: sqlite3_column_double(statement, 14),
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func bindOptionalUUID(_ value: UUID?, to statement: OpaquePointer?, at index: Int32) {
        if let value {
            sqlite3_bind_text(statement, index, value.uuidString, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bindOptionalString(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bindOptionalDouble(_ value: Double?, to statement: OpaquePointer?, at index: Int32) {
        if let value {
            sqlite3_bind_double(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bindTransactionCurrencyMetadata(
        _ transaction: Transaction,
        to statement: OpaquePointer?,
        startingAt index: Int32
    ) {
        bindOptionalString(transaction.ledgerCurrencyCode, to: statement, at: index)
        bindOptionalDouble(transaction.originalAmount, to: statement, at: index + 1)
        bindOptionalString(transaction.originalCurrencyCode, to: statement, at: index + 2)
        bindOptionalDouble(transaction.exchangeRate, to: statement, at: index + 3)
        bindOptionalString(transaction.exchangeRateDate, to: statement, at: index + 4)
        bindOptionalString(transaction.exchangeRateProvider, to: statement, at: index + 5)
    }

    private func bindBackupTransactionCurrencyMetadata(
        _ transaction: BackupTransaction,
        to statement: OpaquePointer?,
        startingAt index: Int32
    ) {
        bindOptionalString(transaction.ledgerCurrencyCode, to: statement, at: index)
        bindOptionalDouble(transaction.originalAmount, to: statement, at: index + 1)
        bindOptionalString(transaction.originalCurrencyCode, to: statement, at: index + 2)
        bindOptionalDouble(transaction.exchangeRate, to: statement, at: index + 3)
        bindOptionalString(transaction.exchangeRateDate, to: statement, at: index + 4)
        bindOptionalString(transaction.exchangeRateProvider, to: statement, at: index + 5)
    }

    private func bindOptionalData(_ value: Data?, to statement: OpaquePointer?, at index: Int32) {
        guard let value, !value.isEmpty else {
            sqlite3_bind_null(statement, index)
            return
        }

        _ = value.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(value.count), sqliteTransient)
        }
    }

    private func bindOptionalLocalizedData(
        _ value: HotelStayLocalizedData?,
        to statement: OpaquePointer?,
        at index: Int32
    ) {
        guard let value,
              let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8),
              !json.isEmpty else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_text(statement, index, json, -1, sqliteTransient)
    }

    private static func string(from statement: OpaquePointer?, index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let cString = sqlite3_column_text(statement, index) else {
            return nil
        }
        let value = String(cString: cString).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func double(from statement: OpaquePointer?, index: Int32) -> Double? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_double(statement, index)
    }

    private static func data(from statement: OpaquePointer?, index: Int32) -> Data? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        let byteCount = sqlite3_column_bytes(statement, index)
        guard byteCount > 0,
              let bytes = sqlite3_column_blob(statement, index) else {
            return nil
        }
        return Data(bytes: bytes, count: Int(byteCount))
    }

    private static func localizedData(from statement: OpaquePointer?, index: Int32) -> HotelStayLocalizedData? {
        guard let json = string(from: statement, index: index),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(HotelStayLocalizedData.self, from: data)
    }

    private static func uuid(from statement: OpaquePointer?, index: Int32) -> UUID? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let cString = sqlite3_column_text(statement, index) else {
            return nil
        }
        return UUID(uuidString: String(cString: cString))
    }

    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"

    private static func makeDatabaseURL(baseDirectoryURL: URL? = nil, filename: String) throws -> URL {
        let fileManager = FileManager.default

        if let provided = baseDirectoryURL {
            return try makeDatabaseURL(
                in: provided,
                filename: filename,
                fileManager: fileManager,
                migrateLegacyDatabase: false
            )
        }

        // 优先使用 App Group 共享容器（Share Extension 也能访问）。
        // A locally launched unsigned Debug build can receive the Group Container
        // URL while sandboxing still denies writes to it. Verify that the
        // container is writable before accepting it as the database location.
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            do {
                return try makeDatabaseURL(
                    in: groupURL,
                    filename: filename,
                    fileManager: fileManager,
                    migrateLegacyDatabase: true
                )
            } catch {
                guard isUnavailableAppGroupContainer(error) else {
                    throw error
                }
            }
        }

        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try makeDatabaseURL(
            in: applicationSupportURL,
            filename: filename,
            fileManager: fileManager,
            migrateLegacyDatabase: true
        )
    }

    private static func makeDatabaseURL(
        in base: URL,
        filename: String,
        fileManager: FileManager,
        migrateLegacyDatabase: Bool
    ) throws -> URL {
        let folder = base.appendingPathComponent("AutoLedger", isDirectory: true)

        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try verifyWritableDirectory(folder, fileManager: fileManager)

        let targetURL = folder.appendingPathComponent(filename)
        guard migrateLegacyDatabase, !fileManager.fileExists(atPath: targetURL.path) else {
            return targetURL
        }

        // 迁移旧数据：从 Application Support 迁移到 App Group 容器。
        let legacyBase = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let legacyURL = legacyBase
            .appendingPathComponent("AutoLedger", isDirectory: true)
            .appendingPathComponent(filename)
        if fileManager.fileExists(atPath: legacyURL.path), legacyURL != targetURL {
            try? fileManager.moveItem(at: legacyURL, to: targetURL)
        }
        return targetURL
    }

    private static func verifyWritableDirectory(_ folder: URL, fileManager: FileManager) throws {
        let probeURL = folder.appendingPathComponent(".autoledger-write-probe-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: probeURL) }
        try Data().write(to: probeURL, options: .withoutOverwriting)
    }

    private static func isUnavailableAppGroupContainer(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain {
            return error.code == NSFileNoSuchFileError
                || error.code == NSFileReadNoPermissionError
                || error.code == NSFileWriteNoPermissionError
        }
        if error.domain == NSPOSIXErrorDomain {
            return error.code == Int(EACCES) || error.code == Int(EPERM) || error.code == Int(ENOENT)
        }
        return false
    }

    private static let syncDeviceIDKey = "top.darkrio326.AutoLedger.syncDeviceID"

    private static func localSyncDeviceID() -> String {
        if let existing = UserDefaults.standard.string(forKey: syncDeviceIDKey),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: syncDeviceIDKey)
        return generated
    }

    private static func defaultIdempotencyKey(for transactionID: UUID) -> String {
        "transaction:\(transactionID.uuidString)"
    }

    private func configureDatabaseConnection() {
        _ = sqlite3_extended_result_codes(db, 1)
        _ = sqlite3_busy_timeout(db, Self.busyTimeoutMilliseconds)
        _ = sqlite3_exec(db, "PRAGMA busy_timeout = \(Self.busyTimeoutMilliseconds);", nil, nil, nil)
        _ = sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
        _ = sqlite3_exec(db, "PRAGMA synchronous = NORMAL;", nil, nil, nil)
    }

    private func stepWithBusyRetry(_ statement: OpaquePointer?, sql: String) -> Int32 {
        var result = sqlite3_step(statement)
        for delay in Self.busyRetryDelays where Self.isBusy(result) {
            sqlite3_reset(statement)
            Thread.sleep(forTimeInterval: delay)
            result = sqlite3_step(statement)
        }
        return result
    }

    private static func isBusy(_ result: Int32) -> Bool {
        result == SQLITE_BUSY || result == SQLITE_LOCKED
    }

    private func prepareStatementError(_ sql: String) -> SQLiteTransactionStoreError {
        .prepareStatement(sqlWithSQLiteError(sql))
    }

    private func executeStatementError(_ sql: String) -> SQLiteTransactionStoreError {
        .executeStatement(sqlWithSQLiteError(sql))
    }

    private func sqlWithSQLiteError(_ sql: String) -> String {
        let code = sqlite3_errcode(db)
        let extendedCode = sqlite3_extended_errcode(db)
        let message = sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
        return "\(sql) [sqlite_code=\(code), sqlite_extended_code=\(extendedCode), message=\(message)]"
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw executeStatementError(sql)
        }
    }

    // MARK: - Subscriptions

    public func loadSubscriptions() throws -> [Subscription] {
        let sql = """
        SELECT id, merchant, plan_name, period, amount, currency_code, last_charged_at, next_charged_at, status, created_at
        FROM subscriptions
        ORDER BY next_charged_at ASC;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        var items: [Subscription] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idCStr         = sqlite3_column_text(statement, 0),
                let merchantCStr   = sqlite3_column_text(statement, 1),
                let planCStr       = sqlite3_column_text(statement, 2),
                let periodCStr     = sqlite3_column_text(statement, 3),
                let currencyCStr   = sqlite3_column_text(statement, 5),
                let lastCStr       = sqlite3_column_text(statement, 6),
                let nextCStr       = sqlite3_column_text(statement, 7),
                let statusCStr     = sqlite3_column_text(statement, 8),
                let createdCStr    = sqlite3_column_text(statement, 9),
                let id             = UUID(uuidString: String(cString: idCStr)),
                let period         = SubscriptionPeriod(rawValue: String(cString: periodCStr)),
                let lastChargedAt  = Self.storageFormatter.date(from: String(cString: lastCStr)),
                let nextChargedAt  = Self.storageFormatter.date(from: String(cString: nextCStr)),
                let createdAt      = Self.storageFormatter.date(from: String(cString: createdCStr))
            else { continue }

            let amount = sqlite3_column_double(statement, 4)
            let status = SubscriptionStatus(rawValue: String(cString: statusCStr)) ?? .active

            items.append(Subscription(
                id: id,
                merchant: String(cString: merchantCStr),
                planName: String(cString: planCStr),
                period: period,
                amount: amount,
                currencyCode: String(cString: currencyCStr),
                lastChargedAt: lastChargedAt,
                nextChargedAt: nextChargedAt,
                status: status,
                createdAt: createdAt
            ))
        }
        return items
    }

    public func saveSubscription(_ sub: Subscription) throws {
        let sql = """
        INSERT INTO subscriptions
            (id, merchant, plan_name, period, amount, currency_code, last_charged_at, next_charged_at, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        let now = Self.storageFormatter.string(from: .now)
        bindSubscription(
            sub,
            to: statement,
            updatedAt: now,
            createdAt: Self.storageFormatter.string(from: sub.createdAt)
        )

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func updateSubscription(_ sub: Subscription) throws {
        let sql = """
        UPDATE subscriptions
        SET merchant = ?, plan_name = ?, period = ?, amount = ?, currency_code = ?,
            last_charged_at = ?, next_charged_at = ?, status = ?, updated_at = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        let now = Self.storageFormatter.string(from: .now)
        sqlite3_bind_text(statement, 1, sub.merchant,                                      -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, sub.planName,                                      -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, sub.period.rawValue,                               -1, sqliteTransient)
        sqlite3_bind_double(statement, 4, sub.amount)
        sqlite3_bind_text(statement, 5, sub.currencyCode,                                  -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, Self.storageFormatter.string(from: sub.lastChargedAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, Self.storageFormatter.string(from: sub.nextChargedAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 8, sub.status.rawValue,                               -1, sqliteTransient)
        sqlite3_bind_text(statement, 9, now,                                               -1, sqliteTransient)
        sqlite3_bind_text(statement, 10, sub.id.uuidString,                                -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func deleteSubscription(id: UUID) throws {
        let sql = "DELETE FROM subscriptions WHERE id = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }
        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    private func bindSubscription(
        _ sub: Subscription,
        to statement: OpaquePointer?,
        updatedAt: String,
        createdAt: String
    ) {
        sqlite3_bind_text(statement, 1, sub.id.uuidString,                                     -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, sub.merchant,                                          -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, sub.planName,                                          -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, sub.period.rawValue,                                   -1, sqliteTransient)
        sqlite3_bind_double(statement, 5, sub.amount)
        sqlite3_bind_text(statement, 6, sub.currencyCode,                                      -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, Self.storageFormatter.string(from: sub.lastChargedAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 8, Self.storageFormatter.string(from: sub.nextChargedAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 9, sub.status.rawValue,                                   -1, sqliteTransient)
        sqlite3_bind_text(statement, 10, createdAt,                                            -1, sqliteTransient)
        sqlite3_bind_text(statement, 11, updatedAt,                                            -1, sqliteTransient)
    }

    // MARK: - Category Corrections

    public func loadCategoryCorrections() throws -> [String: TransactionCategory] {
        let sql = "SELECT merchant, category FROM category_corrections;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        var map: [String: TransactionCategory] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let merchantCStr = sqlite3_column_text(statement, 0),
                let categoryCStr = sqlite3_column_text(statement, 1),
                let category = TransactionCategory(rawValue: String(cString: categoryCStr))
            else { continue }
            map[String(cString: merchantCStr)] = category
        }
        return map
    }

    public func saveCategoryCorrection(merchant: String, category: TransactionCategory) throws {
        let sql = """
        INSERT INTO category_corrections (merchant, category, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(merchant) DO UPDATE SET category = excluded.category, updated_at = excluded.updated_at;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        let now = Self.storageFormatter.string(from: .now)
        sqlite3_bind_text(statement, 1, merchant, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, category.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, now, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func deleteCategoryCorrection(merchant: String) throws {
        let sql = "DELETE FROM category_corrections WHERE merchant = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }
        sqlite3_bind_text(statement, 1, merchant, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    // MARK: - Merchant Aliases

    public func loadMerchantAliases() throws -> [String: String] {
        let sql = "SELECT original, alias FROM merchant_aliases;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        var map: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let originalCStr = sqlite3_column_text(statement, 0),
                let aliasCStr    = sqlite3_column_text(statement, 1)
            else { continue }
            map[String(cString: originalCStr)] = String(cString: aliasCStr)
        }
        return map
    }

    public func saveMerchantAlias(original: String, alias: String) throws {
        let sql = """
        INSERT INTO merchant_aliases (original, alias, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(original) DO UPDATE SET alias = excluded.alias, updated_at = excluded.updated_at;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        let now = Self.storageFormatter.string(from: .now)
        sqlite3_bind_text(statement, 1, original, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, alias,    -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, now,      -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func deleteMerchantAlias(original: String) throws {
        let sql = "DELETE FROM merchant_aliases WHERE original = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }
        sqlite3_bind_text(statement, 1, original, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    nonisolated(unsafe) private static let storageFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
