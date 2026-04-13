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

    public init(baseDirectoryURL: URL? = nil, filename: String = "autoledger.sqlite3") throws {
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

    public func update(transaction: Transaction) throws {
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

        sqlite3_bind_text(statement, 1, transaction.merchant, -1, sqliteTransient)
        sqlite3_bind_double(statement, 2, transaction.amount)
        sqlite3_bind_text(statement, 3, Self.storageFormatter.string(from: transaction.occurredAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, transaction.category, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, transaction.source, -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, transaction.note, -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, Self.storageFormatter.string(from: .now), -1, sqliteTransient)
        sqlite3_bind_text(statement, 8, transaction.id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func delete(transactionID: UUID) throws {
        let sql = "DELETE FROM transactions WHERE id = ?;"
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
        for col in ["llm_prompt", "llm_response", "image_source", "transaction_id"] {
            if !existingColumns.contains(col) {
                sqlite3_exec(db, "ALTER TABLE debug_events ADD COLUMN \(col) TEXT;", nil, nil, nil)
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

    // MARK: - Debug Events

    public func saveDebugEvent(_ record: ImportDebugRecord) throws {
        let sql = """
        INSERT INTO debug_events (id, created_at, stage, source, raw_text, parsed_merchant, parsed_amount, summary, llm_prompt, llm_response, image_source, transaction_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTransactionStoreError.executeStatement(sql)
        }
    }

    public func loadDebugEvents() throws -> [ImportDebugRecord] {
        let sql = """
        SELECT id, created_at, stage, source, raw_text, parsed_merchant, parsed_amount, summary, llm_prompt, llm_response, image_source, transaction_id
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
                    transactionID: transactionID
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
        bindSubscription(sub, to: statement, updatedAt: now, createdAt: now)

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

    nonisolated(unsafe) private static let storageFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
