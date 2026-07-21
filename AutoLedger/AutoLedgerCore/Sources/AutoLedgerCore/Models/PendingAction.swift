import Foundation

public enum PendingActionCategory: String, Codable, CaseIterable, Sendable {
    case receiptReview
    case hotelReview
    case duplicateReview
    case subscriptionAnomaly
    case cleaningSuggestion
}

public enum PendingActionPriority: Int, Codable, Comparable, Sendable {
    case normal = 0
    case elevated = 1
    case urgent = 2

    public static func < (lhs: PendingActionPriority, rhs: PendingActionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum PendingActionKind: String, Codable, CaseIterable, Sendable {
    case receiptConfirmation
    case hotelDraftReview
    case duplicateCandidate
    case subscriptionAnomaly
    case cleaningSuggestion

    public var category: PendingActionCategory {
        switch self {
        case .receiptConfirmation: return .receiptReview
        case .hotelDraftReview: return .hotelReview
        case .duplicateCandidate: return .duplicateReview
        case .subscriptionAnomaly: return .subscriptionAnomaly
        case .cleaningSuggestion: return .cleaningSuggestion
        }
    }

    public var defaultPriority: PendingActionPriority {
        switch self {
        case .receiptConfirmation, .hotelDraftReview:
            return .urgent
        case .duplicateCandidate, .subscriptionAnomaly:
            return .elevated
        case .cleaningSuggestion:
            return .normal
        }
    }

    public var isProAutomation: Bool {
        switch self {
        case .duplicateCandidate, .subscriptionAnomaly, .cleaningSuggestion:
            return true
        case .receiptConfirmation, .hotelDraftReview:
            return false
        }
    }

    public var target: PendingActionTarget {
        switch self {
        case .receiptConfirmation: return .receiptReview
        case .hotelDraftReview: return .hotelReview
        case .duplicateCandidate, .cleaningSuggestion: return .dataCleaning
        case .subscriptionAnomaly: return .subscriptions
        }
    }

    public var defaultActions: [PendingActionAvailableAction] {
        switch self {
        case .receiptConfirmation, .hotelDraftReview, .subscriptionAnomaly,
             .duplicateCandidate, .cleaningSuggestion:
            return [.open, .confirm, .`defer`, .dismiss, .reopen]
        }
    }
}

public enum PendingActionSourceType: String, Codable, CaseIterable, Sendable {
    case receiptImportReview
    case hotelStayDraft
    case dataCleaningPreview
    case subscriptionAnomaly
}

public struct PendingActionSourceReference: Codable, Hashable, Sendable {
    public let type: PendingActionSourceType
    public let id: String
    public let revision: String?

    public init(type: PendingActionSourceType, id: String, revision: String? = nil) {
        self.type = type
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRevision = revision?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.revision = normalizedRevision?.isEmpty == false ? normalizedRevision : nil
    }

    public var isValid: Bool { !id.isEmpty }

    public static func opaqueID(for rawValue: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in Data(rawValue.utf8) {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "src_" + String(format: "%016llx", CUnsignedLongLong(hash))
    }
}

public struct PendingActionID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(kind: PendingActionKind, source: PendingActionSourceReference) {
        let encodedID = Data(source.id.utf8).base64EncodedString()
        let revisionComponent = source.revision.map { "value:\($0)" } ?? "none"
        let encodedRevision = Data(revisionComponent.utf8).base64EncodedString()
        self.rawValue = [
            "pa1",
            kind.rawValue,
            source.type.rawValue,
            encodedID,
            encodedRevision
        ].joined(separator: ".")
    }

    public var description: String { rawValue }
}

public enum PendingActionReasonCode: String, Codable, CaseIterable, Sendable {
    case receiptNeedsConfirmation
    case hotelDraftNeedsReview
    case suspectedDuplicate
    case subscriptionPriceIncrease
    case subscriptionDuplicateCharge
    case subscriptionBillingCycleDrift
    case merchantNormalizationSuggested
    case categoryCorrectionSuggested

    public var localizationKey: String {
        "pending_action.reason.\(rawValue)"
    }
}

public enum PendingActionState: String, Codable, CaseIterable, Sendable {
    case pending
    case deferred
    case resolved
    case dismissed

    public var isActionable: Bool {
        self == .pending || self == .deferred
    }
}

public enum PendingActionAvailableAction: String, Codable, CaseIterable, Sendable {
    case open
    case confirm
    case `defer`
    case dismiss
    case resolve
    case reopen
}

public enum PendingActionTarget: String, Codable, CaseIterable, Sendable {
    case receiptReview
    case hotelReview
    case dataCleaning
    case subscriptions
}

public enum PendingActionMutation: Equatable, Sendable {
    case deferUntil(Date?)
    case resolve
    case dismiss
    case reopen
}

public enum PendingActionDecisionDisposition: String, Codable, CaseIterable, Sendable {
    case deferred
    case resolved
    case dismissed
    case reopened
}

public struct PendingActionDecision: Identifiable, Codable, Equatable, Sendable {
    public let kind: PendingActionKind
    public let source: PendingActionSourceReference
    public let disposition: PendingActionDecisionDisposition
    public let updatedAt: Date
    public let deferredUntil: Date?

    public var id: PendingActionID {
        PendingActionID(kind: kind, source: source)
    }

    public init(
        kind: PendingActionKind,
        source: PendingActionSourceReference,
        disposition: PendingActionDecisionDisposition,
        updatedAt: Date = .now,
        deferredUntil: Date? = nil
    ) throws {
        guard source.isValid else { throw PendingActionContractError.invalidSourceID }
        self.kind = kind
        self.source = source
        self.disposition = disposition
        self.updatedAt = updatedAt
        self.deferredUntil = disposition == .deferred ? deferredUntil : nil
    }

    public init(
        item: PendingActionItem,
        mutation: PendingActionMutation,
        updatedAt: Date = .now
    ) throws {
        if mutation != .reopen {
            _ = try item.applying(mutation, at: updatedAt)
        }
        let disposition: PendingActionDecisionDisposition
        let deferredUntil: Date?
        switch mutation {
        case let .deferUntil(date):
            disposition = .deferred
            deferredUntil = date
        case .resolve:
            disposition = .resolved
            deferredUntil = nil
        case .dismiss:
            disposition = .dismissed
            deferredUntil = nil
        case .reopen:
            disposition = .reopened
            deferredUntil = nil
        }
        try self.init(
            kind: item.kind,
            source: item.source,
            disposition: disposition,
            updatedAt: updatedAt,
            deferredUntil: deferredUntil
        )
    }

    public func applying(to item: PendingActionItem, at timestamp: Date) -> PendingActionItem {
        guard item.id == id else { return item }
        switch disposition {
        case .deferred:
            if let deferredUntil, deferredUntil <= timestamp {
                return item
            }
            return (try? item.applying(.deferUntil(deferredUntil), at: updatedAt)) ?? item
        case .resolved:
            return (try? item.applying(.resolve, at: updatedAt)) ?? item
        case .dismissed:
            return (try? item.applying(.dismiss, at: updatedAt)) ?? item
        case .reopened:
            return item
        }
    }

    public static func normalizedDictionary(
        _ decisions: [String: PendingActionDecision]
    ) -> [String: PendingActionDecision] {
        decisions.values.reduce(into: [:]) { result, decision in
            guard decision.source.isValid else { return }
            let key = decision.id.rawValue
            guard let existing = result[key] else {
                result[key] = decision
                return
            }
            if decision.isPreferred(over: existing) {
                result[key] = decision
            }
        }
    }

    public func isPreferred(over existing: PendingActionDecision) -> Bool {
        if updatedAt != existing.updatedAt {
            return updatedAt > existing.updatedAt
        }
        if disposition != existing.disposition {
            return disposition.mergeRank > existing.disposition.mergeRank
        }
        let candidateDeferredUntil = deferredUntil?.timeIntervalSince1970 ?? .greatestFiniteMagnitude
        let existingDeferredUntil = existing.deferredUntil?.timeIntervalSince1970 ?? .greatestFiniteMagnitude
        return candidateDeferredUntil >= existingDeferredUntil
    }
}

private extension PendingActionDecisionDisposition {
    var mergeRank: Int {
        switch self {
        case .deferred: return 0
        case .resolved: return 1
        case .dismissed: return 2
        case .reopened: return 3
        }
    }
}

public enum PendingActionDecisionOverlay {
    public static func applying(
        _ decisions: [String: PendingActionDecision],
        to items: [PendingActionItem],
        at timestamp: Date = .now
    ) -> [PendingActionItem] {
        let normalizedDecisions = PendingActionDecision.normalizedDictionary(decisions)
        return items.map { item in
            guard let decision = normalizedDecisions[item.id.rawValue] else { return item }
            return decision.applying(to: item, at: timestamp)
        }
    }
}

public enum PendingActionContractError: Error, Equatable, Sendable {
    case invalidSourceID
    case invalidTransition(from: PendingActionState, mutation: PendingActionMutation)
}

public struct PendingActionItem: Identifiable, Codable, Equatable, Sendable {
    public let id: PendingActionID
    public let kind: PendingActionKind
    public let source: PendingActionSourceReference
    public let reason: PendingActionReasonCode
    public let priority: PendingActionPriority
    public let isProAutomation: Bool
    public let target: PendingActionTarget
    public let availableActions: [PendingActionAvailableAction]
    public private(set) var state: PendingActionState
    public let createdAt: Date
    public private(set) var updatedAt: Date
    public private(set) var resolvedAt: Date?
    public private(set) var deferredUntil: Date?

    public init(
        kind: PendingActionKind,
        source: PendingActionSourceReference,
        reason: PendingActionReasonCode,
        state: PendingActionState = .pending,
        createdAt: Date,
        updatedAt: Date? = nil,
        resolvedAt: Date? = nil,
        deferredUntil: Date? = nil,
        priority: PendingActionPriority? = nil,
        isProAutomation: Bool? = nil,
        target: PendingActionTarget? = nil,
        availableActions: [PendingActionAvailableAction]? = nil
    ) throws {
        guard source.isValid else { throw PendingActionContractError.invalidSourceID }
        self.id = PendingActionID(kind: kind, source: source)
        self.kind = kind
        self.source = source
        self.reason = reason
        self.priority = priority ?? kind.defaultPriority
        self.isProAutomation = isProAutomation ?? kind.isProAutomation
        self.target = target ?? kind.target
        self.availableActions = availableActions ?? kind.defaultActions
        self.state = state
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.resolvedAt = resolvedAt
        self.deferredUntil = deferredUntil
    }

    public var category: PendingActionCategory { kind.category }

    public func isVisible(at timestamp: Date) -> Bool {
        switch state {
        case .pending:
            return true
        case .deferred:
            return deferredUntil.map { $0 <= timestamp } ?? false
        case .resolved, .dismissed:
            return false
        }
    }

    public func applying(_ mutation: PendingActionMutation, at timestamp: Date) throws -> PendingActionItem {
        var copy = self
        switch mutation {
        case let .deferUntil(date):
            guard state == .pending || state == .deferred else {
                throw PendingActionContractError.invalidTransition(from: state, mutation: mutation)
            }
            copy.state = .deferred
            copy.deferredUntil = date
            copy.resolvedAt = nil
        case .resolve:
            guard state.isActionable else {
                throw PendingActionContractError.invalidTransition(from: state, mutation: mutation)
            }
            copy.state = .resolved
            copy.deferredUntil = nil
            copy.resolvedAt = timestamp
        case .dismiss:
            guard state.isActionable else {
                throw PendingActionContractError.invalidTransition(from: state, mutation: mutation)
            }
            copy.state = .dismissed
            copy.deferredUntil = nil
            copy.resolvedAt = timestamp
        case .reopen:
            guard state == .resolved || state == .dismissed else {
                throw PendingActionContractError.invalidTransition(from: state, mutation: mutation)
            }
            copy.state = .pending
            copy.deferredUntil = nil
            copy.resolvedAt = nil
        }
        copy.updatedAt = timestamp
        return copy
    }
}
