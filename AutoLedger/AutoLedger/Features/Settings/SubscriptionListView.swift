import AutoLedgerCore
import PhotosUI
import SwiftUI

struct SubscriptionListView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImporting = false
    @State private var editor: SubscriptionEditorPresentation?
    @State private var selectedSubscriptionID: UUID?
    @State private var annualPriceOverrides: [String: Double] = [:]
    @State private var subscriptionNotes: [String: String] = [:]
    private let ocrService = OCRService()
    private let annualPriceKey = "subscriptionAnnualPriceOverrides"
    private let subscriptionNotesKey = "subscriptionNotes"

    var body: some View {
        NavigationSplitView {
            subscriptionList
        } detail: {
            subscriptionDetail
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    editor = .create
                } label: {
                    Image(systemName: "plus")
                }
                .help(String(localized: "subscriptions.add_help"))

                Button {
                    store.detectAndUpsertSubscriptions()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .help(String(localized: "subscriptions.scan_history_help"))
            }
        }
        .sheet(item: $editor) { presentation in
            SubscriptionEditView(
                subscription: presentation.subscription,
                mode: presentation.mode,
                annualPrice: annualPriceOverrides[presentation.subscription.id.uuidString],
                note: subscriptionNotes[presentation.subscription.id.uuidString] ?? ""
            ) { updated, annualPrice, note in
                if presentation.isNew {
                    store.createSubscription(updated)
                    selectedSubscriptionID = updated.id
                } else {
                    store.updateSubscription(updated)
                }
                saveAnnualPrice(annualPrice, for: updated)
                saveNote(note, for: updated)
                store.requestAutomaticBackup()
            }
        }
        .onAppear {
            loadSupplementalSubscriptionData()
        }
        .onChange(of: scopedSubscriptions.map(\.id)) { _, visibleIDs in
            guard let selectedSubscriptionID, !visibleIDs.contains(selectedSubscriptionID) else { return }
            self.selectedSubscriptionID = nil
        }
    }

    // MARK: - Upcoming

    private var scopedSubscriptions: [Subscription] {
        store.visibleSubscriptions
    }

    private var selectedSubscription: Subscription? {
        guard let selectedSubscriptionID else { return nil }
        return scopedSubscriptions.first { $0.id == selectedSubscriptionID }
    }

    private var subscriptionList: some View {
        List(selection: $selectedSubscriptionID) {
            if let summary = store.lastImportSummary {
                importStatusBanner(summary)
                    .listRowBackground(AppTheme.card)
            }

            if scopedSubscriptions.isEmpty {
                emptyState
                    .listRowBackground(AppTheme.card)
            } else {
                let upcoming = upcomingSubscriptions
                if !upcoming.isEmpty {
                    Section("subscriptions.upcoming") {
                        ForEach(upcoming) { sub in
                            subscriptionNavigationRow(sub, highlight: true)
                        }
                    }
                }

                Section {
                    ForEach(scopedSubscriptions) { sub in
                        subscriptionNavigationRow(sub, highlight: false)
                    }

                    annualSummaryCard
                        .listRowBackground(AppTheme.card)
                } header: {
                    HStack {
                        Text("subscriptions.all")
                        Spacer()
                        Text(String(format: String(localized: "subscriptions.count_format"), scopedSubscriptions.count))
                    }
                } footer: {
                    Text(String(format: String(localized: "subscriptions.monthly_estimate_format"), AppFormatters.currency(monthlyEstimate)))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("settings.subscriptions.title")
    }

    private var monthlyEstimate: Double {
        activeSubscriptions.reduce(0.0) { sum, sub in
            switch sub.period {
            case .weekly:  return sum + sub.amount * 4.33
            case .monthly: return sum + sub.amount
            case .yearly:  return sum + sub.amount / 12.0
            }
        }
    }

    private func subscriptionNavigationRow(_ sub: Subscription, highlight: Bool) -> some View {
        NavigationLink(value: sub.id) {
            subscriptionListRow(sub, highlight: highlight)
        }
        .tag(sub.id)
        .listRowBackground(AppTheme.card)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteSubscription(sub)
            } label: {
                Label("common.delete", systemImage: "trash")
            }

            if sub.status != .canceled {
                Button(role: .destructive) {
                    updateSubscriptionStatus(sub, .canceled)
                } label: {
                    Label("subscriptions.cancel_subscription", systemImage: "xmark.circle")
                }
                .tint(.orange)
            }

            let toggleTitle: LocalizedStringKey = sub.status == .active ? "subscriptions.pause" : "subscriptions.resume"
            let toggleIcon = sub.status == .active ? "pause.circle" : "play.circle"
            Button {
                updateSubscriptionStatus(sub, sub.status == .active ? .paused : .active)
            } label: {
                Label(toggleTitle, systemImage: toggleIcon)
            }
            .tint(AppTheme.accent)
        }
        .contextMenu {
            Button {
                selectedSubscriptionID = sub.id
            } label: {
                Label("common.edit", systemImage: "pencil")
            }

            if sub.status == .active {
                Button {
                    updateSubscriptionStatus(sub, .paused)
                } label: {
                    Label("subscriptions.pause", systemImage: "pause.circle")
                }
            } else {
                Button {
                    updateSubscriptionStatus(sub, .active)
                } label: {
                    Label("subscriptions.resume", systemImage: "play.circle")
                }
            }

            if sub.status != .canceled {
                Button(role: .destructive) {
                    updateSubscriptionStatus(sub, .canceled)
                } label: {
                    Label("subscriptions.cancel_subscription", systemImage: "xmark.circle")
                }
            }

            Button(role: .destructive) {
                deleteSubscription(sub)
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }

    private func subscriptionListRow(_ sub: Subscription, highlight: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "repeat.circle.fill")
                .font(.title2)
                .foregroundStyle(highlight ? AppTheme.accentSecondary : AppTheme.accent)
                .frame(width: 40, height: 40)
                .background((highlight ? AppTheme.accentSecondary : AppTheme.accent).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(sub.merchant)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                if !sub.planName.isEmpty {
                    Text(sub.planName)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                HStack(spacing: 8) {
                    Text(sub.period.title)
                    Text("·")
                    Text(String(format: String(localized: "subscriptions.next_charge_format"), AppFormatters.shortDateTime(sub.nextChargedAt)))
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(AppFormatters.currency(sub.amount))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Text(sub.status.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusTint(for: sub.status))

                if highlight {
                    Text(daysUntil(sub.nextChargedAt))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppTheme.accentSecondary))
                }
            }
        }
        .opacity(sub.status.isActive ? 1 : 0.72)
    }

    @ViewBuilder
    private var subscriptionDetail: some View {
        if let subscription = selectedSubscription {
            SubscriptionEditView(
                subscription: subscription,
                mode: .edit,
                annualPrice: annualPriceOverrides[subscription.id.uuidString],
                note: subscriptionNotes[subscription.id.uuidString] ?? "",
                usesNavigationStack: false,
                showsCancelButton: false,
                dismissesOnSave: false
            ) { updated, annualPrice, note in
                store.updateSubscription(updated)
                selectedSubscriptionID = updated.id
                saveAnnualPrice(annualPrice, for: updated)
                saveNote(note, for: updated)
                store.requestAutomaticBackup()
            }
            .id(subscription.id)
            .background(AppTheme.screenGradient.ignoresSafeArea())
        } else {
            ContentUnavailableView(
                "subscriptions.detail.empty.title",
                systemImage: "repeat.circle",
                description: Text("subscriptions.detail.empty.description")
            )
            .background(AppTheme.screenGradient.ignoresSafeArea())
        }
    }

    private var upcomingSubscriptions: [Subscription] {
        store.upcomingSubscriptionsForCurrentLedger()
    }

    private var activeSubscriptions: [Subscription] {
        scopedSubscriptions.filter { $0.status.isActive }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        let upcoming = upcomingSubscriptions
        if !upcoming.isEmpty {
            Text("subscriptions.upcoming")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            ForEach(upcoming) { sub in
                subscriptionCard(sub, highlight: true)
            }
        }
    }

    // MARK: - All

    private var allSubscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("subscriptions.all")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Text(String(format: String(localized: "subscriptions.count_format"), scopedSubscriptions.count))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            let monthlyCost = activeSubscriptions.reduce(0.0) { sum, sub in
                switch sub.period {
                case .weekly:  return sum + sub.amount * 4.33
                case .monthly: return sum + sub.amount
                case .yearly:  return sum + sub.amount / 12.0
                }
            }
            Text(String(format: String(localized: "subscriptions.monthly_estimate_format"), AppFormatters.currency(monthlyCost)))
                .font(.subheadline)
                .foregroundStyle(AppTheme.accentSecondary)

            ForEach(scopedSubscriptions) { sub in
                subscriptionCard(sub, highlight: false)
            }

            annualSummaryCard
        }
    }

    private var annualSummaryCard: some View {
        let annualCost = activeSubscriptions.reduce(0.0) { $0 + estimatedAnnualCost(for: $1) }
        let monthlyCost = annualCost / 12.0
        let knownSavings = activeSubscriptions.reduce(0.0) { sum, sub in
            guard let suggestion = savingsSuggestion(for: sub) else { return sum }
            return sum + max(0, suggestion.savings)
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("subscriptions.annual_overview")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("subscriptions.annual_estimate")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Text(AppFormatters.currency(annualCost))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }

            HStack(spacing: 10) {
                summaryPill(titleKey: "subscriptions.monthly_average", value: AppFormatters.currency(monthlyCost))
                summaryPill(titleKey: "subscriptions.optimizable", value: knownSavings > 0 ? AppFormatters.currency(knownSavings) : String(localized: "common.none"))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func summaryPill(titleKey: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titleKey)
                .font(.caption2)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.accent.opacity(0.08))
        )
    }

    private func importStatusBanner(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "common.import_status"))
        .accessibilityValue(summary)
    }

    // MARK: - Card

    private func subscriptionCard(_ sub: Subscription, highlight: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "repeat.circle.fill")
                .font(.title2)
                .foregroundStyle(highlight ? AppTheme.accentSecondary : AppTheme.accent)
                .frame(width: 40, height: 40)
                .background((highlight ? AppTheme.accentSecondary : AppTheme.accent).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(sub.merchant)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                if !sub.planName.isEmpty {
                    Text(sub.planName)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                HStack(spacing: 8) {
                    Text(sub.period.title)
                    Text("·")
                    Text(String(format: String(localized: "subscriptions.next_charge_format"), AppFormatters.shortDateTime(sub.nextChargedAt)))
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 6) {
                    Button {
                        editor = .edit(sub)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.accent)
                    .background(AppTheme.accent.opacity(0.10))
                    .clipShape(Circle())
                    .help(String(localized: "subscriptions.edit_help"))

                    statusToggleButton(for: sub)

                    if sub.status != .canceled {
                        Button(role: .destructive) {
                            updateSubscriptionStatus(sub, .canceled)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.caption.weight(.bold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.orange)
                        .background(Color.orange.opacity(0.10))
                        .clipShape(Circle())
                        .help(String(localized: "subscriptions.cancel_help"))
                    }

                    Button(role: .destructive) {
                        deleteSubscription(sub)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .background(Color.red.opacity(0.10))
                    .clipShape(Circle())
                    .help(String(localized: "subscriptions.delete_help"))
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text(AppFormatters.currency(sub.amount))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text(sub.status.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusTint(for: sub.status))

                    if highlight {
                        Text(daysUntil(sub.nextChargedAt))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.accentSecondary))
                    }
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let suggestion = savingsSuggestion(for: sub), suggestion.savings > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                    Text(String(format: String(localized: "subscriptions.annual_savings_short_format"), AppFormatters.currency(suggestion.savings)))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }
        }
        .padding(18)
        .padding(.bottom, savingsSuggestion(for: sub)?.savings ?? 0 > 0 ? 24 : 0)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
        .opacity(sub.status.isActive ? 1 : 0.72)
        .contextMenu {
            Button {
                editor = .edit(sub)
            } label: {
                Label("common.edit", systemImage: "pencil")
            }

            if sub.status == .active {
                Button {
                    updateSubscriptionStatus(sub, .paused)
                } label: {
                    Label("subscriptions.pause", systemImage: "pause.circle")
                }
            } else {
                Button {
                    updateSubscriptionStatus(sub, .active)
                } label: {
                    Label("subscriptions.resume", systemImage: "play.circle")
                }
            }

            if sub.status != .canceled {
                Button(role: .destructive) {
                    updateSubscriptionStatus(sub, .canceled)
                } label: {
                    Label("subscriptions.cancel_subscription", systemImage: "xmark.circle")
                }
            }

            Button(role: .destructive) {
                deleteSubscription(sub)
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "repeat.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.mutedInk.opacity(0.5))

            Text("subscriptions.empty.title")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text("subscriptions.empty.description")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .multilineTextAlignment(.center)

            Button {
                editor = .create
            } label: {
                Label("subscriptions.add", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                preferredItemEncoding: .automatic
            ) {
                HStack {
                    if isImporting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "envelope.open.fill")
                    }
                    Text(isImporting ? String(localized: "inbox.import.processing") : String(localized: "subscriptions.upload_renewal_screenshot"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .task(id: selectedPhoto) {
                guard let item = selectedPhoto else { return }
                await importPickedPhoto(item)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    // MARK: - Helpers

    private func daysUntil(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        if days <= 0 { return String(localized: "common.today") }
        if days == 1 { return String(localized: "common.tomorrow") }
        return String(format: String(localized: "common.days_later_format"), days)
    }

    private func estimatedAnnualCost(for sub: Subscription) -> Double {
        switch sub.period {
        case .weekly:  return sub.amount * 52.18
        case .monthly: return sub.amount * 12.0
        case .yearly:  return sub.amount
        }
    }

    private func savingsSuggestion(for sub: Subscription) -> (annualPrice: Double, savings: Double)? {
        guard sub.period == .monthly,
              let annualPrice = annualPriceOverrides[sub.id.uuidString],
              annualPrice > 0 else {
            return nil
        }
        return (annualPrice, sub.amount * 12.0 - annualPrice)
    }

    private func loadSupplementalSubscriptionData() {
        annualPriceOverrides = UserDefaults.standard.dictionary(forKey: annualPriceKey) as? [String: Double] ?? [:]
        subscriptionNotes = UserDefaults.standard.dictionary(forKey: subscriptionNotesKey) as? [String: String] ?? [:]
    }

    @ViewBuilder
    private func statusToggleButton(for sub: Subscription) -> some View {
        if sub.status == .active {
            Button {
                updateSubscriptionStatus(sub, .paused)
            } label: {
                Image(systemName: "pause")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accentSecondary)
            .background(AppTheme.accentSecondary.opacity(0.10))
            .clipShape(Circle())
            .help(String(localized: "subscriptions.pause_help"))
        } else {
            Button {
                updateSubscriptionStatus(sub, .active)
            } label: {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accent)
            .background(AppTheme.accent.opacity(0.10))
            .clipShape(Circle())
            .help(String(localized: "subscriptions.resume_help"))
        }
    }

    private func statusTint(for status: SubscriptionStatus) -> Color {
        switch status {
        case .active: return AppTheme.accent
        case .paused: return AppTheme.accentSecondary
        case .canceled: return .red
        }
    }

    private func saveAnnualPrice(_ value: Double?, for sub: Subscription) {
        if let value, value > 0 {
            annualPriceOverrides[sub.id.uuidString] = value
        } else {
            annualPriceOverrides.removeValue(forKey: sub.id.uuidString)
        }
        UserDefaults.standard.set(annualPriceOverrides, forKey: annualPriceKey)
        store.recordSubscriptionMetadataChanged()
    }

    private func saveNote(_ value: String, for sub: Subscription) {
        let note = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.isEmpty {
            subscriptionNotes.removeValue(forKey: sub.id.uuidString)
        } else {
            subscriptionNotes[sub.id.uuidString] = note
        }
        UserDefaults.standard.set(subscriptionNotes, forKey: subscriptionNotesKey)
        store.recordSubscriptionMetadataChanged()
    }

    private func deleteSubscription(_ sub: Subscription) {
        store.deleteSubscription(sub)
        if selectedSubscriptionID == sub.id {
            selectedSubscriptionID = nil
        }
        annualPriceOverrides.removeValue(forKey: sub.id.uuidString)
        subscriptionNotes.removeValue(forKey: sub.id.uuidString)
        UserDefaults.standard.set(annualPriceOverrides, forKey: annualPriceKey)
        UserDefaults.standard.set(subscriptionNotes, forKey: subscriptionNotesKey)
        store.recordSubscriptionMetadataChanged()
    }

    private func updateSubscriptionStatus(_ sub: Subscription, _ status: SubscriptionStatus) {
        store.updateSubscriptionStatus(sub, status: status)
    }

    private func importPickedPhoto(_ item: PhotosPickerItem) async {
        isImporting = true
        defer {
            isImporting = false
            selectedPhoto = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let text = try ocrService.recognizeText(from: data)
            store.importRecognizedText(text, notePrefix: String(localized: "subscriptions.renewal_screenshot_note"))
        } catch {
            store.setImportError(error.localizedDescription, imageSource: .photoLibrary)
        }
    }
}

private struct SubscriptionEditorPresentation: Identifiable {
    enum Mode {
        case create
        case edit
    }

    let id = UUID()
    let mode: Mode
    let subscription: Subscription

    var isNew: Bool {
        mode == .create
    }

    static var create: SubscriptionEditorPresentation {
        SubscriptionEditorPresentation(
            mode: .create,
            subscription: Subscription(
                merchant: "",
                planName: "",
                period: .monthly,
                amount: 0,
                lastChargedAt: .now,
                status: .active
            )
        )
    }

    static func edit(_ subscription: Subscription) -> SubscriptionEditorPresentation {
        SubscriptionEditorPresentation(mode: .edit, subscription: subscription)
    }
}

private struct SubscriptionEditView: View {
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription
    let mode: SubscriptionEditorPresentation.Mode
    let onSave: (Subscription, Double?, String) -> Void
    let usesNavigationStack: Bool
    let showsCancelButton: Bool
    let dismissesOnSave: Bool
    let onCancel: (() -> Void)?

    @State private var merchant: String
    @State private var planName: String
    @State private var period: SubscriptionPeriod
    @State private var amountText: String
    @State private var lastChargedAt: Date
    @State private var nextChargedAt: Date
    @State private var status: SubscriptionStatus
    @State private var annualPriceText: String
    @State private var note: String

    init(
        subscription: Subscription,
        mode: SubscriptionEditorPresentation.Mode,
        annualPrice: Double?,
        note: String,
        usesNavigationStack: Bool = true,
        showsCancelButton: Bool = true,
        dismissesOnSave: Bool = true,
        onCancel: (() -> Void)? = nil,
        onSave: @escaping (Subscription, Double?, String) -> Void
    ) {
        self.subscription = subscription
        self.mode = mode
        self.onSave = onSave
        self.usesNavigationStack = usesNavigationStack
        self.showsCancelButton = showsCancelButton
        self.dismissesOnSave = dismissesOnSave
        self.onCancel = onCancel
        _merchant = State(initialValue: subscription.merchant)
        _planName = State(initialValue: subscription.planName)
        _period = State(initialValue: subscription.period)
        _amountText = State(initialValue: mode == .create ? "" : Self.text(from: subscription.amount))
        _lastChargedAt = State(initialValue: subscription.lastChargedAt)
        _nextChargedAt = State(initialValue: subscription.nextChargedAt)
        _status = State(initialValue: subscription.status)
        _annualPriceText = State(initialValue: annualPrice.map(Self.text(from:)) ?? "")
        _note = State(initialValue: note)
    }

    var body: some View {
        if usesNavigationStack {
            NavigationStack {
                editContent
            }
        } else {
            editContent
        }
    }

    private var editContent: some View {
        Form {
                Section("subscriptions.edit.section.subscription") {
                    TextField("transaction_editor.merchant", text: $merchant)
                    TextField("subscriptions.edit.plan_name", text: $planName)
                    Picker("subscriptions.edit.period", selection: $period) {
                        ForEach(SubscriptionPeriod.allCases, id: \.self) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    TextField("transaction_editor.amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("subscriptions.edit.status", selection: $status) {
                        ForEach(SubscriptionStatus.allCases, id: \.self) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }

                Section("subscriptions.edit.section.charge_dates") {
                    DatePicker("subscriptions.edit.last_charged", selection: $lastChargedAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("subscriptions.edit.next_charge", selection: $nextChargedAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section("subscriptions.edit.section.optimization") {
                    TextField("subscriptions.edit.annual_price_optional", text: $annualPriceText)
                        .keyboardType(.decimalPad)

                    if let savingsText {
                        Text(savingsText)
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                Section("transaction_editor.note") {
                    TextField("subscriptions.edit.note_optional", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                }
        }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .navigationTitle(mode == .create ? "subscriptions.add.title" : "subscriptions.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCancelButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") {
                            if let onCancel {
                                onCancel()
                            } else {
                                dismiss()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: period) { _, newValue in
                nextChargedAt = newValue.nextDate(from: lastChargedAt)
            }
            .onChange(of: lastChargedAt) { _, newValue in
                nextChargedAt = period.nextDate(from: newValue)
            }
    }

    private var amount: Double? {
        Self.decimalValue(from: amountText)
    }

    private var annualPrice: Double? {
        Self.decimalValue(from: annualPriceText)
    }

    private var canSave: Bool {
        guard let amount else { return false }
        return !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }

    private var savingsText: String? {
        guard period == .monthly, let amount, let annualPrice, annualPrice > 0 else { return nil }
        let savings = amount * 12.0 - annualPrice
        if savings > 0 {
            return String(format: String(localized: "subscriptions.annual_savings_full_format"), AppFormatters.currency(savings))
        }
        return String(localized: "subscriptions.no_annual_savings")
    }

    private func save() {
        guard let amount else { return }
        let updated = Subscription(
            id: subscription.id,
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            planName: planName.trimmingCharacters(in: .whitespacesAndNewlines),
            period: period,
            amount: amount,
            lastChargedAt: lastChargedAt,
            nextChargedAt: nextChargedAt,
            status: status,
            createdAt: subscription.createdAt
        )
        onSave(updated, annualPrice, note)
        if dismissesOnSave {
            dismiss()
        }
    }

    nonisolated private static func decimalValue(from text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    nonisolated private static func text(from amount: Double) -> String {
        String(format: "%.2f", amount)
    }
}

#Preview {
    NavigationStack {
        SubscriptionListView()
    }
    .environmentObject(LedgerStore())
}
