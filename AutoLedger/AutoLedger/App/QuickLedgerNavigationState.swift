import Foundation

@MainActor
final class QuickLedgerNavigationState {
    static let shared = QuickLedgerNavigationState()

    private var isOpenLedgerPending = false
    private var isCreateTransactionPending = false
    private var editTransactionPending: UUID?

    private init() {}

    var hasEditTransactionPending: Bool { editTransactionPending != nil }

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

    func markEditTransactionPending(_ transactionID: UUID) {
        editTransactionPending = transactionID
    }

    /// Consume only after the root view has refreshed persisted entries, so a
    /// notification received during a cold launch can still open its exact entry.
    func consumeEditTransactionPending() -> UUID? {
        defer { editTransactionPending = nil }
        return editTransactionPending
    }
}
