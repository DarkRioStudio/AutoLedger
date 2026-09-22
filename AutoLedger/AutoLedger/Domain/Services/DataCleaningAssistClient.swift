import AutoLedgerCore
import Foundation
import CryptoKit

enum DataCleaningAssistClientError: Error, Sendable {
    case invalidEndpoint
    case invalidResponse
    case httpStatus(Int)
    case coolingDown(Date)
    case rateLimited(TimeInterval)
}

@MainActor
final class DataCleaningAssistClient {
    static let shared = DataCleaningAssistClient()
    private var requests: [String: Task<DataCleaningAssistResponse, Error>] = [:]

    private struct RequestPayload: Encodable {
        let signedTransactionInfo: String
        let payload: DataCleaningAssistPayload
    }

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func requestSuggestions(
        payload: DataCleaningAssistPayload,
        signedTransactionInfo: String,
        endpoint: String
    ) async throws -> DataCleaningAssistResponse {
        let keyEncoder = JSONEncoder()
        keyEncoder.outputFormatting = [.sortedKeys]
        var canonical = try JSONSerialization.jsonObject(with: keyEncoder.encode(payload)) as? [String: Any] ?? [:]
        canonical.removeValue(forKey: "generatedAt")
        let normalized = try JSONSerialization.data(withJSONObject: canonical, options: [.sortedKeys])
        let endpointHash = SHA256.hash(data: Data(endpoint.utf8)).map { String(format: "%02x", $0) }.joined()
        let payloadHash = SHA256.hash(data: normalized).map { String(format: "%02x", $0) }.joined()
        let cacheKey = "cleaningAssist.cache." + endpointHash + payloadHash
        let retryKey = "cleaningAssist.retry." + endpointHash
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: cacheKey),
           let cached = try? decoder.decode(DataCleaningAssistCacheEntry.self, from: data), cached.expiresAt > .now {
            return cached.response
        }
        if let task = requests[cacheKey] { return try await task.value }
        var retry = defaults.data(forKey: retryKey).flatMap { try? decoder.decode(DataCleaningAssistRetryState.self, from: $0) }
            ?? DataCleaningAssistRetryState()
        if let next = retry.nextEligibleAt, next > .now { throw DataCleaningAssistClientError.coolingDown(next) }
        retry.nextEligibleAt = Date().addingTimeInterval(60)
        defaults.set(try encoder.encode(retry), forKey: retryKey)
        let task = Task { try await self.performRequest(payload: payload, signedTransactionInfo: signedTransactionInfo, endpoint: endpoint) }
        requests[cacheKey] = task
        defer { requests[cacheKey] = nil }
        do {
            let response = try await task.value
            retry.recordSuccess(at: .now)
            // Keep one successful hash-only response per endpoint; never persist the entitlement token.
            let prefix = "cleaningAssist.cache." + endpointHash
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) { defaults.removeObject(forKey: key) }
            defaults.set(try encoder.encode(DataCleaningAssistCacheEntry(response: response, expiresAt: .now.addingTimeInterval(21_600))), forKey: cacheKey)
            defaults.set(try encoder.encode(retry), forKey: retryKey)
            return response
        } catch {
            if !(error is CancellationError) {
                let delay: TimeInterval?
                if case let DataCleaningAssistClientError.rateLimited(seconds) = error { delay = seconds } else { delay = nil }
                retry.recordFailure(at: .now, retryAfter: delay)
                defaults.set(try? encoder.encode(retry), forKey: retryKey)
            }
            throw error
        }
    }

    private func performRequest(payload: DataCleaningAssistPayload, signedTransactionInfo: String, endpoint: String) async throws -> DataCleaningAssistResponse {
        var request = try HotelFolioInboxClient.makeBaseRequest(
            path: "/v1/data-cleaning-assist",
            endpoint: endpoint
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(RequestPayload(
            signedTransactionInfo: signedTransactionInfo,
            payload: payload
        ))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DataCleaningAssistClientError.invalidResponse
        }
        if httpResponse.statusCode == 429 {
            throw DataCleaningAssistClientError.rateLimited(Double(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DataCleaningAssistClientError.httpStatus(httpResponse.statusCode)
        }
        let result = try decoder.decode(DataCleaningAssistResponse.self, from: data)
        guard result.schemaVersion == 1, result.privacyMode == "hashed_suggestions_v1" else {
            throw DataCleaningAssistClientError.invalidResponse
        }
        return result
    }
}
