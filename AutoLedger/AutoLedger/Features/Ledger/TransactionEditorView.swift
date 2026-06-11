import AutoLedgerCore
import SwiftUI

struct TransactionEditorView: View {
    let transaction: Transaction
    let onSave: (Transaction, Bool, Bool) -> Bool
    /// `true` 表示新增模式，导航栏标题显示"新增账单"；`false` 为编辑模式
    var isNew: Bool = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore
    @State private var merchant: String
    @State private var amountText: String
    @State private var category: String
    @State private var source: String
    @State private var occurredAt: Date
    @State private var note: String
    @State private var pendingSave: Transaction?
    @State private var pendingRefreshSameMerchantCategory = false
    @State private var showCategoryRefreshPrompt = false
    @State private var showMerchantAliasPrompt = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    init(transaction: Transaction, isNew: Bool = false, onSave: @escaping (Transaction, Bool, Bool) -> Bool) {
        self.transaction = transaction
        self.isNew = isNew
        self.onSave = onSave
        _merchant = State(initialValue: transaction.merchant)
        _amountText = State(initialValue: isNew ? "" : String(format: "%.2f", transaction.amount))
        _category = State(initialValue: transaction.category)
        _source = State(initialValue: transaction.source)
        _occurredAt = State(initialValue: transaction.occurredAt)
        _note = State(initialValue: transaction.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("transaction_editor.section.basic") {
                    TextField("transaction_editor.merchant", text: $merchant)

                    Picker("transaction_editor.source", selection: $source) {
                        ForEach(ReceiptSource.allCases) { item in
                            Text(item.title).tag(item.rawValue)
                        }
                        if !store.customSources.isEmpty {
                            ForEach(store.customSources, id: \.self) { custom in
                                Text(custom).tag(custom)
                            }
                        }
                    }

                    DatePicker("transaction_editor.date", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section("transaction_editor.section.amount") {
                    TextField("transaction_editor.amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    Picker("transaction_editor.category", selection: $category) {
                        ForEach(TransactionCategory.allCases) { item in
                            Text(item.title).tag(item.rawValue)
                        }
                        if !store.customCategories.isEmpty {
                            ForEach(store.customCategories, id: \.self) { custom in
                                Text(custom).tag(custom)
                            }
                        }
                    }

                    TextField("transaction_editor.note", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(isNew ? String(localized: "transaction_editor.title.new") : String(localized: "transaction_editor.title.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        beginSave(editedTransaction())
                    }
                    .disabled(isSaving || parsedAmount <= 0 || merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("transaction_editor.category_refresh.title", isPresented: $showCategoryRefreshPrompt, presenting: pendingSave) { updated in
                Button("transaction_editor.category_refresh.current_only", role: .cancel) {
                    continueSave(updated, refreshSameMerchantCategory: false)
                }
                Button("transaction_editor.category_refresh.refresh_all") {
                    continueSave(updated, refreshSameMerchantCategory: true)
                }
            } message: { updated in
                Text(String(format: String(localized: "transaction_editor.category_refresh.message_format"), updated.merchant, updated.categoryTitle))
            }
            .alert("transaction_editor.merchant_alias.title", isPresented: $showMerchantAliasPrompt, presenting: pendingSave) { updated in
                Button("transaction_editor.merchant_alias.skip", role: .cancel) {
                    save(
                        updated,
                        refreshSameMerchantCategory: pendingRefreshSameMerchantCategory,
                        saveMerchantAlias: false
                    )
                }
                Button("transaction_editor.merchant_alias.save") {
                    save(
                        updated,
                        refreshSameMerchantCategory: pendingRefreshSameMerchantCategory,
                        saveMerchantAlias: true
                    )
                }
            } message: { updated in
                Text(String(format: String(localized: "transaction_editor.merchant_alias.message_format"), transaction.merchant, updated.merchant))
            }
            .alert("transaction_editor.save_failed.title", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("common.done", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? String(localized: "transaction_editor.save_failed.message"))
            }
        }
    }

    private var parsedAmount: Double {
        LedgerAmountInputParser.parse(amountText) ?? 0
    }

    private func editedTransaction() -> Transaction {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return Transaction(
            id: transaction.id,
            merchant: trimmedMerchant.isEmpty ? transaction.merchant : trimmedMerchant,
            amount: parsedAmount,
            occurredAt: occurredAt,
            categoryLabel: category,
            sourceLabel: source,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func shouldPromptCategoryRefresh(for updated: Transaction) -> Bool {
        !isNew && transaction.category != updated.category
    }

    private func shouldPromptMerchantAlias(for updated: Transaction) -> Bool {
        !isNew && store.shouldOfferMerchantAlias(from: transaction, to: updated)
    }

    private func beginSave(_ updated: Transaction) {
        if shouldPromptCategoryRefresh(for: updated) {
            pendingSave = updated
            showCategoryRefreshPrompt = true
        } else {
            continueSave(updated, refreshSameMerchantCategory: false)
        }
    }

    private func continueSave(_ updated: Transaction, refreshSameMerchantCategory: Bool) {
        if shouldPromptMerchantAlias(for: updated) {
            pendingSave = updated
            pendingRefreshSameMerchantCategory = refreshSameMerchantCategory
            showMerchantAliasPrompt = true
        } else {
            save(updated, refreshSameMerchantCategory: refreshSameMerchantCategory, saveMerchantAlias: false)
        }
    }

    private func save(_ updated: Transaction, refreshSameMerchantCategory: Bool, saveMerchantAlias: Bool) {
        guard !isSaving else { return }
        isSaving = true
        let didSave = onSave(updated, refreshSameMerchantCategory, saveMerchantAlias)
        if didSave {
            pendingSave = nil
            pendingRefreshSameMerchantCategory = false
            dismiss()
        } else {
            isSaving = false
            saveErrorMessage = String(localized: "transaction_editor.save_failed.message")
        }
    }
}
