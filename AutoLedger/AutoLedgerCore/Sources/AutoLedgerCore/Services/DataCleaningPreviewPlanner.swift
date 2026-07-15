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
    private let textDuplicateWindow: TimeInterval
    private let textSimilarityThreshold: Double

    public init(
        duplicateWindow: TimeInterval = 60,
        textDuplicateWindow: TimeInterval = 600,
        textSimilarityThreshold: Double = 0.82
    ) {
        self.duplicateWindow = duplicateWindow
        self.textDuplicateWindow = textDuplicateWindow
        self.textSimilarityThreshold = textSimilarityThreshold
    }

    public func buildSnapshot(
        transactions: [Transaction],
        merchantAliases: [String: String],
        categoryCorrections: [String: TransactionCategory],
        ignoredPreviewIDs: Set<String> = []
    ) -> DataCleaningPreviewSnapshot {
        let activeTransactions = transactions.sorted { $0.occurredAt > $1.occurredAt }
        var items: [DataCleaningPreviewItem] = []
        items.append(contentsOf: merchantAliasItems(transactions: activeTransactions, merchantAliases: merchantAliases))
        items.append(contentsOf: merchantNormalizationItems(transactions: activeTransactions, merchantAliases: merchantAliases))
        items.append(contentsOf: categoryCorrectionItems(transactions: activeTransactions, categoryCorrections: categoryCorrections))
        items.append(contentsOf: duplicateItems(transactions: activeTransactions))
        let visibleItems = ignoredPreviewIDs.isEmpty
            ? items
            : items.filter { !ignoredPreviewIDs.contains($0.id) }
        return DataCleaningPreviewSnapshot(items: visibleItems)
    }

    public func buildDuplicateCandidates(
        transactions: [Transaction]
    ) -> [DataCleaningPreviewItem] {
        duplicateItems(transactions: transactions.sorted { $0.occurredAt > $1.occurredAt })
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

    private func merchantNormalizationItems(
        transactions: [Transaction],
        merchantAliases: [String: String]
    ) -> [DataCleaningPreviewItem] {
        let groups = Dictionary(grouping: transactions) { $0.merchant.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.key.isEmpty }
        let stats = groups.map { merchant, transactions in
            MerchantNormalizationStats(
                merchant: merchant,
                normalized: normalizedMerchantKey(merchant),
                count: transactions.count,
                transactionIDs: transactions.map(\.id)
            )
        }
        .filter { !$0.normalized.isEmpty }

        return stats
            .filter { candidate in
                candidate.count > 0 &&
                    merchantAliases[candidate.merchant] == nil &&
                    !merchantAliases.values.contains(candidate.merchant)
            }
            .compactMap { candidate -> DataCleaningPreviewItem? in
                guard let target = bestNormalizationTarget(for: candidate, in: stats) else { return nil }
                return DataCleaningPreviewItem(
                    id: "merchantNormalization:\(candidate.merchant)->\(target.merchant)",
                    kind: .merchantAlias,
                    title: candidate.merchant,
                    subtitle: "\(candidate.count)",
                    currentValue: candidate.merchant,
                    proposedValue: target.merchant,
                    affectedTransactionIDs: candidate.transactionIDs,
                    score: merchantNormalizationScore(candidate: candidate, target: target),
                    reason: "merchant normalization suggestion"
                )
            }
            .sorted { lhs, rhs in
                if (lhs.score ?? 0) != (rhs.score ?? 0) {
                    return (lhs.score ?? 0) > (rhs.score ?? 0)
                }
                return lhs.currentValue < rhs.currentValue
            }
    }

    private func bestNormalizationTarget(
        for candidate: MerchantNormalizationStats,
        in stats: [MerchantNormalizationStats]
    ) -> MerchantNormalizationStats? {
        stats
            .filter { target in
                target.merchant != candidate.merchant &&
                    target.count >= 2 &&
                    target.normalized.count >= 4 &&
                    candidate.normalized.hasPrefix(target.normalized) &&
                    candidate.normalized.count >= target.normalized.count + 3
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                if lhs.normalized.count != rhs.normalized.count {
                    return lhs.normalized.count > rhs.normalized.count
                }
                return lhs.merchant < rhs.merchant
            }
            .first
    }

    private func merchantNormalizationScore(
        candidate: MerchantNormalizationStats,
        target: MerchantNormalizationStats
    ) -> Double {
        let support = min(0.12, Double(target.count - 1) * 0.04)
        let extraLength = max(0, candidate.normalized.count - target.normalized.count)
        let suffixSignal = min(0.08, Double(extraLength) * 0.01)
        return min(0.95, 0.78 + support + suffixSignal)
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
        let maximumDuplicateWindow = max(duplicateWindow, textDuplicateWindow)

        for lhsIndex in transactions.indices {
            for rhsIndex in transactions.index(after: lhsIndex)..<transactions.endIndex {
                let lhs = transactions[lhsIndex]
                let rhs = transactions[rhsIndex]
                let timeDelta = lhs.occurredAt.timeIntervalSince(rhs.occurredAt)
                if timeDelta >= maximumDuplicateWindow {
                    break
                }
                guard isDuplicateCandidate(lhs, rhs) else { continue }

                let pairID = [lhs.id.uuidString, rhs.id.uuidString].sorted().joined(separator: ":")
                let textSimilarity = noteSimilarity(lhs, rhs)
                let score = duplicateScore(timeDelta: timeDelta, textSimilarity: textSimilarity)
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
                        reason: duplicateReason(lhs, rhs, textSimilarity: textSimilarity)
                    )
                )
            }
        }

        return items
    }

    private func isDuplicateCandidate(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        guard abs(lhs.amount - rhs.amount) < 0.01 else { return false }

        let timeDelta = abs(lhs.occurredAt.timeIntervalSince(rhs.occurredAt))
        if normalizedMerchant(lhs.merchant) == normalizedMerchant(rhs.merchant),
           timeDelta < duplicateWindow {
            return true
        }

        return normalizedSource(lhs.source) == normalizedSource(rhs.source) &&
            timeDelta < textDuplicateWindow &&
            noteSimilarity(lhs, rhs) >= textSimilarityThreshold
    }

    private func normalizedMerchant(_ merchant: String) -> String {
        merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedMerchantKey(_ merchant: String) -> String {
        merchant
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func normalizedSource(_ source: String) -> String {
        source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func noteSimilarity(_ lhs: Transaction, _ rhs: Transaction) -> Double {
        let lhsNote = lhs.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhsNote = rhs.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lhsNote.isEmpty, !rhsNote.isEmpty else { return 0 }
        return TextSimilarity.jaccard(lhsNote, rhsNote)
    }

    private func duplicateScore(timeDelta: TimeInterval, textSimilarity: Double) -> Double {
        if textSimilarity >= textSimilarityThreshold {
            return max(0.85, min(1, textSimilarity))
        }
        return max(0.75, min(1, 1 - (timeDelta / duplicateWindow) * 0.2))
    }

    private func duplicateReason(_ lhs: Transaction, _ rhs: Transaction, textSimilarity: Double) -> String {
        if textSimilarity >= textSimilarityThreshold,
           normalizedSource(lhs.source) == normalizedSource(rhs.source) {
            return "same amount, source, and similar text"
        }
        return "same merchant, amount, and nearby time"
    }
}

private struct MerchantNormalizationStats: Sendable {
    let merchant: String
    let normalized: String
    let count: Int
    let transactionIDs: [UUID]
}
