import Foundation
import SQLite3

enum SQLiteTransactionStoreError: LocalizedError {
    case openDatabase
    case prepareStatement(String)
    case executeStatement(String)

    var errorDescription: String? {
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

final class SQLiteTransactionStore: TransactionStore {
    private var db: OpaquePointer?

    init(baseDirectoryURL: URL? = nil, filename: String = "autoledger.sqlite3") throws {
        let url = try Self.makeDatabaseURL(baseDirectoryURL: baseDirectoryURL, filename: filename)

        if sqlite3_open(url.path, &db) != SQLITE_OK {
            throw SQLiteTransactionStoreError.openDatabase
        }

        try createTableIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    func loadTransactions() throws -> [Transaction] {
        let sql = """
        SELECT id, merchant, amount, occurred_at, category, source, note
        FROM transactions
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
                let occurredAt = Self.storageFormatter.date(from: String(cString: occurredCString)),
                let category = TransactionCategory(rawValue: String(cString: categoryCString)),
                let source = ReceiptSource(rawValue: String(cString: sourceCString))
            else {
                continue
            }

            let merchant = String(cString: merchantCString)
            let note = String(cString: noteCString)
            let amount = sqlite3_column_double(statement, 2)

            items.append(
                Transaction(
                    id: id,
                    merchant: merchant,
                    amount: amount,
                    occurredAt: occurredAt,
                    category: category,
                    source: source,
                    note: note
                )
            )
        }

        return items
    }

    func save(transaction: Transaction) throws {
        let sql = """
        INSERT INTO transactions (id, merchant, amount, occurred_at, category, source, note, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
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

    func update(transaction: Transaction) throws {
        let sql = """
        UPDATE transactions
        SET merchant = ?, amount = ?, occurred_at = ?, category = ?, source = ?, note = ?, updated_at = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.prepareStatement(sql)
        }

        sqlite3_bind_text(statement, 1, transaction.merchant, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 2, transaction.amount)
        sqlite3_bind_text(statement, 3, Self.storageFormatter.string(from: transaction.occurredAt), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, transaction.category.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, transaction.source.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, transaction.note, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 7, Self.storageFormatter.string(from: .now), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 8, transaction.id.uuidString, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    func bootstrapIfNeeded(with transactions: [Transaction]) throws -> [Transaction] {
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
        let sql = """
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

        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    private func bind(transaction: Transaction, to statement: OpaquePointer?, includeTimestamps now: String) {
        sqlite3_bind_text(statement, 1, transaction.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, transaction.merchant, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 3, transaction.amount)
        sqlite3_bind_text(statement, 4, Self.storageFormatter.string(from: transaction.occurredAt), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, transaction.category.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, transaction.source.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 7, transaction.note, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 8, now, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 9, now, -1, SQLITE_TRANSIENT)
    }

    private static func makeDatabaseURL(baseDirectoryURL: URL? = nil, filename: String) throws -> URL {
        let fileManager = FileManager.default
        let base = try baseDirectoryURL ?? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent("AutoLedger", isDirectory: true)

        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        return folder.appendingPathComponent(filename)
    }

    private static let storageFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
