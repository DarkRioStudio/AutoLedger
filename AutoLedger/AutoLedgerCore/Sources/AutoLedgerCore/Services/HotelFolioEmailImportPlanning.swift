import Foundation

public struct HotelEmailAccountSettings: Codable, Equatable, Sendable {
    public enum Provider: String, Codable, CaseIterable, Identifiable, Sendable {
        case qq
        case netease163
        case netease126
        case gmail
        case outlook
        case icloud
        case yahoo
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
        searchDays: Int = 0,
        maxMessages: Int = 0
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
        preset(provider: .qq, emailAddress: emailAddress)
    }

    public static func netease163(emailAddress: String = "") -> HotelEmailAccountSettings {
        preset(provider: .netease163, emailAddress: emailAddress)
    }

    public static func netease126(emailAddress: String = "") -> HotelEmailAccountSettings {
        preset(provider: .netease126, emailAddress: emailAddress)
    }

    public static func gmail(emailAddress: String = "") -> HotelEmailAccountSettings {
        preset(provider: .gmail, emailAddress: emailAddress)
    }

    public static func outlook(emailAddress: String = "") -> HotelEmailAccountSettings {
        preset(provider: .outlook, emailAddress: emailAddress)
    }

    public static func icloud(emailAddress: String = "") -> HotelEmailAccountSettings {
        preset(provider: .icloud, emailAddress: emailAddress)
    }

    public static func yahoo(emailAddress: String = "") -> HotelEmailAccountSettings {
        preset(provider: .yahoo, emailAddress: emailAddress)
    }

    public static func custom(emailAddress: String = "") -> HotelEmailAccountSettings {
        HotelEmailAccountSettings(
            emailAddress: emailAddress,
            provider: .custom,
            imapHost: "",
            imapPort: 993,
            useTLS: true,
            searchDays: 0,
            maxMessages: 0
        )
    }

    public static func preset(provider: Provider, emailAddress: String = "") -> HotelEmailAccountSettings {
        let host: String
        switch provider {
        case .qq:
            host = "imap.qq.com"
        case .netease163:
            host = "imap.163.com"
        case .netease126:
            host = "imap.126.com"
        case .gmail:
            host = "imap.gmail.com"
        case .outlook:
            host = "outlook.office365.com"
        case .icloud:
            host = "imap.mail.me.com"
        case .yahoo:
            host = "imap.mail.yahoo.com"
        case .custom:
            return custom(emailAddress: emailAddress)
        }

        return HotelEmailAccountSettings(
            emailAddress: emailAddress,
            provider: provider,
            imapHost: host,
            imapPort: 993,
            useTLS: true,
            searchDays: 0,
            maxMessages: 0
        )
    }

    public var normalized: HotelEmailAccountSettings {
        var copy = self
        copy.emailAddress = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.imapHost = imapHost.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.imapPort = min(max(imapPort, 1), 65_535)
        copy.searchDays = min(max(searchDays, 0), 365)
        copy.maxMessages = min(max(maxMessages, 0), 100)
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
    public var bodyText: String?
    public var attachments: [HotelFolioEmailAttachment]

    public init(
        uid: String,
        messageID: String?,
        subject: String,
        from: String,
        dateText: String?,
        bodyText: String? = nil,
        attachments: [HotelFolioEmailAttachment]
    ) {
        self.uid = uid
        self.messageID = messageID
        self.subject = subject
        self.from = from
        self.dateText = dateText
        self.bodyText = bodyText
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
        let bodyText = extractBodyText(headers: headers, body: envelope.body)
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
            bodyText: bodyText,
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
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDisposition = contentDisposition.lowercased()
        let hasFileName = !fileName.isEmpty
        let isAttachmentDisposition = normalizedDisposition.contains("attachment")
        let isNamedInlineDisposition = normalizedDisposition.contains("inline") && hasFileName
        let isPDF = mimeType == "application/pdf" || fileName.lowercased().hasSuffix(".pdf")
        let hasPDFEvidence = mimeType == "application/pdf" || hasFileName
        guard isPDF,
              hasPDFEvidence,
              isAttachmentDisposition || isNamedInlineDisposition || hasFileName || mimeType == "application/pdf" else {
            return nil
        }

        let encoding = (headers["content-transfer-encoding"] ?? "").lowercased()
        let data = decodeBody(body, transferEncoding: encoding)
        guard !data.isEmpty else { return nil }
        let attachmentFileName = hasFileName ? fileName : "attachment-\(uid)-\(index).pdf"

        return HotelFolioEmailAttachment(
            id: "\(uid)-\(index)-\(attachmentFileName)",
            fileName: attachmentFileName,
            mimeType: mimeType,
            size: data.count,
            data: data
        )
    }

    private func extractBodyText(headers: [String: String], body: String) -> String? {
        let contentType = headers["content-type"] ?? "text/plain"
        if let boundary = parameter(named: "boundary", in: contentType),
           contentType.lowercased().contains("multipart/") {
            let parts = splitMultipartBody(body, boundary: boundary)
            let texts = parts.compactMap { part -> String? in
                let envelope = splitHeaderBody(part)
                let partHeaders = parseHeaders(envelope.headers)
                return extractBodyText(headers: partHeaders, body: envelope.body)
            }
            return texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }

        let contentDisposition = (headers["content-disposition"] ?? "").lowercased()
        guard !contentDisposition.contains("attachment") else {
            return nil
        }

        let mimeType = contentType.split(separator: ";", maxSplits: 1).first.map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        } ?? "text/plain"
        guard mimeType == "text/plain" || mimeType == "text/html" else {
            return nil
        }

        let encoding = (headers["content-transfer-encoding"] ?? "").lowercased()
        let data = decodeBody(body, transferEncoding: encoding)
        let charset = parameter(named: "charset", in: contentType)?.lowercased()
        let text = decodeText(data, charset: charset) ?? String(decoding: data, as: UTF8.self)
        let normalized = mimeType == "text/html" ? stripHTML(text) : text
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private func decodeText(_ data: Data, charset: String?) -> String? {
        let normalized = charset?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let encoding: String.Encoding
        switch normalized {
        case "iso-8859-1", "latin1", "latin-1":
            encoding = .isoLatin1
        case "us-ascii", "ascii":
            encoding = .ascii
        default:
            encoding = .utf8
        }
        return String(data: data, encoding: encoding)
    }

    private func stripHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: #"(?i)<\s*br\s*/?\s*>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)</\s*(p|div|tr|li|table|h[1-6])\s*>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
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

public enum HotelFolioEmailCandidateTier: String, Codable, Equatable, Sendable {
    case pdfFolioSignal
    case pdfHotelSignal
    case bodySubjectSignal

    public var defaultSelected: Bool {
        switch self {
        case .pdfFolioSignal, .pdfHotelSignal:
            return true
        case .bodySubjectSignal:
            return false
        }
    }
}

public enum HotelFolioEmailCandidateReason: String, Codable, Equatable, Sendable {
    case pdfFolioSubjectOrAttachment
    case pdfHotelSenderOrBody
    case bodySubjectFolio
}

public struct HotelFolioEmailCandidateMatch: Codable, Equatable, Sendable {
    public var tier: HotelFolioEmailCandidateTier
    public var reason: HotelFolioEmailCandidateReason
    public var score: Int
    public var matchedKeywords: [String]

    public init(
        tier: HotelFolioEmailCandidateTier,
        reason: HotelFolioEmailCandidateReason,
        score: Int,
        matchedKeywords: [String]
    ) {
        self.tier = tier
        self.reason = reason
        self.score = score
        self.matchedKeywords = matchedKeywords
    }

    public var defaultSelected: Bool {
        tier.defaultSelected
    }
}

public struct HotelFolioEmailCandidateFilter: Sendable {
    private let folioKeywords: [String]
    private let hotelKeywords: [String]
    private let weakDocumentKeywords: [String]
    private let negativeKeywords: [String]

    public init() {
        self.folioKeywords = [
            "folio", "hotel folio", "guest folio", "e-folio",
            "水单", "水單", "账单", "帳單", "电子账单", "電子帳單",
            "明细", "明細", "請求書", "領収書", "精算書"
        ]
        self.hotelKeywords = [
            "hotel", "resort", "inn", "suites", "accommodation", "booking",
            "moxy", "marriott", "luxury collection", "crowne plaza", "holiday inn",
            "intercontinental", "ihg", "hyatt", "hilton", "sheraton", "westin",
            "ritz", "courtyard", "fairfield", "aloft", "accor", "novotel",
            "mercure", "ibis", "sofitel", "pullman", "radisson", "wyndham",
            "four seasons", "mandarin oriental", "shangri", "peninsula", "lotus",
            "酒店", "饭店", "飯店", "度假酒店", "度假飯店", "万豪", "萬豪",
            "皇冠假日", "洲际", "洲際", "凯悦", "凱悅", "希尔顿", "希爾頓",
            "喜来登", "喜來登", "威斯汀", "雅乐轩", "雅樂軒",
            "ホテル", "リゾート", "宿泊", "マリオット", "ヒルトン", "ハイアット"
        ]
        self.weakDocumentKeywords = [
            "invoice", "receipt", "statement", "pdf", "attachment", "附件"
        ]
        self.negativeKeywords = [
            "xcode cloud", "testflight", "app store connect", "apple developer",
            "wwdc", "build succeeded", "approved for beta testing", "available to test",
            "boarding pass", "flight", "airline", "itinerary", "航旅纵横", "航旅縱橫",
            "行程乘机凭证", "行程乘機憑證", "乘机凭证", "乘機憑證", "验证码", "驗證碼"
        ]
    }

    public func isLikelyHotelFolio(_ message: HotelFolioEmailMessage) -> Bool {
        evaluate(message) != nil
    }

    public func evaluate(_ message: HotelFolioEmailMessage) -> HotelFolioEmailCandidateMatch? {
        let pdfAttachments = message.attachments.filter(isPDF)
        let hasPDF = !pdfAttachments.isEmpty
        let hasBody = message.bodyText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        guard hasPDF || hasBody else {
            return nil
        }

        let subject = normalized(message.subject)
        let from = normalized(message.from)
        let body = normalized(message.bodyText ?? "")
        let attachmentNames = normalized(pdfAttachments.map(\.fileName).joined(separator: " "))
        let subjectAndAttachmentText = [subject, attachmentNames].joined(separator: " ")
        let broaderText = [subjectAndAttachmentText, from, body].joined(separator: " ")

        let subjectFolioSignal = matchedKeywords(in: subject, from: folioKeywords)
        let subjectHotelSignal = matchedKeywords(in: subject, from: hotelKeywords)
        let subjectOrAttachmentFolio = matchedKeywords(in: subjectAndAttachmentText, from: folioKeywords)
        let subjectOrAttachmentHotel = matchedKeywords(in: subjectAndAttachmentText, from: hotelKeywords)
        let broaderHotel = matchedKeywords(in: broaderText, from: hotelKeywords)
        let broaderFolio = matchedKeywords(in: broaderText, from: folioKeywords)
        let weakDocuments = matchedKeywords(in: broaderText, from: weakDocumentKeywords)
        let negative = matchedKeywords(in: [subject, from].joined(separator: " "), from: negativeKeywords)
        let hasStrongSubjectOrAttachmentSignal = !subjectOrAttachmentFolio.isEmpty || !subjectOrAttachmentHotel.isEmpty
        let hasStrongSubjectSignal = !subjectFolioSignal.isEmpty || !subjectHotelSignal.isEmpty

        guard negative.isEmpty || hasStrongSubjectSignal else {
            return nil
        }

        if hasPDF {
            if hasStrongSubjectOrAttachmentSignal {
                let matches = unique(subjectOrAttachmentFolio + subjectOrAttachmentHotel)
                return HotelFolioEmailCandidateMatch(
                    tier: .pdfFolioSignal,
                    reason: .pdfFolioSubjectOrAttachment,
                    score: 90 + min(matches.count * 2, 8),
                    matchedKeywords: matches
                )
            }

            if !broaderHotel.isEmpty, !broaderFolio.isEmpty || !weakDocuments.isEmpty {
                let matches = unique(broaderHotel + broaderFolio + weakDocuments)
                return HotelFolioEmailCandidateMatch(
                    tier: .pdfHotelSignal,
                    reason: .pdfHotelSenderOrBody,
                    score: 72 + min(matches.count * 2, 8),
                    matchedKeywords: matches
                )
            }

            return nil
        }

        guard hasBody else { return nil }
        guard !subjectFolioSignal.isEmpty || (!subjectHotelSignal.isEmpty && !broaderFolio.isEmpty) else {
            return nil
        }

        let matches = unique(subjectFolioSignal + subjectHotelSignal + broaderFolio)
        return HotelFolioEmailCandidateMatch(
            tier: .bodySubjectSignal,
            reason: .bodySubjectFolio,
            score: 64 + min(matches.count * 2, 8),
            matchedKeywords: matches
        )
    }

    private func isPDF(_ attachment: HotelFolioEmailAttachment) -> Bool {
        attachment.mimeType == "application/pdf" || attachment.fileName.lowercased().hasSuffix(".pdf")
    }

    private func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
    }

    private func matchedKeywords(in text: String, from keywords: [String]) -> [String] {
        guard !text.isEmpty else { return [] }
        return keywords.filter { keyword in
            text.contains(normalized(keyword))
        }
    }

    private func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            let key = normalized(value)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(value)
        }
        return result
    }
}

public enum HotelFolioEmailFingerprint: Sendable {
    public static func tokenHash(_ token: String) -> String? {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nilIfEmpty
        guard let normalized else { return nil }
        return stableHashHex(Data(normalized.utf8))
    }

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
