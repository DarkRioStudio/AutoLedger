import AutoLedgerCore
import SwiftUI

struct DeletedTransactionsView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.deletedTransactions.isEmpty {
                    ContentUnavailableView(
                        "deleted_transactions.empty.title",
                        systemImage: "trash",
                        description: Text("deleted_transactions.empty.description")
                    )
                } else {
                    List {
                        Section {
                            ForEach(store.deletedTransactions) { transaction in
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
                                    }
                                }
                                .padding(.vertical, 6)
                                .listRowBackground(AppTheme.card)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        store.restoreTransaction(transaction)
                                    } label: {
                                        Label("deleted_transactions.restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.permanentlyDeleteTransaction(transaction)
                                    } label: {
                                        Label("deleted_transactions.delete_permanently", systemImage: "trash.slash")
                                    }
                                }
                            }
                        } footer: {
                            Text("deleted_transactions.footer")
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.screenGradient.ignoresSafeArea())
                }
            }
            .navigationTitle("deleted_transactions.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
                if !store.deletedTransactions.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("deleted_transactions.clear_all", role: .destructive) {
                            let snapshot = store.deletedTransactions
                            for transaction in snapshot {
                                store.permanentlyDeleteTransaction(transaction)
                            }
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

#Preview {
    DeletedTransactionsView()
        .environmentObject(LedgerStore())
}
