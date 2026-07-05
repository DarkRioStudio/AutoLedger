import Foundation

public enum HotelFolioDebugTraceBuilder {
    public static let maxDebugTextCharacters = 3_000

    public static func makeTextExtractedRecord(draft: HotelStayDraft) -> ImportDebugRecord {
        ImportDebugRecord(
            stage: .hotelFolioTextExtracted,
            source: .manual,
            imageSource: imageSource(for: draft.sourceType),
            rawText: truncated(draft.rawText),
            parsedReceipt: nil,
            summary: [
                "酒店水单文本已提取",
                "来源=\(draft.sourceType.rawValue)",
                "文件=\(draft.sourceFileName ?? draft.sourceEmailSubject ?? "-")",
                "字符数=\(draft.rawText.count)"
            ].joined(separator: " · "),
            usedRuleFallback: false
        )
    }

    public static func makeLLMRequestRecord(
        draft: HotelStayDraft,
        payload: HotelFolioParsePayload,
        requestBody: String,
        providerID: String,
        model: String
    ) -> ImportDebugRecord {
        ImportDebugRecord(
            stage: .hotelFolioLLMRequest,
            source: .manual,
            imageSource: imageSource(for: draft.sourceType),
            rawText: payload.sanitizedText,
            parsedReceipt: nil,
            summary: [
                "酒店水单已提交外部模型解析",
                "provider=\(providerID)",
                "model=\(model)",
                "source=\(payload.sourceType.rawValue)",
                "targetLocale=\(payload.targetLocaleIdentifier)",
                "redactions=\(payload.redactionCount)"
            ].joined(separator: " · "),
            llmPrompt: truncated(requestBody),
            llmResponse: nil,
            llmProvider: providerID,
            usedRuleFallback: false
        )
    }

    public static func makeLLMResponseRecord(
        draft: HotelStayDraft,
        responseBody: String,
        httpStatus: Int,
        providerID: String,
        model: String,
        latencyMs: Int,
        parsedPayload: HotelFolioParsedPayload?
    ) -> ImportDebugRecord {
        let hotelName = trimmed(parsedPayload?.localizedData?.hotelName)
            ?? trimmed(parsedPayload?.hotelName)
            ?? "-"
        let amountText: String = {
            guard let amount = parsedPayload?.localizedData?.totalAmount ?? parsedPayload?.totalAmount else {
                return "-"
            }
            let currency = trimmed(parsedPayload?.localizedData?.currency)
                ?? trimmed(parsedPayload?.currency)
                ?? "-"
            return "\(currency) \(formatAmount(amount))"
        }()
        return ImportDebugRecord(
            stage: .hotelFolioLLMResponse,
            source: .manual,
            imageSource: imageSource(for: draft.sourceType),
            rawText: truncated(draft.rawText),
            parsedReceipt: nil,
            summary: [
                "酒店水单模型输出已返回",
                "status=\(httpStatus)",
                "provider=\(providerID)",
                "model=\(model)",
                "hotel=\(hotelName)",
                "total=\(amountText)"
            ].joined(separator: " · "),
            llmPrompt: nil,
            llmResponse: truncated(responseBody),
            llmProvider: providerID,
            llmLatencyMs: latencyMs,
            llmConfidence: parsedPayload?.confidence,
            usedRuleFallback: false
        )
    }

    public static func makeLocalizationRecord(
        draft: HotelStayDraft,
        parsedPayload: HotelFolioParsedPayload,
        providerID: String?,
        model: String?
    ) -> ImportDebugRecord {
        var originalPayload = parsedPayload
        originalPayload.localizedData = nil
        let localized = parsedPayload.localizedData
        return ImportDebugRecord(
            stage: .hotelFolioLocalization,
            source: .manual,
            imageSource: imageSource(for: draft.sourceType),
            rawText: truncated(draft.rawText),
            parsedReceipt: nil,
            summary: localizationSummary(original: originalPayload, localized: localized),
            llmPrompt: truncated(encoded(originalPayload)),
            llmResponse: truncated(localized.map(encoded) ?? #"{"status":"skipped","reason":"model did not return localized object"}"#),
            llmProvider: providerID,
            llmConfidence: parsedPayload.confidence,
            usedRuleFallback: false
        )
    }

    public static func makeExchangeRateRecord(
        draft: HotelStayDraft,
        parsedPayload: HotelFolioParsedPayload
    ) -> ImportDebugRecord {
        let localized = parsedPayload.localizedData
        let input = exchangeRateInputJSON(parsedPayload: parsedPayload, localized: localized)
        let output = exchangeRateOutputJSON(parsedPayload: parsedPayload, localized: localized)
        return ImportDebugRecord(
            stage: .hotelFolioExchangeRate,
            source: .manual,
            imageSource: imageSource(for: draft.sourceType),
            rawText: truncated(draft.rawText),
            parsedReceipt: nil,
            summary: exchangeRateSummary(parsedPayload: parsedPayload, localized: localized),
            llmPrompt: truncated(input),
            llmResponse: truncated(output),
            llmProvider: localized?.exchangeRateProvider,
            llmConfidence: parsedPayload.confidence,
            usedRuleFallback: false
        )
    }

    public static func makeEmailScanRecord(
        summary: String,
        rawText: String = "",
        request: String? = nil,
        response: String? = nil
    ) -> ImportDebugRecord {
        ImportDebugRecord(
            stage: .hotelFolioEmailScan,
            source: .manual,
            imageSource: .emailAttachment,
            rawText: truncated(rawText),
            parsedReceipt: nil,
            summary: summary,
            llmPrompt: request.map(truncated),
            llmResponse: response.map(truncated),
            usedRuleFallback: false
        )
    }

    public static func makeParseFailedRecord(
        draft: HotelStayDraft,
        message: String,
        providerID: String? = nil,
        responseBody: String? = nil,
        latencyMs: Int? = nil
    ) -> ImportDebugRecord {
        ImportDebugRecord(
            stage: .hotelFolioParseFailed,
            source: .manual,
            imageSource: imageSource(for: draft.sourceType),
            rawText: truncated(draft.rawText),
            parsedReceipt: nil,
            summary: "酒店水单识别失败：\(message)",
            llmPrompt: nil,
            llmResponse: responseBody.map(truncated),
            llmProvider: providerID,
            llmLatencyMs: latencyMs,
            usedRuleFallback: false
        )
    }

    public static func makeDraftSavedRecord(draft: HotelStayDraft) -> ImportDebugRecord {
        ImportDebugRecord(
            stage: .hotelFolioDraftSaved,
            source: .manual,
            imageSource: imageSource(for: draft.sourceType),
            rawText: truncated(draft.rawText),
            parsedReceipt: nil,
            summary: [
                "酒店水单已进入待确认",
                "status=\(draft.status.rawValue)",
                "hotel=\(trimmed(draft.localizedData?.hotelName) ?? trimmed(draft.parsedPayload?.hotelName) ?? "-")",
                "confidence=\(String(format: "%.2f", draft.confidence))"
            ].joined(separator: " · "),
            llmConfidence: draft.confidence,
            usedRuleFallback: false
        )
    }

    public static func makePostedRecord(result: HotelStayLedgerPostingResult) -> ImportDebugRecord {
        let record = result.hotelStayRecord
        let localized = record.localizedData
        let amount = localized?.totalAmount ?? record.totalAmount
        let currency = trimmed(localized?.currency) ?? record.currency
        return ImportDebugRecord(
            stage: .hotelFolioPosted,
            source: .manual,
            imageSource: imageSource(for: record.sourceType),
            rawText: truncated(record.rawText),
            parsedReceipt: nil,
            summary: [
                "酒店消费已确认入账",
                "hotel=\(localized?.hotelName ?? record.hotelName)",
                "amount=\(currency) \(formatAmount(amount))",
                "transaction=\(result.transaction.id.uuidString)",
                "ledger=\(record.ledgerID)"
            ].joined(separator: " · "),
            transactionID: result.transaction.id,
            llmConfidence: record.confidence,
            usedRuleFallback: false
        )
    }

    public static func imageSource(for sourceType: HotelFolioSourceType) -> ImageSource {
        switch sourceType {
        case .manualPDF:
            return .documentPDF
        case .localEmailIMAP:
            return .emailAttachment
        case .cloudWorker:
            return .cloudWorker
        case .shareExtension:
            return .shareExtension
        }
    }

    private static func localizationSummary(
        original: HotelFolioParsedPayload,
        localized: HotelStayLocalizedData?
    ) -> String {
        guard let localized, hasLocalizedDisplayValues(localized) else {
            return "酒店水单本地化：模型未返回可用 localized 字段，继续使用原始识别结果。"
        }
        let originalHotel = trimmed(original.hotelName) ?? "-"
        let localizedHotel = trimmed(localized.hotelName) ?? originalHotel
        let originalAmount = original.totalAmount.map(formatAmount) ?? "-"
        let localizedAmount = localized.totalAmount.map(formatAmount) ?? originalAmount
        let originalCurrency = trimmed(original.currency) ?? "-"
        let localizedCurrency = trimmed(localized.currency) ?? originalCurrency
        return "酒店水单本地化：\(originalHotel) -> \(localizedHotel) · \(originalCurrency) \(originalAmount) -> \(localizedCurrency) \(localizedAmount)"
    }

    private static func exchangeRateSummary(
        parsedPayload: HotelFolioParsedPayload,
        localized: HotelStayLocalizedData?
    ) -> String {
        guard let exchangeRate = localized?.exchangeRate else {
            let currency = trimmed(parsedPayload.currency) ?? "-"
            return "酒店水单汇率：未调用外部汇率 API，模型/水单未提供可靠汇率，保留原始币种 \(currency)。"
        }
        let provider = trimmed(localized?.exchangeRateProvider) ?? "folio_or_model"
        let date = trimmed(localized?.exchangeRateDate) ?? "-"
        let sourceCurrency = trimmed(parsedPayload.currency) ?? "-"
        let targetCurrency = trimmed(localized?.currency) ?? "-"
        return "酒店水单汇率：provider=\(provider) · date=\(date) · \(sourceCurrency)->\(targetCurrency) rate=\(formatAmount(exchangeRate))"
    }

    private static func exchangeRateInputJSON(
        parsedPayload: HotelFolioParsedPayload,
        localized: HotelStayLocalizedData?
    ) -> String {
        let sourceCurrency = trimmed(parsedPayload.currency) ?? ""
        let targetLocale = trimmed(localized?.targetLocaleIdentifier) ?? Locale.current.identifier
        let total = parsedPayload.totalAmount.map(formatAmount) ?? ""
        return """
        {
          "source_currency": "\(sourceCurrency)",
          "source_total_amount": "\(total)",
          "target_locale": "\(targetLocale)",
          "external_fx_api": "not_called",
          "accepted_fx_source": "folio_or_model_localized.exchange_rate"
        }
        """
    }

    private static func exchangeRateOutputJSON(
        parsedPayload: HotelFolioParsedPayload,
        localized: HotelStayLocalizedData?
    ) -> String {
        guard let localized, let exchangeRate = localized.exchangeRate else {
            let currency = trimmed(parsedPayload.currency) ?? ""
            return """
            {
              "status": "skipped",
              "reason": "no reliable exchange rate returned by folio/model",
              "currency": "\(currency)"
            }
            """
        }
        return """
        {
          "status": "provided_by_folio_or_model",
          "exchange_rate": "\(formatAmount(exchangeRate))",
          "exchange_rate_date": "\(localized.exchangeRateDate ?? "")",
          "exchange_rate_provider": "\(localized.exchangeRateProvider ?? "folio_or_model")",
          "localized_currency": "\(localized.currency ?? "")",
          "localized_total_amount": "\(localized.totalAmount.map(formatAmount) ?? "")"
        }
        """
    }

    private static func encoded<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private static func hasLocalizedDisplayValues(_ localized: HotelStayLocalizedData) -> Bool {
        [
            localized.hotelName,
            localized.brand,
            localized.group,
            localized.city,
            localized.country,
            localized.roomType,
            localized.roomNumber,
            localized.paymentMethod,
            localized.currency
        ]
        .contains { trimmed($0) != nil } ||
        localized.totalAmount != nil ||
        localized.exchangeRate != nil
    }

    private static func truncated(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > maxDebugTextCharacters else { return normalized }
        return String(normalized.prefix(maxDebugTextCharacters)) + "\n...[truncated]"
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func formatAmount(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.000_001 {
            return String(Int(rounded))
        }
        var formatted = String(format: "%.2f", value)
        while formatted.last == "0" {
            formatted.removeLast()
        }
        if formatted.last == "." {
            formatted.removeLast()
        }
        return formatted
    }
}
