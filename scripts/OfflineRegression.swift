import Foundation
import Darwin

final class RegressionReporter {
    private(set) var failures: [String] = []

    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            print("PASS: \(message)")
        } else {
            failures.append(message)
            print("FAIL: \(message)")
        }
    }

    func finish() -> Never {
        if failures.isEmpty {
            print("Offline regression passed.")
            exit(EXIT_SUCCESS)
        }

        print("Offline regression failed with \(failures.count) issue(s):")
        for failure in failures {
            print("- \(failure)")
        }
        exit(EXIT_FAILURE)
    }
}

@main
struct OfflineRegression {
    static func main() async throws {
        let reporter = RegressionReporter()
        let parser = ReceiptParser()
        let sampleProvider = SampleReceiptProvider()

        verifySampleParsing(using: parser, samples: sampleProvider.samples, reporter: reporter)
        verifyVoiceLedgerParsing(reporter: reporter)
        verifyStructuredLedgerJSONParsing(reporter: reporter)
        verifyHotelStayModels(reporter: reporter)
        verifyHotelFolioParsePipeline(reporter: reporter)
        verifyHotelStayReviewForm(reporter: reporter)
        verifyHotelStayLedgerPosting(reporter: reporter)
        verifyHotelStayArchivePresentation(reporter: reporter)
        verifyLedgerAmountInputParsing(reporter: reporter)
        verifyPaymentAmountExtraction(reporter: reporter)
        verifyMerchantExtraction(reporter: reporter)
        verifyCategoryResolution(reporter: reporter)
        verifyRecognitionLanguagePacks(reporter: reporter)
        verifySmartReceiptMergePolicy(reporter: reporter)
        verifyExternalReceiptAssistPayload(reporter: reporter)
        verifyExternalReceiptAssistGate(reporter: reporter)
        verifyExternalReceiptAssistProviderPresets(reporter: reporter)
        verifyExternalReceiptAssistOpenAICompatibleCodec(reporter: reporter)
        verifyExternalReceiptAssistCachePolicy(reporter: reporter)
        verifyExternalReceiptAssistSuggestionMapping(reporter: reporter)
        verifyLedgerTextInterpreterCore(reporter: reporter)
        await verifyLedgerTextInterpreterTransitShortcut(reporter: reporter)
        await verifyLedgerTextInterpreterSuppressesMultipleReceiptWarning(reporter: reporter)
        await verifyLedgerTextInterpreterUsesLocaleLanguagePack(reporter: reporter)
        verifyBatchImportQueue(reporter: reporter)
        verifyBatchImportRecognitionExecutor(reporter: reporter)
        verifyDataCleaningPreviewPlanner(reporter: reporter)
        verifySubscriptionDetection(reporter: reporter)
        verifySubscriptionStatusCodable(reporter: reporter)
        verifySubscriptionDraftFromTransaction(reporter: reporter)
        verifyTodaySpendingSummary(reporter: reporter)
        verifyMultiLedgerSchema(reporter: reporter)
        try verifyLedgerDefaultAssignment(reporter: reporter)
        try verifyLedgerProfileManagement(reporter: reporter)
        try verifyLedgerSelectionAndTransactionMoves(reporter: reporter)
        try verifyLedgerScopedSurfaces(reporter: reporter)
        verifySyncConflictResolver(reporter: reporter)
        verifyLedgerSyncPlanner(reporter: reporter)
        verifyLedgerConfigurationSyncPolicy(reporter: reporter)
        try verifySQLiteRoundTrip(reporter: reporter)
        try verifyHotelStaySQLitePersistence(reporter: reporter)
        try verifyLedgerStoreHotelStayPosting(reporter: reporter)
        try await verifyLedgerImportFlow(using: reporter)
        try verifyLedgerCSVCodec(reporter: reporter)
        try verifyBackupRoundTrip(reporter: reporter)

        reporter.finish()
    }

    private static var notificationMetroTransitText: String {
        """
        中国联通
        ：！！！39
        支
        6月16日周二・丙午年五月初二
        08:16
        消费成功通知
        你的储值消费成功，查看详情>>
        现在
        天津互联互通城市卡
        地铁：CN¥2.70
        示例站A→示例站B
        你的新余额为 CN¥31.80。
        现在
        示例动态内容
        示例用户
        关注
        展开
        说点什么…
        638
        42
        30
        """
    }

    private static func verifyVoiceLedgerParsing(reporter: RegressionReporter) {
        let fixedNow = AppFormatters.parseFlexibleDate("2026-04-26 12:00") ?? Date(timeIntervalSince1970: 0)
        let parser = VoiceLedgerParser(now: { fixedNow })

        let lunch = parser.parse("午饭 28")
        reporter.check(lunch.confidence == .high, "VoiceLedgerParser marks simple lunch as high confidence")
        reporter.check(lunch.merchant == "午饭", "VoiceLedgerParser extracts lunch merchant")
        reporter.check(abs((lunch.amount ?? 0) - 28) < 0.001, "VoiceLedgerParser extracts lunch amount")
        reporter.check(lunch.category == .dining, "VoiceLedgerParser infers dining category")

        let taxi = parser.parse("昨天打车 23.8")
        let expectedYesterday = AppFormatters.parseFlexibleDate("2026-04-25 12:00") ?? fixedNow
        reporter.check(taxi.confidence == .high, "VoiceLedgerParser marks taxi as high confidence")
        reporter.check(taxi.category == .transport, "VoiceLedgerParser infers transport category")
        reporter.check(sameMinute(taxi.occurredAt, expectedYesterday), "VoiceLedgerParser resolves yesterday")

        let multiAmount = parser.parse("今天花了 20 和 30")
        reporter.check(multiAmount.confidence == .failed, "VoiceLedgerParser rejects multiple amounts")
        reporter.check(multiAmount.failureReason == .multipleAmounts, "VoiceLedgerParser reports multiple amount reason")

        let income = parser.parse("收到报销 200")
        reporter.check(income.confidence == .failed, "VoiceLedgerParser rejects income/refund phrases")
        reporter.check(income.failureReason == .unsupportedIncomeOrTransfer, "VoiceLedgerParser reports income/transfer reason")

        let noAmount = parser.parse("午饭")
        reporter.check(noAmount.confidence == .failed, "VoiceLedgerParser rejects text without amount")
        reporter.check(noAmount.failureReason == .noAmount, "VoiceLedgerParser reports no amount reason")
    }

    private static func verifyStructuredLedgerJSONParsing(reporter: RegressionReporter) {
        let fixedNow = AppFormatters.parseFlexibleDate("2026-06-08 12:00") ?? Date(timeIntervalSince1970: 0)
        let parser = StructuredLedgerJSONParser(now: { fixedNow })

        let highConfidenceJSON = """
        {
          "amount": 18.8,
          "merchant": "Demo Coffee",
          "category": "dining",
          "date": "2026-06-08 09:30",
          "note": "latte",
          "currency": "cny",
          "confidence": 0.92
        }
        """
        let high = try? parser.parse(highConfidenceJSON)
        reporter.check(high?.decision == .autoSave, "StructuredLedgerJSONParser auto-saves high confidence JSON")
        reporter.check(high?.draft.merchant == "Demo Coffee", "StructuredLedgerJSONParser extracts merchant")
        reporter.check(abs((high?.draft.amount ?? 0) - 18.8) < 0.001, "StructuredLedgerJSONParser extracts amount")
        reporter.check(high?.draft.categoryLabel == "dining", "StructuredLedgerJSONParser preserves core category")
        reporter.check(high?.draft.currency == "CNY", "StructuredLedgerJSONParser normalizes currency")

        let reviewJSON = """
        {
          "金额": "47.50",
          "商户": "Example Market",
          "分类": "超市",
          "置信度": 72
        }
        """
        let review = try? parser.parse(reviewJSON)
        reporter.check(review?.decision == .needsConfirmation, "StructuredLedgerJSONParser routes medium confidence JSON to review")
        reporter.check(review?.draft.categoryLabel == "groceries", "StructuredLedgerJSONParser maps Chinese category alias")
        reporter.check(
            review.map { sameMinute($0.draft.occurredAt, fixedNow) } ?? false,
            "StructuredLedgerJSONParser falls back to now when date is missing"
        )

        do {
            _ = try parser.parse(#"{"amount": 12, "merchant": "Sample Store", "confidence": 0.2}"#)
            reporter.check(false, "StructuredLedgerJSONParser rejects low confidence JSON")
        } catch StructuredLedgerJSONError.lowConfidence(let confidence) {
            reporter.check(abs(confidence - 0.2) < 0.001, "StructuredLedgerJSONParser reports low confidence")
        } catch {
            reporter.check(false, "StructuredLedgerJSONParser reports the expected low-confidence error")
        }

        do {
            _ = try parser.parse(#"{"merchant": "Sample Store", "confidence": 0.9}"#)
            reporter.check(false, "StructuredLedgerJSONParser rejects missing amount")
        } catch StructuredLedgerJSONError.missingAmount {
            reporter.check(true, "StructuredLedgerJSONParser reports missing amount")
        } catch {
            reporter.check(false, "StructuredLedgerJSONParser reports the expected missing-amount error")
        }
    }

    private static func verifyHotelStayModels(reporter: RegressionReporter) {
        let json = """
        {
          "hotel_name": "Demo Bay Hotel",
          "brand": "Demo Suites",
          "group": "Demo Hospitality",
          "city": "Tokyo",
          "country": "Japan",
          "check_in_date": "2026-06-20",
          "check_out_date": "2026-06-22",
          "nights": 2,
          "room_type": "King Bay View",
          "confirmation_number": "ABC123",
          "currency": "JPY",
          "room_charge": 40000,
          "tax": 4000,
          "service_charge": 3000,
          "food_beverage": 2500,
          "other_charges": 500,
          "total_amount": 50000,
          "payment_method": "Visa",
          "confidence": 0.91,
          "raw_text_excerpt": "Demo folio excerpt"
        }
        """.data(using: .utf8) ?? Data()

        let decoder = JSONDecoder()
        let payload = try? decoder.decode(HotelFolioParsedPayload.self, from: json)
        reporter.check(payload?.hotelName == "Demo Bay Hotel", "HotelFolioParsedPayload decodes hotel_name")
        reporter.check(payload?.brand == "Demo Suites", "HotelFolioParsedPayload decodes brand")
        reporter.check(payload?.group == "Demo Hospitality", "HotelFolioParsedPayload decodes group")
        reporter.check(payload?.nights == 2, "HotelFolioParsedPayload decodes nights")
        reporter.check(abs((payload?.totalAmount ?? 0) - 50000) < 0.001, "HotelFolioParsedPayload decodes total_amount")

        let now = AppFormatters.parseFlexibleDate("2026-06-24 12:00") ?? Date(timeIntervalSince1970: 0)
        let draft = HotelStayDraft(
            sourceType: .manualPDF,
            targetLedgerID: TodaySpendingSummary.defaultLedgerID,
            sourceFileName: "demo-folio.pdf",
            sourceEmailSubject: nil,
            sourceEmailFrom: nil,
            rawText: "Demo folio raw text",
            parsedPayload: payload,
            confidence: payload?.confidence ?? 0,
            status: .needsReview,
            createdAt: now,
            updatedAt: now
        )
        reporter.check(draft.sourceType == .manualPDF, "HotelStayDraft records manual PDF source")
        reporter.check(draft.targetLedgerID == TodaySpendingSummary.defaultLedgerID, "HotelStayDraft records target ledger id")
        reporter.check(draft.status == .needsReview, "HotelStayDraft defaults to review workflow state")
        reporter.check(draft.parsedPayload?.confirmationNumber == "ABC123", "HotelStayDraft stores parsed payload")

        let record = HotelStayRecord(
            ledgerID: TodaySpendingSummary.defaultLedgerID,
            linkedTransactionID: UUID(uuidString: "00000000-0000-0000-0000-000000000181"),
            hotelName: payload?.hotelName ?? "",
            hotelGroup: payload?.group,
            hotelBrand: payload?.brand,
            city: payload?.city,
            country: payload?.country,
            checkInDate: payload?.checkInDate,
            checkOutDate: payload?.checkOutDate,
            nights: payload?.nights,
            roomType: payload?.roomType,
            confirmationNumber: payload?.confirmationNumber,
            currency: payload?.currency ?? "JPY",
            roomCharge: payload?.roomCharge ?? 0,
            taxAmount: payload?.tax ?? 0,
            serviceCharge: payload?.serviceCharge ?? 0,
            foodBeverageAmount: payload?.foodBeverage ?? 0,
            otherAmount: payload?.otherCharges ?? 0,
            totalAmount: payload?.totalAmount ?? 0,
            paymentMethod: payload?.paymentMethod,
            sourceType: .manualPDF,
            sourceFileName: draft.sourceFileName,
            confidence: draft.confidence,
            rawText: draft.rawText,
            createdAt: now,
            updatedAt: now
        )
        reporter.check(record.linkedTransactionID?.uuidString == "00000000-0000-0000-0000-000000000181", "HotelStayRecord can link a transaction id")
        reporter.check(record.hotelName == "Demo Bay Hotel", "HotelStayRecord records hotel name")
        reporter.check(record.currency == "JPY", "HotelStayRecord records currency")
        reporter.check(abs(record.totalAmount - 50000) < 0.001, "HotelStayRecord records total amount")
        reporter.check(record.sourceType == .manualPDF, "HotelStayRecord records source type")
    }

    private static func verifyHotelFolioParsePipeline(reporter: RegressionReporter) {
        let rawText = """
        Demo Bay Hotel
        Guest Email: traveler@example.com
        Phone: 13800138000
        Member No: GOLD123456789
        Card Number: 4111111111111111
        Confirmation: ABC123
        Check In: 2026-06-20
        Check Out: 2026-06-22
        Total Amount: JPY 50000
        """

        let builder = HotelFolioParsePayloadBuilder()
        let payload = builder.build(rawText: rawText, sourceType: .manualPDF)
        reporter.check(payload.sourceType == .manualPDF, "HotelFolioParsePayload records source type")
        reporter.check(payload.sanitizedText.contains("Demo Bay Hotel"), "HotelFolioParsePayload keeps hotel name")
        reporter.check(payload.sanitizedText.contains("Confirmation: ABC123"), "HotelFolioParsePayload keeps confirmation number")
        reporter.check(!payload.sanitizedText.contains("traveler@example.com"), "HotelFolioParsePayload redacts email")
        reporter.check(!payload.sanitizedText.contains("13800138000"), "HotelFolioParsePayload redacts phone")
        reporter.check(!payload.sanitizedText.contains("GOLD123456789"), "HotelFolioParsePayload redacts member number")
        reporter.check(!payload.sanitizedText.contains("4111111111111111"), "HotelFolioParsePayload redacts card number")
        reporter.check(payload.redactionCount >= 4, "HotelFolioParsePayload records redaction count")

        let codec = HotelFolioOpenAICompatibleCodec()
        let requestData = try? codec.makeRequestData(
            payload: payload,
            model: ExternalReceiptAssistProvider.deepSeek.defaultModel
        )
        let requestJSON = requestData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        reporter.check(requestJSON.contains("hotel_name"), "HotelFolioOpenAICompatibleCodec asks for hotel_name")
        reporter.check(requestJSON.contains("total_amount"), "HotelFolioOpenAICompatibleCodec asks for total_amount")
        reporter.check(requestJSON.contains("manualPDF"), "HotelFolioOpenAICompatibleCodec includes source type")
        reporter.check(!requestJSON.contains("traveler@example.com"), "HotelFolioOpenAICompatibleCodec avoids raw email")
        reporter.check(!requestJSON.contains("4111111111111111"), "HotelFolioOpenAICompatibleCodec avoids raw card number")

        let responseData = """
        {
          "choices": [
            {
              "message": {
                "content": "{\\"hotel_name\\":\\"Demo Bay Hotel\\",\\"brand\\":\\"Demo Suites\\",\\"group\\":\\"Demo Hospitality\\",\\"city\\":\\"Tokyo\\",\\"country\\":\\"Japan\\",\\"check_in_date\\":\\"2026-06-20\\",\\"check_out_date\\":\\"2026-06-22\\",\\"nights\\":2,\\"room_type\\":\\"King Bay View\\",\\"confirmation_number\\":\\"ABC123\\",\\"currency\\":\\"JPY\\",\\"room_charge\\":40000,\\"tax\\":4000,\\"service_charge\\":3000,\\"food_beverage\\":2500,\\"other_charges\\":500,\\"total_amount\\":50000,\\"payment_method\\":\\"Visa\\",\\"confidence\\":0.91,\\"raw_text_excerpt\\":\\"Demo folio excerpt\\"}"
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try? codec.decodeParsedPayload(from: responseData)
        reporter.check(decoded?.hotelName == "Demo Bay Hotel", "HotelFolioOpenAICompatibleCodec decodes chat completion payload")
        reporter.check(decoded?.confirmationNumber == "ABC123", "HotelFolioOpenAICompatibleCodec decodes confirmation number")
        reporter.check(abs((decoded?.totalAmount ?? 0) - 50000) < 0.001, "HotelFolioOpenAICompatibleCodec decodes total amount")

        let pipeline = HotelFolioParsePipeline(now: { Date(timeIntervalSince1970: 1_783_065_600) })
        let draft = HotelStayDraft(
            sourceType: .manualPDF,
            targetLedgerID: TodaySpendingSummary.defaultLedgerID,
            sourceFileName: "demo-folio.pdf",
            rawText: rawText,
            status: .textExtracted,
            createdAt: Date(timeIntervalSince1970: 1_783_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_783_000_000)
        )
        let parsedDraft = decoded.flatMap { try? pipeline.apply($0, to: draft) }
        reporter.check(parsedDraft?.status == .needsReview, "HotelFolioParsePipeline routes parsed folio to review")
        reporter.check(parsedDraft?.parsedPayload?.hotelName == "Demo Bay Hotel", "HotelFolioParsePipeline stores parsed payload")
        reporter.check(parsedDraft?.confidence == 0.91, "HotelFolioParsePipeline stores confidence")
        reporter.check(parsedDraft?.sourceType == .manualPDF, "HotelFolioParsePipeline preserves source type")
        reporter.check(parsedDraft?.rawText == rawText, "HotelFolioParsePipeline preserves raw text")
        reporter.check(parsedDraft?.updatedAt == Date(timeIntervalSince1970: 1_783_065_600), "HotelFolioParsePipeline refreshes updated timestamp")
    }

    private static func verifyHotelStayReviewForm(reporter: RegressionReporter) {
        let payload = HotelFolioParsedPayload(
            hotelName: "Demo Bay Hotel",
            brand: "Demo Suites",
            group: "Demo Hospitality",
            city: "Tokyo",
            country: "Japan",
            checkInDate: "2026-06-20",
            checkOutDate: "2026-06-22",
            nights: 2,
            roomType: "King Bay View",
            confirmationNumber: "ABC123",
            currency: "JPY",
            roomCharge: 40000,
            tax: 4000,
            serviceCharge: 3000,
            foodBeverage: 2500,
            otherCharges: 500,
            totalAmount: 50000,
            paymentMethod: "Visa",
            confidence: 0.91,
            rawTextExcerpt: "Demo folio excerpt"
        )
        let originalUpdatedAt = Date(timeIntervalSince1970: 1_783_000_000)
        let draft = HotelStayDraft(
            sourceType: .manualPDF,
            targetLedgerID: TodaySpendingSummary.defaultLedgerID,
            sourceFileName: "demo-folio.pdf",
            rawText: "Demo folio raw text",
            parsedPayload: payload,
            confidence: 0.91,
            status: .needsReview,
            createdAt: originalUpdatedAt,
            updatedAt: originalUpdatedAt
        )

        var form = HotelStayReviewForm(draft: draft)
        reporter.check(form.hotelName == "Demo Bay Hotel", "HotelStayReviewForm copies hotel name")
        reporter.check(form.totalAmountText == "50000", "HotelStayReviewForm formats total amount")
        reporter.check(form.amountBalanceStatus == .balanced, "HotelStayReviewForm detects balanced charges")
        reporter.check(form.isValid, "HotelStayReviewForm accepts complete required fields")

        form.totalAmountText = "49000"
        reporter.check(form.amountBalanceStatus == .imbalanced, "HotelStayReviewForm flags amount imbalance")
        reporter.check(abs(form.amountBalanceDelta + 1000) < 0.001, "HotelStayReviewForm reports amount balance delta")

        form.totalAmountText = "50000"
        form.hotelName = "Edited Demo Hotel"
        form.paymentMethod = "Amex"
        let confirmedAt = Date(timeIntervalSince1970: 1_783_065_600)
        let confirmedDraft = try? form.confirmedDraft(from: draft, updatedAt: confirmedAt)
        reporter.check(confirmedDraft?.status == .confirmed, "HotelStayReviewForm confirms draft")
        reporter.check(confirmedDraft?.parsedPayload?.hotelName == "Edited Demo Hotel", "HotelStayReviewForm writes edited hotel name")
        reporter.check(confirmedDraft?.parsedPayload?.paymentMethod == "Amex", "HotelStayReviewForm writes edited payment method")
        reporter.check(confirmedDraft?.updatedAt == confirmedAt, "HotelStayReviewForm refreshes confirmed timestamp")

        let rejectedAt = Date(timeIntervalSince1970: 1_783_071_600)
        let rejectedDraft = form.rejectedDraft(from: draft, updatedAt: rejectedAt)
        reporter.check(rejectedDraft.status == .rejected, "HotelStayReviewForm rejects draft")
        reporter.check(rejectedDraft.updatedAt == rejectedAt, "HotelStayReviewForm refreshes rejected timestamp")

        form.hotelName = "   "
        reporter.check(!form.isValid, "HotelStayReviewForm rejects missing hotel name")
        reporter.check((try? form.confirmedDraft(from: draft, updatedAt: confirmedAt)) == nil, "HotelStayReviewForm blocks invalid confirmation")
    }

    private static func verifyHotelStayLedgerPosting(reporter: RegressionReporter) {
        let legacyJSON = """
        {
          "id": "00000000-0000-0000-0000-000000001814",
          "merchant": "Legacy Coffee",
          "amount": 12.5,
          "occurredAt": "2026-06-24T00:00:00Z",
          "category": "dining",
          "source": "manual",
          "note": "legacy"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let legacyTransaction = try? decoder.decode(Transaction.self, from: legacyJSON)
        reporter.check(legacyTransaction?.hotelStayRecordID == nil, "Transaction decodes missing hotel stay link as nil")

        let payload = HotelFolioParsedPayload(
            hotelName: "Edited Demo Hotel",
            brand: "Demo Suites",
            group: "Demo Hospitality",
            city: "Tokyo",
            country: "Japan",
            checkInDate: "2026-06-20",
            checkOutDate: "2026-06-22",
            nights: 2,
            roomType: "King Bay View",
            confirmationNumber: "ABC123",
            currency: "JPY",
            roomCharge: 40000,
            tax: 4000,
            serviceCharge: 3000,
            foodBeverage: 2500,
            otherCharges: 500,
            totalAmount: 50000,
            paymentMethod: "Amex",
            confidence: 0.91,
            rawTextExcerpt: "Demo folio excerpt"
        )
        let draft = HotelStayDraft(
            sourceType: .manualPDF,
            targetLedgerID: TodaySpendingSummary.defaultLedgerID,
            sourceFileName: "demo-folio.pdf",
            rawText: "Demo folio raw text",
            parsedPayload: payload,
            confidence: 0.91,
            status: .confirmed,
            createdAt: Date(timeIntervalSince1970: 1_783_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_783_065_600)
        )
        let stayID = UUID(uuidString: "00000000-0000-0000-0000-000000001815")!
        let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000001816")!
        let postedAt = Date(timeIntervalSince1970: 1_783_071_600)
        let service = HotelStayLedgerPostingService(
            now: { postedAt },
            hotelStayIDGenerator: { stayID },
            transactionIDGenerator: { transactionID }
        )
        let result = try? service.post(draft)

        reporter.check(result?.draft.status == .postedToLedger, "HotelStayLedgerPostingService marks draft posted")
        reporter.check(result?.draft.updatedAt == postedAt, "HotelStayLedgerPostingService refreshes posted draft timestamp")
        reporter.check(result?.hotelStayRecord.id == stayID, "HotelStayLedgerPostingService uses supplied hotel stay id")
        reporter.check(result?.hotelStayRecord.linkedTransactionID == transactionID, "HotelStayRecord links generated transaction")
        reporter.check(result?.hotelStayRecord.ledgerID == TodaySpendingSummary.defaultLedgerID, "HotelStayRecord keeps target ledger id")
        reporter.check(result?.hotelStayRecord.hotelName == "Edited Demo Hotel", "HotelStayRecord receives confirmed hotel name")
        reporter.check(result?.hotelStayRecord.hotelBrand == "Demo Suites", "HotelStayRecord receives hotel brand")
        reporter.check(result?.hotelStayRecord.hotelGroup == "Demo Hospitality", "HotelStayRecord receives hotel group")
        reporter.check(abs((result?.hotelStayRecord.totalAmount ?? 0) - 50000) < 0.001, "HotelStayRecord receives total amount")
        reporter.check(result?.transaction.id == transactionID, "HotelStayLedgerPostingService uses supplied transaction id")
        reporter.check(result?.transaction.hotelStayRecordID == stayID, "Transaction links generated hotel stay record")
        reporter.check(result?.transaction.ledgerID == TodaySpendingSummary.defaultLedgerID, "Hotel transaction keeps target ledger id")
        reporter.check(result?.transaction.merchant == "Edited Demo Hotel", "Hotel transaction uses hotel name as merchant")
        reporter.check(abs((result?.transaction.amount ?? 0) - 50000) < 0.001, "Hotel transaction uses folio total amount")
        reporter.check(result?.transaction.category == "酒店住宿", "Hotel transaction uses accommodation category label")
        reporter.check(result?.transaction.source == ReceiptSource.manual.rawValue, "Hotel transaction uses manual source")
        reporter.check(
            result?.transaction.occurredAt == AppFormatters.parseFlexibleDate("2026-06-22"),
            "Hotel transaction uses checkout date"
        )
        reporter.check(result?.transaction.note.contains("2026-06-20") == true, "Hotel transaction note includes check-in date")
        reporter.check(result?.transaction.note.contains("2026-06-22") == true, "Hotel transaction note includes check-out date")
        reporter.check(result?.transaction.note.contains("King Bay View") == true, "Hotel transaction note includes room type")
        reporter.check(result?.transaction.note.contains("ABC123") == true, "Hotel transaction note includes confirmation number")

        let unconfirmedDraft = HotelStayDraft(
            sourceType: .manualPDF,
            parsedPayload: payload,
            confidence: 0.91,
            status: .needsReview
        )
        reporter.check((try? service.post(unconfirmedDraft)) == nil, "HotelStayLedgerPostingService rejects unconfirmed draft")
    }

    private static func verifyHotelStayArchivePresentation(reporter: RegressionReporter) {
        let tokyoStayID = UUID(uuidString: "00000000-0000-0000-0000-000000001820")!
        let tokyoTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000001821")!
        let osakaStayID = UUID(uuidString: "00000000-0000-0000-0000-000000001822")!
        let tokyoStay = HotelStayRecord(
            id: tokyoStayID,
            ledgerID: TodaySpendingSummary.defaultLedgerID,
            linkedTransactionID: tokyoTransactionID,
            hotelName: "Demo Bay Hotel",
            hotelGroup: "Demo Hospitality",
            hotelBrand: "Demo Suites",
            city: "Tokyo",
            country: "Japan",
            checkInDate: "2026-06-20",
            checkOutDate: "2026-06-22",
            nights: 2,
            roomType: "King Bay View",
            confirmationNumber: "ABC123",
            currency: "JPY",
            roomCharge: 40000,
            taxAmount: 4000,
            serviceCharge: 3000,
            foodBeverageAmount: 2500,
            otherAmount: 500,
            totalAmount: 50000,
            paymentMethod: "Amex",
            sourceType: .manualPDF,
            sourceFileName: "demo-folio.pdf",
            confidence: 0.91,
            rawText: "Demo folio raw text",
            createdAt: Date(timeIntervalSince1970: 1_783_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_783_071_600)
        )
        let osakaStay = HotelStayRecord(
            id: osakaStayID,
            ledgerID: TodaySpendingSummary.defaultLedgerID,
            linkedTransactionID: nil,
            hotelName: "Sample Garden Hotel",
            hotelGroup: nil,
            hotelBrand: nil,
            city: "Osaka",
            country: "Japan",
            checkInDate: "2026-05-01",
            checkOutDate: "2026-05-02",
            nights: 1,
            roomType: nil,
            confirmationNumber: nil,
            currency: "JPY",
            roomCharge: 11000,
            taxAmount: 1000,
            serviceCharge: 0,
            foodBeverageAmount: 0,
            otherAmount: 0,
            totalAmount: 12000,
            paymentMethod: nil,
            sourceType: .cloudWorker,
            sourceFileName: nil,
            confidence: 0.8,
            rawText: "",
            createdAt: Date(timeIntervalSince1970: 1_779_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_779_000_000)
        )
        let linkedTransaction = Transaction(
            id: tokyoTransactionID,
            merchant: "Demo Bay Hotel",
            amount: 50000,
            occurredAt: AppFormatters.parseFlexibleDate("2026-06-22") ?? .now,
            categoryLabel: "酒店住宿",
            sourceLabel: ReceiptSource.manual.rawValue,
            note: "入住：2026-06-20；退房：2026-06-22",
            hotelStayRecordID: tokyoStayID
        )

        let presenter = HotelStayArchivePresenter()
        let list = presenter.makeListSnapshot(records: [osakaStay, tokyoStay])
        reporter.check(list.rows.map(\.id) == [tokyoStayID, osakaStayID], "HotelStayArchivePresenter sorts rows by checkout date descending")
        reporter.check(list.totalNights == 3, "HotelStayArchivePresenter totals nights")
        reporter.check(abs(list.totalAmount - 62000) < 0.001, "HotelStayArchivePresenter totals amount")
        reporter.check(abs((list.averageNightlyRate ?? 0) - (62000.0 / 3.0)) < 0.001, "HotelStayArchivePresenter computes average nightly rate")
        reporter.check(list.rows.first?.locationText == "Tokyo, Japan", "HotelStayListRow formats location")
        reporter.check(list.rows.first?.brandGroupText == "Demo Suites / Demo Hospitality", "HotelStayListRow formats brand and group")
        reporter.check(list.rows.first?.dateRangeText == "2026-06-20 - 2026-06-22", "HotelStayListRow formats stay date range")
        reporter.check(list.rows.first?.nightsText == "2", "HotelStayListRow formats nights")
        reporter.check(list.rows.first?.totalAmountText == "JPY 50000", "HotelStayListRow formats amount with currency")
        reporter.check(list.rows.first?.linkStatus == .postedToLedger, "HotelStayListRow marks linked stays as posted")
        reporter.check(list.rows.last?.linkStatus == .missingTransaction, "HotelStayListRow marks missing linked transaction")

        let detail = presenter.makeDetailSnapshot(record: tokyoStay, transactions: [linkedTransaction])
        reporter.check(detail.row.id == tokyoStayID, "HotelStayDetailSnapshot exposes list row")
        reporter.check(detail.linkedTransaction?.id == tokyoTransactionID, "HotelStayDetailSnapshot resolves linked transaction")
        reporter.check(detail.rawText == "Demo folio raw text", "HotelStayDetailSnapshot keeps raw text")
        reporter.check(detail.chargeFields.first { $0.key == .roomCharge }?.value == "JPY 40000", "HotelStayDetailSnapshot includes room charge")
        reporter.check(detail.chargeFields.first { $0.key == .taxAmount }?.value == "JPY 4000", "HotelStayDetailSnapshot includes tax amount")
        reporter.check(detail.sourceFields.first { $0.key == .sourceFileName }?.value == "demo-folio.pdf", "HotelStayDetailSnapshot includes source file")
        reporter.check(detail.sourceFields.first { $0.key == .confidence }?.value == "91%", "HotelStayDetailSnapshot formats confidence")

        let missingLinkDetail = presenter.makeDetailSnapshot(record: osakaStay, transactions: [linkedTransaction])
        reporter.check(missingLinkDetail.linkedTransaction == nil, "HotelStayDetailSnapshot leaves missing linked transaction nil")
        reporter.check(missingLinkDetail.row.linkStatus == .missingTransaction, "HotelStayDetailSnapshot carries missing transaction status")
    }

    private static func verifyLedgerAmountInputParsing(reporter: RegressionReporter) {
        reporter.check(
            abs((LedgerAmountInputParser.parse("¥12.30") ?? 0) - 12.30) < 0.001,
            "LedgerAmountInputParser accepts currency-prefixed amount"
        )
        reporter.check(
            abs((LedgerAmountInputParser.parse("１２．３０") ?? 0) - 12.30) < 0.001,
            "LedgerAmountInputParser accepts full-width amount"
        )
        reporter.check(
            abs((LedgerAmountInputParser.parse("12,30") ?? 0) - 12.30) < 0.001,
            "LedgerAmountInputParser accepts comma decimal amount"
        )
        reporter.check(
            abs((LedgerAmountInputParser.parse(" 12.30 元") ?? 0) - 12.30) < 0.001,
            "LedgerAmountInputParser accepts amount with unit suffix"
        )
        reporter.check(
            LedgerAmountInputParser.parse("abc") == nil,
            "LedgerAmountInputParser rejects non-amount text"
        )
    }

    private static func verifyPaymentAmountExtraction(reporter: RegressionReporter) {
        let extractor = PaymentAmountExtractor()

        let paymentResult = extractor.extract(from: """
        支付宝
        交易成功
        商户：Demo Coffee
        支付金额：23.80
        """)
        reporter.check(
            abs((paymentResult.paidAmount ?? 0) - 23.80) < 0.001,
            "PaymentAmountExtractor extracts labeled payment amount"
        )
        reporter.check(paymentResult.confidence >= 0.9, "PaymentAmountExtractor marks labeled payment amount reliable")

        let rmResult = extractor.extract(from: """
        MR D.I.Y. (JOHOR) SDN BHD
        Item(s): 4
        TOTAL RM 30.90
        CASH RM 50.00
        CHANGE RM 19.10
        """)
        reporter.check(
            abs((rmResult.paidAmount ?? 0) - 30.90) < 0.01,
            "PaymentAmountExtractor prefers TOTAL RM over cash/change lines"
        )
        reporter.check(
            rmResult.selectedCandidate?.role == .total,
            "PaymentAmountExtractor classifies TOTAL RM as total candidate"
        )

        let fallbackResult = extractor.extract(from: """
        Example Market
        item 2.00
        8.08
        """)
        reporter.check(
            abs((fallbackResult.paidAmount ?? 0) - 8.08) < 0.01,
            "PaymentAmountExtractor falls back to last amount when no total label exists"
        )
        reporter.check(fallbackResult.isApproximate, "PaymentAmountExtractor flags unlabeled fallback as approximate")

        let japaneseResult = PaymentAmountExtractor(localeIdentifier: "ja-JP").extract(from: """
        領収書
        店舗: Demo Cafe
        小計 ¥980
        消費税 ¥100
        合計 ¥1,080
        支払方法 カード
        """)
        reporter.check(
            abs((japaneseResult.paidAmount ?? 0) - 1080) < 0.01,
            "PaymentAmountExtractor uses Japanese pack to parse thousands total"
        )
        reporter.check(
            japaneseResult.selectedCandidate?.role == .total,
            "PaymentAmountExtractor classifies Japanese 合計 as total"
        )
    }

    private static func verifyMerchantExtraction(reporter: RegressionReporter) {
        let extractor = RuleMerchantExtractor()
        let resolver = MerchantResolver()

        let labeledText = """
        支付宝
        交易成功
        商户：Demo Coffee
        支付金额：23.80
        """
        let labeledCandidates = extractor.extractCandidates(from: labeledText)
        let labeledResult = resolver.resolve(candidates: labeledCandidates, text: labeledText)
        reporter.check(labeledResult.merchant == "Demo Coffee", "MerchantResolver prefers labeled merchant")

        let japaneseLabeledText = """
        領収書
        店舗: Demo Cafe
        合計 ¥1,080
        注文番号: ABC-123
        """
        let japaneseExtractor = RuleMerchantExtractor(localeIdentifier: "ja-JP")
        let japaneseCandidates = japaneseExtractor.extractCandidates(from: japaneseLabeledText)
        let japaneseResult = resolver.resolve(candidates: japaneseCandidates, text: japaneseLabeledText)
        reporter.check(
            japaneseResult.merchant == "Demo Cafe",
            "MerchantResolver uses Japanese merchant labels from language pack"
        )
        reporter.check(
            !japaneseCandidates.contains { $0.name.localizedCaseInsensitiveContains("注文番号") },
            "MerchantResolver excludes Japanese non-merchant identifier labels from language pack"
        )

        let blacklistHeader = """
        TAX INVOICE
        SOON HUAT MACHINERY ENTERPRISE
        NO.53 JALAN PUTRA 1
        REPAIR ENGINE 1 X 80.00
        Total Sales: RM 327.00
        """
        let headerResult = resolver.resolve(candidates: extractor.extractCandidates(from: blacklistHeader), text: blacklistHeader)
        reporter.check(
            headerResult.merchant == "SOON HUAT MACHINERY ENTERPRISE",
            "MerchantResolver excludes invoice header noise"
        )

        let paymentChannelNoise = """
        微信支付
        支付成功
        商品说明
        Example Market
        付款金额
        ¥18.80
        """
        let paymentResult = resolver.resolve(candidates: extractor.extractCandidates(from: paymentChannelNoise), text: paymentChannelNoise)
        reporter.check(paymentResult.merchant == "Example Market", "MerchantResolver avoids payment channel as merchant")

        let discountNoisePaymentText = """
        08:18
        回首页
        支付成功
        ¥14.32
        获得森林能量
        易择便利（陈塘科创园店）
        碰友日立减
        付款方式
        ¥15.50
        -¥1.18
        光大银行信用卡（1234）
        最高88元点餐红包 限量发放
        """
        let discountNoiseResult = resolver.resolve(
            candidates: extractor.extractCandidates(from: discountNoisePaymentText),
            text: discountNoisePaymentText
        )
        reporter.check(
            discountNoiseResult.merchant == "易择便利（陈塘科创园店）",
            "MerchantResolver prefers store-like merchant over discount campaign text"
        )
    }

    private static func verifyCategoryResolution(reporter: RegressionReporter) {
        let resolver = CategoryResolver()

        reporter.check(resolver.resolve(text: "McDonald's BHP Taman Melawati") == .dining, "CategoryResolver maps known dining merchant")
        reporter.check(resolver.resolve(text: "NTUC FAIRPRICE") == .groceries, "CategoryResolver maps known grocery merchant")
        reporter.check(resolver.resolve(text: "滴滴出行") == .transport, "CategoryResolver maps known transport merchant")
        reporter.check(resolver.resolve(text: "OpenAI ChatGPT") == .digital, "CategoryResolver maps known digital merchant")

        let japaneseResolver = CategoryResolver(localeIdentifier: "ja-JP")
        reporter.check(
            japaneseResolver.resolve(text: "東京カフェ") == .dining,
            "CategoryResolver maps Japanese カフェ keyword from language pack"
        )
        reporter.check(
            japaneseResolver.resolve(text: "駅前コンビニ") == .groceries,
            "CategoryResolver maps Japanese コンビニ keyword from language pack"
        )
    }

    private static func verifyRecognitionLanguagePacks(reporter: RegressionReporter) {
        let packSet = LedgerRecognitionLanguagePackSet.builtIn
        let japaneseChain = packSet.packs(for: "ja-JP")

        reporter.check(japaneseChain.first?.id == "ja", "RecognitionLanguagePackSet selects Japanese pack for ja-JP")
        reporter.check(japaneseChain.map(\.id).contains("en"), "RecognitionLanguagePackSet keeps English fallback for Japanese pack")
        reporter.check(
            japaneseChain.first?.billKeywords.contains("領収書") == true,
            "Japanese recognition pack contains receipt keyword"
        )

        let japaneseReceipt = """
        領収書
        店舗: Demo Cafe
        合計 ¥1,080
        支払方法 カード
        """
        let builtInGate = BillRelevanceGate(languagePackSet: packSet)
        let japaneseRelevance = builtInGate.evaluate(japaneseReceipt, localeIdentifier: "ja-JP")
        reporter.check(japaneseRelevance.isRelevant, "BillRelevanceGate accepts Japanese receipt via language pack")
        reporter.check(
            japaneseRelevance.positiveSignals.contains("payment_or_receipt_keyword"),
            "BillRelevanceGate records language-pack receipt keyword signal"
        )

        let communityPack = LedgerRecognitionLanguagePack(
            id: "x-community",
            schemaVersion: 1,
            packVersion: "0.1.0",
            localeIdentifiers: ["x-community"],
            billKeywords: ["ticketstub"],
            paymentKeywords: [],
            amountLabels: [],
            totalLabels: [],
            discountLabels: [],
            taxLabels: [],
            dateLabels: [],
            merchantLabels: [],
            nonMerchantKeywords: [],
            categoryKeywordMap: ["ticketstub": .entertainment],
            provenance: .reviewedCommunity
        )
        let communityGate = BillRelevanceGate(languagePackSet: LedgerRecognitionLanguagePackSet(packs: [communityPack]))
        let communityRelevance = communityGate.evaluate("ticketstub $3.25", localeIdentifier: "x-community")
        reporter.check(communityRelevance.isRelevant, "BillRelevanceGate accepts reviewed community language pack keywords")
    }

    private static func verifySmartReceiptMergePolicy(reporter: RegressionReporter) {
        let occurredAt = AppFormatters.parseFlexibleDate("2026-06-11 09:30") ?? Date(timeIntervalSince1970: 0)
        let ruleReceipt = ImportedReceipt(
            source: .alipay,
            merchant: "Rule Merchant",
            amount: 23.80,
            occurredAt: occurredAt,
            rawText: "支付金额 23.80",
            summary: "规则解析",
            confidence: 0.86,
            suggestedCategory: .transport
        )
        let aiSuggestion = ReceiptAISuggestion(
            merchant: "AI Merchant",
            amount: 999.00,
            occurredAt: nil,
            confidence: 0.96,
            needsUserConfirmation: false,
            suggestedCategory: .dining
        )

        let merged = SmartReceiptMergePolicy().merge(
            aiSuggestion: aiSuggestion,
            ruleReceipt: ruleReceipt,
            source: .alipay,
            rawText: "支付金额 23.80"
        )

        reporter.check(abs((merged?.receipt.amount ?? 0) - 23.80) < 0.001, "SmartReceiptMergePolicy keeps rule amount over AI amount")
        reporter.check(merged?.receipt.merchant == "AI Merchant", "SmartReceiptMergePolicy allows AI merchant enrichment")
        reporter.check(merged?.receipt.suggestedCategory == .dining, "SmartReceiptMergePolicy allows AI category enrichment")
        reporter.check(merged?.usedRuleAmount == true, "SmartReceiptMergePolicy records rule amount usage")
    }

    private static func verifyExternalReceiptAssistPayload(reporter: RegressionReporter) {
        let rawText = """
        Demo Coffee
        支付金额 23.80
        订单号 202606111234567890
        商户单号 MERCHANT-ORDER-202606111234
        付款银行卡 尾号 4321
        手机号 13800138000
        地址 天津市和平区Example Road 88号
        样本文件 X510123456789
        """

        let payload = ExternalReceiptAssistPayloadBuilder().build(
            rawText: rawText,
            source: .alipay
        )

        reporter.check(payload.sanitizedText.contains("Demo Coffee"), "ExternalReceiptAssistPayload keeps merchant candidate text")
        reporter.check(payload.sanitizedText.contains("23.80"), "ExternalReceiptAssistPayload keeps short payment amount context")
        reporter.check(!payload.sanitizedText.contains("202606111234567890"), "ExternalReceiptAssistPayload redacts order-like long numbers")
        reporter.check(!payload.sanitizedText.contains("MERCHANT-ORDER-202606111234"), "ExternalReceiptAssistPayload redacts merchant order identifiers")
        reporter.check(!payload.sanitizedText.contains("4321"), "ExternalReceiptAssistPayload redacts card tail numbers")
        reporter.check(!payload.sanitizedText.contains("13800138000"), "ExternalReceiptAssistPayload redacts phone-like numbers")
        reporter.check(!payload.sanitizedText.contains("天津市和平区Example Road 88号"), "ExternalReceiptAssistPayload redacts address-like lines")
        reporter.check(!payload.sanitizedText.contains("X510123456789"), "ExternalReceiptAssistPayload redacts sample file identifiers")
        reporter.check(payload.redactionCount >= 6, "ExternalReceiptAssistPayload records redaction count")

        let longText = String(repeating: "Demo Coffee 支付成功 23.80\n", count: 80)
        let cappedPayload = ExternalReceiptAssistPayloadBuilder().build(rawText: longText, source: .alipay)
        reporter.check(cappedPayload.sanitizedText.count <= 800, "ExternalReceiptAssistPayload defaults to compact 800-character cap")
    }

    private static func verifyExternalReceiptAssistGate(reporter: RegressionReporter) {
        let gate = ExternalReceiptAssistGate()
        let payload = ExternalReceiptAssistPayload(
            source: .alipay,
            sanitizedText: "Demo Coffee\n支付金额 23.80",
            redactionCount: 1
        )

        let disabled = gate.evaluate(
            configuration: ExternalReceiptAssistConfiguration(
                isEnabled: false,
                endpointURLString: "https://api.example.com/receipt-assist",
                hasAPIKey: true
            ),
            payload: payload
        )
        reporter.check(!disabled.canRequest, "ExternalReceiptAssistGate defaults disabled")
        reporter.check(disabled.reason == .disabled, "ExternalReceiptAssistGate reports disabled reason")

        let missingKey = gate.evaluate(
            configuration: ExternalReceiptAssistConfiguration(
                isEnabled: true,
                endpointURLString: "https://api.example.com/receipt-assist",
                hasAPIKey: false
            ),
            payload: payload
        )
        reporter.check(!missingKey.canRequest, "ExternalReceiptAssistGate blocks missing API key")
        reporter.check(missingKey.reason == .missingAPIKey, "ExternalReceiptAssistGate reports missing API key")

        let invalidEndpoint = gate.evaluate(
            configuration: ExternalReceiptAssistConfiguration(
                isEnabled: true,
                endpointURLString: "not a url",
                hasAPIKey: true
            ),
            payload: payload
        )
        reporter.check(!invalidEndpoint.canRequest, "ExternalReceiptAssistGate blocks invalid endpoint")
        reporter.check(invalidEndpoint.reason == .invalidEndpoint, "ExternalReceiptAssistGate reports invalid endpoint")

        let allowed = gate.evaluate(
            configuration: ExternalReceiptAssistConfiguration(
                isEnabled: true,
                endpointURLString: "https://api.example.com/receipt-assist",
                hasAPIKey: true
            ),
            payload: payload
        )
        reporter.check(allowed.canRequest, "ExternalReceiptAssistGate allows complete enabled config")
        reporter.check(allowed.reason == nil, "ExternalReceiptAssistGate has no failure reason when allowed")
    }

    private static func verifyExternalReceiptAssistProviderPresets(reporter: RegressionReporter) {
        reporter.check(
            ExternalReceiptAssistProvider.deepSeek.defaultEndpointURLString == "https://api.deepseek.com/chat/completions",
            "ExternalReceiptAssistProvider provides DeepSeek chat completions endpoint"
        )
        reporter.check(
            ExternalReceiptAssistProvider.qwen.defaultEndpointURLString?.contains("dashscope.aliyuncs.com/compatible-mode/v1/chat/completions") == true,
            "ExternalReceiptAssistProvider provides Qwen OpenAI-compatible endpoint"
        )
        reporter.check(
            ExternalReceiptAssistProvider.openAI.defaultEndpointURLString == "https://api.openai.com/v1/chat/completions",
            "ExternalReceiptAssistProvider provides OpenAI chat completions endpoint"
        )
        reporter.check(
            ExternalReceiptAssistProvider.deepSeek.defaultModel == "deepseek-v4-flash",
            "ExternalReceiptAssistProvider uses current DeepSeek V4 Flash model"
        )
    }

    private static func verifyExternalReceiptAssistOpenAICompatibleCodec(reporter: RegressionReporter) {
        let payload = ExternalReceiptAssistPayload(
            source: .alipay,
            sanitizedText: "支付成功\nDemo Coffee\n支付金额 23.80",
            redactionCount: 0
        )
        let codec = ExternalReceiptAssistOpenAICompatibleCodec()
        let requestData = try? codec.makeRequestData(
            payload: payload,
            model: ExternalReceiptAssistProvider.deepSeek.defaultModel
        )
        let requestJSON = requestData.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        reporter.check(requestJSON.contains("\"model\""), "ExternalReceiptAssistOpenAICompatibleCodec includes model")
        reporter.check(requestJSON.contains("merchantCandidates"), "ExternalReceiptAssistOpenAICompatibleCodec asks for merchant candidates")
        reporter.check(requestJSON.contains("subscriptionHint"), "ExternalReceiptAssistOpenAICompatibleCodec asks for subscription hint")
        reporter.check(!requestJSON.contains("explanation"), "ExternalReceiptAssistOpenAICompatibleCodec does not request explanation by default")
        reporter.check(requestJSON.contains("Demo Coffee"), "ExternalReceiptAssistOpenAICompatibleCodec includes sanitized text")
        reporter.check(!requestJSON.contains("raw OCR"), "ExternalReceiptAssistOpenAICompatibleCodec avoids raw OCR wording")

        let responseData = """
        {
          "choices": [
            {
              "message": {
                "content": "{\\"merchantCandidates\\":[\\"Demo Coffee\\",\\"Example Market\\"],\\"categoryHint\\":\\"dining\\",\\"confidence\\":0.84,\\"subscriptionHint\\":{\\"isSubscription\\":true,\\"serviceName\\":\\"Demo Coffee Pro\\",\\"billingCycle\\":\\"monthly\\",\\"confidence\\":0.91},\\"explanation\\":\\"merchant is closest to payment amount\\"}"
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try? codec.decodeSuggestion(from: responseData)
        reporter.check(decoded?.merchantCandidates.first == "Demo Coffee", "ExternalReceiptAssistOpenAICompatibleCodec decodes chat completion content")
        reporter.check(decoded?.categoryHint == "dining", "ExternalReceiptAssistOpenAICompatibleCodec decodes category hint")
        reporter.check(decoded?.confidence == 0.84, "ExternalReceiptAssistOpenAICompatibleCodec decodes confidence")
        reporter.check(decoded?.subscriptionHint?.isSubscription == true, "ExternalReceiptAssistOpenAICompatibleCodec decodes subscription hint")
        reporter.check(decoded?.subscriptionHint?.serviceName == "Demo Coffee Pro", "ExternalReceiptAssistOpenAICompatibleCodec decodes subscription service name")
        reporter.check(decoded?.subscriptionHint?.billingCycle == "monthly", "ExternalReceiptAssistOpenAICompatibleCodec decodes subscription billing cycle")
        reporter.check(decoded?.subscriptionHint?.confidence == 0.91, "ExternalReceiptAssistOpenAICompatibleCodec decodes subscription confidence")

        let snakeData = """
        {"merchant_candidates":["Demo Cloud"],"category_hint":"digital","confidence":0.9,"subscription_hint":{"is_subscription":true,"service_name":"Demo Cloud","billing_cycle":"monthly","confidence":0.88}}
        """.data(using: .utf8)!
        let snakeDecoded = try? codec.decodeSuggestion(from: snakeData)
        reporter.check(snakeDecoded?.merchantCandidates.first == "Demo Cloud", "ExternalReceiptAssistOpenAICompatibleCodec decodes snake case merchants")
        reporter.check(snakeDecoded?.subscriptionHint?.serviceName == "Demo Cloud", "ExternalReceiptAssistOpenAICompatibleCodec decodes snake case subscription hint")
    }

    private static func verifyExternalReceiptAssistCachePolicy(reporter: RegressionReporter) {
        let policy = ExternalReceiptAssistCachePolicy()
        let payload = ExternalReceiptAssistPayload(
            source: .alipay,
            sanitizedText: "支付成功\nDemo Coffee\n支付金额 23.80",
            redactionCount: 0
        )
        let configuration = ExternalReceiptAssistConfiguration(
            isEnabled: true,
            endpointURLString: "https://api.deepseek.com/chat/completions",
            hasAPIKey: true,
            provider: .deepSeek,
            modelName: "deepseek-v4-flash"
        )
        let key = policy.makeCacheKey(
            payload: payload,
            configuration: configuration,
            sanitizedTextHash: "hash-demo-001",
            endpointFingerprint: "endpoint-hash-001"
        )
        reporter.check(!key.contains("Demo Coffee"), "ExternalReceiptAssistCachePolicy key never embeds sanitized OCR text")
        reporter.check(key.contains("hash-demo-001"), "ExternalReceiptAssistCachePolicy key uses supplied sanitized hash")

        let otherModelKey = policy.makeCacheKey(
            payload: payload,
            configuration: ExternalReceiptAssistConfiguration(
                isEnabled: true,
                endpointURLString: "https://api.deepseek.com/chat/completions",
                hasAPIKey: true,
                provider: .deepSeek,
                modelName: "qwen-plus"
            ),
            sanitizedTextHash: "hash-demo-001",
            endpointFingerprint: "endpoint-hash-001"
        )
        reporter.check(key != otherModelKey, "ExternalReceiptAssistCachePolicy isolates provider model changes")

        let otherEndpointKey = policy.makeCacheKey(
            payload: payload,
            configuration: configuration,
            sanitizedTextHash: "hash-demo-001",
            endpointFingerprint: "endpoint-hash-002"
        )
        reporter.check(key != otherEndpointKey, "ExternalReceiptAssistCachePolicy isolates endpoint changes")

        let otherSourceKey = policy.makeCacheKey(
            payload: ExternalReceiptAssistPayload(
                source: .wechat,
                sanitizedText: payload.sanitizedText,
                redactionCount: payload.redactionCount
            ),
            configuration: configuration,
            sanitizedTextHash: "hash-demo-001",
            endpointFingerprint: "endpoint-hash-001"
        )
        reporter.check(key != otherSourceKey, "ExternalReceiptAssistCachePolicy isolates receipt source changes")

        let suggestion = ExternalReceiptAssistSuggestion(
            merchantCandidates: ["Demo Coffee"],
            categoryHint: "dining",
            explanation: nil,
            confidence: 0.88,
            subscriptionHint: ExternalReceiptAssistSubscriptionHint(
                isSubscription: false,
                serviceName: nil,
                billingCycle: nil,
                confidence: 0.12
            )
        )
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let record = policy.makeRecord(
            suggestion: suggestion,
            cacheKey: key,
            payload: payload,
            configuration: configuration,
            endpointFingerprint: "endpoint-hash-001",
            createdAt: now,
            ttl: 60
        )
        reporter.check(record.expiresAt == now.addingTimeInterval(60), "ExternalReceiptAssistCachePolicy records TTL expiry")
        reporter.check(
            policy.usableSuggestion(from: record, expectedCacheKey: key, now: now.addingTimeInterval(30)) == suggestion,
            "ExternalReceiptAssistCachePolicy returns live cached suggestion"
        )
        reporter.check(
            policy.usableSuggestion(from: record, expectedCacheKey: key, now: now.addingTimeInterval(61)) == nil,
            "ExternalReceiptAssistCachePolicy rejects expired cached suggestion"
        )
        reporter.check(
            policy.usableSuggestion(from: record, expectedCacheKey: otherModelKey, now: now.addingTimeInterval(30)) == nil,
            "ExternalReceiptAssistCachePolicy rejects mismatched cache key"
        )

        let expired = policy.makeRecord(
            suggestion: suggestion,
            cacheKey: "expired",
            payload: payload,
            configuration: configuration,
            endpointFingerprint: "endpoint-hash-001",
            createdAt: now.addingTimeInterval(-120),
            ttl: 30
        )
        let pruned = policy.pruned([key: record, "expired": expired], now: now)
        reporter.check(pruned[key] == record, "ExternalReceiptAssistCachePolicy keeps live records while pruning")
        reporter.check(pruned["expired"] == nil, "ExternalReceiptAssistCachePolicy prunes expired records")
    }

    private static func verifyExternalReceiptAssistSuggestionMapping(reporter: RegressionReporter) {
        let suggestion = ExternalReceiptAssistSuggestion(
            merchantCandidates: ["", "Demo Coffee", "Example Market"],
            categoryHint: "dining",
            explanation: "merchant appears near payment context",
            confidence: 0.82
        )
        let mapped = ExternalReceiptAssistSuggestionMapper().makeAISuggestion(from: suggestion)

        reporter.check(mapped?.merchant == "Demo Coffee", "ExternalReceiptAssistSuggestionMapper picks first non-empty merchant candidate")
        reporter.check(mapped?.amount == 0, "ExternalReceiptAssistSuggestionMapper never supplies amount")
        reporter.check(mapped?.suggestedCategory == .dining, "ExternalReceiptAssistSuggestionMapper maps category hint")
        reporter.check(mapped?.needsUserConfirmation == false, "ExternalReceiptAssistSuggestionMapper accepts high confidence suggestion")

        let empty = ExternalReceiptAssistSuggestion(
            merchantCandidates: ["", "   "],
            categoryHint: nil,
            explanation: nil,
            confidence: 0.9
        )
        reporter.check(
            ExternalReceiptAssistSuggestionMapper().makeAISuggestion(from: empty) == nil,
            "ExternalReceiptAssistSuggestionMapper rejects empty merchant candidates"
        )
    }

    private static func verifyLedgerTextInterpreterCore(reporter: RegressionReporter) {
        let gate = BillRelevanceGate()
        let billText = """
        支付宝
        交易成功
        商户：测试咖啡
        金额：￥12.50
        """
        let billResult = gate.evaluate(billText, sourceHint: .payment)
        reporter.check(billResult.isRelevant, "BillRelevanceGate accepts payment-like OCR text")

        let nonBillText = """
        今天风很大
        记得下班后买牛奶
        """
        let nonBillResult = gate.evaluate(nonBillText)
        reporter.check(!nonBillResult.isRelevant, "BillRelevanceGate rejects unrelated text")

        let interpreter = LedgerTextInterpreterCore()
        let nonBillInterpretation = interpreter.interpret(
            InterpretInput(rawText: nonBillText, sourceType: .ocr)
        )
        reporter.check(nonBillInterpretation.draft == nil, "LedgerTextInterpreterCore does not draft non-bill image text")
        reporter.check(nonBillInterpretation.warnings.contains(.nonBillImage), "LedgerTextInterpreterCore reports nonBillImage")

        let voiceInterpretation = interpreter.interpret(
            InterpretInput(rawText: "午饭 28 元", sourceType: .voice)
        )
        reporter.check(voiceInterpretation.draft?.merchant == "午饭", "LedgerTextInterpreterCore drafts voice merchant")
        reporter.check(abs((voiceInterpretation.draft?.amount ?? 0) - 28) < 0.001, "LedgerTextInterpreterCore drafts voice amount")

        let noisyAmountText = """
        支付宝
        交易成功
        1
        数量 1
        商户：测试咖啡
        支付金额：23.80
        """
        let noisyAmountInterpretation = interpreter.interpret(
            InterpretInput(
                rawText: noisyAmountText,
                sourceType: .ocr,
                hints: LedgerInterpretHints(sourceHint: .payment)
            )
        )
        reporter.check(
            abs((noisyAmountInterpretation.draft?.amount ?? 0) - 23.80) < 0.001,
            "LedgerTextInterpreterCore ignores OCR list/quantity numbers before amount"
        )

        let metroTransitText = """
        08:15
        天津互联互通城市卡
        地铁：CN¥2.70
        示例站A→示例站B
        你的新余额为CN¥39.90。
        •共274人推荐＞
        • 示例城市｜示例体育场
        @示例用户・5月10日
        #示例话题 #示例比赛 #示例球队#var 裁判评议
        Q相关搜索•示例裁判说话原声
        留下你的友善评论吧
        61
        现在
        1.0万
        1170
        728
        3384
        SAMPLE-CODE-001
        938
        """
        let metroTransitResult = interpreter.interpret(
            InterpretInput(
                rawText: metroTransitText,
                sourceType: .ocr,
                hints: LedgerInterpretHints(sourceHint: .payment)
            )
        )
        reporter.check(
            metroTransitResult.draft?.merchant == "地铁：示例站A→示例站B",
            "LedgerTextInterpreterCore prefers metro route over city card and social feed noise (got '\(metroTransitResult.draft?.merchant ?? "")')"
        )
        reporter.check(
            abs((metroTransitResult.draft?.amount ?? 0) - 2.70) < 0.001,
            "LedgerTextInterpreterCore extracts metro fare amount from inline CN¥ row"
        )
        reporter.check(
            metroTransitResult.draft?.category == TransactionCategory.transport.rawValue,
            "LedgerTextInterpreterCore infers transport category for metro route"
        )

        let notificationMetroResult = interpreter.interpret(
            InterpretInput(
                rawText: notificationMetroTransitText,
                sourceType: .ocr,
                hints: LedgerInterpretHints(sourceHint: .payment)
            )
        )
        reporter.check(
            notificationMetroResult.draft?.merchant == "地铁：示例站A→示例站B",
            "LedgerTextInterpreterCore extracts metro route from notification-center stored-value text"
        )
        reporter.check(
            abs((notificationMetroResult.draft?.amount ?? 0) - 2.70) < 0.001,
            "LedgerTextInterpreterCore extracts metro fare from notification-center stored-value text"
        )

        // Phase 1: Amount extraction - RM receipts with registration numbers
        let rmReceiptRegNumber = """
        MR D.I.Y. (JOHOR) SDN BHD
        (CO.REG:860671-D)
        LOT 1851-A, JALAN KPB 6
        KAWASAN PERINDUSTRIAN BALAKONG
        CHOPPING BOARD 35.5×25.5CM 1 X 19.00
        AIR PRESSURE SPRAYER 1.5L 1 X 8.02
        BOPP TAPE 48MM*100M CLEAR 1 X 3.88
        Item(s): 4
        TOTAL RM 30.90
        CASH RM 50.00
        CHANGE RM 19.10
        """
        let rmResult = interpreter.interpret(
            InterpretInput(rawText: rmReceiptRegNumber, sourceType: .ocr, hints: LedgerInterpretHints(sourceHint: .receipt))
        )
        reporter.check(
            abs((rmResult.draft?.amount ?? 0) - 30.90) < 0.01,
            "LedgerTextInterpreterCore extracts TOTAL RM 30.90 from MR DIY receipt, not registration number 860671 (got \(rmResult.draft?.amount ?? -1))"
        )
        reporter.check(
            rmResult.draft?.merchant == "MR D.I.Y. (JOHOR) SDN BHD",
            "LedgerTextInterpreterCore extracts merchant from MR DIY receipt (got '\(rmResult.draft?.merchant ?? "")')"
        )

        // Phase 1: Amount extraction - TOTAL line priority
        let multiItemTotal = """
        NTUC FAIRPRICE
        FRESH MILK 2.00
        BREAD 3.20
        TOTAL £8.08
        """
        let multiTotalResult = interpreter.interpret(
            InterpretInput(rawText: multiItemTotal, sourceType: .ocr, hints: LedgerInterpretHints(sourceHint: .receipt))
        )
        reporter.check(
            abs((multiTotalResult.draft?.amount ?? 0) - 8.08) < 0.01,
            "LedgerTextInterpreterCore extracts TOTAL line amount £8.08, not item prices (got \(multiTotalResult.draft?.amount ?? -1))"
        )

        // Phase 1: Amount extraction - Jumlah (Malay) total keyword
        let malayReceipt = """
        PERNIAGAAN ZHENG HUI
        NO.59 JALAN PERMAS 9/5
        BANDAR BARU PERMAS JAYA
        GST ID: SAMPLE-GST-001
        Silicone Gun G-D2 1 X 16.00
        XTRASEAL RIVACETIC 3 X 7.00
        Total Qty: 9
        Total (RM): 112.45
        CASH: 112.45
        """
        let malayResult = interpreter.interpret(
            InterpretInput(rawText: malayReceipt, sourceType: .ocr, hints: LedgerInterpretHints(sourceHint: .receipt))
        )
        reporter.check(
            abs((malayResult.draft?.amount ?? 0) - 112.45) < 0.01,
            "LedgerTextInterpreterCore extracts Total (RM): 112.45 with RM prefix (got \(malayResult.draft?.amount ?? -1))"
        )

        let japaneseReceipt = """
        領収書
        店舗: Demo Cafe
        小計 ¥980
        消費税 ¥100
        合計 ¥1,080
        支払方法 カード
        """
        let japaneseResult = interpreter.interpret(
            InterpretInput(
                rawText: japaneseReceipt,
                sourceType: .ocr,
                localeIdentifier: "ja-JP",
                hints: LedgerInterpretHints(sourceHint: .receipt)
            )
        )
        reporter.check(
            abs((japaneseResult.draft?.amount ?? 0) - 1080) < 0.01,
            "LedgerTextInterpreterCore extracts Japanese 合計 ¥1,080 using language pack (got \(japaneseResult.draft?.amount ?? -1))"
        )
        reporter.check(
            japaneseResult.draft?.merchant == "Demo Cafe",
            "LedgerTextInterpreterCore extracts Japanese 店舗 merchant using language pack (got '\(japaneseResult.draft?.merchant ?? "")')"
        )

        let japaneseCafeReceipt = """
        領収書
        店舗: 東京カフェ
        合計 ¥1,080
        支払方法 カード
        """
        let japaneseCafeResult = interpreter.interpret(
            InterpretInput(
                rawText: japaneseCafeReceipt,
                sourceType: .ocr,
                localeIdentifier: "ja-JP",
                hints: LedgerInterpretHints(sourceHint: .receipt)
            )
        )
        reporter.check(
            japaneseCafeResult.draft?.category == TransactionCategory.dining.rawValue,
            "LedgerTextInterpreterCore infers Japanese カフェ category using language pack (got '\(japaneseCafeResult.draft?.category ?? "")')"
        )

        // Phase 2: Merchant extraction excludes blacklisted headers
        let blacklistHeader = """
        tan woon yann
        INDAH GIFT & HOME DECO
        27, JALAN DEDAP 13
        TAMAN JOHOR JAYA
        81100 JOHOR BAHRU, JOHOR
        ST-PRIVILEGE CARD/SD INDAH 1 X 10.00
        GF-TABLE LAMP/STITCH 1 X 55.90
        TOTAL AMT. RM 60.30
        CASH RM 70.00
        CHANGE RM 9.70
        """
        let blacklistResult = interpreter.interpret(
            InterpretInput(rawText: blacklistHeader, sourceType: .ocr, hints: LedgerInterpretHints(sourceHint: .receipt))
        )
        reporter.check(
            blacklistResult.draft?.merchant == "INDAH GIFT & HOME DECO",
            "LedgerTextInterpreterCore picks INDAH GIFT as merchant, not 'tan woon yann' header (got '\(blacklistResult.draft?.merchant ?? "")')"
        )

        // Phase 2: Merchant extraction excludes INVOICE/RECEIPT headers
        let invoiceHeader = """
        TAX INVOICE
        SOON HUAT MACHINERY ENTERPRISE
        NO.53 JALAN PUTRA 1
        TAMAN SRI PUTRA
        81200 JOHOR BAHRU
        REPAIR ENGINE 1 X 80.00
        ENGINE OIL 1 X 17.00
        Total Sales: RM 327.00
        """
        let invoiceResult = interpreter.interpret(
            InterpretInput(rawText: invoiceHeader, sourceType: .ocr, hints: LedgerInterpretHints(sourceHint: .receipt))
        )
        reporter.check(
            invoiceResult.draft?.merchant == "SOON HUAT MACHINERY ENTERPRISE",
            "LedgerTextInterpreterCore picks SOON HUAT as merchant, not 'TAX INVOICE' header (got '\(invoiceResult.draft?.merchant ?? "")')"
        )

        // Phase 3: Category inference for known merchants
        let merchantCategoryText = """
        McDonald's BHP Taman Melawati
        2 ChicMcMuffin 11.00
        1 M Porridge 5.60
        TOTAL 26.60
        """
        let mcDResult = interpreter.interpret(
            InterpretInput(rawText: merchantCategoryText, sourceType: .ocr, hints: LedgerInterpretHints(sourceHint: .receipt))
        )
        reporter.check(
            mcDResult.draft?.category == "dining",
            "LedgerTextInterpreterCore infers dining category for McDonald's receipt (got '\(mcDResult.draft?.category ?? "")')"
        )
    }

    private static func verifySubscriptionDetection(reporter: RegressionReporter) {
        let detector = SubscriptionDetector()
        let base = AppFormatters.parseFlexibleDate("2026-01-05 09:00") ?? .now
        let calendar = Calendar(identifier: .gregorian)

        func date(monthOffset: Int) -> Date {
            calendar.date(byAdding: .month, value: monthOffset, to: base) ?? base
        }

        let transactions = [
            Transaction(
                merchant: "Apple Services",
                amount: 28,
                occurredAt: date(monthOffset: 0),
                category: .digital,
                source: .appStore,
                note: "订阅"
            ),
            Transaction(
                merchant: "Apple Services",
                amount: 28,
                occurredAt: date(monthOffset: 1),
                category: .digital,
                source: .appStore,
                note: "订阅"
            ),
            Transaction(
                merchant: "Demo Burger",
                amount: 19.9,
                occurredAt: date(monthOffset: 0),
                category: .dining,
                source: .alipay,
                note: "午餐"
            ),
            Transaction(
                merchant: "Demo Burger",
                amount: 19.9,
                occurredAt: date(monthOffset: 1),
                category: .dining,
                source: .alipay,
                note: "午餐"
            ),
            Transaction(
                merchant: "地铁：ExampleStationA → ExampleStationB",
                amount: 2.7,
                occurredAt: date(monthOffset: 0),
                category: .transport,
                source: .manual,
                note: "地铁"
            ),
            Transaction(
                merchant: "地铁：ExampleStationA → ExampleStationB",
                amount: 2.7,
                occurredAt: date(monthOffset: 1),
                category: .transport,
                source: .manual,
                note: "地铁"
            )
        ]

        let detected = detector.detectFromHistory(transactions)
        reporter.check(detected.contains { $0.merchant == "Apple Services" }, "SubscriptionDetector scans digital service subscriptions")
        reporter.check(!detected.contains { $0.merchant == "Demo Burger" }, "SubscriptionDetector excludes dining transactions")
        reporter.check(!detected.contains { $0.merchant.contains("地铁") }, "SubscriptionDetector excludes transport transactions")
    }

    private static func verifySubscriptionStatusCodable(reporter: RegressionReporter) {
        let legacyJSON = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "merchant": "Legacy Music",
          "planName": "Monthly",
          "period": "monthly",
          "amount": 18.0,
          "lastChargedAt": 1772326800,
          "nextChargedAt": 1775005200,
          "createdAt": 1772326800
        }
        """.data(using: .utf8)!

        do {
            let decoded = try JSONDecoder().decode(Subscription.self, from: legacyJSON)
            reporter.check(decoded.status == .active, "Subscription status decodes legacy backups as active")
        } catch {
            reporter.check(false, "Subscription status decodes legacy backups without throwing")
        }

        let paused = Subscription(
            merchant: "Demo Cloud",
            planName: "Pro",
            period: .monthly,
            amount: 28,
            lastChargedAt: AppFormatters.parseFlexibleDate("2026-04-01 09:00") ?? .now,
            status: .paused
        )
        do {
            let data = try JSONEncoder().encode(paused)
            let decoded = try JSONDecoder().decode(Subscription.self, from: data)
            reporter.check(decoded.status == .paused, "Subscription status round-trips through Codable")
        } catch {
            reporter.check(false, "Subscription status round-trips through Codable without throwing")
        }
    }

    private static func verifySubscriptionDraftFromTransaction(reporter: RegressionReporter) {
        let chargedAt = AppFormatters.parseFlexibleDate("2026-05-01 08:30") ?? .now
        let transaction = Transaction(
            merchant: "Demo Cloud",
            amount: 28.0,
            occurredAt: chargedAt,
            category: .digital,
            source: .manual,
            note: "手动确认订阅"
        )

        let draft = Subscription.draft(from: transaction)
        reporter.check(draft.merchant == transaction.merchant, "Subscription draft uses transaction merchant")
        reporter.check(abs(draft.amount - transaction.amount) < 0.001, "Subscription draft uses transaction amount")
        reporter.check(draft.period == .monthly, "Subscription draft defaults to monthly period")
        reporter.check(draft.status == .active, "Subscription draft defaults to active status")
        reporter.check(sameMinute(draft.lastChargedAt, chargedAt), "Subscription draft uses transaction date as last charge")
        reporter.check(
            sameMinute(draft.nextChargedAt, SubscriptionPeriod.monthly.nextDate(from: chargedAt)),
            "Subscription draft computes next monthly charge"
        )
    }

    private static func verifyTodaySpendingSummary(reporter: RegressionReporter) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current

        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )) ?? Date(timeIntervalSince1970: 0)
        }

        let referenceDate = date(2026, 6, 1, 12, 0)
        let coffee = Transaction(
            merchant: "Demo Coffee",
            amount: 18.50,
            occurredAt: date(2026, 6, 1, 9, 30),
            category: .dining,
            source: .alipay,
            note: "today coffee"
        )
        let market = Transaction(
            merchant: "Example Market",
            amount: 30.00,
            occurredAt: date(2026, 6, 1, 20, 15),
            category: .groceries,
            source: .wechat,
            note: "today market"
        )
        let customCategory = Transaction(
            merchant: "Sample Store",
            amount: 12.34,
            occurredAt: date(2026, 6, 1, 11, 0),
            categoryLabel: "宠物",
            sourceLabel: "家庭账本",
            note: "custom category/source"
        )
        let yesterday = Transaction(
            merchant: "Yesterday Store",
            amount: 100,
            occurredAt: date(2026, 5, 31, 23, 59),
            category: .shopping,
            source: .manual,
            note: "yesterday"
        )
        let zeroAmount = Transaction(
            merchant: "Zero Amount",
            amount: 0,
            occurredAt: date(2026, 6, 1, 13, 0),
            category: .other,
            source: .manual,
            note: "zero"
        )
        let negativeAmount = Transaction(
            merchant: "Refund",
            amount: -5,
            occurredAt: date(2026, 6, 1, 14, 0),
            category: .other,
            source: .manual,
            note: "negative"
        )
        let deletedOutsideActiveInput = Transaction(
            merchant: "Deleted Store",
            amount: 99,
            occurredAt: date(2026, 6, 1, 15, 0),
            category: .shopping,
            source: .manual,
            note: "deleted"
        )

        let summary = TodaySpendingSummary.build(
            from: [yesterday, coffee, zeroAmount, customCategory, negativeAmount, market],
            referenceDate: referenceDate,
            calendar: calendar
        )

        reporter.check(summary.ledgerID == TodaySpendingSummary.defaultLedgerID, "TodaySpendingSummary uses default ledger id")
        reporter.check(summary.ledgerName == TodaySpendingSummary.defaultLedgerName, "TodaySpendingSummary uses default ledger name")
        reporter.check(summary.transactionCount == 3, "TodaySpendingSummary includes today's positive active expenses only")
        reporter.check(abs(summary.totalExpense - 60.84) < 0.001, "TodaySpendingSummary totals today's positive expenses")
        reporter.check(summary.recentTransaction?.id == market.id, "TodaySpendingSummary picks latest occurredAt transaction as recent")
        reporter.check(summary.recentDisplayName == "Example Market", "TodaySpendingSummary exposes recent merchant display name")
        reporter.check(!summary.isEmpty, "TodaySpendingSummary non-empty state is false when today has expenses")

        let activeOnlySummary = TodaySpendingSummary.build(
            from: [coffee],
            referenceDate: referenceDate,
            calendar: calendar
        )
        reporter.check(
            abs(activeOnlySummary.totalExpense - deletedOutsideActiveInput.amount) > 0.001 &&
            activeOnlySummary.transactionCount == 1,
            "TodaySpendingSummary excludes deleted transactions by active input contract"
        )

        let emptySummary = TodaySpendingSummary.build(
            from: [yesterday, zeroAmount, negativeAmount],
            referenceDate: referenceDate,
            calendar: calendar
        )
        reporter.check(emptySummary.isEmpty, "TodaySpendingSummary reports empty state when no valid today expenses exist")
        reporter.check(emptySummary.totalExpense == 0, "TodaySpendingSummary empty total is zero")
        reporter.check(emptySummary.recentTransaction == nil, "TodaySpendingSummary empty recent transaction is nil")

        let dayStart = Transaction(
            merchant: "Day Start",
            amount: 1,
            occurredAt: date(2026, 6, 1, 0, 0),
            category: .other,
            source: .manual,
            note: "start included"
        )
        let nextDayStart = Transaction(
            merchant: "Next Day Start",
            amount: 2,
            occurredAt: date(2026, 6, 2, 0, 0),
            category: .other,
            source: .manual,
            note: "end excluded"
        )
        let boundarySummary = TodaySpendingSummary.build(
            from: [dayStart, nextDayStart],
            referenceDate: referenceDate,
            calendar: calendar
        )
        reporter.check(boundarySummary.transactionCount == 1, "TodaySpendingSummary uses [localStartOfDay, nextLocalStartOfDay) boundary")
        reporter.check(boundarySummary.recentTransaction?.id == dayStart.id, "TodaySpendingSummary includes local day start")

        let fallbackDisplay = Transaction(
            merchant: "   ",
            amount: 8,
            occurredAt: date(2026, 6, 1, 16, 0),
            categoryLabel: "交通",
            sourceLabel: "快捷指令",
            note: "fallback display"
        )
        let fallbackSummary = TodaySpendingSummary.build(
            from: [fallbackDisplay],
            referenceDate: referenceDate,
            calendar: calendar
        )
        reporter.check(fallbackSummary.recentDisplayName == "交通", "TodaySpendingSummary falls back to category when merchant is blank")
    }

    private static func verifyMultiLedgerSchema(reporter: RegressionReporter) {
        let createdAt = Date(timeIntervalSince1970: 1_780_300_000)
        let updatedAt = Date(timeIntervalSince1970: 1_780_300_600)
        let archivedAt = Date(timeIntervalSince1970: 1_780_301_200)
        let travelLedgerID = "travel-ledger"

        let defaultLedger = LedgerProfile.defaultLocal(createdAt: createdAt)
        reporter.check(defaultLedger.id == TodaySpendingSummary.defaultLedgerID, "LedgerProfile default id matches summary default")
        reporter.check(defaultLedger.name == TodaySpendingSummary.defaultLedgerName, "LedgerProfile default name matches summary default")
        reporter.check(defaultLedger.isDefault, "LedgerProfile default ledger is marked default")
        reporter.check(!defaultLedger.isArchived, "LedgerProfile default ledger starts active")

        let travelLedger = LedgerProfile(
            id: travelLedgerID,
            name: "Travel",
            iconName: "airplane",
            colorName: "teal",
            currency: "JPY",
            isDefault: false,
            sortOrder: 10,
            archivedAt: archivedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        reporter.check(travelLedger.id == travelLedgerID, "LedgerProfile records custom ledger id")
        reporter.check(travelLedger.currency == "JPY", "LedgerProfile records default currency")
        reporter.check(travelLedger.isArchived, "LedgerProfile reports archived state")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedLedger: LedgerProfile? = {
            guard let data = try? encoder.encode(travelLedger) else { return nil }
            return try? decoder.decode(LedgerProfile.self, from: data)
        }()
        reporter.check(decodedLedger == travelLedger, "LedgerProfile round-trips through JSON")

        let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000001840") ?? UUID()
        let transaction = Transaction(
            id: transactionID,
            merchant: "Travel Hotel",
            amount: 888,
            occurredAt: createdAt,
            category: .dining,
            source: .manual,
            note: "multi ledger",
            ledgerID: travelLedgerID
        )
        reporter.check(transaction.ledgerID == travelLedgerID, "Transaction records ledger id")

        let legacyTransactionJSON = """
        {
          "id": "00000000-0000-0000-0000-000000001841",
          "merchant": "Legacy Ledger Store",
          "amount": 12.5,
          "occurredAt": "2026-04-24T08:30:00Z",
          "category": "shopping",
          "source": "manual",
          "note": "legacy transaction",
          "hotelStayRecordID": null
        }
        """.data(using: .utf8) ?? Data()
        let legacyTransaction = try? decoder.decode(Transaction.self, from: legacyTransactionJSON)
        reporter.check(legacyTransaction?.ledgerID == nil, "Transaction decodes missing ledger id as nil")

        let backup = BackupTransaction(transaction: transaction)
        reporter.check(backup.ledgerID == travelLedgerID, "BackupTransaction preserves ledger id")
        reporter.check(backup.transaction.ledgerID == travelLedgerID, "BackupTransaction restores transaction ledger id")

        let payload = LedgerTransactionSyncPayload(
            record: TransactionSyncRecord(
                transaction: transaction,
                metadata: TransactionSyncMetadata(
                    transactionID: transactionID,
                    updatedAt: updatedAt,
                    syncRevision: 2,
                    deviceID: "local-device",
                    idempotencyKey: "transaction:\(transactionID.uuidString)"
                )
            )
        )
        reporter.check(payload.ledgerID == travelLedgerID, "LedgerTransactionSyncPayload preserves ledger id")
        reporter.check(payload.syncRecord.transaction.ledgerID == travelLedgerID, "LedgerTransactionSyncPayload restores transaction ledger id")
    }

    private static func verifyLedgerDefaultAssignment(reporter: RegressionReporter) throws {
        let date = Date(timeIntervalSince1970: 1_780_400_000)
        let hotelStayRecordID = UUID(uuidString: "00000000-0000-0000-0000-000000001842") ?? UUID()
        let legacyTransaction = Transaction(
            merchant: "Legacy Default Store",
            amount: 18,
            occurredAt: date,
            category: .shopping,
            source: .manual,
            note: "legacy nil ledger",
            hotelStayRecordID: hotelStayRecordID
        )
        reporter.check(
            legacyTransaction.resolvedLedgerID() == TodaySpendingSummary.defaultLedgerID,
            "Transaction resolves missing ledger id to default ledger"
        )

        let assigned = legacyTransaction.assigningLedgerIDIfMissing()
        reporter.check(assigned.ledgerID == TodaySpendingSummary.defaultLedgerID, "Transaction assigns default ledger when missing")
        reporter.check(assigned.hotelStayRecordID == hotelStayRecordID, "Transaction default ledger assignment preserves hotel link")

        let customLedger = legacyTransaction.assigningLedgerIDIfMissing("travel-ledger")
        reporter.check(customLedger.ledgerID == "travel-ledger", "Transaction can assign a supplied default ledger")

        let existingLedger = Transaction(
            id: legacyTransaction.id,
            merchant: legacyTransaction.merchant,
            amount: legacyTransaction.amount,
            occurredAt: legacyTransaction.occurredAt,
            category: .shopping,
            source: .manual,
            note: legacyTransaction.note,
            ledgerID: "travel-ledger",
            hotelStayRecordID: hotelStayRecordID
        )
        reporter.check(
            existingLedger.assigningLedgerIDIfMissing().ledgerID == "travel-ledger",
            "Transaction keeps existing ledger id during default assignment"
        )

        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerDefaultLedgerRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let store = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger-default.sqlite3")
        let ledger = LedgerStore(transactionStore: store)
        let manual = Transaction(
            merchant: "Manual Default Store",
            amount: 21,
            occurredAt: date,
            category: .dining,
            source: .manual,
            note: "manual default"
        )
        reporter.check(ledger.addTransaction(manual), "LedgerStore accepts manual transaction for default ledger assignment")
        let storedManual = try store.loadTransactions().first { $0.id == manual.id }
        reporter.check(
            storedManual?.ledgerID == TodaySpendingSummary.defaultLedgerID,
            "LedgerStore writes default ledger id for new manual transaction"
        )

        let travel = Transaction(
            merchant: "Travel Existing Store",
            amount: 33,
            occurredAt: date,
            category: .shopping,
            source: .manual,
            note: "travel ledger",
            ledgerID: "travel-ledger"
        )
        reporter.check(ledger.addTransaction(travel), "LedgerStore accepts transaction with existing ledger id")
        let travelEditWithoutLedger = Transaction(
            id: travel.id,
            merchant: "Travel Existing Store Edited",
            amount: travel.amount,
            occurredAt: travel.occurredAt,
            category: .shopping,
            source: .manual,
            note: "travel ledger edited"
        )
        reporter.check(ledger.updateTransaction(travelEditWithoutLedger), "LedgerStore updates transaction while preserving ledger assignment")
        let storedTravel = try store.loadTransactions().first { $0.id == travel.id }
        reporter.check(
            storedTravel?.ledgerID == "travel-ledger",
            "LedgerStore preserves existing ledger id when update payload omits it"
        )
    }

    private static func verifyLedgerProfileManagement(reporter: RegressionReporter) throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerProfileManagementRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let store = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger-profiles.sqlite3")
        let bootstrapped = try store.loadLedgerProfiles()
        reporter.check(bootstrapped.count == 1, "SQLite ledger profile store bootstraps one default ledger")
        reporter.check(bootstrapped.first?.id == TodaySpendingSummary.defaultLedgerID, "SQLite ledger profile store bootstraps default ledger id")
        reporter.check(bootstrapped.first?.isDefault == true, "SQLite ledger profile store marks bootstrap ledger as default")

        let createdAt = Date(timeIntervalSince1970: 1_780_500_000)
        let updatedAt = Date(timeIntervalSince1970: 1_780_500_600)
        let archivedAt = Date(timeIntervalSince1970: 1_780_501_200)
        let travelLedger = LedgerProfile(
            id: "travel-ledger",
            name: "Travel",
            iconName: "airplane",
            colorName: "teal",
            currency: "JPY",
            isDefault: false,
            sortOrder: 10,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        try store.saveLedgerProfile(travelLedger)
        let withTravel = try store.loadLedgerProfiles()
        reporter.check(withTravel.map(\.id) == [TodaySpendingSummary.defaultLedgerID, "travel-ledger"], "SQLite ledger profile store orders ledgers by sort order")
        reporter.check(withTravel.last?.currency == "JPY", "SQLite ledger profile store persists ledger currency")

        try store.renameLedgerProfile(id: travelLedger.id, name: "Trip Wallet", updatedAt: updatedAt)
        let renamed = try store.loadLedgerProfiles().first { $0.id == travelLedger.id }
        reporter.check(renamed?.name == "Trip Wallet", "SQLite ledger profile store renames custom ledger")
        reporter.check(renamed?.updatedAt == updatedAt, "SQLite ledger profile store records rename timestamp")

        try store.setDefaultLedgerProfile(id: travelLedger.id, updatedAt: updatedAt)
        let defaultSwitched = try store.loadLedgerProfiles()
        reporter.check(defaultSwitched.filter(\.isDefault).map(\.id) == [travelLedger.id], "SQLite ledger profile store keeps one default ledger")

        try store.setDefaultLedgerProfile(id: TodaySpendingSummary.defaultLedgerID, updatedAt: updatedAt)
        try store.archiveLedgerProfile(id: travelLedger.id, archivedAt: archivedAt)
        let activeOnly = try store.loadLedgerProfiles(includeArchived: false)
        let withArchived = try store.loadLedgerProfiles(includeArchived: true)
        reporter.check(activeOnly.map(\.id) == [TodaySpendingSummary.defaultLedgerID], "SQLite ledger profile store hides archived ledgers from active listing")
        reporter.check(withArchived.first { $0.id == travelLedger.id }?.archivedAt == archivedAt, "SQLite ledger profile store persists archive timestamp")

        let uiStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger-profiles-ui.sqlite3")
        let ledgerStore = LedgerStore(transactionStore: uiStore)
        reporter.check(ledgerStore.ledgerProfiles.map(\.id) == [TodaySpendingSummary.defaultLedgerID], "LedgerStore exposes bootstrapped ledger profiles")

        let createdLedger = ledgerStore.createLedgerProfile(name: "Travel", iconName: "airplane", colorName: "teal", currency: "JPY")
        reporter.check(createdLedger?.name == "Travel", "LedgerStore creates a custom ledger profile")
        reporter.check(ledgerStore.ledgerProfiles.contains { $0.id == createdLedger?.id }, "LedgerStore publishes created ledger profile")

        if let createdLedger {
            ledgerStore.renameLedgerProfile(createdLedger, name: "Trip Wallet")
            reporter.check(
                ledgerStore.ledgerProfiles.first { $0.id == createdLedger.id }?.name == "Trip Wallet",
                "LedgerStore renames custom ledger profile"
            )

            ledgerStore.setDefaultLedgerProfile(createdLedger)
            reporter.check(
                ledgerStore.ledgerProfiles.filter(\.isDefault).map(\.id) == [createdLedger.id],
                "LedgerStore switches default ledger profile"
            )

            ledgerStore.archiveLedgerProfile(createdLedger)
            reporter.check(
                ledgerStore.ledgerProfiles.first { $0.id == createdLedger.id }?.isArchived == true,
                "LedgerStore archives custom ledger profile"
            )
            reporter.check(
                ledgerStore.ledgerProfiles.filter(\.isDefault).map(\.id) == [TodaySpendingSummary.defaultLedgerID],
                "LedgerStore restores default local ledger when archiving current default"
            )
        }
    }

    private static func verifyLedgerSelectionAndTransactionMoves(reporter: RegressionReporter) throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerSelectionRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let sqlStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger-selection.sqlite3")
        let ledgerStore = LedgerStore(transactionStore: sqlStore)
        let travelLedger = ledgerStore.createLedgerProfile(name: "Travel", iconName: "airplane", colorName: "teal", currency: "JPY")
        reporter.check(travelLedger != nil, "LedgerStore creates ledger for selection regression")

        let date = Date(timeIntervalSince1970: 1_780_600_000)
        let defaultTransaction = Transaction(
            merchant: "Local Coffee",
            amount: 18,
            occurredAt: date,
            category: .dining,
            source: .manual,
            note: "default ledger"
        )
        reporter.check(ledgerStore.addTransaction(defaultTransaction), "LedgerStore saves default-ledger transaction before selection")
        reporter.check(ledgerStore.selectedLedgerID == TodaySpendingSummary.defaultLedgerID, "LedgerStore starts on default ledger")
        reporter.check(!ledgerStore.isShowingAllLedgers, "LedgerStore starts in current ledger mode")
        reporter.check(ledgerStore.visibleTransactions.map(\.id) == [defaultTransaction.id], "LedgerStore visible transactions start with default ledger")

        if let travelLedger {
            ledgerStore.selectLedgerProfile(travelLedger)
            reporter.check(ledgerStore.selectedLedgerID == travelLedger.id, "LedgerStore selects custom ledger")
            reporter.check(ledgerStore.visibleTransactions.isEmpty, "LedgerStore filters current ledger before travel transaction exists")

            let travelTransaction = Transaction(
                merchant: "Airport Hotel",
                amount: 888,
                occurredAt: date.addingTimeInterval(60),
                category: .other,
                source: .manual,
                note: "current ledger"
            )
            reporter.check(ledgerStore.addTransaction(travelTransaction), "LedgerStore saves transaction into selected ledger")
            let storedTravel = try sqlStore.loadTransactions().first { $0.id == travelTransaction.id }
            reporter.check(storedTravel?.ledgerID == travelLedger.id, "LedgerStore writes selected ledger id for new transaction")
            reporter.check(ledgerStore.visibleTransactions.map(\.id) == [travelTransaction.id], "LedgerStore filters to selected ledger transaction")

            ledgerStore.selectAllLedgers()
            reporter.check(ledgerStore.isShowingAllLedgers, "LedgerStore switches to all-ledgers mode")
            reporter.check(ledgerStore.visibleTransactions.map(\.id) == [travelTransaction.id, defaultTransaction.id], "LedgerStore shows all ledgers when selected")

            reporter.check(ledgerStore.moveTransaction(defaultTransaction, toLedgerID: travelLedger.id), "LedgerStore moves single transaction to another ledger")
            let moved = try sqlStore.loadTransactions().first { $0.id == defaultTransaction.id }
            reporter.check(moved?.ledgerID == travelLedger.id, "LedgerStore persists moved transaction ledger id")

            ledgerStore.selectLedgerProfile(travelLedger)
            reporter.check(
                ledgerStore.visibleTransactions.map(\.id) == [travelTransaction.id, defaultTransaction.id],
                "LedgerStore current ledger includes moved transaction"
            )
        }
    }

    private static func verifyLedgerScopedSurfaces(reporter: RegressionReporter) throws {
        UserDefaults.standard.removeObject(forKey: "selectedLedgerID")
        UserDefaults.standard.removeObject(forKey: "showAllLedgers")

        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerScopedSurfaceRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let sqlStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger-scoped-surfaces.sqlite3")
        let ledgerStore = LedgerStore(transactionStore: sqlStore)
        guard let travelLedger = ledgerStore.createLedgerProfile(name: "Travel", iconName: "airplane", colorName: "teal", currency: "JPY") else {
            reporter.check(false, "LedgerStore creates travel ledger for scoped surfaces")
            return
        }

        let calendar = AppFormatters.calendar
        let referenceDate = Date()
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate.addingTimeInterval(-31 * 86_400)

        let defaultCurrent = Transaction(
            merchant: "Default Cloud",
            amount: 18,
            occurredAt: referenceDate,
            category: .digital,
            source: .appStore,
            note: "default current"
        )
        let defaultPrevious = Transaction(
            merchant: "Default Cloud",
            amount: 18,
            occurredAt: previousMonth,
            category: .digital,
            source: .appStore,
            note: "default previous"
        )
        let travelCurrent = Transaction(
            merchant: "Travel Cloud",
            amount: 88,
            occurredAt: referenceDate,
            category: .digital,
            source: .appStore,
            note: "travel current",
            ledgerID: travelLedger.id
        )
        let travelPrevious = Transaction(
            merchant: "Travel Cloud",
            amount: 88,
            occurredAt: previousMonth,
            category: .digital,
            source: .appStore,
            note: "travel previous",
            ledgerID: travelLedger.id
        )

        reporter.check(ledgerStore.addTransaction(defaultPrevious), "LedgerStore saves default previous transaction for scoped surfaces")
        reporter.check(ledgerStore.addTransaction(defaultCurrent), "LedgerStore saves default current transaction for scoped surfaces")
        reporter.check(ledgerStore.addTransaction(travelPrevious), "LedgerStore saves travel previous transaction for scoped surfaces")
        reporter.check(ledgerStore.addTransaction(travelCurrent), "LedgerStore saves travel current transaction for scoped surfaces")

        let defaultSnapshot = ledgerStore.monthlySnapshot(for: referenceDate)
        reporter.check(defaultSnapshot.transactionCount == 1, "LedgerStore monthly snapshot uses current default ledger")
        reporter.check(abs(defaultSnapshot.totalExpense - 18) < 0.001, "LedgerStore monthly snapshot excludes other ledgers")
        reporter.check(ledgerStore.todaySpendingSummary.transactionCount == 1, "LedgerStore today summary uses current default ledger")
        reporter.check(abs(ledgerStore.todaySpendingSummary.totalExpense - 18) < 0.001, "LedgerStore today summary excludes other ledgers")

        let defaultDetected = ledgerStore.detectSubscriptionsForCurrentLedger()
        reporter.check(defaultDetected.map(\.merchant) == ["Default Cloud"], "LedgerStore detects subscriptions from current default ledger only")

        let defaultSubscription = Subscription(
            merchant: "Default Cloud",
            planName: "",
            period: .monthly,
            amount: 18,
            lastChargedAt: referenceDate
        )
        let travelSubscription = Subscription(
            merchant: "Travel Cloud",
            planName: "",
            period: .monthly,
            amount: 88,
            lastChargedAt: referenceDate
        )
        reporter.check(
            ledgerStore.subscriptionsForCurrentLedger([defaultSubscription, travelSubscription]).map(\.merchant) == ["Default Cloud"],
            "LedgerStore filters subscription list by current ledger activity"
        )

        let defaultStay = HotelStayRecord(
            ledgerID: TodaySpendingSummary.defaultLedgerID,
            hotelName: "Default Hotel",
            currency: "CNY",
            totalAmount: 300,
            sourceType: .manualPDF,
            updatedAt: previousMonth
        )
        let travelStay = HotelStayRecord(
            ledgerID: travelLedger.id,
            hotelName: "Travel Hotel",
            currency: "JPY",
            totalAmount: 50000,
            sourceType: .manualPDF,
            updatedAt: referenceDate
        )
        let scopedHotelSnapshot = HotelStayArchivePresenter().makeListSnapshot(
            records: [defaultStay, travelStay],
            ledgerID: travelLedger.id
        )
        reporter.check(scopedHotelSnapshot.rows.map(\.hotelName) == ["Travel Hotel"], "HotelStayArchivePresenter filters records by ledger id")

        ledgerStore.selectLedgerProfile(travelLedger)
        let travelSnapshot = ledgerStore.monthlySnapshot(for: referenceDate)
        reporter.check(travelSnapshot.transactionCount == 1, "LedgerStore monthly snapshot switches to selected ledger")
        reporter.check(abs(travelSnapshot.totalExpense - 88) < 0.001, "LedgerStore selected ledger snapshot uses travel amount")
        reporter.check(
            ledgerStore.detectSubscriptionsForCurrentLedger().map(\.merchant) == ["Travel Cloud"],
            "LedgerStore detects subscriptions after switching ledger"
        )
        reporter.check(
            ledgerStore.subscriptionsForCurrentLedger([defaultSubscription, travelSubscription]).map(\.merchant) == ["Travel Cloud"],
            "LedgerStore filters subscriptions after switching ledger"
        )

        ledgerStore.selectAllLedgers()
        let allSnapshot = ledgerStore.monthlySnapshot(for: referenceDate)
        reporter.check(allSnapshot.transactionCount == 2, "LedgerStore all-ledgers monthly snapshot aggregates active ledgers")
        reporter.check(abs(allSnapshot.totalExpense - 106) < 0.001, "LedgerStore all-ledgers monthly snapshot totals all ledgers")
        reporter.check(ledgerStore.todaySpendingSummary.transactionCount == 2, "LedgerStore all-ledgers today summary aggregates ledgers")
        reporter.check(
            ledgerStore.subscriptionsForCurrentLedger([defaultSubscription, travelSubscription]).map(\.merchant) == ["Default Cloud", "Travel Cloud"],
            "LedgerStore all-ledgers subscription filter returns all subscriptions"
        )
    }

    private static func verifySyncConflictResolver(reporter: RegressionReporter) {
        let transactionID = UUID()
        let baseTransaction = Transaction(
            id: transactionID,
            merchant: "Demo Coffee",
            amount: 18,
            occurredAt: Date(timeIntervalSince1970: 1_780_000_000),
            category: .dining,
            source: .manual,
            note: "sync"
        )
        let local = TransactionSyncRecord(
            transaction: baseTransaction,
            metadata: TransactionSyncMetadata(
                transactionID: transactionID,
                updatedAt: Date(timeIntervalSince1970: 1_780_000_010),
                syncRevision: 1,
                deviceID: "local-device",
                idempotencyKey: "transaction:\(transactionID.uuidString)"
            )
        )
        let remoteNewer = TransactionSyncRecord(
            transaction: baseTransaction,
            metadata: TransactionSyncMetadata(
                transactionID: transactionID,
                updatedAt: Date(timeIntervalSince1970: 1_780_000_020),
                syncRevision: 2,
                deviceID: "remote-device",
                idempotencyKey: "transaction:\(transactionID.uuidString)"
            )
        )
        reporter.check(
            TransactionSyncConflictResolver.resolve(local: local, remote: remoteNewer) == .applyRemote,
            "TransactionSyncConflictResolver applies newer remote timestamp"
        )

        let localEditedMetro = TransactionSyncRecord(
            transaction: Transaction(
                id: transactionID,
                merchant: "地铁：琅西→金湖广场",
                amount: 1.8,
                occurredAt: baseTransaction.occurredAt,
                category: .transport,
                source: .manual,
                note: "user edited metro station"
            ),
            metadata: TransactionSyncMetadata(
                transactionID: transactionID,
                updatedAt: Date(timeIntervalSince1970: 1_780_000_040),
                syncRevision: 2,
                deviceID: "local-device",
                idempotencyKey: "transaction:\(transactionID.uuidString)"
            )
        )
        let remoteStaleMetro = TransactionSyncRecord(
            transaction: Transaction(
                id: transactionID,
                merchant: "地铁：琅西 →",
                amount: 1.8,
                occurredAt: baseTransaction.occurredAt,
                category: .transport,
                source: .manual,
                note: "user edited metro station"
            ),
            metadata: TransactionSyncMetadata(
                transactionID: transactionID,
                updatedAt: Date(timeIntervalSince1970: 1_780_000_030),
                syncRevision: 3,
                deviceID: "remote-device",
                idempotencyKey: "transaction:\(transactionID.uuidString)"
            )
        )
        reporter.check(
            TransactionSyncConflictResolver.resolve(local: localEditedMetro, remote: remoteStaleMetro) == .keepLocal,
            "TransactionSyncConflictResolver preserves newer local metro merchant edits even when remote revision is higher"
        )

        let remoteSameSecondHigherRevisionMetro = TransactionSyncRecord(
            transaction: Transaction(
                id: transactionID,
                merchant: "地铁：埌西 →",
                amount: 1.8,
                occurredAt: baseTransaction.occurredAt,
                category: .transport,
                source: .manual,
                note: "same second stale remote"
            ),
            metadata: TransactionSyncMetadata(
                transactionID: transactionID,
                updatedAt: localEditedMetro.metadata.updatedAt,
                syncRevision: localEditedMetro.metadata.syncRevision + 3,
                deviceID: "remote-device",
                idempotencyKey: "transaction:\(transactionID.uuidString)"
            )
        )
        reporter.check(
            TransactionSyncConflictResolver.resolve(local: localEditedMetro, remote: remoteSameSecondHigherRevisionMetro) == .conflictPendingReview,
            "TransactionSyncConflictResolver does not let cross-device revision overwrite same-second local metro edits"
        )

        let remoteConflict = TransactionSyncRecord(
            transaction: Transaction(
                id: transactionID,
                merchant: "Changed Merchant",
                amount: 22,
                occurredAt: baseTransaction.occurredAt,
                category: .dining,
                source: .manual,
                note: "sync"
            ),
            metadata: TransactionSyncMetadata(
                transactionID: transactionID,
                updatedAt: local.metadata.updatedAt,
                syncRevision: local.metadata.syncRevision,
                deviceID: "remote-device",
                idempotencyKey: "transaction:\(transactionID.uuidString)"
            )
        )
        reporter.check(
            TransactionSyncConflictResolver.resolve(local: local, remote: remoteConflict) == .conflictPendingReview,
            "TransactionSyncConflictResolver flags same-revision divergent records"
        )
    }

    private static func verifyLedgerSyncPlanner(reporter: RegressionReporter) {
        let activeID = UUID(uuidString: "00000000-0000-0000-0000-000000001565") ?? UUID()
        let deletedID = UUID(uuidString: "00000000-0000-0000-0000-000000001566") ?? UUID()
        let expiredID = UUID(uuidString: "00000000-0000-0000-0000-000000001567") ?? UUID()
        let hotelStayRecordID = UUID(uuidString: "00000000-0000-0000-0000-000000001568") ?? UUID()
        let ledgerID = "travel-ledger"
        let activeTransaction = Transaction(
            id: activeID,
            merchant: "Demo Coffee",
            amount: 18,
            occurredAt: Date(timeIntervalSince1970: 1_780_000_000),
            category: .dining,
            source: .manual,
            note: "active sync",
            ledgerID: ledgerID,
            hotelStayRecordID: hotelStayRecordID
        )
        let deletedTransaction = Transaction(
            id: deletedID,
            merchant: "Example Market",
            amount: 26,
            occurredAt: Date(timeIntervalSince1970: 1_780_000_100),
            category: .groceries,
            source: .wechat,
            note: "deleted sync"
        )
        let expiredTransaction = Transaction(
            id: expiredID,
            merchant: "Old Store",
            amount: 9,
            occurredAt: Date(timeIntervalSince1970: 1_780_000_200),
            category: .shopping,
            source: .manual,
            note: "expired tombstone"
        )
        let activeRecord = TransactionSyncRecord(
            transaction: activeTransaction,
            metadata: TransactionSyncMetadata(
                transactionID: activeID,
                updatedAt: Date(timeIntervalSince1970: 1_780_010_000),
                syncRevision: 1,
                deviceID: "local-device",
                idempotencyKey: "transaction:\(activeID.uuidString)"
            )
        )
        let deletedRecord = TransactionSyncRecord(
            transaction: deletedTransaction,
            metadata: TransactionSyncMetadata(
                transactionID: deletedID,
                updatedAt: Date(timeIntervalSince1970: 1_780_020_000),
                syncRevision: 2,
                deviceID: "local-device",
                idempotencyKey: "transaction:\(deletedID.uuidString)",
                deletedAt: Date(timeIntervalSince1970: 1_780_020_000)
            )
        )
        let expiredRecord = TransactionSyncRecord(
            transaction: expiredTransaction,
            metadata: TransactionSyncMetadata(
                transactionID: expiredID,
                updatedAt: Date(timeIntervalSince1970: 1_780_030_000),
                syncRevision: 3,
                deviceID: "local-device",
                idempotencyKey: "transaction:\(expiredID.uuidString)",
                deletedAt: Date(timeIntervalSince1970: 1_770_000_000)
            )
        )

        reporter.check(
            CloudLedgerSyncSchema.RecordType.transaction == "LedgerTransaction",
            "CloudLedgerSyncSchema keeps transaction record type stable"
        )
        reporter.check(
            CloudLedgerSyncSchema.recordName(for: activeID) == "transaction-00000000-0000-0000-0000-000000001565",
            "CloudLedgerSyncSchema derives deterministic transaction record name"
        )

        let batch = LedgerSyncPlanner.makePushBatch(
            from: [deletedRecord, activeRecord, expiredRecord],
            tombstoneRetentionDays: 30,
            referenceDate: Date(timeIntervalSince1970: 1_780_040_000)
        )
        reporter.check(batch.upserts.map(\.transactionID) == [activeID], "LedgerSyncPlanner places active records in upsert batch")
        reporter.check(batch.tombstones.map(\.transactionID) == [deletedID], "LedgerSyncPlanner keeps retained tombstones in delete batch")
        reporter.check(batch.expiredTombstoneIDs == [expiredID], "LedgerSyncPlanner separates expired tombstones")
        reporter.check(batch.upserts.first?.recordName == CloudLedgerSyncSchema.recordName(for: activeID), "LedgerSyncPlanner payload carries record name")
        reporter.check(batch.upserts.first?.syncRecord.transaction == activeTransaction, "LedgerSyncPlanner payload round-trips transaction")
        reporter.check(
            batch.upserts.first?.syncRecord.transaction.ledgerID == ledgerID,
            "LedgerSyncPlanner payload preserves transaction ledger id"
        )
        reporter.check(
            batch.upserts.first?.syncRecord.transaction.hotelStayRecordID == hotelStayRecordID,
            "LedgerSyncPlanner payload preserves hotel stay transaction link"
        )
        reporter.check(batch.upserts.first?.syncRecord.metadata.syncRevision == 1, "LedgerSyncPlanner payload round-trips sync metadata")

        let incrementalBatch = LedgerSyncPlanner.makePushBatch(
            from: [activeRecord, deletedRecord],
            changedAfter: Date(timeIntervalSince1970: 1_780_015_000),
            tombstoneRetentionDays: 30,
            referenceDate: Date(timeIntervalSince1970: 1_780_040_000)
        )
        reporter.check(incrementalBatch.upserts.isEmpty, "LedgerSyncPlanner filters unchanged active records by changedAfter")
        reporter.check(incrementalBatch.tombstones.map(\.transactionID) == [deletedID], "LedgerSyncPlanner keeps changed tombstones after changedAfter")

        let equalTimestampBatch = LedgerSyncPlanner.makePushBatch(
            from: [activeRecord],
            changedAfter: activeRecord.metadata.updatedAt,
            tombstoneRetentionDays: 30,
            referenceDate: Date(timeIntervalSince1970: 1_780_040_000)
        )
        reporter.check(
            equalTimestampBatch.upserts.map(\.transactionID) == [activeID],
            "LedgerSyncPlanner includes records changed at the checkpoint second"
        )
    }

    private static func verifyLedgerConfigurationSyncPolicy(reporter: RegressionReporter) {
        let appSettings = BackupAppSettings(
            subscriptionReminderEnabled: true,
            monthlyAnomalyThresholdPercent: 150,
            llmEnhancementEnabled: false,
            autoClipboardImportEnabled: false,
            iCloudBackupEnabled: false
        )
        let local = LedgerConfigurationSyncPayload(
            updatedAt: Date(timeIntervalSince1970: 1_780_000_000),
            deviceID: "iphone",
            subscriptions: [],
            categoryCorrections: [
                BackupCategoryCorrection(merchant: "Demo Coffee", category: .dining)
            ],
            customCategories: ["咖啡", "通勤"],
            customSources: ["快捷指令"],
            merchantAliases: ["Demo Cafe": "Demo Coffee"],
            subscriptionMetadata: BackupSubscriptionMetadata(notes: ["sample": "local"]),
            appSettings: appSettings
        )
        let emptyRemote = LedgerConfigurationSyncPayload(
            updatedAt: Date(timeIntervalSince1970: 1_780_010_000),
            deviceID: "ipad",
            subscriptions: [],
            categoryCorrections: [],
            customCategories: [],
            customSources: [],
            merchantAliases: [:],
            subscriptionMetadata: BackupSubscriptionMetadata(),
            appSettings: appSettings
        )

        reporter.check(
            LedgerConfigurationSyncPolicy.shouldPreserveLocalConfiguration(local: local, remote: emptyRemote),
            "LedgerConfigurationSyncPolicy preserves local config when remote config is empty"
        )

        let remote = LedgerConfigurationSyncPayload(
            updatedAt: Date(timeIntervalSince1970: 1_780_020_000),
            deviceID: "ipad",
            subscriptions: [],
            categoryCorrections: [
                BackupCategoryCorrection(merchant: "Example Market", category: .groceries)
            ],
            customCategories: ["餐饮"],
            customSources: ["相册"],
            merchantAliases: ["Example Shop": "Example Market"],
            subscriptionMetadata: BackupSubscriptionMetadata(annualPriceOverrides: ["remote": 88]),
            appSettings: appSettings
        )
        let merged = LedgerConfigurationSyncPolicy.merge(local: local, remote: remote)
        reporter.check(
            Set(merged.customCategories) == Set(["咖啡", "通勤", "餐饮"]),
            "LedgerConfigurationSyncPolicy merges custom categories from local and remote"
        )
        reporter.check(
            merged.categoryCorrections.contains(BackupCategoryCorrection(merchant: "Demo Coffee", category: .dining)) &&
                merged.categoryCorrections.contains(BackupCategoryCorrection(merchant: "Example Market", category: .groceries)),
            "LedgerConfigurationSyncPolicy merges category learning records"
        )
        reporter.check(
            merged.merchantAliases["Demo Cafe"] == "Demo Coffee" &&
                merged.merchantAliases["Example Shop"] == "Example Market",
            "LedgerConfigurationSyncPolicy merges merchant aliases"
        )
    }

    private static func verifyBatchImportQueue(reporter: RegressionReporter) {
        let batchID = UUID(uuidString: "00000000-0000-0000-0000-000000001540") ?? UUID()
        let rawInputID = UUID(uuidString: "00000000-0000-0000-0000-000000001541") ?? UUID()
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-000000001542") ?? UUID()
        let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000001543") ?? UUID()
        let now = Date(timeIntervalSince1970: 1_780_100_000)
        let later = Date(timeIntervalSince1970: 1_780_100_600)
        let batch = BatchImportBatch(
            id: batchID,
            sourceKind: .text,
            itemCount: 1,
            createdAt: now,
            updatedAt: now
        )
        let rawInput = BatchRawInput(
            id: rawInputID,
            batchID: batch.id,
            sourceKind: .text,
            originalFileName: "sample_receipt_01.txt",
            inputHash: "sample-hash-001",
            rawText: "Demo Coffee\nAmount ¥18.00",
            createdAt: now,
            updatedAt: now
        )
        let rawItem = BatchImportQueueItem.rawInput(rawInput: rawInput, id: itemID, createdAt: now)
        reporter.check(rawItem.state == .rawInput, "BatchImportQueue creates raw input item")
        reporter.check(rawItem.rawInputID == rawInput.id, "BatchImportQueue links item to raw input")
        reporter.check(!rawItem.isOfficialTransaction, "BatchImportQueue raw input does not enter official ledger")

        let draft = TransactionDraft(
            amount: 18,
            merchant: "Demo Coffee",
            category: TransactionCategory.dining.rawValue,
            occurredAt: later,
            sourceType: .ocr,
            inputText: rawInput.rawText ?? "",
            parseMethod: .rule
        )
        let candidate = rawItem.applyingInterpretation(
            InterpretResult(
                draft: draft,
                confidence: .high,
                needsReview: false
            ),
            now: later
        )
        reporter.check(candidate.state == .candidate, "BatchImportQueue advances raw input to candidate")
        reporter.check(candidate.merchant == "Demo Coffee", "BatchImportQueue carries candidate merchant")
        reporter.check(abs((candidate.amount ?? 0) - 18) < 0.001, "BatchImportQueue carries candidate amount")
        reporter.check(candidate.convertedTransactionID == nil, "BatchImportQueue high confidence candidate is not auto-saved")
        reporter.check(!candidate.isOfficialTransaction, "BatchImportQueue candidate does not pollute official ledger")

        let missingAmount = rawItem.applyingInterpretation(
            InterpretResult(
                draft: nil,
                confidence: .low,
                needsReview: true,
                warnings: [.missingAmount]
            ),
            now: later
        )
        reporter.check(missingAmount.state == .candidate, "BatchImportQueue turns missing amount item into review candidate")
        reporter.check(missingAmount.failureReason == .missingAmount, "BatchImportQueue records missing amount failure")
        reporter.check(missingAmount.warnings.contains(.lowConfidence), "BatchImportQueue records low confidence warning")
        reporter.check(missingAmount.canRetry, "BatchImportQueue missing amount item can retry")

        let duplicate = candidate.markedDuplicate(
            groupID: "duplicate-demo-001",
            score: 0.92,
            reason: "same amount and merchant",
            possibleTransactionID: transactionID,
            now: later
        )
        reporter.check(duplicate.state == .candidate, "BatchImportQueue duplicate warning keeps candidate")
        reporter.check(duplicate.failureReason == .duplicateSuspected, "BatchImportQueue records duplicate failure reason")
        reporter.check(duplicate.needsReview, "BatchImportQueue duplicate suspected requires review")
        reporter.check(!duplicate.isOfficialTransaction, "BatchImportQueue duplicate warning does not delete or save")

        let reviewed = candidate.reviewed(now: later)
        let converted = reviewed.converted(transactionID: transactionID, now: later)
        let rejected = candidate.markedFailed(reason: .userRejected, now: later)
        reporter.check(reviewed.state == .reviewed, "BatchImportQueue reviewed candidate moves to reviewed")
        reporter.check(converted.state == .transaction, "BatchImportQueue converted item moves to transaction")
        reporter.check(converted.convertedTransactionID == transactionID, "BatchImportQueue stores converted transaction id")
        reporter.check(rejected.state == .rejected, "BatchImportQueue ignored candidate moves to rejected")
        reporter.check(rejected.convertedTransactionID == nil, "BatchImportQueue ignored candidate does not create transaction id")

        let snapshot = BatchImportQueueSnapshot(
            batches: [batch],
            rawInputs: [rawInput],
            items: [rawItem, candidate, duplicate, converted]
        )
        reporter.check(snapshot.items(in: .candidate).count == 2, "BatchImportQueue snapshot filters candidate items")
        reporter.check(snapshot.officialTransactionIDs == [transactionID], "BatchImportQueue snapshot exposes only converted transaction ids")
        reporter.check(snapshot.doesNotPolluteOfficialLedger(), "BatchImportQueue snapshot keeps non-transaction items out of official ledger")
    }

    private static func verifyBatchImportRecognitionExecutor(reporter: RegressionReporter) {
        let batchID = UUID(uuidString: "00000000-0000-0000-0000-000000001544") ?? UUID()
        let now = Date(timeIntervalSince1970: 1_780_110_000)
        let textRaw = BatchRawInput(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001545") ?? UUID(),
            batchID: batchID,
            sourceKind: .text,
            originalFileName: "sample_receipt_02.txt",
            rawText: "Demo Coffee\nTotal ¥21.50",
            createdAt: now,
            updatedAt: now
        )
        let emptyRaw = BatchRawInput(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001546") ?? UUID(),
            batchID: batchID,
            sourceKind: .text,
            originalFileName: "empty_receipt.txt",
            rawText: "   ",
            createdAt: now,
            updatedAt: now
        )
        let photoRaw = BatchRawInput(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001547") ?? UUID(),
            batchID: batchID,
            sourceKind: .photos,
            originalFileName: "sample_receipt_03.png",
            rawText: nil,
            createdAt: now,
            updatedAt: now
        )
        let fileRaw = BatchRawInput(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001548") ?? UUID(),
            batchID: batchID,
            sourceKind: .files,
            originalFileName: "sample_receipt_04.pdf",
            rawText: nil,
            createdAt: now,
            updatedAt: now
        )
        let snapshot = BatchImportQueueSnapshot(
            batches: [
                BatchImportBatch(
                    id: batchID,
                    sourceKind: .text,
                    itemCount: 4,
                    createdAt: now,
                    updatedAt: now
                )
            ],
            rawInputs: [textRaw, emptyRaw, photoRaw, fileRaw],
            items: [textRaw, emptyRaw, photoRaw, fileRaw].map { BatchImportQueueItem.rawInput(rawInput: $0, createdAt: now) }
        )

        let executor = BatchImportRecognitionExecutor()
        let result = executor.process(snapshot: snapshot, now: now.addingTimeInterval(30))
        reporter.check(result.processedCount == 4, "BatchImportRecognitionExecutor processes raw queue items")
        reporter.check(result.candidateCount == 1, "BatchImportRecognitionExecutor generates one candidate from text")
        reporter.check(result.failedCount == 3, "BatchImportRecognitionExecutor records failures for empty/OCR-missing/unsupported inputs")

        let byRawInputID = Dictionary(uniqueKeysWithValues: result.snapshot.items.map { ($0.rawInputID, $0) })
        let textItem = byRawInputID[textRaw.id]
        reporter.check(textItem?.state == .candidate, "BatchImportRecognitionExecutor advances text input to candidate")
        reporter.check(abs((textItem?.amount ?? 0) - 21.5) < 0.001, "BatchImportRecognitionExecutor carries interpreted amount")
        reporter.check(textItem?.convertedTransactionID == nil, "BatchImportRecognitionExecutor does not auto-save candidate")
        reporter.check(byRawInputID[emptyRaw.id]?.failureReason == .emptyInput, "BatchImportRecognitionExecutor marks empty text")
        reporter.check(byRawInputID[photoRaw.id]?.failureReason == .ocrFailed, "BatchImportRecognitionExecutor marks image without OCR text")
        reporter.check(byRawInputID[fileRaw.id]?.failureReason == .unsupportedFileType, "BatchImportRecognitionExecutor marks unsupported file")
        reporter.check(result.snapshot.doesNotPolluteOfficialLedger(), "BatchImportRecognitionExecutor keeps official ledger untouched")

        guard let retryItem = byRawInputID[emptyRaw.id]?.retryRequested(now: now.addingTimeInterval(60)) else {
            reporter.check(false, "BatchImportRecognitionExecutor prepares retry item")
            return
        }
        var retrySnapshot = result.snapshot
        if let index = retrySnapshot.items.firstIndex(where: { $0.id == retryItem.id }) {
            retrySnapshot.items[index] = retryItem
        }
        let retryResult = executor.process(snapshot: retrySnapshot, itemIDs: [retryItem.id], now: now.addingTimeInterval(90))
        reporter.check(retryResult.processedCount == 1, "BatchImportRecognitionExecutor retries selected item only")
        reporter.check(retryResult.snapshot.items.first(where: { $0.id == retryItem.id })?.retryCount == 1, "BatchImportRecognitionExecutor preserves retry count")
    }

    private static func verifyDataCleaningPreviewPlanner(reporter: RegressionReporter) {
        let base = Date(timeIntervalSince1970: 1_780_300_000)
        let aliasTransaction = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001551") ?? UUID(),
            merchant: "Demo Coffee Original",
            amount: 18,
            occurredAt: base,
            category: .other,
            source: .manual,
            note: ""
        )
        let categoryTransaction = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001552") ?? UUID(),
            merchant: "Example Market",
            amount: 42,
            occurredAt: base.addingTimeInterval(-300),
            category: .other,
            source: .manual,
            note: ""
        )
        let duplicateA = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001553") ?? UUID(),
            merchant: "Sample Store",
            amount: 9.9,
            occurredAt: base.addingTimeInterval(-600),
            category: .shopping,
            source: .manual,
            note: ""
        )
        let duplicateB = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001554") ?? UUID(),
            merchant: "Sample Store",
            amount: 9.9,
            occurredAt: base.addingTimeInterval(-630),
            category: .shopping,
            source: .manual,
            note: ""
        )
        let textDuplicateA = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001555") ?? UUID(),
            merchant: "Demo Coffee",
            amount: 26.8,
            occurredAt: base.addingTimeInterval(-1_200),
            category: .dining,
            source: .alipay,
            note: "支付宝 交易成功 Demo Coffee 26.80 订单 EXAMPLE-001"
        )
        let textDuplicateB = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001556") ?? UUID(),
            merchant: "Demo Coffee Store",
            amount: 26.8,
            occurredAt: base.addingTimeInterval(-1_500),
            category: .dining,
            source: .alipay,
            note: "支付宝交易成功 Demo Coffee 26.80 订单 EXAMPLE-001"
        )

        let snapshot = DataCleaningPreviewPlanner().buildSnapshot(
            transactions: [aliasTransaction, categoryTransaction, duplicateA, duplicateB, textDuplicateA, textDuplicateB],
            merchantAliases: ["Demo Coffee Original": "Demo Coffee"],
            categoryCorrections: ["Example Market": .groceries]
        )

        reporter.check(snapshot.items(kind: .merchantAlias).count == 1, "DataCleaningPreviewPlanner previews merchant alias impact")
        reporter.check(snapshot.items(kind: .categoryCorrection).count == 1, "DataCleaningPreviewPlanner previews category correction impact")
        reporter.check(snapshot.items(kind: .duplicateCandidate).count == 2, "DataCleaningPreviewPlanner previews field and text duplicate candidates")
        reporter.check(
            snapshot.items(kind: .merchantAlias).first?.affectedTransactionIDs == [aliasTransaction.id],
            "DataCleaningPreviewPlanner scopes alias impact to matching transactions"
        )
        reporter.check(
            Set(snapshot.items(kind: .duplicateCandidate).first?.affectedTransactionIDs ?? []) == Set([duplicateA.id, duplicateB.id]),
            "DataCleaningPreviewPlanner duplicate preview includes both transactions"
        )
        reporter.check(
            snapshot.items(kind: .duplicateCandidate).contains {
                Set($0.affectedTransactionIDs) == Set([textDuplicateA.id, textDuplicateB.id]) &&
                ($0.score ?? 0) >= 0.85
            },
            "DataCleaningPreviewPlanner detects same-source similar-note duplicate candidates"
        )
    }

    private static func verifySampleParsing(
        using parser: ReceiptParser,
        samples: [SampleReceipt],
        reporter: RegressionReporter
    ) {
        let expectedDates: [String: String] = [
            "微信买菜截图": "2026-03-26 19:42",
            "微信支付详情个体工商户跨行截图": "2026-04-13 16:42:09",
            "支付宝出行截图": "2026-03-25 08:10",
            "App Store 订阅截图": "2026-03-22 12:14",
            "微信支付全部账单截图（7-11）": "2026-04-20 18:17:58",
            "微信支付全部账单截图（羊汤）": "2026-05-04 07:03:35",
            "云闪付账单详情截图": "2026-04-21 18:46:58"
        ]

        let expectedMerchants: [String: String] = [
            "微信买菜截图": "Example Supermarket",
            "微信支付详情个体工商户跨行截图": "示例便利店商贸有限公司",
            "支付宝出行截图": "滴滴出行",
            "App Store 订阅截图": "Apple Services",
            "天津地铁储值卡截图": "地铁：ExampleStationA → ExampleStationB",
            "互联互通城市卡CN¥嵌入格式截图": "地铁：ExampleAirport → ExampleEastStation",
            "抖音团购示例汉堡截图": "Demo Burger (Example Branch)",
            "支付宝碰一下支付截图（7-11）": "Example Convenience Store",
            "滴滴出行结束订单截图": "滴滴出行",
            "滴滴出行通知截图": "滴滴出行",
            "滴滴出行优享出租车截图": "滴滴出行",
            "滴滴出行微信扣费凭证截图": "滴滴出行",
            "支付宝示例汉堡支付成功截图": "Demo Burger Restaurant",
            "淘宝闪购订单进行中截图": "Sample Restaurant（Example Branch）",
            "微信支付全部账单截图（7-11）": "Example Convenience Store",
            "微信支付全部账单截图（羊汤）": "示例餐厅",
            "云闪付付款成功截图": "示例咖啡（Example Station）",
            "云闪付账单详情截图": "Sample Restaurant（Example Branch）",
            "银联二维码支付详情截图": "示例便利店（Example Road）",
            "英文超市纸质小票TOTAL": "NTUC FAIRPRICE",
            "英文超市纸质小票无TOTAL": "WALMART"
        ]

        let expectedAmounts: [String: Double] = [
            "微信买菜截图": 86.30,
            "微信支付详情个体工商户跨行截图": 6.15,
            "支付宝出行截图": 23.80,
            "App Store 订阅截图": 28.00,
            "天津地铁储值卡截图": 2.70,
            "互联互通城市卡CN¥嵌入格式截图": 7.00,
            "抖音团购示例汉堡截图": 26.90,
            "支付宝碰一下支付截图（7-11）": 4.30,
            "滴滴出行结束订单截图": 19.60,
            "滴滴出行通知截图": 9.70,
            "滴滴出行优享出租车截图": 45.00,
            "滴滴出行微信扣费凭证截图": 24.90,
            "支付宝示例汉堡支付成功截图": 60.80,
            "淘宝闪购订单进行中截图": 47.4,
            "微信支付全部账单截图（7-11）": 16.80,
            "微信支付全部账单截图（羊汤）": 20.00,
            "云闪付付款成功截图": 18.60,
            "云闪付账单详情截图": 13.52,
            "银联二维码支付详情截图": 12.80,
            "英文超市纸质小票TOTAL": 12.30,
            "英文超市纸质小票无TOTAL": 7.10
        ]

        let expectedCategories: [String: TransactionCategory] = [
            "微信买菜截图": .groceries,
            "微信支付详情个体工商户跨行截图": .groceries,
            "支付宝出行截图": .transport,
            "App Store 订阅截图": .digital,
            "天津地铁储值卡截图": .transport,
            "互联互通城市卡CN¥嵌入格式截图": .transport,
            "抖音团购示例汉堡截图": .dining,
            "支付宝碰一下支付截图（7-11）": .other,
            "滴滴出行结束订单截图": .transport,
            "滴滴出行通知截图": .transport,
            "滴滴出行优享出租车截图": .transport,
            "滴滴出行微信扣费凭证截图": .transport,
            "支付宝示例汉堡支付成功截图": .dining,
            "淘宝闪购订单进行中截图": .dining,
            "微信支付全部账单截图（7-11）": .other,
            "微信支付全部账单截图（羊汤）": .dining,
            "云闪付付款成功截图": .dining,
            "云闪付账单详情截图": .dining,
            "银联二维码支付详情截图": .groceries,
            "英文超市纸质小票TOTAL": .groceries,
            "英文超市纸质小票无TOTAL": .groceries
        ]

        for sample in samples {
            guard let receipt = parser.parse(text: sample.rawText, source: sample.source) else {
                reporter.check(false, "\(sample.title) should parse successfully")
                continue
            }

            reporter.check(receipt.source == sample.source, "\(sample.title) source matches")
            reporter.check(receipt.merchant == expectedMerchants[sample.title], "\(sample.title) merchant matches")
            reporter.check(abs(receipt.amount - (expectedAmounts[sample.title] ?? 0)) < 0.001, "\(sample.title) amount matches")
            let expectedCategory = expectedCategories[sample.title]
            reporter.check(
                receipt.suggestedCategory == expectedCategory,
                "\(sample.title) category matches (got \(receipt.suggestedCategory.rawValue), expected \(expectedCategory?.rawValue ?? "nil"))"
            )

            if sample.title == "英文超市纸质小票TOTAL" {
                reporter.check(receipt.parseDiagnostics?.isMultiItemReceipt == true, "英文超市纸质小票TOTAL flagged as receipt")
                reporter.check(receipt.parseDiagnostics?.totalMatched == true, "英文超市纸质小票TOTAL matches TOTAL")
                reporter.check(receipt.merchant != "FRESH MILK", "英文超市纸质小票TOTAL does not use first item as merchant")
            }

            if sample.title == "英文超市纸质小票无TOTAL" {
                reporter.check(receipt.parseDiagnostics?.isMultiItemReceipt == true, "英文超市纸质小票无TOTAL flagged as receipt")
                reporter.check(receipt.parseDiagnostics?.totalMatched == false, "英文超市纸质小票无TOTAL stays low confidence")
                reporter.check(receipt.confidence < 0.5, "英文超市纸质小票无TOTAL confidence stays low")
            }

            if let expectedDate = expectedDates[sample.title],
               let parsedDate = AppFormatters.parseFlexibleDate(expectedDate) {
                reporter.check(
                    sameMinute(receipt.occurredAt, parsedDate),
                    "\(sample.title) date matches"
                )
            }
            // Skip date check for samples that have no expected date fixture.
        }

        let alipayDiscountSuccessText = """
        08:18
        回首页
        支付成功
        ¥14.32
        获得森林能量
        易择便利（陈塘科创园店）
        碰友日立减
        付款方式
        加油小葵•当前有100葵花籽待领取
        ¥15.50
        -¥1.18
        光大银行信用卡（1234）
        最高88元点餐红包 限量发放
        """
        if let receipt = parser.parse(text: alipayDiscountSuccessText, source: .alipay) {
            reporter.check(
                receipt.merchant == "易择便利（陈塘科创园店）",
                "ReceiptParser prefers payment success store over discount campaign text"
            )
            reporter.check(abs(receipt.amount - 14.32) < 0.001, "ReceiptParser keeps actual paid amount on discount success page")
        } else {
            reporter.check(false, "ReceiptParser parses discount success payment text")
        }

        let metroTransitText = """
        08:15
        天津互联互通城市卡
        地铁：CN¥2.70
        示例站A→示例站B
        你的新余额为CN¥39.90。
        •共274人推荐＞
        • 示例城市｜示例体育场
        @示例用户・5月10日
        #示例话题 #示例比赛 #示例球队#var 裁判评议
        Q相关搜索•示例裁判说话原声
        留下你的友善评论吧
        61
        现在
        1.0万
        1170
        728
        3384
        SAMPLE-CODE-001
        938
        """
        if let receipt = parser.parse(text: metroTransitText, source: .manual) {
            reporter.check(
                receipt.merchant == "地铁：示例站A→示例站B",
                "ReceiptParser prioritizes metro route before city card and social feed noise"
            )
            reporter.check(abs(receipt.amount - 2.70) < 0.001, "ReceiptParser extracts metro inline CN¥ amount")
            reporter.check(receipt.suggestedCategory == .transport, "ReceiptParser categorizes metro receipt as transport")
        } else {
            reporter.check(false, "ReceiptParser parses metro stored-value payment text")
        }

        if let receipt = parser.parse(text: notificationMetroTransitText, source: .manual) {
            reporter.check(
                receipt.merchant == "地铁：示例站A→示例站B",
                "ReceiptParser extracts metro route from notification-center stored-value text"
            )
            reporter.check(abs(receipt.amount - 2.70) < 0.001, "ReceiptParser extracts notification-center metro fare")
            reporter.check(receipt.suggestedCategory == .transport, "ReceiptParser categorizes notification-center metro receipt as transport")
        } else {
            reporter.check(false, "ReceiptParser parses notification-center metro stored-value text")
        }
    }

    private static func verifyLedgerTextInterpreterTransitShortcut(reporter: RegressionReporter) async {
        ExternalReceiptAssistSettings.isEnabled = true
        defer { ExternalReceiptAssistSettings.isEnabled = false }

        let interpreter = LedgerTextInterpreter()
        let interpretation = await interpreter.interpret(
            LedgerTextInterpretationInput(
                text: notificationMetroTransitText,
                preferredSource: .manual,
                fallbackMerchant: nil,
                ocrMinConfidence: nil
            )
        )

        switch interpretation {
        case .transaction(let result, _, _, let multiReceiptDetected):
            reporter.check(
                result.receipt.merchant == "地铁：示例站A→示例站B",
                "LedgerTextInterpreter shortcuts metro stored-value text before external assist"
            )
            reporter.check(result.llmTrace == nil, "LedgerTextInterpreter does not attach LLM trace for metro shortcut")
            reporter.check(result.usedRuleFallback, "LedgerTextInterpreter marks metro shortcut as rule fallback")
            reporter.check(!multiReceiptDetected, "LedgerTextInterpreter does not mark metro shortcut as multi receipt")
        default:
            reporter.check(false, "LedgerTextInterpreter returns transaction for metro stored-value shortcut")
        }
    }

    private static func verifyLedgerTextInterpreterSuppressesMultipleReceiptWarning(reporter: RegressionReporter) async {
        ExternalReceiptAssistSettings.isEnabled = false

        let interpreter = LedgerTextInterpreter()
        let text = """
        支付成功
        星巴克咖啡
        ¥35.00
        付款方式
        ¥35.00
        优惠
        ¥5.00
        """
        let interpretation = await interpreter.interpret(
            LedgerTextInterpretationInput(
                text: text,
                preferredSource: .manual,
                fallbackMerchant: nil,
                ocrMinConfidence: nil
            )
        )

        switch interpretation {
        case .transaction(let result, _, _, let multiReceiptDetected):
            reporter.check(result.receipt.amount > 0, "LedgerTextInterpreter parses payment text with repeated amount lines")
            reporter.check(!multiReceiptDetected, "LedgerTextInterpreter suppresses multiple receipt warning while feature is paused")
        default:
            reporter.check(false, "LedgerTextInterpreter returns transaction when multiple receipt warning is paused")
        }
    }

    private static func verifyLedgerTextInterpreterUsesLocaleLanguagePack(reporter: RegressionReporter) async {
        ExternalReceiptAssistSettings.isEnabled = false

        let interpreter = LedgerTextInterpreter()
        let text = """
        領収書
        店舗: Demo Cafe
        支払方法 カード
        """
        let interpretation = await interpreter.interpret(
            LedgerTextInterpretationInput(
                text: text,
                preferredSource: .manual,
                fallbackMerchant: nil,
                ocrMinConfidence: nil,
                localeIdentifier: "ja-JP"
            )
        )

        switch interpretation {
        case .nonBillImage:
            reporter.check(false, "LedgerTextInterpreter uses locale language pack before non-bill rejection")
        default:
            reporter.check(true, "LedgerTextInterpreter uses locale language pack before non-bill rejection")
        }
    }

    private static func verifySQLiteRoundTrip(reporter: RegressionReporter) throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerOfflineRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let store = try SQLiteTransactionStore(
            baseDirectoryURL: rootURL,
            filename: "offline.sqlite3",
            syncDeviceID: "offline-device"
        )
        let hotelStayRecordID = UUID(uuidString: "00000000-0000-0000-0000-000000001817") ?? UUID()
        let ledgerID = "travel-ledger"
        let transaction = Transaction(
            merchant: "离线回归商户",
            amount: 12.50,
            occurredAt: AppFormatters.parseFlexibleDate("2026-03-27 09:15") ?? .now,
            category: .dining,
            source: .alipay,
            note: "offline regression",
            ledgerID: ledgerID,
            hotelStayRecordID: hotelStayRecordID
        )
        try store.save(transaction: transaction)

        let loaded = try store.loadTransactions()
        reporter.check(loaded.contains(transaction), "SQLite save/load retains inserted transaction")
        reporter.check(
            loaded.first { $0.id == transaction.id }?.ledgerID == ledgerID,
            "SQLite save/load preserves transaction ledger id"
        )
        reporter.check(
            loaded.first { $0.id == transaction.id }?.hotelStayRecordID == hotelStayRecordID,
            "SQLite save/load preserves hotel stay transaction link"
        )
        guard let insertedMetadata = try store.loadTransactionSyncMetadata(transactionID: transaction.id) else {
            reporter.check(false, "SQLite exposes inserted transaction sync metadata")
            return
        }
        reporter.check(insertedMetadata.syncRevision == 0, "SQLite inserted transaction starts at sync revision 0")
        reporter.check(insertedMetadata.deviceID == "offline-device", "SQLite inserted transaction stores sync device id")
        reporter.check(
            insertedMetadata.idempotencyKey == "transaction:\(transaction.id.uuidString)",
            "SQLite inserted transaction stores default idempotency key"
        )
        reporter.check(insertedMetadata.deletedAt == nil, "SQLite inserted transaction sync metadata has no tombstone")
        reporter.check(insertedMetadata.conflictState == .clean, "SQLite inserted transaction sync metadata starts clean")

        let updated = Transaction(
            id: transaction.id,
            merchant: "离线回归商户-更新",
            amount: 13.37,
            occurredAt: AppFormatters.parseFlexibleDate("2026-03-27 10:20") ?? .now,
            category: .shopping,
            source: .wechat,
            note: "updated note",
            ledgerID: ledgerID,
            hotelStayRecordID: hotelStayRecordID
        )
        try store.update(transaction: updated)

        let reloaded = try store.loadTransactions()
        reporter.check(reloaded.contains(updated), "SQLite update persists modified transaction")
        reporter.check(
            reloaded.first { $0.id == updated.id }?.ledgerID == ledgerID,
            "SQLite update preserves transaction ledger id"
        )
        reporter.check(
            reloaded.first { $0.id == updated.id }?.hotelStayRecordID == hotelStayRecordID,
            "SQLite update preserves hotel stay transaction link"
        )
        let updatedMetadata = try store.loadTransactionSyncMetadata(transactionID: updated.id)
        reporter.check(updatedMetadata?.syncRevision == insertedMetadata.syncRevision + 1, "SQLite update increments sync revision")
        reporter.check(updatedMetadata?.deletedAt == nil, "SQLite update keeps sync tombstone empty")

        try store.delete(transactionID: updated.id)
        let activeAfterDelete = try store.loadTransactions()
        let deletedAfterDelete = try store.loadDeletedTransactions()
        reporter.check(!activeAfterDelete.contains(updated), "SQLite soft delete hides transaction from active load")
        reporter.check(deletedAfterDelete.contains(updated), "SQLite soft delete exposes transaction in deleted load")
        let deletedMetadata = try store.loadTransactionSyncMetadata(transactionID: updated.id)
        reporter.check(deletedMetadata?.syncRevision == (updatedMetadata?.syncRevision ?? 0) + 1, "SQLite soft delete increments sync revision")
        reporter.check(deletedMetadata?.deletedAt != nil, "SQLite soft delete records sync tombstone")
        let allSyncRecordsAfterDelete = try store.loadTransactionSyncRecords(includeDeleted: true)
        let activeSyncRecordsAfterDelete = try store.loadTransactionSyncRecords(includeDeleted: false)
        reporter.check(
            allSyncRecordsAfterDelete.contains { $0.transaction.id == updated.id && $0.metadata.deletedAt != nil },
            "SQLite sync records include deleted tombstones"
        )
        reporter.check(
            !activeSyncRecordsAfterDelete.contains { $0.transaction.id == updated.id },
            "SQLite active sync records exclude deleted tombstones when requested"
        )

        let reopenedStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "offline.sqlite3")
        let reopenedDeleted = try reopenedStore.loadDeletedTransactions()
        reporter.check(reopenedDeleted.contains(updated), "SQLite deleted transactions survive store reopen")

        try store.restoreTransaction(id: updated.id)
        let activeAfterRestore = try store.loadTransactions()
        reporter.check(activeAfterRestore.contains(updated), "SQLite restore returns transaction to active load")
        let restoredMetadata = try store.loadTransactionSyncMetadata(transactionID: updated.id)
        reporter.check(restoredMetadata?.syncRevision == (deletedMetadata?.syncRevision ?? 0) + 1, "SQLite restore increments sync revision")
        reporter.check(restoredMetadata?.deletedAt == nil, "SQLite restore clears sync tombstone")

        let remoteInsertedID = UUID(uuidString: "00000000-0000-0000-0000-000000151500") ?? UUID()
        let remoteInserted = TransactionSyncRecord(
            transaction: Transaction(
                id: remoteInsertedID,
                merchant: "Remote Demo Coffee",
                amount: 22,
                occurredAt: Date(timeIntervalSince1970: 1_780_100_000),
                category: .dining,
                source: .manual,
                note: "remote insert",
                ledgerID: ledgerID
            ),
            metadata: TransactionSyncMetadata(
                transactionID: remoteInsertedID,
                updatedAt: Date(timeIntervalSince1970: 1_780_100_100),
                syncRevision: 3,
                deviceID: "remote-device",
                idempotencyKey: "transaction:\(remoteInsertedID.uuidString)"
            )
        )
        let remoteInsertOutcome = try store.applyRemoteSyncRecord(remoteInserted)
        let transactionsAfterRemoteInsert = try store.loadTransactions()
        reporter.check(remoteInsertOutcome == .inserted, "SQLite remote sync inserts new active transaction")
        reporter.check(transactionsAfterRemoteInsert.contains(remoteInserted.transaction), "SQLite remote inserted transaction becomes active")
        reporter.check(
            transactionsAfterRemoteInsert.first { $0.id == remoteInsertedID }?.ledgerID == ledgerID,
            "SQLite remote inserted transaction preserves ledger id"
        )

        let remoteUpdatedLedgerID = "travel-ledger-updated"
        let remoteUpdated = TransactionSyncRecord(
            transaction: Transaction(
                id: remoteInsertedID,
                merchant: "Remote Example Market",
                amount: 33,
                occurredAt: Date(timeIntervalSince1970: 1_780_100_200),
                category: .groceries,
                source: .wechat,
                note: "remote update",
                ledgerID: remoteUpdatedLedgerID
            ),
            metadata: TransactionSyncMetadata(
                transactionID: remoteInsertedID,
                updatedAt: Date(timeIntervalSince1970: 1_780_100_300),
                syncRevision: 4,
                deviceID: "remote-device",
                idempotencyKey: "transaction:\(remoteInsertedID.uuidString)"
            )
        )
        let remoteUpdateOutcome = try store.applyRemoteSyncRecord(remoteUpdated)
        let transactionsAfterRemoteUpdate = try store.loadTransactions()
        reporter.check(remoteUpdateOutcome == .updated, "SQLite remote sync applies higher remote revision")
        reporter.check(transactionsAfterRemoteUpdate.contains(remoteUpdated.transaction), "SQLite remote updated transaction becomes active")
        reporter.check(
            transactionsAfterRemoteUpdate.first { $0.id == remoteInsertedID }?.ledgerID == remoteUpdatedLedgerID,
            "SQLite remote updated transaction preserves ledger id"
        )

        let remoteDeleted = TransactionSyncRecord(
            transaction: remoteUpdated.transaction,
            metadata: TransactionSyncMetadata(
                transactionID: remoteInsertedID,
                updatedAt: Date(timeIntervalSince1970: 1_780_100_400),
                syncRevision: 5,
                deviceID: "remote-device",
                idempotencyKey: "transaction:\(remoteInsertedID.uuidString)",
                deletedAt: Date(timeIntervalSince1970: 1_780_100_400)
            )
        )
        let remoteDeleteOutcome = try store.applyRemoteSyncRecord(remoteDeleted)
        let deletedAfterRemoteDelete = try store.loadDeletedTransactions()
        reporter.check(remoteDeleteOutcome == .deleted, "SQLite remote sync applies higher remote tombstone")
        reporter.check(deletedAfterRemoteDelete.contains(remoteUpdated.transaction), "SQLite remote tombstone moves transaction to deleted list")

        let conflictID = UUID(uuidString: "00000000-0000-0000-0000-000000151501") ?? UUID()
        let conflictLocal = Transaction(
            id: conflictID,
            merchant: "Conflict Local Store",
            amount: 44,
            occurredAt: Date(timeIntervalSince1970: 1_780_200_000),
            category: .shopping,
            source: .manual,
            note: "local"
        )
        try store.save(transaction: conflictLocal)
        let conflictRemote = TransactionSyncRecord(
            transaction: Transaction(
                id: conflictID,
                merchant: "Conflict Remote Store",
                amount: 55,
                occurredAt: conflictLocal.occurredAt,
                category: .shopping,
                source: .manual,
                note: "remote"
            ),
            metadata: TransactionSyncMetadata(
                transactionID: conflictID,
                updatedAt: try store.loadTransactionSyncMetadata(transactionID: conflictID)?.updatedAt ?? .now,
                syncRevision: 0,
                deviceID: "remote-device",
                idempotencyKey: "transaction:\(conflictID.uuidString)"
            )
        )
        let conflictOutcome = try store.applyRemoteSyncRecord(conflictRemote)
        let conflictMetadata = try store.loadTransactionSyncMetadata(transactionID: conflictID)
        reporter.check(conflictOutcome == .conflictPendingReview, "SQLite remote sync flags same-revision divergent conflict")
        reporter.check(conflictMetadata?.conflictState == .conflictPendingReview, "SQLite remote sync stores conflict state")

        let localEditID = UUID(uuidString: "00000000-0000-0000-0000-000000151503") ?? UUID()
        let localMetroOriginal = Transaction(
            id: localEditID,
            merchant: "地铁：琅西 →",
            amount: 1.8,
            occurredAt: Date(timeIntervalSince1970: 1_780_250_000),
            category: .transport,
            source: .manual,
            note: "快捷指令自动记账"
        )
        try store.save(transaction: localMetroOriginal)
        let localMetroEdited = Transaction(
            id: localEditID,
            merchant: "地铁：琅西→金湖广场",
            amount: 1.8,
            occurredAt: localMetroOriginal.occurredAt,
            category: .transport,
            source: .manual,
            note: "快捷指令自动记账"
        )
        try store.update(transaction: localMetroEdited)
        guard let localEditMetadata = try store.loadTransactionSyncMetadata(transactionID: localEditID) else {
            reporter.check(false, "SQLite local edit exposes sync metadata")
            return
        }
        let staleRemoteMetro = TransactionSyncRecord(
            transaction: localMetroOriginal,
            metadata: TransactionSyncMetadata(
                transactionID: localEditID,
                updatedAt: localEditMetadata.updatedAt.addingTimeInterval(-60),
                syncRevision: localEditMetadata.syncRevision + 1,
                deviceID: "remote-device",
                idempotencyKey: "transaction:\(localEditID.uuidString)"
            )
        )
        let staleRemoteOutcome = try store.applyRemoteSyncRecord(staleRemoteMetro)
        let transactionsAfterStaleRemote = try store.loadTransactions()
        reporter.check(staleRemoteOutcome == .keptLocal, "SQLite remote sync keeps newer local metro merchant edit")
        reporter.check(
            transactionsAfterStaleRemote.contains(localMetroEdited),
            "SQLite remote sync does not overwrite edited metro merchant with stale remote value"
        )

        let protectedEditID = UUID(uuidString: "00000000-0000-0000-0000-000000151504") ?? UUID()
        let protectedMetroOriginal = Transaction(
            id: protectedEditID,
            merchant: "地铁：埌西 →",
            amount: 1.8,
            occurredAt: Date(timeIntervalSince1970: 1_780_260_000),
            category: .transport,
            source: .manual,
            note: "快捷指令自动记账"
        )
        try store.save(transaction: protectedMetroOriginal)
        let protectedMetroEdited = Transaction(
            id: protectedEditID,
            merchant: "地铁：埌西→万象城",
            amount: 1.8,
            occurredAt: protectedMetroOriginal.occurredAt,
            category: .transport,
            source: .manual,
            note: "快捷指令自动记账"
        )
        try store.update(transaction: protectedMetroEdited)
        guard let protectedEditMetadata = try store.loadTransactionSyncMetadata(transactionID: protectedEditID) else {
            reporter.check(false, "SQLite protected local edit exposes sync metadata")
            return
        }
        let remoteProtectedMetro = TransactionSyncRecord(
            transaction: protectedMetroOriginal,
            metadata: TransactionSyncMetadata(
                transactionID: protectedEditID,
                updatedAt: protectedEditMetadata.updatedAt,
                syncRevision: protectedEditMetadata.syncRevision + 3,
                deviceID: "remote-device",
                idempotencyKey: "transaction:\(protectedEditID.uuidString)"
            )
        )
        let protectedBatchSummary = try store.applyRemoteSyncRecords(
            [remoteProtectedMetro],
            protectedLocalTransactionIDs: [protectedEditID]
        )
        let transactionsAfterProtectedRemote = try store.loadTransactions()
        reporter.check(protectedBatchSummary.keptLocal == 1, "SQLite batch sync keeps protected recent local edit")
        reporter.check(
            transactionsAfterProtectedRemote.contains(protectedMetroEdited),
            "SQLite protected recent local edit is not overwritten by same-second remote pull"
        )

        let batchInsertID = UUID(uuidString: "00000000-0000-0000-0000-000000151502") ?? UUID()
        let batchUpdateID = batchInsertID
        let batchDeleteID = remoteInsertedID
        let batchSummary = try store.applyRemoteSyncRecords([
            TransactionSyncRecord(
                transaction: Transaction(
                    id: batchInsertID,
                    merchant: "Batch Demo Coffee",
                    amount: 12.34,
                    occurredAt: Date(timeIntervalSince1970: 1_780_300_000),
                    category: .dining,
                    source: .manual,
                    note: "batch insert"
                ),
                metadata: TransactionSyncMetadata(
                    transactionID: batchInsertID,
                    updatedAt: Date(timeIntervalSince1970: 1_780_300_100),
                    syncRevision: 1,
                    deviceID: "remote-device",
                    idempotencyKey: "transaction:\(batchInsertID.uuidString)"
                )
            ),
            TransactionSyncRecord(
                transaction: Transaction(
                    id: batchUpdateID,
                    merchant: "Batch Updated Store",
                    amount: 66,
                    occurredAt: Date(timeIntervalSince1970: 1_780_300_200),
                    category: .shopping,
                    source: .manual,
                    note: "batch update"
                ),
                metadata: TransactionSyncMetadata(
                    transactionID: batchUpdateID,
                    updatedAt: Date(timeIntervalSince1970: 1_780_300_300),
                    syncRevision: 3,
                    deviceID: "remote-device",
                    idempotencyKey: "transaction:\(batchUpdateID.uuidString)"
                )
            ),
            TransactionSyncRecord(
                transaction: remoteUpdated.transaction,
                metadata: TransactionSyncMetadata(
                    transactionID: batchDeleteID,
                    updatedAt: Date(timeIntervalSince1970: 1_780_300_400),
                    syncRevision: 6,
                    deviceID: "remote-device",
                    idempotencyKey: "transaction:\(batchDeleteID.uuidString)",
                    deletedAt: Date(timeIntervalSince1970: 1_780_300_400)
                )
            )
        ])
        reporter.check(batchSummary.inserted == 1, "SQLite batch remote sync reports inserted count")
        reporter.check(batchSummary.updated == 1, "SQLite batch remote sync reports updated count")
        reporter.check(batchSummary.deleted == 1, "SQLite batch remote sync reports deleted count")
        reporter.check(batchSummary.conflicts == 0, "SQLite batch remote sync avoids false conflicts")

        try store.delete(transactionID: updated.id)
        try store.permanentlyDeleteTransaction(id: updated.id)
        let activeAfterPermanentDelete = try store.loadTransactions()
        let deletedAfterPermanentDelete = try store.loadDeletedTransactions()
        reporter.check(
            !activeAfterPermanentDelete.contains(updated) && !deletedAfterPermanentDelete.contains(updated),
            "SQLite permanent delete removes transaction completely"
        )

        let subscription = Subscription(
            merchant: "离线订阅",
            planName: "月度会员",
            period: .monthly,
            amount: 18.00,
            lastChargedAt: AppFormatters.parseFlexibleDate("2026-03-01 09:00") ?? .now
        )
        try store.saveSubscription(subscription)
        let persistedSubscription = try store.loadSubscriptions().first { $0.id == subscription.id } ?? subscription
        reporter.check(
            persistedSubscription.status == .active,
            "SQLite subscription defaults to active status"
        )

        let editedSubscription = Subscription(
            id: persistedSubscription.id,
            merchant: "离线订阅 Pro",
            planName: "年度对比会员",
            period: .yearly,
            amount: 188.00,
            lastChargedAt: persistedSubscription.lastChargedAt,
            nextChargedAt: AppFormatters.parseFlexibleDate("2027-03-01 09:00") ?? persistedSubscription.nextChargedAt,
            status: .paused,
            createdAt: persistedSubscription.createdAt
        )
        try store.updateSubscription(editedSubscription)

        let loadedSubscriptions = try store.loadSubscriptions()
        reporter.check(
            loadedSubscriptions.contains(editedSubscription),
            "SQLite subscription update persists edited fields"
        )
        reporter.check(
            loadedSubscriptions.first { $0.id == editedSubscription.id }?.status == .paused,
            "SQLite subscription update persists paused status"
        )
    }

    private static func verifyHotelStaySQLitePersistence(reporter: RegressionReporter) throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerHotelStayPersistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let store = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "hotel-stays.sqlite3")
        let hotelStayID = UUID(uuidString: "00000000-0000-0000-0000-000000001861") ?? UUID()
        let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000001862") ?? UUID()
        let createdAt = AppFormatters.parseFlexibleDate("2026-06-25 10:00") ?? .now
        let record = HotelStayRecord(
            id: hotelStayID,
            ledgerID: "travel-ledger",
            linkedTransactionID: transactionID,
            hotelName: "Demo Bay Hotel",
            hotelGroup: "Demo Hospitality",
            hotelBrand: "Demo Suites",
            city: "Tokyo",
            country: "Japan",
            checkInDate: "2026-06-20",
            checkOutDate: "2026-06-22",
            nights: 2,
            roomType: "King Bay View",
            confirmationNumber: "ABC123",
            currency: "JPY",
            roomCharge: 40000,
            taxAmount: 4000,
            serviceCharge: 3000,
            foodBeverageAmount: 2500,
            otherAmount: 500,
            totalAmount: 50000,
            paymentMethod: "Visa",
            sourceType: .manualPDF,
            sourceFileName: "demo-folio.pdf",
            confidence: 0.91,
            rawText: "Demo Bay Hotel raw folio text",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let transaction = Transaction(
            id: transactionID,
            merchant: "Demo Bay Hotel",
            amount: 50000,
            occurredAt: AppFormatters.parseFlexibleDate("2026-06-22") ?? createdAt,
            categoryLabel: "酒店住宿",
            sourceLabel: ReceiptSource.manual.rawValue,
            note: "入住：2026-06-20；退房：2026-06-22",
            ledgerID: "travel-ledger",
            hotelStayRecordID: hotelStayID
        )

        try store.save(hotelStayRecord: record, linkedTransaction: transaction)

        let loadedRecords = try store.loadHotelStayRecords()
        let loadedTransactions = try store.loadTransactions()
        reporter.check(loadedRecords == [record], "SQLite saves hotel stay record")
        reporter.check(loadedTransactions.contains(transaction), "SQLite saves linked hotel transaction")
        reporter.check(
            loadedTransactions.first { $0.id == transactionID }?.hotelStayRecordID == hotelStayID,
            "SQLite linked hotel transaction keeps hotel stay id"
        )

        let reopenedStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "hotel-stays.sqlite3")
        let reopenedRecords = try reopenedStore.loadHotelStayRecords()
        reporter.check(reopenedRecords == [record], "SQLite hotel stay records survive store reopen")

        try reopenedStore.deleteHotelStayRecord(id: hotelStayID)
        let recordsAfterDelete = try reopenedStore.loadHotelStayRecords()
        reporter.check(recordsAfterDelete.isEmpty, "SQLite deletes hotel stay record")
    }

    private static func verifyLedgerStoreHotelStayPosting(reporter: RegressionReporter) throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerHotelStayLedgerStore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let sqlStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "hotel-ledger-store.sqlite3")
        let ledgerStore = LedgerStore(transactionStore: sqlStore)
        let draft = HotelStayDraft(
            sourceType: .manualPDF,
            targetLedgerID: "travel-ledger",
            sourceFileName: "demo-folio.pdf",
            rawText: "Demo Bay Hotel raw folio text",
            parsedPayload: HotelFolioParsedPayload(
                hotelName: "Demo Bay Hotel",
                brand: "Demo Suites",
                group: "Demo Hospitality",
                city: "Tokyo",
                country: "Japan",
                checkInDate: "2026-06-20",
                checkOutDate: "2026-06-22",
                nights: 2,
                roomType: "King Bay View",
                confirmationNumber: "ABC123",
                currency: "JPY",
                roomCharge: 40000,
                tax: 4000,
                serviceCharge: 3000,
                foodBeverage: 2500,
                otherCharges: 500,
                totalAmount: 50000,
                paymentMethod: "Visa",
                confidence: 0.91,
                rawTextExcerpt: "Demo folio excerpt"
            ),
            confidence: 0.91,
            status: .confirmed
        )

        let didPost = ledgerStore.postConfirmedHotelStayDraft(draft)
        reporter.check(didPost, "LedgerStore posts confirmed hotel stay draft")
        reporter.check(ledgerStore.hotelStayRecords.count == 1, "LedgerStore publishes hotel stay record")
        reporter.check(ledgerStore.transactions.count == 1, "LedgerStore publishes linked hotel transaction")
        reporter.check(
            ledgerStore.transactions.first?.hotelStayRecordID == ledgerStore.hotelStayRecords.first?.id,
            "LedgerStore links hotel transaction to posted stay"
        )

        let reopenedStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "hotel-ledger-store.sqlite3")
        let reopenedLedgerStore = LedgerStore(transactionStore: reopenedStore)
        reporter.check(reopenedLedgerStore.hotelStayRecords.count == 1, "LedgerStore reloads hotel stays from SQLite")
        reporter.check(reopenedLedgerStore.transactions.count == 1, "LedgerStore reloads linked hotel transaction")
    }

    private static func verifyLedgerImportFlow(using reporter: RegressionReporter) async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerLedgerRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let store = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger.sqlite3")
        UserDefaults.standard.removeObject(forKey: "merchantAliases")
        let ledger = LedgerStore(transactionStore: store)

        let initialCount = ledger.transactions.count
        reporter.check(initialCount == 0, "LedgerStore bootstraps seed data in empty store")

        let rawText = """
        支付宝
        交易成功
        商户：离线回归咖啡
        金额：￥12.50
        时间：2026/03/27 09:15
        备注：离线回归
        """

        ledger.importRecognizedText(rawText, preferredSource: .alipay)
        try await Task.sleep(nanoseconds: 200_000_000)  // 等待 Task 完成
        reporter.check(ledger.transactions.count == initialCount + 1, "LedgerStore imports unique OCR text")

        ledger.setMerchantAlias(original: "离线回归咖啡", alias: "回归咖啡")
        reporter.check(ledger.transactions.first?.merchant == "回归咖啡", "Merchant alias refreshes existing transactions")

        let aliasedNewText = """
        支付宝
        交易成功
        商户：离线回归咖啡
        金额：￥13.50
        时间：2026/03/27 10:15
        备注：离线回归别名新账单
        """
        ledger.importRecognizedText(aliasedNewText, preferredSource: .alipay)
        try await Task.sleep(nanoseconds: 200_000_000)
        reporter.check(
            ledger.transactions.contains { abs($0.amount - 13.50) < 0.01 && $0.merchant == "回归咖啡" },
            "LedgerStore applies merchant aliases before persisting newly imported OCR transactions"
        )
        reporter.check(
            !ledger.transactions.contains { abs($0.amount - 13.50) < 0.01 && $0.merchant == "离线回归咖啡" },
            "LedgerStore does not persist raw merchant when alias exists"
        )

        ledger.recordMerchantAlias(original: "手动原商户", alias: "手动别名")
        let manualAliased = Transaction(
            merchant: "手动原商户",
            amount: 14.50,
            occurredAt: .now,
            category: .other,
            source: .manual,
            note: "手动别名新账单"
        )
        ledger.addTransaction(manualAliased)
        reporter.check(
            ledger.transactions.contains { $0.id == manualAliased.id && $0.merchant == "手动别名" },
            "LedgerStore applies merchant aliases before persisting manual transactions"
        )

        ledger.importRecognizedText(rawText, preferredSource: .alipay)
        try await Task.sleep(nanoseconds: 200_000_000)
        reporter.check(ledger.transactions.count == initialCount + 3, "LedgerStore skips duplicate OCR text")

        // Jaccard 相似度去重：略微修改的文本应被判定为重复
        let similarText = """
        支付宝
        交易成功
        商户：离线回归咖啡
        金额：￥12.50
        时间：2026/03/27 09:15
        备注：离线回归测试
        """
        ledger.importRecognizedText(similarText, preferredSource: .alipay)
        try await Task.sleep(nanoseconds: 200_000_000)
        reporter.check(ledger.transactions.count == initialCount + 3, "LedgerStore skips OCR-similar duplicate (Jaccard > 0.8)")

        do {
            let legacyStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "legacy-debug.sqlite3")
            let legacyLedger = LedgerStore(transactionStore: legacyStore)
            legacyLedger.importRecognizedText(rawText, preferredSource: .alipay)
            try await Task.sleep(nanoseconds: 200_000_000)
            if let importedCoffee = legacyLedger.transactions.first(where: { abs($0.amount - 12.50) < 0.01 }) {
                try legacyStore.saveDebugEvent(
                    ImportDebugRecord(
                        stage: .persisted,
                        source: .alipay,
                        rawText: similarText,
                        parsedReceipt: nil,
                        summary: "legacy persisted debug event without transaction id"
                    )
                )
                legacyLedger.deleteTransaction(importedCoffee)
                legacyLedger.permanentlyDeleteTransaction(importedCoffee)

                reporter.check(
                    !ImportDuplicateDetector.hasOCRTextDuplicate(
                        rawText: rawText,
                        debugRecords: (try? legacyStore.loadDebugEvents()) ?? [],
                        activeTransactionIDs: [],
                        threshold: 0.8
                    ),
                    "ImportDuplicateDetector ignores deleted and legacy debug text"
                )

                let reloadedLedger = LedgerStore(transactionStore: legacyStore)
                reloadedLedger.importRecognizedText(rawText, preferredSource: .alipay)
                try await Task.sleep(nanoseconds: 200_000_000)
                reporter.check(
                    reloadedLedger.transactions.count == 1,
                    "LedgerStore reimports after permanent delete despite legacy debug text"
                )
            } else {
                reporter.check(false, "LedgerStore finds imported coffee transaction for delete/reimport regression")
            }
        }

        do {
            let manualEditStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "manual-edit.sqlite3")
            let manualEditLedger = LedgerStore(transactionStore: manualEditStore)
            let directManual = Transaction(
                merchant: "普通编辑原商户",
                amount: 15.50,
                occurredAt: .now,
                category: .other,
                source: .manual,
                note: "普通编辑不应学习别名"
            )
            manualEditLedger.addTransaction(directManual)
            manualEditLedger.updateTransaction(
                Transaction(
                    id: directManual.id,
                    merchant: "普通编辑新商户",
                    amount: directManual.amount,
                    occurredAt: directManual.occurredAt,
                    categoryLabel: directManual.category,
                    sourceLabel: directManual.source,
                    note: directManual.note
                )
            )
            reporter.check(
                manualEditLedger.merchantAliases["普通编辑原商户"] == nil,
                "LedgerStore does not learn merchant alias from ordinary manual edit"
            )
        }

        let aliasLearningText = """
        支付宝
        交易成功
        商户：Example Restaurant Management Co.
        金额：￥18.80
        时间：2026/03/28 12:15
        备注：商户别名学习
        """
        ledger.importRecognizedText(aliasLearningText, preferredSource: .alipay)
        try await Task.sleep(nanoseconds: 200_000_000)
        let importedForAlias = ledger.transactions.first { $0.merchant == "Example Restaurant Management Co." }
        reporter.check(importedForAlias != nil, "LedgerStore imports full merchant before alias learning")
        if let importedForAlias {
            let aliasUpdate = Transaction(
                id: importedForAlias.id,
                merchant: "Example Dining",
                amount: importedForAlias.amount,
                occurredAt: importedForAlias.occurredAt,
                categoryLabel: importedForAlias.category,
                sourceLabel: importedForAlias.source,
                note: importedForAlias.note
            )
            reporter.check(
                ledger.shouldOfferMerchantAlias(from: importedForAlias, to: aliasUpdate),
                "LedgerStore can offer merchant alias prompt for high-confidence edit"
            )
            ledger.updateTransaction(aliasUpdate)
            reporter.check(
                ledger.merchantAliases["Example Restaurant Management Co."] == nil,
                "LedgerStore does not learn merchant alias until user confirms"
            )
        }

        let confirmedAliasLearningText = """
        支付宝
        交易成功
        商户：Example Restaurant Management Branch
        金额：￥21.80
        时间：2026/03/28 12:30
        备注：商户别名确认保存
        """
        ledger.importRecognizedText(confirmedAliasLearningText, preferredSource: .alipay)
        try await Task.sleep(nanoseconds: 200_000_000)
        let confirmedAliasSource = ledger.transactions.first { $0.merchant == "Example Restaurant Management Branch" }
        reporter.check(confirmedAliasSource != nil, "LedgerStore imports second full merchant before confirmed alias learning")
        if let confirmedAliasSource {
            ledger.updateTransaction(
                Transaction(
                    id: confirmedAliasSource.id,
                    merchant: "Example Dining",
                    amount: confirmedAliasSource.amount,
                    occurredAt: confirmedAliasSource.occurredAt,
                    categoryLabel: confirmedAliasSource.category,
                    sourceLabel: confirmedAliasSource.source,
                    note: confirmedAliasSource.note
                ),
                saveMerchantAlias: true
            )
            reporter.check(
                ledger.merchantAliases["Example Restaurant Management Branch"] == "Example Dining",
                "LedgerStore learns merchant alias after user confirms high-confidence edit"
            )
        }

        let multiItemNoTotalText = """
        WALMART
        450 MARKET ST
        FRESH MILK        2.00
        BREAD             3.20
        APPLES            7.10
        CASHIER 12
        04/23/2026 18:02
        """
        ledger.importRecognizedText(multiItemNoTotalText, preferredSource: .manual)
        try await Task.sleep(nanoseconds: 200_000_000)
        reporter.check(ledger.transactions.count == initialCount + 5, "LedgerStore does not persist multi-item receipt without reliable total")
        reporter.check(
            ledger.lastImportSummary?.contains("总金额") == true || ledger.lastImportSummary?.contains("total amount") == true,
            "LedgerStore reports multi-item receipt total-missing guidance"
        )

        // TextSimilarity 单元验证
        let sim = TextSimilarity.jaccard(rawText, similarText)
        reporter.check(sim > 0.8, "TextSimilarity.jaccard returns > 0.8 for similar texts (got \(String(format: "%.3f", sim)))")

        let unrelatedText = "Example delivery order amount ¥88.00 merchant Demo Burger"
        let lowSim = TextSimilarity.jaccard(rawText, unrelatedText)
        reporter.check(lowSim < 0.5, "TextSimilarity.jaccard returns < 0.5 for unrelated texts (got \(String(format: "%.3f", lowSim)))")

        let reloadedStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger.sqlite3")
        let reloadedTransactions = try reloadedStore.loadTransactions()
        reporter.check(reloadedTransactions.count == initialCount + 5, "SQLite store reload keeps imported transactions")

        let categoryRefreshA = Transaction(
            merchant: "批量分类商户",
            amount: 11,
            occurredAt: .now,
            category: .other,
            source: .manual,
            note: "分类批量刷新 A"
        )
        let categoryRefreshB = Transaction(
            merchant: "批量分类商户",
            amount: 12,
            occurredAt: .now.addingTimeInterval(-60),
            category: .other,
            source: .manual,
            note: "分类批量刷新 B"
        )
        ledger.addTransaction(categoryRefreshA)
        ledger.addTransaction(categoryRefreshB)
        ledger.updateTransaction(
            Transaction(
                id: categoryRefreshA.id,
                merchant: categoryRefreshA.merchant,
                amount: categoryRefreshA.amount,
                occurredAt: categoryRefreshA.occurredAt,
                categoryLabel: TransactionCategory.dining.rawValue,
                sourceLabel: categoryRefreshA.source,
                note: categoryRefreshA.note
            ),
            refreshSameMerchantCategory: true
        )
        reporter.check(
            ledger.transactions.filter { $0.merchant == "批量分类商户" }.allSatisfy { $0.category == TransactionCategory.dining.rawValue },
            "LedgerStore refreshes same-merchant categories after edit"
        )

        let aliasRefresh = Transaction(
            merchant: "别名刷新原商户",
            amount: 9,
            occurredAt: .now,
            category: .shopping,
            source: .manual,
            note: "单条别名刷新"
        )
        ledger.addTransaction(aliasRefresh)
        ledger.recordMerchantAlias(original: "别名刷新原商户", alias: "别名刷新后")
        let aliasRefreshCount = ledger.refreshTransactionsForMerchantAlias(original: "别名刷新原商户")
        reporter.check(aliasRefreshCount == 1, "LedgerStore refreshes a single merchant alias count")
        reporter.check(
            ledger.transactions.contains { $0.id == aliasRefresh.id && $0.merchant == "别名刷新后" },
            "LedgerStore refreshes a single merchant alias merchant name"
        )

        let cleaningAlias = Transaction(
            merchant: "Cleanup Original Merchant",
            amount: 21,
            occurredAt: .now,
            category: .other,
            source: .manual,
            note: "data cleaning alias"
        )
        ledger.addTransaction(cleaningAlias)
        ledger.recordMerchantAlias(original: "Cleanup Original Merchant", alias: "Cleanup Unified Merchant")
        let aliasCleaningPreview = DataCleaningPreviewPlanner()
            .buildSnapshot(
                transactions: ledger.transactions,
                merchantAliases: ledger.merchantAliases,
                categoryCorrections: ledger.categoryCorrections
            )
            .items(kind: .merchantAlias)
            .first { $0.affectedTransactionIDs.contains(cleaningAlias.id) }
        reporter.check(aliasCleaningPreview != nil, "LedgerStore data cleaning can preview merchant alias application")
        if let aliasCleaningPreview {
            let result = ledger.applyDataCleaningPreview(aliasCleaningPreview)
            reporter.check(result.updatedCount == 1 && result.canUndo, "LedgerStore applies merchant alias cleaning with undo snapshot")
            reporter.check(
                ledger.transactions.contains { $0.id == cleaningAlias.id && $0.merchant == "Cleanup Unified Merchant" },
                "LedgerStore merchant alias cleaning updates affected transaction"
            )
            _ = ledger.undoLastDataCleaningApplication()
            reporter.check(
                ledger.transactions.contains { $0.id == cleaningAlias.id && $0.merchant == "Cleanup Original Merchant" },
                "LedgerStore undo restores merchant alias cleaning"
            )
        }

        let cleaningCategory = Transaction(
            merchant: "Cleanup Category Merchant",
            amount: 22,
            occurredAt: .now.addingTimeInterval(-120),
            category: .other,
            source: .manual,
            note: "data cleaning category"
        )
        ledger.addTransaction(cleaningCategory)
        ledger.recordCategoryCorrection(merchant: "Cleanup Category Merchant", category: .dining)
        let categoryCleaningPreview = DataCleaningPreviewPlanner()
            .buildSnapshot(
                transactions: ledger.transactions,
                merchantAliases: ledger.merchantAliases,
                categoryCorrections: ledger.categoryCorrections
            )
            .items(kind: .categoryCorrection)
            .first { $0.affectedTransactionIDs.contains(cleaningCategory.id) }
        reporter.check(categoryCleaningPreview != nil, "LedgerStore data cleaning can preview category correction application")
        if let categoryCleaningPreview {
            let result = ledger.applyDataCleaningPreview(categoryCleaningPreview)
            reporter.check(result.updatedCount == 1, "LedgerStore applies category cleaning")
            reporter.check(
                ledger.transactions.contains { $0.id == cleaningCategory.id && $0.category == TransactionCategory.dining.rawValue },
                "LedgerStore category cleaning updates affected transaction"
            )
        }

        let duplicateA = Transaction(
            merchant: "Cleanup Duplicate Merchant",
            amount: 23,
            occurredAt: .now.addingTimeInterval(-240),
            category: .shopping,
            source: .manual,
            note: "duplicate A"
        )
        let duplicateB = Transaction(
            merchant: "Cleanup Duplicate Merchant",
            amount: 23,
            occurredAt: duplicateA.occurredAt.addingTimeInterval(-20),
            category: .shopping,
            source: .manual,
            note: "duplicate B"
        )
        ledger.addTransaction(duplicateA)
        ledger.addTransaction(duplicateB)
        let duplicateCleaningPreview = DataCleaningPreviewPlanner()
            .buildSnapshot(
                transactions: ledger.transactions,
                merchantAliases: ledger.merchantAliases,
                categoryCorrections: ledger.categoryCorrections
            )
            .items(kind: .duplicateCandidate)
            .first { Set($0.affectedTransactionIDs) == Set([duplicateA.id, duplicateB.id]) }
        reporter.check(duplicateCleaningPreview != nil, "LedgerStore data cleaning can preview duplicate application")
        if let duplicateCleaningPreview {
            let result = ledger.applyDataCleaningPreview(duplicateCleaningPreview)
            reporter.check(result.deletedCount == 1 && result.canUndo, "LedgerStore duplicate cleaning soft-deletes one duplicate with undo snapshot")
            reporter.check(
                ledger.transactions.filter { $0.merchant == "Cleanup Duplicate Merchant" }.count == 1 &&
                ledger.deletedTransactions.contains { $0.merchant == "Cleanup Duplicate Merchant" },
                "LedgerStore duplicate cleaning moves one item to recently deleted"
            )
            _ = ledger.undoLastDataCleaningApplication()
            reporter.check(
                ledger.transactions.filter { $0.merchant == "Cleanup Duplicate Merchant" }.count == 2 &&
                !ledger.deletedTransactions.contains { $0.merchant == "Cleanup Duplicate Merchant" },
                "LedgerStore undo restores duplicate cleaning"
            )
        }
    }

    private static func verifyLedgerCSVCodec(reporter: RegressionReporter) throws {
        let transaction = Transaction(
            merchant: "Demo Coffee",
            amount: 18.80,
            occurredAt: AppFormatters.parseFlexibleDate("2026-06-04 09:30") ?? .now,
            category: .dining,
            source: .manual,
            note: "latte, \"morning\""
        )

        let data = try LedgerCSVCodec.encode(transactions: [transaction])
        let decoded = try LedgerCSVCodec.decode(data: data)
        reporter.check(decoded.rows.count == 1, "LedgerCSVCodec round-trips one transaction row")
        reporter.check(decoded.validCount == 1, "LedgerCSVCodec imports valid row")
        reporter.check(decoded.rows.first?.transaction?.merchant == transaction.merchant, "LedgerCSVCodec preserves merchant")
        reporter.check(abs((decoded.rows.first?.transaction?.amount ?? 0) - transaction.amount) < 0.001, "LedgerCSVCodec preserves amount")
        reporter.check(decoded.rows.first?.transaction?.note == transaction.note, "LedgerCSVCodec preserves quoted note")

        let invalidCSV = """
        occurredAt,merchant,amount,category,source,note
        2026-06-04T09:30:00Z,Example Market,not-a-number,groceries,manual,invalid amount
        """
        let invalid = try LedgerCSVCodec.decode(data: Data(invalidCSV.utf8))
        reporter.check(invalid.rows.count == 1, "LedgerCSVCodec keeps invalid row for review")
        reporter.check(invalid.rows.first?.failureReason == .missingAmount, "LedgerCSVCodec marks invalid amount")
    }

    private static func verifyBackupRoundTrip(reporter: RegressionReporter) throws {
        let legacyTransactionJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000101",
          "merchant": "Legacy Store",
          "amount": 12.5,
          "occurredAt": "2026-04-24T08:30:00Z",
          "category": "shopping",
          "source": "manual",
          "note": "legacy backup",
          "deletedAt": null
        }
        """.data(using: .utf8) ?? Data()
        let legacyDecoder = JSONDecoder()
        legacyDecoder.dateDecodingStrategy = .iso8601
        let legacyBackupTransaction = try legacyDecoder.decode(BackupTransaction.self, from: legacyTransactionJSON)
        reporter.check(
            legacyBackupTransaction.syncMetadata == nil,
            "BackupTransaction decodes legacy v1 JSON without sync metadata"
        )

        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerBackupRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        UserDefaults.standard.removeObject(forKey: "customSources")
        UserDefaults.standard.removeObject(forKey: "customCategories")
        UserDefaults.standard.removeObject(forKey: "merchantAliases")
        UserDefaults.standard.removeObject(forKey: "subscriptionAnnualPriceOverrides")
        UserDefaults.standard.removeObject(forKey: "subscriptionNotes")

        let sourceStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "source.sqlite3")
        let sourceLedger = LedgerStore(transactionStore: sourceStore)
        let hotelStayRecordID = UUID(uuidString: "00000000-0000-0000-0000-000000001819") ?? UUID()
        let ledgerID = "travel-ledger"
        let active = Transaction(
            merchant: "备份回归咖啡",
            amount: 21.00,
            occurredAt: AppFormatters.parseFlexibleDate("2026-04-24 08:30") ?? .now,
            categoryLabel: "咖啡",
            sourceLabel: "测试来源",
            note: "active",
            ledgerID: ledgerID,
            hotelStayRecordID: hotelStayRecordID
        )
        let deleted = Transaction(
            merchant: "备份回归删除",
            amount: 9.90,
            occurredAt: AppFormatters.parseFlexibleDate("2026-04-23 18:30") ?? .now,
            category: .dining,
            source: .wechat,
            note: "deleted"
        )
        sourceLedger.addTransaction(active)
        sourceLedger.addTransaction(deleted)
        sourceLedger.deleteTransaction(deleted)
        sourceLedger.customCategories = ["咖啡"]
        sourceLedger.customSources = ["测试来源"]
        sourceLedger.setMerchantAlias(original: "原始商户", alias: "别名商户")
        sourceLedger.saveCustomCategories()
        sourceLedger.saveCustomSources()
        sourceLedger.recordCategoryCorrection(merchant: "备份回归咖啡", category: .dining)

        let subscription = Subscription(
            merchant: "备份订阅",
            planName: "Pro",
            period: .monthly,
            amount: 18,
            lastChargedAt: AppFormatters.parseFlexibleDate("2026-04-01 09:00") ?? .now,
            status: .canceled
        )
        sourceLedger.upsertSubscription(subscription)
        UserDefaults.standard.set([subscription.id.uuidString: 168.0], forKey: "subscriptionAnnualPriceOverrides")
        UserDefaults.standard.set([subscription.id.uuidString: "年度价备注"], forKey: "subscriptionNotes")

        let bundle = try sourceLedger.makeBackupBundle()
        reporter.check(bundle.summary.transactionCount == 1, "BackupBundle summary counts active transactions")
        reporter.check(bundle.summary.deletedTransactionCount == 1, "BackupBundle summary counts deleted transactions")
        reporter.check(
            bundle.transactions.first { $0.id == active.id }?.ledgerID == ledgerID,
            "BackupBundle preserves transaction ledger id"
        )
        reporter.check(
            bundle.transactions.first { $0.id == active.id }?.hotelStayRecordID == hotelStayRecordID,
            "BackupBundle preserves hotel stay transaction link"
        )
        reporter.check(bundle.customCategories == ["咖啡"], "BackupBundle includes custom categories")
        reporter.check(bundle.subscriptionMetadata.annualPriceOverrides[subscription.id.uuidString] == 168.0, "BackupBundle includes subscription annual price metadata")

        let restoreStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "restore.sqlite3")
        let restoreLedger = LedgerStore(transactionStore: restoreStore)
        try restoreLedger.restoreBackup(bundle)

        reporter.check(restoreLedger.transactions.contains(active), "Backup restore keeps active transaction")
        reporter.check(
            restoreLedger.transactions.first { $0.id == active.id }?.ledgerID == ledgerID,
            "Backup restore keeps transaction ledger id"
        )
        reporter.check(
            restoreLedger.transactions.first { $0.id == active.id }?.hotelStayRecordID == hotelStayRecordID,
            "Backup restore keeps hotel stay transaction link"
        )
        reporter.check(restoreLedger.deletedTransactions.contains(deleted.assigningLedgerIDIfMissing()), "Backup restore keeps deleted transaction")
        let restoredSubscription = restoreLedger.subscriptions.first { $0.id == subscription.id }
        reporter.check(
            restoredSubscription?.merchant == subscription.merchant &&
            restoredSubscription?.planName == subscription.planName &&
            restoredSubscription?.period == subscription.period &&
            restoredSubscription?.status == .canceled &&
            abs((restoredSubscription?.amount ?? 0) - subscription.amount) < 0.001,
            "Backup restore keeps subscriptions"
        )
        reporter.check(restoreLedger.customCategories == ["咖啡"], "Backup restore keeps custom categories")
        reporter.check(restoreLedger.customSources == ["测试来源"], "Backup restore keeps custom sources")
        reporter.check(restoreLedger.merchantAliases["原始商户"] == "别名商户", "Backup restore keeps merchant aliases")
        reporter.check(restoreLedger.categoryCorrections["备份回归咖啡"] == .dining, "Backup restore keeps category corrections")
    }

    private static func sameMinute(_ lhs: Date, _ rhs: Date) -> Bool {
        let calendar = AppFormatters.calendar
        let lhsComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: lhs)
        let rhsComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rhs)
        return lhsComponents == rhsComponents
    }
}
