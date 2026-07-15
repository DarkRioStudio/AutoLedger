import AutoLedgerCore
import SwiftUI

struct DataCleaningSuggestionsView: View {
    @EnvironmentObject private var store: LedgerStore
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared
    @State private var pendingPreviews: [DataCleaningPreviewItem] = []
    @State private var showsApplyConfirmation = false
    @State private var isPresentingProSheet = false
    @State private var snapshot = DataCleaningPreviewSnapshot()
    @State private var advancedRulePlan = AdvancedRuleAutomationPlan(rules: [])
    @State private var cloudAssistDecision = DataCleaningAssistRequestDecision(
        isAllowed: false,
        reason: .disabledByUser
    )
    @State private var isAnalyzing = true
    @AppStorage("dataCleaningCloudAssistEnabled") private var cloudAssistEnabled = false

    private var previews: [DataCleaningPreviewItem] {
        snapshot.items
    }

    private var analysisRevision: String {
        [
            String(store.dataCleaningRevision),
            cloudAssistEnabled ? "cloud-on" : "cloud-off",
            proEntitlement.isProActive ? "pro" : "free"
        ].joined(separator: "|")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AutoLedgerPageTitle("ipad.cleaning.title")

                if proEntitlement.canUse(.advancedRuleAutomation) {
                    summaryRow
                    advancedRuleAutomationCard
                    cloudAssistAuthorizationCard

                    if isAnalyzing {
                        ProgressView("ipad.cleaning.analyzing")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else if previews.isEmpty {
                        emptyState
                    } else {
                        applyAllRow

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(previews) { item in
                                suggestionCard(item)
                            }
                        }
                    }

                    if store.lastDataCleaningApplicationResult != nil {
                        undoCard
                    }

                    historySection
                } else {
                    proGateCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
            .autoLedgerReadableContent(maxWidth: 720)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("ipad.cleaning.title")
        .autoLedgerSolidNavigationBarChrome()
        .onAppear {
            let startedAt = Date()
            CommonAPIAnalyticsService.trackFeatureSurfaceOpened(
                surface: "data_cleaning",
                entrySurface: "settings_or_ledger",
                isProSurface: true,
                openReason: "view_appear"
            )
            CommonAPIAnalyticsService.trackUIResponsiveness(
                surface: "data_cleaning",
                operation: "surface_ready",
                startedAt: startedAt
            )
        }
        .onChange(of: cloudAssistEnabled) { _, isEnabled in
            CommonAPIAnalyticsService.trackFeatureSurfaceOpened(
                surface: "data_cleaning_cloud_assist",
                entrySurface: "data_cleaning",
                isProSurface: true,
                openReason: isEnabled ? "enabled" : "disabled"
            )
        }
        .task {
            await proEntitlement.loadProducts()
            await proEntitlement.refreshEntitlements()
        }
        .task(id: analysisRevision) {
            await refreshAnalysis()
        }
        .confirmationDialog(
            "ipad.cleaning.apply_confirm_title",
            isPresented: $showsApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button("ipad.cleaning.apply_confirm_action", role: .destructive) {
                applyPendingPreviews()
            }
            Button("common.cancel", role: .cancel) {
                pendingPreviews = []
            }
        } message: {
            Text("ipad.cleaning.apply_confirm_message")
        }
        .sheet(isPresented: $isPresentingProSheet) {
            NavigationStack {
                AutoLedgerProView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.close") {
                                isPresentingProSheet = false
                            }
                        }
                    }
            }
        }
    }

    private var advancedRuleAutomationCard: some View {
        let plan = advancedRulePlan
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("ipad.cleaning.rules.title")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(String(
                        format: String(localized: "ipad.cleaning.rules.subtitle_format"),
                        plan.ruleCount,
                        plan.affectedTransactionCount
                    ))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 10) {
                ruleMetric(
                    String(format: String(localized: "ipad.cleaning.rules.alias_count_format"), plan.rules(kind: .merchantAlias).count),
                    systemImage: "textformat.alt",
                    tint: AppTheme.accent
                )
                ruleMetric(
                    String(format: String(localized: "ipad.cleaning.rules.category_count_format"), plan.rules(kind: .categoryCorrection).count),
                    systemImage: "tag.fill",
                    tint: AppTheme.accentSecondary
                )
                ruleMetric(
                    String(format: String(localized: "ipad.cleaning.rules.affected_count_format"), plan.affectedTransactionCount),
                    systemImage: "checklist",
                    tint: AppTheme.ink
                )
            }

            if plan.isEmpty {
                Label("ipad.cleaning.rules.empty", systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            } else {
                Button {
                    CommonAPIAnalyticsService.trackFeatureSurfaceOpened(
                        surface: "data_cleaning_rules",
                        entrySurface: "data_cleaning",
                        isProSurface: true,
                        openReason: "apply_rules"
                    )
                    pendingPreviews = advancedRulePlan.previewItems
                    showsApplyConfirmation = true
                } label: {
                    Label("ipad.cleaning.rules.apply", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .padding(16)
        .autoLedgerCardSurface(cornerRadius: 18)
    }

    private func ruleMetric(_ text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .padding(.horizontal, 10)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var cloudAssistAuthorizationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "cloud.bolt.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("ipad.cleaning.cloud_assist.title")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("ipad.cleaning.cloud_assist.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: $cloudAssistEnabled)
                    .labelsHidden()
                    .tint(AppTheme.accent)
            }

            Label(cloudAssistStatusText, systemImage: cloudAssistDecision.isAllowed ? "checkmark.seal.fill" : "info.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(cloudAssistDecision.isAllowed ? AppTheme.accent : AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("ipad.cleaning.cloud_assist.privacy_note")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .autoLedgerCardSurface(cornerRadius: 18)
    }

    private var cloudAssistStatusText: LocalizedStringKey {
        switch cloudAssistDecision.reason {
        case .allowed:
            return "ipad.cleaning.cloud_assist.status.allowed"
        case .disabledByUser:
            return "ipad.cleaning.cloud_assist.status.disabled"
        case .requiresPro:
            return "ipad.cleaning.cloud_assist.status.requires_pro"
        case .insufficientHistory:
            return "ipad.cleaning.cloud_assist.status.insufficient_history"
        case .coolingDown:
            return "ipad.cleaning.cloud_assist.status.cooling_down"
        case .backoffActive:
            return "ipad.cleaning.cloud_assist.status.backoff"
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryPill("ipad.cleaning.summary.alias", value: snapshot.items(kind: .merchantAlias).count, tint: AppTheme.accent)
            summaryPill("ipad.cleaning.summary.category", value: snapshot.items(kind: .categoryCorrection).count, tint: AppTheme.accentSecondary)
            summaryPill("ipad.cleaning.summary.duplicate", value: snapshot.items(kind: .duplicateCandidate).count, tint: Color(red: 0.84, green: 0.45, blue: 0.12))
        }
    }

    private func summaryPill(_ titleKey: LocalizedStringKey, value: Int, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .monospacedDigit()
            Text(titleKey)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(tint)
                .frame(height: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.accent)
            Text("ipad.cleaning.empty.title")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text("ipad.cleaning.empty.subtitle")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .padding(20)
        .autoLedgerCardSurface(cornerRadius: 18)
    }

    @ViewBuilder
    private var historySection: some View {
        if !store.dataCleaningApplicationHistory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("ipad.cleaning.history.title", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                VStack(spacing: 10) {
                    ForEach(store.dataCleaningApplicationHistory.prefix(5)) { entry in
                        historyRow(entry)
                    }
                }
            }
            .padding(16)
            .autoLedgerCardSurface(cornerRadius: 18)
        }
    }

    private func historyRow(_ entry: DataCleaningApplicationHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.undoneAt == nil ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                .font(.headline)
                .foregroundStyle(entry.undoneAt == nil ? AppTheme.accent : AppTheme.mutedInk)
                .frame(width: 28, height: 28)
                .background((entry.undoneAt == nil ? AppTheme.accent : AppTheme.mutedInk).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(kindTitle(entry.kind))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(entry.appliedAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Text(historyDetail(entry))
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let firstTitle = entry.previewTitles.first {
                    Text(firstTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(entry.undoneAt == nil ? String(localized: "ipad.cleaning.history.applied") : String(localized: "ipad.cleaning.history.undone"))
                .font(.caption.weight(.bold))
                .foregroundStyle(entry.undoneAt == nil ? AppTheme.accent : AppTheme.mutedInk)
        }
        .padding(.vertical, 4)
    }

    private var applyAllRow: some View {
        Button {
            pendingPreviews = previews
            showsApplyConfirmation = true
        } label: {
            Label("ipad.cleaning.apply_all", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.accent)
    }

    private var proGateCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "wand.and.sparkles")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 58, height: 58)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("ipad.cleaning.pro.title")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text("ipad.cleaning.pro.body")
                    .font(.body)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text("ipad.cleaning.pro.free_note")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                CommonAPIAnalyticsService.trackProGateViewed(
                    surface: "data_cleaning",
                    featureArea: "advanced_rule_automation",
                    userAction: "view_plans",
                    dismissReasonCode: "requires_pro"
                )
                isPresentingProSheet = true
            } label: {
                Label("pro.cta.view_plans", systemImage: "sparkles")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
        .padding(22)
        .autoLedgerCardSurface(cornerRadius: 22)
    }

    private func suggestionCard(_ item: DataCleaningPreviewItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: kindIcon(item.kind))
                    .font(.headline)
                    .foregroundStyle(kindTint(item.kind))
                    .frame(width: 40, height: 40)
                    .background(kindTint(item.kind).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(kindTitle(item.kind))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(kindTint(item.kind))
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                    Text(localizedReason(item))
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text("\(item.affectedTransactionIDs.count)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .monospacedDigit()
            }

            VStack(spacing: 8) {
                detailRow("ipad.cleaning.current", value: item.currentValue)
                detailRow("ipad.cleaning.proposed", value: item.proposedValue)
                if let score = item.score {
                    detailRow("ipad.cleaning.score", value: String(format: "%.0f%%", score * 100))
                }
            }

            HStack(spacing: 10) {
                Button {
                    CommonAPIAnalyticsService.trackFeatureSurfaceOpened(
                        surface: "data_cleaning_suggestion",
                        entrySurface: "data_cleaning",
                        isProSurface: true,
                        openReason: "ignore_\(analyticsKind(item.kind))"
                    )
                    store.ignoreDataCleaningPreview(id: item.id)
                } label: {
                    Label("ipad.cleaning.ignore", systemImage: "eye.slash")
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.bordered)

                Button {
                    CommonAPIAnalyticsService.trackFeatureSurfaceOpened(
                        surface: "data_cleaning_suggestion",
                        entrySurface: "data_cleaning",
                        isProSurface: true,
                        openReason: "apply_\(analyticsKind(item.kind))"
                    )
                    pendingPreviews = [item]
                    showsApplyConfirmation = true
                } label: {
                    Label(applyButtonTitle(for: item.kind), systemImage: item.kind == .duplicateCandidate ? "trash" : "checkmark.circle.fill")
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(kindTint(item.kind))
            }
        }
        .padding(16)
        .autoLedgerCardSurface(cornerRadius: 18)
    }

    private func detailRow(_ titleKey: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(titleKey)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 72, alignment: .leading)
            Text(verbatim: value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }

    private var undoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let result = store.lastDataCleaningApplicationResult {
                Text("ipad.cleaning.result")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(String(
                    format: String(localized: "ipad.cleaning.result_format"),
                    result.updatedCount,
                    result.deletedCount,
                    result.skippedCount
                ))
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
            }

            Button {
                _ = store.undoLastDataCleaningApplication()
                Task { await refreshAnalysis() }
            } label: {
                Label("ipad.cleaning.undo_last", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.bordered)
            .disabled(store.lastDataCleaningApplicationResult?.canUndo != true)
        }
        .padding(16)
        .autoLedgerCardSurface(cornerRadius: 18)
    }

    private func applyPendingPreviews() {
        guard !pendingPreviews.isEmpty else { return }
        let startedAt = Date()
        CommonAPIAnalyticsService.trackImportStarted(
            flowType: "data_cleaning",
            inputType: "local_ledger",
            entrySurface: "data_cleaning",
            isProSurface: true
        )
        _ = store.applyDataCleaningPreviews(pendingPreviews)
        CommonAPIAnalyticsService.trackImportCompleted(
            flowType: "data_cleaning",
            inputType: "local_ledger",
            status: "success",
            startedAt: startedAt
        )
        pendingPreviews = []
        Task { await refreshAnalysis() }
    }

    private func refreshAnalysis() async {
        isAnalyzing = true
        let transactions = store.visibleTransactions
        let merchantAliases = store.merchantAliases
        let categoryCorrections = store.categoryCorrections
        let ignoredIDs = store.ignoredDataCleaningPreviewIDs
        let allTransactions = store.transactions
        let isCloudAssistEnabled = cloudAssistEnabled
        let isProActive = proEntitlement.isProActive
        let result = await Task.detached(priority: .userInitiated) {
            let snapshot = DataCleaningPreviewPlanner().buildSnapshot(
                transactions: transactions,
                merchantAliases: merchantAliases,
                categoryCorrections: categoryCorrections,
                ignoredPreviewIDs: ignoredIDs
            )
            let plan = AdvancedRuleAutomationPlanner().buildPlan(snapshot: snapshot)
            let cloudDecision: DataCleaningAssistRequestDecision
            if !isCloudAssistEnabled {
                cloudDecision = DataCleaningAssistRequestDecision(
                    isAllowed: false,
                    reason: .disabledByUser
                )
            } else if !isProActive {
                cloudDecision = DataCleaningAssistRequestDecision(
                    isAllowed: false,
                    reason: .requiresPro
                )
            } else {
                let payload = DataCleaningAssistPayloadBuilder().build(
                    transactions: allTransactions,
                    merchantAliases: merchantAliases,
                    categoryCorrections: categoryCorrections
                )
                cloudDecision = DataCleaningAssistRequestPolicy().evaluate(
                    payload: payload,
                    context: DataCleaningAssistRequestContext(
                        userEnabledCloudAssist: true,
                        isProActive: true
                    )
                )
            }
            return (snapshot, plan, cloudDecision)
        }.value
        guard !Task.isCancelled else { return }
        snapshot = result.0
        advancedRulePlan = result.1
        cloudAssistDecision = result.2
        isAnalyzing = false
    }

    private func applyButtonTitle(for kind: DataCleaningPreviewKind) -> LocalizedStringKey {
        switch kind {
        case .merchantAlias, .categoryCorrection:
            return "ipad.cleaning.apply"
        case .duplicateCandidate:
            return "ipad.cleaning.apply_duplicate"
        }
    }

    private func localizedReason(_ item: DataCleaningPreviewItem) -> String {
        if item.reason == "merchant normalization suggestion" {
            return String(localized: "ipad.cleaning.reason.normalization")
        }
        switch item.kind {
        case .merchantAlias:
            return String(localized: "ipad.cleaning.reason.alias")
        case .categoryCorrection:
            return String(localized: "ipad.cleaning.reason.category")
        case .duplicateCandidate:
            return String(localized: "ipad.cleaning.reason.duplicate")
        }
    }

    private func analyticsKind(_ kind: DataCleaningPreviewKind) -> String {
        switch kind {
        case .merchantAlias:
            return "alias"
        case .categoryCorrection:
            return "category_correction"
        case .duplicateCandidate:
            return "duplicate_candidate"
        }
    }

    private func historyDetail(_ entry: DataCleaningApplicationHistoryEntry) -> String {
        String(
            format: String(localized: "ipad.cleaning.history.detail_format"),
            entry.previewCount,
            entry.updatedCount,
            entry.deletedCount,
            entry.skippedCount
        )
    }

    private func kindTitle(_ kind: DataCleaningPreviewKind) -> String {
        switch kind {
        case .merchantAlias:
            return String(localized: "ipad.cleaning.kind.alias")
        case .categoryCorrection:
            return String(localized: "ipad.cleaning.kind.category")
        case .duplicateCandidate:
            return String(localized: "ipad.cleaning.kind.duplicate")
        }
    }

    private func kindIcon(_ kind: DataCleaningPreviewKind) -> String {
        switch kind {
        case .merchantAlias:
            return "textformat.alt"
        case .categoryCorrection:
            return "tag.fill"
        case .duplicateCandidate:
            return "doc.on.doc.fill"
        }
    }

    private func kindTint(_ kind: DataCleaningPreviewKind) -> Color {
        switch kind {
        case .merchantAlias:
            return AppTheme.accent
        case .categoryCorrection:
            return AppTheme.accentSecondary
        case .duplicateCandidate:
            return Color(red: 0.84, green: 0.45, blue: 0.12)
        }
    }
}

#Preview {
    NavigationStack {
        DataCleaningSuggestionsView()
            .environmentObject(LedgerStore())
    }
}
