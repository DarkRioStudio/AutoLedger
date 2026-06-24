import Foundation

public enum HotelStayAmountBalanceStatus: String, Codable, Equatable, Sendable {
    case balanced
    case missingBreakdown
    case imbalanced
}

public enum HotelStayReviewFormError: Error, Equatable, Sendable {
    case missingHotelName
    case invalidTotalAmount
}

public struct HotelStayReviewForm: Equatable, Sendable {
    public var hotelName: String
    public var hotelGroup: String
    public var hotelBrand: String
    public var city: String
    public var country: String
    public var checkInDate: String
    public var checkOutDate: String
    public var nightsText: String
    public var roomType: String
    public var confirmationNumber: String
    public var currency: String
    public var roomChargeText: String
    public var taxAmountText: String
    public var serviceChargeText: String
    public var foodBeverageAmountText: String
    public var otherAmountText: String
    public var totalAmountText: String
    public var paymentMethod: String
    public var sourceType: HotelFolioSourceType
    public var sourceFileName: String?
    public var sourceEmailSubject: String?
    public var sourceEmailFrom: String?
    public var confidence: Double
    public var rawText: String

    public init(draft: HotelStayDraft) {
        let payload = draft.parsedPayload
        hotelName = payload?.hotelName ?? ""
        hotelGroup = payload?.group ?? ""
        hotelBrand = payload?.brand ?? ""
        city = payload?.city ?? ""
        country = payload?.country ?? ""
        checkInDate = payload?.checkInDate ?? ""
        checkOutDate = payload?.checkOutDate ?? ""
        nightsText = payload?.nights.map(String.init) ?? ""
        roomType = payload?.roomType ?? ""
        confirmationNumber = payload?.confirmationNumber ?? ""
        currency = payload?.currency ?? ""
        roomChargeText = Self.formatAmount(payload?.roomCharge)
        taxAmountText = Self.formatAmount(payload?.tax)
        serviceChargeText = Self.formatAmount(payload?.serviceCharge)
        foodBeverageAmountText = Self.formatAmount(payload?.foodBeverage)
        otherAmountText = Self.formatAmount(payload?.otherCharges)
        totalAmountText = Self.formatAmount(payload?.totalAmount)
        paymentMethod = payload?.paymentMethod ?? ""
        sourceType = draft.sourceType
        sourceFileName = draft.sourceFileName
        sourceEmailSubject = draft.sourceEmailSubject
        sourceEmailFrom = draft.sourceEmailFrom
        confidence = payload?.confidence ?? draft.confidence
        rawText = draft.rawText
    }

    public var isValid: Bool {
        !hotelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Self.amount(from: totalAmountText) ?? 0) > 0
    }

    public var amountBalanceDelta: Double {
        (Self.amount(from: totalAmountText) ?? 0) - amountBreakdownTotal
    }

    public var amountBalanceStatus: HotelStayAmountBalanceStatus {
        guard hasAmountBreakdown else { return .missingBreakdown }
        return abs(amountBalanceDelta) <= 0.01 ? .balanced : .imbalanced
    }

    public func confirmedDraft(from draft: HotelStayDraft, updatedAt: Date = Date()) throws -> HotelStayDraft {
        let payload = try parsedPayload()
        var updated = draft
        updated.parsedPayload = payload
        updated.confidence = payload.confidence ?? confidence
        updated.status = .confirmed
        updated.updatedAt = updatedAt
        return updated
    }

    public func rejectedDraft(from draft: HotelStayDraft, updatedAt: Date = Date()) -> HotelStayDraft {
        var updated = draft
        updated.status = .rejected
        updated.updatedAt = updatedAt
        return updated
    }

    public func parsedPayload() throws -> HotelFolioParsedPayload {
        guard !hotelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HotelStayReviewFormError.missingHotelName
        }
        guard let totalAmount = Self.amount(from: totalAmountText), totalAmount > 0 else {
            throw HotelStayReviewFormError.invalidTotalAmount
        }

        return HotelFolioParsedPayload(
            hotelName: trimmedOptional(hotelName),
            brand: trimmedOptional(hotelBrand),
            group: trimmedOptional(hotelGroup),
            city: trimmedOptional(city),
            country: trimmedOptional(country),
            checkInDate: trimmedOptional(checkInDate),
            checkOutDate: trimmedOptional(checkOutDate),
            nights: Self.intValue(from: nightsText),
            roomType: trimmedOptional(roomType),
            confirmationNumber: trimmedOptional(confirmationNumber),
            currency: trimmedOptional(currency.uppercased()),
            roomCharge: Self.amount(from: roomChargeText),
            tax: Self.amount(from: taxAmountText),
            serviceCharge: Self.amount(from: serviceChargeText),
            foodBeverage: Self.amount(from: foodBeverageAmountText),
            otherCharges: Self.amount(from: otherAmountText),
            totalAmount: totalAmount,
            paymentMethod: trimmedOptional(paymentMethod),
            confidence: min(max(confidence, 0), 1),
            rawTextExcerpt: String(rawText.prefix(240))
        )
    }

    private var amountBreakdownTotal: Double {
        [
            roomChargeText,
            taxAmountText,
            serviceChargeText,
            foodBeverageAmountText,
            otherAmountText
        ]
        .compactMap(Self.amount)
        .reduce(0, +)
    }

    private var hasAmountBreakdown: Bool {
        [
            roomChargeText,
            taxAmountText,
            serviceChargeText,
            foodBeverageAmountText,
            otherAmountText
        ]
        .contains { (Self.amount(from: $0) ?? 0) > 0 }
    }

    private func trimmedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func amount(from text: String) -> Double? {
        LedgerAmountInputParser.parse(text)
    }

    private static func intValue(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private static func formatAmount(_ value: Double?) -> String {
        guard let value else { return "" }
        let rounded = value.rounded()
        if abs(value - rounded) < 0.000_001 {
            return String(Int(rounded))
        }
        var formatted = String(format: "%.2f", value)
        while formatted.last == "0" {
            formatted.removeLast()
        }
        if formatted.last == "." {
            formatted.removeLast()
        }
        return formatted
    }
}
