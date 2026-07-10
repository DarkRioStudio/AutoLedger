import Foundation

public enum LedgerCSVCodecError: Error, LocalizedError, Sendable {
    case invalidUTF8
    case missingHeader
    case missingRequiredColumns([String])
    case duplicateColumns([String])

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "CSV data is not valid UTF-8."
        case .missingHeader:
            return "CSV header is missing."
        case let .missingRequiredColumns(columns):
            return "CSV is missing required columns: \(columns.joined(separator: ", "))."
        case let .duplicateColumns(columns):
            return "CSV contains duplicate columns: \(columns.joined(separator: ", "))."
        }
    }
}

public struct LedgerCSVImportedRow: Equatable, Sendable {
    public var lineNumber: Int
    public var rawText: String
    public var transaction: Transaction?
    public var failureReason: BatchImportFailureReason?

    public init(
        lineNumber: Int,
        rawText: String,
        transaction: Transaction?,
        failureReason: BatchImportFailureReason?
    ) {
        self.lineNumber = lineNumber
        self.rawText = rawText
        self.transaction = transaction
        self.failureReason = failureReason
    }
}

public struct LedgerCSVImportResult: Equatable, Sendable {
    public var rows: [LedgerCSVImportedRow]

    public init(rows: [LedgerCSVImportedRow]) {
        self.rows = rows
    }

    public var validCount: Int {
        rows.filter { $0.transaction != nil }.count
    }

    public var failedCount: Int {
        rows.filter { $0.transaction == nil || $0.failureReason != nil }.count
    }
}

public enum LedgerCSVCodec {
    public static let header = ["id", "occurredAt", "merchant", "amount", "category", "source", "note"]

    public static func encode(transactions: [Transaction]) throws -> Data {
        let rows = [header] + transactions
            .sorted { $0.occurredAt > $1.occurredAt }
            .map { transaction in
                [
                    transaction.id.uuidString,
                    DateFormatter.ledgerCSVFormatter.string(from: transaction.occurredAt),
                    transaction.merchant,
                    String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), transaction.amount),
                    transaction.category,
                    transaction.source,
                    transaction.note
                ]
            }
        let text = rows.map { row in
            row.map(escape).joined(separator: ",")
        }
        .joined(separator: "\n")
        return Data((text + "\n").utf8)
    }

    public static func decode(data: Data) throws -> LedgerCSVImportResult {
        guard let text = String(data: data, encoding: .utf8) else {
            throw LedgerCSVCodecError.invalidUTF8
        }
        let rows = parse(text)
        guard let headerRow = rows.first else {
            throw LedgerCSVCodecError.missingHeader
        }

        let normalizedHeader = headerRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let required = ["occurredAt", "merchant", "amount"]
        let missing = required.filter { column in
            !normalizedHeader.contains(column)
        }
        guard missing.isEmpty else {
            throw LedgerCSVCodecError.missingRequiredColumns(missing)
        }

        let duplicateColumns = Dictionary(grouping: normalizedHeader, by: { $0 })
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
            .keys
            .sorted()
        guard duplicateColumns.isEmpty else {
            throw LedgerCSVCodecError.duplicateColumns(duplicateColumns)
        }

        let indexByColumn = Dictionary(uniqueKeysWithValues: normalizedHeader.enumerated().map { ($0.element, $0.offset) })
        let importedRows = rows.dropFirst().enumerated().compactMap { offset, columns -> LedgerCSVImportedRow? in
            let lineNumber = offset + 2
            guard !columns.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                return nil
            }

            let rawText = normalizedHeader.enumerated()
                .map { index, column in
                    let value = index < columns.count ? columns[index] : ""
                    return "\(column)=\(value)"
                }
                .joined(separator: "\n")

            let merchant = value(for: "merchant", in: columns, indexByColumn: indexByColumn)
            let amountText = value(for: "amount", in: columns, indexByColumn: indexByColumn)
                .replacingOccurrences(of: "¥", with: "")
                .replacingOccurrences(of: ",", with: "")
            let occurredAtText = value(for: "occurredAt", in: columns, indexByColumn: indexByColumn)
            let category = value(for: "category", in: columns, indexByColumn: indexByColumn)
            let source = value(for: "source", in: columns, indexByColumn: indexByColumn)
            let note = value(for: "note", in: columns, indexByColumn: indexByColumn)

            guard !merchant.isEmpty else {
                return LedgerCSVImportedRow(lineNumber: lineNumber, rawText: rawText, transaction: nil, failureReason: .missingMerchant)
            }
            guard let amount = Double(amountText), amount > 0 else {
                return LedgerCSVImportedRow(lineNumber: lineNumber, rawText: rawText, transaction: nil, failureReason: .missingAmount)
            }
            guard let occurredAt = DateFormatter.ledgerCSVFormatter.date(from: occurredAtText)
                ?? ISO8601DateFormatter().date(from: occurredAtText) else {
                return LedgerCSVImportedRow(lineNumber: lineNumber, rawText: rawText, transaction: nil, failureReason: .missingDate)
            }

            let idText = value(for: "id", in: columns, indexByColumn: indexByColumn)
            let transaction = Transaction(
                id: UUID(uuidString: idText) ?? UUID(),
                merchant: merchant,
                amount: amount,
                occurredAt: occurredAt,
                categoryLabel: category.isEmpty ? TransactionCategory.other.rawValue : category,
                sourceLabel: source.isEmpty ? ReceiptSource.manual.rawValue : source,
                note: note
            )
            return LedgerCSVImportedRow(lineNumber: lineNumber, rawText: rawText, transaction: transaction, failureReason: nil)
        }
        return LedgerCSVImportResult(rows: importedRows)
    }

    private static func value(
        for column: String,
        in values: [String],
        indexByColumn: [String: Int]
    ) -> String {
        guard let index = indexByColumn[column], index < values.count else { return "" }
        return values[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if isQuoted {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            isQuoted = false
                            if next == "," {
                                row.append(field)
                                field = ""
                            } else if next == "\n" {
                                row.append(field)
                                rows.append(row)
                                row = []
                                field = ""
                            } else if next != "\r" {
                                field.append(next)
                            }
                        }
                    } else {
                        isQuoted = false
                    }
                } else if field.isEmpty {
                    isQuoted = true
                } else {
                    field.append(character)
                }
            } else if character == "," && !isQuoted {
                row.append(field)
                field = ""
            } else if character == "\n" && !isQuoted {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}

private extension DateFormatter {
    static let ledgerCSVFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter
    }()
}
