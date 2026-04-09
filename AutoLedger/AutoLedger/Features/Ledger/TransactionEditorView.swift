import AutoLedgerCore
import SwiftUI

struct TransactionEditorView: View {
    let transaction: Transaction
    let onSave: (Transaction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var merchant: String
    @State private var amountText: String
    @State private var category: TransactionCategory
    @State private var source: ReceiptSource
    @State private var occurredAt: Date
    @State private var note: String

    init(transaction: Transaction, onSave: @escaping (Transaction) -> Void) {
        self.transaction = transaction
        self.onSave = onSave
        _merchant = State(initialValue: transaction.merchant)
        _amountText = State(initialValue: String(format: "%.2f", transaction.amount))
        _category = State(initialValue: transaction.category)
        _source = State(initialValue: transaction.source)
        _occurredAt = State(initialValue: transaction.occurredAt)
        _note = State(initialValue: transaction.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("账单信息") {
                    TextField("商户", text: $merchant)

                    Picker("来源", selection: $source) {
                        ForEach(ReceiptSource.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }

                    DatePicker("时间", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section("金额与分类") {
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
                        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            Transaction(
                                id: transaction.id,
                                merchant: trimmedMerchant.isEmpty ? transaction.merchant : trimmedMerchant,
                                amount: parsedAmount,
                                occurredAt: occurredAt,
                                category: category,
                                source: source,
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
