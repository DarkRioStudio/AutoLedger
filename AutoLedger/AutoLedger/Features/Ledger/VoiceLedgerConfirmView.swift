import AutoLedgerCore
import SwiftUI

struct VoiceLedgerConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore

    @State private var inputText = ""
    @State private var merchant = ""
    @State private var amountText = ""
    @State private var category: TransactionCategory = .other
    @State private var occurredAt = Date()
    @State private var result: VoiceLedgerParseResult?
    @State private var message = String(localized: "voice_ledger_example")

    private let parser = VoiceLedgerParser()

    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard let amount, amount > 0 else { return false }
        return !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "voice_ledger_input_placeholder"), text: $inputText, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text(String(localized: "voice_ledger_title"))
                } footer: {
                    Text(message)
                }

                Section(String(localized: "voice_ledger_review_required")) {
                    TextField(String(localized: "transaction_editor.merchant"), text: $merchant)

                    TextField(String(localized: "transaction_editor.amount"), text: $amountText)
                        .keyboardType(.decimalPad)

                    Picker(String(localized: "transaction_editor.category"), selection: $category) {
                        ForEach(TransactionCategory.allCases) { item in
                            Label(item.title, systemImage: item.iconName)
                                .tag(item)
                        }
                    }

                    DatePicker(
                        String(localized: "transaction_editor.date"),
                        selection: $occurredAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle(String(localized: "voice_ledger_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if inputText.isEmpty {
                    message = String(localized: "voice_ledger_example")
                }
            }
            .onChange(of: inputText) { _, _ in
                parseInput()
            }
        }
    }

    private func parseInput() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            result = nil
            merchant = ""
            amountText = ""
            category = .other
            occurredAt = .now
            message = String(localized: "voice_ledger_example")
            return
        }

        let parsed = parser.parse(inputText, corrections: store.categoryCorrections)
        result = parsed

        merchant = parsed.merchant
        amountText = parsed.amount.map { String(format: "%.2f", $0) } ?? ""
        category = parsed.category
        occurredAt = parsed.occurredAt

        switch parsed.confidence {
        case .high:
            message = String(localized: "voice_ledger_ready_to_save")
        case .needsReview:
            message = String(localized: "voice_ledger_review_required")
        case .failed:
            message = failureMessage(for: parsed.failureReason)
        }
    }

    private func save() {
        guard let amount else { return }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        store.addVoiceTransaction(
            merchant: trimmedMerchant,
            amount: amount,
            occurredAt: occurredAt,
            category: category,
            rawText: inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        dismiss()
    }

    private func failureMessage(for reason: VoiceLedgerFailureReason?) -> String {
        switch reason {
        case .noAmount:
            return String(localized: "voice_ledger_no_amount")
        case .multipleAmounts:
            return String(localized: "voice_ledger_multiple_amounts")
        case .unsupportedIncomeOrTransfer:
            return String(localized: "voice_ledger_income_not_supported")
        case .emptyInput:
            return String(localized: "voice_ledger_example")
        default:
            return String(localized: "voice_ledger_unclear")
        }
    }
}

#Preview {
    VoiceLedgerConfirmView()
        .environmentObject(LedgerStore())
}
