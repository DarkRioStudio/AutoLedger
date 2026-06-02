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
    @State private var selectedTransaction: Transaction?
    @State private var filter: LedgerFilter = .all
    @State private var filterDate = Date()
    @State private var isAddingTransaction = false
    @State private var isShowingVoiceLedger = false
    @State private var isShowingDeleted = false
    @State private var searchText = ""

    private var filteredTransactions: [Transaction] {
        let cal = Calendar.current
        switch filter {
        case .all:
            return store.transactions
        case .month:
            return store.transactions.filter {
                cal.isDate($0.occurredAt, equalTo: filterDate, toGranularity: .month)
            }
        case .year:
            return store.transactions.filter {
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
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section {
                        // Filter controls
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
                                Button {
                                    selectedTransaction = transaction
                                } label: {
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

                                            if !transaction.note.isEmpty {
                                                Text(transaction.note)
                                                    .font(.footnote)
                                                    .foregroundStyle(AppTheme.mutedInk)
                                            }
                                        }

                                        Image(systemName: "slider.horizontal.3")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppTheme.mutedInk)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .id(transaction.id)
                                .accessibilityLabel("\(transaction.merchant)，\(AppFormatters.currency(transaction.amount))，\(transaction.categoryTitle)，\(AppFormatters.shortDateTime(transaction.occurredAt))")
                                .accessibilityHint(Text("ledger.transaction.edit_hint"))
                                .buttonStyle(.plain)
                                .padding(.vertical, 6)
                                .listRowBackground(AppTheme.card)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.deleteTransaction(transaction)
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                    }
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
            .navigationTitle("tab.ledger")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingVoiceLedger = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel(Text(String(localized: "voice_ledger_title")))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddingTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel(Text("transaction_editor.title.new"))
                }
                if !store.deletedTransactions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isShowingDeleted = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(Text("deleted_transactions.title"))
                    }
                }
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionEditorView(transaction: transaction) { updated, refreshSameMerchantCategory in
                    store.updateTransaction(updated, refreshSameMerchantCategory: refreshSameMerchantCategory)
                }
            }
            .sheet(isPresented: $isAddingTransaction) {
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
                ) { newTransaction, _ in
                    store.addTransaction(newTransaction)
                }
            }
            .sheet(isPresented: $isShowingVoiceLedger) {
                VoiceLedgerConfirmView()
            }
            .sheet(isPresented: $isShowingDeleted) {
                DeletedTransactionsView()
            }
            .onAppear {
                consumePendingNewTransactionIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationService.openNewTransactionEvent)) { _ in
                consumePendingNewTransactionIfNeeded()
            }
        }
    }

    @MainActor
    private func consumePendingNewTransactionIfNeeded() {
        guard QuickLedgerNavigationState.shared.consumeCreateTransactionPending() else { return }
        isAddingTransaction = true
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
}
