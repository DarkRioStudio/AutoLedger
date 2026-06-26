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
        } detail: {
            transactionDetail
        }
        .navigationSplitViewStyle(.balanced)
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
                store.addTransaction(newTransaction)
            }
        }
        .sheet(isPresented: $navigationState.isPresentingVoiceLedger) {
            VoiceLedgerConfirmView()
        }
        .sheet(isPresented: $navigationState.isPresentingDeletedTransactions) {
            DeletedTransactionsView()
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
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationService.openNewTransactionEvent)) { _ in
            consumePendingNewTransactionIfNeeded()
        }
        .onChange(of: store.visibleTransactions.map(\.id)) { _, visibleIDs in
            guard let selectedTransactionID = navigationState.selectedLedgerTransactionID,
                  !visibleIDs.contains(selectedTransactionID) else { return }
            navigationState.selectedLedgerTransactionID = nil
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
                                .listRowBackground(AppTheme.card)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.deleteTransaction(transaction)
                                        if navigationState.selectedLedgerTransactionID == transaction.id {
                                            navigationState.selectedLedgerTransactionID = nil
                                        }
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                    }

                                    Button {
                                        navigationState.ledgerTransactionPendingMove = transaction
                                    } label: {
                                        Label("ledger.action.move", systemImage: "folder")
                                    }
                                    .tint(AppTheme.accent)
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
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .refreshable {
                await store.pullLedgerFromCloudKitIfEnabled(reason: "账本下拉刷新，正在从 iCloud 拉取数据。")
            }
            .onChange(of: searchText) { _, _ in
                if let first = searchFilteredTransactions.first {
                    withAnimation {
                        proxy.scrollTo(first.id, anchor: .top)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: Text("ledger.search.prompt"))
        .navigationTitle(store.currentLedgerTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if let onOpenLedgerSettings {
                        onOpenLedgerSettings()
                    } else {
                        navigationState.isPresentingLedgerProfiles = true
                    }
                } label: {
                    Image(systemName: "books.vertical")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel(Text("ledger_profiles.title"))
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    navigationState.isPresentingVoiceLedger = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel(Text(String(localized: "voice_ledger_title")))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    navigationState.isPresentingNewTransaction = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel(Text("transaction_editor.title.new"))
            }
            if !store.deletedTransactions.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        navigationState.isPresentingDeletedTransactions = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(Text("deleted_transactions.title"))
                }
            }
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
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: transaction.categoryEnum.iconName)
                .font(.headline)
                .foregroundStyle(transaction.categoryEnum.tint)
                .frame(width: 34, height: 34)
                .background(transaction.categoryEnum.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(transaction.merchant)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Spacer()

                    Text(AppFormatters.currency(transaction.amount))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                }

                HStack(spacing: 10) {
                    Text(transaction.categoryTitle)
                    Text(transaction.sourceTitle)
                    Text(AppFormatters.shortDateTime(transaction.occurredAt))
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }

            Image(systemName: "slider.horizontal.3")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.mutedInk)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var transactionDetail: some View {
        if let transaction = selectedTransaction {
            TransactionEditorView(
                transaction: transaction,
                usesNavigationStack: false,
                showsCancelButton: false,
                dismissesOnSave: false
            ) { updated, refreshSameMerchantCategory, saveMerchantAlias in
                store.updateTransaction(
                    updated,
                    refreshSameMerchantCategory: refreshSameMerchantCategory,
                    saveMerchantAlias: saveMerchantAlias
                )
            }
            .id(transaction.id)
            .background(AppTheme.screenGradient.ignoresSafeArea())
        } else {
            ContentUnavailableView(
                "ledger.detail.empty.title",
                systemImage: "list.bullet.rectangle.portrait",
                description: Text("ledger.detail.empty.description")
            )
            .background(AppTheme.screenGradient.ignoresSafeArea())
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
