import SwiftUI

struct TransactionEditorView: View {
    let transaction: Transaction
    let onSave: (Transaction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var category: TransactionCategory
    @State private var note: String

    init(transaction: Transaction, onSave: @escaping (Transaction) -> Void) {
        self.transaction = transaction
        self.onSave = onSave
        _amountText = State(initialValue: String(format: "%.2f", transaction.amount))
        _category = State(initialValue: transaction.category)
        _note = State(initialValue: transaction.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("账单信息") {
                    LabeledContent("商户", value: transaction.merchant)
                    LabeledContent("来源", value: transaction.source.title)
                    LabeledContent("时间", value: AppFormatters.shortDateTime(transaction.occurredAt))
                }

                Section("可修正字段") {
                    TextField("金额", text: $amountText)
                        .keyboardType(.decimalPad)

                    Picker("分类", selection: $category) {
                        ForEach(TransactionCategory.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }

                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("编辑账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(
                            Transaction(
                                id: transaction.id,
                                merchant: transaction.merchant,
                                amount: parsedAmount,
                                occurredAt: transaction.occurredAt,
                                category: category,
                                source: transaction.source,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(parsedAmount <= 0)
                }
            }
        }
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}
