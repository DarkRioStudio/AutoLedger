import AutoLedgerCore
import SwiftUI

struct HotelStayReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let draft: HotelStayDraft
    let onConfirm: (HotelStayDraft) -> Void
    let onReject: (HotelStayDraft) -> Void

    @State private var form: HotelStayReviewForm
    @State private var validationMessageKey: String?
    private let rawTextLocalizer = HotelFolioRawTextLocalizer()

    init(
        draft: HotelStayDraft,
        onConfirm: @escaping (HotelStayDraft) -> Void = { _ in },
        onReject: @escaping (HotelStayDraft) -> Void = { _ in }
    ) {
        self.draft = draft
        self.onConfirm = onConfirm
        self.onReject = onReject
        _form = State(initialValue: HotelStayReviewForm(draft: draft))
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                staySection
                chargeSection
                sourceSection
                rawTextSection
            }
            .navigationTitle(String(localized: "hotel_stay.review.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("hotel_stay.review.reject", role: .destructive) {
                        rejectDraft()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("hotel_stay.review.confirm") {
                        confirmDraft()
                    }
                    .disabled(!form.isValid)
                }
            }
        }
    }

    private var identitySection: some View {
        Section {
            TextField("hotel_stay.review.hotel_name", text: $form.hotelName)
            TextField("hotel_stay.review.brand", text: $form.hotelBrand)
            TextField("hotel_stay.review.group", text: $form.hotelGroup)
            TextField("hotel_stay.review.city", text: $form.city)
            TextField("hotel_stay.review.country", text: $form.country)
        } header: {
            Text("hotel_stay.review.identity")
        } footer: {
            if let validationMessageKey {
                Text(LocalizedStringKey(validationMessageKey))
                    .foregroundStyle(.red)
            }
        }
    }

    private var staySection: some View {
        Section("hotel_stay.review.stay") {
            TextField("hotel_stay.review.check_in", text: $form.checkInDate)
            TextField("hotel_stay.review.check_out", text: $form.checkOutDate)
            TextField("hotel_stay.review.nights", text: $form.nightsText)
                .keyboardType(.numberPad)
            TextField("hotel_stay.review.room_type", text: $form.roomType)
            TextField("hotel_stay.review.confirmation", text: $form.confirmationNumber)
        }
    }

    private var chargeSection: some View {
        Section {
            TextField("hotel_stay.review.currency", text: $form.currency)
                .textInputAutocapitalization(.characters)
            TextField("hotel_stay.review.room_charge", text: $form.roomChargeText)
                .keyboardType(.decimalPad)
            TextField("hotel_stay.review.tax", text: $form.taxAmountText)
                .keyboardType(.decimalPad)
            TextField("hotel_stay.review.service_charge", text: $form.serviceChargeText)
                .keyboardType(.decimalPad)
            TextField("hotel_stay.review.food_beverage", text: $form.foodBeverageAmountText)
                .keyboardType(.decimalPad)
            TextField("hotel_stay.review.other_charges", text: $form.otherAmountText)
                .keyboardType(.decimalPad)
            TextField("hotel_stay.review.total", text: $form.totalAmountText)
                .keyboardType(.decimalPad)
            TextField("hotel_stay.review.payment_method", text: $form.paymentMethod)
            balanceRow
        } header: {
            Text("hotel_stay.review.charges")
        } footer: {
            if !form.isValid {
                Text("hotel_stay.review.validation.required")
                    .foregroundStyle(.red)
            }
        }
    }

    private var balanceRow: some View {
        let status = form.amountBalanceStatus
        return Label {
            Text(balanceMessageKey(for: status))
        } icon: {
            Image(systemName: balanceIconName(for: status))
        }
        .foregroundStyle(balanceColor(for: status))
    }

    private var sourceSection: some View {
        Section("hotel_stay.review.source") {
            LabeledContent("hotel_stay.review.source_type", value: form.sourceType.rawValue)
            if let sourceFileName = form.sourceFileName, !sourceFileName.isEmpty {
                LabeledContent("hotel_stay.review.source_file", value: sourceFileName)
            }
            if let subject = form.sourceEmailSubject, !subject.isEmpty {
                LabeledContent("hotel_stay.review.email_subject", value: subject)
            }
            if let sender = form.sourceEmailFrom, !sender.isEmpty {
                LabeledContent("hotel_stay.review.email_from", value: sender)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("hotel_stay.review.confidence")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: form.confidence, total: 1)
                Text(String(format: "%.0f%%", form.confidence * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rawTextSection: some View {
        Section("hotel_stay.review.raw_text") {
            ScrollView {
                Text(localizedRawText)
                    .font(.footnote.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 120)
        }
    }

    private var localizedRawText: String {
        let rawText = form.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else {
            return String(localized: "hotel_stay.review.raw_text.empty")
        }
        return rawTextLocalizer.localizedText(rawText)
    }

    private func confirmDraft() {
        do {
            let confirmed = try form.confirmedDraft(from: draft)
            onConfirm(confirmed)
            dismiss()
        } catch HotelStayReviewFormError.missingHotelName {
            validationMessageKey = "hotel_stay.review.validation.missing_hotel"
        } catch HotelStayReviewFormError.invalidTotalAmount {
            validationMessageKey = "hotel_stay.review.validation.invalid_total"
        } catch {
            validationMessageKey = "hotel_stay.review.validation.required"
        }
    }

    private func rejectDraft() {
        onReject(form.rejectedDraft(from: draft))
        dismiss()
    }

    private func balanceMessageKey(for status: HotelStayAmountBalanceStatus) -> LocalizedStringKey {
        switch status {
        case .balanced:
            return "hotel_stay.review.balance.balanced"
        case .missingBreakdown:
            return "hotel_stay.review.balance.missing_breakdown"
        case .imbalanced:
            return "hotel_stay.review.balance.imbalanced"
        }
    }

    private func balanceIconName(for status: HotelStayAmountBalanceStatus) -> String {
        switch status {
        case .balanced:
            return "checkmark.circle.fill"
        case .missingBreakdown:
            return "questionmark.circle"
        case .imbalanced:
            return "exclamationmark.triangle.fill"
        }
    }

    private func balanceColor(for status: HotelStayAmountBalanceStatus) -> Color {
        switch status {
        case .balanced:
            return .green
        case .missingBreakdown:
            return .secondary
        case .imbalanced:
            return .orange
        }
    }
}

#Preview {
    HotelStayReviewView(
        draft: HotelStayDraft(
            sourceType: .manualPDF,
            targetLedgerID: TodaySpendingSummary.defaultLedgerID,
            sourceFileName: "demo-folio.pdf",
            rawText: "Demo Bay Hotel\nConfirmation: ABC123\nTotal Amount: JPY 50000",
            parsedPayload: HotelFolioParsedPayload(
                hotelName: "Demo Bay Hotel",
                brand: "Demo Suites",
                group: "Demo Hospitality",
                city: "Tokyo",
                country: "Japan",
                checkInDate: "2026-06-20",
                checkOutDate: "2026-06-22",
                nights: 2,
                roomType: "King Bay View",
                confirmationNumber: "ABC123",
                currency: "JPY",
                roomCharge: 40000,
                tax: 4000,
                serviceCharge: 3000,
                foodBeverage: 2500,
                otherCharges: 500,
                totalAmount: 50000,
                paymentMethod: "Visa",
                confidence: 0.91,
                rawTextExcerpt: "Demo folio excerpt"
            ),
            confidence: 0.91,
            status: .needsReview
        )
    )
}
