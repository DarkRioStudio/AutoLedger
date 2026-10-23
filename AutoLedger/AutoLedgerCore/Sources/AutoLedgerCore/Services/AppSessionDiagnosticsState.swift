import Foundation

/// Persists a foreground-session hint. Background-only launches are not active sessions.
/// A missing clean marker is a recovery signal, never proof of a crash.
public final class AppSessionDiagnosticsState {
    private let defaults: UserDefaults
    private let stateKey = "appDiagnostics.sessionState.v1"
    private let timestampKey = "appDiagnostics.sessionTimestamp.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func beginLaunch(at date: Date = Date()) -> Bool {
        let wasActive = defaults.string(forKey: stateKey) == "active"
        let timestamp = defaults.object(forKey: timestampKey) as? Date
        let shouldReportRecovery = wasActive && timestamp.map { date.timeIntervalSince($0) < 24 * 60 * 60 } == true
        // Consume the previous marker even if this process never presents a foreground scene.
        write(state: "launching", at: date)
        return shouldReportRecovery
    }

    public func markActive(at date: Date = Date()) {
        write(state: "active", at: date)
    }

    public func markCleanBackground(at date: Date = Date()) {
        write(state: "background_clean", at: date)
    }

    private func write(state: String, at date: Date) {
        defaults.set(state, forKey: stateKey)
        defaults.set(date, forKey: timestampKey)
    }
}
