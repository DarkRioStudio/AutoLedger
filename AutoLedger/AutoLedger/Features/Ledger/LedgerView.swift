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
    private let onOpenLedgerSettings: (() -> Void)?
    @State private var filter: LedgerFilter = .all
    @State private var filterDate = Date()
    @State private var searchText = ""

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
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return filteredTransactions }
        return filteredTransactions.filter {
            $0.merchant.localizedCaseInsensitiveContains(trimmed) ||
            $0.note.localizedCaseInsensitiveContains(trimmed) ||
            $0.categoryTitle.localizedCaseInsensitiveContains(trimmed)
        }
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
        ScrollViewReader { proxy in
            List(selection: $navigationState.selectedLedgerTransactionID) {
                filterSection

                Section {
                    let results = searchFilteredTransactions
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
                    let count = searchFilteredTransactions.count
                    Text(String(format: String(localized: "ledger.footer_format"), count))
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

#Preview {
    LedgerView()
        .environmentObject(LedgerStore())
        .environmentObject(AutoLedgerNavigationState())
}
