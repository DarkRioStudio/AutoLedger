import SwiftUI

struct ShareCardPreviewSheet: View {
    enum Mode: Identifiable {
        case monthly(MonthlySummaryShareCardData)
        case hotel(HotelStayShareCardData)

        var id: UUID {
            switch self {
            case .monthly(let data):
                return data.id
            case .hotel(let data):
                return data.id
            }
        }

        var titleKey: LocalizedStringKey {
            switch self {
            case .monthly:
                return "share_card.monthly.preview_title"
            case .hotel:
                return "share_card.hotel.preview_title"
            }
        }

        var toggleKey: LocalizedStringKey {
            switch self {
            case .monthly:
                return "share_card.monthly.show_amount"
            case .hotel:
                return "share_card.hotel.show_price"
            }
        }

        var defaultFileName: String {
            switch self {
            case .monthly(let data):
                return "AutoLedger-\(data.monthLabel)-Monthly-Summary"
            case .hotel(let data):
                return "AutoLedger-\(data.hotelName)-Stay-Card"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var showsSensitiveAmount = false
    @State private var reviewText: String
    @State private var isExporting = false
    @State private var exportErrorMessage: String?
    @State private var sharePayload: ShareCardSharePayload?

    let mode: Mode

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .monthly:
            _reviewText = State(initialValue: "")
        case .hotel(let data):
            _reviewText = State(initialValue: data.reviewText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    cardPreview

                    Toggle(isOn: $showsSensitiveAmount) {
                        Text(mode.toggleKey)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    .tint(AppTheme.accent)
                    .padding(16)
                    .autoLedgerCardSurface(cornerRadius: 18)

                    if case .hotel = mode {
                        reviewEditor
                    }

                    if let exportErrorMessage {
                        Label(exportErrorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(20)
            }
            .autoLedgerScreenChrome()
            .navigationTitle(mode.titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        exportAndShare()
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            Label("share_card.share_action", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .sheet(item: $sharePayload) { payload in
                ActivityShareSheet(activityItems: [payload.url])
            }
        }
    }

    private var cardPreview: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 1080
            renderedCard
                .frame(width: 1080, height: 1350)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.width * 1.25, alignment: .topLeading)
                .clipped()
        }
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: AppTheme.softShadow.opacity(0.9), radius: 20, x: 0, y: 12)
            .accessibilityLabel(Text("share_card.preview.accessibility_label"))
    }

    @ViewBuilder
    private var renderedCard: some View {
        switch mode {
        case .monthly(let data):
            MonthlySummaryShareCardView(data: data, showsAmount: showsSensitiveAmount)
        case .hotel(let data):
            HotelStayShareCardView(
                data: data.replacingReviewText(sanitizedReviewText),
                showsPrice: showsSensitiveAmount
            )
        }
    }

    private var reviewEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("share_card.hotel.review_editor")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            TextField("share_card.hotel.review_placeholder", text: $reviewText, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.plain)
                .padding(12)
                .background(AppTheme.canvas.opacity(0.68))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .autoLedgerCardSurface(cornerRadius: 18)
    }

    private var sanitizedReviewText: String {
        let trimmed = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return String(localized: "share_card.hotel.default_review")
        }
        return trimmed
    }

    private func exportAndShare() {
        isExporting = true
        exportErrorMessage = nil
        do {
            let url = try ShareCardExportService.exportPNG(fileName: mode.defaultFileName) {
                renderedCard
            }
            sharePayload = ShareCardSharePayload(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
        isExporting = false
    }
}

private struct ShareCardSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}
