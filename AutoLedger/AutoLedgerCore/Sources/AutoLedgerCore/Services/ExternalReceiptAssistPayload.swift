import Foundation

public struct ExternalReceiptAssistPayload: Equatable, Sendable {
    public let source: ReceiptSource
    public let sanitizedText: String
    public let redactionCount: Int

    public init(source: ReceiptSource, sanitizedText: String, redactionCount: Int) {
        self.source = source
        self.sanitizedText = sanitizedText
        self.redactionCount = redactionCount
    }
}

public struct ExternalReceiptAssistSuggestion: Codable, Equatable, Sendable {
    public let merchantCandidates: [String]
    public let categoryHint: String?
    public let explanation: String?
    public let confidence: Double?
    public let subscriptionHint: ExternalReceiptAssistSubscriptionHint?

    public init(
        merchantCandidates: [String],
        categoryHint: String?,
        explanation: String?,
        confidence: Double?,
        subscriptionHint: ExternalReceiptAssistSubscriptionHint? = nil
    ) {
        self.merchantCandidates = merchantCandidates
        self.categoryHint = categoryHint
        self.explanation = explanation
        self.confidence = confidence
        self.subscriptionHint = subscriptionHint
    }

    enum CodingKeys: String, CodingKey {
        case merchantCandidates
        case merchantCandidatesSnake = "merchant_candidates"
        case categoryHint
        case categoryHintSnake = "category_hint"
        case explanation
        case confidence
        case subscriptionHint
        case subscriptionHintSnake = "subscription_hint"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hasSuggestionKey =
            container.contains(.merchantCandidates) ||
            container.contains(.merchantCandidatesSnake) ||
            container.contains(.categoryHint) ||
            container.contains(.categoryHintSnake) ||
            container.contains(.confidence) ||
            container.contains(.subscriptionHint) ||
            container.contains(.subscriptionHintSnake)
        guard hasSuggestionKey else {
            throw DecodingError.keyNotFound(
                CodingKeys.merchantCandidates,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Missing external receipt assist suggestion fields"
                )
            )
        }
        merchantCandidates =
            (try? container.decode([String].self, forKey: .merchantCandidates)) ??
            (try? container.decode([String].self, forKey: .merchantCandidatesSnake)) ??
            []
        categoryHint =
            (try? container.decodeIfPresent(String.self, forKey: .categoryHint)) ??
            (try? container.decodeIfPresent(String.self, forKey: .categoryHintSnake)) ??
            nil
        explanation = try? container.decodeIfPresent(String.self, forKey: .explanation)
        confidence = try? container.decodeIfPresent(Double.self, forKey: .confidence)
        subscriptionHint =
            (try? container.decodeIfPresent(ExternalReceiptAssistSubscriptionHint.self, forKey: .subscriptionHint)) ??
            (try? container.decodeIfPresent(ExternalReceiptAssistSubscriptionHint.self, forKey: .subscriptionHintSnake)) ??
            nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(merchantCandidates, forKey: .merchantCandidates)
        try container.encodeIfPresent(categoryHint, forKey: .categoryHint)
        try container.encodeIfPresent(explanation, forKey: .explanation)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(subscriptionHint, forKey: .subscriptionHint)
    }
}

public struct ExternalReceiptAssistSubscriptionHint: Codable, Equatable, Sendable {
    public let isSubscription: Bool
    public let serviceName: String?
    public let billingCycle: String?
    public let confidence: Double?

    public init(
        isSubscription: Bool,
        serviceName: String?,
        billingCycle: String?,
        confidence: Double?
    ) {
        self.isSubscription = isSubscription
        self.serviceName = serviceName
        self.billingCycle = billingCycle
        self.confidence = confidence
    }

    enum CodingKeys: String, CodingKey {
        case isSubscription
        case isSubscriptionSnake = "is_subscription"
        case serviceName
        case serviceNameSnake = "service_name"
        case billingCycle
        case billingCycleSnake = "billing_cycle"
        case confidence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isSubscription =
            (try? container.decode(Bool.self, forKey: .isSubscription)) ??
            (try? container.decode(Bool.self, forKey: .isSubscriptionSnake)) ??
            false
        serviceName =
            (try? container.decodeIfPresent(String.self, forKey: .serviceName)) ??
            (try? container.decodeIfPresent(String.self, forKey: .serviceNameSnake)) ??
            nil
        billingCycle =
            (try? container.decodeIfPresent(String.self, forKey: .billingCycle)) ??
            (try? container.decodeIfPresent(String.self, forKey: .billingCycleSnake)) ??
            nil
        confidence = try? container.decodeIfPresent(Double.self, forKey: .confidence)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isSubscription, forKey: .isSubscription)
        try container.encodeIfPresent(serviceName, forKey: .serviceName)
        try container.encodeIfPresent(billingCycle, forKey: .billingCycle)
        try container.encodeIfPresent(confidence, forKey: .confidence)
    }
}

public enum ExternalReceiptAssistProvider: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case deepSeek = "deepseek"
    case qwen
    case openAI = "openai"
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .deepSeek:
            return "DeepSeek"
        case .qwen:
            return "Qwen"
        case .openAI:
            return "OpenAI"
        case .custom:
            return "Custom"
        }
    }

    public var defaultEndpointURLString: String? {
        switch self {
        case .deepSeek:
            return "https://api.deepseek.com/chat/completions"
        case .qwen:
            return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .custom:
            return nil
        }
    }

    public var defaultModel: String {
        switch self {
        case .deepSeek:
            return "deepseek-v4-flash"
        case .qwen:
            return "qwen-plus"
        case .openAI:
            return "gpt-4.1-mini"
        case .custom:
            return ""
        }
    }
}

public enum ExternalReceiptAssistOpenAICompatibleCodecError: Error, Equatable, Sendable {
    case missingChoiceContent
    case invalidSuggestionJSON
}

public struct ExternalReceiptAssistOpenAICompatibleCodec: Sendable {
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

    private struct SnakeCaseSuggestion: Decodable {
        let merchantCandidates: [String]
        let categoryHint: String?
        let explanation: String?
        let confidence: Double?
        let subscriptionHint: ExternalReceiptAssistSubscriptionHint?

        enum CodingKeys: String, CodingKey {
            case merchantCandidates = "merchant_candidates"
            case categoryHint = "category_hint"
            case explanation
            case confidence
            case subscriptionHint = "subscription_hint"
        }
    }

    public init() {}

    public func makeRequestData(
        payload: ExternalReceiptAssistPayload,
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

    public func decodeSuggestion(from data: Data) throws -> ExternalReceiptAssistSuggestion {
        if let direct = try? JSONDecoder().decode(ExternalReceiptAssistSuggestion.self, from: data) {
            return direct
        }

        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = response.choices.first?.message.content,
              let contentData = normalizedJSONContent(content).data(using: .utf8) else {
            throw ExternalReceiptAssistOpenAICompatibleCodecError.missingChoiceContent
        }

        if let direct = try? JSONDecoder().decode(ExternalReceiptAssistSuggestion.self, from: contentData) {
            return direct
        }

        if let snake = try? JSONDecoder().decode(SnakeCaseSuggestion.self, from: contentData) {
            return ExternalReceiptAssistSuggestion(
                merchantCandidates: snake.merchantCandidates,
                categoryHint: snake.categoryHint,
                explanation: snake.explanation,
                confidence: snake.confidence,
                subscriptionHint: snake.subscriptionHint
            )
        }

        throw ExternalReceiptAssistOpenAICompatibleCodecError.invalidSuggestionJSON
    }

    private var systemPrompt: String {
        """
        You are AutoLedger's redacted receipt merchant assistant. Return JSON only.
        Find likely real merchant names from minimized redacted payment OCR text.
        Do not infer or return transaction amount, account, card, order id, address, or personal data.
        Output keys: merchantCandidates, categoryHint, confidence, subscriptionHint.
        merchantCandidates must be ordered by likelihood and should prefer store or brand names over rewards, coupons, banks, payment methods, addresses, routes, or UI labels.
        categoryHint may be dining, transport, groceries, digital, shopping, other, or null.
        confidence must be a number from 0 to 1.
        subscriptionHint must be an object: {"isSubscription": boolean, "serviceName": string|null, "billingCycle": "weekly"|"monthly"|"yearly"|null, "confidence": number|null}.
        Mark subscriptionHint.isSubscription true only for recurring memberships, digital subscriptions, renewal receipts, or repeated billing. When recurring evidence is absent, return isSubscription false. Do not treat ordinary one-time dining, shopping, transit, or grocery payments as subscriptions.
        """
    }

    private func userPrompt(for payload: ExternalReceiptAssistPayload) -> String {
        """
        Source: \(payload.source.rawValue)
        Redaction count: \(payload.redactionCount)
        Sanitized payment text:
        \(payload.sanitizedText)
        """
    }

    private func normalizedJSONContent(_ content: String) -> String {
        content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct ExternalReceiptAssistSuggestionMapper: Sendable {
    public init() {}

    public func makeAISuggestion(from suggestion: ExternalReceiptAssistSuggestion) -> ReceiptAISuggestion? {
        guard let merchant = suggestion.merchantCandidates
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            return nil
        }

        let confidence = suggestion.confidence ?? 0.5
        return ReceiptAISuggestion(
            merchant: merchant,
            amount: 0,
            occurredAt: nil,
            confidence: confidence,
            needsUserConfirmation: confidence < 0.7,
            suggestedCategory: mapCategoryHint(suggestion.categoryHint)
        )
    }

    private func mapCategoryHint(_ hint: String?) -> TransactionCategory? {
        guard let hint = hint?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hint.isEmpty else {
            return nil
        }

        if let category = TransactionCategory(rawValue: hint) {
            return category
        }

        switch hint.lowercased() {
        case "餐饮", "餐飲", "food", "meal", "restaurant":
            return .dining
        case "交通", "transportation", "ride", "taxi", "transit":
            return .transport
        case "购物", "購物", "shopping", "groceries", "supermarket":
            return .groceries
        case "数字服务", "數字服務", "digital", "subscription":
            return .digital
        default:
            return nil
        }
    }
}

public struct ExternalReceiptAssistPayloadBuilder: Sendable {
    public init() {}

    public func build(
        rawText: String,
        source: ReceiptSource,
        maxCharacters: Int = 800
    ) -> ExternalReceiptAssistPayload {
        let lines = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        var redactionCount = 0
        var sanitizedLines: [String] = []

        for line in lines where !line.isEmpty {
            if isAddressLike(line) {
                sanitizedLines.append("地址 [REDACTED_ADDRESS]")
                redactionCount += 1
                continue
            }

            if let replacedIDLine = redactIdentifierLabelLine(line) {
                sanitizedLines.append(replacedIDLine.text)
                redactionCount += replacedIDLine.count
                continue
            }

            var sanitized = line
            let cardTail = replace(pattern: #"(尾号\s*)[0-9]{3,6}"#, in: sanitized, template: "$1****")
            sanitized = cardTail.text
            redactionCount += cardTail.count

            let phone = replace(pattern: #"1[3-9][0-9]{9}"#, in: sanitized, template: "[REDACTED_PHONE]")
            sanitized = phone.text
            redactionCount += phone.count

            let sampleFileID = replace(pattern: #"X[0-9]{8,}"#, in: sanitized, template: "[REDACTED_ID]")
            sanitized = sampleFileID.text
            redactionCount += sampleFileID.count

            let longNumber = replace(pattern: #"[0-9]{8,}"#, in: sanitized, template: "[REDACTED_NUMBER]")
            sanitized = longNumber.text
            redactionCount += longNumber.count

            sanitizedLines.append(sanitized)
        }

        let joined = sanitizedLines.joined(separator: "\n")
        let capped = String(joined.prefix(max(0, maxCharacters)))
        return ExternalReceiptAssistPayload(
            source: source,
            sanitizedText: capped,
            redactionCount: redactionCount
        )
    }

    private func redactIdentifierLabelLine(_ line: String) -> (text: String, count: Int)? {
        let labels = [
            "订单号", "商户单号", "交易单号", "交易参考号", "参考号", "流水号",
            "order id", "merchant order", "transaction id", "reference",
            "样本文件"
        ]
        let lowercased = line.lowercased()
        guard let label = labels.first(where: { lowercased.contains($0.lowercased()) }),
              let range = lowercased.range(of: label.lowercased()) else {
            return nil
        }

        let prefix = String(line[..<range.upperBound])
        return ("\(prefix) [REDACTED_ID]", 1)
    }

    private func isAddressLike(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        if lowercased.contains("address") || line.contains("地址") {
            return true
        }

        let hasRegion = line.contains("省") || line.contains("市") || line.contains("区") || line.contains("县")
        let hasRoad = line.contains("路") || line.contains("街") || line.contains("号") || lowercased.contains("road")
        return hasRegion && hasRoad
    }

    private func replace(pattern: String, in text: String, template: String) -> (text: String, count: Int) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (text, 0)
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.numberOfMatches(in: text, range: range)
        guard matches > 0 else {
            return (text, 0)
        }
        let replaced = regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: template
        )
        return (replaced, matches)
    }
}

public struct ExternalReceiptAssistConfiguration: Equatable, Sendable {
    public let isEnabled: Bool
    public let endpointURLString: String?
    public let hasAPIKey: Bool
    public let provider: ExternalReceiptAssistProvider
    public let modelName: String?

    public init(
        isEnabled: Bool,
        endpointURLString: String?,
        hasAPIKey: Bool,
        provider: ExternalReceiptAssistProvider = .custom,
        modelName: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.endpointURLString = endpointURLString
        self.hasAPIKey = hasAPIKey
        self.provider = provider
        self.modelName = modelName
    }
}

public enum ExternalReceiptAssistBlockReason: Equatable, Sendable {
    case disabled
    case missingEndpoint
    case invalidEndpoint
    case missingAPIKey
    case emptyPayload
}

public struct ExternalReceiptAssistGateDecision: Equatable, Sendable {
    public let canRequest: Bool
    public let endpointURL: URL?
    public let reason: ExternalReceiptAssistBlockReason?

    public init(canRequest: Bool, endpointURL: URL?, reason: ExternalReceiptAssistBlockReason?) {
        self.canRequest = canRequest
        self.endpointURL = endpointURL
        self.reason = reason
    }
}

public struct ExternalReceiptAssistGate: Sendable {
    public init() {}

    public func evaluate(
        configuration: ExternalReceiptAssistConfiguration,
        payload: ExternalReceiptAssistPayload
    ) -> ExternalReceiptAssistGateDecision {
        guard configuration.isEnabled else {
            return ExternalReceiptAssistGateDecision(canRequest: false, endpointURL: nil, reason: .disabled)
        }

        guard !payload.sanitizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ExternalReceiptAssistGateDecision(canRequest: false, endpointURL: nil, reason: .emptyPayload)
        }

        guard let endpointURLString = configuration.endpointURLString,
              !endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ExternalReceiptAssistGateDecision(canRequest: false, endpointURL: nil, reason: .missingEndpoint)
        }

        guard let endpointURL = URL(string: endpointURLString),
              let scheme = endpointURL.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              endpointURL.host?.isEmpty == false else {
            return ExternalReceiptAssistGateDecision(canRequest: false, endpointURL: nil, reason: .invalidEndpoint)
        }

        guard configuration.hasAPIKey else {
            return ExternalReceiptAssistGateDecision(canRequest: false, endpointURL: endpointURL, reason: .missingAPIKey)
        }

        return ExternalReceiptAssistGateDecision(canRequest: true, endpointURL: endpointURL, reason: nil)
    }
}
