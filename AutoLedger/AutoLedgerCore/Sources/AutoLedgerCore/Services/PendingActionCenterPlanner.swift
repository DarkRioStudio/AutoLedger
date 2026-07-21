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
    public var deferredItems: [PendingActionItem]
    public var handledItems: [PendingActionItem]

    public init(
        groups: [PendingActionGroup] = [],
        items: [PendingActionItem] = [],
        deferredItems: [PendingActionItem] = [],
        handledItems: [PendingActionItem] = []
    ) {
        self.groups = groups
        self.items = items
        self.deferredItems = deferredItems
        self.handledItems = handledItems
    }

    public var totalCount: Int {
        groups.reduce(0) { $0 + $1.count }
    }

    public var isEmpty: Bool {
        totalCount == 0
    }

    public var hasStoredItems: Bool {
        !items.isEmpty || !deferredItems.isEmpty || !handledItems.isEmpty
    }

    public func count(for category: PendingActionCategory) -> Int {
        groups.first { $0.category == category }?.count ?? 0
    }

    public func items(for category: PendingActionCategory) -> [PendingActionItem] {
        items.filter { $0.category == category && $0.state.isActionable }
    }

    private enum CodingKeys: String, CodingKey {
        case groups
        case items
        case deferredItems
        case handledItems
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groups = try container.decodeIfPresent([PendingActionGroup].self, forKey: .groups) ?? []
        items = try container.decodeIfPresent([PendingActionItem].self, forKey: .items) ?? []
        deferredItems = try container.decodeIfPresent([PendingActionItem].self, forKey: .deferredItems) ?? []
        handledItems = try container.decodeIfPresent([PendingActionItem].self, forKey: .handledItems) ?? []
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
        let deferredItems = items
            .filter { item in
                item.state == .deferred && !item.isVisible(at: timestamp)
            }
            .sorted(by: deferredItemSort)
        let handledItems = items
            .filter { $0.state == .resolved || $0.state == .dismissed }
            .sorted(by: handledItemSort)
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

        return PendingActionCenterSnapshot(
            groups: groups,
            items: actionableItems,
            deferredItems: deferredItems,
            handledItems: handledItems
        )
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

    private func deferredItemSort(_ lhs: PendingActionItem, _ rhs: PendingActionItem) -> Bool {
        switch (lhs.deferredUntil, rhs.deferredUntil) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            return itemSort(lhs, rhs)
        }
    }

    private func handledItemSort(_ lhs: PendingActionItem, _ rhs: PendingActionItem) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return itemSort(lhs, rhs)
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
