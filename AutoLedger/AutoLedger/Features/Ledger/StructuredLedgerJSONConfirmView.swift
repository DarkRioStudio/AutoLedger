import AutoLedgerCore
import SwiftUI

struct StructuredLedgerJSONConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore

    let handoff: StructuredLedgerJSONIntentHandoff

    @State private var merchant: String
    @State private var amountText: String
    @State private var currencyCode: String
    @State private var category: String
    @State private var occurredAt: Date
    @State private var note: String

    init(handoff: StructuredLedgerJSONIntentHandoff) {
        self.handoff = handoff
        _merchant = State(initialValue: handoff.draft.merchant)
        _amountText = State(initialValue: String(format: "%.2f", handoff.draft.amount))
        _currencyCode = State(initialValue: LedgerCurrencyOption.supportedCode(matching: handoff.draft.currency ?? ExpenseCurrencyPreference.currentCode))
        _category = State(initialValue: handoff.draft.categoryLabel)
        _occurredAt = State(initialValue: handoff.draft.occurredAt)
        _note = State(initialValue: handoff.draft.note)
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canSave: Bool {
        parsedAmount > 0 && !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var targetCurrencyCode: String {
        store.ledgerCurrencyCode(for: store.targetLedgerIDForNewTransactions)
    }

    private var shouldShowCurrencyConversion: Bool {
        currencyCode != targetCurrencyCode
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(format: String(localized: "import_ledger_json.confirm.confidence_format"), handoff.draft.confidence))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: String(localized: "import_ledger_json.confirm.currency_format"), currencyCode))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("import_ledger_json.confirm.section.review")
                } footer: {
                    Text("import_ledger_json.confirm.footer")
                }

                Section("transaction_editor.section.basic") {
                    TextField("transaction_editor.merchant", text: $merchant)

                    DatePicker(
                        "transaction_editor.date",
                        selection: $occurredAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("transaction_editor.section.amount") {
                    TextField("transaction_editor.amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    Picker("hotel_stay.review.currency", selection: $currencyCode) {
                        ForEach(LedgerCurrencyOption.common) { option in
                            Text(option.localizedTitle).tag(option.code)
                        }
                    }

                    if shouldShowCurrencyConversion {
                        CurrencyConversionPreviewCard(
                            sourceAmount: parsedAmount,
                            sourceCurrencyCode: currencyCode,
                            targetCurrencyCode: targetCurrencyCode
                        )
                    }

                    Picker("transaction_editor.category", selection: $category) {
                        ForEach(TransactionCategory.allCases) { item in
                            Text(item.title).tag(item.rawValue)
                        }
                        if !store.customCategories.isEmpty {
                            ForEach(store.customCategories, id: \.self) { custom in
                                Text(custom).tag(custom)
                            }
                        }
                        if !isKnownCategory(category) {
                            Text(category).tag(category)
                        }
                    }

                    TextField("transaction_editor.note", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(String(localized: "import_ledger_json.confirm.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func isKnownCategory(_ value: String) -> Bool {
        TransactionCategory(rawValue: value) != nil || store.customCategories.contains(value)
    }

    private func save() {
        var noteParts: [String] = []
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNote.isEmpty {
            noteParts.append(trimmedNote)
        }
        if shouldShowCurrencyConversion {
            noteParts.append(String(format: String(localized: "import_ledger_json.currency_note_format"), currencyCode))
        }
        noteParts.append(String(format: String(localized: "import_ledger_json.confidence_note_format"), handoff.draft.confidence))

        let transaction = Transaction(
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: parsedAmount,
            occurredAt: occurredAt,
            categoryLabel: category,
            sourceLabel: ReceiptSource.manual.rawValue,
            note: noteParts.joined(separator: "\n"),
            ledgerID: store.targetLedgerIDForNewTransactions,
            originalAmount: parsedAmount,
            originalCurrencyCode: currencyCode
        )
        store.addTransaction(transaction)
        dismiss()
    }
}

#Preview {
    StructuredLedgerJSONConfirmView(
        handoff: StructuredLedgerJSONIntentHandoff(
            draft: StructuredLedgerJSONDraft(
                merchant: "Demo Coffee",
                amount: 18.8,
                categoryLabel: TransactionCategory.dining.rawValue,
                occurredAt: .now,
                note: "Imported from JSON",
                currency: "CNY",
                confidence: 0.72
            ),
            rawJSON: "{}"
        )
    )
    .environmentObject(LedgerStore())
}
