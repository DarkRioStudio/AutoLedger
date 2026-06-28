import AutoLedgerCore
#if canImport(PDFKit)
import PDFKit
#endif
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct HotelStayListView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let records: [HotelStayRecord]
    let drafts: [HotelStayDraft]
    let transactions: [Transaction]
    let ledgerID: String?
    let isImporting: Bool
    let statusMessage: String?
    let onImportPDF: (() -> Void)?
    let onImportEmail: (() -> Void)?
    let onReviewDraft: ((HotelStayDraft) -> Void)?
    let onUpdateRecord: ((HotelStayRecord, Transaction?) -> Bool)?
    let onDeleteRecord: ((HotelStayRecord) -> Bool)?
    @Binding private var selectedRecordID: UUID?
    @State private var pendingDeleteRecord: HotelStayRecord?

    private let presenter = HotelStayArchivePresenter()

    init(
        records: [HotelStayRecord],
        drafts: [HotelStayDraft] = [],
        transactions: [Transaction] = [],
        ledgerID: String? = nil,
        isImporting: Bool = false,
        statusMessage: String? = nil,
        selectedRecordID: Binding<UUID?> = .constant(nil),
        onImportPDF: (() -> Void)? = nil,
        onImportEmail: (() -> Void)? = nil,
        onReviewDraft: ((HotelStayDraft) -> Void)? = nil,
        onUpdateRecord: ((HotelStayRecord, Transaction?) -> Bool)? = nil,
        onDeleteRecord: ((HotelStayRecord) -> Bool)? = nil
    ) {
        self.records = records
        self.drafts = drafts
        self.transactions = transactions
        self.ledgerID = ledgerID
        self.isImporting = isImporting
        self.statusMessage = statusMessage
        self.onImportPDF = onImportPDF
        self.onImportEmail = onImportEmail
        self.onReviewDraft = onReviewDraft
        self.onUpdateRecord = onUpdateRecord
        self.onDeleteRecord = onDeleteRecord
        self._selectedRecordID = selectedRecordID
    }

    private var hasImportActions: Bool {
        onImportPDF != nil || onImportEmail != nil
    }

    private var snapshot: HotelStayListSnapshot {
        presenter.makeListSnapshot(records: records, ledgerID: ledgerID)
    }

    private var pendingDrafts: [HotelStayDraft] {
        drafts
            .filter { draft in
                switch draft.status {
                case .imported, .textExtracted, .parsed, .needsReview:
                    break
                case .confirmed, .rejected, .postedToLedger:
                    return false
                }
                guard let ledgerID else { return true }
                return (draft.targetLedgerID ?? TodaySpendingSummary.defaultLedgerID) == ledgerID
            }
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var hasListContent: Bool {
        !snapshot.rows.isEmpty || !pendingDrafts.isEmpty
    }

    private var recordByID: [UUID: HotelStayRecord] {
        Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    }

    private var selectedRecord: HotelStayRecord? {
        guard let selectedRecordID else { return nil }
        return recordByID[selectedRecordID]
    }

    var body: some View {
        NavigationSplitView {
            listColumn
                .navigationTitle("hotel_stay.list.title")
                .navigationSplitViewColumnWidth(min: 340, ideal: 420, max: 520)
                .toolbar {
                    if hasImportActions {
                        ToolbarItem(placement: .primaryAction) {
                            importMenu
                        }
                    }
                }
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .autoLedgerNavigationBarChrome()
        .onAppear {
            reconcileSelection()
        }
        .onChange(of: snapshot.rows.map(\.id)) { _, _ in
            reconcileSelection()
        }
        .onChange(of: horizontalSizeClass) { _, _ in
            reconcileSelection()
        }
        .confirmationDialog(
            "hotel_stay.delete.confirm.title",
            isPresented: Binding(
                get: { pendingDeleteRecord != nil },
                set: { if !$0 { pendingDeleteRecord = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingDeleteRecord {
                Button("hotel_stay.delete.confirm.action", role: .destructive) {
                    deleteRecord(pendingDeleteRecord)
                }
            }
            Button("common.cancel", role: .cancel) {
                pendingDeleteRecord = nil
            }
        } message: {
            Text("hotel_stay.delete.confirm.message")
        }
    }

    @ViewBuilder
    private var listColumn: some View {
        if !hasListContent {
            VStack(spacing: 16) {
                if let statusMessage {
                    statusRow(statusMessage)
                        .padding(.horizontal, 20)
                }
                ContentUnavailableView(
                    "hotel_stay.list.empty.title",
                    systemImage: "bed.double",
                    description: Text("hotel_stay.list.empty.description")
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .autoLedgerScreenChrome()
        } else {
            List(selection: $selectedRecordID) {
                if statusMessage != nil {
                    importSection
                }
                if !pendingDrafts.isEmpty {
                    pendingDraftSection
                }
                if !snapshot.rows.isEmpty {
                    summarySection
                    staySection
                }
            }
            .autoLedgerListChrome()
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let record = selectedRecord {
            HotelStayDetailView(
                record: record,
                transactions: transactions,
                ledgerID: ledgerID,
                onUpdateRecord: onUpdateRecord,
                onSaveRecord: {
                    selectedRecordID = nil
                },
                onDeleteRecord: onDeleteRecord
            )
        } else {
            ContentUnavailableView(
                "hotel_stay.detail.empty.title",
                systemImage: "bed.double",
                description: Text("hotel_stay.detail.empty.description")
            )
            .autoLedgerScreenChrome()
        }
    }

    private var importMenu: some View {
        Menu {
            if onImportPDF != nil {
                Button {
                    onImportPDF?()
                } label: {
                    Label("hotel_stay.import.pdf", systemImage: "doc.badge.plus")
                }
            }
            if onImportEmail != nil {
                Button {
                    onImportEmail?()
                } label: {
                    Label("hotel_stay.import.email", systemImage: "envelope.badge")
                }
            }
        } label: {
            Label("hotel_stay.import.menu", systemImage: "plus")
        }
        .disabled(isImporting)
    }

    private var importSection: some View {
        Section {
            if let statusMessage {
                statusRow(statusMessage)
            }
        }
        .listRowBackground(AppTheme.card)
    }

    private func statusRow(_ message: String) -> some View {
        Label {
            Text(message)
                .font(.footnote)
                .foregroundStyle(AppTheme.mutedInk)
                .textSelection(.enabled)
        } icon: {
            if isImporting {
                ProgressView()
            } else {
                Image(systemName: "info.circle")
            }
        }
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 12) {
                summaryMetric(
                    titleKey: "hotel_stay.list.summary.count",
                    value: String(snapshot.rows.count)
                )
                summaryMetric(
                    titleKey: "hotel_stay.list.summary.nights",
                    value: String(snapshot.totalNights)
                )
                summaryMetric(
                    titleKey: "hotel_stay.list.summary.average",
                    value: averageNightlyRateText
                )
            }
            .padding(.vertical, 4)
            .listRowBackground(AppTheme.card)
        }
    }

    private var averageNightlyRateText: String {
        if snapshot.hasMixedCurrencies {
            return String(localized: "hotel_stay.list.summary.average_mixed_currency")
        }
        guard let averageNightlyRate = snapshot.averageNightlyRate,
              let currency = snapshot.averageNightlyRateCurrency else {
            return "-"
        }
        return presenter.localizedAmountText(averageNightlyRate, currency: currency)
    }

    private var staySection: some View {
        Section {
            let recordsByID = recordByID
            ForEach(snapshot.rows) { row in
                if let record = recordsByID[row.id] {
                    NavigationLink(value: row.id) {
                        HotelStayRowView(row: row)
                    }
                    .autoLedgerSelectableRowBackground(selectedRecordID == row.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if onDeleteRecord != nil {
                            Button(role: .destructive) {
                                pendingDeleteRecord = record
                            } label: {
                                Label("hotel_stay.delete.button", systemImage: "trash")
                            }
                        }
                    }
                    .contextMenu {
                        hotelRecordActionItems(for: record)
                    }
                }
            }
        } header: {
            Text("hotel_stay.list.section.records")
        } footer: {
            Text(String(format: String(localized: "hotel_stay.list.footer_format"), snapshot.rows.count))
        }
    }

    private var pendingDraftSection: some View {
        Section {
            ForEach(pendingDrafts) { draft in
                Button {
                    onReviewDraft?(draft)
                } label: {
                    HotelStayDraftRowView(draft: draft)
                }
                .buttonStyle(.plain)
                .listRowBackground(AppTheme.card)
            }
        } header: {
            Text("hotel_stay.list.section.pending_drafts")
        } footer: {
            Text(String(format: String(localized: "hotel_stay.list.pending_drafts.footer_format"), pendingDrafts.count))
        }
    }

    @ViewBuilder
    private func hotelRecordActionItems(for record: HotelStayRecord) -> some View {
        if onDeleteRecord != nil {
            Button(role: .destructive) {
                pendingDeleteRecord = record
            } label: {
                Label("hotel_stay.delete.button", systemImage: "trash")
            }
        }
    }

    private func summaryMetric(titleKey: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reconcileSelection() {
        let rowIDs = snapshot.rows.map(\.id)
        guard !rowIDs.isEmpty else {
            selectedRecordID = nil
            return
        }

        if let selectedRecordID, rowIDs.contains(selectedRecordID) {
            return
        }

        selectedRecordID = horizontalSizeClass == .regular ? rowIDs.first : nil
    }

    private func deleteRecord(_ record: HotelStayRecord) {
        let nextID = nextSelectionID(afterDeleting: record)
        if onDeleteRecord?(record) == true,
           selectedRecordID == record.id {
            selectedRecordID = horizontalSizeClass == .regular ? nextID : nil
        }
        pendingDeleteRecord = nil
    }

    private func nextSelectionID(afterDeleting record: HotelStayRecord) -> UUID? {
        let rowIDs = snapshot.rows.map(\.id).filter { $0 != record.id }
        guard !rowIDs.isEmpty else { return nil }
        let originalRows = snapshot.rows.map(\.id)
        guard let deletedIndex = originalRows.firstIndex(of: record.id) else {
            return rowIDs.first
        }
        return rowIDs[min(deletedIndex, rowIDs.count - 1)]
    }
}

private struct HotelStayRowView: View {
    let row: HotelStayListRow

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bed.double.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28, height: 28)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.hotelName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                        .layoutPriority(3)

                    Spacer(minLength: 4)

                    Text(row.totalAmountText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                        .layoutPriority(1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if !row.locationText.isEmpty {
                        Text(row.locationText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if !row.brandGroupText.isEmpty {
                        Text(row.brandGroupText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    HStack(spacing: 8) {
                        if !row.dateRangeText.isEmpty {
                            Text(row.dateRangeText)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        if !row.nightsText.isEmpty {
                            Text(String(format: String(localized: "hotel_stay.list.nights_format"), row.nightsText))
                                .lineLimit(1)
                        }
                    }
                    HStack(spacing: 8) {
                        Label(sourceTitleKey(for: row.sourceType), systemImage: "doc.text")
                            .lineLimit(1)
                        Label(statusTitleKey(for: row.linkStatus), systemImage: statusIconName(for: row.linkStatus))
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func sourceTitleKey(for sourceType: HotelFolioSourceType) -> LocalizedStringKey {
        switch sourceType {
        case .manualPDF:
            return "hotel_stay.source.manual_pdf"
        case .localEmailIMAP:
            return "hotel_stay.source.local_email_imap"
        case .cloudWorker:
            return "hotel_stay.source.cloud_worker"
        case .shareExtension:
            return "hotel_stay.source.share_extension"
        }
    }

    private func statusTitleKey(for status: HotelStayLedgerLinkStatus) -> LocalizedStringKey {
        switch status {
        case .postedToLedger:
            return "hotel_stay.status.posted"
        case .missingTransaction:
            return "hotel_stay.status.missing_transaction"
        }
    }

    private func statusIconName(for status: HotelStayLedgerLinkStatus) -> String {
        switch status {
        case .postedToLedger:
            return "checkmark.circle.fill"
        case .missingTransaction:
            return "exclamationmark.circle"
        }
    }
}

private struct HotelStayDraftRowView: View {
    let draft: HotelStayDraft
    private let presenter = HotelStayArchivePresenter()

    private var payload: HotelFolioParsedPayload? {
        draft.parsedPayload
    }

    private var title: String {
        draft.localizedData?.hotelName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? payload?.hotelName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? draft.sourceFileName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? draft.sourceEmailSubject?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? String(localized: "hotel_stay.draft.unknown_hotel")
    }

    private var amountText: String {
        let totalAmount = draft.localizedData?.totalAmount ?? payload?.totalAmount
        guard let totalAmount else {
            return String(localized: "hotel_stay.draft.amount_pending")
        }
        let currency = draft.localizedData?.currency?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? payload?.currency?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? "CNY"
        return presenter.localizedAmountText(totalAmount, currency: currency)
    }

    private var locationText: String? {
        [
            draft.localizedData?.city ?? payload?.city,
            draft.localizedData?.country ?? payload?.country
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .joined(separator: " / ")
            .nilIfEmpty
    }

    private var dateText: String? {
        let checkIn = payload?.checkInDate?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let checkOut = payload?.checkOutDate?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if let checkIn, let checkOut {
            return "\(checkIn) - \(checkOut)"
        }
        return checkOut ?? checkIn
    }

    private var sourceDetailText: String? {
        draft.sourceEmailSubject?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? draft.sourceFileName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 30, height: 30)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .allowsTightening(true)
                        .layoutPriority(1)

                    Spacer(minLength: 6)

                    Text(amountText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                        .layoutPriority(2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let locationText {
                        Text(locationText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let dateText {
                        Text(dateText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let sourceDetailText {
                        Text(sourceDetailText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    HStack(spacing: 8) {
                        Label(sourceTitleKey(for: draft.sourceType), systemImage: "tray.and.arrow.down")
                            .lineLimit(1)
                        Label("hotel_stay.draft.status.needs_review", systemImage: "exclamationmark.circle")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func sourceTitleKey(for sourceType: HotelFolioSourceType) -> LocalizedStringKey {
        switch sourceType {
        case .manualPDF:
            return "hotel_stay.source.manual_pdf"
        case .localEmailIMAP:
            return "hotel_stay.source.local_email_imap"
        case .cloudWorker:
            return "hotel_stay.source.cloud_worker"
        case .shareExtension:
            return "hotel_stay.source.share_extension"
        }
    }
}

struct HotelStayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var form: HotelStayRecordEditForm
    @State private var saveMessage: String?
    @State private var saveMessageIsSuccess = false
    @State private var showsDeleteConfirmation = false

    let record: HotelStayRecord
    let transactions: [Transaction]
    let ledgerID: String?
    let onUpdateRecord: ((HotelStayRecord, Transaction?) -> Bool)?
    let onSaveRecord: (() -> Void)?
    let onDeleteRecord: ((HotelStayRecord) -> Bool)?

    private let presenter = HotelStayArchivePresenter()
    private let rawTextLocalizer = HotelFolioRawTextLocalizer()

    init(
        record: HotelStayRecord,
        transactions: [Transaction] = [],
        ledgerID: String? = nil,
        onUpdateRecord: ((HotelStayRecord, Transaction?) -> Bool)? = nil,
        onSaveRecord: (() -> Void)? = nil,
        onDeleteRecord: ((HotelStayRecord) -> Bool)? = nil
    ) {
        self.record = record
        self.transactions = transactions
        self.ledgerID = ledgerID
        self.onUpdateRecord = onUpdateRecord
        self.onSaveRecord = onSaveRecord
        self.onDeleteRecord = onDeleteRecord
        let linkedTransaction = Self.linkedTransaction(for: record, transactions: transactions, ledgerID: ledgerID)
        self._form = State(initialValue: HotelStayRecordEditForm(record: record, linkedTransaction: linkedTransaction))
    }

    private var snapshot: HotelStayDetailSnapshot {
        presenter.makeDetailSnapshot(record: record, transactions: transactions, ledgerID: ledgerID)
    }

    private var linkedTransaction: Transaction? {
        Self.linkedTransaction(for: record, transactions: transactions, ledgerID: ledgerID)
    }

    var body: some View {
        List {
            detailHeader
            identityEditorSection
            stayEditorSection
            chargeEditorSection
            linkedTransactionEditorSection
            fieldSection(titleKey: "hotel_stay.detail.source", fields: snapshot.sourceFields)
            sourcePDFSection
            rawTextSection
        }
        .autoLedgerListChrome()
        .navigationTitle("hotel_stay.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .autoLedgerNavigationBarChrome()
        .toolbar {
            if onUpdateRecord != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        saveEdits()
                    } label: {
                        Label("common.save", systemImage: "checkmark")
                    }
                    .disabled(!form.isValid)
                }
            }
            if onDeleteRecord != nil {
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            showsDeleteConfirmation = true
                        } label: {
                            Label("hotel_stay.delete.button", systemImage: "trash")
                        }
                    } label: {
                        Label("common.more_actions", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .onChange(of: record) { oldRecord, newRecord in
            form = HotelStayRecordEditForm(record: newRecord, linkedTransaction: linkedTransaction)
            if oldRecord.id != newRecord.id {
                saveMessage = nil
                saveMessageIsSuccess = false
            }
        }
        .onChange(of: form.checkInDateValue) { _, _ in
            form.updateNightsFromDates()
        }
        .onChange(of: form.checkOutDateValue) { _, _ in
            form.updateNightsFromDates()
        }
        .confirmationDialog(
            "hotel_stay.delete.confirm.title",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("hotel_stay.delete.confirm.action", role: .destructive) {
                if onDeleteRecord?(record) == true {
                    dismiss()
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("hotel_stay.delete.confirm.message")
        }
    }

    private var detailHeader: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(form.hotelName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? snapshot.row.hotelName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                HStack(spacing: 8) {
                    if let locationText = form.locationText {
                        Label(locationText, systemImage: "mappin.and.ellipse")
                    }
                    if let nightsText = form.nightsText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                        Label(
                            String(format: String(localized: "hotel_stay.list.nights_format"), nightsText),
                            systemImage: "moon"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)

                Text(form.displayTotalAmountText(using: presenter))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.accent)

                if let saveMessage {
                    Label(saveMessage, systemImage: saveMessageIsSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(saveMessageIsSuccess ? AppTheme.accent : .orange)
                }
            }
            .padding(.vertical, 6)
            .listRowBackground(AppTheme.card)
        }
    }

    private var identityEditorSection: some View {
        Section("hotel_stay.detail.identity") {
            editableTextField("hotel_stay.review.hotel_name", text: $form.hotelName)
            editableTextField("hotel_stay.review.brand", text: $form.hotelBrand)
            editableTextField("hotel_stay.review.group", text: $form.hotelGroup)
            editableOptionField("hotel_stay.review.city", text: $form.city, options: form.cityOptions)
            editableOptionField("hotel_stay.review.country", text: $form.country, options: form.countryOptions)
        }
    }

    private var stayEditorSection: some View {
        Section("hotel_stay.detail.stay") {
            DatePicker("hotel_stay.review.check_in", selection: $form.checkInDateValue, displayedComponents: [.date])
            DatePicker("hotel_stay.review.check_out", selection: $form.checkOutDateValue, displayedComponents: [.date])
            editableNumberField("hotel_stay.review.nights", text: $form.nightsText)
            editableTextField("hotel_stay.review.room_type", text: $form.roomType)
            editableTextField("hotel_stay.review.confirmation", text: $form.confirmationNumber)
        }
    }

    private var chargeEditorSection: some View {
        Section("hotel_stay.detail.charges") {
            Picker("hotel_stay.review.currency", selection: $form.currency) {
                ForEach(form.currencyOptions, id: \.self) { currency in
                    Text(currency).tag(currency)
                }
            }
            .pickerStyle(.menu)
            editableAmountField("hotel_stay.review.room_charge", text: $form.roomChargeText)
            editableAmountField("hotel_stay.review.tax", text: $form.taxAmountText)
            editableAmountField("hotel_stay.review.service_charge", text: $form.serviceChargeText)
            editableAmountField("hotel_stay.review.food_beverage", text: $form.foodBeverageAmountText)
            editableAmountField("hotel_stay.review.other_charges", text: $form.otherAmountText)
            editableAmountField("hotel_stay.review.total", text: $form.totalAmountText)
            editableTextField("hotel_stay.review.payment_method", text: $form.paymentMethod)
            if !form.isValid {
                Text("hotel_stay.review.validation.required")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func fieldSection(
        titleKey: LocalizedStringKey,
        fields: [HotelStayDetailField]
    ) -> some View {
        Section(titleKey) {
            ForEach(fields, id: \.key) { field in
                LabeledContent(fieldTitleKey(for: field.key), value: displayValue(for: field))
            }
        }
    }

    private var linkedTransactionEditorSection: some View {
        Section("hotel_stay.detail.linked_transaction") {
            if linkedTransaction != nil {
                editableTextField("hotel_stay.detail.transaction_merchant", text: $form.transactionMerchant)
                editableAmountField("hotel_stay.detail.transaction_amount", text: $form.transactionAmountText)
                DatePicker(
                    "hotel_stay.detail.transaction_date",
                    selection: $form.transactionOccurredAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
                LabeledContent("hotel_stay.detail.transaction_category", value: TransactionCategory.hotel.title)
                editableLongTextField("hotel_stay.detail.transaction_note", text: $form.transactionNote)
            } else {
                Label("hotel_stay.detail.linked_transaction.missing", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var sourcePDFSection: some View {
        Section("hotel_stay.detail.source_pdf") {
            if let sourcePDFData = record.sourcePDFData, !sourcePDFData.isEmpty {
                #if canImport(PDFKit)
                HotelStayPDFPreview(data: sourcePDFData)
                    .frame(minHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel(Text("hotel_stay.detail.source_pdf"))
                #else
                Label("hotel_stay.detail.source_pdf.unsupported", systemImage: "doc.richtext")
                    .foregroundStyle(AppTheme.mutedInk)
                #endif
            } else {
                Label("hotel_stay.detail.source_pdf.empty", systemImage: "doc")
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
    }

    private var rawTextSection: some View {
        Section("hotel_stay.detail.raw_text") {
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
        let rawText = snapshot.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else {
            return String(localized: "hotel_stay.detail.raw_text.empty")
        }
        return rawTextLocalizer.localizedText(rawText)
    }

    private func displayValue(for field: HotelStayDetailField) -> String {
        if field.key == .sourceType,
           let sourceType = HotelFolioSourceType(rawValue: field.value) {
            return NSLocalizedString(sourceStringKey(for: sourceType), comment: "")
        }
        return field.value
    }

    private func sourceStringKey(for sourceType: HotelFolioSourceType) -> String {
        switch sourceType {
        case .manualPDF:
            return "hotel_stay.source.manual_pdf"
        case .localEmailIMAP:
            return "hotel_stay.source.local_email_imap"
        case .cloudWorker:
            return "hotel_stay.source.cloud_worker"
        case .shareExtension:
            return "hotel_stay.source.share_extension"
        }
    }

    private func fieldTitleKey(for key: HotelStayDetailFieldKey) -> LocalizedStringKey {
        switch key {
        case .hotelName:
            return "hotel_stay.review.hotel_name"
        case .hotelBrand:
            return "hotel_stay.review.brand"
        case .hotelGroup:
            return "hotel_stay.review.group"
        case .city:
            return "hotel_stay.review.city"
        case .country:
            return "hotel_stay.review.country"
        case .checkInDate:
            return "hotel_stay.review.check_in"
        case .checkOutDate:
            return "hotel_stay.review.check_out"
        case .nights:
            return "hotel_stay.review.nights"
        case .roomType:
            return "hotel_stay.review.room_type"
        case .confirmationNumber:
            return "hotel_stay.review.confirmation"
        case .currency:
            return "hotel_stay.review.currency"
        case .roomCharge:
            return "hotel_stay.review.room_charge"
        case .taxAmount:
            return "hotel_stay.review.tax"
        case .serviceCharge:
            return "hotel_stay.review.service_charge"
        case .foodBeverageAmount:
            return "hotel_stay.review.food_beverage"
        case .otherAmount:
            return "hotel_stay.review.other_charges"
        case .totalAmount:
            return "hotel_stay.review.total"
        case .paymentMethod:
            return "hotel_stay.review.payment_method"
        case .sourceType:
            return "hotel_stay.review.source_type"
        case .sourceFileName:
            return "hotel_stay.review.source_file"
        case .confidence:
            return "hotel_stay.review.confidence"
        case .linkedTransactionID:
            return "hotel_stay.detail.linked_transaction_id"
        }
    }

    private func editableTextField(
        _ titleKey: LocalizedStringKey,
        text: Binding<String>
    ) -> some View {
        LabeledContent(titleKey) {
            TextField(titleKey, text: text, axis: .vertical)
                .multilineTextAlignment(.trailing)
                .lineLimit(1...3)
        }
    }

    private func editableOptionField(
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

    private func editableNumberField(
        _ titleKey: LocalizedStringKey,
        text: Binding<String>
    ) -> some View {
        LabeledContent(titleKey) {
            TextField(titleKey, text: text)
                .multilineTextAlignment(.trailing)
                .hotelNumberKeyboard()
        }
    }

    private func editableAmountField(
        _ titleKey: LocalizedStringKey,
        text: Binding<String>
    ) -> some View {
        LabeledContent(titleKey) {
            TextField(titleKey, text: text)
                .multilineTextAlignment(.trailing)
                .hotelDecimalKeyboard()
        }
    }

    private func editableLongTextField(
        _ titleKey: LocalizedStringKey,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
            TextField(titleKey, text: text, axis: .vertical)
                .lineLimit(4...10)
                .textFieldStyle(.plain)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.canvas.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func saveEdits() {
        guard let onUpdateRecord else { return }
        guard form.isValid else {
            saveMessage = String(localized: "hotel_stay.review.validation.required")
            saveMessageIsSuccess = false
            return
        }

        let updatedRecord = form.updatedRecord(from: record)
        let updatedTransaction = form.updatedTransaction(from: linkedTransaction, record: updatedRecord)
        if onUpdateRecord(updatedRecord, updatedTransaction) {
            saveMessage = String(localized: "common.saved")
            saveMessageIsSuccess = true
            form = HotelStayRecordEditForm(record: updatedRecord, linkedTransaction: updatedTransaction)
            onSaveRecord?()
            dismiss()
        } else {
            saveMessage = String(localized: "hotel_stay.detail.save.failed")
            saveMessageIsSuccess = false
        }
    }

    private static func linkedTransaction(
        for record: HotelStayRecord,
        transactions: [Transaction],
        ledgerID: String?
    ) -> Transaction? {
        let scopedTransactions: [Transaction]
        if let ledgerID = ledgerID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !ledgerID.isEmpty {
            scopedTransactions = transactions.filter { $0.resolvedLedgerID() == ledgerID }
        } else {
            scopedTransactions = transactions
        }
        return scopedTransactions.first { transaction in
            transaction.id == record.linkedTransactionID ||
            transaction.hotelStayRecordID == record.id
        }
    }
}

private struct HotelStayRecordEditForm: Equatable {
    var hotelName: String
    var hotelGroup: String
    var hotelBrand: String
    var city: String
    var country: String
    var checkInDateValue: Date
    var checkOutDateValue: Date
    var nightsText: String
    var roomType: String
    var confirmationNumber: String
    var currency: String
    var roomChargeText: String
    var taxAmountText: String
    var serviceChargeText: String
    var foodBeverageAmountText: String
    var otherAmountText: String
    var totalAmountText: String
    var paymentMethod: String
    var transactionMerchant: String
    var transactionAmountText: String
    var transactionOccurredAt: Date
    var transactionNote: String

    private let existingLocalizedData: HotelStayLocalizedData?

    init(record: HotelStayRecord, linkedTransaction: Transaction?) {
        existingLocalizedData = record.localizedData
        hotelName = Self.displayString(record.localizedData?.hotelName, fallback: record.hotelName)
        hotelGroup = Self.displayString(record.localizedData?.group, fallback: record.hotelGroup)
        hotelBrand = Self.displayString(record.localizedData?.brand, fallback: record.hotelBrand)
        city = Self.displayString(record.localizedData?.city, fallback: record.city)
        country = Self.displayString(record.localizedData?.country, fallback: record.country)
        checkInDateValue = Self.parsedDate(record.checkInDate) ?? record.createdAt
        checkOutDateValue = Self.parsedDate(record.checkOutDate) ?? record.updatedAt
        nightsText = record.nights.map(String.init) ?? ""
        roomType = Self.displayString(record.localizedData?.roomType, fallback: record.roomType)
        confirmationNumber = record.confirmationNumber ?? ""
        currency = Self.displayString(record.localizedData?.currency, fallback: record.currency)
        roomChargeText = Self.amountText(record.localizedData?.roomCharge ?? record.roomCharge)
        taxAmountText = Self.amountText(record.localizedData?.taxAmount ?? record.taxAmount)
        serviceChargeText = Self.amountText(record.localizedData?.serviceCharge ?? record.serviceCharge)
        foodBeverageAmountText = Self.amountText(record.localizedData?.foodBeverageAmount ?? record.foodBeverageAmount)
        otherAmountText = Self.amountText(record.localizedData?.otherAmount ?? record.otherAmount)
        totalAmountText = Self.amountText(record.localizedData?.totalAmount ?? record.totalAmount)
        paymentMethod = Self.displayString(record.localizedData?.paymentMethod, fallback: record.paymentMethod)
        transactionMerchant = linkedTransaction?.merchant ?? Self.displayString(record.localizedData?.hotelName, fallback: record.hotelName)
        transactionAmountText = Self.amountText(linkedTransaction?.amount ?? record.localizedData?.totalAmount ?? record.totalAmount)
        transactionOccurredAt = linkedTransaction?.occurredAt ?? Self.defaultTransactionDate(checkOutDate: record.checkOutDate, fallback: record.updatedAt)
        transactionNote = linkedTransaction?.note ?? ""
    }

    var isValid: Bool {
        !hotelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parsedAmount(totalAmountText) > 0 &&
        parsedAmount(transactionAmountText) > 0
    }

    var locationText: String? {
        [city, country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            .nilIfEmpty
    }

    var cityOptions: [String] {
        Self.uniqueOptions([city] + Self.commonCityOptions)
    }

    var countryOptions: [String] {
        Self.uniqueOptions([country] + Self.commonCountryOptions)
    }

    var currencyOptions: [String] {
        Self.uniqueOptions([currency] + Self.commonCurrencyOptions)
    }

    mutating func updateNightsFromDates() {
        let start = AppFormatters.calendar.startOfDay(for: checkInDateValue)
        let end = AppFormatters.calendar.startOfDay(for: checkOutDateValue)
        guard let days = AppFormatters.calendar.dateComponents([.day], from: start, to: end).day,
              days > 0 else {
            return
        }
        nightsText = String(days)
    }

    func displayTotalAmountText(using presenter: HotelStayArchivePresenter) -> String {
        presenter.localizedAmountText(parsedAmount(totalAmountText), currency: currency)
    }

    func updatedRecord(from record: HotelStayRecord) -> HotelStayRecord {
        var updated = record
        updated.hotelName = trimmedRequired(hotelName, fallback: record.hotelName)
        updated.checkInDate = Self.dateText(checkInDateValue)
        updated.checkOutDate = Self.dateText(checkOutDateValue)
        updated.nights = Int(nightsText.trimmingCharacters(in: .whitespacesAndNewlines))
        updated.confirmationNumber = trimmedOptional(confirmationNumber)
        updated.currency = trimmedRequired(currency, fallback: record.currency)
        updated.roomCharge = parsedAmount(roomChargeText)
        updated.taxAmount = parsedAmount(taxAmountText)
        updated.serviceCharge = parsedAmount(serviceChargeText)
        updated.foodBeverageAmount = parsedAmount(foodBeverageAmountText)
        updated.otherAmount = parsedAmount(otherAmountText)
        updated.totalAmount = parsedAmount(totalAmountText)
        updated.hotelGroup = trimmedOptional(hotelGroup)
        updated.hotelBrand = trimmedOptional(hotelBrand)
        updated.city = trimmedOptional(city)
        updated.country = trimmedOptional(country)
        updated.roomType = trimmedOptional(roomType)
        updated.paymentMethod = trimmedOptional(paymentMethod)
        updated.localizedData = HotelStayLocalizedData(
            hotelName: trimmedOptional(hotelName),
            brand: trimmedOptional(hotelBrand),
            group: trimmedOptional(hotelGroup),
            city: trimmedOptional(city),
            country: trimmedOptional(country),
            roomType: trimmedOptional(roomType),
            currency: trimmedOptional(currency),
            roomCharge: parsedAmount(roomChargeText),
            taxAmount: parsedAmount(taxAmountText),
            serviceCharge: parsedAmount(serviceChargeText),
            foodBeverageAmount: parsedAmount(foodBeverageAmountText),
            otherAmount: parsedAmount(otherAmountText),
            totalAmount: parsedAmount(totalAmountText),
            paymentMethod: trimmedOptional(paymentMethod),
            exchangeRate: existingLocalizedData?.exchangeRate,
            exchangeRateDate: existingLocalizedData?.exchangeRateDate,
            exchangeRateProvider: existingLocalizedData?.exchangeRateProvider,
            targetLocaleIdentifier: existingLocalizedData?.targetLocaleIdentifier,
            generatedAt: Date()
        )
        return updated
    }

    func updatedTransaction(from transaction: Transaction?, record: HotelStayRecord) -> Transaction? {
        guard let transaction else { return nil }
        return Transaction(
            id: transaction.id,
            merchant: trimmedRequired(transactionMerchant, fallback: record.localizedData?.hotelName ?? record.hotelName),
            amount: parsedAmount(transactionAmountText),
            occurredAt: transactionOccurredAt,
            categoryLabel: TransactionCategory.hotel.rawValue,
            sourceLabel: transaction.source,
            note: transactionNote,
            ledgerID: transaction.resolvedLedgerID(defaultLedgerID: record.ledgerID),
            hotelStayRecordID: record.id
        )
    }

    private static func defaultTransactionDate(checkOutDate: String?, fallback: Date) -> Date {
        let baseDate = checkOutDate.flatMap(AppFormatters.parseFlexibleDate) ?? fallback
        var components = AppFormatters.calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = 16
        components.minute = 0
        components.second = 0
        return AppFormatters.calendar.date(from: components) ?? fallback
    }

    private static func parsedDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return AppFormatters.parseFlexibleDate(value)
    }

    private static func dateText(_ date: Date) -> String {
        let components = AppFormatters.calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func uniqueOptions(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    private static let commonCityOptions = [
        "北京", "上海", "广州", "深圳", "重庆", "成都", "杭州", "南京", "天津", "西安",
        "香港", "澳门", "台北", "东京", "大阪", "京都", "首尔", "曼谷", "新加坡",
        "New York", "Los Angeles", "San Francisco", "London", "Paris", "Berlin"
    ]

    private static let commonCountryOptions = [
        "中国", "中国香港", "中国澳门", "中国台湾", "日本", "韩国", "新加坡", "泰国",
        "美国", "英国", "法国", "德国", "澳大利亚", "加拿大", "United States",
        "United Kingdom", "Japan", "Singapore"
    ]

    private static let commonCurrencyOptions = [
        "CNY", "USD", "JPY", "EUR", "GBP", "HKD", "MOP", "TWD", "SGD", "KRW",
        "THB", "MYR", "AUD", "CAD"
    ]

    private static func displayString(_ localized: String?, fallback: String?) -> String {
        trimmedOptional(localized) ?? trimmedOptional(fallback) ?? ""
    }

    private static func amountText(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.000_001 {
            return String(Int(rounded))
        }
        var text = String(format: "%.2f", value)
        while text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text
    }

    private func parsedAmount(_ value: String) -> Double {
        let cleaned = value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned) ?? 0
    }

    private func trimmedRequired(_ value: String, fallback: String) -> String {
        trimmedOptional(value) ?? fallback
    }

    private func trimmedOptional(_ value: String) -> String? {
        Self.trimmedOptional(value)
    }

    private static func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#if canImport(PDFKit) && canImport(UIKit)
private struct HotelStayPDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor.clear
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(data: data)
    }
}
#elseif canImport(PDFKit) && canImport(AppKit)
private struct HotelStayPDFPreview: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor.clear
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(data: data)
    }
}
#endif

private extension View {
    @ViewBuilder
    func hotelDecimalKeyboard() -> some View {
        #if canImport(UIKit)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func hotelNumberKeyboard() -> some View {
        #if canImport(UIKit)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview("Hotel stays") {
    HotelStayListView(
        records: HotelStayPreviewData.records,
        transactions: HotelStayPreviewData.transactions
    )
}

private enum HotelStayPreviewData {
    static let stayID = UUID(uuidString: "00000000-0000-0000-0000-000000001820")!
    static let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000001821")!

    static let records = [
        HotelStayRecord(
            id: stayID,
            ledgerID: TodaySpendingSummary.defaultLedgerID,
            linkedTransactionID: transactionID,
            hotelName: "Demo Bay Hotel",
            hotelGroup: "Demo Hospitality",
            hotelBrand: "Demo Suites",
            city: "Tokyo",
            country: "Japan",
            checkInDate: "2026-06-20",
            checkOutDate: "2026-06-22",
            nights: 2,
            roomType: "King Bay View",
            confirmationNumber: "ABC123",
            currency: "JPY",
            roomCharge: 40000,
            taxAmount: 4000,
            serviceCharge: 3000,
            foodBeverageAmount: 2500,
            otherAmount: 500,
            totalAmount: 50000,
            paymentMethod: "Amex",
            sourceType: .manualPDF,
            sourceFileName: "demo-folio.pdf",
            confidence: 0.91,
            rawText: "Demo Bay Hotel\nConfirmation: ABC123\nTotal Amount: JPY 50000"
        )
    ]

    static let transactions = [
        Transaction(
            id: transactionID,
            merchant: "Demo Bay Hotel",
            amount: 50000,
            occurredAt: AppFormatters.parseFlexibleDate("2026-06-22 16:00") ?? .now,
            categoryLabel: TransactionCategory.hotel.rawValue,
            sourceLabel: ReceiptSource.manual.rawValue,
            note: "入住：2026-06-20；退房：2026-06-22",
            hotelStayRecordID: stayID
        )
    ]
}
