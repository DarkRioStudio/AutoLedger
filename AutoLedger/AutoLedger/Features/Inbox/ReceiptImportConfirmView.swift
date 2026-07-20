import AutoLedgerCore
import SwiftUI

struct ReceiptImportConfirmView: View {
    let draft: ReceiptImportReviewDraft

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore
    @State private var merchant: String
    @State private var amountText: String
    @State private var currencyCode: String
    @State private var source: ReceiptSource
    @State private var category: TransactionCategory
    @State private var occurredAt: Date
    @State private var note: String
    @State private var conversionPreviewState: CurrencyConversionPreviewState = .idle
    @State private var saveErrorMessage: String?

    init(draft: ReceiptImportReviewDraft) {
        self.draft = draft
        _merchant = State(initialValue: draft.receipt.merchant)
        _amountText = State(initialValue: String(format: "%.2f", draft.receipt.amount))
        _currencyCode = State(initialValue: LedgerCurrencyOption.supportedCode(matching: draft.receipt.currencyCode ?? ExpenseCurrencyPreference.currentCode))
        _source = State(initialValue: draft.receipt.source)
        _category = State(initialValue: draft.receipt.suggestedCategory)
        _occurredAt = State(initialValue: draft.receipt.occurredAt)
        _note = State(initialValue: draft.notePrefix)
    }

    private var parsedAmount: Double {
        LedgerAmountInputParser.parse(amountText) ?? 0
    }

    private var canSave: Bool {
        parsedAmount > 0 && !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var targetCurrencyCode: String {
        store.ledgerCurrencyCode(for: store.targetLedgerIDForNewTransactions)
    }

    private var hasAmbiguousRecognizedDate: Bool {
        AppFormatters.isAmbiguousNumericDate(draft.receipt.rawText)
    }

    private var shouldShowCurrencyConversion: Bool {
        currencyCode != targetCurrencyCode
    }

    private var conversionPreviewTaskID: String {
        [
            currencyCode,
            targetCurrencyCode,
            String(format: "%.2f", parsedAmount),
            String(Int(occurredAt.timeIntervalSince1970 / 60))
        ]
        .joined(separator: "|")
    }

    private var usableConversionQuote: CurrencyConversionPreviewQuote? {
        guard shouldShowCurrencyConversion,
              let quote = conversionPreviewState.quote,
              quote.sourceCurrencyCode == currencyCode,
              quote.targetCurrencyCode == targetCurrencyCode,
              abs(quote.sourceAmount - parsedAmount) < 0.001
        else {
            return nil
        }
        return quote
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(format: String(localized: "receipt_confirm.confidence_format"), draft.receipt.confidence))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: String(localized: "import_ledger_json.confirm.currency_format"), currencyCode))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("receipt_confirm.section.review")
                } footer: {
                    Text("receipt_confirm.footer")
                }

                Section("transaction_editor.section.basic") {
                    TextField("transaction_editor.merchant", text: $merchant)

                    Picker("transaction_editor.source", selection: $source) {
                        ForEach(ReceiptSource.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }

                    DatePicker(
                        "transaction_editor.date",
                        selection: $occurredAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    if hasAmbiguousRecognizedDate {
                        Label("receipt_confirm.ambiguous_date_warning", systemImage: "calendar.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
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
                            targetCurrencyCode: targetCurrencyCode,
                            state: conversionPreviewState,
                            onRetry: retryConversionPreview
                        )
                    }

                    Picker("transaction_editor.category", selection: $category) {
                        ForEach(TransactionCategory.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }

                    TextField("transaction_editor.note", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("receipt_confirm.section.ocr_text") {
                    Text(draft.rawText)
                        .font(.footnote.monospaced())
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineLimit(8)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle(String(localized: "receipt_confirm.title"))
            .navigationBarTitleDisplayMode(.inline)
            .task(id: conversionPreviewTaskID) {
                await refreshConversionPreview()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        CommonAPIAnalyticsService.trackConfirmationState(
                            flowType: "receipt_scan",
                            requiredFieldCount: requiredReviewFieldCount,
                            editedFieldCount: editedReviewFieldCount,
                            confirmStatus: "discarded",
                            discardReasonCode: "user_cancelled"
                        )
                        store.clearPendingReceiptReview()
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

    private func save() {
        let didSave = store.saveReceiptReview(
            draft,
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: parsedAmount,
            currencyCode: currencyCode,
            source: source,
            category: category,
            occurredAt: occurredAt,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            conversionQuote: usableConversionQuote
        )
        if didSave {
            CommonAPIAnalyticsService.trackConfirmationState(
                flowType: "receipt_scan",
                requiredFieldCount: requiredReviewFieldCount,
                editedFieldCount: editedReviewFieldCount,
                confirmStatus: "saved"
            )
            dismiss()
        } else {
            CommonAPIAnalyticsService.trackConfirmationState(
                flowType: "receipt_scan",
                requiredFieldCount: requiredReviewFieldCount,
                editedFieldCount: editedReviewFieldCount,
                confirmStatus: "failed",
                discardReasonCode: "save_failed"
            )
            saveErrorMessage = String(localized: "transaction_editor.save_failed.message")
        }
    }

    private var requiredReviewFieldCount: Int {
        5
    }

    private var editedReviewFieldCount: Int {
        var count = 0
        let initialAmountText = String(format: "%.2f", draft.receipt.amount)
        if merchant.trimmingCharacters(in: .whitespacesAndNewlines) != draft.receipt.merchant.trimmingCharacters(in: .whitespacesAndNewlines) {
            count += 1
        }
        if amountText.trimmingCharacters(in: .whitespacesAndNewlines) != initialAmountText {
            count += 1
        }
        if currencyCode != LedgerCurrencyOption.supportedCode(matching: draft.receipt.currencyCode ?? ExpenseCurrencyPreference.currentCode) {
            count += 1
        }
        if source != draft.receipt.source {
            count += 1
        }
        if category != draft.receipt.suggestedCategory {
            count += 1
        }
        if abs(occurredAt.timeIntervalSince(draft.receipt.occurredAt)) > 60 {
            count += 1
        }
        if note.trimmingCharacters(in: .whitespacesAndNewlines) != draft.notePrefix.trimmingCharacters(in: .whitespacesAndNewlines) {
            count += 1
        }
        return count
    }

    private func retryConversionPreview() {
        Task {
            await refreshConversionPreview()
        }
    }

    private func refreshConversionPreview() async {
        guard shouldShowCurrencyConversion, parsedAmount > 0 else {
            conversionPreviewState = .idle
            return
        }

        let sourceAmount = parsedAmount
        let sourceCurrencyCode = currencyCode
        let destinationCurrencyCode = targetCurrencyCode
        let conversionDate = occurredAt
        conversionPreviewState = .loading

        do {
            try await Task.sleep(nanoseconds: 250_000_000)
            let quote = try await CommonAPIExchangeRateService.quote(
                baseCurrencyCode: sourceCurrencyCode,
                quoteCurrencyCode: destinationCurrencyCode,
                date: conversionDate
            )
            guard !Task.isCancelled else { return }
            let convertedAmount = (sourceAmount * quote.rate * 100).rounded() / 100
            conversionPreviewState = .loaded(
                CurrencyConversionPreviewQuote(
                    sourceAmount: sourceAmount,
                    sourceCurrencyCode: quote.baseCurrencyCode,
                    targetCurrencyCode: quote.quoteCurrencyCode,
                    convertedAmount: convertedAmount,
                    rate: quote.rate,
                    rateDate: quote.date,
                    provider: quote.provider
                )
            )
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            conversionPreviewState = .failed
        }
    }
}

#Preview {
    ReceiptImportConfirmView(
        draft: ReceiptImportReviewDraft(
            receipt: ImportedReceipt(
                source: .wechat,
                merchant: "Demo Coffee",
                amount: 28,
                currencyCode: "CNY",
                occurredAt: .now,
                rawText: "Demo Coffee\nTotal CNY28.00",
                summary: "Demo receipt",
                confidence: 0.88,
                suggestedCategory: .dining
            ),
            rawText: "Demo Coffee\nTotal CNY28.00",
            notePrefix: "支付截图照片导入",
            imageSource: .photoLibrary,
            llmTrace: nil,
            usedRuleFallback: true,
            multiReceiptDetected: false
        )
    )
    .environmentObject(LedgerStore())
}
