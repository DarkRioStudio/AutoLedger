actor QuickLedgerNavigationState {
    static let shared = QuickLedgerNavigationState()

    private var isOpenLedgerPending = false

    func markOpenLedgerPending() {
        isOpenLedgerPending = true
    }

    func consumeOpenLedgerPending() -> Bool {
        let pending = isOpenLedgerPending
        isOpenLedgerPending = false
        return pending
    }
}
