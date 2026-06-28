import Foundation

public enum HotelFolioSourceType: String, Codable, CaseIterable, Sendable {
    case manualPDF
    case localEmailIMAP
    case cloudWorker
    case shareExtension
}

public enum HotelStayDraftStatus: String, Codable, CaseIterable, Sendable {
    case imported
    case textExtracted
    case parsed
    case needsReview
    case confirmed
    case rejected
    case postedToLedger
}

public struct HotelStayLocalizedData: Codable, Equatable, Sendable {
    public var hotelName: String?
    public var brand: String?
    public var group: String?
    public var city: String?
    public var country: String?
    public var roomType: String?
    public var currency: String?
    public var roomCharge: Double?
    public var taxAmount: Double?
    public var serviceCharge: Double?
    public var foodBeverageAmount: Double?
    public var otherAmount: Double?
    public var totalAmount: Double?
    public var paymentMethod: String?
    public var exchangeRate: Double?
    public var exchangeRateDate: String?
    public var exchangeRateProvider: String?
    public var targetLocaleIdentifier: String?
    public var generatedAt: Date?

    public init(
        hotelName: String? = nil,
        brand: String? = nil,
        group: String? = nil,
        city: String? = nil,
        country: String? = nil,
        roomType: String? = nil,
        currency: String? = nil,
        roomCharge: Double? = nil,
        taxAmount: Double? = nil,
        serviceCharge: Double? = nil,
        foodBeverageAmount: Double? = nil,
        otherAmount: Double? = nil,
        totalAmount: Double? = nil,
        paymentMethod: String? = nil,
        exchangeRate: Double? = nil,
        exchangeRateDate: String? = nil,
        exchangeRateProvider: String? = nil,
        targetLocaleIdentifier: String? = nil,
        generatedAt: Date? = nil
    ) {
        self.hotelName = hotelName
        self.brand = brand
        self.group = group
        self.city = city
        self.country = country
        self.roomType = roomType
        self.currency = currency
        self.roomCharge = roomCharge
        self.taxAmount = taxAmount
        self.serviceCharge = serviceCharge
        self.foodBeverageAmount = foodBeverageAmount
        self.otherAmount = otherAmount
        self.totalAmount = totalAmount
        self.paymentMethod = paymentMethod
        self.exchangeRate = exchangeRate
        self.exchangeRateDate = exchangeRateDate
        self.exchangeRateProvider = exchangeRateProvider
        self.targetLocaleIdentifier = targetLocaleIdentifier
        self.generatedAt = generatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case hotelName = "hotel_name"
        case brand
        case group
        case city
        case country
        case roomType = "room_type"
        case currency
        case roomCharge = "room_charge"
        case taxAmount = "tax"
        case serviceCharge = "service_charge"
        case foodBeverageAmount = "food_beverage"
        case otherAmount = "other_charges"
        case totalAmount = "total_amount"
        case paymentMethod = "payment_method"
        case exchangeRate = "exchange_rate"
        case exchangeRateDate = "exchange_rate_date"
        case exchangeRateProvider = "exchange_rate_provider"
        case targetLocaleIdentifier = "target_locale"
        case generatedAt = "generated_at"
    }
}

public struct HotelFolioParsedPayload: Codable, Equatable, Sendable {
    public var hotelName: String?
    public var brand: String?
    public var group: String?
    public var city: String?
    public var country: String?
    public var checkInDate: String?
    public var checkOutDate: String?
    public var nights: Int?
    public var roomType: String?
    public var confirmationNumber: String?
    public var currency: String?
    public var roomCharge: Double?
    public var tax: Double?
    public var serviceCharge: Double?
    public var foodBeverage: Double?
    public var otherCharges: Double?
    public var totalAmount: Double?
    public var paymentMethod: String?
    public var confidence: Double?
    public var rawTextExcerpt: String?
    public var localizedData: HotelStayLocalizedData?

    public init(
        hotelName: String? = nil,
        brand: String? = nil,
        group: String? = nil,
        city: String? = nil,
        country: String? = nil,
        checkInDate: String? = nil,
        checkOutDate: String? = nil,
        nights: Int? = nil,
        roomType: String? = nil,
        confirmationNumber: String? = nil,
        currency: String? = nil,
        roomCharge: Double? = nil,
        tax: Double? = nil,
        serviceCharge: Double? = nil,
        foodBeverage: Double? = nil,
        otherCharges: Double? = nil,
        totalAmount: Double? = nil,
        paymentMethod: String? = nil,
        confidence: Double? = nil,
        rawTextExcerpt: String? = nil,
        localizedData: HotelStayLocalizedData? = nil
    ) {
        self.hotelName = hotelName
        self.brand = brand
        self.group = group
        self.city = city
        self.country = country
        self.checkInDate = checkInDate
        self.checkOutDate = checkOutDate
        self.nights = nights
        self.roomType = roomType
        self.confirmationNumber = confirmationNumber
        self.currency = currency
        self.roomCharge = roomCharge
        self.tax = tax
        self.serviceCharge = serviceCharge
        self.foodBeverage = foodBeverage
        self.otherCharges = otherCharges
        self.totalAmount = totalAmount
        self.paymentMethod = paymentMethod
        self.confidence = confidence
        self.rawTextExcerpt = rawTextExcerpt
        self.localizedData = localizedData
    }

    private enum CodingKeys: String, CodingKey {
        case hotelName = "hotel_name"
        case brand
        case group
        case city
        case country
        case checkInDate = "check_in_date"
        case checkOutDate = "check_out_date"
        case nights
        case roomType = "room_type"
        case confirmationNumber = "confirmation_number"
        case currency
        case roomCharge = "room_charge"
        case tax
        case serviceCharge = "service_charge"
        case foodBeverage = "food_beverage"
        case otherCharges = "other_charges"
        case totalAmount = "total_amount"
        case paymentMethod = "payment_method"
        case confidence
        case rawTextExcerpt = "raw_text_excerpt"
        case localizedData = "localized"
    }
}

public struct HotelStayDraft: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sourceType: HotelFolioSourceType
    public var targetLedgerID: String?
    public var sourceFileName: String?
    public var sourcePDFData: Data?
    public var sourceEmailSubject: String?
    public var sourceEmailFrom: String?
    public var sourceEmailUID: String?
    public var sourceEmailMessageIDHash: String?
    public var sourceEmailAttachmentHash: String?
    public var sourceEmailDateText: String?
    public var rawText: String
    public var parsedPayload: HotelFolioParsedPayload?
    public var localizedData: HotelStayLocalizedData?
    public var confidence: Double
    public var status: HotelStayDraftStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        sourceType: HotelFolioSourceType,
        targetLedgerID: String? = nil,
        sourceFileName: String? = nil,
        sourcePDFData: Data? = nil,
        sourceEmailSubject: String? = nil,
        sourceEmailFrom: String? = nil,
        sourceEmailUID: String? = nil,
        sourceEmailMessageIDHash: String? = nil,
        sourceEmailAttachmentHash: String? = nil,
        sourceEmailDateText: String? = nil,
        rawText: String = "",
        parsedPayload: HotelFolioParsedPayload? = nil,
        localizedData: HotelStayLocalizedData? = nil,
        confidence: Double = 0,
        status: HotelStayDraftStatus = .imported,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.targetLedgerID = targetLedgerID
        self.sourceFileName = sourceFileName
        self.sourcePDFData = sourcePDFData
        self.sourceEmailSubject = sourceEmailSubject
        self.sourceEmailFrom = sourceEmailFrom
        self.sourceEmailUID = sourceEmailUID
        self.sourceEmailMessageIDHash = sourceEmailMessageIDHash
        self.sourceEmailAttachmentHash = sourceEmailAttachmentHash
        self.sourceEmailDateText = sourceEmailDateText
        self.rawText = rawText
        self.parsedPayload = parsedPayload
        self.localizedData = localizedData
        self.confidence = confidence
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct HotelStayRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var ledgerID: String
    public var linkedTransactionID: UUID?
    public var hotelName: String
    public var hotelGroup: String?
    public var hotelBrand: String?
    public var city: String?
    public var country: String?
    public var checkInDate: String?
    public var checkOutDate: String?
    public var nights: Int?
    public var roomType: String?
    public var confirmationNumber: String?
    public var currency: String
    public var roomCharge: Double
    public var taxAmount: Double
    public var serviceCharge: Double
    public var foodBeverageAmount: Double
    public var otherAmount: Double
    public var totalAmount: Double
    public var paymentMethod: String?
    public var sourceType: HotelFolioSourceType
    public var sourceFileName: String?
    public var sourcePDFData: Data?
    public var localizedData: HotelStayLocalizedData?
    public var confidence: Double
    public var rawText: String
    public var createdAt: Date
    public var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case ledgerID
        case linkedTransactionID
        case hotelName
        case hotelGroup
        case hotelBrand
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
        case sourcePDFData
        case localizedData
        case confidence
        case rawText
        case createdAt
        case updatedAt
    }

    public init(
        id: UUID = UUID(),
        ledgerID: String,
        linkedTransactionID: UUID? = nil,
        hotelName: String,
        hotelGroup: String? = nil,
        hotelBrand: String? = nil,
        city: String? = nil,
        country: String? = nil,
        checkInDate: String? = nil,
        checkOutDate: String? = nil,
        nights: Int? = nil,
        roomType: String? = nil,
        confirmationNumber: String? = nil,
        currency: String,
        roomCharge: Double = 0,
        taxAmount: Double = 0,
        serviceCharge: Double = 0,
        foodBeverageAmount: Double = 0,
        otherAmount: Double = 0,
        totalAmount: Double,
        paymentMethod: String? = nil,
        sourceType: HotelFolioSourceType,
        sourceFileName: String? = nil,
        sourcePDFData: Data? = nil,
        localizedData: HotelStayLocalizedData? = nil,
        confidence: Double = 0,
        rawText: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ledgerID = Self.normalizedLedgerID(ledgerID)
        self.linkedTransactionID = linkedTransactionID
        self.hotelName = hotelName
        self.hotelGroup = hotelGroup
        self.hotelBrand = hotelBrand
        self.city = city
        self.country = country
        self.checkInDate = checkInDate
        self.checkOutDate = checkOutDate
        self.nights = nights
        self.roomType = roomType
        self.confirmationNumber = confirmationNumber
        self.currency = currency
        self.roomCharge = roomCharge
        self.taxAmount = taxAmount
        self.serviceCharge = serviceCharge
        self.foodBeverageAmount = foodBeverageAmount
        self.otherAmount = otherAmount
        self.totalAmount = totalAmount
        self.paymentMethod = paymentMethod
        self.sourceType = sourceType
        self.sourceFileName = sourceFileName
        self.sourcePDFData = sourcePDFData
        self.localizedData = localizedData
        self.confidence = confidence
        self.rawText = rawText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            ledgerID: try container.decodeIfPresent(String.self, forKey: .ledgerID) ?? TodaySpendingSummary.defaultLedgerID,
            linkedTransactionID: try container.decodeIfPresent(UUID.self, forKey: .linkedTransactionID),
            hotelName: try container.decode(String.self, forKey: .hotelName),
            hotelGroup: try container.decodeIfPresent(String.self, forKey: .hotelGroup),
            hotelBrand: try container.decodeIfPresent(String.self, forKey: .hotelBrand),
            city: try container.decodeIfPresent(String.self, forKey: .city),
            country: try container.decodeIfPresent(String.self, forKey: .country),
            checkInDate: try container.decodeIfPresent(String.self, forKey: .checkInDate),
            checkOutDate: try container.decodeIfPresent(String.self, forKey: .checkOutDate),
            nights: try container.decodeIfPresent(Int.self, forKey: .nights),
            roomType: try container.decodeIfPresent(String.self, forKey: .roomType),
            confirmationNumber: try container.decodeIfPresent(String.self, forKey: .confirmationNumber),
            currency: try container.decode(String.self, forKey: .currency),
            roomCharge: try container.decodeIfPresent(Double.self, forKey: .roomCharge) ?? 0,
            taxAmount: try container.decodeIfPresent(Double.self, forKey: .taxAmount) ?? 0,
            serviceCharge: try container.decodeIfPresent(Double.self, forKey: .serviceCharge) ?? 0,
            foodBeverageAmount: try container.decodeIfPresent(Double.self, forKey: .foodBeverageAmount) ?? 0,
            otherAmount: try container.decodeIfPresent(Double.self, forKey: .otherAmount) ?? 0,
            totalAmount: try container.decode(Double.self, forKey: .totalAmount),
            paymentMethod: try container.decodeIfPresent(String.self, forKey: .paymentMethod),
            sourceType: try container.decode(HotelFolioSourceType.self, forKey: .sourceType),
            sourceFileName: try container.decodeIfPresent(String.self, forKey: .sourceFileName),
            sourcePDFData: try container.decodeIfPresent(Data.self, forKey: .sourcePDFData),
            localizedData: try container.decodeIfPresent(HotelStayLocalizedData.self, forKey: .localizedData),
            confidence: try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0,
            rawText: try container.decodeIfPresent(String.self, forKey: .rawText) ?? "",
            createdAt: createdAt,
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        )
    }

    public func resolvedLedgerID(defaultLedgerID: String = TodaySpendingSummary.defaultLedgerID) -> String {
        Self.normalizedLedgerID(ledgerID, defaultLedgerID: defaultLedgerID)
    }

    private static func normalizedLedgerID(
        _ ledgerID: String,
        defaultLedgerID: String = TodaySpendingSummary.defaultLedgerID
    ) -> String {
        let trimmed = ledgerID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultLedgerID : trimmed
    }
}
