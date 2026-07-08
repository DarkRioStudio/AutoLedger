import XCTest
@testable import AutoLedgerCore

final class AnalyticsInstrumentationTests: XCTestCase {
    func testBuildsAllowedAnonymousImportCompletionEvent() throws {
        let event = try AutoLedgerAnalyticsEvent.make(
            .importFlowCompleted,
            payload: [
                "event_id": .string("event-1"),
                "app_version": .string("1.6.0"),
                "flow_type": .string("receipt_scan"),
                "input_type": .string("camera"),
                "status": .string("success"),
                "duration_ms_bucket": .string("1s_3s"),
                "retry_count_bucket": .string("0"),
                "error_code": .string("none")
            ]
        )

        XCTAssertEqual(event.eventName, "al_import_flow_completed")
        XCTAssertEqual(event.payload["flow_type"], .string("receipt_scan"))
        XCTAssertEqual(event.payload["duration_ms_bucket"], .string("1s_3s"))
    }

    func testRejectsForbiddenFinancialAndDocumentFields() {
        let forbiddenPayloads: [[String: AutoLedgerAnalyticsPayloadValue]] = [
            ["amount": .string("88.80")],
            ["merchant": .string("Cafe Example")],
            ["screenshot": .string("image.png")],
            ["pdf_filename": .string("hotel.pdf")],
            ["email_subject": .string("Your folio")],
            ["hotel_name": .string("Hotel Example")],
            ["room_number": .string("1208")],
            ["exact_latitude": .double(39.123456)],
            ["ocr_text": .string("TOTAL 88.80")],
            ["transaction_id": .string("tx-raw-id")]
        ]

        for payload in forbiddenPayloads {
            XCTAssertThrowsError(try AutoLedgerAnalyticsEvent.make(.importFlowCompleted, payload: payload)) { error in
                guard case AutoLedgerAnalyticsValidationError.forbiddenField = error else {
                    return XCTFail("Expected forbidden field error, got \(error)")
                }
            }
        }
    }

    func testRejectsFieldsOutsideEventAllowList() {
        XCTAssertThrowsError(
            try AutoLedgerAnalyticsEvent.make(.purchaseFlowStatus, payload: [
                "event_id": .string("event-2"),
                "product_tier": .string("pro"),
                "storekit_status": .string("failed"),
                "unknown_field": .string("value")
            ])
        ) { error in
            guard case AutoLedgerAnalyticsValidationError.unsupportedField("unknown_field", "al_purchase_flow_status") = error else {
                return XCTFail("Expected unsupported field error, got \(error)")
            }
        }
    }

    func testPurchaseFlowAllowsStatusButRejectsStoreKitIdentifiers() throws {
        let event = try AutoLedgerAnalyticsEvent.make(
            .purchaseFlowStatus,
            payload: [
                "event_id": .string("event-3"),
                "app_version": .string("1.6.0"),
                "product_tier": .string("pro"),
                "storekit_step": .string("purchase"),
                "storekit_status": .string("cancelled"),
                "error_code": .string("user_cancelled"),
                "duration_ms_bucket": .string("under_1s")
            ]
        )

        XCTAssertEqual(event.eventName, "al_purchase_flow_status")
        XCTAssertThrowsError(try AutoLedgerAnalyticsEvent.make(.purchaseFlowStatus, payload: [
            "transaction_id": .string("200000123"),
            "receipt": .string("base64-receipt")
        ]))
    }

    func testCatalogCoversPlanEventsAndMinimalDashboardMetrics() {
        let eventNames = Set(AutoLedgerAnalyticsCatalog.eventDefinitions.map(\.eventName))
        XCTAssertTrue(eventNames.isSuperset(of: [
            "al_perf_app_launch",
            "al_import_flow_started",
            "al_import_flow_completed",
            "al_confirmation_state",
            "al_currency_lookup_status",
            "al_hotel_pdf_flow_status",
            "al_common_api_request_status",
            "al_pro_gate_viewed",
            "al_purchase_flow_status",
            "al_privacy_payload_guard_violation"
        ]))

        let metrics = Set(AutoLedgerAnalyticsCatalog.minimalDashboardMetrics.map(\.metricID))
        XCTAssertTrue(metrics.isSuperset(of: [
            "launch_success_rate",
            "import_completion_rate",
            "import_error_code_top_n",
            "confirmation_discard_rate",
            "currency_lookup_success_rate",
            "pro_gate_boundary_risk",
            "purchase_flow_failure_rate",
            "privacy_payload_violation_count"
        ]))
    }

    func testRecorderBuildsMinimalDashboardSnapshotFromAllowedEvents() throws {
        var recorder = AutoLedgerAnalyticsRecorder()

        try recorder.record(.importFlowStarted, payload: [
            "event_id": .string("start-1"),
            "app_version": .string("1.6.0"),
            "flow_type": .string("receipt_scan"),
            "input_type": .string("camera"),
            "entry_surface": .string("inbox"),
            "is_pro_surface": .bool(false),
            "start_status": .string("started")
        ])
        try recorder.record(.importFlowStarted, payload: [
            "event_id": .string("start-2"),
            "app_version": .string("1.6.0"),
            "flow_type": .string("hotel_pdf"),
            "input_type": .string("file_picker"),
            "entry_surface": .string("hotel"),
            "is_pro_surface": .bool(true),
            "start_status": .string("started")
        ])
        try recorder.record(.importFlowCompleted, payload: [
            "event_id": .string("complete-1"),
            "app_version": .string("1.6.0"),
            "flow_type": .string("receipt_scan"),
            "input_type": .string("camera"),
            "status": .string("success"),
            "duration_ms_bucket": .string("1s_3s"),
            "retry_count_bucket": .string("0"),
            "error_code": .string("none")
        ])
        try recorder.record(.purchaseFlowStatus, payload: [
            "event_id": .string("purchase-1"),
            "app_version": .string("1.6.0"),
            "product_tier": .string("pro"),
            "storekit_step": .string("purchase"),
            "storekit_status": .string("failed"),
            "error_code": .string("network_error"),
            "duration_ms_bucket": .string("1s_3s")
        ])

        let snapshot = recorder.makeMinimalDashboardSnapshot()

        XCTAssertEqual(snapshot.metric(id: "import_completion_rate")?.value, 50)
        XCTAssertEqual(snapshot.metric(id: "purchase_flow_failure_rate")?.value, 100)
        XCTAssertEqual(snapshot.metric(id: "privacy_payload_violation_count")?.value, 0)
        XCTAssertEqual(snapshot.metric(id: "import_error_code_top_n")?.breakdown["none"], 1)
    }

    func testRecorderCountsPrivacyGuardViolationWithoutStoringForbiddenPayload() {
        var recorder = AutoLedgerAnalyticsRecorder()

        XCTAssertThrowsError(try recorder.record(.importFlowCompleted, payload: [
            "event_id": .string("bad-1"),
            "app_version": .string("1.6.0"),
            "amount": .double(88.8)
        ]))

        let snapshot = recorder.makeMinimalDashboardSnapshot()
        let violationEvents = recorder.recordedEvents.filter { $0.name == .privacyPayloadGuardViolation }
        XCTAssertEqual(snapshot.metric(id: "privacy_payload_violation_count")?.value, 1)
        XCTAssertEqual(violationEvents.count, 1)
        XCTAssertEqual(violationEvents.first?.payload["blocked_field_category"], .string("financial"))
        XCTAssertNil(violationEvents.first?.payload["amount"])
    }
}
