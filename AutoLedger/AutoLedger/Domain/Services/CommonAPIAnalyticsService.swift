import AutoLedgerCore
import Foundation
import OSLog

nonisolated private let commonAPIAnalyticsLogger = Logger(
    subsystem: "top.darkrio326.AutoLedger",
    category: "CommonAPIAnalytics"
)

enum CommonAPIAnalyticsService {
    nonisolated static func uploadLaunchEvent() async {
        await uploadEvent(.appLaunchPerformance, payload: [
            "build_number": .string(buildNumber),
            "os_major": .string("\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"),
            "device_class": .string(deviceClass),
            "launch_type": .string("foreground"),
            "duration_ms_bucket": .string("not_measured"),
            "result": .string("success"),
            "error_code": .string("none")
        ])
        commonAPIAnalyticsLogger.info("[CommonAPI] anonymous launch analytics uploaded")
    }

    nonisolated static func trackRecoveredUncleanLaunch() {
        fireAndForget(.appLaunchPerformance, payload: [
            "build_number": .string(buildNumber),
            "os_major": .string("\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"),
            "device_class": .string(deviceClass),
            "launch_type": .string("previous_session_recovery"),
            "duration_ms_bucket": .string("not_measured"),
            "result": .string("failure"),
            "error_code": .string("unclean_previous_session")
        ])
    }

    nonisolated static func trackFeatureSurfaceOpened(
        surface: String,
        entrySurface: String,
        isProSurface: Bool = false,
        openReason: String = "view_appear"
    ) {
        fireAndForget(.featureSurfaceOpened, payload: [
            "surface": .string(safeEnum(surface)),
            "entry_surface": .string(safeEnum(entrySurface)),
            "is_pro_surface": .bool(isProSurface),
            "open_reason": .string(safeEnum(openReason))
        ])
    }

    nonisolated static func trackImportStarted(
        flowType: String,
        inputType: String,
        entrySurface: String,
        isProSurface: Bool = false,
        startStatus: String = "started"
    ) {
        fireAndForget(.importFlowStarted, payload: [
            "flow_type": .string(safeEnum(flowType)),
            "input_type": .string(safeEnum(inputType)),
            "entry_surface": .string(safeEnum(entrySurface)),
            "is_pro_surface": .bool(isProSurface),
            "start_status": .string(safeEnum(startStatus))
        ])
    }

    nonisolated static func trackImportCompleted(
        flowType: String,
        inputType: String,
        status: String,
        startedAt: Date? = nil,
        retryCount: Int = 0,
        errorCode: String = "none"
    ) {
        fireAndForget(.importFlowCompleted, payload: [
            "flow_type": .string(safeEnum(flowType)),
            "input_type": .string(safeEnum(inputType)),
            "status": .string(safeEnum(status)),
            "duration_ms_bucket": .string(durationBucket(since: startedAt)),
            "retry_count_bucket": .string(retryCountBucket(retryCount)),
            "error_code": .string(safeErrorCode(errorCode))
        ])
    }

    nonisolated static func trackConfirmationState(
        flowType: String,
        requiredFieldCount: Int,
        editedFieldCount: Int,
        confirmStatus: String,
        discardReasonCode: String = "none"
    ) {
        fireAndForget(.confirmationState, payload: [
            "flow_type": .string(safeEnum(flowType)),
            "required_field_count_bucket": .string(countBucket(requiredFieldCount)),
            "edited_field_count_bucket": .string(countBucket(editedFieldCount)),
            "confirm_status": .string(safeEnum(confirmStatus)),
            "discard_reason_code": .string(safeErrorCode(discardReasonCode))
        ])
    }

    nonisolated static func trackCurrencyLookup(
        lookupContext: String,
        hasForeignCurrency: Bool,
        status: String,
        startedAt: Date? = nil,
        errorCode: String = "none",
        cacheStatus: String = "unknown"
    ) {
        fireAndForget(.currencyLookupStatus, payload: [
            "lookup_context": .string(safeEnum(lookupContext)),
            "has_foreign_currency": .bool(hasForeignCurrency),
            "rate_lookup_status": .string(safeEnum(status)),
            "latency_ms_bucket": .string(durationBucket(since: startedAt)),
            "error_code": .string(safeErrorCode(errorCode)),
            "cache_status": .string(safeEnum(cacheStatus))
        ])
    }

    nonisolated static func trackHotelPDF(
        flowType: String,
        pageCount: Int? = nil,
        status: String,
        startedAt: Date? = nil,
        errorCode: String = "none"
    ) {
        fireAndForget(.hotelPDFFlowStatus, payload: [
            "flow_type": .string(safeEnum(flowType)),
            "page_count_bucket": .string(pageCountBucket(pageCount)),
            "status": .string(safeEnum(status)),
            "duration_ms_bucket": .string(durationBucket(since: startedAt)),
            "error_code": .string(safeErrorCode(errorCode))
        ])
    }

    nonisolated static func trackCommonAPIRequest(
        endpointGroup: String,
        httpStatusBucket: String,
        startedAt: Date? = nil,
        errorCode: String = "none",
        cacheStatus: String = "unknown"
    ) {
        fireAndForget(.commonAPIRequestStatus, payload: [
            "endpoint_group": .string(safeEnum(endpointGroup)),
            "http_status_bucket": .string(safeEnum(httpStatusBucket)),
            "latency_ms_bucket": .string(durationBucket(since: startedAt)),
            "error_code": .string(safeErrorCode(errorCode)),
            "cache_status": .string(safeEnum(cacheStatus))
        ])
    }

    nonisolated static func trackProGateViewed(
        surface: String,
        featureArea: String,
        userAction: String,
        dismissReasonCode: String = "none",
        copyVariant: String = "default"
    ) {
        fireAndForget(.proGateViewed, payload: [
            "surface": .string(safeEnum(surface)),
            "pro_feature_area": .string(safeEnum(featureArea)),
            "copy_variant": .string(safeEnum(copyVariant)),
            "user_action": .string(safeEnum(userAction)),
            "dismiss_reason_code": .string(safeErrorCode(dismissReasonCode))
        ])
    }

    nonisolated static func trackPurchaseFlow(
        productTier: String,
        storeKitStep: String,
        storeKitStatus: String,
        startedAt: Date? = nil,
        errorCode: String = "none"
    ) {
        fireAndForget(.purchaseFlowStatus, payload: [
            "product_tier": .string(safeEnum(productTier)),
            "storekit_step": .string(safeEnum(storeKitStep)),
            "storekit_status": .string(safeEnum(storeKitStatus)),
            "error_code": .string(safeErrorCode(errorCode)),
            "duration_ms_bucket": .string(durationBucket(since: startedAt))
        ])
    }

    nonisolated static func trackCrashDiagnostic(
        diagnosticType: String,
        signalSource: String,
        severity: String,
        count: Int = 1,
        terminationState: String = "unknown",
        errorCode: String = "none"
    ) {
        fireAndForget(.crashDiagnostic, payload: [
            "diagnostic_type": .string(safeEnum(diagnosticType)),
            "signal_source": .string(safeEnum(signalSource)),
            "severity": .string(safeEnum(severity)),
            "count_bucket": .string(countBucket(count)),
            "termination_state": .string(safeEnum(terminationState)),
            "error_code": .string(safeErrorCode(errorCode))
        ])
    }

    nonisolated static func trackPerformanceDiagnostic(
        diagnosticType: String,
        surface: String,
        operation: String,
        startedAt: Date? = nil,
        count: Int = 1,
        severity: String = "info",
        result: String = "completed",
        errorCode: String = "none"
    ) {
        fireAndForget(.performanceDiagnostic, payload: [
            "diagnostic_type": .string(safeEnum(diagnosticType)),
            "surface": .string(safeEnum(surface)),
            "operation": .string(safeEnum(operation)),
            "duration_ms_bucket": .string(durationBucket(since: startedAt)),
            "count_bucket": .string(countBucket(count)),
            "severity": .string(safeEnum(severity)),
            "result": .string(safeEnum(result)),
            "error_code": .string(safeErrorCode(errorCode))
        ])
    }

    nonisolated static func trackUIResponsiveness(
        surface: String,
        operation: String,
        startedAt: Date
    ) {
        Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(120))
            trackPerformanceDiagnostic(
                diagnosticType: "ui_response",
                surface: surface,
                operation: operation,
                startedAt: startedAt,
                severity: severity(forDurationSince: startedAt)
            )
        }
    }

    nonisolated static func httpStatusBucket(_ statusCode: Int) -> String {
        switch statusCode {
        case 200...299:
            return "2xx"
        case 300...399:
            return "3xx"
        case 400...499:
            return "4xx"
        case 500...599:
            return "5xx"
        default:
            return "other"
        }
    }

    nonisolated static func durationBucket(since startedAt: Date?) -> String {
        guard let startedAt else { return "not_measured" }
        let milliseconds = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
        switch milliseconds {
        case 0..<1_000:
            return "under_1s"
        case 1_000..<3_000:
            return "1s_3s"
        case 3_000..<10_000:
            return "3s_10s"
        case 10_000..<30_000:
            return "10s_30s"
        default:
            return "over_30s"
        }
    }

    nonisolated private static func severity(forDurationSince startedAt: Date) -> String {
        let milliseconds = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
        switch milliseconds {
        case 0..<1_000:
            return "info"
        case 1_000..<3_000:
            return "notice"
        case 3_000..<10_000:
            return "warning"
        default:
            return "critical"
        }
    }

    nonisolated static func errorCode(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "not_connected"
            case .timedOut:
                return "timeout"
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "network_unreachable"
            case .cancelled:
                return "cancelled"
            default:
                return "network_error"
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            return "cocoa_error_\(nsError.code)"
        }
        return safeErrorCode(String(describing: type(of: error)))
    }

    nonisolated private static func fireAndForget(
        _ name: AutoLedgerAnalyticsEventName,
        payload: [String: AutoLedgerAnalyticsPayloadValue]
    ) {
        Task.detached(priority: .utility) {
            await uploadEvent(name, payload: payload)
        }
    }

    nonisolated private static func uploadEvent(
        _ name: AutoLedgerAnalyticsEventName,
        payload: [String: AutoLedgerAnalyticsPayloadValue]
    ) async {
        let appVersion = appVersion
        let buildNumber = buildNumber
        let osMajor = "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
        let deviceClass = deviceClass
        var completePayload = metadataPayload(appVersion: appVersion)
        for (key, value) in payload {
            completePayload[key] = value
        }

        do {
            let event = try AutoLedgerAnalyticsEvent.make(name, payload: completePayload)
            try await AutoLedgerAnalyticsUploadClient().upload(
                events: [event],
                appVersion: appVersion,
                buildNumber: buildNumber,
                osMajor: osMajor,
                deviceClass: deviceClass
            )
        } catch {
            commonAPIAnalyticsLogger.warning("[CommonAPI] analytics upload skipped: \(error.localizedDescription)")
        }
    }

    nonisolated private static func metadataPayload(
        appVersion: String
    ) -> [String: AutoLedgerAnalyticsPayloadValue] {
        [
            "event_id": .string(UUID().uuidString),
            "app_version": .string(appVersion)
        ]
    }

    nonisolated private static func retryCountBucket(_ count: Int) -> String {
        switch max(0, count) {
        case 0:
            return "0"
        case 1:
            return "1"
        case 2:
            return "2"
        default:
            return "3_plus"
        }
    }

    nonisolated private static func countBucket(_ count: Int) -> String {
        switch max(0, count) {
        case 0:
            return "0"
        case 1:
            return "1"
        case 2:
            return "2"
        case 3...5:
            return "3_5"
        default:
            return "6_plus"
        }
    }

    nonisolated private static func pageCountBucket(_ count: Int?) -> String {
        guard let count, count > 0 else { return "unknown" }
        switch count {
        case 1:
            return "1"
        case 2...3:
            return "2_3"
        case 4...10:
            return "4_10"
        default:
            return "11_plus"
        }
    }

    nonisolated private static func safeEnum(_ rawValue: String) -> String {
        let cleaned = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9._-]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
        return cleaned.isEmpty ? "unknown" : String(cleaned.prefix(64))
    }

    nonisolated private static func safeErrorCode(_ rawValue: String) -> String {
        let cleaned = safeEnum(rawValue)
        return cleaned.isEmpty ? "unknown" : cleaned
    }

    nonisolated private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    nonisolated private static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    nonisolated private static var deviceClass: String {
        #if targetEnvironment(macCatalyst)
        return "mac"
        #elseif os(iOS)
        return "ios"
        #else
        return "unknown"
        #endif
    }
}
