import AutoLedgerCore
import Combine
import Foundation
import SwiftUI

enum SettingsNavigationTarget: Hashable {
    case ledgerProfiles
}

struct SubscriptionEditorPresentation: Identifiable {
    enum Mode {
        case create
        case edit
    }

    let id = UUID()
    let mode: Mode
    let subscription: Subscription

    var isNew: Bool {
        mode == .create
    }

    static var create: SubscriptionEditorPresentation {
        SubscriptionEditorPresentation(
            mode: .create,
            subscription: Subscription(
                merchant: "",
                planName: "",
                period: .monthly,
                amount: 0,
                lastChargedAt: .now,
                status: .active
            )
        )
    }

    static func edit(_ subscription: Subscription) -> SubscriptionEditorPresentation {
        SubscriptionEditorPresentation(mode: .edit, subscription: subscription)
    }
}

@MainActor
final class AutoLedgerNavigationState: ObservableObject {
    @Published var selectedHomeTab = AutoLedgerHomeTab.inbox.rawValue
    @Published var settingsPath: [SettingsNavigationTarget] = []

    @Published var selectedLedgerTransactionID: UUID?
    @Published var ledgerTransactionPendingMove: Transaction?
    @Published var isPresentingNewTransaction = false
    @Published var isPresentingVoiceLedger = false
    @Published var isPresentingDeletedTransactions = false
    @Published var isPresentingLedgerProfiles = false

    @Published var selectedSubscriptionID: UUID?
    @Published var subscriptionEditor: SubscriptionEditorPresentation?

    func openLedgerTab() {
        selectedHomeTab = AutoLedgerHomeTab.ledger.rawValue
    }

    func openLedgerProfiles() {
        selectedHomeTab = AutoLedgerHomeTab.settings.rawValue
        settingsPath = [.ledgerProfiles]
    }
}

enum AutoLedgerHomeTab: Int {
    case inbox = 0
    case ledger = 1
    case hotelStays = 2
    case report = 3
    case settings = 4
}
