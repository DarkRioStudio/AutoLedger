import AutoLedgerCore
import SwiftUI

private enum LedgerFilter: String, CaseIterable {
    case all = "全部"
    case month = "本月"
    case year = "本年"
}

struct LedgerView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var selectedTransaction: Transaction?
    @State private var filter: LedgerFilter = .all
    @State private var filterDate = Date()
    @State private var isAddingTransaction = false
    @State private var isShowingVoiceLedger = false
    @State private var isShowingDeleted = false

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

    private var filterLabel: String {
        let fmt = DateFormatter()
        switch filter {
        case .all: return "全部账单"
        case .month:
            fmt.dateFormat = "yyyy年M月"
            return fmt.string(from: filterDate)
        case .year:
            fmt.dateFormat = "yyyy年"
            return fmt.string(from: filterDate)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Filter controls
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("筛选", selection: $filter) {
                            ForEach(LedgerFilter.allCases, id: \.self) { f in
                                Text(f.rawValue).tag(f)
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
                            }
                            .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .listRowBackground(AppTheme.card)
                }

                Section {
                    ForEach(filteredTransactions) { transaction in
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
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)
                        .listRowBackground(AppTheme.card)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteTransaction(transaction)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(filterLabel)
                } footer: {
                    let count = filteredTransactions.count
                    Text("共 \(count) 笔，点按任一账单可修正金额、分类和备注。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .refreshable {
                store.refreshFromStore()
            }
            .navigationTitle("账本")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingVoiceLedger = true
                    } label: {
                        Image(systemName: "waveform")
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
                }
                if !store.deletedTransactions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isShowingDeleted = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionEditorView(transaction: transaction) { updated in
                    store.updateTransaction(updated)
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
                ) { newTransaction in
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
