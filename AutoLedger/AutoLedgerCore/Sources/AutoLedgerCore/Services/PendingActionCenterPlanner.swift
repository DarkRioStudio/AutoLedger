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

public struct PendingActionGroup: Identifiable, Codable, Equatable, Sendable {
    public var category: PendingActionCategory
    public var count: Int
    public var priority: PendingActionPriority
    public var isProAutomation: Bool

    public var id: PendingActionCategory { category }

    public init(
        category: PendingActionCategory,
        count: Int,
        priority: PendingActionPriority,
        isProAutomation: Bool
    ) {
        self.category = category
        self.count = max(0, count)
        self.priority = priority
        self.isProAutomation = isProAutomation
    }
}

public struct PendingActionCenterSnapshot: Codable, Equatable, Sendable {
    public var groups: [PendingActionGroup]

    public init(groups: [PendingActionGroup] = []) {
        self.groups = groups
    }

    public var totalCount: Int {
        groups.reduce(0) { $0 + $1.count }
    }

    public var isEmpty: Bool {
        totalCount == 0
    }

    public func count(for category: PendingActionCategory) -> Int {
        groups.first { $0.category == category }?.count ?? 0
    }
}

public struct PendingActionCenterPlanner: Sendable {
    public init() {}

    public func buildSnapshot(
        receiptReviewCount: Int,
        hotelReviewCount: Int,
        cleaningSnapshot: DataCleaningPreviewSnapshot,
        subscriptionAnomalyCount: Int
    ) -> PendingActionCenterSnapshot {
        let duplicateCount = cleaningSnapshot.items(kind: .duplicateCandidate).count
        let cleaningCount = cleaningSnapshot.items.count - duplicateCount
        let candidates = [
            PendingActionGroup(
                category: .receiptReview,
                count: receiptReviewCount,
                priority: .urgent,
                isProAutomation: false
            ),
            PendingActionGroup(
                category: .hotelReview,
                count: hotelReviewCount,
                priority: .urgent,
                isProAutomation: false
            ),
            PendingActionGroup(
                category: .duplicateReview,
                count: duplicateCount,
                priority: .elevated,
                isProAutomation: true
            ),
            PendingActionGroup(
                category: .subscriptionAnomaly,
                count: subscriptionAnomalyCount,
                priority: .elevated,
                isProAutomation: true
            ),
            PendingActionGroup(
                category: .cleaningSuggestion,
                count: cleaningCount,
                priority: .normal,
                isProAutomation: true
            )
        ]
        .filter { $0.count > 0 }

        return PendingActionCenterSnapshot(
            groups: candidates.sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return categoryRank(lhs.category) < categoryRank(rhs.category)
            }
        )
    }

    private func categoryRank(_ category: PendingActionCategory) -> Int {
        switch category {
        case .receiptReview: return 0
        case .hotelReview: return 1
        case .duplicateReview: return 2
        case .subscriptionAnomaly: return 3
        case .cleaningSuggestion: return 4
        }
    }
}
