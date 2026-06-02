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

public final class SQLiteTransactionStore: TransactionStore, @unchecked Sendable {
    private var db: OpaquePointer?
    private let syncDeviceID: String

    public init(
        baseDirectoryURL: URL? = nil,
        filename: String = "autoledger.sqlite3",
        syncDeviceID: String? = nil
    ) throws {
        self.syncDeviceID = syncDeviceID ?? Self.localSyncDeviceID()
        let url = try Self.makeDatabaseURL(baseDirectoryURL: baseDirectoryURL, filename: filename)

        if sqlite3_open(url.path, &db) != SQLITE_OK {
            throw SQLiteTransactionStoreError.openDatabase
        }

        try createTableIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    public func loadTransactions() throws -> [Transaction] {
        let sql = """
        SELECT id, merchant, amount, occurred_at, category, source, note
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
                    note: note
                )
            )
        }

        return items
    }

    public func save(transaction: Transaction) throws {
        let sql = """
        INSERT INTO transactions (
            id, merchant, amount, occurred_at, category, source, note, created_at, updated_at,
            sync_revision, sync_device_id, sync_idempotency_key, sync_conflict_state
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        let now = Self.storageFormatter.string(from: .now)
        bind(transaction: transaction, to: statement, includeTimestamps: now)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func update(transaction: Transaction) throws {
        let sql = """
        UPDATE transactions
        SET merchant = ?, amount = ?, occurred_at = ?, category = ?, source = ?, note = ?, updated_at = ?,
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

        sqlite3_bind_text(statement, 1, transaction.merchant, -1, sqliteTransient)
        sqlite3_bind_double(statement, 2, transaction.amount)
        sqlite3_bind_text(statement, 3, Self.storageFormatter.string(from: transaction.occurredAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, transaction.category, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, transaction.source, -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, transaction.note, -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, Self.storageFormatter.string(from: .now), -1, sqliteTransient)
        sqlite3_bind_text(statement, 8, syncDeviceID, -1, sqliteTransient)
        sqlite3_bind_text(statement, 9, SyncConflictState.clean.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 10, transaction.id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
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
        SELECT id, merchant, amount, occurred_at, category, source, note
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
        SELECT id, merchant, amount, occurred_at, category, source, note, deleted_at,
               updated_at, sync_revision, sync_device_id, sync_idempotency_key, sync_conflict_state
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

            let deletedAt: Date? = {
                guard sqlite3_column_type(statement, 7) != SQLITE_NULL,
                      let deletedCString = sqlite3_column_text(statement, 7) else { return nil }
                return Self.storageFormatter.date(from: String(cString: deletedCString))
            }()
            guard
                let updatedCString = sqlite3_column_text(statement, 8),
                let updatedAt = Self.storageFormatter.date(from: String(cString: updatedCString)),
                let deviceCString = sqlite3_column_text(statement, 10),
                let conflictCString = sqlite3_column_text(statement, 12)
            else {
                continue
            }

            let idempotencyKey: String? = sqlite3_column_type(statement, 11) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 11))
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
                    deletedAt: deletedAt,
                    syncMetadata: TransactionSyncMetadata(
                        transactionID: id,
                        updatedAt: updatedAt,
                        syncRevision: Int(sqlite3_column_int(statement, 9)),
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
        merchantAliases: [String: String] = [:]
    ) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try execute("DELETE FROM transactions;")
            try execute("DELETE FROM subscriptions;")
            try execute("DELETE FROM category_corrections;")
            try execute("DELETE FROM merchant_aliases;")

            for transaction in backupTransactions {
                try insertBackupTransaction(transaction)
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
        try backfillSyncMetadataDefaults()

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
            last_charged_at TEXT NOT NULL,
            next_charged_at TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """

        guard sqlite3_exec(db, subscriptionsSQL, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(subscriptionsSQL)
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

    public func loadTransactionSyncRecords(includeDeleted: Bool = true) throws -> [TransactionSyncRecord] {
        let deletedFilter = includeDeleted ? "" : "WHERE deleted_at IS NULL"
        let sql = """
        SELECT id, merchant, amount, occurred_at, category, source, note,
               updated_at, deleted_at, sync_revision, sync_device_id, sync_idempotency_key, sync_conflict_state
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
                continue
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
                note: String(cString: noteCString)
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
            records.append(TransactionSyncRecord(transaction: transaction, metadata: metadata))
        }

        return records
    }

    public func applyRemoteSyncRecord(_ remote: TransactionSyncRecord) throws -> TransactionSyncApplyOutcome {
        let localRecord = try loadTransactionSyncRecords(includeDeleted: true)
            .first { $0.transaction.id == remote.transaction.id }

        guard let localRecord else {
            guard remote.metadata.deletedAt == nil else {
                return .keptLocal
            }
            try insertRemoteSyncRecord(remote)
            return .inserted
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
            sync_revision, sync_device_id, sync_idempotency_key, sync_conflict_state
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
            sync_idempotency_key = ?, sync_conflict_state = ?
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
        sqlite3_bind_text(statement, 13, record.transaction.id.uuidString, -1, sqliteTransient)

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
        } else {
            bindRemoteMetadata(record.metadata, to: statement, startingAt: 8)
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
    }

    private func insertBackupTransaction(_ transaction: BackupTransaction) throws {
        let sql = """
        INSERT INTO transactions (
            id, merchant, amount, occurred_at, category, source, note, created_at, updated_at, deleted_at,
            sync_revision, sync_device_id, sync_idempotency_key, sync_conflict_state
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
                    note: String(cString: noteCString)
                )
            )
        }

        return items
    }

    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"

    private static func makeDatabaseURL(baseDirectoryURL: URL? = nil, filename: String) throws -> URL {
        let fileManager = FileManager.default

        // 优先使用 App Group 共享容器（Share Extension 也能访问）
        let base: URL
        if let provided = baseDirectoryURL {
            base = provided
        } else if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            base = groupURL
        } else {
            base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        let folder = base.appendingPathComponent("AutoLedger", isDirectory: true)

        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        // 迁移旧数据：从 Application Support 迁移到 App Group 容器
        let targetURL = folder.appendingPathComponent(filename)
        if !fileManager.fileExists(atPath: targetURL.path) {
            let legacyBase = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let legacyURL = legacyBase
                .appendingPathComponent("AutoLedger", isDirectory: true)
                .appendingPathComponent(filename)
            if fileManager.fileExists(atPath: legacyURL.path) {
                try? fileManager.moveItem(at: legacyURL, to: targetURL)
            }
        }

        return targetURL
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

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    // MARK: - Subscriptions

    public func loadSubscriptions() throws -> [Subscription] {
        let sql = """
        SELECT id, merchant, plan_name, period, amount, last_charged_at, next_charged_at, created_at
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
                let lastCStr       = sqlite3_column_text(statement, 5),
                let nextCStr       = sqlite3_column_text(statement, 6),
                let createdCStr    = sqlite3_column_text(statement, 7),
                let id             = UUID(uuidString: String(cString: idCStr)),
                let period         = SubscriptionPeriod(rawValue: String(cString: periodCStr)),
                let lastChargedAt  = Self.storageFormatter.date(from: String(cString: lastCStr)),
                let nextChargedAt  = Self.storageFormatter.date(from: String(cString: nextCStr)),
                let createdAt      = Self.storageFormatter.date(from: String(cString: createdCStr))
            else { continue }

            let amount = sqlite3_column_double(statement, 4)

            items.append(Subscription(
                id: id,
                merchant: String(cString: merchantCStr),
                planName: String(cString: planCStr),
                period: period,
                amount: amount,
                lastChargedAt: lastChargedAt,
                nextChargedAt: nextChargedAt,
                createdAt: createdAt
            ))
        }
        return items
    }

    public func saveSubscription(_ sub: Subscription) throws {
        let sql = """
        INSERT INTO subscriptions
            (id, merchant, plan_name, period, amount, last_charged_at, next_charged_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
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
        SET merchant = ?, plan_name = ?, period = ?, amount = ?,
            last_charged_at = ?, next_charged_at = ?, updated_at = ?
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
        sqlite3_bind_text(statement, 5, Self.storageFormatter.string(from: sub.lastChargedAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, Self.storageFormatter.string(from: sub.nextChargedAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, now,                                               -1, sqliteTransient)
        sqlite3_bind_text(statement, 8, sub.id.uuidString,                                 -1, sqliteTransient)

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
        sqlite3_bind_text(statement, 6, Self.storageFormatter.string(from: sub.lastChargedAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, Self.storageFormatter.string(from: sub.nextChargedAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 8, createdAt,                                             -1, sqliteTransient)
        sqlite3_bind_text(statement, 9, updatedAt,                                             -1, sqliteTransient)
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
