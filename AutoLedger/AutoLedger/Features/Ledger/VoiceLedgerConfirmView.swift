import AutoLedgerCore
import SwiftUI

struct VoiceLedgerConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore
    @StateObject private var speechRecognizer = VoiceSpeechRecognizer()

    @State private var inputText = ""
    @State private var merchant = ""
    @State private var amountText = ""
    @State private var category: TransactionCategory = .other
    @State private var occurredAt = Date()
    @State private var result: VoiceLedgerParseResult?
    @State private var message = ""
    @State private var isRecordingVoice = false
    @State private var finishRecordingTask: Task<Void, Never>?
    @State private var parseTask: Task<Void, Never>?

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
                    voiceInputControl
                }

                Section {
                    TextField(String(localized: "voice_ledger_input_placeholder"), text: $inputText, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text(String(localized: "voice_ledger_title"))
                } footer: {
                    if !message.isEmpty {
                        Text(message)
                    }
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
                    message = ""
                }
            }
            .onChange(of: inputText) { _, _ in
                parseInput()
            }
            .onChange(of: speechRecognizer.transcript) { _, newValue in
                guard !newValue.isEmpty else { return }
                inputText = newValue
            }
            .onChange(of: speechRecognizer.state) { _, newValue in
                updateSpeechMessage(for: newValue)
            }
            .onDisappear {
                finishRecordingTask?.cancel()
                parseTask?.cancel()
                speechRecognizer.cancel()
            }
        }
    }

    private var voiceInputControl: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isRecordingVoice ? AppTheme.accentSecondary : AppTheme.accent)
                    .frame(width: 48, height: 48)

                Image(systemName: isRecordingVoice ? "stop.fill" : "mic.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(isRecordingVoice ? String(localized: "voice_ledger_release_to_finish") : String(localized: "voice_ledger_hold_to_record"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text("voice_ledger_home_subtitle")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginVoiceRecording() }
                .onEnded { _ in finishVoiceRecording() }
        )
        .accessibilityLabel(Text(String(localized: "voice_ledger_hold_to_record")))
    }

    private func parseInput() {
        parseTask?.cancel()

        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            result = nil
            merchant = ""
            amountText = ""
            category = .other
            occurredAt = .now
            if !isRecordingVoice {
                message = ""
            }
            return
        }

        let currentText = inputText
        parseTask = Task { @MainActor in
            let parsed = await store.interpretVoiceText(currentText)
            guard !Task.isCancelled, currentText == inputText else { return }
            applyParsedResult(parsed)
        }
    }

    private func beginVoiceRecording() {
        guard !isRecordingVoice else { return }
        finishRecordingTask?.cancel()
        isRecordingVoice = true
        inputText = ""
        merchant = ""
        amountText = ""
        category = .other
        occurredAt = .now
        result = nil
        message = String(localized: "voice_ledger_listening")
        speechRecognizer.start()
    }

    private func finishVoiceRecording() {
        guard isRecordingVoice else { return }
        isRecordingVoice = false
        speechRecognizer.stop()
        message = String(localized: "voice_ledger_processing")
        finishRecordingTask?.cancel()
        finishRecordingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                message = String(localized: "voice_ledger_empty_result")
            } else {
                parseInput()
            }
        }
    }

    private func applyParsedResult(_ parsed: VoiceLedgerParseResult) {
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
            return ""
        default:
            return String(localized: "voice_ledger_unclear")
        }
    }

    private func updateSpeechMessage(for state: VoiceSpeechRecognizer.RecognitionState) {
        switch state {
        case .idle:
            break
        case .requestingPermission:
            message = String(localized: "voice_ledger_requesting_permission")
        case .listening:
            message = String(localized: "voice_ledger_listening")
        case .unavailable(let reason):
            message = reason
        }
    }
}

#Preview {
    VoiceLedgerConfirmView()
        .environmentObject(LedgerStore())
}
