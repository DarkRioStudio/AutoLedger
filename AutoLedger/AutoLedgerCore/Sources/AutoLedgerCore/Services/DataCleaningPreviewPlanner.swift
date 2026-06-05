import Foundation

public enum DataCleaningPreviewKind: String, Codable, CaseIterable, Sendable {
    case merchantAlias
    case categoryCorrection
    case duplicateCandidate
}

public struct DataCleaningPreviewItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var kind: DataCleaningPreviewKind
    public var title: String
    public var subtitle: String
    public var currentValue: String
    public var proposedValue: String
    public var affectedTransactionIDs: [UUID]
    public var score: Double?
    public var reason: String

    public init(
        id: String,
        kind: DataCleaningPreviewKind,
        title: String,
        subtitle: String,
        currentValue: String,
        proposedValue: String,
        affectedTransactionIDs: [UUID],
        score: Double? = nil,
        reason: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.currentValue = currentValue
        self.proposedValue = proposedValue
        self.affectedTransactionIDs = affectedTransactionIDs
        self.score = score
        self.reason = reason
    }
}

public struct DataCleaningPreviewSnapshot: Codable, Equatable, Sendable {
    public var items: [DataCleaningPreviewItem]

    public init(items: [DataCleaningPreviewItem] = []) {
        self.items = items
    }

    public func items(kind: DataCleaningPreviewKind) -> [DataCleaningPreviewItem] {
        items.filter { $0.kind == kind }
    }
}

public struct DataCleaningPreviewPlanner: Sendable {
    private let duplicateWindow: TimeInterval

    public init(duplicateWindow: TimeInterval = 60) {
        self.duplicateWindow = duplicateWindow
    }

    public func buildSnapshot(
        transactions: [Transaction],
        merchantAliases: [String: String],
        categoryCorrections: [String: TransactionCategory]
    ) -> DataCleaningPreviewSnapshot {
        let activeTransactions = transactions.sorted { $0.occurredAt > $1.occurredAt }
        var items: [DataCleaningPreviewItem] = []
        items.append(contentsOf: merchantAliasItems(transactions: activeTransactions, merchantAliases: merchantAliases))
        items.append(contentsOf: categoryCorrectionItems(transactions: activeTransactions, categoryCorrections: categoryCorrections))
        items.append(contentsOf: duplicateItems(transactions: activeTransactions))
        return DataCleaningPreviewSnapshot(items: items)
    }

    private func merchantAliasItems(
        transactions: [Transaction],
        merchantAliases: [String: String]
    ) -> [DataCleaningPreviewItem] {
        merchantAliases
            .sorted { $0.key < $1.key }
            .compactMap { original, alias in
                let affected = transactions.filter { $0.merchant == original && $0.merchant != alias }
                guard !affected.isEmpty else { return nil }
                return DataCleaningPreviewItem(
                    id: "merchantAlias:\(original)->\(alias)",
                    kind: .merchantAlias,
                    title: original,
                    subtitle: "\(affected.count)",
                    currentValue: original,
                    proposedValue: alias,
                    affectedTransactionIDs: affected.map(\.id),
                    reason: "merchant alias"
                )
            }
    }

    private func categoryCorrectionItems(
        transactions: [Transaction],
        categoryCorrections: [String: TransactionCategory]
    ) -> [DataCleaningPreviewItem] {
        categoryCorrections
            .sorted { $0.key < $1.key }
            .compactMap { merchant, category in
                let affected = transactions.filter { $0.merchant == merchant && $0.category != category.rawValue }
                guard !affected.isEmpty else { return nil }
                let currentCategories = Set(affected.map(\.categoryTitle)).sorted().joined(separator: " / ")
                return DataCleaningPreviewItem(
                    id: "categoryCorrection:\(merchant)->\(category.rawValue)",
                    kind: .categoryCorrection,
                    title: merchant,
                    subtitle: "\(affected.count)",
                    currentValue: currentCategories,
                    proposedValue: category.title,
                    affectedTransactionIDs: affected.map(\.id),
                    reason: "category correction"
                )
            }
    }

    private func duplicateItems(transactions: [Transaction]) -> [DataCleaningPreviewItem] {
        var items: [DataCleaningPreviewItem] = []
        var seenPairs = Set<String>()

        for lhsIndex in transactions.indices {
            for rhsIndex in transactions.index(after: lhsIndex)..<transactions.endIndex {
                let lhs = transactions[lhsIndex]
                let rhs = transactions[rhsIndex]
                guard isDuplicateCandidate(lhs, rhs) else { continue }

                let pairID = [lhs.id.uuidString, rhs.id.uuidString].sorted().joined(separator: ":")
                guard !seenPairs.contains(pairID) else { continue }
                seenPairs.insert(pairID)

                let timeDelta = abs(lhs.occurredAt.timeIntervalSince(rhs.occurredAt))
                let score = max(0.75, min(1, 1 - (timeDelta / duplicateWindow) * 0.2))
                items.append(
                    DataCleaningPreviewItem(
                        id: "duplicate:\(pairID)",
                        kind: .duplicateCandidate,
                        title: lhs.merchant,
                        subtitle: "\(lhs.amount)",
                        currentValue: lhs.id.uuidString,
                        proposedValue: rhs.id.uuidString,
                        affectedTransactionIDs: [lhs.id, rhs.id],
                        score: score,
                        reason: "same merchant, amount, and nearby time"
                    )
                )
            }
        }

        return items
    }

    private func isDuplicateCandidate(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        normalizedMerchant(lhs.merchant) == normalizedMerchant(rhs.merchant) &&
        abs(lhs.amount - rhs.amount) < 0.01 &&
        abs(lhs.occurredAt.timeIntervalSince(rhs.occurredAt)) < duplicateWindow
    }

    private func normalizedMerchant(_ merchant: String) -> String {
        merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
