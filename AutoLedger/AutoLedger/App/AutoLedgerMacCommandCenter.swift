import Foundation
import SwiftUI

@MainActor
final class AutoLedgerMacCommandCenter {
    enum Command: Sendable {
        case importFiles
        case importCSV
        case exportCSV
        case exportJSON
        case openSettings
    }

    static let shared = AutoLedgerMacCommandCenter()
    static let didPerformCommand = Notification.Name("AutoLedger.macCommandCenter.didPerformCommand")

    private(set) var pendingCommand: Command?

    private init() {}

    func perform(_ command: Command) {
        pendingCommand = command
        NotificationCenter.default.post(name: Self.didPerformCommand, object: command)
    }

    @discardableResult
    func consume(_ command: Command) -> Bool {
        guard pendingCommand == command else { return false }
        pendingCommand = nil
        return true
    }
}

#if targetEnvironment(macCatalyst)
struct AutoLedgerMacCommands: Commands {
    var body: some Commands {
        CommandMenu(String(localized: "mac.menu.import")) {
            Button(String(localized: "mac.menu.import.files")) {
                Task { @MainActor in
                    AutoLedgerMacCommandCenter.shared.perform(.importFiles)
                }
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button(String(localized: "mac.menu.import.csv")) {
                Task { @MainActor in
                    AutoLedgerMacCommandCenter.shared.perform(.importCSV)
                }
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }

        CommandMenu(String(localized: "mac.menu.export")) {
            Button(String(localized: "mac.menu.export.csv")) {
                Task { @MainActor in
                    AutoLedgerMacCommandCenter.shared.perform(.exportCSV)
                }
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }

        CommandMenu(String(localized: "mac.menu.backup")) {
            Button(String(localized: "mac.menu.backup.json")) {
                Task { @MainActor in
                    AutoLedgerMacCommandCenter.shared.perform(.exportJSON)
                }
            }
            .keyboardShortcut("b", modifiers: [.command, .option])
        }

        CommandGroup(after: .appSettings) {
            Button(String(localized: "mac.menu.settings")) {
                Task { @MainActor in
                    AutoLedgerMacCommandCenter.shared.perform(.openSettings)
                }
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}
#endif
