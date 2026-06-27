import Foundation

public struct HotelEmailAccountSettings: Codable, Equatable, Sendable {
    public enum Provider: String, Codable, CaseIterable, Identifiable, Sendable {
        case qq
        case custom

        public var id: String { rawValue }
    }

    public var emailAddress: String
    public var provider: Provider
    public var imapHost: String
    public var imapPort: Int
    public var useTLS: Bool
    public var searchDays: Int
    public var maxMessages: Int

    public init(
        emailAddress: String,
        provider: Provider,
        imapHost: String,
        imapPort: Int,
        useTLS: Bool,
        searchDays: Int = 90,
        maxMessages: Int = 20
    ) {
        self.emailAddress = emailAddress
        self.provider = provider
        self.imapHost = imapHost
        self.imapPort = imapPort
        self.useTLS = useTLS
        self.searchDays = searchDays
        self.maxMessages = maxMessages
    }

    public static func qq(emailAddress: String = "") -> HotelEmailAccountSettings {
        HotelEmailAccountSettings(
            emailAddress: emailAddress,
            provider: .qq,
            imapHost: "imap.qq.com",
            imapPort: 993,
            useTLS: true,
            searchDays: 90,
            maxMessages: 20
        )
    }

    public static func custom(emailAddress: String = "") -> HotelEmailAccountSettings {
        HotelEmailAccountSettings(
            emailAddress: emailAddress,
            provider: .custom,
            imapHost: "",
            imapPort: 993,
            useTLS: true,
            searchDays: 90,
            maxMessages: 20
        )
    }

    public var normalized: HotelEmailAccountSettings {
        var copy = self
        copy.emailAddress = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.imapHost = imapHost.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.imapPort = min(max(imapPort, 1), 65_535)
        copy.searchDays = min(max(searchDays, 1), 365)
        copy.maxMessages = min(max(maxMessages, 1), 100)
        return copy
    }
}

public struct HotelFolioEmailAttachment: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var fileName: String
    public var mimeType: String
    public var size: Int
    public var data: Data

    public init(
        id: String,
        fileName: String,
        mimeType: String,
        size: Int,
        data: Data
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.size = size
        self.data = data
    }
}

public struct HotelFolioEmailMessage: Identifiable, Codable, Equatable, Sendable {
    public var id: String { uid }
    public var uid: String
    public var messageID: String?
    public var subject: String
    public var from: String
    public var dateText: String?
    public var attachments: [HotelFolioEmailAttachment]

    public init(
        uid: String,
        messageID: String?,
        subject: String,
        from: String,
        dateText: String?,
        attachments: [HotelFolioEmailAttachment]
    ) {
        self.uid = uid
        self.messageID = messageID
        self.subject = subject
        self.from = from
        self.dateText = dateText
        self.attachments = attachments
    }
}

public enum HotelFolioEmailImportPlanningError: Error, Equatable, Sendable {
    case emptyRawMessage
    case missingMultipartBoundary
    case emptyExtractedText
}

public struct HotelFolioEmailMessageParser: Sendable {
    public init() {}

    public func parse(rawMessage: String, uid: String) throws -> HotelFolioEmailMessage {
        let normalized = normalizeLineEndings(rawMessage)
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HotelFolioEmailImportPlanningError.emptyRawMessage
        }

        let envelope = splitHeaderBody(normalized)
        let headers = parseHeaders(envelope.headers)
        let subject = decodeHeaderValue(headers["subject"] ?? "")
        let from = decodeHeaderValue(headers["from"] ?? "")
        let dateText = decodeHeaderValue(headers["date"] ?? "")
        let messageID = normalizeMessageID(headers["message-id"])
        let attachments = try parseAttachments(
            headers: headers,
            body: envelope.body,
            uid: uid
        )

        return HotelFolioEmailMessage(
            uid: uid,
            messageID: messageID,
            subject: subject,
            from: from,
            dateText: dateText.isEmpty ? nil : dateText,
            attachments: attachments
        )
    }

    private func parseAttachments(
        headers: [String: String],
        body: String,
        uid: String
    ) throws -> [HotelFolioEmailAttachment] {
        let contentType = headers["content-type"] ?? ""
        guard let boundary = parameter(named: "boundary", in: contentType) else {
            return singlePartAttachment(headers: headers, body: body, uid: uid, index: 1).map { [$0] } ?? []
        }

        var attachments: [HotelFolioEmailAttachment] = []
        for part in splitMultipartBody(body, boundary: boundary) {
            let envelope = splitHeaderBody(part)
            let partHeaders = parseHeaders(envelope.headers)
            let partContentType = partHeaders["content-type"] ?? ""
            if let nestedBoundary = parameter(named: "boundary", in: partContentType),
               partContentType.lowercased().contains("multipart/") {
                for nested in splitMultipartBody(envelope.body, boundary: nestedBoundary) {
                    let nestedEnvelope = splitHeaderBody(nested)
                    let nestedHeaders = parseHeaders(nestedEnvelope.headers)
                    if let attachment = singlePartAttachment(
                        headers: nestedHeaders,
                        body: nestedEnvelope.body,
                        uid: uid,
                        index: attachments.count + 1
                    ) {
                        attachments.append(attachment)
                    }
                }
                continue
            }

            if let attachment = singlePartAttachment(
                headers: partHeaders,
                body: envelope.body,
                uid: uid,
                index: attachments.count + 1
            ) {
                attachments.append(attachment)
            }
        }

        return attachments
    }

    private func singlePartAttachment(
        headers: [String: String],
        body: String,
        uid: String,
        index: Int
    ) -> HotelFolioEmailAttachment? {
        let contentType = headers["content-type"] ?? "application/octet-stream"
        let contentDisposition = headers["content-disposition"] ?? ""
        let mimeType = contentType.split(separator: ";", maxSplits: 1).first.map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        } ?? "application/octet-stream"
        let fileName = decodeHeaderValue(
            parameter(named: "filename", in: contentDisposition)
                ?? parameter(named: "name", in: contentType)
                ?? ""
        )
        let normalizedFileName = fileName.isEmpty ? "folio-\(uid)-\(index).pdf" : fileName
        let isAttachment = contentDisposition.lowercased().contains("attachment")
            || contentDisposition.lowercased().contains("inline")
            || !fileName.isEmpty
        let isPDF = mimeType == "application/pdf" || normalizedFileName.lowercased().hasSuffix(".pdf")
        guard isAttachment, isPDF else { return nil }

        let encoding = (headers["content-transfer-encoding"] ?? "").lowercased()
        let data = decodeBody(body, transferEncoding: encoding)
        guard !data.isEmpty else { return nil }

        return HotelFolioEmailAttachment(
            id: "\(uid)-\(index)-\(normalizedFileName)",
            fileName: normalizedFileName,
            mimeType: mimeType,
            size: data.count,
            data: data
        )
    }

    private func decodeBody(_ body: String, transferEncoding: String) -> Data {
        switch transferEncoding {
        case "base64":
            let compacted = body
                .components(separatedBy: .whitespacesAndNewlines)
                .joined()
            return Data(base64Encoded: compacted) ?? Data()
        case "quoted-printable":
            return decodeQuotedPrintable(body)
        default:
            return Data(body.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        }
    }

    private func splitMultipartBody(_ body: String, boundary: String) -> [String] {
        body
            .components(separatedBy: "--\(boundary)")
            .dropFirst()
            .compactMap { part in
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != "--", !trimmed.hasPrefix("--") else { return nil }
                return trimmed
            }
    }

    private func splitHeaderBody(_ text: String) -> (headers: String, body: String) {
        if let range = text.range(of: "\n\n") {
            return (String(text[..<range.lowerBound]), String(text[range.upperBound...]))
        }
        return (text, "")
    }

    private func parseHeaders(_ headerText: String) -> [String: String] {
        var headers: [String: String] = [:]
        var currentKey: String?

        for rawLine in headerText.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix(" ") || line.hasPrefix("\t"), let key = currentKey {
                headers[key, default: ""] += " " + line.trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator]).lowercased()
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
            currentKey = key
        }

        return headers
    }

    private func parameter(named name: String, in headerValue: String) -> String? {
        let pattern = "(?:^|;)\\s*\(NSRegularExpression.escapedPattern(for: name))\\*?=([^;]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(headerValue.startIndex..<headerValue.endIndex, in: headerValue)
        guard let match = regex.firstMatch(in: headerValue, range: range),
              let valueRange = Range(match.range(at: 1), in: headerValue) else {
            return nil
        }
        return String(headerValue[valueRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private func decodeHeaderValue(_ value: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"=\?([^?]+)\?([bBqQ])\?([^?]*)\?="#,
            options: []
        ) else {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let nsValue = value as NSString
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: nsValue.length))
        guard !matches.isEmpty else {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var decoded = value
        for match in matches.reversed() {
            let charset = nsValue.substring(with: match.range(at: 1)).lowercased()
            let transfer = nsValue.substring(with: match.range(at: 2)).lowercased()
            let payload = nsValue.substring(with: match.range(at: 3))
            let data: Data
            if transfer == "b" {
                data = Data(base64Encoded: payload) ?? Data()
            } else {
                data = decodeQuotedPrintable(payload.replacingOccurrences(of: "_", with: " "))
            }
            let encoding: String.Encoding = charset.contains("iso-8859-1") ? .isoLatin1 : .utf8
            let replacement = String(data: data, encoding: encoding) ?? payload
            if let range = Range(match.range, in: decoded) {
                decoded.replaceSubrange(range, with: replacement)
            }
        }

        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeQuotedPrintable(_ text: String) -> Data {
        var bytes: [UInt8] = []
        let scalars = Array(text.unicodeScalars)
        var index = 0

        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "=" {
                let nextIndex = index + 1
                let secondIndex = index + 2
                if nextIndex < scalars.count, scalars[nextIndex] == "\n" {
                    index += 2
                    continue
                }
                if secondIndex < scalars.count,
                   let byte = UInt8(String(scalars[nextIndex]) + String(scalars[secondIndex]), radix: 16) {
                    bytes.append(byte)
                    index += 3
                    continue
                }
            }
            bytes.append(contentsOf: String(scalar).utf8)
            index += 1
        }

        return Data(bytes)
    }

    private func normalizeMessageID(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            .nilIfEmpty
    }

    private func normalizeLineEndings(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

public struct HotelFolioEmailCandidateFilter: Sendable {
    private let keywords: [String]

    public init(keywords: [String]? = nil) {
        self.keywords = keywords ?? [
            "hotel", "folio", "invoice", "receipt", "stay", "booking", "accommodation",
            "酒店", "水单", "水單", "住宿", "账单", "帳單",
            "ホテル", "宿泊", "領収書", "請求書"
        ]
    }

    public func isLikelyHotelFolio(_ message: HotelFolioEmailMessage) -> Bool {
        guard message.attachments.contains(where: { $0.mimeType == "application/pdf" || $0.fileName.lowercased().hasSuffix(".pdf") }) else {
            return false
        }

        let searchable = ([message.subject, message.from] + message.attachments.map(\.fileName))
            .joined(separator: " ")
            .lowercased()
        return keywords.contains { searchable.contains($0.lowercased()) }
    }
}

public enum HotelFolioEmailDemoFixture: Sendable {
    public static let uid = "demo-hotel-folio-001"
    public static let messageID = "autoledger-demo-hotel-folio@example.test"
    public static let subject = "AutoLedger Demo Hotel Folio"
    public static let sender = "Demo Bay Hotel <folio@example.test>"
    public static let dateText = "Sat, 27 Jun 2026 10:30:00 +0800"
    public static let attachmentFileName = "autoledger-demo-hotel-folio.pdf"

    public static let extractedText = """
    Demo Bay Hotel
    1 Demo Harbor Road, Demo City, JP
    Guest: Demo Traveler
    Guest Email: demo@example.test
    Confirmation No: DEMO-2026-0618
    Check In: 2026-06-18
    Check Out: 2026-06-20
    Nights: 2
    Room Type: Demo King Room
    Room Charge: JPY 42000
    Tax: JPY 4000
    Service Charge: JPY 2000
    Food & Beverage: JPY 1500
    Other Charges: JPY 500
    Total Amount: JPY 50000
    Payment Method: Demo Card **** 4242
    """

    public static func message(pdfData: Data) -> HotelFolioEmailMessage {
        HotelFolioEmailMessage(
            uid: uid,
            messageID: messageID,
            subject: subject,
            from: sender,
            dateText: dateText,
            attachments: [attachment(pdfData: pdfData)]
        )
    }

    public static func attachment(pdfData: Data) -> HotelFolioEmailAttachment {
        HotelFolioEmailAttachment(
            id: "\(uid)-1-\(attachmentFileName)",
            fileName: attachmentFileName,
            mimeType: "application/pdf",
            size: pdfData.count,
            data: pdfData
        )
    }
}

public enum HotelFolioEmailFingerprint: Sendable {
    public static func messageIDHash(_ messageID: String?) -> String? {
        guard let normalized = messageID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            .lowercased()
            .nilIfEmpty else {
            return nil
        }
        return stableHashHex(Data(normalized.utf8))
    }

    public static func attachmentHash(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        return stableHashHex(data)
    }

    private static func stableHashHex(_ data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", CUnsignedLongLong(hash))
    }
}

public struct HotelFolioEmailDraftFactory: Sendable {
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    public func makeDraft(
        message: HotelFolioEmailMessage,
        attachment: HotelFolioEmailAttachment,
        extractedText: String,
        targetLedgerID: String?
    ) throws -> HotelStayDraft {
        let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw HotelFolioEmailImportPlanningError.emptyExtractedText
        }

        let timestamp = now()
        return HotelStayDraft(
            sourceType: .localEmailIMAP,
            targetLedgerID: targetLedgerID,
            sourceFileName: attachment.fileName,
            sourcePDFData: attachment.data,
            sourceEmailSubject: message.subject.nilIfEmpty,
            sourceEmailFrom: message.from.nilIfEmpty,
            sourceEmailUID: message.uid.nilIfEmpty,
            sourceEmailMessageIDHash: HotelFolioEmailFingerprint.messageIDHash(message.messageID),
            sourceEmailAttachmentHash: HotelFolioEmailFingerprint.attachmentHash(attachment.data),
            sourceEmailDateText: message.dateText?.nilIfEmpty,
            rawText: trimmedText,
            confidence: 0,
            status: .textExtracted,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
