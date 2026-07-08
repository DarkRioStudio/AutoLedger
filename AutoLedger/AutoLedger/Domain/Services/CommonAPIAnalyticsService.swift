import AutoLedgerCore
import Foundation
import OSLog

nonisolated private let commonAPIAnalyticsLogger = Logger(
    subsystem: "top.darkrio326.AutoLedger",
    category: "CommonAPIAnalytics"
)

enum CommonAPIAnalyticsService {
    nonisolated static func uploadLaunchEvent() async {
        let appVersion = appVersion
        let buildNumber = buildNumber
        let osMajor = "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
        let deviceClass = deviceClass

        do {
            let event = try AutoLedgerAnalyticsEvent.make(.appLaunchPerformance, payload: [
                "event_id": .string(UUID().uuidString),
                "app_version": .string(appVersion),
                "build_number": .string(buildNumber),
                "os_major": .string(osMajor),
                "device_class": .string(deviceClass),
                "launch_type": .string("foreground"),
                "duration_ms_bucket": .string("not_measured"),
                "result": .string("success"),
                "error_code": .string("none")
            ])
            try await AutoLedgerAnalyticsUploadClient().upload(
                events: [event],
                appVersion: appVersion,
                buildNumber: buildNumber,
                osMajor: osMajor,
                deviceClass: deviceClass
            )
            commonAPIAnalyticsLogger.info("[CommonAPI] anonymous launch analytics uploaded")
        } catch {
            commonAPIAnalyticsLogger.warning("[CommonAPI] analytics upload skipped: \(error.localizedDescription)")
        }
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
