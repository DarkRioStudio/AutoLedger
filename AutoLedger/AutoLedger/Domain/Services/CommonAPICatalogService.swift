import CryptoKit
import Foundation
import OSLog

nonisolated private let commonAPICatalogLogger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "CommonAPICatalogService")

enum CommonAPICatalogService {
    nonisolated struct LocalizedText: Codable, Sendable, Hashable {
        let zhHans: String
        let zhHant: String
        let en: String
        let ja: String
        let ko: String

        enum CodingKeys: String, CodingKey {
            case zhHans = "zh-Hans"
            case zhHant = "zh-Hant"
            case en
            case ja
            case ko
        }

        nonisolated var localizedName: String {
            switch languageKey {
            case "zh-Hant":
                return zhHant
            case "zh-Hans":
                return zhHans
            case "ja":
                return ja
            case "ko":
                return ko
            default:
                return en
            }
        }

        nonisolated private var languageKey: String {
            AppLanguagePreference.current.catalogLanguageKey
        }
    }

    nonisolated struct PlacesCatalog: Decodable, Sendable {
        let schemaVersion: Int
        let resourceVersion: String
        let countries: [PlaceCountry]
        let cities: [PlaceCity]
    }

    nonisolated struct PlaceCountry: Decodable, Sendable {
        let id: String
        let countryCode: String
        let names: LocalizedText
        let defaultCurrencyCode: String?
    }

    nonisolated struct PlaceCity: Decodable, Sendable {
        let id: String
        let countryCode: String
        let names: LocalizedText
        let latitude: Double
        let longitude: Double
        let timezone: String
    }

    nonisolated struct CurrencyCatalog: Decodable, Sendable {
        let schemaVersion: Int
        let resourceVersion: String
        let defaultCurrencyCode: String
        let currencies: [CurrencyRecord]
    }

    nonisolated struct CurrencyRecord: Decodable, Sendable {
        let code: String
        let symbol: String
        let names: LocalizedText
        let decimalDigits: Int
    }

    nonisolated private struct Manifest: Decodable {
        let resourceVersion: String
        let capabilities: Capabilities
    }

    nonisolated private struct Capabilities: Decodable {
        let placesCatalog: ResourceCapability?
        let currencyCatalog: ResourceCapability?
    }

    nonisolated private struct ResourceCapability: Decodable {
        let status: String
        let resourceVersion: String
        let url: String
        let sha256: String
    }

    nonisolated private static let manifestURLString = "https://api.darkrio326.top/v1/manifest"
    nonisolated private static let lastRefreshKey = "commonAPI.catalog.lastRefreshAt"
    nonisolated private static let minimumRefreshInterval: TimeInterval = 6 * 60 * 60

    nonisolated static func refreshIfNeeded(force: Bool = false) async {
        if !force,
           let lastRefreshAt = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date,
           Date().timeIntervalSince(lastRefreshAt) < minimumRefreshInterval {
            return
        }

        do {
            try await refresh()
            UserDefaults.standard.set(Date(), forKey: lastRefreshKey)
        } catch {
            commonAPICatalogLogger.warning("[CommonAPI] catalog refresh skipped: \(error.localizedDescription)")
        }
    }

    nonisolated static func cachedPlacesCatalog() -> PlacesCatalog? {
        guard let data = try? Data(contentsOf: placesCatalogURL) else { return nil }
        return try? JSONDecoder().decode(PlacesCatalog.self, from: data)
    }

    nonisolated static func cachedCurrencyCatalog() -> CurrencyCatalog? {
        guard let data = try? Data(contentsOf: currencyCatalogURL) else { return nil }
        return try? JSONDecoder().decode(CurrencyCatalog.self, from: data)
    }

    nonisolated private static func refresh() async throws {
        guard let url = URL(string: manifestURLString) else {
            throw CatalogError.invalidURL(manifestURLString)
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        let (manifestData, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, label: "manifest")

        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        if let places = manifest.capabilities.placesCatalog, places.status == "available" {
            try await refreshCatalog(
                capability: places,
                cacheURL: placesCatalogURL,
                decodeAs: PlacesCatalog.self
            )
        }

        if let currencies = manifest.capabilities.currencyCatalog, currencies.status == "available" {
            try await refreshCatalog(
                capability: currencies,
                cacheURL: currencyCatalogURL,
                decodeAs: CurrencyCatalog.self
            )
        }

        try manifestData.write(to: manifestURL, options: .atomic)
        commonAPICatalogLogger.info("[CommonAPI] catalog manifest refreshed: \(manifest.resourceVersion)")
    }

    nonisolated private static func refreshCatalog<T: Decodable>(
        capability: ResourceCapability,
        cacheURL: URL,
        decodeAs type: T.Type
    ) async throws {
        if let cachedData = try? Data(contentsOf: cacheURL),
           sha256Hex(cachedData) == capability.sha256 {
            return
        }

        guard let url = URL(string: capability.url) else {
            throw CatalogError.invalidURL(capability.url)
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, label: capability.url)

        guard sha256Hex(data) == capability.sha256 else {
            throw CatalogError.integrityCheckFailed(resourceVersion: capability.resourceVersion)
        }

        _ = try JSONDecoder().decode(type, from: data)
        try data.write(to: cacheURL, options: .atomic)
        commonAPICatalogLogger.info("[CommonAPI] catalog cached: \(capability.resourceVersion)")
    }

    nonisolated private static func validateHTTPResponse(_ response: URLResponse, label: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw CatalogError.httpFailure(label: label, statusCode: http.statusCode)
        }
    }

    nonisolated private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static var cacheDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CommonAPI", isDirectory: true)
    }

    nonisolated private static var manifestURL: URL {
        cacheDirectory.appendingPathComponent("manifest.json")
    }

    nonisolated private static var placesCatalogURL: URL {
        cacheDirectory.appendingPathComponent("places-catalog.json")
    }

    nonisolated private static var currencyCatalogURL: URL {
        cacheDirectory.appendingPathComponent("currencies-catalog.json")
    }

    nonisolated enum CatalogError: LocalizedError {
        case invalidURL(String)
        case httpFailure(label: String, statusCode: Int)
        case integrityCheckFailed(resourceVersion: String)

        var errorDescription: String? {
            switch self {
            case .invalidURL(let url):
                return "Invalid Common API URL: \(url)"
            case .httpFailure(let label, let statusCode):
                return "Common API \(label) returned HTTP \(statusCode)"
            case .integrityCheckFailed(let resourceVersion):
                return "Common API catalog integrity check failed: \(resourceVersion)"
            }
        }
    }
}
