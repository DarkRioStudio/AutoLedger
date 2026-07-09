import Foundation
import OSLog

nonisolated private let commonAPIReleaseNotesLogger = Logger(
    subsystem: "top.darkrio326.AutoLedger",
    category: "CommonAPIReleaseNotesService"
)

enum CommonAPIReleaseNotesService {
    nonisolated struct Section: Codable, Equatable, Sendable {
        let title: String
        let body: String
    }

    nonisolated struct ReleaseNotes: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let resourceVersion: String
        let app: String
        let version: String
        let locale: String
        let current: Section
        let upcoming: Section
    }

    nonisolated private static let endpointURLString = "https://api.darkrio326.top/v1/release-notes"
    nonisolated private static let appID = "autoledger"

    nonisolated static func cachedReleaseNotes(appVersion: String) -> ReleaseNotes? {
        guard let cacheURL = cacheURL(appVersion: appVersion) else { return nil }
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(ReleaseNotes.self, from: data)
    }

    nonisolated static func refreshReleaseNotes(appVersion: String) async -> ReleaseNotes? {
        let startedAt = Date()
        do {
            let notes = try await fetchReleaseNotes(appVersion: appVersion)
            CommonAPIAnalyticsService.trackCommonAPIRequest(
                endpointGroup: "release_notes",
                httpStatusBucket: "2xx",
                startedAt: startedAt,
                errorCode: "none",
                cacheStatus: "miss"
            )
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            if let cacheURL = cacheURL(appVersion: appVersion) {
                let data = try JSONEncoder().encode(notes)
                try data.write(to: cacheURL, options: .atomic)
            }
            return notes
        } catch {
            commonAPIReleaseNotesLogger.warning("[CommonAPI] release notes refresh skipped: \(error.localizedDescription)")
            if let cached = cachedReleaseNotes(appVersion: appVersion) {
                CommonAPIAnalyticsService.trackCommonAPIRequest(
                    endpointGroup: "release_notes",
                    httpStatusBucket: "network_error",
                    startedAt: startedAt,
                    errorCode: CommonAPIAnalyticsService.errorCode(for: error),
                    cacheStatus: "stale"
                )
                return cached
            }
            CommonAPIAnalyticsService.trackCommonAPIRequest(
                endpointGroup: "release_notes",
                httpStatusBucket: httpStatusBucket(for: error),
                startedAt: startedAt,
                errorCode: errorCode(for: error),
                cacheStatus: "miss"
            )
            return nil
        }
    }

    nonisolated private static func fetchReleaseNotes(appVersion: String) async throws -> ReleaseNotes {
        guard let url = releaseNotesURL(appVersion: appVersion) else {
            throw ReleaseNotesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)
        return try JSONDecoder().decode(ReleaseNotes.self, from: data)
    }

    nonisolated private static func releaseNotesURL(appVersion: String) -> URL? {
        guard !appVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let baseURL = URL(string: endpointURLString),
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "app", value: appID),
            URLQueryItem(name: "version", value: appVersion),
            URLQueryItem(name: "locale", value: AppLanguagePreference.current.catalogLanguageKey)
        ]
        return components.url
    }

    nonisolated private static func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw ReleaseNotesError.httpFailure(statusCode: http.statusCode)
        }
    }

    nonisolated private static func httpStatusBucket(for error: Error) -> String {
        if case let ReleaseNotesError.httpFailure(statusCode) = error {
            return CommonAPIAnalyticsService.httpStatusBucket(statusCode)
        }
        return "network_error"
    }

    nonisolated private static func errorCode(for error: Error) -> String {
        if case let ReleaseNotesError.httpFailure(statusCode) = error {
            return "http_\(statusCode)"
        }
        return CommonAPIAnalyticsService.errorCode(for: error)
    }

    nonisolated private static func cacheURL(appVersion: String) -> URL? {
        let trimmedVersion = appVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVersion.isEmpty else { return nil }
        let locale = AppLanguagePreference.current.catalogLanguageKey
        let filename = "release-notes-\(appID)-\(safeFileComponent(trimmedVersion))-\(safeFileComponent(locale)).json"
        return cacheDirectory.appendingPathComponent(filename)
    }

    nonisolated private static func safeFileComponent(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"[^A-Za-z0-9._-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    nonisolated private static var cacheDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CommonAPI", isDirectory: true)
    }

    nonisolated enum ReleaseNotesError: LocalizedError {
        case invalidURL
        case httpFailure(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Common API release notes URL"
            case .httpFailure(let statusCode):
                return "Common API release notes returned HTTP \(statusCode)"
            }
        }
    }
}
