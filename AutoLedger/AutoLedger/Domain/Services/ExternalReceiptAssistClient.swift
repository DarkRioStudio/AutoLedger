import AutoLedgerCore
import CryptoKit
import Foundation
import Security

enum ExternalReceiptAssistSettings {
    static let enabledKey = "externalReceiptAssistEnabled"
    static let providerKey = "externalReceiptAssistProvider"
    static let endpointKey = "externalReceiptAssistEndpoint"
    static let modelKey = "externalReceiptAssistModel"
    static let apiKeyEnvironmentKey = "AUTOLEDGER_EXTERNAL_RECEIPT_ASSIST_API_KEY"
    static let cacheStorageKey = "externalReceiptAssistShortTermCache.v1"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var provider: ExternalReceiptAssistProvider {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: providerKey),
                  let provider = ExternalReceiptAssistProvider(rawValue: rawValue) else {
                return .deepSeek
            }
            return provider
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: providerKey)
            if let endpoint = newValue.defaultEndpointURLString {
                endpointURLString = endpoint
            }
            if !newValue.defaultModel.isEmpty {
                modelName = newValue.defaultModel
            } else if newValue == .custom {
                UserDefaults.standard.removeObject(forKey: modelKey)
            }
        }
    }

    static var endpointURLString: String? {
        get {
            if let endpoint = UserDefaults.standard.string(forKey: endpointKey),
               !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return endpoint
            }
            return provider.defaultEndpointURLString
        }
        set {
            if let value = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                UserDefaults.standard.set(value, forKey: endpointKey)
            } else {
                UserDefaults.standard.removeObject(forKey: endpointKey)
            }
        }
    }

    static var modelName: String {
        get {
            if let model = UserDefaults.standard.string(forKey: modelKey),
               !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return model
            }
            return provider.defaultModel
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: modelKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: modelKey)
            }
        }
    }

    static func gateConfiguration(apiKey: String?) -> ExternalReceiptAssistConfiguration {
        ExternalReceiptAssistConfiguration(
            isEnabled: isEnabled,
            endpointURLString: endpointURLString,
            hasAPIKey: apiKey?.isEmpty == false,
            provider: provider,
            modelName: modelName
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

    static func clearShortTermCache() {
        UserDefaults.standard.removeObject(forKey: cacheStorageKey)
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
    private let gate = ExternalReceiptAssistGate()
    private let codec = ExternalReceiptAssistOpenAICompatibleCodec()
    private let cache = ExternalReceiptAssistShortTermCache()

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

        if let cached = cache.suggestion(for: payload, configuration: configuration, now: Date()) {
            return cached
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try codec.makeRequestData(
            payload: payload,
            model: configuration.modelName ?? ExternalReceiptAssistSettings.modelName
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExternalReceiptAssistClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ExternalReceiptAssistClientError.httpStatus(httpResponse.statusCode)
        }

        let suggestion = try codec.decodeSuggestion(from: data)
        cache.store(suggestion, for: payload, configuration: configuration, now: Date())
        return suggestion
    }
}

private struct ExternalReceiptAssistShortTermCache: Sendable {
    private let policy = ExternalReceiptAssistCachePolicy()

    init() {}

    func suggestion(
        for payload: ExternalReceiptAssistPayload,
        configuration: ExternalReceiptAssistConfiguration,
        now: Date
    ) -> ExternalReceiptAssistSuggestion? {
        let cacheKey = makeCacheKey(payload: payload, configuration: configuration)
        var records = loadRecords()
        records = policy.pruned(records, now: now)
        persist(records)
        return policy.usableSuggestion(
            from: records[cacheKey],
            expectedCacheKey: cacheKey,
            now: now
        )
    }

    func store(
        _ suggestion: ExternalReceiptAssistSuggestion,
        for payload: ExternalReceiptAssistPayload,
        configuration: ExternalReceiptAssistConfiguration,
        now: Date
    ) {
        let cacheKey = makeCacheKey(payload: payload, configuration: configuration)
        let record = policy.makeRecord(
            suggestion: suggestion,
            cacheKey: cacheKey,
            payload: payload,
            configuration: configuration,
            endpointFingerprint: fingerprint(configuration.endpointURLString),
            createdAt: now
        )
        var records = loadRecords()
        records[cacheKey] = record
        persist(policy.pruned(records, now: now))
    }

    private func makeCacheKey(
        payload: ExternalReceiptAssistPayload,
        configuration: ExternalReceiptAssistConfiguration
    ) -> String {
        policy.makeCacheKey(
            payload: payload,
            configuration: configuration,
            sanitizedTextHash: fingerprint(payload.sanitizedText),
            endpointFingerprint: fingerprint(configuration.endpointURLString)
        )
    }

    private func loadRecords() -> [String: ExternalReceiptAssistCacheRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = UserDefaults.standard.data(forKey: ExternalReceiptAssistSettings.cacheStorageKey),
              let records = try? decoder.decode([String: ExternalReceiptAssistCacheRecord].self, from: data) else {
            return [:]
        }
        return records
    }

    private func persist(_ records: [String: ExternalReceiptAssistCacheRecord]) {
        if records.isEmpty {
            UserDefaults.standard.removeObject(forKey: ExternalReceiptAssistSettings.cacheStorageKey)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        UserDefaults.standard.set(data, forKey: ExternalReceiptAssistSettings.cacheStorageKey)
    }

    private func fingerprint(_ value: String?) -> String {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
