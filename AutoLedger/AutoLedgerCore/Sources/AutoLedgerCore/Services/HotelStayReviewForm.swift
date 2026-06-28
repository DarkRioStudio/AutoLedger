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
    public var localizedData: HotelStayLocalizedData?

    public init(draft: HotelStayDraft) {
        let payload = draft.parsedPayload
        let localized = draft.localizedData ?? payload?.localizedData
        localizedData = localized
        hotelName = Self.displayValue(localized?.hotelName, fallback: payload?.hotelName)
        hotelGroup = Self.displayValue(localized?.group, fallback: payload?.group)
        hotelBrand = Self.displayValue(localized?.brand, fallback: payload?.brand)
        city = Self.displayValue(localized?.city, fallback: payload?.city)
        country = Self.displayValue(localized?.country, fallback: payload?.country)
        checkInDate = payload?.checkInDate ?? ""
        checkOutDate = payload?.checkOutDate ?? ""
        nightsText = payload?.nights.map(String.init) ?? ""
        roomType = Self.displayValue(localized?.roomType, fallback: payload?.roomType)
        confirmationNumber = payload?.confirmationNumber ?? ""
        currency = Self.displayValue(localized?.currency, fallback: payload?.currency)
        roomChargeText = Self.formatAmount(localized?.roomCharge ?? payload?.roomCharge)
        taxAmountText = Self.formatAmount(localized?.taxAmount ?? payload?.tax)
        serviceChargeText = Self.formatAmount(localized?.serviceCharge ?? payload?.serviceCharge)
        foodBeverageAmountText = Self.formatAmount(localized?.foodBeverageAmount ?? payload?.foodBeverage)
        otherAmountText = Self.formatAmount(localized?.otherAmount ?? payload?.otherCharges)
        totalAmountText = Self.formatAmount(localized?.totalAmount ?? payload?.totalAmount)
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
        let displayPayload = try parsedPayload()
        let localizedData = localizedData(from: displayPayload)
        var updated = draft
        if var originalPayload = draft.parsedPayload {
            originalPayload.localizedData = localizedData
            updated.parsedPayload = originalPayload
            updated.confidence = originalPayload.confidence ?? confidence
        } else {
            updated.parsedPayload = displayPayload
            updated.confidence = displayPayload.confidence ?? confidence
        }
        updated.localizedData = localizedData
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
            rawTextExcerpt: String(rawText.prefix(240)),
            localizedData: localizedData
        )
    }

    private func localizedData(from payload: HotelFolioParsedPayload) -> HotelStayLocalizedData {
        HotelStayLocalizedData(
            hotelName: payload.hotelName,
            brand: payload.brand,
            group: payload.group,
            city: payload.city,
            country: payload.country,
            roomType: payload.roomType,
            currency: payload.currency,
            roomCharge: payload.roomCharge,
            taxAmount: payload.tax,
            serviceCharge: payload.serviceCharge,
            foodBeverageAmount: payload.foodBeverage,
            otherAmount: payload.otherCharges,
            totalAmount: payload.totalAmount,
            exchangeRate: localizedData?.exchangeRate,
            exchangeRateDate: localizedData?.exchangeRateDate,
            exchangeRateProvider: localizedData?.exchangeRateProvider,
            targetLocaleIdentifier: localizedData?.targetLocaleIdentifier ?? Locale.current.identifier,
            generatedAt: localizedData?.generatedAt ?? Date()
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

    private static func displayValue(_ localized: String?, fallback: String?) -> String {
        trimmed(localized) ?? trimmed(fallback) ?? ""
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
