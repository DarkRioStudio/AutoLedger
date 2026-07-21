import Foundation

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
    public var items: [PendingActionItem]

    public init(groups: [PendingActionGroup] = [], items: [PendingActionItem] = []) {
        self.groups = groups
        self.items = items
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

    public func items(for category: PendingActionCategory) -> [PendingActionItem] {
        items.filter { $0.category == category && $0.state.isActionable }
    }
}

public struct PendingActionCenterPlanner: Sendable {
    public init() {}

    public func buildSnapshot(
        items: [PendingActionItem],
        at timestamp: Date = .now
    ) -> PendingActionCenterSnapshot {
        let actionableItems = items
            .filter { $0.isVisible(at: timestamp) }
            .sorted(by: itemSort)
        let grouped = Dictionary(grouping: actionableItems, by: \PendingActionItem.category)
        let groups = grouped.map { category, items in
            PendingActionGroup(
                category: category,
                count: items.count,
                priority: items.map(\.priority).max() ?? .normal,
                isProAutomation: items.contains { $0.isProAutomation }
            )
        }
        .sorted(by: groupSort)

        return PendingActionCenterSnapshot(groups: groups, items: actionableItems)
    }

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
            groups: candidates.sorted(by: groupSort)
        )
    }

    private func itemSort(_ lhs: PendingActionItem, _ rhs: PendingActionItem) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }
        if categoryRank(lhs.category) != categoryRank(rhs.category) {
            return categoryRank(lhs.category) < categoryRank(rhs.category)
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    private func groupSort(_ lhs: PendingActionGroup, _ rhs: PendingActionGroup) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }
        return categoryRank(lhs.category) < categoryRank(rhs.category)
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
