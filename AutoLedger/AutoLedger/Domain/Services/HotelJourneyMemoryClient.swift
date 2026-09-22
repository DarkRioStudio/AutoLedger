import AutoLedgerCore
import Foundation

enum HotelJourneyMemoryClient {
    enum RequestError: Error {
        case needsDeepSeekConfiguration
        case requestFailed
    }

    /// Called only after the user selects Generate; shares the existing DeepSeek settings.
    static func generate(input: HotelJourneyMemoryInput) async throws -> String {
        guard ExternalReceiptAssistSettings.provider == .deepSeek,
              let endpoint = ExternalReceiptAssistSettings.endpointURLString.flatMap(URL.init(string:)),
              endpoint.scheme == "https",
              let apiKey = ExternalReceiptAssistSettings.runtimeAPIKey, !apiKey.isEmpty else {
            throw RequestError.needsDeepSeekConfiguration
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try HotelJourneyMemoryCodec.requestData(input: input, model: ExternalReceiptAssistSettings.modelName)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw RequestError.requestFailed
        }
        return try HotelJourneyMemoryCodec.text(from: data)
    }
}
