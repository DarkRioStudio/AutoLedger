import AutoLedgerCore
import PhotosUI
import SwiftUI
import UIKit

struct InboxView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImportingPhoto = false
    @State private var isImportingClipboard = false
    @State private var showCamera = false
    @State private var capturedImageData: Data?
    @State private var isImportingCamera = false
    @State private var showMerchantSheet = false
    @State private var isQuickSetupExpanded = false
    @State private var isPresentingManualEntry = false
    @State private var isPresentingVoiceEntry = false

    private let ocrService = OCRService()
    private var hasShortcutEntries: Bool {
        let shortcutNote = localized("quick_ledger.note", fallback: "Saved by Shortcuts")
        return store.visibleTransactions.contains { $0.note == shortcutNote }
    }

    private var upcomingSubscriptions: [Subscription] {
        store.upcomingSubscriptionsForCurrentLedger()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AutoLedgerPageTitle("tab.inbox")

                    captureCommandCenter

                    quickImportButtonRow

                    if !upcomingSubscriptions.isEmpty {
                        upcomingChargeCard
                    }

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
                .autoLedgerReadableContent(maxWidth: 760, alignment: .center)
            }
            .autoLedgerScreenChrome()
            .autoLedgerSolidNavigationBarChrome()
            .autoLedgerContentTitleNavigation("tab.inbox")
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
            .sheet(isPresented: $showMerchantSheet) {
                merchantSheet
            }
            .sheet(isPresented: $isPresentingManualEntry) {
                manualEntrySheet
            }
            .sheet(isPresented: $isPresentingVoiceEntry) {
                VoiceLedgerConfirmView()
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(imageData: $capturedImageData)
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto else {
                    return
                }
                await importPickedPhoto(selectedPhoto)
            }
            .task(id: capturedImageData) {
                guard let data = capturedImageData else { return }
                capturedImageData = nil
                await importCapturedPhoto(data)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    quickEntryActionMenu
                }
            }
        }
    }

    private var captureCommandCenter: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        }

                    Image(systemName: hasShortcutEntries ? "checkmark.seal.fill" : "bolt.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.white)
                }
                .frame(width: 54, height: 54)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(hasShortcutEntries ? "inbox.quick_setup.enabled" : "inbox.quick_setup.title"))
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(captureHeroSubtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                Button {
                    toggleQuickSetupExpansion()
                } label: {
                    Image(systemName: isQuickSetupExpanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.16))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(LocalizedStringKey(isQuickSetupExpanded ? "common.collapse" : "common.more_actions")))
            }

            captureFlowRow

            if isQuickSetupExpanded {
                expandedQuickSetupActions
            } else {
                captureHeroMetrics
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppTheme.heroGradient)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.white.opacity(0.02),
                                Color.black.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 7) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 108, height: 6)
                    }
                }
                .rotationEffect(.degrees(-12))
                .offset(x: 34, y: 10)
                .accessibilityHidden(true)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: AppTheme.softShadow.opacity(1.3), radius: 18, x: 0, y: 12)
    }

    private var captureHeroSubtitle: String {
        if hasShortcutEntries {
            let shortcutNote = localized("quick_ledger.note", fallback: "Saved by Shortcuts")
            let count = store.visibleTransactions.filter { $0.note == shortcutNote }.count
            return String(format: localized("inbox.quick_setup.enabled.detail", fallback: "%d transactions logged with Shortcuts"), count)
        }
        return localized("inbox.quick_setup.subtitle", fallback: "Assign the shortcut to the Action Button so a press-and-hold logs your screenshot.")
    }

    private var captureFlowRow: some View {
        HStack(spacing: 8) {
            captureFlowItem(
                title: localized("inbox.capture.flow.action", fallback: "长按"),
                systemImage: "button.programmable"
            )

            captureFlowDivider

            captureFlowItem(
                title: localized("inbox.capture.flow.screenshot", fallback: "自动截图"),
                systemImage: "photo"
            )

            captureFlowDivider

            captureFlowItem(
                title: localized("inbox.capture.flow.ledger", fallback: "记账"),
                systemImage: "checkmark.circle"
            )
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.14))
        )
    }

    private var captureFlowDivider: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.white.opacity(0.58))
            .accessibilityHidden(true)
    }

    private func captureFlowItem(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .accessibilityHidden(true)

            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }

    private var captureHeroMetrics: some View {
        HStack(spacing: 10) {
            captureHeroMetricButton(
                title: localized("inbox.hero.monthly_expense.title", fallback: "This Month"),
                value: AppFormatters.currency(store.monthlySnapshot.totalExpense),
                detail: String(format: localized("inbox.hero.monthly_expense.detail", fallback: "%d transactions"), store.monthlySnapshot.transactionCount),
                systemImage: "chart.bar.fill",
                action: { selectedTab = AutoLedgerHomeTab.report.rawValue }
            )
            .accessibilityHint(Text("inbox.hero.monthly_expense.accessibility_hint"))

            captureHeroMetricButton(
                title: localized("inbox.hero.top_merchant.title", fallback: "Top Merchant"),
                value: store.monthlySnapshot.topMerchant,
                detail: String(format: localized("inbox.hero.top_merchant.detail", fallback: "%d merchants"), store.monthlySnapshot.topMerchants.count),
                systemImage: "storefront.fill",
                action: { showMerchantSheet = true }
            )
            .accessibilityLabel(String(format: localized("inbox.hero.top_merchant.accessibility_label_format", fallback: "Top merchant %@"), store.monthlySnapshot.topMerchant))
            .accessibilityHint(Text("inbox.hero.top_merchant.accessibility_hint"))
        }
    }

    private func captureHeroMetricButton(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)

                    Text(title)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.white.opacity(0.78))

                Text(value)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }

    private var expandedQuickSetupActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            heroSetupStep(
                number: "1",
                title: localized("inbox.quick_setup.step1.title", fallback: "Get the Shortcut"),
                detail: localized("inbox.quick_setup.step1.detail", fallback: "Add the Quick Ledger shortcut to your iPhone.")
            )

            Link(destination: URL(string: "https://www.icloud.com/shortcuts/e64528fb5bc34afdab4d7c64242d537e")!) {
                heroActionLabel(title: "inbox.quick_setup.add_shortcut", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.plain)

            heroSetupStep(
                number: "2",
                title: localized("inbox.quick_setup.step2.title", fallback: "Assign the Action Button"),
                detail: localized("inbox.quick_setup.step2.detail", fallback: "Go to Settings -> Action Button -> Shortcut, then choose Quick Ledger.")
            )

            Button {
                if let url = URL(string: "App-prefs:") {
                    UIApplication.shared.open(url)
                }
            } label: {
                heroActionLabel(title: "inbox.quick_setup.open_settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)

            heroSetupStep(
                number: "3",
                title: localized("inbox.quick_setup.step3.title", fallback: "Press and Hold to Log"),
                detail: localized("inbox.quick_setup.step3.detail", fallback: "Take a payment screenshot, then press and hold the Action Button to recognize and save it.")
            )

            Text("inbox.quick_setup.clipboard_hint")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func heroSetupStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.white)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func heroActionLabel(title: LocalizedStringKey, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .accessibilityHidden(true)

            Text(title)
                .font(.headline.weight(.bold))

            Spacer()

            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .accessibilityHidden(true)
        }
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
        )
    }

    private func toggleQuickSetupExpansion() {
        if reduceMotion {
            isQuickSetupExpanded.toggle()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                isQuickSetupExpanded.toggle()
            }
        }
    }

    private var compactMonthlyInsightStrip: some View {
        HStack(spacing: 10) {
            compactInsightButton(
                title: localized("inbox.hero.monthly_expense.title", fallback: "This Month"),
                value: AppFormatters.currency(store.monthlySnapshot.totalExpense),
                detail: String(format: localized("inbox.hero.monthly_expense.detail", fallback: "%d transactions"), store.monthlySnapshot.transactionCount),
                systemImage: "chart.bar.fill",
                action: { selectedTab = AutoLedgerHomeTab.report.rawValue }
            )
            .accessibilityHint(Text("inbox.hero.monthly_expense.accessibility_hint"))

            compactInsightButton(
                title: localized("inbox.hero.top_merchant.title", fallback: "Top Merchant"),
                value: store.monthlySnapshot.topMerchant,
                detail: String(format: localized("inbox.hero.top_merchant.detail", fallback: "%d merchants"), store.monthlySnapshot.topMerchants.count),
                systemImage: "storefront.fill",
                action: { showMerchantSheet = true }
            )
            .accessibilityLabel(String(format: localized("inbox.hero.top_merchant.accessibility_label_format", fallback: "Top merchant %@"), store.monthlySnapshot.topMerchant))
            .accessibilityHint(Text("inbox.hero.top_merchant.accessibility_hint"))
        }
    }

    private func compactInsightButton(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.12))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                    Text(value)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .autoLedgerCardSurface(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }

    private var quickImportButtonRow: some View {
        Group {
            if isQuickSetupExpanded && isCameraImportAvailable {
                HStack(spacing: 12) {
                    photoImportButton
                    receiptScanButton
                }
            } else {
                VStack(spacing: 12) {
                    photoImportButton
                    if isCameraImportAvailable {
                        receiptScanButton
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: isQuickSetupExpanded)
    }

    private var photoImportButton: some View {
        PhotosPicker(
            selection: $selectedPhoto,
            matching: .images,
            preferredItemEncoding: .automatic
        ) {
            quickImportButtonLabel(
                title: isImportingPhoto ? String(localized: "inbox.import.processing") : localized("inbox.import.photo_short", fallback: "相册截图"),
                subtitle: localized("inbox.import.photo_short_detail", fallback: "支付截图导入"),
                systemImage: isImportingPhoto ? nil : "photo.on.rectangle",
                isLoading: isImportingPhoto,
                tint: AppTheme.accent
            )
        }
        .buttonStyle(.plain)
    }

    private var receiptScanButton: some View {
        Button {
            startCameraImport()
        } label: {
            quickImportButtonLabel(
                title: isImportingCamera ? String(localized: "inbox.import.processing") : localized("inbox.import.scan_receipt", fallback: "票据扫描"),
                subtitle: localized("inbox.import.scan_receipt_detail", fallback: "实时拍照识别"),
                systemImage: isImportingCamera ? nil : "doc.viewfinder",
                isLoading: isImportingCamera,
                tint: AppTheme.accentSecondary
            )
        }
        .buttonStyle(.plain)
    }

    private func quickImportButtonLabel(
        title: String,
        subtitle: String,
        systemImage: String?,
        isLoading: Bool,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(tint.opacity(0.14))
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(tint)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 20)
    }

    private var quickEntryActionMenu: some View {
        Menu {
            Button {
                isPresentingManualEntry = true
            } label: {
                Label("transaction_editor.title.new", systemImage: "plus.circle")
            }

            Button {
                isPresentingVoiceEntry = true
            } label: {
                Label("voice_ledger_title", systemImage: "waveform")
            }

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                preferredItemEncoding: .automatic
            ) {
                Label("inbox.import.photo_short", systemImage: "photo.on.rectangle")
            }

            if isCameraImportAvailable {
                Button {
                    startCameraImport()
                } label: {
                    Label("inbox.import.scan_receipt", systemImage: "doc.viewfinder")
                }
            }

            Button {
                Task { await importFromClipboard() }
            } label: {
                Label("inbox.import.clipboard", systemImage: "doc.on.clipboard")
            }
        } label: {
            Label("common.more_actions", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
        }
        .accessibilityLabel(Text("common.more_actions"))
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
        .autoLedgerCardSurface(cornerRadius: 22)
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
                    let count = store.visibleTransactions.filter { $0.note == shortcutNote }.count
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
            .autoLedgerCardSurface(cornerRadius: 22)
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
                        Text(AppFormatters.currency(sub.amount, code: sub.currencyCode))
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
        .autoLedgerCardSurface(cornerRadius: 22)
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
        .autoLedgerCardSurface(cornerRadius: 20)
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
        .autoLedgerCardSurface(cornerRadius: 18)
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
        .autoLedgerCardSurface(cornerRadius: 22)
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
        for t in store.visibleTransactions {
            totals[t.merchant, default: 0] += t.amount
        }
        return totals.map { (merchant: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    @ViewBuilder
    private var manualEntrySheet: some View {
        TransactionEditorView(
            transaction: Transaction(
                merchant: "",
                amount: 0,
                occurredAt: .now,
                category: .other,
                source: .manual,
                note: ""
            ),
            isNew: true
        ) { newTransaction, _, _ in
            store.addTransaction(newTransaction)
        }
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
            .autoLedgerListChrome()
            .autoLedgerNavigationBarChrome()
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

    private func startCameraImport() {
        guard isCameraImportAvailable else {
            store.setImportError(localized("inbox.import.camera_unavailable", fallback: "Camera is unavailable on this device."), imageSource: .camera)
            return
        }
        showCamera = true
    }
}

private extension InboxView {
    var isCameraImportAvailable: Bool {
        #if targetEnvironment(macCatalyst)
        false
        #else
        UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

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
