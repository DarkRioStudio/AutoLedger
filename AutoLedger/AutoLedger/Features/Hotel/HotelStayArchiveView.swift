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
    let records: [HotelStayRecord]
    let transactions: [Transaction]
    let ledgerID: String?
    let isImporting: Bool
    let statusMessage: String?
    let onImportPDF: (() -> Void)?
    let onImportEmail: (() -> Void)?
    let onDeleteRecord: ((HotelStayRecord) -> Bool)?

    private let presenter = HotelStayArchivePresenter()

    init(
        records: [HotelStayRecord],
        transactions: [Transaction] = [],
        ledgerID: String? = nil,
        isImporting: Bool = false,
        statusMessage: String? = nil,
        onImportPDF: (() -> Void)? = nil,
        onImportEmail: (() -> Void)? = nil,
        onDeleteRecord: ((HotelStayRecord) -> Bool)? = nil
    ) {
        self.records = records
        self.transactions = transactions
        self.ledgerID = ledgerID
        self.isImporting = isImporting
        self.statusMessage = statusMessage
        self.onImportPDF = onImportPDF
        self.onImportEmail = onImportEmail
        self.onDeleteRecord = onDeleteRecord
    }

    private var hasImportActions: Bool {
        onImportPDF != nil || onImportEmail != nil
    }

    private var snapshot: HotelStayListSnapshot {
        presenter.makeListSnapshot(records: records, ledgerID: ledgerID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if snapshot.rows.isEmpty {
                    VStack(spacing: 16) {
                        if hasImportActions {
                            importButtons
                        }
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
                    .background(AppTheme.screenGradient.ignoresSafeArea())
                } else {
                    List {
                        if hasImportActions || statusMessage != nil {
                            importSection
                        }
                        summarySection
                        staySection
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.screenGradient.ignoresSafeArea())
                }
            }
            .navigationTitle("hotel_stay.list.title")
            .toolbar {
                if hasImportActions {
                    ToolbarItem(placement: .primaryAction) {
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
                }
            }
        }
    }

    private var importSection: some View {
        Section {
            if hasImportActions {
                importButtons
            }
            if let statusMessage {
                statusRow(statusMessage)
            }
        }
        .listRowBackground(AppTheme.card)
    }

    private var importButtons: some View {
        VStack(spacing: 10) {
            if onImportPDF != nil {
                Button {
                    onImportPDF?()
                } label: {
                    Label(
                        isImporting ? "hotel_stay.import.processing" : "hotel_stay.import.pdf",
                        systemImage: isImporting ? "hourglass" : "doc.badge.plus"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting)
            }

            if onImportEmail != nil {
                Button {
                    onImportEmail?()
                } label: {
                    Label(
                        isImporting ? "hotel_stay.import.processing" : "hotel_stay.import.email",
                        systemImage: isImporting ? "hourglass" : "envelope.badge"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(isImporting)
            }
        }
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
                    value: snapshot.averageNightlyRate.map { String(format: "%.0f", $0) } ?? "-"
                )
            }
            .padding(.vertical, 4)
            .listRowBackground(AppTheme.card)
        }
    }

    private var staySection: some View {
        Section {
            ForEach(snapshot.rows) { row in
                if let record = records.first(where: { $0.id == row.id }) {
                    NavigationLink {
                        HotelStayDetailView(
                            record: record,
                            transactions: transactions,
                            ledgerID: ledgerID,
                            onDeleteRecord: onDeleteRecord
                        )
                    } label: {
                        HotelStayRowView(row: row)
                    }
                    .listRowBackground(AppTheme.card)
                }
            }
        } header: {
            Text("hotel_stay.list.section.records")
        } footer: {
            Text(String(format: String(localized: "hotel_stay.list.footer_format"), snapshot.rows.count))
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
}

private struct HotelStayRowView: View {
    let row: HotelStayListRow

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "bed.double.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.hotelName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)

                    Spacer()

                    Text(row.totalAmountText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if !row.locationText.isEmpty {
                        Text(row.locationText)
                    }
                    if !row.brandGroupText.isEmpty {
                        Text(row.brandGroupText)
                    }
                    HStack(spacing: 8) {
                        if !row.dateRangeText.isEmpty {
                            Text(row.dateRangeText)
                        }
                        if !row.nightsText.isEmpty {
                            Text(String(format: String(localized: "hotel_stay.list.nights_format"), row.nightsText))
                        }
                    }
                    HStack(spacing: 8) {
                        Label(sourceTitleKey(for: row.sourceType), systemImage: "doc.text")
                        Label(statusTitleKey(for: row.linkStatus), systemImage: statusIconName(for: row.linkStatus))
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

struct HotelStayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showsDeleteConfirmation = false

    let record: HotelStayRecord
    let transactions: [Transaction]
    let ledgerID: String?
    let onDeleteRecord: ((HotelStayRecord) -> Bool)?

    private let presenter = HotelStayArchivePresenter()

    init(
        record: HotelStayRecord,
        transactions: [Transaction] = [],
        ledgerID: String? = nil,
        onDeleteRecord: ((HotelStayRecord) -> Bool)? = nil
    ) {
        self.record = record
        self.transactions = transactions
        self.ledgerID = ledgerID
        self.onDeleteRecord = onDeleteRecord
    }

    private var snapshot: HotelStayDetailSnapshot {
        presenter.makeDetailSnapshot(record: record, transactions: transactions, ledgerID: ledgerID)
    }

    var body: some View {
        List {
            detailHeader
            fieldSection(titleKey: "hotel_stay.detail.identity", fields: snapshot.identityFields)
            fieldSection(titleKey: "hotel_stay.detail.stay", fields: snapshot.stayFields)
            fieldSection(titleKey: "hotel_stay.detail.charges", fields: snapshot.chargeFields)
            linkedTransactionSection
            fieldSection(titleKey: "hotel_stay.detail.source", fields: snapshot.sourceFields)
            sourcePDFSection
            rawTextSection
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("hotel_stay.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onDeleteRecord != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label("hotel_stay.delete.button", systemImage: "trash")
                    }
                }
            }
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
                Text(record.hotelName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                HStack(spacing: 8) {
                    if !snapshot.row.locationText.isEmpty {
                        Label(snapshot.row.locationText, systemImage: "mappin.and.ellipse")
                    }
                    if !snapshot.row.nightsText.isEmpty {
                        Label(
                            String(format: String(localized: "hotel_stay.list.nights_format"), snapshot.row.nightsText),
                            systemImage: "moon"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)

                Text(snapshot.row.totalAmountText)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.vertical, 6)
            .listRowBackground(AppTheme.card)
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

    private var linkedTransactionSection: some View {
        Section("hotel_stay.detail.linked_transaction") {
            if let transaction = snapshot.linkedTransaction {
                LabeledContent("hotel_stay.detail.transaction_merchant", value: transaction.merchant)
                LabeledContent("hotel_stay.detail.transaction_amount", value: AppFormatters.currency(transaction.amount))
                LabeledContent("hotel_stay.detail.transaction_date", value: AppFormatters.shortDateTime(transaction.occurredAt))
                LabeledContent("hotel_stay.detail.transaction_category", value: transaction.categoryTitle)
                if !transaction.note.isEmpty {
                    LabeledContent("hotel_stay.detail.transaction_note", value: transaction.note)
                }
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
                Text(snapshot.rawText.isEmpty ? String(localized: "hotel_stay.detail.raw_text.empty") : snapshot.rawText)
                    .font(.footnote.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 120)
        }
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
            occurredAt: AppFormatters.parseFlexibleDate("2026-06-22") ?? .now,
            categoryLabel: "酒店住宿",
            sourceLabel: ReceiptSource.manual.rawValue,
            note: "入住：2026-06-20；退房：2026-06-22",
            hotelStayRecordID: stayID
        )
    ]
}
