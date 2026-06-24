import Foundation

public enum HotelStayLedgerLinkStatus: String, Codable, Equatable, Sendable {
    case postedToLedger
    case missingTransaction
}

public enum HotelStayDetailFieldKey: String, Codable, Equatable, Sendable {
    case hotelName
    case hotelBrand
    case hotelGroup
    case city
    case country
    case checkInDate
    case checkOutDate
    case nights
    case roomType
    case confirmationNumber
    case currency
    case roomCharge
    case taxAmount
    case serviceCharge
    case foodBeverageAmount
    case otherAmount
    case totalAmount
    case paymentMethod
    case sourceType
    case sourceFileName
    case confidence
    case linkedTransactionID
}

public struct HotelStayDetailField: Equatable, Sendable {
    public var key: HotelStayDetailFieldKey
    public var value: String

    public init(key: HotelStayDetailFieldKey, value: String) {
        self.key = key
        self.value = value
    }
}

public struct HotelStayListRow: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var hotelName: String
    public var dateRangeText: String
    public var locationText: String
    public var brandGroupText: String
    public var nightsText: String
    public var totalAmountText: String
    public var sourceType: HotelFolioSourceType
    public var linkStatus: HotelStayLedgerLinkStatus
    public var linkedTransactionID: UUID?

    public init(
        id: UUID,
        hotelName: String,
        dateRangeText: String,
        locationText: String,
        brandGroupText: String,
        nightsText: String,
        totalAmountText: String,
        sourceType: HotelFolioSourceType,
        linkStatus: HotelStayLedgerLinkStatus,
        linkedTransactionID: UUID?
    ) {
        self.id = id
        self.hotelName = hotelName
        self.dateRangeText = dateRangeText
        self.locationText = locationText
        self.brandGroupText = brandGroupText
        self.nightsText = nightsText
        self.totalAmountText = totalAmountText
        self.sourceType = sourceType
        self.linkStatus = linkStatus
        self.linkedTransactionID = linkedTransactionID
    }
}

public struct HotelStayListSnapshot: Equatable, Sendable {
    public var rows: [HotelStayListRow]
    public var totalNights: Int
    public var totalAmount: Double
    public var averageNightlyRate: Double?

    public init(
        rows: [HotelStayListRow],
        totalNights: Int,
        totalAmount: Double,
        averageNightlyRate: Double?
    ) {
        self.rows = rows
        self.totalNights = totalNights
        self.totalAmount = totalAmount
        self.averageNightlyRate = averageNightlyRate
    }
}

public struct HotelStayDetailSnapshot: Equatable, Sendable {
    public var row: HotelStayListRow
    public var identityFields: [HotelStayDetailField]
    public var stayFields: [HotelStayDetailField]
    public var chargeFields: [HotelStayDetailField]
    public var sourceFields: [HotelStayDetailField]
    public var linkedTransaction: Transaction?
    public var rawText: String

    public init(
        row: HotelStayListRow,
        identityFields: [HotelStayDetailField],
        stayFields: [HotelStayDetailField],
        chargeFields: [HotelStayDetailField],
        sourceFields: [HotelStayDetailField],
        linkedTransaction: Transaction?,
        rawText: String
    ) {
        self.row = row
        self.identityFields = identityFields
        self.stayFields = stayFields
        self.chargeFields = chargeFields
        self.sourceFields = sourceFields
        self.linkedTransaction = linkedTransaction
        self.rawText = rawText
    }
}

public struct HotelStayArchivePresenter: Sendable {
    public init() {}

    public func makeListSnapshot(records: [HotelStayRecord], ledgerID: String? = nil) -> HotelStayListSnapshot {
        let records = filtered(records: records, ledgerID: ledgerID)
        let sorted = records.sorted { lhs, rhs in
            sortDate(for: lhs) > sortDate(for: rhs)
        }
        let rows = sorted.map(makeRow)
        let totalNights = records.reduce(0) { $0 + ($1.nights ?? 0) }
        let totalAmount = records.reduce(0) { $0 + $1.totalAmount }
        let averageNightlyRate = totalNights > 0 ? totalAmount / Double(totalNights) : nil
        return HotelStayListSnapshot(
            rows: rows,
            totalNights: totalNights,
            totalAmount: totalAmount,
            averageNightlyRate: averageNightlyRate
        )
    }

    public func makeDetailSnapshot(
        record: HotelStayRecord,
        transactions: [Transaction] = [],
        ledgerID: String? = nil
    ) -> HotelStayDetailSnapshot {
        let transactions = filtered(transactions: transactions, ledgerID: ledgerID)
        let linkedTransaction = transactions.first { transaction in
            transaction.id == record.linkedTransactionID ||
            transaction.hotelStayRecordID == record.id
        }

        return HotelStayDetailSnapshot(
            row: makeRow(record: record),
            identityFields: identityFields(for: record),
            stayFields: stayFields(for: record),
            chargeFields: chargeFields(for: record),
            sourceFields: sourceFields(for: record),
            linkedTransaction: linkedTransaction,
            rawText: record.rawText
        )
    }

    private func makeRow(record: HotelStayRecord) -> HotelStayListRow {
        HotelStayListRow(
            id: record.id,
            hotelName: record.hotelName,
            dateRangeText: dateRangeText(for: record),
            locationText: joined([record.city, record.country], separator: ", "),
            brandGroupText: joined([record.hotelBrand, record.hotelGroup], separator: " / "),
            nightsText: record.nights.map(String.init) ?? "",
            totalAmountText: amountText(record.totalAmount, currency: record.currency),
            sourceType: record.sourceType,
            linkStatus: record.linkedTransactionID == nil ? .missingTransaction : .postedToLedger,
            linkedTransactionID: record.linkedTransactionID
        )
    }

    private func identityFields(for record: HotelStayRecord) -> [HotelStayDetailField] {
        compactFields([
            (.hotelName, record.hotelName),
            (.hotelBrand, record.hotelBrand),
            (.hotelGroup, record.hotelGroup),
            (.city, record.city),
            (.country, record.country)
        ])
    }

    private func stayFields(for record: HotelStayRecord) -> [HotelStayDetailField] {
        compactFields([
            (.checkInDate, record.checkInDate),
            (.checkOutDate, record.checkOutDate),
            (.nights, record.nights.map(String.init)),
            (.roomType, record.roomType),
            (.confirmationNumber, record.confirmationNumber)
        ])
    }

    private func chargeFields(for record: HotelStayRecord) -> [HotelStayDetailField] {
        [
            HotelStayDetailField(key: .currency, value: record.currency),
            HotelStayDetailField(key: .roomCharge, value: amountText(record.roomCharge, currency: record.currency)),
            HotelStayDetailField(key: .taxAmount, value: amountText(record.taxAmount, currency: record.currency)),
            HotelStayDetailField(key: .serviceCharge, value: amountText(record.serviceCharge, currency: record.currency)),
            HotelStayDetailField(key: .foodBeverageAmount, value: amountText(record.foodBeverageAmount, currency: record.currency)),
            HotelStayDetailField(key: .otherAmount, value: amountText(record.otherAmount, currency: record.currency)),
            HotelStayDetailField(key: .totalAmount, value: amountText(record.totalAmount, currency: record.currency))
        ] + compactFields([
            (.paymentMethod, record.paymentMethod)
        ])
    }

    private func sourceFields(for record: HotelStayRecord) -> [HotelStayDetailField] {
        var fields = [
            HotelStayDetailField(key: .sourceType, value: record.sourceType.rawValue)
        ]
        fields.append(contentsOf: compactFields([
            (.sourceFileName, record.sourceFileName),
            (.linkedTransactionID, record.linkedTransactionID?.uuidString)
        ]))
        fields.append(
            HotelStayDetailField(
                key: .confidence,
                value: "\(Int((record.confidence * 100).rounded()))%"
            )
        )
        return fields
    }

    private func filtered(records: [HotelStayRecord], ledgerID: String?) -> [HotelStayRecord] {
        guard let targetLedgerID = trimmed(ledgerID) else { return records }
        return records.filter { trimmed($0.ledgerID) == targetLedgerID }
    }

    private func filtered(transactions: [Transaction], ledgerID: String?) -> [Transaction] {
        guard let targetLedgerID = trimmed(ledgerID) else { return transactions }
        return transactions.filter { $0.resolvedLedgerID() == targetLedgerID }
    }

    private func compactFields(_ values: [(HotelStayDetailFieldKey, String?)]) -> [HotelStayDetailField] {
        values.compactMap { key, value in
            guard let value = trimmed(value) else { return nil }
            return HotelStayDetailField(key: key, value: value)
        }
    }

    private func sortDate(for record: HotelStayRecord) -> Date {
        if let checkOutDate = trimmed(record.checkOutDate),
           let date = AppFormatters.parseFlexibleDate(checkOutDate) {
            return date
        }
        if let checkInDate = trimmed(record.checkInDate),
           let date = AppFormatters.parseFlexibleDate(checkInDate) {
            return date
        }
        return record.updatedAt
    }

    private func dateRangeText(for record: HotelStayRecord) -> String {
        switch (trimmed(record.checkInDate), trimmed(record.checkOutDate)) {
        case let (checkIn?, checkOut?):
            return "\(checkIn) - \(checkOut)"
        case let (checkIn?, nil):
            return checkIn
        case let (nil, checkOut?):
            return checkOut
        default:
            return ""
        }
    }

    private func amountText(_ amount: Double, currency: String) -> String {
        let trimmedCurrency = trimmed(currency) ?? ""
        let rounded = amount.rounded()
        let amountString: String
        if abs(amount - rounded) < 0.000_001 {
            amountString = String(Int(rounded))
        } else {
            var formatted = String(format: "%.2f", amount)
            while formatted.last == "0" {
                formatted.removeLast()
            }
            if formatted.last == "." {
                formatted.removeLast()
            }
            amountString = formatted
        }
        return trimmedCurrency.isEmpty ? amountString : "\(trimmedCurrency) \(amountString)"
    }

    private func joined(_ values: [String?], separator: String) -> String {
        values.compactMap(trimmed).joined(separator: separator)
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
