import Foundation

public struct MonthlyExportPackageOptions: Equatable, Sendable {
    public var ledgerID: String?
    public var categoryIDs: Set<String>
    public var merchantQuery: String?
    public var startDate: Date?
    public var endDate: Date?
    public var redactSensitiveFields: Bool
    public var includeHotelAttachmentIndex: Bool

    public init(
        ledgerID: String? = nil,
        categoryIDs: Set<String> = [],
        merchantQuery: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        redactSensitiveFields: Bool = false,
        includeHotelAttachmentIndex: Bool = true
    ) {
        self.ledgerID = ledgerID
        self.categoryIDs = categoryIDs
        self.merchantQuery = merchantQuery
        self.startDate = startDate
        self.endDate = endDate
        self.redactSensitiveFields = redactSensitiveFields
        self.includeHotelAttachmentIndex = includeHotelAttachmentIndex
    }
}

public enum MonthlyExportPackageFileKind: String, Codable, Equatable, Sendable {
    case excelCSV
    case printableReport
    case hotelAttachmentIndex
    case manifestJSON
}

public struct MonthlyExportPackageFile: Identifiable, Codable, Equatable, Sendable {
    public var id: String { fileName }

    public let kind: MonthlyExportPackageFileKind
    public let fileName: String
    public let mimeType: String
    public let data: Data

    public var text: String {
        String(data: data, encoding: .utf8) ?? ""
    }

    public init(kind: MonthlyExportPackageFileKind, fileName: String, mimeType: String, text: String) {
        self.kind = kind
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = Data(text.utf8)
    }
}

public struct MonthlyExportHotelAttachmentIndex: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID { hotelStayRecordID }

    public let hotelStayRecordID: UUID
    public let linkedTransactionID: UUID?
    public let hotelName: String
    public let sourceFileName: String?
    public let checkInDate: String?
    public let checkOutDate: String?
    public let nights: Int?
    public let roomNumber: String?
    public let confirmationNumber: String?
    public let currency: String
    public let totalAmount: Double
    public let hasPDFData: Bool

    public init(
        hotelStayRecordID: UUID,
        linkedTransactionID: UUID?,
        hotelName: String,
        sourceFileName: String?,
        checkInDate: String?,
        checkOutDate: String?,
        nights: Int?,
        roomNumber: String?,
        confirmationNumber: String?,
        currency: String,
        totalAmount: Double,
        hasPDFData: Bool
    ) {
        self.hotelStayRecordID = hotelStayRecordID
        self.linkedTransactionID = linkedTransactionID
        self.hotelName = hotelName
        self.sourceFileName = sourceFileName
        self.checkInDate = checkInDate
        self.checkOutDate = checkOutDate
        self.nights = nights
        self.roomNumber = roomNumber
        self.confirmationNumber = confirmationNumber
        self.currency = currency
        self.totalAmount = totalAmount
        self.hasPDFData = hasPDFData
    }
}

public struct MonthlyExportPackageSummary: Codable, Equatable, Sendable {
    public let monthLabel: String
    public let totalExpense: Double
    public let transactionCount: Int
    public let topMerchant: String
    public let categoryCount: Int
    public let hotelFolioCount: Int
    public let isRedacted: Bool

    public init(
        monthLabel: String,
        totalExpense: Double,
        transactionCount: Int,
        topMerchant: String,
        categoryCount: Int,
        hotelFolioCount: Int,
        isRedacted: Bool
    ) {
        self.monthLabel = monthLabel
        self.totalExpense = totalExpense
        self.transactionCount = transactionCount
        self.topMerchant = topMerchant
        self.categoryCount = categoryCount
        self.hotelFolioCount = hotelFolioCount
        self.isRedacted = isRedacted
    }
}

public struct MonthlyExportPackage: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let monthStart: Date
    public let monthEnd: Date
    public let summary: MonthlyExportPackageSummary
    public let files: [MonthlyExportPackageFile]
    public let hotelAttachmentIndex: [MonthlyExportHotelAttachmentIndex]

    public init(
        generatedAt: Date,
        monthStart: Date,
        monthEnd: Date,
        summary: MonthlyExportPackageSummary,
        files: [MonthlyExportPackageFile],
        hotelAttachmentIndex: [MonthlyExportHotelAttachmentIndex]
    ) {
        self.generatedAt = generatedAt
        self.monthStart = monthStart
        self.monthEnd = monthEnd
        self.summary = summary
        self.files = files
        self.hotelAttachmentIndex = hotelAttachmentIndex
    }

    public func file(kind: MonthlyExportPackageFileKind) -> MonthlyExportPackageFile? {
        files.first { $0.kind == kind }
    }

    public func fileText(kind: MonthlyExportPackageFileKind) -> String {
        file(kind: kind)?.text ?? ""
    }
}

public struct MonthlyExportPackageBuilder: Sendable {
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(calendar: Calendar = AppFormatters.calendar, now: @escaping @Sendable () -> Date = { Date() }) {
        self.calendar = calendar
        self.now = now
    }

    public func build(
        transactions: [Transaction],
        hotelStayRecords: [HotelStayRecord],
        referenceDate: Date,
        options: MonthlyExportPackageOptions = MonthlyExportPackageOptions()
    ) -> MonthlyExportPackage {
        let monthInterval = calendar.dateInterval(of: .month, for: referenceDate)
        let startDate = options.startDate ?? monthInterval?.start ?? referenceDate
        let endDate = options.endDate ?? monthInterval?.end ?? referenceDate
        let scopedTransactions = filterTransactions(transactions, startDate: startDate, endDate: endDate, options: options)
        let redactor = MonthlyExportRedactor(isEnabled: options.redactSensitiveFields)
        let snapshot = MonthlySnapshot.build(from: scopedTransactions, referenceDate: referenceDate)
        let hotelIndex = options.includeHotelAttachmentIndex
            ? buildHotelAttachmentIndex(records: hotelStayRecords, transactions: scopedTransactions, options: options, redactor: redactor)
            : []
        let monthToken = Self.monthToken(referenceDate)
        let generatedAt = now()
        let summary = MonthlyExportPackageSummary(
            monthLabel: snapshot.monthLabel,
            totalExpense: snapshot.totalExpense,
            transactionCount: scopedTransactions.count,
            topMerchant: options.redactSensitiveFields && snapshot.topMerchantMetric != nil ? "Merchant 1" : snapshot.topMerchant,
            categoryCount: snapshot.categoryBreakdown.count,
            hotelFolioCount: hotelIndex.count,
            isRedacted: options.redactSensitiveFields
        )
        let files = [
            MonthlyExportPackageFile(
                kind: .excelCSV,
                fileName: "AutoLedger_\(monthToken)_transactions.csv",
                mimeType: "text/csv",
                text: buildTransactionCSV(scopedTransactions, redactor: redactor)
            ),
            MonthlyExportPackageFile(
                kind: .printableReport,
                fileName: "AutoLedger_\(monthToken)_monthly_report.md",
                mimeType: "text/markdown",
                text: buildPrintableReport(
                    snapshot: snapshot,
                    transactions: scopedTransactions,
                    hotelIndex: hotelIndex,
                    generatedAt: generatedAt,
                    redactor: redactor,
                    isRedacted: options.redactSensitiveFields
                )
            ),
            MonthlyExportPackageFile(
                kind: .hotelAttachmentIndex,
                fileName: "AutoLedger_\(monthToken)_hotel_folios.csv",
                mimeType: "text/csv",
                text: buildHotelAttachmentCSV(hotelIndex)
            ),
            MonthlyExportPackageFile(
                kind: .manifestJSON,
                fileName: "AutoLedger_\(monthToken)_manifest.json",
                mimeType: "application/json",
                text: buildManifest(
                    monthToken: monthToken,
                    generatedAt: generatedAt,
                    summary: summary,
                    fileNames: [
                        "AutoLedger_\(monthToken)_transactions.csv",
                        "AutoLedger_\(monthToken)_monthly_report.md",
                        "AutoLedger_\(monthToken)_hotel_folios.csv"
                    ]
                )
            )
        ]

        return MonthlyExportPackage(
            generatedAt: generatedAt,
            monthStart: startDate,
            monthEnd: endDate,
            summary: summary,
            files: files,
            hotelAttachmentIndex: hotelIndex
        )
    }

    private func filterTransactions(
        _ transactions: [Transaction],
        startDate: Date,
        endDate: Date,
        options: MonthlyExportPackageOptions
    ) -> [Transaction] {
        let normalizedLedgerID = options.ledgerID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let merchantQuery = options.merchantQuery?.trimmingCharacters(in: .whitespacesAndNewlines)

        return transactions
            .filter { transaction in
                transaction.occurredAt >= startDate && transaction.occurredAt < endDate
            }
            .filter { transaction in
                guard let normalizedLedgerID, !normalizedLedgerID.isEmpty else { return true }
                return transaction.resolvedLedgerID() == normalizedLedgerID
            }
            .filter { transaction in
                options.categoryIDs.isEmpty || options.categoryIDs.contains(transaction.category)
            }
            .filter { transaction in
                guard let merchantQuery, !merchantQuery.isEmpty else { return true }
                return transaction.merchant.localizedCaseInsensitiveContains(merchantQuery)
            }
            .sorted { lhs, rhs in
                if lhs.occurredAt == rhs.occurredAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.occurredAt < rhs.occurredAt
            }
    }

    private func buildHotelAttachmentIndex(
        records: [HotelStayRecord],
        transactions: [Transaction],
        options: MonthlyExportPackageOptions,
        redactor: MonthlyExportRedactor
    ) -> [MonthlyExportHotelAttachmentIndex] {
        let transactionIDs = Set(transactions.map(\.id))
        return records
            .filter { record in
                guard let linkedTransactionID = record.linkedTransactionID else { return false }
                return transactionIDs.contains(linkedTransactionID)
            }
            .filter { record in
                guard let ledgerID = options.ledgerID?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !ledgerID.isEmpty
                else {
                    return true
                }
                return record.ledgerID == ledgerID
            }
            .sorted { lhs, rhs in
                let left = lhs.checkOutDate ?? lhs.checkInDate ?? ""
                let right = rhs.checkOutDate ?? rhs.checkInDate ?? ""
                if left == right {
                    return lhs.hotelName < rhs.hotelName
                }
                return left < right
            }
            .enumerated()
            .map { offset, record in
                MonthlyExportHotelAttachmentIndex(
                    hotelStayRecordID: record.id,
                    linkedTransactionID: record.linkedTransactionID,
                    hotelName: redactor.hotelName(record.hotelName, index: offset + 1),
                    sourceFileName: redactor.fileName(record.sourceFileName, index: offset + 1),
                    checkInDate: record.checkInDate,
                    checkOutDate: record.checkOutDate,
                    nights: record.nights,
                    roomNumber: redactor.sensitive(record.roomNumber),
                    confirmationNumber: redactor.sensitive(record.confirmationNumber),
                    currency: record.currency,
                    totalAmount: record.totalAmount,
                    hasPDFData: record.sourcePDFData?.isEmpty == false
                )
            }
    }

    private func buildTransactionCSV(_ transactions: [Transaction], redactor: MonthlyExportRedactor) -> String {
        let header = [
            "id",
            "occurredAt",
            "merchant",
            "amount",
            "ledgerCurrency",
            "category",
            "source",
            "note",
            "originalAmount",
            "originalCurrency",
            "exchangeRate",
            "exchangeRateDate",
            "exchangeRateProvider",
            "hotelStayRecordID"
        ]
        let rows = transactions.enumerated().map { offset, transaction in
            [
                transaction.id.uuidString,
                Self.isoDateTime(transaction.occurredAt),
                redactor.merchant(transaction.merchant, index: offset + 1),
                Self.decimal(transaction.amount),
                transaction.ledgerCurrencyCode ?? "",
                transaction.category,
                transaction.source,
                redactor.note(transaction.note),
                transaction.originalAmount.map(Self.decimal) ?? "",
                transaction.originalCurrencyCode ?? "",
                transaction.exchangeRate.map(Self.decimal) ?? "",
                transaction.exchangeRateDate ?? "",
                transaction.exchangeRateProvider ?? "",
                transaction.hotelStayRecordID?.uuidString ?? ""
            ]
        }

        return ([header] + rows)
            .map { row in row.map(Self.csvEscape).joined(separator: ",") }
            .joined(separator: "\n") + "\n"
    }

    private func buildPrintableReport(
        snapshot: MonthlySnapshot,
        transactions: [Transaction],
        hotelIndex: [MonthlyExportHotelAttachmentIndex],
        generatedAt: Date,
        redactor: MonthlyExportRedactor,
        isRedacted: Bool
    ) -> String {
        var lines: [String] = [
            "# AutoLedger Monthly Export",
            "",
            "- Month: \(snapshot.monthLabel)",
            "- Generated At: \(Self.isoDateTime(generatedAt))",
            "- Redacted: \(isRedacted ? "yes" : "no")",
            "- Total Expense: \(AppFormatters.currency(snapshot.totalExpense))",
            "- Transactions: \(snapshot.transactionCount)",
            "- Hotel Folios: \(hotelIndex.count)",
            "",
            "## Category Breakdown"
        ]

        if snapshot.categoryBreakdown.isEmpty {
            lines.append("- No category data")
        } else {
            for metric in snapshot.categoryBreakdown {
                lines.append("- \(metric.title): \(AppFormatters.currency(metric.total)) (\(Int((metric.ratio * 100).rounded()))%)")
            }
        }

        lines.append(contentsOf: ["", "## Top Merchants"])
        if snapshot.topMerchantMetrics.isEmpty {
            lines.append("- No merchant data")
        } else {
            for (index, metric) in snapshot.topMerchantMetrics.prefix(5).enumerated() {
                lines.append("- \(redactor.merchant(metric.merchant, index: index + 1)): \(AppFormatters.currency(metric.total)) · \(metric.transactionCount)")
            }
        }

        lines.append(contentsOf: ["", "## Transactions"])
        if transactions.isEmpty {
            lines.append("- No transactions")
        } else {
            for (index, transaction) in transactions.enumerated() {
                lines.append("- \(Self.isoDateTime(transaction.occurredAt)) · \(redactor.merchant(transaction.merchant, index: index + 1)) · \(AppFormatters.currency(transaction.amount)) · \(transaction.categoryTitle)")
            }
        }

        lines.append(contentsOf: ["", "## Hotel Folio Attachments"])
        if hotelIndex.isEmpty {
            lines.append("- No hotel folio attachments")
        } else {
            for item in hotelIndex {
                let period = [item.checkInDate, item.checkOutDate].compactMap { $0 }.joined(separator: " -> ")
                let file = item.sourceFileName ?? "missing file name"
                lines.append("- \(item.hotelName) · \(period) · \(file) · PDF: \(item.hasPDFData ? "yes" : "no")")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func buildHotelAttachmentCSV(_ index: [MonthlyExportHotelAttachmentIndex]) -> String {
        let header = [
            "hotelStayRecordID",
            "linkedTransactionID",
            "hotelName",
            "sourceFileName",
            "checkInDate",
            "checkOutDate",
            "nights",
            "roomNumber",
            "confirmationNumber",
            "currency",
            "totalAmount",
            "hasPDFData"
        ]
        let rows = index.map { item in
            [
                item.hotelStayRecordID.uuidString,
                item.linkedTransactionID?.uuidString ?? "",
                item.hotelName,
                item.sourceFileName ?? "",
                item.checkInDate ?? "",
                item.checkOutDate ?? "",
                item.nights.map(String.init) ?? "",
                item.roomNumber ?? "",
                item.confirmationNumber ?? "",
                item.currency,
                Self.decimal(item.totalAmount),
                item.hasPDFData ? "true" : "false"
            ]
        }
        return ([header] + rows)
            .map { row in row.map(Self.csvEscape).joined(separator: ",") }
            .joined(separator: "\n") + "\n"
    }

    private func buildManifest(
        monthToken: String,
        generatedAt: Date,
        summary: MonthlyExportPackageSummary,
        fileNames: [String]
    ) -> String {
        """
        {
          "schema": "autoledger.monthly_export_package.v1",
          "month": "\(monthToken)",
          "generatedAt": "\(Self.isoDateTime(generatedAt))",
          "redacted": \(summary.isRedacted ? "true" : "false"),
          "transactionCount": \(summary.transactionCount),
          "totalExpense": \(Self.decimal(summary.totalExpense)),
          "hotelFolioCount": \(summary.hotelFolioCount),
          "files": [\(fileNames.map { "\"\($0)\"" }.joined(separator: ", "))]
        }
        """
    }

    private static func monthToken(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private static func isoDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter.string(from: date)
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

private struct MonthlyExportRedactor: Sendable {
    let isEnabled: Bool

    func merchant(_ value: String, index: Int) -> String {
        isEnabled ? "Merchant \(index)" : value
    }

    func hotelName(_ value: String, index: Int) -> String {
        isEnabled ? "Hotel \(index)" : value
    }

    func note(_ value: String) -> String {
        isEnabled && !value.isEmpty ? "[redacted]" : value
    }

    func sensitive(_ value: String?) -> String? {
        guard isEnabled else { return value }
        guard value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return nil }
        return "[redacted]"
    }

    func fileName(_ value: String?, index: Int) -> String? {
        guard isEnabled else { return value }
        guard value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return nil }
        return "hotel-folio-\(index).pdf"
    }
}
