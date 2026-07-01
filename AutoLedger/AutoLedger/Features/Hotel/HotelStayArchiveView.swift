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
    let onImportCloudInbox: (() -> Void)?
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
        onImportCloudInbox: (() -> Void)? = nil,
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
        self.onImportCloudInbox = onImportCloudInbox
        self.onReviewDraft = onReviewDraft
        self.onUpdateRecord = onUpdateRecord
        self.onDeleteRecord = onDeleteRecord
        self._selectedRecordID = selectedRecordID
    }

    private var hasImportActions: Bool {
        onImportPDF != nil || onImportEmail != nil || onImportCloudInbox != nil
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
            if onImportCloudInbox != nil {
                Button {
                    onImportCloudInbox?()
                } label: {
                    Label("hotel_stay.import.cloud_inbox", systemImage: "icloud.and.arrow.down")
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
                    .padding(.vertical, 8)
            }
        }
        .autoLedgerSelectableRowBackground(false)
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
            .autoLedgerSelectableRowBackground(false)
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
                .autoLedgerSelectableRowBackground(false)
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

    private var hotelNameLineLimit: Int {
        Self.cjkIdeographCount(in: row.hotelName) > 8 ? 2 : 1
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bed.double.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(row.hotelName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(hotelNameLineLimit)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    Spacer(minLength: 4)

                    Text(row.totalAmountText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                        .layoutPriority(4)
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
        .padding(.vertical, 8)
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

    private static func cjkIdeographCount(in value: String) -> Int {
        value.unicodeScalars.filter { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value)) ||
            (0x3400...0x4DBF).contains(Int(scalar.value)) ||
            (0xF900...0xFAFF).contains(Int(scalar.value))
        }.count
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 34, height: 34)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                        .font(.subheadline.weight(.bold))
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
        .padding(.vertical, 8)
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
            if onUpdateRecord != nil || onDeleteRecord != nil {
                ToolbarItemGroup(placement: .primaryAction) {
                    if onUpdateRecord != nil {
                        Button {
                            saveEdits()
                        } label: {
                            Label("common.save", systemImage: "checkmark")
                        }
                        .disabled(!form.isValid)
                    }

                    if onDeleteRecord != nil {
                        deleteActionMenu
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
            .autoLedgerSelectableRowBackground(false)
        }
    }

    private var identityEditorSection: some View {
        Section("hotel_stay.detail.identity") {
            editableTextField("hotel_stay.review.hotel_name", text: $form.hotelName)
            editableTextField("hotel_stay.review.brand", text: $form.hotelBrand)
            editableTextField("hotel_stay.review.group", text: $form.hotelGroup)
            editableOptionField("hotel_stay.review.country", text: $form.country, options: form.countryOptions) { selectedCountry in
                form.applyCountrySelection(selectedCountry)
            }
            editableOptionField("hotel_stay.review.city", text: $form.city, options: form.cityOptions) { selectedCity in
                form.applyCitySelection(selectedCity)
            }
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
        options: [String],
        onSelect: ((String) -> Void)? = nil
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
                            if let onSelect {
                                onSelect(option)
                            } else {
                                text.wrappedValue = option
                            }
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

    private var deleteActionMenu: some View {
        Menu {
            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Label("hotel_stay.delete.button", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Text("common.more_actions"))
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
        currency = Self.currencyString(record.localizedData?.currency, fallback: record.currency, context: record.rawText)
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

        let localizedLocation = HotelStayLocationCatalog.localizedLocation(city: city, country: country)
        city = localizedLocation.city
        country = localizedLocation.country
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
        let selectedCountry = HotelStayLocationCatalog.country(matching: country)
        return Self.uniqueOptions([city] + HotelStayLocationCatalog.cityOptions(for: selectedCountry))
    }

    var countryOptions: [String] {
        Self.uniqueOptions([country] + HotelStayLocationCatalog.countryOptions())
    }

    var currencyOptions: [String] {
        Self.uniqueOptions([currency] + Self.commonCurrencyOptions)
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
        updated.currency = normalizedCurrency(fallback: record.currency)
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
            currency: normalizedCurrency(fallback: record.currency),
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

    private static let commonCurrencyOptions = [
        "CNY", "USD", "JPY", "EUR", "GBP", "HKD", "MOP", "TWD", "SGD", "KRW",
        "THB", "MYR", "AUD", "CAD"
    ]

    private static func displayString(_ localized: String?, fallback: String?) -> String {
        trimmedOptional(localized) ?? trimmedOptional(fallback) ?? ""
    }

    private static func currencyString(_ localized: String?, fallback: String?, context: String) -> String {
        let value = displayString(localized, fallback: fallback)
        return HotelCurrencyCodeNormalizer.normalizedCode(value, context: context) ?? value
    }

    private func normalizedCurrency(fallback: String) -> String {
        HotelCurrencyCodeNormalizer.normalizedCode(currency, context: [country, city].joined(separator: " "))
            ?? trimmedRequired(currency.uppercased(), fallback: fallback)
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

private enum HotelStayLocationCatalog {
    struct Country: Sendable {
        let code: String
        let aliases: [String]
        let cities: [City]

        nonisolated var localizedName: String {
            Locale.current.localizedString(forRegionCode: code) ?? aliases.first ?? code
        }

        nonisolated func matches(_ value: String) -> Bool {
            let normalizedValue = HotelStayLocationCatalog.normalized(value)
            guard !normalizedValue.isEmpty else { return false }
            return ([code, localizedName] + aliases)
                .map(HotelStayLocationCatalog.normalized)
                .contains(normalizedValue)
        }

        nonisolated func localizedCityName(matching value: String) -> String? {
            cities.first { $0.matches(value) }?.localizedName
        }
    }

    struct City: Sendable {
        let english: String
        let zhHans: String
        let zhHant: String
        let ja: String
        let aliases: [String]

        nonisolated var localizedName: String {
            switch HotelStayLocationCatalog.languageKey {
            case "zh-Hant":
                return zhHant
            case "zh-Hans":
                return zhHans
            case "ja":
                return ja
            default:
                return english
            }
        }

        nonisolated func matches(_ value: String) -> Bool {
            let normalizedValue = HotelStayLocationCatalog.normalized(value)
            guard !normalizedValue.isEmpty else { return false }
            return ([english, zhHans, zhHant, ja, localizedName] + aliases)
                .map(HotelStayLocationCatalog.normalized)
                .contains(normalizedValue)
        }
    }

    nonisolated static func localizedLocation(city: String, country: String) -> (city: String, country: String) {
        let matchedCountry = self.country(matching: country) ?? self.country(containingCity: city)
        let localizedCountry = matchedCountry?.localizedName ?? country.trimmingCharacters(in: .whitespacesAndNewlines)
        let localizedCity = localizedCityName(matching: city, country: matchedCountry)
            ?? localizedCityName(matching: city)
            ?? city.trimmingCharacters(in: .whitespacesAndNewlines)
        return (localizedCity, localizedCountry)
    }

    nonisolated static func countryOptions() -> [String] {
        countries.map(\.localizedName)
    }

    nonisolated static func cityOptions(for country: Country?) -> [String] {
        if let country {
            return country.cities.map(\.localizedName)
        }
        return fallbackCities.map(\.localizedName)
    }

    nonisolated static func country(matching value: String) -> Country? {
        countries.first { $0.matches(value) }
    }

    nonisolated static func localizedCityName(matching value: String, country: Country? = nil) -> String? {
        if let country, let city = country.localizedCityName(matching: value) {
            return city
        }
        return countries.lazy.compactMap { $0.localizedCityName(matching: value) }.first
    }

    nonisolated private static func country(containingCity value: String) -> Country? {
        countries.first { country in
            country.cities.contains { $0.matches(value) }
        }
    }

    nonisolated private static var languageKey: String {
        let identifier = Locale.current.identifier.lowercased()
        if identifier.hasPrefix("ja") {
            return "ja"
        }
        if identifier.contains("hant") || identifier.contains("_tw") || identifier.contains("_hk") || identifier.contains("_mo") {
            return "zh-Hant"
        }
        if identifier.hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }

    nonisolated private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "·", with: "")
            .lowercased()
    }

    nonisolated private static func city(
        _ english: String,
        zhHans: String,
        zhHant: String? = nil,
        ja: String? = nil,
        aliases: [String] = []
    ) -> City {
        City(
            english: english,
            zhHans: zhHans,
            zhHant: zhHant ?? zhHans,
            ja: ja ?? english,
            aliases: aliases
        )
    }

    nonisolated private static func country(_ code: String, aliases: [String], cities: [City]) -> Country {
        Country(code: code, aliases: aliases, cities: cities)
    }

    nonisolated private static let countries: [Country] = [
        country("CN", aliases: ["中国", "中國", "China", "Mainland China", "PRC"], cities: [
            city("Beijing", zhHans: "北京", ja: "北京"),
            city("Shanghai", zhHans: "上海", ja: "上海"),
            city("Guangzhou", zhHans: "广州", zhHant: "廣州", ja: "広州"),
            city("Shenzhen", zhHans: "深圳", ja: "深セン"),
            city("Chongqing", zhHans: "重庆", zhHant: "重慶", ja: "重慶"),
            city("Chengdu", zhHans: "成都", ja: "成都"),
            city("Hangzhou", zhHans: "杭州", ja: "杭州"),
            city("Nanjing", zhHans: "南京", ja: "南京"),
            city("Tianjin", zhHans: "天津", ja: "天津"),
            city("Xi'an", zhHans: "西安", ja: "西安", aliases: ["Xian"]),
            city("Wuhan", zhHans: "武汉", zhHant: "武漢", ja: "武漢"),
            city("Suzhou", zhHans: "苏州", zhHant: "蘇州", ja: "蘇州"),
            city("Qingdao", zhHans: "青岛", zhHant: "青島", ja: "青島"),
            city("Xiamen", zhHans: "厦门", zhHant: "廈門", ja: "厦門"),
            city("Sanya", zhHans: "三亚", zhHant: "三亞", ja: "三亜")
        ]),
        country("HK", aliases: ["香港", "中国香港", "中國香港", "Hong Kong"], cities: [
            city("Hong Kong", zhHans: "香港", ja: "香港")
        ]),
        country("MO", aliases: ["澳门", "澳門", "中国澳门", "中國澳門", "Macau", "Macao"], cities: [
            city("Macau", zhHans: "澳门", zhHant: "澳門", ja: "マカオ", aliases: ["Macao"])
        ]),
        country("TW", aliases: ["台湾", "台灣", "中国台湾", "中國台灣", "Taiwan"], cities: [
            city("Taipei", zhHans: "台北", ja: "台北"),
            city("Taichung", zhHans: "台中", ja: "台中"),
            city("Kaohsiung", zhHans: "高雄", ja: "高雄"),
            city("Tainan", zhHans: "台南", ja: "台南")
        ]),
        country("JP", aliases: ["日本", "Japan"], cities: [
            city("Tokyo", zhHans: "东京", zhHant: "東京", ja: "東京"),
            city("Osaka", zhHans: "大阪", ja: "大阪"),
            city("Kyoto", zhHans: "京都", ja: "京都"),
            city("Yokohama", zhHans: "横滨", zhHant: "橫濱", ja: "横浜"),
            city("Nagoya", zhHans: "名古屋", ja: "名古屋"),
            city("Fukuoka", zhHans: "福冈", zhHant: "福岡", ja: "福岡"),
            city("Sapporo", zhHans: "札幌", ja: "札幌"),
            city("Naha", zhHans: "那霸", zhHant: "那霸", ja: "那覇")
        ]),
        country("KR", aliases: ["韩国", "韓國", "South Korea", "Korea", "대한민국"], cities: [
            city("Seoul", zhHans: "首尔", zhHant: "首爾", ja: "ソウル"),
            city("Busan", zhHans: "釜山", ja: "釜山"),
            city("Incheon", zhHans: "仁川", ja: "仁川"),
            city("Jeju", zhHans: "济州", zhHant: "濟州", ja: "済州"),
            city("Daegu", zhHans: "大邱", ja: "大邱")
        ]),
        country("SG", aliases: ["新加坡", "Singapore"], cities: [
            city("Singapore", zhHans: "新加坡", ja: "シンガポール")
        ]),
        country("TH", aliases: ["泰国", "泰國", "Thailand"], cities: [
            city("Bangkok", zhHans: "曼谷", ja: "バンコク"),
            city("Phuket", zhHans: "普吉", ja: "プーケット"),
            city("Chiang Mai", zhHans: "清迈", zhHant: "清邁", ja: "チェンマイ"),
            city("Pattaya", zhHans: "芭提雅", ja: "パタヤ")
        ]),
        country("MY", aliases: ["马来西亚", "馬來西亞", "Malaysia"], cities: [
            city("Kuala Lumpur", zhHans: "吉隆坡", ja: "クアラルンプール"),
            city("Penang", zhHans: "槟城", zhHant: "檳城", ja: "ペナン"),
            city("Johor Bahru", zhHans: "新山", ja: "ジョホールバル"),
            city("Kota Kinabalu", zhHans: "亚庇", zhHant: "亞庇", ja: "コタキナバル")
        ]),
        country("ID", aliases: ["印度尼西亚", "印尼", "印度尼西亞", "Indonesia"], cities: [
            city("Jakarta", zhHans: "雅加达", zhHant: "雅加達", ja: "ジャカルタ"),
            city("Bali", zhHans: "巴厘岛", zhHant: "峇里島", ja: "バリ"),
            city("Surabaya", zhHans: "泗水", ja: "スラバヤ")
        ]),
        country("VN", aliases: ["越南", "Vietnam"], cities: [
            city("Ho Chi Minh City", zhHans: "胡志明市", ja: "ホーチミン"),
            city("Hanoi", zhHans: "河内", zhHant: "河內", ja: "ハノイ"),
            city("Da Nang", zhHans: "岘港", zhHant: "峴港", ja: "ダナン")
        ]),
        country("PH", aliases: ["菲律宾", "菲律賓", "Philippines"], cities: [
            city("Manila", zhHans: "马尼拉", zhHant: "馬尼拉", ja: "マニラ"),
            city("Cebu", zhHans: "宿务", zhHant: "宿霧", ja: "セブ")
        ]),
        country("US", aliases: ["美国", "美國", "United States", "United States of America", "USA", "US"], cities: [
            city("New York", zhHans: "纽约", zhHant: "紐約", ja: "ニューヨーク", aliases: ["NYC"]),
            city("Los Angeles", zhHans: "洛杉矶", zhHant: "洛杉磯", ja: "ロサンゼルス"),
            city("San Francisco", zhHans: "旧金山", zhHant: "舊金山", ja: "サンフランシスコ"),
            city("Las Vegas", zhHans: "拉斯维加斯", zhHant: "拉斯維加斯", ja: "ラスベガス"),
            city("Seattle", zhHans: "西雅图", zhHant: "西雅圖", ja: "シアトル"),
            city("Chicago", zhHans: "芝加哥", ja: "シカゴ"),
            city("Boston", zhHans: "波士顿", zhHant: "波士頓", ja: "ボストン"),
            city("Washington", zhHans: "华盛顿", zhHant: "華盛頓", ja: "ワシントン", aliases: ["Washington DC", "Washington, DC"]),
            city("Miami", zhHans: "迈阿密", zhHant: "邁阿密", ja: "マイアミ"),
            city("Orlando", zhHans: "奥兰多", zhHant: "奧蘭多", ja: "オーランド")
        ]),
        country("GB", aliases: ["英国", "英國", "United Kingdom", "UK", "Great Britain"], cities: [
            city("London", zhHans: "伦敦", zhHant: "倫敦", ja: "ロンドン"),
            city("Manchester", zhHans: "曼彻斯特", zhHant: "曼徹斯特", ja: "マンチェスター"),
            city("Edinburgh", zhHans: "爱丁堡", zhHant: "愛丁堡", ja: "エディンバラ"),
            city("Birmingham", zhHans: "伯明翰", ja: "バーミンガム")
        ]),
        country("FR", aliases: ["法国", "法國", "France"], cities: [
            city("Paris", zhHans: "巴黎", ja: "パリ"),
            city("Nice", zhHans: "尼斯", ja: "ニース"),
            city("Lyon", zhHans: "里昂", ja: "リヨン"),
            city("Marseille", zhHans: "马赛", zhHant: "馬賽", ja: "マルセイユ")
        ]),
        country("DE", aliases: ["德国", "德國", "Germany"], cities: [
            city("Berlin", zhHans: "柏林", ja: "ベルリン"),
            city("Munich", zhHans: "慕尼黑", ja: "ミュンヘン"),
            city("Frankfurt", zhHans: "法兰克福", zhHant: "法蘭克福", ja: "フランクフルト"),
            city("Hamburg", zhHans: "汉堡", zhHant: "漢堡", ja: "ハンブルク")
        ]),
        country("IT", aliases: ["意大利", "義大利", "Italy"], cities: [
            city("Rome", zhHans: "罗马", zhHant: "羅馬", ja: "ローマ"),
            city("Milan", zhHans: "米兰", zhHant: "米蘭", ja: "ミラノ"),
            city("Venice", zhHans: "威尼斯", ja: "ベネチア"),
            city("Florence", zhHans: "佛罗伦萨", zhHant: "佛羅倫斯", ja: "フィレンツェ")
        ]),
        country("ES", aliases: ["西班牙", "Spain"], cities: [
            city("Madrid", zhHans: "马德里", zhHant: "馬德里", ja: "マドリード"),
            city("Barcelona", zhHans: "巴塞罗那", zhHant: "巴塞隆納", ja: "バルセロナ"),
            city("Seville", zhHans: "塞维利亚", zhHant: "塞維利亞", ja: "セビリア"),
            city("Valencia", zhHans: "瓦伦西亚", zhHant: "瓦倫西亞", ja: "バレンシア")
        ]),
        country("NL", aliases: ["荷兰", "荷蘭", "Netherlands"], cities: [
            city("Amsterdam", zhHans: "阿姆斯特丹", ja: "アムステルダム"),
            city("Rotterdam", zhHans: "鹿特丹", ja: "ロッテルダム")
        ]),
        country("CH", aliases: ["瑞士", "Switzerland"], cities: [
            city("Zurich", zhHans: "苏黎世", zhHant: "蘇黎世", ja: "チューリッヒ"),
            city("Geneva", zhHans: "日内瓦", zhHant: "日內瓦", ja: "ジュネーブ"),
            city("Lucerne", zhHans: "卢塞恩", zhHant: "琉森", ja: "ルツェルン")
        ]),
        country("AT", aliases: ["奥地利", "奧地利", "Austria"], cities: [
            city("Vienna", zhHans: "维也纳", zhHant: "維也納", ja: "ウィーン"),
            city("Salzburg", zhHans: "萨尔茨堡", zhHant: "薩爾斯堡", ja: "ザルツブルク")
        ]),
        country("AU", aliases: ["澳大利亚", "澳洲", "澳大利亞", "Australia"], cities: [
            city("Sydney", zhHans: "悉尼", zhHant: "雪梨", ja: "シドニー"),
            city("Melbourne", zhHans: "墨尔本", zhHant: "墨爾本", ja: "メルボルン"),
            city("Brisbane", zhHans: "布里斯班", ja: "ブリスベン"),
            city("Perth", zhHans: "珀斯", ja: "パース")
        ]),
        country("CA", aliases: ["加拿大", "Canada"], cities: [
            city("Toronto", zhHans: "多伦多", zhHant: "多倫多", ja: "トロント"),
            city("Vancouver", zhHans: "温哥华", zhHant: "溫哥華", ja: "バンクーバー"),
            city("Montreal", zhHans: "蒙特利尔", zhHant: "蒙特婁", ja: "モントリオール"),
            city("Calgary", zhHans: "卡尔加里", zhHant: "卡加利", ja: "カルガリー")
        ]),
        country("AE", aliases: ["阿联酋", "阿聯酋", "United Arab Emirates", "UAE"], cities: [
            city("Dubai", zhHans: "迪拜", ja: "ドバイ"),
            city("Abu Dhabi", zhHans: "阿布扎比", zhHant: "阿布達比", ja: "アブダビ")
        ])
    ]

    nonisolated private static var fallbackCities: [City] {
        countries.flatMap(\.cities).prefix(32).map { $0 }
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
