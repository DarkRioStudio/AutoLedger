import Foundation

public enum AdvancedRuleAutomationRuleKind: String, Codable, Equatable, Sendable {
    case merchantAlias
    case categoryCorrection
}

public struct AdvancedRuleAutomationRule: Identifiable, Codable, Equatable, Sendable {
    public var id: String { previewItem.id }

    public let kind: AdvancedRuleAutomationRuleKind
    public let title: String
    public let currentValue: String
    public let proposedValue: String
    public let affectedTransactionCount: Int
    public let previewItem: DataCleaningPreviewItem

    public init(kind: AdvancedRuleAutomationRuleKind, previewItem: DataCleaningPreviewItem) {
        self.kind = kind
        self.title = previewItem.title
        self.currentValue = previewItem.currentValue
        self.proposedValue = previewItem.proposedValue
        self.affectedTransactionCount = previewItem.affectedTransactionIDs.count
        self.previewItem = previewItem
    }
}

public struct AdvancedRuleAutomationPlan: Codable, Equatable, Sendable {
    public let rules: [AdvancedRuleAutomationRule]

    public init(rules: [AdvancedRuleAutomationRule]) {
        self.rules = rules
    }

    public var ruleCount: Int {
        rules.count
    }

    public var affectedTransactionCount: Int {
        Set(rules.flatMap(\.previewItem.affectedTransactionIDs)).count
    }

    public var isEmpty: Bool {
        rules.isEmpty
    }

    public var previewItems: [DataCleaningPreviewItem] {
        rules.map(\.previewItem)
    }

    public func rules(kind: AdvancedRuleAutomationRuleKind) -> [AdvancedRuleAutomationRule] {
        rules.filter { $0.kind == kind }
    }
}

public struct AdvancedRuleAutomationPlanner: Sendable {
    private let dataCleaningPlanner: DataCleaningPreviewPlanner

    public init(dataCleaningPlanner: DataCleaningPreviewPlanner = DataCleaningPreviewPlanner()) {
        self.dataCleaningPlanner = dataCleaningPlanner
    }

    public func buildPlan(
        transactions: [Transaction],
        merchantAliases: [String: String],
        categoryCorrections: [String: TransactionCategory],
        ignoredRuleIDs: Set<String> = []
    ) -> AdvancedRuleAutomationPlan {
        let snapshot = dataCleaningPlanner.buildSnapshot(
            transactions: transactions,
            merchantAliases: merchantAliases,
            categoryCorrections: categoryCorrections,
            ignoredPreviewIDs: ignoredRuleIDs
        )
        return buildPlan(snapshot: snapshot)
    }

    public func buildPlan(snapshot: DataCleaningPreviewSnapshot) -> AdvancedRuleAutomationPlan {
        let rules = snapshot.items.compactMap(rule)
        return AdvancedRuleAutomationPlan(rules: rules)
    }

    private func rule(from preview: DataCleaningPreviewItem) -> AdvancedRuleAutomationRule? {
        switch preview.kind {
        case .merchantAlias:
            guard preview.reason == "merchant alias" else { return nil }
            return AdvancedRuleAutomationRule(kind: .merchantAlias, previewItem: preview)

        case .categoryCorrection:
            guard preview.reason == "category correction" else { return nil }
            return AdvancedRuleAutomationRule(kind: .categoryCorrection, previewItem: preview)

        case .duplicateCandidate:
            return nil
        }
    }
}
