import AutoLedgerCore
import SwiftUI

struct DataCleaningSuggestionsView: View {
    @EnvironmentObject private var store: LedgerStore
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared
    @State private var pendingPreview: DataCleaningPreviewItem?
    @State private var showsApplyConfirmation = false
    @State private var isPresentingProSheet = false

    private var snapshot: DataCleaningPreviewSnapshot {
        DataCleaningPreviewPlanner().buildSnapshot(
            transactions: store.visibleTransactions,
            merchantAliases: store.merchantAliases,
            categoryCorrections: store.categoryCorrections
        )
    }

    private var previews: [DataCleaningPreviewItem] {
        snapshot.items
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AutoLedgerPageTitle("ipad.cleaning.title")

                if proEntitlement.canUse(.merchantNormalizationSuggestions) {
                    summaryRow

                    if previews.isEmpty {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(previews) { item in
                                suggestionCard(item)
                            }
                        }

                        undoCard
                    }
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
        .task {
            await proEntitlement.loadProducts()
            await proEntitlement.refreshEntitlements()
        }
        .confirmationDialog(
            "ipad.cleaning.apply_confirm_title",
            isPresented: $showsApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button("ipad.cleaning.apply_confirm_action", role: .destructive) {
                applyPendingPreview()
            }
            Button("common.cancel", role: .cancel) {
                pendingPreview = nil
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

            Button {
                pendingPreview = item
                showsApplyConfirmation = true
            } label: {
                Label(applyButtonTitle(for: item.kind), systemImage: item.kind == .duplicateCandidate ? "trash" : "checkmark.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.borderedProminent)
            .tint(kindTint(item.kind))
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

    private func applyPendingPreview() {
        guard let pendingPreview else { return }
        _ = store.applyDataCleaningPreview(pendingPreview)
        self.pendingPreview = nil
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
