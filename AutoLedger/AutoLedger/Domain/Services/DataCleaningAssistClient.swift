import AutoLedgerCore
import Foundation

enum DataCleaningAssistClientError: Error, Sendable {
    case invalidEndpoint
    case invalidResponse
    case httpStatus(Int)
}

struct DataCleaningAssistClient: Sendable {
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
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func requestSuggestions(
        payload: DataCleaningAssistPayload,
        signedTransactionInfo: String,
        endpoint: String
    ) async throws -> DataCleaningAssistResponse {
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
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DataCleaningAssistClientError.httpStatus(httpResponse.statusCode)
        }
        return try decoder.decode(DataCleaningAssistResponse.self, from: data)
    }
}
