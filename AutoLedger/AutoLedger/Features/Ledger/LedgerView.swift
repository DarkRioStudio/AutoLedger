import AutoLedgerCore
import SwiftUI

private enum LedgerFilter: String, CaseIterable {
    case all
    case month
    case year

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: return "ledger.filter.all"
        case .month: return "ledger.filter.month"
        case .year: return "ledger.filter.year"
        }
    }

    var previousAccessibilityKey: LocalizedStringKey {
        switch self {
        case .all: return "ledger.filter.previous"
        case .month: return "ledger.filter.previous_month"
        case .year: return "ledger.filter.previous_year"
        }
    }

    var nextAccessibilityKey: LocalizedStringKey {
        switch self {
        case .all: return "ledger.filter.next"
        case .month: return "ledger.filter.next_month"
        case .year: return "ledger.filter.next_year"
        }
    }
}

struct LedgerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    @EnvironmentObject private var store: LedgerStore
    @EnvironmentObject private var navigationState: AutoLedgerNavigationState
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared
    private let onOpenLedgerSettings: (() -> Void)?
    @State private var filter: LedgerFilter = .all
    @State private var filterDate = Date()
    @State private var searchText = ""
    @State private var advancedSearchQuery = LedgerAdvancedSearchQuery()
    @State private var isPresentingAdvancedSearch = false
    @State private var isPresentingDataCleaning = false
    @State private var isPresentingProSheet = false
    @State private var savedAdvancedSearches: [LedgerSavedSearch] = []
    @AppStorage("ledgerAdvancedSavedSearches") private var savedAdvancedSearchesData = Data()

    init(onOpenLedgerSettings: (() -> Void)? = nil) {
        self.onOpenLedgerSettings = onOpenLedgerSettings
    }

    private var filteredTransactions: [Transaction] {
        let cal = Calendar.current
        switch filter {
        case .all:
            return store.visibleTransactions
        case .month:
            return store.visibleTransactions.filter {
                cal.isDate($0.occurredAt, equalTo: filterDate, toGranularity: .month)
            }
        case .year:
            return store.visibleTransactions.filter {
                cal.isDate($0.occurredAt, equalTo: filterDate, toGranularity: .year)
            }
        }
    }

    private var searchFilteredTransactions: [Transaction] {
        let query = effectiveAdvancedSearchQuery
        if query.hasAdvancedFilters && !proEntitlement.canUse(.advancedSearch) {
            return LedgerAdvancedSearchService().search(
                transactions: filteredTransactions,
                query: LedgerAdvancedSearchQuery(keyword: query.keyword)
            )
        }
        return LedgerAdvancedSearchService().search(transactions: filteredTransactions, query: query)
    }

    private var effectiveAdvancedSearchQuery: LedgerAdvancedSearchQuery {
        var query = advancedSearchQuery
        query.keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query
    }

    private var hasAdvancedSearchFilters: Bool {
        advancedSearchQuery.hasAdvancedFilters
    }

    private var selectedTransaction: Transaction? {
        guard let selectedTransactionID = navigationState.selectedLedgerTransactionID else { return nil }
        return store.visibleTransactions.first { $0.id == selectedTransactionID }
    }

    private var prefersPersistentDetail: Bool {
        horizontalSizeClass == .regular
    }

    private var filterLabel: String {
        let fmt = DateFormatter()
        fmt.locale = .current
        switch filter {
        case .all: return String(localized: "ledger.filter.all_transactions")
        case .month:
            fmt.setLocalizedDateFormatFromTemplate("yMMM")
            return fmt.string(from: filterDate)
        case .year:
            fmt.setLocalizedDateFormatFromTemplate("y")
            return fmt.string(from: filterDate)
        }
    }

    var body: some View {
        NavigationSplitView {
            ledgerList
                .navigationSplitViewColumnWidth(min: 360, ideal: 430, max: 520)
        } detail: {
            transactionDetail
        }
        .navigationSplitViewStyle(.balanced)
        .autoLedgerNavigationBarChrome()
        .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
        .sheet(isPresented: $navigationState.isPresentingNewTransaction) {
            TransactionEditorView(
                transaction: Transaction(
                    merchant: "",
                    amount: 0,
                    occurredAt: .now,
                    category: .other,
                    source: .manual,
                    note: ""
                ),
                isNew: true
            ) { newTransaction, _, _ in
                let didSave = store.addTransaction(newTransaction)
                if didSave, prefersPersistentDetail {
                    navigationState.selectedLedgerTransactionID = newTransaction.id
                }
                return didSave
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $navigationState.isPresentingVoiceLedger) {
            VoiceLedgerConfirmView()
                .environmentObject(store)
        }
        .sheet(isPresented: $navigationState.isPresentingDeletedTransactions) {
            DeletedTransactionsView()
                .environmentObject(store)
        }
        .sheet(isPresented: $navigationState.isPresentingLedgerProfiles) {
            NavigationStack {
                LedgerProfileManagementView(allowsSelection: true, showsDoneButton: true)
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $isPresentingAdvancedSearch) {
            advancedSearchSheet
        }
        .sheet(isPresented: $isPresentingDataCleaning) {
            NavigationStack {
                DataCleaningSuggestionsView()
                    .environmentObject(store)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.close") {
                                isPresentingDataCleaning = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $isPresentingProSheet) {
            NavigationStack {
                AutoLedgerProView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.close") {
                                isPresentingProSheet = false
                            }
                        }
                    }
            }
        }
        .confirmationDialog(
            "ledger.move.title",
            isPresented: Binding(
                get: { navigationState.ledgerTransactionPendingMove != nil },
                set: { if !$0 { navigationState.ledgerTransactionPendingMove = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let transactionPendingMove = navigationState.ledgerTransactionPendingMove {
                let currentLedgerID = transactionPendingMove.resolvedLedgerID()
                ForEach(store.activeLedgerProfiles.filter { $0.id != currentLedgerID }) { profile in
                    Button(profile.name) {
                        store.moveTransaction(transactionPendingMove, toLedgerID: profile.id)
                        navigationState.ledgerTransactionPendingMove = nil
                    }
                }
            }
            Button("common.cancel", role: .cancel) {
                navigationState.ledgerTransactionPendingMove = nil
            }
        }
        .onAppear {
            store.showSelectedLedgerOnly()
            loadSavedAdvancedSearches()
            consumePendingNewTransactionIfNeeded()
            ensurePersistentDetailSelectionIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationService.openNewTransactionEvent)) { _ in
            consumePendingNewTransactionIfNeeded()
        }
        .onChange(of: store.visibleTransactions.map(\.id)) { _, visibleIDs in
            reconcileSelection(with: visibleIDs)
        }
        .onChange(of: horizontalSizeClass) { _, _ in
            ensurePersistentDetailSelectionIfNeeded()
        }
    }

    private var ledgerList: some View {
        let results = searchFilteredTransactions
        return ScrollViewReader { proxy in
            List(selection: $navigationState.selectedLedgerTransactionID) {
                filterSection

                Section {
                    if results.isEmpty && !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("ledger.search.no_results")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.mutedInk)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                            .listRowBackground(AppTheme.card)
                    } else {
                        ForEach(results) { transaction in
                            NavigationLink(value: transaction.id) {
                                transactionRow(transaction)
                            }
                                .id(transaction.id)
                                .tag(transaction.id)
                                .accessibilityLabel("\(transaction.merchant)，\(AppFormatters.currency(transaction.amount))，\(transaction.categoryTitle)，\(AppFormatters.shortDateTime(transaction.occurredAt))")
                                .accessibilityHint(Text("ledger.transaction.edit_hint"))
                                .padding(.vertical, 6)
                                .autoLedgerSelectableRowBackground(
                                    navigationState.selectedLedgerTransactionID == transaction.id
                                )
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        duplicateTransaction(transaction)
                                    } label: {
                                        Label("ledger.action.copy", systemImage: "doc.on.doc")
                                    }
                                    .tint(AppTheme.accent)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteTransaction(transaction)
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    transactionActionItems(for: transaction)
                                }
                        }
                    }
                } header: {
                    Text(filterLabel)
                } footer: {
                    Text(String(format: String(localized: "ledger.footer_format"), results.count))
                }
            }
            .autoLedgerListChrome()
            .refreshable {
                await store.pullLedgerFromCloudKitIfEnabled(reason: "账本下拉刷新，正在从 iCloud 拉取数据。")
            }
            .onChange(of: searchText) { _, _ in
                if let first = searchFilteredTransactions.first {
                    if reduceMotion {
                        proxy.scrollTo(first.id, anchor: .top)
                    } else {
                        withAnimation {
                            proxy.scrollTo(first.id, anchor: .top)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: Text("ledger.search.prompt"))
        .navigationTitle(store.currentLedgerTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentAdvancedSearch()
                } label: {
                    Image(systemName: hasAdvancedSearchFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(hasAdvancedSearchFilters ? AppTheme.accent : AppTheme.ink)
                .accessibilityLabel(Text("ledger.advanced_search.title"))
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    navigationState.isPresentingNewTransaction = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel(Text("transaction_editor.title.new"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        navigationState.isPresentingVoiceLedger = true
                    } label: {
                        Label("voice_ledger_title", systemImage: "square.and.pencil")
                    }

                    Button {
                        presentLedgerProfiles()
                    } label: {
                        Label("ledger_profiles.title", systemImage: "books.vertical")
                    }

                    Button {
                        isPresentingDataCleaning = true
                    } label: {
                        Label("settings.data_cleaning.title", systemImage: "wand.and.sparkles")
                    }

                    if !store.deletedTransactions.isEmpty {
                        Divider()

                        Button {
                            navigationState.isPresentingDeletedTransactions = true
                        } label: {
                            Label("deleted_transactions.title", systemImage: "trash")
                        }
                    }
                } label: {
                    Label("common.more_actions", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
            }
        }
    }

    private var advancedSearchSheet: some View {
        NavigationStack {
            LedgerAdvancedSearchSheet(
                query: advancedSearchQuery,
                searchText: searchText,
                savedAdvancedSearches: $savedAdvancedSearches,
                categoryOptions: advancedCategoryOptions,
                sourceOptions: advancedSourceOptions,
                ledgerOptions: advancedLedgerOptions,
                onPersistSavedSearches: persistSavedAdvancedSearches,
                onApply: { appliedQuery, appliedKeyword in
                    advancedSearchQuery = appliedQuery
                    searchText = appliedKeyword
                    isPresentingAdvancedSearch = false
                },
                onCancel: {
                    isPresentingAdvancedSearch = false
                }
            )
        }
    }

    private var advancedCategoryOptions: [LedgerAdvancedSearchOption] {
        let builtIns = TransactionCategory.allCases.map {
            LedgerAdvancedSearchOption(id: $0.rawValue, title: $0.title)
        }
        let custom = store.customCategories.map {
            LedgerAdvancedSearchOption(id: $0, title: $0)
        }
        return builtIns + custom
    }

    private var advancedSourceOptions: [LedgerAdvancedSearchOption] {
        let builtIns = ReceiptSource.allCases.map {
            LedgerAdvancedSearchOption(id: $0.rawValue, title: $0.title)
        }
        let custom = store.customSources.map {
            LedgerAdvancedSearchOption(id: $0, title: $0)
        }
        return builtIns + custom
    }

    private var advancedLedgerOptions: [LedgerAdvancedSearchOption] {
        store.activeLedgerProfiles.map {
            LedgerAdvancedSearchOption(id: $0.id, title: $0.name)
        }
    }

    private func presentAdvancedSearch() {
        if proEntitlement.canUse(.advancedSearch) {
            CommonAPIAnalyticsService.trackFeatureSurfaceOpened(
                surface: "advanced_search",
                entrySurface: "ledger",
                isProSurface: true,
                openReason: "button_tap"
            )
            isPresentingAdvancedSearch = true
        } else {
            CommonAPIAnalyticsService.trackProGateViewed(
                surface: "ledger",
                featureArea: "advanced_search",
                userAction: "view_plans",
                dismissReasonCode: "requires_pro"
            )
            isPresentingProSheet = true
        }
    }

    private func loadSavedAdvancedSearches() {
        guard !savedAdvancedSearchesData.isEmpty,
              let decoded = try? JSONDecoder().decode([LedgerSavedSearch].self, from: savedAdvancedSearchesData) else {
            savedAdvancedSearches = []
            return
        }
        savedAdvancedSearches = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persistSavedAdvancedSearches() {
        savedAdvancedSearches = savedAdvancedSearches.sorted { $0.updatedAt > $1.updatedAt }
        savedAdvancedSearchesData = (try? JSONEncoder().encode(savedAdvancedSearches)) ?? Data()
    }

    private func presentLedgerProfiles() {
        if let onOpenLedgerSettings {
            onOpenLedgerSettings()
        } else {
            navigationState.isPresentingLedgerProfiles = true
        }
    }

    private var filterSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Picker("ledger.filter.picker", selection: $filter) {
                    ForEach(LedgerFilter.allCases, id: \.self) { f in
                        Text(f.titleKey).tag(f)
                    }
                }
                .pickerStyle(.segmented)

                if filter != .all {
                    HStack {
                        Button {
                            filterDate = stepDate(filterDate, by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(filter.previousAccessibilityKey))

                        Spacer()

                        Text(filterLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)

                        Spacer()

                        Button {
                            filterDate = stepDate(filterDate, by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .disabled(isAtOrAfterToday)
                        .accessibilityLabel(Text(filter.nextAccessibilityKey))
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
            .listRowBackground(AppTheme.card)
        }
    }

    private func transactionRow(_ transaction: Transaction) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: transaction.categoryEnum.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(transaction.categoryEnum.tint)
                .frame(width: 30, height: 30)
                .background(transaction.categoryEnum.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(transaction.merchant)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.9)
                        .allowsTightening(true)
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    Text(AppFormatters.currency(transaction.amount))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .allowsTightening(true)
                        .layoutPriority(2)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(transaction.categoryTitle)
                        Text(transaction.sourceTitle)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)

                    Spacer(minLength: 8)

                    Text(AppFormatters.shortDateTime(transaction.occurredAt))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .frame(minWidth: 58, alignment: .trailing)
                        .layoutPriority(1)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }
        }
    }

    @ViewBuilder
    private var transactionDetail: some View {
        if let transaction = selectedTransaction {
            TransactionEditorView(
                transaction: transaction,
                usesNavigationStack: false,
                showsCancelButton: false,
                dismissesOnSave: !prefersPersistentDetail,
                onDuplicate: { transaction in
                    duplicateTransaction(transaction)
                },
                onMove: { transaction in
                    navigationState.ledgerTransactionPendingMove = transaction
                },
                onDelete: { transaction in
                    deleteTransaction(transaction)
                }
            ) { updated, refreshSameMerchantCategory, saveMerchantAlias in
                let didSave = store.updateTransaction(
                    updated,
                    refreshSameMerchantCategory: refreshSameMerchantCategory,
                    saveMerchantAlias: saveMerchantAlias
                )
                if didSave {
                    navigationState.selectedLedgerTransactionID = prefersPersistentDetail ? updated.id : nil
                }
                return didSave
            }
            .id(transaction.id)
            .autoLedgerScreenChrome()
        } else {
            ContentUnavailableView(
                "ledger.detail.empty.title",
                systemImage: "list.bullet.rectangle.portrait",
                description: Text("ledger.detail.empty.description")
            )
            .autoLedgerScreenChrome()
        }
    }

    @ViewBuilder
    private func transactionActionItems(for transaction: Transaction) -> some View {
        Button {
            duplicateTransaction(transaction)
        } label: {
            Label("ledger.action.copy", systemImage: "doc.on.doc")
        }

        Button {
            navigationState.ledgerTransactionPendingMove = transaction
        } label: {
            Label("ledger.action.move", systemImage: "folder")
        }

        Divider()

        Button(role: .destructive) {
            deleteTransaction(transaction)
        } label: {
            Label("common.delete", systemImage: "trash")
        }
    }

    @MainActor
    private func consumePendingNewTransactionIfNeeded() {
        guard QuickLedgerNavigationState.shared.consumeCreateTransactionPending() else { return }
        navigationState.isPresentingNewTransaction = true
    }

    private func stepDate(_ date: Date, by value: Int) -> Date {
        let cal = Calendar.current
        switch filter {
        case .all: return date
        case .month: return cal.date(byAdding: .month, value: value, to: date) ?? date
        case .year: return cal.date(byAdding: .year, value: value, to: date) ?? date
        }
    }

    private func reconcileSelection(with visibleIDs: [UUID]) {
        guard let selectedTransactionID = navigationState.selectedLedgerTransactionID else {
            ensurePersistentDetailSelectionIfNeeded()
            return
        }

        if !visibleIDs.contains(selectedTransactionID) {
            navigationState.selectedLedgerTransactionID = prefersPersistentDetail
                ? searchFilteredTransactions.first?.id
                : nil
        }
    }

    private func ensurePersistentDetailSelectionIfNeeded() {
        guard prefersPersistentDetail,
              navigationState.selectedLedgerTransactionID == nil else { return }
        navigationState.selectedLedgerTransactionID = searchFilteredTransactions.first?.id
    }

    private func deleteTransaction(_ transaction: Transaction) {
        let nextID = nextSelectionID(afterDeleting: transaction)
        store.deleteTransaction(transaction)
        if navigationState.selectedLedgerTransactionID == transaction.id {
            navigationState.selectedLedgerTransactionID = prefersPersistentDetail ? nextID : nil
        }
    }

    private func duplicateTransaction(_ transaction: Transaction) {
        guard let duplicated = store.duplicateTransaction(transaction) else { return }
        navigationState.selectedLedgerTransactionID = duplicated.id
    }

    private func nextSelectionID(afterDeleting transaction: Transaction) -> UUID? {
        let rows = searchFilteredTransactions
        guard let deletedIndex = rows.firstIndex(where: { $0.id == transaction.id }) else {
            return rows.first(where: { $0.id != transaction.id })?.id
        }
        let remainingIDs = rows.map(\.id).filter { $0 != transaction.id }
        guard !remainingIDs.isEmpty else { return nil }
        return remainingIDs[min(deletedIndex, remainingIDs.count - 1)]
    }

    private var isAtOrAfterToday: Bool {
        let cal = Calendar.current
        switch filter {
        case .all: return true
        case .month: return cal.isDate(filterDate, equalTo: Date(), toGranularity: .month) ||
                           filterDate > Date()
        case .year: return cal.isDate(filterDate, equalTo: Date(), toGranularity: .year) ||
                          filterDate > Date()
        }
    }
}

private struct LedgerAdvancedSearchOption: Identifiable, Hashable {
    let id: String
    let title: String
}

private struct LedgerAdvancedSearchSheet: View {
    @Binding var savedAdvancedSearches: [LedgerSavedSearch]
    let categoryOptions: [LedgerAdvancedSearchOption]
    let sourceOptions: [LedgerAdvancedSearchOption]
    let ledgerOptions: [LedgerAdvancedSearchOption]
    let onPersistSavedSearches: () -> Void
    let onApply: (LedgerAdvancedSearchQuery, String) -> Void
    let onCancel: () -> Void

    @State private var draftQuery: LedgerAdvancedSearchQuery
    @State private var draftSearchText: String
    @State private var minAmountText: String
    @State private var maxAmountText: String
    @State private var savedSearchName = ""
    @State private var isAmountFilterEnabled: Bool
    @State private var isCategoryFilterEnabled: Bool
    @State private var isSourceFilterEnabled: Bool
    @State private var isLedgerFilterEnabled: Bool

    init(
        query: LedgerAdvancedSearchQuery,
        searchText: String,
        savedAdvancedSearches: Binding<[LedgerSavedSearch]>,
        categoryOptions: [LedgerAdvancedSearchOption],
        sourceOptions: [LedgerAdvancedSearchOption],
        ledgerOptions: [LedgerAdvancedSearchOption],
        onPersistSavedSearches: @escaping () -> Void,
        onApply: @escaping (LedgerAdvancedSearchQuery, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._savedAdvancedSearches = savedAdvancedSearches
        self.categoryOptions = categoryOptions
        self.sourceOptions = sourceOptions
        self.ledgerOptions = ledgerOptions
        self.onPersistSavedSearches = onPersistSavedSearches
        self.onApply = onApply
        self.onCancel = onCancel

        var initialQuery = query
        let initialKeyword = searchText.isEmpty ? query.keyword : searchText
        initialQuery.keyword = initialKeyword
        self._draftQuery = State(initialValue: initialQuery)
        self._draftSearchText = State(initialValue: initialKeyword)
        self._minAmountText = State(initialValue: Self.text(for: query.minAmount))
        self._maxAmountText = State(initialValue: Self.text(for: query.maxAmount))
        self._isAmountFilterEnabled = State(initialValue: query.minAmount != nil || query.maxAmount != nil)
        self._isCategoryFilterEnabled = State(initialValue: !query.categoryIDs.isEmpty)
        self._isSourceFilterEnabled = State(initialValue: !query.sourceIDs.isEmpty)
        self._isLedgerFilterEnabled = State(initialValue: !query.ledgerIDs.isEmpty)
    }

    var body: some View {
        Form {
            Section {
                Text("ledger.advanced_search.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)

                TextField("ledger.search.prompt", text: $draftSearchText)
            } header: {
                Text("ledger.advanced_search.title")
            }

            Section {
                Toggle("ledger.advanced_search.amount_range", isOn: $isAmountFilterEnabled)

                if isAmountFilterEnabled {
                    TextField("ledger.advanced_search.min_amount", text: $minAmountText)
                        .keyboardType(.decimalPad)
                        .onChange(of: minAmountText) { _, newValue in
                            draftQuery.minAmount = Self.amount(from: newValue)
                        }
                    TextField("ledger.advanced_search.max_amount", text: $maxAmountText)
                        .keyboardType(.decimalPad)
                        .onChange(of: maxAmountText) { _, newValue in
                            draftQuery.maxAmount = Self.amount(from: newValue)
                        }
                }
            }

            Section("ledger.advanced_search.date_range") {
                Toggle("ledger.advanced_search.start_date", isOn: Binding(
                    get: { draftQuery.startDate != nil },
                    set: { draftQuery.startDate = $0 ? (draftQuery.startDate ?? .now) : nil }
                ))
                if draftQuery.startDate != nil {
                    DatePicker(
                        "ledger.advanced_search.start_date",
                        selection: Binding(
                            get: { draftQuery.startDate ?? .now },
                            set: { draftQuery.startDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }

                Toggle("ledger.advanced_search.end_date", isOn: Binding(
                    get: { draftQuery.endDate != nil },
                    set: { draftQuery.endDate = $0 ? (draftQuery.endDate ?? .now) : nil }
                ))
                if draftQuery.endDate != nil {
                    DatePicker(
                        "ledger.advanced_search.end_date",
                        selection: Binding(
                            get: { draftQuery.endDate ?? .now },
                            set: { draftQuery.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
            }

            optionSection(
                "ledger.advanced_search.category",
                isEnabled: $isCategoryFilterEnabled,
                options: categoryOptions,
                selection: $draftQuery.categoryIDs
            )
            optionSection(
                "ledger.advanced_search.source",
                isEnabled: $isSourceFilterEnabled,
                options: sourceOptions,
                selection: $draftQuery.sourceIDs
            )
            optionSection(
                "ledger.advanced_search.ledger",
                isEnabled: $isLedgerFilterEnabled,
                options: ledgerOptions,
                selection: $draftQuery.ledgerIDs
            )

            Section {
                Toggle("ledger.advanced_search.hotel_folio", isOn: $draftQuery.requiresHotelFolioLink)
                Toggle("ledger.advanced_search.original_currency", isOn: Binding(
                    get: { draftQuery.requiresOriginalCurrency == true },
                    set: { draftQuery.requiresOriginalCurrency = $0 ? true : nil }
                ))
            }

            Section("ledger.advanced_search.saved") {
                if savedAdvancedSearches.isEmpty {
                    Text("ledger.advanced_search.saved_empty")
                        .foregroundStyle(AppTheme.mutedInk)
                } else {
                    ForEach(savedAdvancedSearches) { saved in
                        Button {
                            loadSavedSearch(saved.query)
                        } label: {
                            Label(saved.name, systemImage: "bookmark")
                        }
                    }
                    .onDelete { indexSet in
                        savedAdvancedSearches.remove(atOffsets: indexSet)
                        onPersistSavedSearches()
                    }
                }

                TextField("ledger.advanced_search.save_name", text: $savedSearchName)

                Button {
                    saveCurrentSearch()
                } label: {
                    Label("ledger.advanced_search.save_current", systemImage: "bookmark.fill")
                }
                .disabled(savedSearchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("ledger.advanced_search.title")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel", action: onCancel)
            }

            ToolbarItem(placement: .primaryAction) {
                Button("ledger.advanced_search.clear") {
                    clearSearch()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()

                Button(action: applySearch) {
                    Label("ledger.advanced_search.apply", systemImage: "line.3.horizontal.decrease.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.accent)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(.regularMaterial)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func optionSection(
        _ titleKey: LocalizedStringKey,
        isEnabled: Binding<Bool>,
        options: [LedgerAdvancedSearchOption],
        selection: Binding<Set<String>>
    ) -> some View {
        Section {
            Toggle(titleKey, isOn: isEnabled)

            if isEnabled.wrappedValue {
                ForEach(options) { option in
                    Toggle(option.title, isOn: Binding(
                        get: { selection.wrappedValue.contains(option.id) },
                        set: { isSelected in
                            if isSelected {
                                selection.wrappedValue.insert(option.id)
                            } else {
                                selection.wrappedValue.remove(option.id)
                            }
                        }
                    ))
                }
            }
        }
    }

    private func saveCurrentSearch() {
        let trimmed = savedSearchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let snapshot = normalizedDraftQuery
        let now = Date()
        if let existingIndex = savedAdvancedSearches.firstIndex(where: { $0.name == trimmed }) {
            let existing = savedAdvancedSearches[existingIndex]
            savedAdvancedSearches[existingIndex] = LedgerSavedSearch(
                id: existing.id,
                name: existing.name,
                query: snapshot,
                createdAt: existing.createdAt,
                updatedAt: now
            )
        } else {
            savedAdvancedSearches.append(
                LedgerSavedSearch(name: trimmed, query: snapshot, createdAt: now, updatedAt: now)
            )
        }
        savedSearchName = ""
        onPersistSavedSearches()
    }

    private func applySearch() {
        let snapshot = normalizedDraftQuery
        onApply(snapshot, snapshot.keyword)
    }

    private var normalizedDraftQuery: LedgerAdvancedSearchQuery {
        var snapshot = draftQuery
        snapshot.keyword = draftSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isAmountFilterEnabled {
            snapshot.minAmount = nil
            snapshot.maxAmount = nil
        }
        if !isCategoryFilterEnabled {
            snapshot.categoryIDs = []
        }
        if !isSourceFilterEnabled {
            snapshot.sourceIDs = []
        }
        if !isLedgerFilterEnabled {
            snapshot.ledgerIDs = []
        }
        return snapshot
    }

    private func loadSavedSearch(_ savedQuery: LedgerAdvancedSearchQuery) {
        draftQuery = savedQuery
        draftSearchText = savedQuery.keyword
        minAmountText = Self.text(for: savedQuery.minAmount)
        maxAmountText = Self.text(for: savedQuery.maxAmount)
        isAmountFilterEnabled = savedQuery.minAmount != nil || savedQuery.maxAmount != nil
        isCategoryFilterEnabled = !savedQuery.categoryIDs.isEmpty
        isSourceFilterEnabled = !savedQuery.sourceIDs.isEmpty
        isLedgerFilterEnabled = !savedQuery.ledgerIDs.isEmpty
    }

    private func clearSearch() {
        draftQuery = LedgerAdvancedSearchQuery()
        draftSearchText = ""
        minAmountText = ""
        maxAmountText = ""
        isAmountFilterEnabled = false
        isCategoryFilterEnabled = false
        isSourceFilterEnabled = false
        isLedgerFilterEnabled = false
    }

    private static func amount(from text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private static func text(for amount: Double?) -> String {
        guard let amount else { return "" }
        return String(format: "%.2f", amount)
    }
}

#Preview {
    LedgerView()
        .environmentObject(LedgerStore())
        .environmentObject(AutoLedgerNavigationState())
}
