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
    public var averageNightlyRateCurrency: String?
    public var hasMixedCurrencies: Bool

    public init(
        rows: [HotelStayListRow],
        totalNights: Int,
        totalAmount: Double,
        averageNightlyRate: Double?,
        averageNightlyRateCurrency: String? = nil,
        hasMixedCurrencies: Bool = false
    ) {
        self.rows = rows
        self.totalNights = totalNights
        self.totalAmount = totalAmount
        self.averageNightlyRate = averageNightlyRate
        self.averageNightlyRateCurrency = averageNightlyRateCurrency
        self.hasMixedCurrencies = hasMixedCurrencies
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
    private struct DisplayCharge: Sendable {
        var currency: String
        var roomCharge: Double
        var taxAmount: Double
        var serviceCharge: Double
        var foodBeverageAmount: Double
        var otherAmount: Double
        var totalAmount: Double
    }

    public init() {}

    public func localizedAmountText(_ amount: Double, currency: String) -> String {
        amountText(amount, currency: currency)
    }

    public func makeListSnapshot(records: [HotelStayRecord], ledgerID: String? = nil) -> HotelStayListSnapshot {
        let records = filtered(records: records, ledgerID: ledgerID)
        let sorted = records.sorted { lhs, rhs in
            sortDate(for: lhs) > sortDate(for: rhs)
        }
        let rows = sorted.map(makeRow)
        let totalNights = records.reduce(0) { $0 + ($1.nights ?? 0) }
        let displayCharges = records.map { displayCharge(for: $0) }
        let totalAmount = displayCharges.reduce(0) { $0 + $1.totalAmount }
        let currencies = Set(displayCharges.compactMap { normalizedCurrencyCode($0.currency) })
        let hasMixedCurrencies = currencies.count > 1
        let averageNightlyRate = totalNights > 0 && !hasMixedCurrencies ? totalAmount / Double(totalNights) : nil
        return HotelStayListSnapshot(
            rows: rows,
            totalNights: totalNights,
            totalAmount: totalAmount,
            averageNightlyRate: averageNightlyRate,
            averageNightlyRateCurrency: currencies.count == 1 ? currencies.first : nil,
            hasMixedCurrencies: hasMixedCurrencies
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
        let displayCharge = displayCharge(for: record)
        return HotelStayListRow(
            id: record.id,
            hotelName: displayString(record.localizedData?.hotelName, fallback: record.hotelName) ?? record.hotelName,
            dateRangeText: dateRangeText(for: record),
            locationText: joined([
                displayString(record.localizedData?.city, fallback: record.city),
                displayString(record.localizedData?.country, fallback: record.country)
            ], separator: ", "),
            brandGroupText: joined([
                displayString(record.localizedData?.brand, fallback: record.hotelBrand),
                displayString(record.localizedData?.group, fallback: record.hotelGroup)
            ], separator: " / "),
            nightsText: record.nights.map(String.init) ?? "",
            totalAmountText: amountText(displayCharge.totalAmount, currency: displayCharge.currency),
            sourceType: record.sourceType,
            linkStatus: record.linkedTransactionID == nil ? .missingTransaction : .postedToLedger,
            linkedTransactionID: record.linkedTransactionID
        )
    }

    private func identityFields(for record: HotelStayRecord) -> [HotelStayDetailField] {
        compactFields([
            (.hotelName, displayString(record.localizedData?.hotelName, fallback: record.hotelName)),
            (.hotelBrand, displayString(record.localizedData?.brand, fallback: record.hotelBrand)),
            (.hotelGroup, displayString(record.localizedData?.group, fallback: record.hotelGroup)),
            (.city, displayString(record.localizedData?.city, fallback: record.city)),
            (.country, displayString(record.localizedData?.country, fallback: record.country))
        ])
    }

    private func stayFields(for record: HotelStayRecord) -> [HotelStayDetailField] {
        compactFields([
            (.checkInDate, record.checkInDate),
            (.checkOutDate, record.checkOutDate),
            (.nights, record.nights.map(String.init)),
            (.roomType, displayString(record.localizedData?.roomType, fallback: record.roomType)),
            (.confirmationNumber, record.confirmationNumber)
        ])
    }

    private func chargeFields(for record: HotelStayRecord) -> [HotelStayDetailField] {
        let displayCharge = displayCharge(for: record)
        return [
            HotelStayDetailField(key: .currency, value: displayCharge.currency),
            HotelStayDetailField(key: .roomCharge, value: amountText(displayCharge.roomCharge, currency: displayCharge.currency)),
            HotelStayDetailField(key: .taxAmount, value: amountText(displayCharge.taxAmount, currency: displayCharge.currency)),
            HotelStayDetailField(key: .serviceCharge, value: amountText(displayCharge.serviceCharge, currency: displayCharge.currency)),
            HotelStayDetailField(key: .foodBeverageAmount, value: amountText(displayCharge.foodBeverageAmount, currency: displayCharge.currency)),
            HotelStayDetailField(key: .otherAmount, value: amountText(displayCharge.otherAmount, currency: displayCharge.currency)),
            HotelStayDetailField(key: .totalAmount, value: amountText(displayCharge.totalAmount, currency: displayCharge.currency))
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

    private func displayCharge(for record: HotelStayRecord) -> DisplayCharge {
        let localized = record.localizedData
        let currency = trimmed(localized?.currency) ?? record.currency
        return DisplayCharge(
            currency: currency,
            roomCharge: localized?.roomCharge ?? record.roomCharge,
            taxAmount: localized?.taxAmount ?? record.taxAmount,
            serviceCharge: localized?.serviceCharge ?? record.serviceCharge,
            foodBeverageAmount: localized?.foodBeverageAmount ?? record.foodBeverageAmount,
            otherAmount: localized?.otherAmount ?? record.otherAmount,
            totalAmount: localized?.totalAmount ?? record.totalAmount
        )
    }

    private func displayString(_ localizedValue: String?, fallback: String?) -> String? {
        trimmed(localizedValue) ?? trimmed(fallback)
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
        let currencyCode = normalizedCurrencyCode(currency)
        guard let currencyCode else {
            return decimalAmountText(amount)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = currencyMinorDigits(currencyCode)
        formatter.minimumFractionDigits = amountHasFraction(amount) ? min(2, formatter.maximumFractionDigits) : 0
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currencyCode) \(decimalAmountText(amount))"
    }

    private func decimalAmountText(_ amount: Double) -> String {
        let rounded = amount.rounded()
        if abs(amount - rounded) < 0.000_001 {
            return String(Int(rounded))
        }

        var formatted = String(format: "%.2f", amount)
        while formatted.last == "0" {
            formatted.removeLast()
        }
        if formatted.last == "." {
            formatted.removeLast()
        }
        return formatted
    }

    private func amountHasFraction(_ amount: Double) -> Bool {
        abs(amount - amount.rounded()) >= 0.000_001
    }

    private func currencyMinorDigits(_ currencyCode: String) -> Int {
        switch currencyCode.uppercased() {
        case "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG", "RWF", "UGX", "VND", "VUV", "XAF", "XOF", "XPF":
            return 0
        default:
            return 2
        }
    }

    private func normalizedCurrencyCode(_ value: String?) -> String? {
        guard let trimmedCurrency = trimmed(value) else { return nil }
        let uppercased = trimmedCurrency.uppercased()
        switch uppercased {
        case "￥", "¥", "RMB", "CN¥", "CN￥":
            return "CNY"
        case "$", "US$":
            return "USD"
        case "€":
            return "EUR"
        case "£":
            return "GBP"
        default:
            guard uppercased.count == 3,
                  uppercased.allSatisfy({ $0.isLetter }) else {
                return trimmedCurrency
            }
            return uppercased
        }
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
