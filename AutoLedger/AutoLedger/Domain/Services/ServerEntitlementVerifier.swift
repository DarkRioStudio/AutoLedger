import AutoLedgerCore
import Foundation

protocol ServerEntitlementVerifying: Sendable {
    func verifyAccess(
        capability: AutoLedgerCapability,
        localSubscriptionSnapshot: ProSubscriptionSnapshot?
    ) async throws -> ServerEntitlementVerificationResult
}

struct ServerEntitlementVerificationResult: Equatable, Sendable {
    let allowed: Bool
    let reason: String?
    let expiresAt: Date?

    init(allowed: Bool, reason: String? = nil, expiresAt: Date? = nil) {
        self.allowed = allowed
        self.reason = reason
        self.expiresAt = expiresAt
    }
}

struct UnavailableServerEntitlementVerifier: ServerEntitlementVerifying {
    func verifyAccess(
        capability: AutoLedgerCapability,
        localSubscriptionSnapshot: ProSubscriptionSnapshot?
    ) async throws -> ServerEntitlementVerificationResult {
        ServerEntitlementVerificationResult(
            allowed: false,
            reason: "server_entitlement_verifier_unavailable",
            expiresAt: localSubscriptionSnapshot?.expirationDate
        )
    }
}

struct CloudFolioInboxEntitlementVerifier: ServerEntitlementVerifying {
    private struct VerificationPayload: Encodable {
        let capability: AutoLedgerCapability
        let signedTransactionInfo: String?
        let clientID: String
        let platform: String
        let environment: String
    }

    private struct VerificationResponse: Decodable {
        let allowed: Bool
        let reason: String?
        let expiresAt: Date?
    }

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.decoder.dateDecodingStrategy = .custom(Self.decodeISODate)
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func verifyAccess(
        capability: AutoLedgerCapability,
        localSubscriptionSnapshot: ProSubscriptionSnapshot?
    ) async throws -> ServerEntitlementVerificationResult {
        guard capability == .cloudFolioInbox else {
            return ServerEntitlementVerificationResult(allowed: false, reason: "unsupported_capability")
        }
        let payload = VerificationPayload(
            capability: capability,
            signedTransactionInfo: localSubscriptionSnapshot?.signedTransactionInfo,
            clientID: HotelFolioInboxSettings.currentClientID,
            platform: HotelFolioInboxClient.currentPlatform,
            environment: HotelFolioInboxClient.currentPushEnvironment
        )
        var request = try HotelFolioInboxClient.makeBaseRequest(
            path: "/v1/pro-entitlements/verify",
            endpoint: HotelFolioInboxSettings.currentEndpoint
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return ServerEntitlementVerificationResult(allowed: false, reason: "invalid_http_response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            return ServerEntitlementVerificationResult(allowed: false, reason: message)
        }

        let verified = try decoder.decode(VerificationResponse.self, from: data)
        return ServerEntitlementVerificationResult(
            allowed: verified.allowed,
            reason: verified.reason,
            expiresAt: verified.expiresAt
        )
    }

    private static func decodeISODate(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let date = standard.date(from: value) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
    }
}

struct StubServerEntitlementVerifier: ServerEntitlementVerifying {
    var result: ServerEntitlementVerificationResult

    init(result: ServerEntitlementVerificationResult) {
        self.result = result
    }

    func verifyAccess(
        capability: AutoLedgerCapability,
        localSubscriptionSnapshot: ProSubscriptionSnapshot?
    ) async throws -> ServerEntitlementVerificationResult {
        result
    }
}
