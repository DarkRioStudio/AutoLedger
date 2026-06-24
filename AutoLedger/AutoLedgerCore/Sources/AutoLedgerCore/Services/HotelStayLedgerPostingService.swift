import Foundation

public enum HotelStayLedgerPostingError: Error, Equatable, Sendable {
    case draftNotConfirmed
    case missingParsedPayload
    case missingHotelName
    case invalidTotalAmount
}

public struct HotelStayLedgerPostingResult: Equatable, Sendable {
    public var draft: HotelStayDraft
    public var hotelStayRecord: HotelStayRecord
    public var transaction: Transaction

    public init(
        draft: HotelStayDraft,
        hotelStayRecord: HotelStayRecord,
        transaction: Transaction
    ) {
        self.draft = draft
        self.hotelStayRecord = hotelStayRecord
        self.transaction = transaction
    }
}

public struct HotelStayLedgerPostingService: Sendable {
    private let now: @Sendable () -> Date
    private let hotelStayIDGenerator: @Sendable () -> UUID
    private let transactionIDGenerator: @Sendable () -> UUID

    public init(
        now: @escaping @Sendable () -> Date = { Date() },
        hotelStayIDGenerator: @escaping @Sendable () -> UUID = { UUID() },
        transactionIDGenerator: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.now = now
        self.hotelStayIDGenerator = hotelStayIDGenerator
        self.transactionIDGenerator = transactionIDGenerator
    }

    public func post(_ draft: HotelStayDraft) throws -> HotelStayLedgerPostingResult {
        guard draft.status == .confirmed else {
            throw HotelStayLedgerPostingError.draftNotConfirmed
        }
        guard let payload = draft.parsedPayload else {
            throw HotelStayLedgerPostingError.missingParsedPayload
        }
        let hotelName = try requiredString(payload.hotelName, error: .missingHotelName)
        let totalAmount = payload.totalAmount ?? 0
        guard totalAmount > 0 else {
            throw HotelStayLedgerPostingError.invalidTotalAmount
        }

        let postedAt = now()
        let hotelStayID = hotelStayIDGenerator()
        let transactionID = transactionIDGenerator()
        let ledgerID = draft.targetLedgerID ?? TodaySpendingSummary.defaultLedgerID
        let currency = trimmed(payload.currency) ?? "CNY"
        let occurredAt = transactionDate(from: payload) ?? postedAt

        let transaction = Transaction(
            id: transactionID,
            merchant: hotelName,
            amount: totalAmount,
            occurredAt: occurredAt,
            categoryLabel: "酒店住宿",
            sourceLabel: ReceiptSource.manual.rawValue,
            note: transactionNote(from: payload),
            ledgerID: ledgerID,
            hotelStayRecordID: hotelStayID
        )

        let record = HotelStayRecord(
            id: hotelStayID,
            ledgerID: ledgerID,
            linkedTransactionID: transactionID,
            hotelName: hotelName,
            hotelGroup: trimmed(payload.group),
            hotelBrand: trimmed(payload.brand),
            city: trimmed(payload.city),
            country: trimmed(payload.country),
            checkInDate: trimmed(payload.checkInDate),
            checkOutDate: trimmed(payload.checkOutDate),
            nights: payload.nights,
            roomType: trimmed(payload.roomType),
            confirmationNumber: trimmed(payload.confirmationNumber),
            currency: currency,
            roomCharge: payload.roomCharge ?? 0,
            taxAmount: payload.tax ?? 0,
            serviceCharge: payload.serviceCharge ?? 0,
            foodBeverageAmount: payload.foodBeverage ?? 0,
            otherAmount: payload.otherCharges ?? 0,
            totalAmount: totalAmount,
            paymentMethod: trimmed(payload.paymentMethod),
            sourceType: draft.sourceType,
            sourceFileName: draft.sourceFileName,
            confidence: payload.confidence ?? draft.confidence,
            rawText: draft.rawText,
            createdAt: postedAt,
            updatedAt: postedAt
        )

        var postedDraft = draft
        postedDraft.status = .postedToLedger
        postedDraft.updatedAt = postedAt

        return HotelStayLedgerPostingResult(
            draft: postedDraft,
            hotelStayRecord: record,
            transaction: transaction
        )
    }

    private func requiredString(
        _ value: String?,
        error: HotelStayLedgerPostingError
    ) throws -> String {
        guard let trimmed = trimmed(value), !trimmed.isEmpty else {
            throw error
        }
        return trimmed
    }

    private func transactionDate(from payload: HotelFolioParsedPayload) -> Date? {
        if let checkOutDate = trimmed(payload.checkOutDate),
           let date = AppFormatters.parseFlexibleDate(checkOutDate) {
            return date
        }
        if let checkInDate = trimmed(payload.checkInDate),
           let date = AppFormatters.parseFlexibleDate(checkInDate) {
            return date
        }
        return nil
    }

    private func transactionNote(from payload: HotelFolioParsedPayload) -> String {
        var parts: [String] = []
        append("入住", payload.checkInDate, to: &parts)
        append("退房", payload.checkOutDate, to: &parts)
        if let nights = payload.nights {
            parts.append("晚数：\(nights)")
        }
        append("房型", payload.roomType, to: &parts)
        append("订单号", payload.confirmationNumber, to: &parts)
        append("支付方式", payload.paymentMethod, to: &parts)
        return parts.joined(separator: "；")
    }

    private func append(_ label: String, _ value: String?, to parts: inout [String]) {
        guard let value = trimmed(value) else { return }
        parts.append("\(label)：\(value)")
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
