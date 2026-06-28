import AutoLedgerCore
import Combine
import Foundation
import SwiftUI

enum SettingsNavigationTarget: Hashable {
    case ledgerProfiles
    case subscriptions
}

enum AutoLedgerDeepLinkDestination: Equatable {
    case ledger
    case ledgerToday
    case transaction(UUID)
    case hotelStay(UUID)
    case hotelReviewQueue(UUID?)
    case subscriptions
    case ledgerProfiles
    case scan
    case quickAdd
}

enum AutoLedgerDeepLinkParser {
    static let scheme = "autoledger"

    static func parse(_ url: URL) -> AutoLedgerDeepLinkDestination? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        let parts = destinationParts(from: url)
        guard let first = parts.first else { return .scan }

        switch first {
        case "ledger":
            if parts.dropFirst().first == "today" {
                return .ledgerToday
            }
            return .ledger
        case "transaction":
            guard let id = uuid(from: parts.dropFirst().first) else { return nil }
            return .transaction(id)
        case "hotel-stay", "hotelstay":
            guard let id = uuid(from: parts.dropFirst().first) else { return nil }
            return .hotelStay(id)
        case "hotel-stays", "hotelstays", "hotel-review", "hotelreview":
            return .hotelReviewQueue(uuid(from: queryItems(from: url)["draftID"]))
        case "subscriptions", "subscription":
            return .subscriptions
        case "settings":
            guard parts.dropFirst().first == "ledger-profiles" else { return nil }
            return .ledgerProfiles
        case "scan", "inbox":
            return .scan
        case "quick-add", "quickadd", "add":
            return .quickAdd
        default:
            return nil
        }
    }

    private static func destinationParts(from url: URL) -> [String] {
        let host = url.host(percentEncoded: false)
        let pathParts = url.pathComponents.filter { $0 != "/" }
        return ([host].compactMap { $0 } + pathParts)
            .compactMap { $0.removingPercentEncoding }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private static func uuid(from value: String?) -> UUID? {
        guard let value else { return nil }
        return UUID(uuidString: value)
    }

    private static func queryItems(from url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return [:]
        }
        return Dictionary(
            uniqueKeysWithValues: components.queryItems?
                .compactMap { item -> (String, String)? in
                    guard let value = item.value else { return nil }
                    return (item.name, value)
                } ?? []
        )
    }
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

    @Published var selectedHotelStayRecordID: UUID?
    @Published var pendingHotelStayDraftReviewID: UUID?

    @Published var selectedSubscriptionID: UUID?
    @Published var subscriptionEditor: SubscriptionEditorPresentation?

    func openLedgerTab() {
        selectedHomeTab = AutoLedgerHomeTab.ledger.rawValue
    }

    func openLedgerProfiles() {
        selectedHomeTab = AutoLedgerHomeTab.settings.rawValue
        settingsPath = [.ledgerProfiles]
    }

    func openHotelReviewQueue(draftID: UUID? = nil) {
        selectedHomeTab = AutoLedgerHomeTab.hotelStays.rawValue
        if let draftID {
            pendingHotelStayDraftReviewID = draftID
        }
    }

    @discardableResult
    func openDeepLink(_ url: URL, store: LedgerStore) -> Bool {
        guard let destination = AutoLedgerDeepLinkParser.parse(url) else { return false }
        open(destination, store: store)
        return true
    }

    func open(_ destination: AutoLedgerDeepLinkDestination, store: LedgerStore) {
        switch destination {
        case .ledger, .ledgerToday:
            openLedgerTab()
        case .transaction(let id):
            selectLedgerForTransaction(id, store: store)
            selectedHomeTab = AutoLedgerHomeTab.ledger.rawValue
            selectedLedgerTransactionID = id
        case .hotelStay(let id):
            selectLedgerForHotelStay(id, store: store)
            selectedHomeTab = AutoLedgerHomeTab.hotelStays.rawValue
            selectedHotelStayRecordID = id
        case .hotelReviewQueue(let draftID):
            openHotelReviewQueue(draftID: draftID)
        case .subscriptions:
            selectedHomeTab = AutoLedgerHomeTab.settings.rawValue
            settingsPath = [.subscriptions]
        case .ledgerProfiles:
            openLedgerProfiles()
        case .scan:
            selectedHomeTab = AutoLedgerHomeTab.inbox.rawValue
        case .quickAdd:
            selectedHomeTab = AutoLedgerHomeTab.ledger.rawValue
            isPresentingNewTransaction = true
        }
    }

    private func selectLedgerForTransaction(_ id: UUID, store: LedgerStore) {
        guard let transaction = store.transactions.first(where: { $0.id == id }),
              let profile = store.activeLedgerProfiles.first(where: { $0.id == transaction.resolvedLedgerID() }) else {
            return
        }
        store.selectLedgerProfile(profile)
    }

    private func selectLedgerForHotelStay(_ id: UUID, store: LedgerStore) {
        guard let record = store.hotelStayRecords.first(where: { $0.id == id }),
              let profile = store.activeLedgerProfiles.first(where: { $0.id == record.ledgerID }) else {
            return
        }
        store.selectLedgerProfile(profile)
    }
}

enum AutoLedgerHomeTab: Int {
    case inbox = 0
    case ledger = 1
    case hotelStays = 2
    case report = 3
    case settings = 4
}
