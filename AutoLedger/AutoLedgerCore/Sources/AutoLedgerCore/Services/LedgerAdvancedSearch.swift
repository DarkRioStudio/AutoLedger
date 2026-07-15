import Foundation

public enum LedgerAdvancedSearchSort: String, Codable, CaseIterable, Sendable {
    case dateDescending
    case dateAscending
    case amountDescending
    case amountAscending
}

public struct LedgerAdvancedSearchQuery: Codable, Equatable, Sendable {
    public var keyword: String
    public var minAmount: Double?
    public var maxAmount: Double?
    public var startDate: Date?
    public var endDate: Date?
    public var categoryIDs: Set<String>
    public var sourceIDs: Set<String>
    public var ledgerIDs: Set<String>
    public var requiresHotelFolioLink: Bool
    public var requiresOriginalCurrency: Bool?
    public var sort: LedgerAdvancedSearchSort

    public init(
        keyword: String = "",
        minAmount: Double? = nil,
        maxAmount: Double? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        categoryIDs: Set<String> = [],
        sourceIDs: Set<String> = [],
        ledgerIDs: Set<String> = [],
        requiresHotelFolioLink: Bool = false,
        requiresOriginalCurrency: Bool? = nil,
        sort: LedgerAdvancedSearchSort = .dateDescending
    ) {
        self.keyword = keyword
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.startDate = startDate
        self.endDate = endDate
        self.categoryIDs = categoryIDs
        self.sourceIDs = sourceIDs
        self.ledgerIDs = ledgerIDs
        self.requiresHotelFolioLink = requiresHotelFolioLink
        self.requiresOriginalCurrency = requiresOriginalCurrency
        self.sort = sort
    }

    public var normalizedKeywordTokens: [String] {
        keyword
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline || $0 == "," || $0 == "，" })
            .map { String($0).normalizedForAdvancedLedgerSearch }
            .filter { !$0.isEmpty }
    }

    public var hasAdvancedFilters: Bool {
        minAmount != nil ||
            maxAmount != nil ||
            startDate != nil ||
            endDate != nil ||
            categoryIDs.isEmpty == false ||
            sourceIDs.isEmpty == false ||
            ledgerIDs.isEmpty == false ||
            requiresHotelFolioLink ||
            requiresOriginalCurrency != nil ||
            sort != .dateDescending
    }

    public var requiresProAccess: Bool {
        hasAdvancedFilters
    }
}

public struct LedgerSavedSearch: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var query: LedgerAdvancedSearchQuery
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        query: LedgerAdvancedSearchQuery,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.query = query
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct LedgerAdvancedSearchService: Sendable {
    public init() {}

    public func search(
        transactions: [Transaction],
        query: LedgerAdvancedSearchQuery,
        defaultLedgerID: String = TodaySpendingSummary.defaultLedgerID
    ) -> [Transaction] {
        let tokens = query.normalizedKeywordTokens
        if tokens.isEmpty && !query.hasAdvancedFilters {
            return transactions
        }
        let filtered = transactions.filter { transaction in
            matchesKeyword(transaction, tokens: tokens) &&
                matchesAmount(transaction, query: query) &&
                matchesDate(transaction, query: query) &&
                matchesCategory(transaction, query: query) &&
                matchesSource(transaction, query: query) &&
                matchesLedger(transaction, query: query, defaultLedgerID: defaultLedgerID) &&
                matchesHotelFolio(transaction, query: query) &&
                matchesOriginalCurrency(transaction, query: query)
        }
        return sort(filtered, by: query.sort)
    }

    private func matchesKeyword(_ transaction: Transaction, tokens: [String]) -> Bool {
        guard tokens.isEmpty == false else { return true }
        let haystack = [
            transaction.merchant,
            transaction.category,
            transaction.categoryTitle,
            transaction.source,
            transaction.sourceTitle,
            transaction.note,
            transaction.ledgerID ?? "",
            transaction.ledgerCurrencyCode ?? "",
            transaction.originalCurrencyCode ?? "",
            transaction.exchangeRateProvider ?? "",
            transaction.exchangeRateDate ?? ""
        ]
        .joined(separator: " ")
        .normalizedForAdvancedLedgerSearch
        return tokens.allSatisfy { haystack.contains($0) }
    }

    private func matchesAmount(_ transaction: Transaction, query: LedgerAdvancedSearchQuery) -> Bool {
        if let minAmount = query.minAmount, transaction.amount < minAmount {
            return false
        }
        if let maxAmount = query.maxAmount, transaction.amount > maxAmount {
            return false
        }
        return true
    }

    private func matchesDate(_ transaction: Transaction, query: LedgerAdvancedSearchQuery) -> Bool {
        if let startDate = query.startDate, transaction.occurredAt < startDate {
            return false
        }
        if let endDate = query.endDate, transaction.occurredAt > endDate {
            return false
        }
        return true
    }

    private func matchesCategory(_ transaction: Transaction, query: LedgerAdvancedSearchQuery) -> Bool {
        query.categoryIDs.isEmpty || query.categoryIDs.contains(transaction.category)
    }

    private func matchesSource(_ transaction: Transaction, query: LedgerAdvancedSearchQuery) -> Bool {
        query.sourceIDs.isEmpty || query.sourceIDs.contains(transaction.source)
    }

    private func matchesLedger(
        _ transaction: Transaction,
        query: LedgerAdvancedSearchQuery,
        defaultLedgerID: String
    ) -> Bool {
        query.ledgerIDs.isEmpty || query.ledgerIDs.contains(transaction.resolvedLedgerID(defaultLedgerID: defaultLedgerID))
    }

    private func matchesHotelFolio(_ transaction: Transaction, query: LedgerAdvancedSearchQuery) -> Bool {
        query.requiresHotelFolioLink == false || transaction.hotelStayRecordID != nil
    }

    private func matchesOriginalCurrency(_ transaction: Transaction, query: LedgerAdvancedSearchQuery) -> Bool {
        guard let requiresOriginalCurrency = query.requiresOriginalCurrency else { return true }
        let hasOriginalCurrency = transaction.originalCurrencyCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return requiresOriginalCurrency ? hasOriginalCurrency : !hasOriginalCurrency
    }

    private func sort(_ transactions: [Transaction], by sort: LedgerAdvancedSearchSort) -> [Transaction] {
        transactions.sorted { lhs, rhs in
            switch sort {
            case .dateDescending:
                return lhs.occurredAt == rhs.occurredAt ? lhs.merchant < rhs.merchant : lhs.occurredAt > rhs.occurredAt
            case .dateAscending:
                return lhs.occurredAt == rhs.occurredAt ? lhs.merchant < rhs.merchant : lhs.occurredAt < rhs.occurredAt
            case .amountDescending:
                return lhs.amount == rhs.amount ? lhs.occurredAt > rhs.occurredAt : lhs.amount > rhs.amount
            case .amountAscending:
                return lhs.amount == rhs.amount ? lhs.occurredAt > rhs.occurredAt : lhs.amount < rhs.amount
            }
        }
    }
}

private extension String {
    var normalizedForAdvancedLedgerSearch: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
