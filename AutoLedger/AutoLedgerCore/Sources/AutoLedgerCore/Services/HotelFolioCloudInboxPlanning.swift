import Foundation

public struct HotelCloudFolioInboxAddress: Codable, Equatable, Sendable {
    public var token: String
    public var domain: String
    public var localPartPrefix: String

    public init(
        token: String,
        domain: String = "getautoledger.app",
        localPartPrefix: String = "folio"
    ) {
        self.token = token
        self.domain = domain
        self.localPartPrefix = localPartPrefix
    }

    public var normalizedToken: String {
        token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { character in
                character.isLetter || character.isNumber || character == "-" || character == "_"
            }
    }

    public var tokenHash: String? {
        HotelFolioEmailFingerprint.tokenHash(normalizedToken)
    }

    public var emailAddress: String {
        let prefix = localPartPrefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let host = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedToken.isEmpty else {
            return "\(prefix)@\(host)"
        }
        return "\(prefix)+\(normalizedToken)@\(host)"
    }

    public var objectStoragePrefix: String {
        "hotel-folio-candidates/\(tokenHash ?? "unconfigured")"
    }
}

public enum CloudHotelFolioCandidateStatus: String, Codable, CaseIterable, Equatable, Sendable {
    case received
    case stored
    case notified
    case downloaded
    case converted
    case expired
    case deleted
    case failed
}

public extension CloudHotelFolioCandidateStatus {
    var isVisibleInInboxImportList: Bool {
        self == .stored || self == .notified
    }
}

public struct CloudHotelFolioCandidate: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sourceType: HotelFolioSourceType
    public var tokenHash: String
    public var sourceEmailSubject: String?
    public var sourceEmailFrom: String?
    public var messageIDHash: String?
    public var attachmentFileName: String
    public var attachmentHash: String
    public var objectStorageKey: String
    public var objectByteSize: Int
    public var mimeType: String
    public var status: CloudHotelFolioCandidateStatus
    public var receivedAt: Date
    public var expiresAt: Date
    public var downloadedAt: Date?
    public var convertedAt: Date?
    public var deletedAt: Date?
    public var failureReason: String?

    public init(
        id: UUID = UUID(),
        sourceType: HotelFolioSourceType = .cloudWorker,
        tokenHash: String,
        sourceEmailSubject: String?,
        sourceEmailFrom: String?,
        messageIDHash: String?,
        attachmentFileName: String,
        attachmentHash: String,
        objectStorageKey: String,
        objectByteSize: Int,
        mimeType: String,
        status: CloudHotelFolioCandidateStatus,
        receivedAt: Date,
        expiresAt: Date,
        downloadedAt: Date? = nil,
        convertedAt: Date? = nil,
        deletedAt: Date? = nil,
        failureReason: String? = nil
    ) {
        self.id = id
        self.sourceType = sourceType
        self.tokenHash = tokenHash
        self.sourceEmailSubject = sourceEmailSubject
        self.sourceEmailFrom = sourceEmailFrom
        self.messageIDHash = messageIDHash
        self.attachmentFileName = attachmentFileName
        self.attachmentHash = attachmentHash
        self.objectStorageKey = objectStorageKey
        self.objectByteSize = objectByteSize
        self.mimeType = mimeType
        self.status = status
        self.receivedAt = receivedAt
        self.expiresAt = expiresAt
        self.downloadedAt = downloadedAt
        self.convertedAt = convertedAt
        self.deletedAt = deletedAt
        self.failureReason = failureReason
    }

    public func markedNotified() -> CloudHotelFolioCandidate {
        var copy = self
        copy.status = .notified
        return copy
    }

    public func markedDownloaded(at date: Date) -> CloudHotelFolioCandidate {
        var copy = self
        copy.status = .downloaded
        copy.downloadedAt = date
        copy.failureReason = nil
        return copy
    }

    public func markedConverted(at date: Date) -> CloudHotelFolioCandidate {
        var copy = self
        copy.status = .converted
        copy.convertedAt = date
        copy.failureReason = nil
        return copy
    }

    public func markedDeleted(at date: Date) -> CloudHotelFolioCandidate {
        var copy = self
        copy.status = .deleted
        copy.deletedAt = date
        return copy
    }

    public func markedFailed(_ reason: String, at date: Date) -> CloudHotelFolioCandidate {
        var copy = self
        copy.status = .failed
        copy.failureReason = reason.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        copy.downloadedAt = copy.downloadedAt ?? date
        return copy
    }

    public var isVisibleInInboxImportList: Bool {
        status.isVisibleInInboxImportList
    }
}

public struct CloudHotelFolioCandidateFactory: Sendable {
    private let now: @Sendable () -> Date
    private let idProvider: @Sendable () -> UUID

    public init(
        now: @escaping @Sendable () -> Date = { Date() },
        idProvider: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.now = now
        self.idProvider = idProvider
    }

    public func makeCandidate(
        inboxAddress: HotelCloudFolioInboxAddress,
        message: HotelFolioEmailMessage,
        attachment: HotelFolioEmailAttachment,
        retentionDays: Int = 7
    ) -> CloudHotelFolioCandidate {
        let receivedAt = now()
        let safeRetentionDays = min(max(retentionDays, 1), 30)
        let tokenHash = inboxAddress.tokenHash ?? "unconfigured"
        let attachmentHash = HotelFolioEmailFingerprint.attachmentHash(attachment.data)
            ?? HotelFolioEmailFingerprint.tokenHash(attachment.id)
            ?? UUID().uuidString.lowercased()
        let objectStorageKey = [
            inboxAddress.objectStoragePrefix,
            "\(attachmentHash)-\(Self.safeObjectFileName(attachment.fileName))"
        ].joined(separator: "/")

        return CloudHotelFolioCandidate(
            id: idProvider(),
            tokenHash: tokenHash,
            sourceEmailSubject: HotelCloudFolioMetadataRedactor.redact(message.subject),
            sourceEmailFrom: HotelCloudFolioMetadataRedactor.redact(message.from),
            messageIDHash: HotelFolioEmailFingerprint.messageIDHash(message.messageID),
            attachmentFileName: attachment.fileName,
            attachmentHash: attachmentHash,
            objectStorageKey: objectStorageKey,
            objectByteSize: attachment.data.count,
            mimeType: attachment.mimeType,
            status: .stored,
            receivedAt: receivedAt,
            expiresAt: receivedAt.addingTimeInterval(TimeInterval(safeRetentionDays * 24 * 60 * 60))
        )
    }

    private static func safeObjectFileName(_ fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "folio.pdf" : trimmed
        let safe = fallback.map { character -> Character in
            if character.isLetter || character.isNumber || character == "." || character == "-" || character == "_" {
                return character
            }
            return "-"
        }
        return String(safe).lowercased()
    }
}

public struct HotelCloudFolioDraftFactory: Sendable {
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    public func makeDraft(
        candidate: CloudHotelFolioCandidate,
        pdfData: Data,
        extractedText: String,
        targetLedgerID: String?
    ) throws -> HotelStayDraft {
        let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw HotelFolioEmailImportPlanningError.emptyExtractedText
        }

        let timestamp = now()
        return HotelStayDraft(
            sourceType: .cloudWorker,
            targetLedgerID: targetLedgerID,
            sourceFileName: candidate.attachmentFileName,
            sourcePDFData: pdfData,
            sourceEmailSubject: candidate.sourceEmailSubject,
            sourceEmailFrom: candidate.sourceEmailFrom,
            sourceEmailUID: candidate.id.uuidString,
            sourceEmailMessageIDHash: candidate.messageIDHash,
            sourceEmailAttachmentHash: candidate.attachmentHash,
            sourceEmailDateText: AppFormatters.exportDateTime(candidate.receivedAt),
            rawText: trimmedText,
            confidence: 0,
            status: .textExtracted,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}

private enum HotelCloudFolioMetadataRedactor {
    static func redact(_ value: String) -> String? {
        var redacted = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !redacted.isEmpty else { return nil }

        redacted = redacted.replacingOccurrences(
            of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            with: "[redacted-email]",
            options: [.regularExpression, .caseInsensitive]
        )
        redacted = redacted.replacingOccurrences(
            of: #"(?<!\d)(?:\+?\d[\d\s-]{6,}\d)(?!\d)"#,
            with: "[redacted-number]",
            options: .regularExpression
        )
        return redacted.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
