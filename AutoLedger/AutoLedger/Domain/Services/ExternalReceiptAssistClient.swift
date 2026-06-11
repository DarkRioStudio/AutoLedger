import AutoLedgerCore
import Foundation
import Security

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
        set {
            if let value = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                UserDefaults.standard.set(value, forKey: endpointKey)
            } else {
                UserDefaults.standard.removeObject(forKey: endpointKey)
            }
        }
    }

    static func gateConfiguration(apiKey: String?) -> ExternalReceiptAssistConfiguration {
        ExternalReceiptAssistConfiguration(
            isEnabled: isEnabled,
            endpointURLString: endpointURLString,
            hasAPIKey: apiKey?.isEmpty == false
        )
    }

    static var runtimeAPIKey: String? {
        storedAPIKey ?? ProcessInfo.processInfo.environment[apiKeyEnvironmentKey]
    }

    static var hasStoredAPIKey: Bool {
        storedAPIKey?.isEmpty == false
    }

    static func saveAPIKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try ExternalReceiptAssistAPIKeyStore.save(trimmed)
    }

    static func clearStoredAPIKey() {
        ExternalReceiptAssistAPIKeyStore.delete()
    }

    private static var storedAPIKey: String? {
        try? ExternalReceiptAssistAPIKeyStore.read()
    }
}

private enum ExternalReceiptAssistAPIKeyStore {
    private static let service = "top.darkrio326.AutoLedger.externalReceiptAssist"
    private static let account = "apiKey"

    static func save(_ value: String) throws {
        let data = Data(value.utf8)
        delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ExternalReceiptAssistClientError.keychainStatus(status)
        }
    }

    static func read() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw ExternalReceiptAssistClientError.keychainStatus(status)
        }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum ExternalReceiptAssistClientError: Error, Sendable {
    case requestBlocked(ExternalReceiptAssistBlockReason)
    case missingEndpoint
    case invalidHTTPResponse
    case httpStatus(Int)
    case keychainStatus(OSStatus)
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
