import AutoLedgerCore
import SwiftUI
import UIKit

struct VoiceLedgerQuickEntryView: View {
    @EnvironmentObject private var store: LedgerStore
    @StateObject private var speechRecognizer = VoiceSpeechRecognizer()

    @State private var inputText = ""
    @State private var merchant = ""
    @State private var amountText = ""
    @State private var category: TransactionCategory = .other
    @State private var occurredAt = Date()
    @State private var result: VoiceLedgerParseResult?
    @State private var message = String(localized: "voice_ledger_home_hint")
    @State private var isPressing = false
    @State private var didAutoSave = false
    @State private var finishTask: Task<Void, Never>?
    @State private var parseTask: Task<Void, Never>?

    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard let amount, amount > 0 else { return false }
        return !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldAutoSave: Bool {
        result?.confidence == .high && canSave && !didAutoSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            holdControl

            if !inputText.isEmpty {
                recognizedText
            }

            if canSave && !didAutoSave {
                reviewBlock
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            guard !newValue.isEmpty else { return }
            inputText = newValue
            parseInput()
        }
        .onChange(of: speechRecognizer.state) { _, newValue in
            updateSpeechMessage(for: newValue)
        }
        .onDisappear {
            finishTask?.cancel()
            parseTask?.cancel()
            speechRecognizer.cancel()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, AppTheme.accent)

            VStack(alignment: .leading, spacing: 6) {
                Text("voice_ledger_home_title")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Text("voice_ledger_home_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()
        }
    }

    private var holdControl: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isPressing ? AppTheme.accentSecondary : AppTheme.accent)
                    .frame(width: 88, height: 88)
                    .shadow(color: AppTheme.accent.opacity(isPressing ? 0.24 : 0.12), radius: 16, x: 0, y: 10)

                Image(systemName: isPressing ? "stop.fill" : "mic.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginPressing() }
                    .onEnded { _ in finishPressing() }
            )
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text(String(localized: "voice_ledger_hold_to_record")))

            Text(isPressing ? String(localized: "voice_ledger_release_to_finish") : String(localized: "voice_ledger_hold_to_record"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(isPressing ? AppTheme.accentSecondary : AppTheme.accent)
        }
    }

    private var recognizedText: some View {
        Text(inputText)
            .font(.subheadline)
            .foregroundStyle(AppTheme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.accent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var reviewBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(merchant, systemImage: category.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                Spacer()

                if let amount {
                    Text(
                        AppFormatters.currency(
                            amount,
                            code: store.ledgerCurrencyCode(
                                for: store.targetLedgerIDForNewTransactions
                            )
                        )
                    )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                }
            }

            Button {
                save()
            } label: {
                Label(String(localized: "common.save"), systemImage: "checkmark.circle.fill")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
    }

    private func beginPressing() {
        guard !isPressing else { return }
        didAutoSave = false
        finishTask?.cancel()
        isPressing = true
        inputText = ""
        merchant = ""
        amountText = ""
        result = nil
        message = String(localized: "voice_ledger_listening")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        speechRecognizer.start()
    }

    private func finishPressing() {
        guard isPressing else { return }
        isPressing = false
        speechRecognizer.stop()
        message = String(localized: "voice_ledger_processing")
        finishTask?.cancel()
        finishTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            parseInput(autoSaveWhenReady: true)
        }
    }

    private func parseInput(autoSaveWhenReady: Bool = false) {
        parseTask?.cancel()
        let currentText = inputText
        parseTask = Task { @MainActor in
            let parsed = await store.interpretVoiceText(currentText)
            guard !Task.isCancelled, currentText == inputText else { return }
            applyParsedResult(parsed)

            if autoSaveWhenReady, shouldAutoSave {
                save()
            } else if autoSaveWhenReady, inputText.isEmpty {
                message = String(localized: "voice_ledger_empty_result")
            }
        }
    }

    private func applyParsedResult(_ parsed: VoiceLedgerParseResult) {
        result = parsed

        if !parsed.merchant.isEmpty {
            merchant = parsed.merchant
        }
        if let parsedAmount = parsed.amount {
            amountText = String(format: "%.2f", parsedAmount)
        }
        category = parsed.category
        occurredAt = parsed.occurredAt

        switch parsed.confidence {
        case .high:
            message = String(localized: "voice_ledger_auto_save_ready")
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
        didAutoSave = true
        message = store.lastImportSummary ?? String(localized: "voice_ledger_saved")
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
            return String(localized: "voice_ledger_home_hint")
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
    VoiceLedgerQuickEntryView()
        .environmentObject(LedgerStore())
}
