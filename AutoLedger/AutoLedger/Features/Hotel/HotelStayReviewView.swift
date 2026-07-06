import AutoLedgerCore
import SwiftUI

struct HotelStayReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore

    let draft: HotelStayDraft
    let onConfirm: (HotelStayDraft) -> Void
    let onReject: (HotelStayDraft) -> Void

    @State private var form: HotelStayReviewForm
    @State private var validationMessageKey: String?
    @State private var conversionPreviewState: CurrencyConversionPreviewState = .idle
    private let rawTextLocalizer = HotelFolioRawTextLocalizer()

    private var targetCurrencyCode: String {
        store.ledgerCurrencyCode(for: draft.targetLedgerID)
    }

    private var normalizedFormCurrencyCode: String {
        LedgerCurrencyOption.supportedCode(matching: form.currency)
    }

    private var shouldShowCurrencyConversion: Bool {
        normalizedFormCurrencyCode != targetCurrencyCode
    }

    private var parsedTotalAmount: Double {
        LedgerAmountInputParser.parse(form.totalAmountText) ?? 0
    }

    private var conversionPreviewDate: Date {
        if let checkOutDate = AppFormatters.parseFlexibleDate(form.checkOutDate) {
            return checkOutDate
        }
        if let checkInDate = AppFormatters.parseFlexibleDate(form.checkInDate) {
            return checkInDate
        }
        return Date()
    }

    private var conversionPreviewTaskID: String {
        [
            normalizedFormCurrencyCode,
            targetCurrencyCode,
            String(format: "%.2f", parsedTotalAmount),
            form.checkInDate,
            form.checkOutDate
        ]
        .joined(separator: "|")
    }

    private var usableConversionQuote: CurrencyConversionPreviewQuote? {
        guard shouldShowCurrencyConversion,
              let quote = conversionPreviewState.quote,
              quote.sourceCurrencyCode == normalizedFormCurrencyCode,
              quote.targetCurrencyCode == targetCurrencyCode,
              abs(quote.sourceAmount - parsedTotalAmount) < 0.001
        else {
            return nil
        }
        return quote
    }

    init(
        draft: HotelStayDraft,
        onConfirm: @escaping (HotelStayDraft) -> Void = { _ in },
        onReject: @escaping (HotelStayDraft) -> Void = { _ in }
    ) {
        self.draft = draft
        self.onConfirm = onConfirm
        self.onReject = onReject
        var initialForm = HotelStayReviewForm(draft: draft)
        initialForm.applyLocalizedLocation()
        _form = State(initialValue: initialForm)
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
            .task(id: conversionPreviewTaskID) {
                await refreshConversionPreview()
            }
            .onChange(of: form.checkInDate) { _, _ in
                form.updateNightsFromStayDates()
            }
            .onChange(of: form.checkOutDate) { _, _ in
                form.updateNightsFromStayDates()
            }
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
            optionField("hotel_stay.review.hotel_name", text: $form.hotelName, options: form.hotelNameOptions)
            TextField("hotel_stay.review.brand", text: $form.hotelBrand)
            TextField("hotel_stay.review.group", text: $form.hotelGroup)
            locationOptionField("hotel_stay.review.country", text: $form.country, options: form.countryOptions) { selectedCountry in
                form.applyCountrySelection(selectedCountry)
            }
            locationOptionField("hotel_stay.review.city", text: $form.city, options: form.cityOptions) { selectedCity in
                form.applyCitySelection(selectedCity)
            }
        } header: {
            Text("hotel_stay.review.identity")
        } footer: {
            if let validationMessageKey {
                Text(LocalizedStringKey(validationMessageKey))
                    .foregroundStyle(.red)
            }
        }
    }

    private func locationOptionField(
        _ titleKey: LocalizedStringKey,
        text: Binding<String>,
        options: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        LabeledContent(titleKey) {
            HStack(spacing: 8) {
                TextField(titleKey, text: text)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(option) {
                            onSelect(option)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down.circle")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private var staySection: some View {
        Section("hotel_stay.review.stay") {
            optionField("hotel_stay.review.check_in", text: $form.checkInDate, options: form.checkInDateOptions)
            optionField("hotel_stay.review.check_out", text: $form.checkOutDate, options: form.checkOutDateOptions)
            TextField("hotel_stay.review.nights", text: $form.nightsText)
                .keyboardType(.numberPad)
            optionField("hotel_stay.review.room_type", text: $form.roomType, options: form.roomTypeOptions)
            optionField("hotel_stay.review.room_number", text: $form.roomNumber, options: form.roomNumberOptions)
            optionField("hotel_stay.review.confirmation", text: $form.confirmationNumber, options: form.confirmationNumberOptions)
        }
    }

    private func optionField(
        _ titleKey: LocalizedStringKey,
        text: Binding<String>,
        options: [String]
    ) -> some View {
        LabeledContent(titleKey) {
            HStack(spacing: 8) {
                TextField(titleKey, text: text)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !options.isEmpty {
                    Menu {
                        ForEach(options, id: \.self) { option in
                            Button(option) {
                                text.wrappedValue = option
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private var chargeSection: some View {
        Section {
            Picker("hotel_stay.review.currency", selection: $form.currency) {
                ForEach(form.currencyOptions, id: \.self) { currency in
                    Text(currency).tag(currency)
                }
            }

            if shouldShowCurrencyConversion {
                CurrencyConversionPreviewCard(
                    sourceAmount: parsedTotalAmount,
                    sourceCurrencyCode: normalizedFormCurrencyCode,
                    targetCurrencyCode: targetCurrencyCode,
                    state: conversionPreviewState,
                    onRetry: retryConversionPreview
                )
            }

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
            applyConversionQuoteToForm()
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

    private func retryConversionPreview() {
        Task {
            await refreshConversionPreview()
        }
    }

    private func refreshConversionPreview() async {
        guard shouldShowCurrencyConversion, parsedTotalAmount > 0 else {
            conversionPreviewState = .idle
            return
        }

        let sourceAmount = parsedTotalAmount
        let sourceCurrencyCode = normalizedFormCurrencyCode
        let destinationCurrencyCode = targetCurrencyCode
        let conversionDate = conversionPreviewDate
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

    private func applyConversionQuoteToForm() {
        guard let quote = usableConversionQuote else { return }
        var localizedData = form.localizedData ?? HotelStayLocalizedData()
        localizedData.currency = quote.sourceCurrencyCode
        localizedData.exchangeRate = quote.rate
        localizedData.exchangeRateDate = quote.rateDate
        localizedData.exchangeRateProvider = quote.provider
        form.localizedData = localizedData
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

private extension HotelStayReviewForm {
    var hotelNameOptions: [String] {
        Self.uniqueOptions([hotelName] + Self.hotelNameCandidates(in: rawText))
    }

    var checkInDateOptions: [String] {
        Self.uniqueOptions([checkInDate] + Self.dateCandidates(in: rawText))
    }

    var checkOutDateOptions: [String] {
        Self.uniqueOptions([checkOutDate] + Self.dateCandidates(in: rawText))
    }

    var roomTypeOptions: [String] {
        Self.uniqueOptions([roomType] + Self.labeledTextCandidates(
            in: rawText,
            labels: ["room type", "room category", "房型", "房间类型", "房間類型", "部屋タイプ"]
        ))
    }

    var roomNumberOptions: [String] {
        Self.uniqueOptions([roomNumber] + Self.labeledTextCandidates(
            in: rawText,
            labels: ["room no", "room number", "room #", "房号", "房號", "房间号码", "房間號碼", "部屋番号"]
        ))
    }

    var confirmationNumberOptions: [String] {
        Self.uniqueOptions([confirmationNumber] + Self.labeledTextCandidates(
            in: rawText,
            labels: [
                "confirmation", "confirmation no", "confirmation number", "reservation no",
                "booking no", "订单号", "訂單號", "预订号", "預訂號", "予約番号"
            ]
        ))
    }

    var cityOptions: [String] {
        let selectedCountry = HotelStayLocationCatalog.country(matching: country)
        return Self.uniqueOptions([city] + HotelStayLocationCatalog.cityOptions(for: selectedCountry))
    }

    var countryOptions: [String] {
        Self.uniqueOptions([country] + HotelStayLocationCatalog.countryOptions())
    }

    var currencyOptions: [String] {
        Self.uniqueOptions([currency] + LedgerCurrencyOption.common.map(\.code))
    }

    mutating func applyLocalizedLocation() {
        let localizedLocation = HotelStayLocationCatalog.localizedLocation(city: city, country: country)
        city = localizedLocation.city
        country = localizedLocation.country
    }

    mutating func applyCountrySelection(_ selectedCountry: String) {
        let previousCountry = HotelStayLocationCatalog.country(matching: country)
        let nextCountry = HotelStayLocationCatalog.country(matching: selectedCountry)
        country = nextCountry?.localizedName ?? selectedCountry

        guard previousCountry?.code != nextCountry?.code else { return }
        guard !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let nextCountry else {
            city = HotelStayLocationCatalog.localizedCityName(matching: city) ?? city
            return
        }

        if let cityInNextCountry = nextCountry.localizedCityName(matching: city) {
            city = cityInNextCountry
        } else {
            city = ""
        }
    }

    mutating func applyCitySelection(_ selectedCity: String) {
        let selectedCountry = HotelStayLocationCatalog.country(matching: country)
        city = HotelStayLocationCatalog.localizedCityName(matching: selectedCity, country: selectedCountry) ?? selectedCity
    }

    private static func uniqueOptions(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    private static func dateCandidates(in rawText: String) -> [String] {
        matches(
            pattern: #"\b(?:\d{4}[/-]\d{1,2}[/-]\d{1,2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b|\d{4}年\d{1,2}月\d{1,2}日"#,
            in: rawText
        )
        .compactMap { AppFormatters.normalizedDateString($0) ?? nonEmpty($0) }
    }

    private static func labeledTextCandidates(in rawText: String, labels: [String]) -> [String] {
        let labelPattern = labels
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let pattern = #"(?i)(?:"# + labelPattern + #")\s*(?:[:：#\-]|\s)\s*([^\n\r\t,，;；]{1,48})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(rawText.startIndex..<rawText.endIndex, in: rawText)
        return regex.matches(in: rawText, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: rawText) else {
                return nil
            }
            return cleanCandidateValue(String(rawText[valueRange]))
        }
    }

    private static func hotelNameCandidates(in rawText: String) -> [String] {
        rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard (3...80).contains(line.count) else { return false }
                let lowercased = line.lowercased()
                let hasHotelSignal = [
                    "hotel", "plaza", "resort", "inn", "suites", "holiday", "crowne",
                    "酒店", "宾馆", "賓館", "皇冠假日", "假日酒店", "洲际", "洲際", "ホテル"
                ].contains { lowercased.contains($0.lowercased()) }
                guard hasHotelSignal else { return false }
                return !lowercased.contains("http") &&
                    !lowercased.contains("@") &&
                    LedgerAmountInputParser.parse(line) == nil
            }
            .prefix(8)
            .map { String($0) }
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let valueRange = Range(match.range, in: text) else { return nil }
            return String(text[valueRange])
        }
    }

    private static func cleanCandidateValue(_ value: String) -> String? {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[\s]{2,}"#, with: " ", options: .regularExpression)
        let stopCharacters = CharacterSet(charactersIn: "，,;；")
        let firstSegment = trimmed
            .components(separatedBy: stopCharacters)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return nonEmpty(firstSegment)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
                roomNumber: "2609",
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
    .environmentObject(LedgerStore())
}
