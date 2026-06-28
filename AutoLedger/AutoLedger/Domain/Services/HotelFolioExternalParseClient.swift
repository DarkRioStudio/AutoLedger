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

struct HotelFolioExternalParseResult: Sendable {
    let draft: HotelStayDraft
    let debugRecords: [ImportDebugRecord]
}

struct HotelFolioExternalParseFailure: LocalizedError, Sendable {
    let message: String
    let debugRecords: [ImportDebugRecord]

    var errorDescription: String? { message }
}

struct HotelFolioExternalParseClient: Sendable {
    private let pipeline = HotelFolioParsePipeline()
    private let codec = HotelFolioOpenAICompatibleCodec()

    func parse(_ draft: HotelStayDraft) async throws -> HotelStayDraft {
        try await parseWithDebug(draft).draft
    }

    func parseWithDebug(_ draft: HotelStayDraft) async throws -> HotelFolioExternalParseResult {
        var debugRecords: [ImportDebugRecord] = []

        func fail(
            _ error: Error,
            providerID: String? = nil,
            responseBody: String? = nil,
            latencyMs: Int? = nil
        ) throws -> Never {
            let message = localizedErrorMessage(error)
            debugRecords.append(
                HotelFolioDebugTraceBuilder.makeParseFailedRecord(
                    draft: draft,
                    message: message,
                    providerID: providerID,
                    responseBody: responseBody,
                    latencyMs: latencyMs
                )
            )
            throw HotelFolioExternalParseFailure(message: message, debugRecords: debugRecords)
        }

        guard ExternalReceiptAssistSettings.isEnabled else {
            try fail(HotelFolioExternalParseClientError.disabled)
        }
        guard let apiKey = ExternalReceiptAssistSettings.runtimeAPIKey,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            try fail(HotelFolioExternalParseClientError.missingAPIKey)
        }
        guard let endpointString = ExternalReceiptAssistSettings.endpointURLString,
              let endpointURL = URL(string: endpointString) else {
            try fail(HotelFolioExternalParseClientError.missingEndpoint)
        }

        let providerID = "external_\(ExternalReceiptAssistSettings.provider.rawValue)"
        let modelName = ExternalReceiptAssistSettings.modelName
        let payload: HotelFolioParsePayload
        do {
            payload = try pipeline.makePayload(from: draft)
        } catch {
            try fail(error, providerID: providerID)
        }

        let requestData: Data
        do {
            requestData = try codec.makeRequestData(
                payload: payload,
                model: modelName
            )
        } catch {
            try fail(error, providerID: providerID)
        }

        if let requestBody = String(data: requestData, encoding: .utf8) {
            debugRecords.append(
                HotelFolioDebugTraceBuilder.makeLLMRequestRecord(
                    draft: draft,
                    payload: payload,
                    requestBody: requestBody,
                    providerID: providerID,
                    model: modelName
                )
            )
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestData

        let start = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            let latencyMs = Int(Date().timeIntervalSince(start) * 1_000)
            try fail(error, providerID: providerID, latencyMs: latencyMs)
        }
        let latencyMs = Int(Date().timeIntervalSince(start) * 1_000)
        let responseBody = String(data: data, encoding: .utf8) ?? ""
        guard let httpResponse = response as? HTTPURLResponse else {
            try fail(
                HotelFolioExternalParseClientError.invalidHTTPResponse,
                providerID: providerID,
                responseBody: responseBody,
                latencyMs: latencyMs
            )
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            try fail(
                HotelFolioExternalParseClientError.httpStatus(httpResponse.statusCode),
                providerID: providerID,
                responseBody: responseBody,
                latencyMs: latencyMs
            )
        }

        let parsedPayload: HotelFolioParsedPayload
        do {
            parsedPayload = try codec.decodeParsedPayload(from: data)
        } catch {
            try fail(error, providerID: providerID, responseBody: responseBody, latencyMs: latencyMs)
        }

        debugRecords.append(
            HotelFolioDebugTraceBuilder.makeLLMResponseRecord(
                draft: draft,
                responseBody: responseBody,
                httpStatus: httpResponse.statusCode,
                providerID: providerID,
                model: modelName,
                latencyMs: latencyMs,
                parsedPayload: parsedPayload
            )
        )
        debugRecords.append(
            HotelFolioDebugTraceBuilder.makeLocalizationRecord(
                draft: draft,
                parsedPayload: parsedPayload,
                providerID: providerID,
                model: modelName
            )
        )
        debugRecords.append(
            HotelFolioDebugTraceBuilder.makeExchangeRateRecord(
                draft: draft,
                parsedPayload: parsedPayload
            )
        )

        let parsedDraft: HotelStayDraft
        do {
            parsedDraft = try pipeline.apply(parsedPayload, to: draft)
        } catch {
            try fail(error, providerID: providerID, responseBody: responseBody, latencyMs: latencyMs)
        }
        return HotelFolioExternalParseResult(draft: parsedDraft, debugRecords: debugRecords)
    }

    private func localizedErrorMessage(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
    }
}
