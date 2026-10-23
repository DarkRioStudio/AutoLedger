import Foundation
import AutoLedgerCore
import MetricKit
import OSLog

@MainActor
final class AppDiagnosticsAnalyticsMonitor: NSObject {
    private struct DiagnosticSource: Hashable {
        let appVersion: String
        let buildNumber: String
    }

    static let shared = AppDiagnosticsAnalyticsMonitor()

    private static let logger = Logger(
        subsystem: "top.darkrio326.AutoLedger",
        category: "AppDiagnosticsAnalytics"
    )

    private var isStarted = false

    private override init() {
        super.init()
    }

    func startIfNeeded() {
        guard !isStarted else { return }
        isStarted = true
        MXMetricManager.shared.add(self)
        Self.logger.info("[Diagnostics] MetricKit subscriber started")
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

    nonisolated private static func trackDiagnostics<T: MXDiagnostic>(
        type: String,
        diagnostics: [T],
        severity: String
    ) {
        for (source, count) in diagnosticSourceCounts(diagnostics) {
            CommonAPIAnalyticsService.trackCrashDiagnostic(
                diagnosticType: type,
                signalSource: "metrickit",
                severity: severity,
                count: count,
                terminationState: "unknown",
                diagnosticAppVersion: source.appVersion,
                diagnosticBuildNumber: source.buildNumber
            )
        }
    }

    nonisolated private static func trackPerformanceDiagnostics<T: MXDiagnostic>(
        type: String,
        operation: String,
        diagnostics: [T],
        severity: String
    ) {
        for (source, count) in diagnosticSourceCounts(diagnostics) {
            CommonAPIAnalyticsService.trackPerformanceDiagnostic(
                diagnosticType: type,
                surface: "system",
                operation: operation,
                count: count,
                severity: severity,
                result: "reported_by_metrickit",
                diagnosticAppVersion: source.appVersion,
                diagnosticBuildNumber: source.buildNumber
            )
        }
    }

    nonisolated private static func diagnosticSourceCounts<T: MXDiagnostic>(
        _ diagnostics: [T]
    ) -> [DiagnosticSource: Int] {
        diagnostics.reduce(into: [:]) { counts, diagnostic in
            let source = DiagnosticSource(
                appVersion: diagnostic.applicationVersion,
                buildNumber: diagnostic.metaData.applicationBuildVersion
            )
            counts[source, default: 0] += 1
        }
    }
}

extension AppDiagnosticsAnalyticsMonitor: MXMetricManagerSubscriber {
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let crashDiagnostics = payload.crashDiagnostics ?? []
            let hangDiagnostics = payload.hangDiagnostics ?? []
            let cpuExceptionDiagnostics = payload.cpuExceptionDiagnostics ?? []
            let diskWriteExceptionDiagnostics = payload.diskWriteExceptionDiagnostics ?? []

            Self.trackDiagnostics(type: "crash", diagnostics: crashDiagnostics, severity: "critical")
            Self.trackDiagnostics(type: "hang", diagnostics: hangDiagnostics, severity: "warning")
            Self.trackPerformanceDiagnostics(type: "hang", operation: "system_hang", diagnostics: hangDiagnostics, severity: "warning")
            Self.trackPerformanceDiagnostics(type: "cpu_exception", operation: "system_cpu_exception", diagnostics: cpuExceptionDiagnostics, severity: "warning")
            Self.trackPerformanceDiagnostics(type: "disk_write_exception", operation: "system_disk_write_exception", diagnostics: diskWriteExceptionDiagnostics, severity: "warning")
        }
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        guard !payloads.isEmpty else { return }
        CommonAPIAnalyticsService.trackPerformanceDiagnostic(
            diagnosticType: "metrickit_metric_payload",
            surface: "system",
            operation: "system_daily_metrics",
            count: payloads.count,
            severity: "info",
            result: "received"
        )
    }
}

@MainActor
enum AppSessionDiagnosticsService {
    private static let state = AppSessionDiagnosticsState()

    static func recordLaunchRecoveryIfNeeded() {
        if state.beginLaunch() {
            // This is a recovery hint for the preceding session, not a failed current launch.
            CommonAPIAnalyticsService.trackCrashDiagnostic(
                diagnosticType: "unclean_active_session",
                signalSource: "session_marker",
                severity: "warning",
                count: 1,
                terminationState: "active"
            )
        }
    }

    static func markActive() {
        state.markActive()
    }

    static func markCleanBackground() {
        state.markCleanBackground()
    }
}
