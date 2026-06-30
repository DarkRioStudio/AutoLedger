import AutoLedgerCore
import Foundation

protocol ServerEntitlementVerifying: Sendable {
    func verifyAccess(
        capability: AutoLedgerCapability,
        localSubscriptionSnapshot: ProSubscriptionSnapshot?
    ) async throws -> ServerEntitlementVerificationResult
}

struct ServerEntitlementVerificationResult: Equatable, Sendable {
    let allowed: Bool
    let reason: String?
    let expiresAt: Date?

    init(allowed: Bool, reason: String? = nil, expiresAt: Date? = nil) {
        self.allowed = allowed
        self.reason = reason
        self.expiresAt = expiresAt
    }
}

struct UnavailableServerEntitlementVerifier: ServerEntitlementVerifying {
    func verifyAccess(
        capability: AutoLedgerCapability,
        localSubscriptionSnapshot: ProSubscriptionSnapshot?
    ) async throws -> ServerEntitlementVerificationResult {
        ServerEntitlementVerificationResult(
            allowed: false,
            reason: "server_entitlement_verifier_unavailable",
            expiresAt: localSubscriptionSnapshot?.expirationDate
        )
    }
}

struct StubServerEntitlementVerifier: ServerEntitlementVerifying {
    var result: ServerEntitlementVerificationResult

    init(result: ServerEntitlementVerificationResult) {
        self.result = result
    }

    func verifyAccess(
        capability: AutoLedgerCapability,
        localSubscriptionSnapshot: ProSubscriptionSnapshot?
    ) async throws -> ServerEntitlementVerificationResult {
        result
    }
}
