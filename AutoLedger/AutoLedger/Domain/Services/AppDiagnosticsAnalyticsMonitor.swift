import Foundation
import MetricKit
import OSLog

@MainActor
final class AppDiagnosticsAnalyticsMonitor: NSObject {
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

    nonisolated private static func trackDiagnostic(
        type: String,
        count: Int,
        severity: String
    ) {
        guard count > 0 else { return }
        CommonAPIAnalyticsService.trackCrashDiagnostic(
            diagnosticType: type,
            signalSource: "metrickit",
            severity: severity,
            count: count,
            terminationState: "unknown"
        )
    }

    nonisolated private static func trackPerformance(
        type: String,
        operation: String,
        count: Int,
        severity: String
    ) {
        guard count > 0 else { return }
        CommonAPIAnalyticsService.trackPerformanceDiagnostic(
            diagnosticType: type,
            surface: "system",
            operation: operation,
            count: count,
            severity: severity,
            result: "reported_by_metrickit"
        )
    }
}

extension AppDiagnosticsAnalyticsMonitor: MXMetricManagerSubscriber {
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let crashCount = payload.crashDiagnostics?.count ?? 0
            let hangCount = payload.hangDiagnostics?.count ?? 0
            let cpuExceptionCount = payload.cpuExceptionDiagnostics?.count ?? 0
            let diskWriteExceptionCount = payload.diskWriteExceptionDiagnostics?.count ?? 0

            Self.trackDiagnostic(type: "crash", count: crashCount, severity: "critical")
            Self.trackDiagnostic(type: "hang", count: hangCount, severity: "warning")
            Self.trackPerformance(type: "hang", operation: "system_hang", count: hangCount, severity: "warning")
            Self.trackPerformance(type: "cpu_exception", operation: "system_cpu_exception", count: cpuExceptionCount, severity: "warning")
            Self.trackPerformance(type: "disk_write_exception", operation: "system_disk_write_exception", count: diskWriteExceptionCount, severity: "warning")
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

enum AppSessionDiagnosticsService {
    private static let stateKey = "appDiagnostics.sessionState.v1"
    private static let timestampKey = "appDiagnostics.sessionTimestamp.v1"

    nonisolated static func recordLaunchRecoveryIfNeeded() {
        let defaults = UserDefaults.standard
        let previousState = defaults.string(forKey: stateKey) ?? "unknown"
        let previousTimestamp = defaults.object(forKey: timestampKey) as? Date
        if previousState == "active", isRecent(previousTimestamp) {
            CommonAPIAnalyticsService.trackCrashDiagnostic(
                diagnosticType: "unclean_active_session",
                signalSource: "session_marker",
                severity: "warning",
                count: 1,
                terminationState: previousState
            )
        }
        markActive()
    }

    nonisolated static func markActive() {
        write(state: "active")
    }

    nonisolated static func markCleanBackground() {
        write(state: "background_clean")
    }

    nonisolated private static func write(state: String) {
        let defaults = UserDefaults.standard
        defaults.set(state, forKey: stateKey)
        defaults.set(Date(), forKey: timestampKey)
    }

    nonisolated private static func isRecent(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Date().timeIntervalSince(date) < 24 * 60 * 60
    }
}
