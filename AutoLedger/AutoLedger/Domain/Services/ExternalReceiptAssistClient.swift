import AutoLedgerCore
import Foundation

enum ExternalReceiptAssistSettings {
    static let enabledKey = "externalReceiptAssistEnabled"
    static let endpointKey = "externalReceiptAssistEndpoint"
    static let apiKeyEnvironmentKey = "AUTOLEDGER_EXTERNAL_RECEIPT_ASSIST_API_KEY"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var endpointURLString: String? {
        get { UserDefaults.standard.string(forKey: endpointKey) }
        set { UserDefaults.standard.set(newValue, forKey: endpointKey) }
    }

    static func gateConfiguration(apiKey: String?) -> ExternalReceiptAssistConfiguration {
        ExternalReceiptAssistConfiguration(
            isEnabled: isEnabled,
            endpointURLString: endpointURLString,
            hasAPIKey: apiKey?.isEmpty == false
        )
    }

    static var runtimeAPIKey: String? {
        ProcessInfo.processInfo.environment[apiKeyEnvironmentKey]
    }
}

enum ExternalReceiptAssistClientError: Error, Sendable {
    case requestBlocked(ExternalReceiptAssistBlockReason)
    case missingEndpoint
    case invalidHTTPResponse
    case httpStatus(Int)
}

protocol ExternalReceiptAssistClientProtocol: Sendable {
    func requestSuggestion(
        payload: ExternalReceiptAssistPayload,
        configuration: ExternalReceiptAssistConfiguration,
        apiKey: String
    ) async throws -> ExternalReceiptAssistSuggestion
}

struct ExternalReceiptAssistClient: ExternalReceiptAssistClientProtocol {
    private struct RequestBody: Encodable {
        let source: String
        let sanitizedText: String
    }

    private let gate = ExternalReceiptAssistGate()

    func requestSuggestion(
        payload: ExternalReceiptAssistPayload,
        configuration: ExternalReceiptAssistConfiguration,
        apiKey: String
    ) async throws -> ExternalReceiptAssistSuggestion {
        let decision = gate.evaluate(configuration: configuration, payload: payload)
        guard decision.canRequest else {
            throw ExternalReceiptAssistClientError.requestBlocked(decision.reason ?? .disabled)
        }
        guard let endpointURL = decision.endpointURL else {
            throw ExternalReceiptAssistClientError.missingEndpoint
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                source: payload.source.rawValue,
                sanitizedText: payload.sanitizedText
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExternalReceiptAssistClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ExternalReceiptAssistClientError.httpStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(ExternalReceiptAssistSuggestion.self, from: data)
    }
}
