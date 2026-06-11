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

    public init(
        merchantCandidates: [String],
        categoryHint: String?,
        explanation: String?,
        confidence: Double?
    ) {
        self.merchantCandidates = merchantCandidates
        self.categoryHint = categoryHint
        self.explanation = explanation
        self.confidence = confidence
    }
}

public struct ExternalReceiptAssistPayloadBuilder: Sendable {
    public init() {}

    public func build(
        rawText: String,
        source: ReceiptSource,
        maxCharacters: Int = 1_200
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

    public init(isEnabled: Bool, endpointURLString: String?, hasAPIKey: Bool) {
        self.isEnabled = isEnabled
        self.endpointURLString = endpointURLString
        self.hasAPIKey = hasAPIKey
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
