import Foundation

public enum BatchImportSourceKind: String, Codable, CaseIterable, Sendable {
    case photos
    case files
    case clipboard
    case share
    case shortcut
    case camera
    case text
}

public enum BatchImportBatchStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

public enum BatchImportItemState: String, Codable, CaseIterable, Sendable {
    case rawInput
    case candidate
    case reviewed
    case transaction
    case rejected
}

public enum BatchImportFailureReason: String, Codable, CaseIterable, Sendable {
    case emptyInput
    case ocrFailed
    case nonBillImage
    case missingAmount
    case missingMerchant
    case missingDate
    case lowConfidence
    case multipleReceipts
    case duplicateSuspected
    case unsupportedFileType
    case parseFailed
    case userRejected
    case permissionDenied
}

public enum BatchImportWarning: String, Codable, CaseIterable, Sendable {
    case nonBillImage
    case emptyOCRText
    case missingAmount
    case missingMerchant
    case missingDate
    case lowConfidence
    case multipleReceipts
    case duplicateSuspected
    case unsupportedFileType
    case parseFailed

    public init(_ warning: InterpretWarning) {
        switch warning {
        case .nonBillImage:
            self = .nonBillImage
        case .emptyOCRText:
            self = .emptyOCRText
        case .missingAmount:
            self = .missingAmount
        case .merchantMissing:
            self = .missingMerchant
        case .missingReliableTotal, .multipleAmountsNeedsReview:
            self = .multipleReceipts
        }
    }
}

public struct BatchImportBatch: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sourceKind: BatchImportSourceKind
    public var status: BatchImportBatchStatus
    public var itemCount: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        sourceKind: BatchImportSourceKind,
        status: BatchImportBatchStatus = .pending,
        itemCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceKind = sourceKind
        self.status = status
        self.itemCount = itemCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct BatchRawInput: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var batchID: UUID?
    public var sourceKind: BatchImportSourceKind
    public var originalFileName: String?
    public var originalUTType: String?
    public var inputHash: String?
    public var fileRef: String?
    public var thumbnailRef: String?
    public var rawText: String?
    public var rawContentPurgedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        batchID: UUID? = nil,
        sourceKind: BatchImportSourceKind,
        originalFileName: String? = nil,
        originalUTType: String? = nil,
        inputHash: String? = nil,
        fileRef: String? = nil,
        thumbnailRef: String? = nil,
        rawText: String? = nil,
        rawContentPurgedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.batchID = batchID
        self.sourceKind = sourceKind
        self.originalFileName = originalFileName
        self.originalUTType = originalUTType
        self.inputHash = inputHash
        self.fileRef = fileRef
        self.thumbnailRef = thumbnailRef
        self.rawText = rawText
        self.rawContentPurgedAt = rawContentPurgedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct BatchImportQueueItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var rawInputID: UUID
    public var batchID: UUID?
    public var state: BatchImportItemState
    public var merchant: String?
    public var amount: Double?
    public var occurredAt: Date?
    public var category: String?
    public var source: String?
    public var note: String
    public var ledgerID: String?
    public var currencyCode: String?
    public var confidence: Double
    public var needsReview: Bool
    public var warnings: [BatchImportWarning]
    public var failureReason: BatchImportFailureReason?
    public var retryCount: Int
    public var duplicateGroupID: String?
    public var duplicateScore: Double?
    public var duplicateReason: String?
    public var possibleDuplicateTransactionID: UUID?
    public var reviewedAt: Date?
    public var convertedTransactionID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        rawInputID: UUID,
        batchID: UUID? = nil,
        state: BatchImportItemState = .rawInput,
        merchant: String? = nil,
        amount: Double? = nil,
        occurredAt: Date? = nil,
        category: String? = nil,
        source: String? = nil,
        note: String = "",
        ledgerID: String? = nil,
        currencyCode: String? = nil,
        confidence: Double = 0,
        needsReview: Bool = true,
        warnings: [BatchImportWarning] = [],
        failureReason: BatchImportFailureReason? = nil,
        retryCount: Int = 0,
        duplicateGroupID: String? = nil,
        duplicateScore: Double? = nil,
        duplicateReason: String? = nil,
        possibleDuplicateTransactionID: UUID? = nil,
        reviewedAt: Date? = nil,
        convertedTransactionID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.rawInputID = rawInputID
        self.batchID = batchID
        self.state = state
        self.merchant = merchant
        self.amount = amount
        self.occurredAt = occurredAt
        self.category = category
        self.source = source
        self.note = note
        self.ledgerID = ledgerID
        self.currencyCode = currencyCode
        self.confidence = confidence
        self.needsReview = needsReview
        self.warnings = warnings
        self.failureReason = failureReason
        self.retryCount = retryCount
        self.duplicateGroupID = duplicateGroupID
        self.duplicateScore = duplicateScore
        self.duplicateReason = duplicateReason
        self.possibleDuplicateTransactionID = possibleDuplicateTransactionID
        self.reviewedAt = reviewedAt
        self.convertedTransactionID = convertedTransactionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var canRetry: Bool {
        switch state {
        case .rawInput, .candidate:
            return failureReason != nil
        case .reviewed, .transaction, .rejected:
            return false
        }
    }

    public var isOfficialTransaction: Bool {
        state == .transaction && convertedTransactionID != nil
    }

    public static func rawInput(
        rawInput: BatchRawInput,
        id: UUID = UUID(),
        createdAt: Date? = nil
    ) -> BatchImportQueueItem {
        let date = createdAt ?? rawInput.createdAt
        return BatchImportQueueItem(
            id: id,
            rawInputID: rawInput.id,
            batchID: rawInput.batchID,
            state: .rawInput,
            createdAt: date,
            updatedAt: date
        )
    }

    public func applyingInterpretation(_ result: InterpretResult, now: Date = Date()) -> BatchImportQueueItem {
        var item = self
        var mappedWarnings = result.warnings.map(BatchImportWarning.init)
        if result.confidence == .low && !mappedWarnings.contains(.lowConfidence) {
            mappedWarnings.append(.lowConfidence)
        }
        item.warnings = mappedWarnings
        item.confidence = result.confidence.batchImportScore
        item.updatedAt = now
        item.failureReason = nil

        if let draft = result.draft {
            item.state = .candidate
            item.merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.merchant
            item.amount = draft.amount > 0 ? draft.amount : nil
            item.occurredAt = draft.occurredAt
            item.category = draft.category
            item.source = draft.sourceType.rawValue
            item.note = ""
            item.needsReview = result.needsReview || !mappedWarnings.isEmpty || item.merchant == nil || item.amount == nil
            if item.merchant == nil {
                item.failureReason = .missingMerchant
            } else if item.amount == nil {
                item.failureReason = .missingAmount
            } else if result.confidence == .low {
                item.failureReason = .lowConfidence
            }
            return item
        }

        item.merchant = nil
        item.amount = nil
        item.occurredAt = nil
        item.category = nil
        item.source = nil
        item.needsReview = true
        item.failureReason = BatchImportFailureReason.inferred(from: mappedWarnings)
        switch item.failureReason {
        case .nonBillImage, .unsupportedFileType, .userRejected:
            item.state = .rejected
        case .missingAmount, .missingMerchant, .missingDate, .lowConfidence, .multipleReceipts, .duplicateSuspected:
            item.state = .candidate
        default:
            item.state = .rawInput
        }
        return item
    }

    public func markedFailed(reason: BatchImportFailureReason, now: Date = Date()) -> BatchImportQueueItem {
        var item = self
        item.failureReason = reason
        item.needsReview = true
        item.updatedAt = now
        switch reason {
        case .nonBillImage, .unsupportedFileType, .userRejected:
            item.state = .rejected
        default:
            item.state = .rawInput
        }
        return item
    }

    public func markedDuplicate(
        groupID: String,
        score: Double,
        reason: String,
        possibleTransactionID: UUID? = nil,
        now: Date = Date()
    ) -> BatchImportQueueItem {
        var item = self
        item.duplicateGroupID = groupID
        item.duplicateScore = min(max(score, 0), 1)
        item.duplicateReason = reason
        item.possibleDuplicateTransactionID = possibleTransactionID
        item.failureReason = .duplicateSuspected
        item.needsReview = true
        if !item.warnings.contains(.duplicateSuspected) {
            item.warnings.append(.duplicateSuspected)
        }
        item.updatedAt = now
        return item
    }

    public func reviewed(now: Date = Date()) -> BatchImportQueueItem {
        var item = self
        guard item.state == .candidate else { return item }
        item.state = .reviewed
        item.needsReview = false
        item.reviewedAt = now
        item.updatedAt = now
        return item
    }

    public func converted(transactionID: UUID, now: Date = Date()) -> BatchImportQueueItem {
        var item = self
        item.state = .transaction
        item.convertedTransactionID = transactionID
        item.needsReview = false
        item.updatedAt = now
        return item
    }

    public func retryRequested(now: Date = Date()) -> BatchImportQueueItem {
        var item = self
        item.state = .rawInput
        item.failureReason = nil
        item.warnings = []
        item.needsReview = true
        item.retryCount += 1
        item.updatedAt = now
        return item
    }
}

public struct BatchImportQueueSnapshot: Codable, Equatable, Sendable {
    public var batches: [BatchImportBatch]
    public var rawInputs: [BatchRawInput]
    public var items: [BatchImportQueueItem]

    public init(
        batches: [BatchImportBatch] = [],
        rawInputs: [BatchRawInput] = [],
        items: [BatchImportQueueItem] = []
    ) {
        self.batches = batches
        self.rawInputs = rawInputs
        self.items = items
    }

    public var officialTransactionIDs: [UUID] {
        items.compactMap(\.convertedTransactionID)
    }

    public func items(in state: BatchImportItemState) -> [BatchImportQueueItem] {
        items.filter { $0.state == state }
    }

    public func doesNotPolluteOfficialLedger() -> Bool {
        items.allSatisfy { item in
            item.state == .transaction || item.convertedTransactionID == nil
        }
    }
}

private extension InterpretConfidence {
    var batchImportScore: Double {
        switch self {
        case .high:
            return 0.9
        case .medium:
            return 0.65
        case .low:
            return 0.35
        }
    }
}

private extension BatchImportFailureReason {
    static func inferred(from warnings: [BatchImportWarning]) -> BatchImportFailureReason {
        if warnings.contains(.nonBillImage) { return .nonBillImage }
        if warnings.contains(.emptyOCRText) { return .emptyInput }
        if warnings.contains(.missingAmount) { return .missingAmount }
        if warnings.contains(.missingMerchant) { return .missingMerchant }
        if warnings.contains(.missingDate) { return .missingDate }
        if warnings.contains(.multipleReceipts) { return .multipleReceipts }
        if warnings.contains(.duplicateSuspected) { return .duplicateSuspected }
        if warnings.contains(.lowConfidence) { return .lowConfidence }
        return .parseFailed
    }
}
