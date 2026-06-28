import Foundation

public struct HotelFolioParsePayload: Equatable, Sendable {
    public let sourceType: HotelFolioSourceType
    public let sanitizedText: String
    public let redactionCount: Int
    public let targetLocaleIdentifier: String

    public init(
        sourceType: HotelFolioSourceType,
        sanitizedText: String,
        redactionCount: Int,
        targetLocaleIdentifier: String = Locale.current.identifier
    ) {
        self.sourceType = sourceType
        self.sanitizedText = sanitizedText
        self.redactionCount = redactionCount
        self.targetLocaleIdentifier = targetLocaleIdentifier
    }
}

public struct HotelFolioParsePayloadBuilder: Sendable {
    public init() {}

    public func build(
        rawText: String,
        sourceType: HotelFolioSourceType,
        maxCharacters: Int = 4_000
    ) -> HotelFolioParsePayload {
        let lines = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        var redactionCount = 0
        var sanitizedLines: [String] = []

        for line in lines where !line.isEmpty {
            if let redacted = redactLabeledSensitiveValue(line) {
                sanitizedLines.append(redacted.text)
                redactionCount += redacted.count
                continue
            }

            var sanitized = line
            let email = replace(pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: sanitized, template: "[REDACTED_EMAIL]", options: [.caseInsensitive])
            sanitized = email.text
            redactionCount += email.count

            let phone = replace(pattern: #"(?<![0-9])(?:\+?86[- ]?)?1[3-9][0-9]{9}(?![0-9])"#, in: sanitized, template: "[REDACTED_PHONE]")
            sanitized = phone.text
            redactionCount += phone.count

            let card = replace(pattern: #"(?<![0-9])(?:[0-9][ -]?){13,19}(?![0-9])"#, in: sanitized, template: "[REDACTED_CARD]")
            sanitized = card.text
            redactionCount += card.count

            sanitizedLines.append(sanitized)
        }

        let joined = sanitizedLines.joined(separator: "\n")
        let capped = String(joined.prefix(max(0, maxCharacters)))
        return HotelFolioParsePayload(
            sourceType: sourceType,
            sanitizedText: capped,
            redactionCount: redactionCount,
            targetLocaleIdentifier: Locale.current.identifier
        )
    }

    private func redactLabeledSensitiveValue(_ line: String) -> (text: String, count: Int)? {
        let labels = [
            "member no", "membership no", "member number", "membership number", "loyalty no", "loyalty number",
            "passport", "passport no", "passport number", "id no", "id number", "guest id",
            "card number", "credit card", "身份证", "身分證", "护照", "護照", "会员号", "會員號",
            "会员编号", "會員編號", "银行卡", "銀行卡", "信用卡"
        ]
        let lowercased = line.lowercased()
        guard let label = labels.first(where: { lowercased.contains($0.lowercased()) }),
              let range = lowercased.range(of: label.lowercased()) else {
            return nil
        }

        let prefix = String(line[..<range.upperBound])
        let token = label.lowercased().contains("card") || label.contains("卡")
            ? "[REDACTED_CARD]"
            : "[REDACTED_ID]"
        return ("\(prefix): \(token)", 1)
    }

    private func replace(
        pattern: String,
        in text: String,
        template: String,
        options: NSRegularExpression.Options = []
    ) -> (text: String, count: Int) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return (text, 0)
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.numberOfMatches(in: text, range: range)
        guard matches > 0 else {
            return (text, 0)
        }
        let result = regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
        return (result, matches)
    }
}

public enum HotelFolioOpenAICompatibleCodecError: Error, Equatable, Sendable {
    case missingChoiceContent
    case invalidParsedPayloadJSON
}

public struct HotelFolioOpenAICompatibleCodec: Sendable {
    private struct ChatMessage: Codable, Equatable, Sendable {
        let role: String
        let content: String
    }

    private struct ResponseFormat: Codable, Equatable, Sendable {
        let type: String
    }

    private struct ChatCompletionRequest: Codable, Equatable, Sendable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        let responseFormat: ResponseFormat

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case responseFormat = "response_format"
        }
    }

    private struct ChatCompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }

            let message: Message
        }

        let choices: [Choice]
    }

    public init() {}

    public func makeRequestData(
        payload: HotelFolioParsePayload,
        model: String
    ) throws -> Data {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = ChatCompletionRequest(
            model: trimmedModel.isEmpty ? ExternalReceiptAssistProvider.deepSeek.defaultModel : trimmedModel,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userPrompt(for: payload))
            ],
            temperature: 0.1,
            responseFormat: ResponseFormat(type: "json_object")
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(request)
    }

    public func decodeParsedPayload(from data: Data) throws -> HotelFolioParsedPayload {
        if let direct = try? JSONDecoder().decode(HotelFolioParsedPayload.self, from: data),
           direct.hasRecognizedHotelFolioField {
            return direct
        }

        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = response.choices.first?.message.content,
              let contentData = normalizedJSONContent(content).data(using: .utf8),
              let payload = try? JSONDecoder().decode(HotelFolioParsedPayload.self, from: contentData),
              payload.hasRecognizedHotelFolioField else {
            throw HotelFolioOpenAICompatibleCodecError.missingChoiceContent
        }
        return payload
    }

    private var systemPrompt: String {
        """
        You are AutoLedger's hotel folio parser. Return JSON only.
        Extract one hotel stay from sanitized hotel folio text.
        Output exactly these top-level schema keys when known: hotel_name, brand, group, city, country, check_in_date, check_out_date, nights, room_type, confirmation_number, currency, room_charge, tax, service_charge, food_beverage, other_charges, total_amount, payment_method, confidence, raw_text_excerpt, localized.
        Keep top-level fields as the original recognized folio values. Do not translate or convert top-level values.
        The optional localized object is for display only. When reliable, put localized display values in localized using keys: hotel_name, brand, group, city, country, room_type, currency, room_charge, tax, service_charge, food_beverage, other_charges, total_amount, exchange_rate, exchange_rate_date, exchange_rate_provider, target_locale.
        Only fill localized amount fields when the folio itself provides a reliable converted amount or exchange rate. Otherwise use null for localized amount fields.
        Use ISO 8601 date strings for check_in_date and check_out_date when possible.
        Amount fields must be numbers, nights must be an integer, confidence must be a number from 0 to 1.
        Do not return email addresses, phone numbers, membership numbers, passport or ID numbers, card numbers, postal addresses, or unrelated personal data.
        Use null for unknown fields instead of inventing values.
        """
    }

    private func userPrompt(for payload: HotelFolioParsePayload) -> String {
        """
        Source: \(payload.sourceType.rawValue)
        Redaction count: \(payload.redactionCount)
        Target display locale: \(payload.targetLocaleIdentifier)
        Sanitized hotel folio text:
        \(payload.sanitizedText)
        """
    }

    private func normalizedJSONContent(_ content: String) -> String {
        let trimmed = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(#"\""#) {
            return trimmed.replacingOccurrences(of: #"\""#, with: #"""#)
        }
        return trimmed
    }
}

public enum HotelFolioParsePipelineError: Error, Equatable, Sendable {
    case emptyRawText
    case missingStructuredFields
}

public struct HotelFolioParsePipeline: Sendable {
    private let payloadBuilder: HotelFolioParsePayloadBuilder
    private let now: @Sendable () -> Date

    public init(
        payloadBuilder: HotelFolioParsePayloadBuilder = HotelFolioParsePayloadBuilder(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.payloadBuilder = payloadBuilder
        self.now = now
    }

    public func makePayload(from draft: HotelStayDraft) throws -> HotelFolioParsePayload {
        let rawText = draft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else {
            throw HotelFolioParsePipelineError.emptyRawText
        }
        return payloadBuilder.build(rawText: rawText, sourceType: draft.sourceType)
    }

    public func parse(
        draft: HotelStayDraft,
        responseData: Data,
        codec: HotelFolioOpenAICompatibleCodec = HotelFolioOpenAICompatibleCodec()
    ) throws -> HotelStayDraft {
        let parsedPayload = try codec.decodeParsedPayload(from: responseData)
        return try apply(parsedPayload, to: draft)
    }

    public func apply(_ parsedPayload: HotelFolioParsedPayload, to draft: HotelStayDraft) throws -> HotelStayDraft {
        guard !draft.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HotelFolioParsePipelineError.emptyRawText
        }
        guard parsedPayload.hasRecognizedHotelFolioField else {
            throw HotelFolioParsePipelineError.missingStructuredFields
        }

        var updated = draft
        updated.parsedPayload = parsedPayload
        updated.localizedData = parsedPayload.localizedData ?? draft.localizedData
        updated.confidence = normalizedConfidence(parsedPayload.confidence)
        updated.status = .needsReview
        updated.updatedAt = now()
        return updated
    }

    private func normalizedConfidence(_ confidence: Double?) -> Double {
        guard let confidence else { return 0 }
        if confidence > 1, confidence <= 100 {
            return min(max(confidence / 100, 0), 1)
        }
        return min(max(confidence, 0), 1)
    }
}

private extension HotelFolioParsedPayload {
    var hasRecognizedHotelFolioField: Bool {
        [
            hotelName,
            brand,
            group,
            city,
            country,
            checkInDate,
            checkOutDate,
            roomType,
            confirmationNumber,
            currency,
            paymentMethod,
            rawTextExcerpt
        ]
        .contains { text in
            text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        } ||
        nights != nil ||
        roomCharge != nil ||
        tax != nil ||
        serviceCharge != nil ||
        foodBeverage != nil ||
        otherCharges != nil ||
        totalAmount != nil
    }
}
