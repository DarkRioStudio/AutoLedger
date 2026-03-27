import SwiftUI

struct LedgerView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var selectedTransaction: Transaction?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.transactions) { transaction in
                        Button {
                            selectedTransaction = transaction
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: transaction.category.iconName)
                                    .font(.headline)
                                    .foregroundStyle(transaction.category.tint)
                                    .frame(width: 34, height: 34)
                                    .background(transaction.category.tint.opacity(0.12))
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
                                        Text(transaction.category.title)
                                        Text(transaction.source.title)
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
                    }
                } header: {
                    Text("本地账本")
                } footer: {
                    Text("当前账本已写入本地 SQLite，点按任一账单可修正金额、分类和备注。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("账本")
            .sheet(item: $selectedTransaction) { transaction in
                TransactionEditorView(transaction: transaction) { updated in
                    store.updateTransaction(updated)
                }
            }
        }
    }
}

#Preview {
    LedgerView()
        .environmentObject(LedgerStore())
}
