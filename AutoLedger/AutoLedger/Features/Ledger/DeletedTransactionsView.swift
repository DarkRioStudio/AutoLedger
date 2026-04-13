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
                        "暂无已删除账单",
                        systemImage: "trash",
                        description: Text("删除的账单会暂存于此，可在本次使用期间恢复。")
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
                                        Label("恢复", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.permanentlyDeleteTransaction(transaction)
                                    } label: {
                                        Label("彻底删除", systemImage: "trash.slash")
                                    }
                                }
                            }
                        } footer: {
                            Text("右滑恢复，左滑彻底删除。退出 App 后已删除记录将清空。")
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.screenGradient.ignoresSafeArea())
                }
            }
            .navigationTitle("最近删除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
                if !store.deletedTransactions.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("全部清空", role: .destructive) {
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
