import Foundation

/// Stable, user-facing sync states. Detailed CloudKit phases and counters stay
/// in developer diagnostics instead of becoming part of the product contract.
public enum LedgerUserSyncState: String, Codable, CaseIterable, Sendable {
    case disabled
    case checkingAccount
    case syncing
    case waitingToUpload
    case upToDate
    case offline
    case needsConflictReview
    case failedWithLocalDataSafe

    public var localDataRemainsAvailable: Bool {
        switch self {
        case .offline, .needsConflictReview, .failedWithLocalDataSafe:
            return true
        case .disabled, .checkingAccount, .syncing, .waitingToUpload, .upToDate:
            return false
        }
    }
}

public struct LedgerUserSyncStatus: Codable, Equatable, Sendable {
    public let state: LedgerUserSyncState
    public let lastSuccessfulSyncAt: Date?
    public let conflictCount: Int

    public init(
        state: LedgerUserSyncState,
        lastSuccessfulSyncAt: Date? = nil,
        conflictCount: Int = 0
    ) {
        self.state = state
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        self.conflictCount = max(0, conflictCount)
    }

    public var needsAttention: Bool {
        switch state {
        case .offline, .needsConflictReview, .failedWithLocalDataSafe:
            return true
        case .disabled, .checkingAccount, .syncing, .waitingToUpload, .upToDate:
            return false
        }
    }
}

public enum LedgerUserSyncStatusResolver {
    public static func resolve(
        isEnabled: Bool,
        activityState: LedgerUserSyncState,
        lastSuccessfulSyncAt: Date?,
        conflictCount: Int
    ) -> LedgerUserSyncStatus {
        guard isEnabled else {
            return LedgerUserSyncStatus(
                state: .disabled,
                lastSuccessfulSyncAt: lastSuccessfulSyncAt
            )
        }

        let normalizedConflictCount = max(0, conflictCount)
        let resolvedState: LedgerUserSyncState
        switch activityState {
        case .checkingAccount, .syncing, .offline, .failedWithLocalDataSafe:
            resolvedState = activityState
        case .disabled, .waitingToUpload, .upToDate, .needsConflictReview:
            resolvedState = normalizedConflictCount > 0
                ? .needsConflictReview
                : activityState == .disabled ? .waitingToUpload : activityState
        }

        return LedgerUserSyncStatus(
            state: resolvedState,
            lastSuccessfulSyncAt: lastSuccessfulSyncAt,
            conflictCount: normalizedConflictCount
        )
    }
}
