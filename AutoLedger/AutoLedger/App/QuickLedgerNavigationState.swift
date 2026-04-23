import Foundation

@MainActor
final class QuickLedgerNavigationState {
    static let shared = QuickLedgerNavigationState()

    private var isOpenLedgerPending = false
    private var isCreateTransactionPending = false

    private init() {}

    func markOpenLedgerPending() {
        isOpenLedgerPending = true
    }

    func markCreateTransactionPending() {
        isOpenLedgerPending = true
        isCreateTransactionPending = true
    }

    func consumeOpenLedgerPending() -> Bool {
        let pending = isOpenLedgerPending
        isOpenLedgerPending = false
        return pending
    }

    func consumeCreateTransactionPending() -> Bool {
        let pending = isCreateTransactionPending
        isCreateTransactionPending = false
        return pending
    }
}
