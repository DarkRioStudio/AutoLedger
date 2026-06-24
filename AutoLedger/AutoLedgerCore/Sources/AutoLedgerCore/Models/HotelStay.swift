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
        rawTextExcerpt: String? = nil
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
    }
}

public struct HotelStayDraft: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sourceType: HotelFolioSourceType
    public var targetLedgerID: String?
    public var sourceFileName: String?
    public var sourceEmailSubject: String?
    public var sourceEmailFrom: String?
    public var rawText: String
    public var parsedPayload: HotelFolioParsedPayload?
    public var confidence: Double
    public var status: HotelStayDraftStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        sourceType: HotelFolioSourceType,
        targetLedgerID: String? = nil,
        sourceFileName: String? = nil,
        sourceEmailSubject: String? = nil,
        sourceEmailFrom: String? = nil,
        rawText: String = "",
        parsedPayload: HotelFolioParsedPayload? = nil,
        confidence: Double = 0,
        status: HotelStayDraftStatus = .imported,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.targetLedgerID = targetLedgerID
        self.sourceFileName = sourceFileName
        self.sourceEmailSubject = sourceEmailSubject
        self.sourceEmailFrom = sourceEmailFrom
        self.rawText = rawText
        self.parsedPayload = parsedPayload
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
    public var confidence: Double
    public var rawText: String
    public var createdAt: Date
    public var updatedAt: Date

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
        confidence: Double = 0,
        rawText: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ledgerID = ledgerID
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
        self.confidence = confidence
        self.rawText = rawText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
