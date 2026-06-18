import AutoLedgerCore
import PhotosUI
import SwiftUI
import UIKit

struct InboxView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImportingPhoto = false
    @State private var isImportingClipboard = false
    @State private var showCamera = false
    @State private var capturedImageData: Data?
    @State private var isImportingCamera = false
    @State private var showMerchantSheet = false
    @State private var isQuickSetupExpanded = false

    private let ocrService = OCRService()

    private var hasShortcutEntries: Bool {
        let shortcutNote = localized("quick_ledger.note", fallback: "Saved by Shortcuts")
        return store.transactions.contains { $0.note == shortcutNote }
    }

    private var upcomingSubscriptions: [Subscription] {
        let sevenDaysLater = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        return store.subscriptions.filter { $0.status.isActive && $0.nextChargedAt <= sevenDaysLater && $0.nextChargedAt >= .now }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero

                    if !upcomingSubscriptions.isEmpty {
                        upcomingChargeCard
                    }

                    if hasShortcutEntries && !isQuickSetupExpanded {
                        quickSetupCollapsed
                    } else {
                        quickSetupCard
                    }

                    liveImportCard

                    VoiceLedgerQuickEntryView()

                    if let summary = store.lastImportSummary {
                        statusBanner(summary)
                    }

                    if !store.lastRecognizedText.isEmpty {
                        recognizedTextCard
                    }

                    if !store.recentImports.isEmpty {
                        Text("inbox.recent_imports")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        ForEach(store.recentImports.prefix(10)) { receipt in
                            importedCard(receipt)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("AutoLedger")
            .sheet(isPresented: $showMerchantSheet) {
                merchantSheet
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto else {
                    return
                }
                await importPickedPhoto(selectedPhoto)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("inbox.hero.title")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                MetricCard(
                    title: localized("inbox.hero.monthly_expense.title", fallback: "This Month"),
                    value: AppFormatters.currency(store.monthlySnapshot.totalExpense),
                    detail: String(format: localized("inbox.hero.monthly_expense.detail", fallback: "%d transactions"), store.monthlySnapshot.transactionCount),
                    accent: AppTheme.accent
                )
                .onTapGesture { selectedTab = 2 }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(String(format: localized("inbox.hero.monthly_expense.detail", fallback: "%d transactions"), store.monthlySnapshot.transactionCount) + "，" + AppFormatters.currency(store.monthlySnapshot.totalExpense))
                .accessibilityHint(Text("inbox.hero.monthly_expense.accessibility_hint"))

                MetricCard(
                    title: localized("inbox.hero.top_merchant.title", fallback: "Top Merchant"),
                    value: store.monthlySnapshot.topMerchant,
                    detail: String(format: localized("inbox.hero.top_merchant.detail", fallback: "%d merchants"), store.monthlySnapshot.topMerchants.count),
                    accent: AppTheme.accentSecondary
                )
                .onTapGesture { showMerchantSheet = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(String(format: localized("inbox.hero.top_merchant.accessibility_label_format", fallback: "Top merchant %@"), store.monthlySnapshot.topMerchant))
                .accessibilityHint(Text("inbox.hero.top_merchant.accessibility_hint"))
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppTheme.heroGradient)
        )
    }

    private var quickSetupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("inbox.quick_setup.title")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text("inbox.quick_setup.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accentSecondary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 12) {
                setupStep(
                    number: "1",
                    title: localized("inbox.quick_setup.step1.title", fallback: "Get the Shortcut"),
                    detail: localized("inbox.quick_setup.step1.detail", fallback: "Add the Quick Ledger shortcut to your iPhone.")
                )

                Link(destination: URL(string: "https://www.icloud.com/shortcuts/e64528fb5bc34afdab4d7c64242d537e")!) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("inbox.quick_setup.add_shortcut")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentSecondary)

                setupStep(
                    number: "2",
                    title: localized("inbox.quick_setup.step2.title", fallback: "Assign the Action Button"),
                    detail: localized("inbox.quick_setup.step2.detail", fallback: "Go to Settings -> Action Button -> Shortcut, then choose Quick Ledger.")
                )

                Button {
                    if let url = URL(string: "App-prefs:") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("inbox.quick_setup.open_settings")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent.opacity(0.85))

                setupStep(
                    number: "3",
                    title: localized("inbox.quick_setup.step3.title", fallback: "Press and hold to log"),
                    detail: localized("inbox.quick_setup.step3.detail", fallback: "Take a payment screenshot, then press and hold the Action Button to log it.")
                )
            }

            Text("inbox.quick_setup.device_hint")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)

            Text("inbox.quick_setup.clipboard_hint")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private var quickSetupCollapsed: some View {
        Button {
            if reduceMotion {
                isQuickSetupExpanded = true
            } else {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isQuickSetupExpanded = true
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("inbox.quick_setup.enabled")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    let shortcutNote = localized("quick_ledger.note", fallback: "Saved by Shortcuts")
                    let count = store.transactions.filter { $0.note == shortcutNote }.count
                    Text(String(format: localized("inbox.quick_setup.enabled.detail", fallback: "%d transactions logged with Shortcuts"), count))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .accessibilityHidden(true)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.card)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Upcoming Charge Card

    private var upcomingChargeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accentSecondary)
                    .accessibilityHidden(true)

                Text("inbox.upcoming_subscriptions.title")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Text("inbox.upcoming_subscriptions.range")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            ForEach(upcomingSubscriptions) { sub in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sub.merchant)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)

                        Text(sub.period.title)
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedInk)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(AppFormatters.currency(sub.amount))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        let days = Calendar.current.dateComponents([.day], from: .now, to: sub.nextChargedAt).day ?? 0
                        Text(daysText(days))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func setupStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(AppTheme.accent))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
    }

    private var liveImportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("inbox.import.title")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text("inbox.import.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Image(systemName: "doc.text.viewfinder")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
            }

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                preferredItemEncoding: .automatic
            ) {
                HStack {
                    if isImportingPhoto {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "photo.on.rectangle")
                    }

                    Text(isImportingPhoto ? String(localized: "inbox.import.processing") : String(localized: "inbox.import.photo"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    HStack {
                        if isImportingCamera {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "camera.fill")
                        }

                        Text(isImportingCamera ? String(localized: "inbox.import.processing") : String(localized: "inbox.import.camera"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }

            Button {
                Task { await importFromClipboard() }
            } label: {
                HStack {
                    if isImportingClipboard {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "doc.on.clipboard")
                    }

                    Text(isImportingClipboard ? String(localized: "inbox.import.processing") : String(localized: "inbox.import.clipboard"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentSecondary)

            Text("inbox.import.hint")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
        .sheet(isPresented: $showCamera) {
            CameraPicker(imageData: $capturedImageData)
        }
        .task(id: capturedImageData) {
            guard let data = capturedImageData else { return }
            capturedImageData = nil
            await importCapturedPhoto(data)
        }
    }

    private func importedCard(_ receipt: ImportedReceipt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(receipt.merchant)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Text(AppFormatters.currency(receipt.amount))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }

            HStack(spacing: 10) {
                Label(receipt.source.title, systemImage: "camera.metering.center.weighted")
                Label(receipt.suggestedCategory.title, systemImage: receipt.suggestedCategory.iconName)
                Text(AppFormatters.shortDateTime(receipt.occurredAt))
            }
            .font(.caption)
            .foregroundStyle(AppTheme.mutedInk)

            Text(receipt.summary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func statusBanner(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private var recognizedTextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("inbox.recent_ocr")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text(store.lastRecognizedText)
                .font(.footnote.monospaced())
                .foregroundStyle(AppTheme.ink.opacity(0.82))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func importPickedPhoto(_ item: PhotosPickerItem) async {
        isImportingPhoto = true
        store.prepareForLiveImport()
        defer {
            isImportingPhoto = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw OCRServiceError.loadFailed
            }
            let text = try ocrService.recognizeText(from: data)
            store.importRecognizedText(text, imageSource: .photoLibrary)
        } catch {
            store.setImportError(error.localizedDescription, imageSource: .photoLibrary)
        }
    }

    private func importCapturedPhoto(_ data: Data) async {
        isImportingCamera = true
        store.prepareForLiveImport()
        defer { isImportingCamera = false }

        do {
            let text = try ocrService.recognizeText(from: data)
            store.importRecognizedText(text, imageSource: .camera)
        } catch {
            store.setImportError(error.localizedDescription, imageSource: .camera)
        }
    }

    private var merchantRankings: [(merchant: String, total: Double)] {
        var totals: [String: Double] = [:]
        for t in store.transactions {
            totals[t.merchant, default: 0] += t.amount
        }
        return totals.map { (merchant: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    @ViewBuilder
    private var merchantSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(merchantRankings.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.mutedInk)
                            .frame(width: 24)

                        Text(item.merchant)
                            .font(.body)
                            .foregroundStyle(AppTheme.ink)

                        Spacer()

                        Text(AppFormatters.currency(item.total))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .listRowBackground(AppTheme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("inbox.merchant_rankings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.close") { showMerchantSheet = false }
                }
            }
        }
    }

    private func importFromClipboard() async {
        isImportingClipboard = true
        store.prepareForLiveImport()
        defer { isImportingClipboard = false }

        guard let image = UIPasteboard.general.image,
              let data = image.pngData() else {
            store.setImportError(localized("inbox.clipboard.empty", fallback: "No image found in clipboard."), imageSource: .clipboard)
            return
        }

        do {
            let text = try ocrService.recognizeText(from: data)
            store.importRecognizedText(text, imageSource: .clipboard)
        } catch {
            store.setImportError(error.localizedDescription, imageSource: .clipboard)
        }
    }
}

private extension InboxView {
    func localized(_ key: String, fallback: String) -> String {
        let value = NSLocalizedString(key, comment: "")
        return value == key ? fallback : value
    }

    func daysText(_ days: Int) -> String {
        if days <= 0 { return String(localized: "common.today") }
        if days == 1 { return String(localized: "common.tomorrow") }
        return String(format: localized("common.days_later_format", fallback: "%d days later"), days)
    }
}

#Preview {
    InboxView(selectedTab: .constant(0))
        .environmentObject(LedgerStore())
}
