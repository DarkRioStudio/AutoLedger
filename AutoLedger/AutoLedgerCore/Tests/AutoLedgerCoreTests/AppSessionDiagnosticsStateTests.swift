import Foundation
import XCTest
@testable import AutoLedgerCore

final class AppSessionDiagnosticsStateTests: XCTestCase {
    private func withState(_ test: (AppSessionDiagnosticsState) -> Void) {
        let name = "AppSessionDiagnosticsStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        test(AppSessionDiagnosticsState(defaults: defaults))
    }

    func testBackgroundOnlyLaunchDoesNotCreateARecoverySignal() {
        withState { state in
            let now = Date()
            XCTAssertFalse(state.beginLaunch(at: now))
            XCTAssertFalse(state.beginLaunch(at: now.addingTimeInterval(60)))
        }
    }

    func testInterruptedActiveSessionIsReportedOnceEvenAcrossBackgroundLaunches() {
        withState { state in
            let now = Date()
            XCTAssertFalse(state.beginLaunch(at: now))
            state.markActive(at: now)
            XCTAssertTrue(state.beginLaunch(at: now.addingTimeInterval(60)))
            XCTAssertFalse(state.beginLaunch(at: now.addingTimeInterval(120)))
        }
    }

    func testInactiveInterruptionKeepsActiveMarkerUntilAllScenesBackground() {
        withState { state in
            let now = Date()
            state.markActive(at: now)
            // No clean-background transition for a temporary inactive state.
            XCTAssertTrue(state.beginLaunch(at: now.addingTimeInterval(60)))
            state.markActive(at: now.addingTimeInterval(120))
            state.markCleanBackground(at: now.addingTimeInterval(180))
            XCTAssertFalse(state.beginLaunch(at: now.addingTimeInterval(240)))
        }
    }

    func testOldActiveMarkerDoesNotReportRecentRecovery() {
        withState { state in
            let now = Date()
            state.markActive(at: now.addingTimeInterval(-25 * 60 * 60))
            XCTAssertFalse(state.beginLaunch(at: now))
        }
    }
}
