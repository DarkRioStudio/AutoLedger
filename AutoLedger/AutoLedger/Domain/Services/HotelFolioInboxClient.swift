import AutoLedgerCore
import Foundation
import Security

enum HotelFolioInboxClientError: LocalizedError, Sendable {
    case missingToken
    case invalidEndpoint
    case invalidHTTPResponse
    case invalidTokenClaimResponse
    case httpStatus(Int, String)
    case keychainStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return String(localized: "hotel_stay.cloud_inbox.error.missing_token")
        case .invalidEndpoint:
            return String(localized: "hotel_stay.cloud_inbox.error.invalid_endpoint")
        case .invalidHTTPResponse:
            return String(localized: "hotel_stay.cloud_inbox.error.invalid_response")
        case .invalidTokenClaimResponse:
            return String(localized: "hotel_stay.cloud_inbox.error.invalid_token_claim_response")
        case .httpStatus(let status, let message):
            return String(format: String(localized: "hotel_stay.cloud_inbox.error.http_status_format"), status, message)
        case .keychainStatus(let status):
            return String(format: String(localized: "hotel_stay.cloud_inbox.error.keychain_format"), Int(status))
        }
    }
}

struct HotelFolioInboxSettings: Equatable, Sendable {
    static let defaultEndpoint = "https://folio.getautoledger.app"
    static let endpointKey = "hotelFolioInboxEndpoint"
    static let clientIDKey = "hotelFolioInboxClientID"

    var endpoint: String
    var token: String

    init(endpoint: String = Self.currentEndpoint, token: String = HotelFolioInboxTokenStore.readToken() ?? "") {
        self.endpoint = endpoint
        self.token = token
    }

    var normalizedToken: String {
        HotelCloudFolioInboxAddress(token: token).normalizedToken
    }

    var inboxAddress: String {
        HotelCloudFolioInboxAddress(token: normalizedToken).emailAddress
    }

    var canRequest: Bool {
        !normalizedToken.isEmpty && URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    static var currentEndpoint: String {
        let stored = UserDefaults.standard.string(forKey: endpointKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored! : defaultEndpoint
    }

    static var currentClientID: String {
        if let stored = UserDefaults.standard.string(forKey: clientIDKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            return stored
        }
        let clientID = UUID().uuidString.lowercased()
        UserDefaults.standard.set(clientID, forKey: clientIDKey)
        return clientID
    }

    func save() throws {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEndpoint.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.endpointKey)
        } else {
            UserDefaults.standard.set(trimmedEndpoint, forKey: Self.endpointKey)
        }

        if !normalizedToken.isEmpty {
            try HotelFolioInboxTokenStore.saveToken(normalizedToken)
        }
    }
}

struct HotelFolioInboxTokenClaim: Equatable, Sendable {
    var token: String
    var inboxEmail: String
    var tokenHash: String
    var userID: String
    var status: String
}

extension HotelFolioInboxTokenClaim: Decodable {}

enum HotelFolioInboxTokenStore {
    private static let service = "top.darkrio326.AutoLedger.hotelFolioInbox"
    private static let account = "inboxToken"

    static func saveToken(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        deleteToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(trimmed.utf8)
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw HotelFolioInboxClientError.keychainStatus(status)
        }
    }

    static func readToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct HotelFolioInboxClient: Sendable {
    private struct CandidateListResponse: Decodable {
        var candidates: [CloudHotelFolioCandidate]
    }

    private struct StatusUpdatePayload: Encodable {
        var status: CloudHotelFolioCandidateStatus
        var failureReason: String?
        var deleteCloudPDF: Bool?
    }

    private struct DeviceRegistrationPayload: Encodable {
        var deviceToken: String
        var platform: String
        var environment: String
    }

    private struct TokenClaimPayload: Encodable {
        var clientID: String
        var platform: String
        var environment: String
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

    func claimInboxToken(settings: HotelFolioInboxSettings) async throws -> HotelFolioInboxTokenClaim {
        var request = try makeBaseRequest(
            path: "/v1/cloud-hotel-folio-token",
            endpoint: settings.endpoint
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(TokenClaimPayload(
            clientID: HotelFolioInboxSettings.currentClientID,
            platform: Self.currentPlatform,
            environment: Self.currentPushEnvironment
        ))

        let data = try await data(for: request)
        let claim = try decoder.decode(HotelFolioInboxTokenClaim.self, from: data)
        guard !claim.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !claim.inboxEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HotelFolioInboxClientError.invalidTokenClaimResponse
        }
        return claim
    }

    func listCandidates(settings: HotelFolioInboxSettings) async throws -> [CloudHotelFolioCandidate] {
        let request = try makeRequest(
            path: "/v1/cloud-hotel-folio-candidates",
            settings: settings
        )
        let data = try await data(for: request)
        return try decoder
            .decode(CandidateListResponse.self, from: data)
            .candidates
            .filter(\.isVisibleInInboxImportList)
    }

    func downloadPDF(candidate: CloudHotelFolioCandidate, settings: HotelFolioInboxSettings) async throws -> Data {
        let request = try makeRequest(
            path: "/v1/cloud-hotel-folio-candidates/\(candidateIDPathComponent(candidate))/pdf",
            settings: settings
        )
        return try await data(for: request)
    }

    func registerDeviceToken(
        settings: HotelFolioInboxSettings,
        deviceToken: String,
        platform: String = Self.currentPlatform,
        environment: String = Self.currentPushEnvironment
    ) async throws {
        var request = try makeRequest(
            path: "/v1/cloud-hotel-folio-devices",
            settings: settings
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(DeviceRegistrationPayload(
            deviceToken: deviceToken,
            platform: platform,
            environment: environment
        ))
        _ = try await data(for: request)
    }

    @discardableResult
    func updateStatus(
        candidate: CloudHotelFolioCandidate,
        status: CloudHotelFolioCandidateStatus,
        failureReason: String? = nil,
        deleteCloudPDF: Bool = false,
        settings: HotelFolioInboxSettings
    ) async throws -> CloudHotelFolioCandidate? {
        var request = try makeRequest(
            path: "/v1/cloud-hotel-folio-candidates/\(candidateIDPathComponent(candidate))/status",
            settings: settings
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(StatusUpdatePayload(
            status: status,
            failureReason: failureReason,
            deleteCloudPDF: deleteCloudPDF
        ))
        let data = try await data(for: request)
        return try? decoder.decode([String: CloudHotelFolioCandidate].self, from: data)["candidate"]
    }

    private func candidateIDPathComponent(_ candidate: CloudHotelFolioCandidate) -> String {
        candidate.id.uuidString.lowercased()
    }

    private func makeRequest(path: String, settings: HotelFolioInboxSettings) throws -> URLRequest {
        guard !settings.normalizedToken.isEmpty else {
            throw HotelFolioInboxClientError.missingToken
        }
        var request = try makeBaseRequest(path: path, endpoint: settings.endpoint)
        request.setValue("Bearer \(settings.normalizedToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func makeBaseRequest(path: String, endpoint: String) throws -> URLRequest {
        guard let baseURL = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw HotelFolioInboxClientError.invalidEndpoint
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let basePath = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        let requestPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components?.path = "/" + [basePath, requestPath].filter { !$0.isEmpty }.joined(separator: "/")
        guard let url = components?.url else {
            throw HotelFolioInboxClientError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        return request
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HotelFolioInboxClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw HotelFolioInboxClientError.httpStatus(httpResponse.statusCode, message)
        }
        return data
    }

    nonisolated private static func decodeISODate(_ decoder: Decoder) throws -> Date {
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

    nonisolated private static var currentPushEnvironment: String {
        #if DEBUG
        "development"
        #else
        "production"
        #endif
    }

    nonisolated private static var currentPlatform: String {
        #if targetEnvironment(macCatalyst)
        "mac_catalyst"
        #elseif os(iOS)
        "ios"
        #else
        "apple"
        #endif
    }
}
