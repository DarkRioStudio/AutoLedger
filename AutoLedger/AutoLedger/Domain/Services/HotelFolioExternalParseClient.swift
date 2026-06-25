import AutoLedgerCore
import Foundation

enum HotelFolioExternalParseClientError: LocalizedError, Sendable {
    case disabled
    case missingAPIKey
    case missingEndpoint
    case invalidHTTPResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return String(localized: "hotel_stay.import.error.external_disabled")
        case .missingAPIKey:
            return String(localized: "hotel_stay.import.error.missing_api_key")
        case .missingEndpoint:
            return String(localized: "hotel_stay.import.error.missing_endpoint")
        case .invalidHTTPResponse:
            return String(localized: "hotel_stay.import.error.invalid_response")
        case let .httpStatus(status):
            return String(format: String(localized: "hotel_stay.import.error.http_status_format"), status)
        }
    }
}

struct HotelFolioExternalParseClient: Sendable {
    private let pipeline = HotelFolioParsePipeline()
    private let codec = HotelFolioOpenAICompatibleCodec()

    func parse(_ draft: HotelStayDraft) async throws -> HotelStayDraft {
        guard ExternalReceiptAssistSettings.isEnabled else {
            throw HotelFolioExternalParseClientError.disabled
        }
        guard let apiKey = ExternalReceiptAssistSettings.runtimeAPIKey,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HotelFolioExternalParseClientError.missingAPIKey
        }
        guard let endpointString = ExternalReceiptAssistSettings.endpointURLString,
              let endpointURL = URL(string: endpointString) else {
            throw HotelFolioExternalParseClientError.missingEndpoint
        }

        let payload = try pipeline.makePayload(from: draft)
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try codec.makeRequestData(
            payload: payload,
            model: ExternalReceiptAssistSettings.modelName
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HotelFolioExternalParseClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HotelFolioExternalParseClientError.httpStatus(httpResponse.statusCode)
        }
        return try pipeline.parse(draft: draft, responseData: data, codec: codec)
    }
}
