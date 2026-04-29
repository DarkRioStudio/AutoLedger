import Foundation

public enum LedgerInputSourceType: String, Sendable, Codable {
    case ocr
    case voice
    case siri
    case clipboard
    case manual
    case share
    case subscriptionEmail
}

public enum LedgerSourceHint: String, Sendable, Codable {
    case receipt
    case payment
    case sentence
    case subscription
    case unknown
}

public struct LedgerInterpretHints: Sendable, Codable, Equatable {
    public var sourceHint: LedgerSourceHint

    public init(sourceHint: LedgerSourceHint = .unknown) {
        self.sourceHint = sourceHint
    }
}

public struct InterpretInput: Sendable, Codable {
    public var rawText: String
    public var sourceType: LedgerInputSourceType
    public var localeIdentifier: String?
    public var timeZoneIdentifier: String?
    public var hints: LedgerInterpretHints
    public var categoryCorrections: [String: String]

    public init(
        rawText: String,
        sourceType: LedgerInputSourceType,
        localeIdentifier: String? = nil,
        timeZoneIdentifier: String? = nil,
        hints: LedgerInterpretHints = LedgerInterpretHints(),
        categoryCorrections: [String: String] = [:]
    ) {
        self.rawText = rawText
        self.sourceType = sourceType
        self.localeIdentifier = localeIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
        self.hints = hints
        self.categoryCorrections = categoryCorrections
    }
}

public enum ParseMethod: String, Sendable, Codable {
    case rule
    case ai
    case mixed
}

public enum InterpretConfidence: String, Sendable, Codable {
    case high
    case medium
    case low
}

public enum InterpretWarning: String, Sendable, Codable, Equatable {
    case nonBillImage
    case emptyOCRText
    case missingAmount
    case merchantMissing
    case multipleAmountsNeedsReview
    case missingReliableTotal
}

public struct TransactionDraft: Sendable, Codable, Equatable {
    public var amount: Double
    public var merchant: String
    public var category: String
    public var occurredAt: Date
    public var sourceType: LedgerInputSourceType
    public var inputText: String
    public var parseMethod: ParseMethod

    public init(
        amount: Double,
        merchant: String,
        category: String,
        occurredAt: Date,
        sourceType: LedgerInputSourceType,
        inputText: String,
        parseMethod: ParseMethod
    ) {
        self.amount = amount
        self.merchant = merchant
        self.category = category
        self.occurredAt = occurredAt
        self.sourceType = sourceType
        self.inputText = inputText
        self.parseMethod = parseMethod
    }
}

public struct InterpretResult: Sendable, Codable, Equatable {
    public var draft: TransactionDraft?
    public var confidence: InterpretConfidence
    public var needsReview: Bool
    public var warnings: [InterpretWarning]
    public var debugTrace: [String]

    public init(
        draft: TransactionDraft?,
        confidence: InterpretConfidence,
        needsReview: Bool,
        warnings: [InterpretWarning] = [],
        debugTrace: [String] = []
    ) {
        self.draft = draft
        self.confidence = confidence
        self.needsReview = needsReview
        self.warnings = warnings
        self.debugTrace = debugTrace
    }
}
