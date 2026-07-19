import AutoLedgerCore
import SwiftUI

@MainActor
enum PendingActionCenterLoader {
    static func revision(for store: LedgerStore) -> String {
        [
            String(store.visibleTransactions.count),
            String(store.visibleSubscriptions.count),
            String(store.hotelStayDrafts.count),
            String(store.merchantAliases.count),
            String(store.categoryCorrections.count),
            String(store.ignoredDataCleaningPreviewIDs.count),
            String(store.dataCleaningRevision),
            String(store.subscriptionAnomalyDecisionRevision),
            store.pendingReceiptReview?.id.uuidString ?? "none",
            store.lastImportSummary ?? ""
        ].joined(separator: "|")
    }

    static func load(from store: LedgerStore) async -> PendingActionCenterSnapshot {
        let transactions = store.visibleTransactions
        let subscriptions = store.visibleSubscriptions
        let merchantAliases = store.merchantAliases
        let categoryCorrections = store.categoryCorrections
        let ignoredPreviewIDs = store.ignoredDataCleaningPreviewIDs
        let handledSubscriptionAnomalyIDs = Set(store.subscriptionAnomalyDecisions.keys)
        let receiptReviewCount = store.pendingReceiptReview == nil ? 0 : 1
        let hotelReviewCount = store.hotelStayDrafts.filter {
            ![HotelStayDraftStatus.confirmed, .rejected, .postedToLedger].contains($0.status)
        }.count

        return await Task.detached(priority: .userInitiated) {
            let cleaningSnapshot = DataCleaningPreviewPlanner().buildSnapshot(
                transactions: transactions,
                merchantAliases: merchantAliases,
                categoryCorrections: categoryCorrections,
                ignoredPreviewIDs: ignoredPreviewIDs
            )
            let anomalySummary = SubscriptionAnomalyDetector().analyze(
                subscriptions: subscriptions,
                transactions: transactions
            ).filteringHandledAnomalies(withIDs: handledSubscriptionAnomalyIDs)
            return PendingActionCenterPlanner().buildSnapshot(
                receiptReviewCount: receiptReviewCount,
                hotelReviewCount: hotelReviewCount,
                cleaningSnapshot: cleaningSnapshot,
                subscriptionAnomalyCount: anomalySummary.anomalies.count
            )
        }.value
    }
}

struct PendingActionCenterCard: View {
    let snapshot: PendingActionCenterSnapshot
    let isRefreshing: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: snapshot.isEmpty ? "checkmark.circle.fill" : "tray.full.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(snapshot.isEmpty ? Color.green : AppTheme.accent)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill((snapshot.isEmpty ? Color.green : AppTheme.accent).opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("pending_center.title")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        Text(snapshot.isEmpty ? "pending_center.empty.subtitle" : "pending_center.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.mutedInk)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    if isRefreshing {
                        ProgressView()
                            .tint(AppTheme.accent)
                    } else if !snapshot.isEmpty {
                        Text("\(snapshot.totalCount)")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.white)
                            .frame(minWidth: 32, minHeight: 32)
                            .background(Circle().fill(AppTheme.accent))
                    }

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.mutedInk)
                }

                if !snapshot.groups.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(snapshot.groups.prefix(3))) { group in
                            PendingActionCompactPill(group: group)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .autoLedgerCardSurface(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(format: String(localized: "pending_center.accessibility_format"), snapshot.totalCount)))
    }
}

struct PendingActionCenterListView: View {
    let snapshot: PendingActionCenterSnapshot
    let isRefreshing: Bool
    let onSelect: (PendingActionCategory) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isRefreshing && snapshot.groups.isEmpty {
                    ProgressView("pending_center.loading")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if snapshot.isEmpty {
                    ContentUnavailableView(
                        "pending_center.empty.title",
                        systemImage: "checkmark.circle.fill",
                        description: Text("pending_center.empty.detail")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    Text(String(format: String(localized: "pending_center.total_format"), snapshot.totalCount))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)

                    ForEach(snapshot.groups) { group in
                        Button {
                            onSelect(group.category)
                        } label: {
                            PendingActionGroupRow(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .autoLedgerReadableContent(maxWidth: 760, alignment: .center)
        }
        .autoLedgerScreenChrome()
        .navigationTitle("pending_center.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct IPadPendingActionWorkspaceView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var snapshot = PendingActionCenterSnapshot()
    @State private var isRefreshing = false

    let openCapture: () -> Void
    let openHotelReview: () -> Void
    let openCleaning: () -> Void
    let openSubscriptions: () -> Void

    var body: some View {
        NavigationStack {
            PendingActionCenterListView(
                snapshot: snapshot,
                isRefreshing: isRefreshing,
                onSelect: open
            )
        }
        .task(id: PendingActionCenterLoader.revision(for: store)) {
            isRefreshing = true
            snapshot = await PendingActionCenterLoader.load(from: store)
            isRefreshing = false
        }
    }

    private func open(_ category: PendingActionCategory) {
        switch category {
        case .receiptReview:
            openCapture()
        case .hotelReview:
            openHotelReview()
        case .duplicateReview, .cleaningSuggestion:
            openCleaning()
        case .subscriptionAnomaly:
            openSubscriptions()
        }
    }
}

private struct PendingActionCompactPill: View {
    let group: PendingActionGroup

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: group.category.systemImage)
                .font(.caption2.weight(.bold))
            Text("\(group.count)")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(group.category.tint)
        .frame(maxWidth: .infinity, minHeight: 34)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(group.category.tint.opacity(0.10))
        )
        .accessibilityLabel(Text(group.category.titleKey))
        .accessibilityValue(Text("\(group.count)"))
    }
}

private struct PendingActionGroupRow: View {
    let group: PendingActionGroup

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: group.category.systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(group.category.tint)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(group.category.tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(group.category.titleKey)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    if group.isProAutomation {
                        Text("Pro")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
                    }
                }

                Text(group.category.subtitleKey)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text("\(group.count)")
                .font(.headline.weight(.heavy))
                .foregroundStyle(group.category.tint)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 18)
    }
}

private extension PendingActionCategory {
    var titleKey: LocalizedStringKey {
        switch self {
        case .receiptReview: return "pending_center.receipt.title"
        case .hotelReview: return "pending_center.hotel.title"
        case .duplicateReview: return "pending_center.duplicate.title"
        case .subscriptionAnomaly: return "pending_center.subscription.title"
        case .cleaningSuggestion: return "pending_center.cleaning.title"
        }
    }

    var subtitleKey: LocalizedStringKey {
        switch self {
        case .receiptReview: return "pending_center.receipt.subtitle"
        case .hotelReview: return "pending_center.hotel.subtitle"
        case .duplicateReview: return "pending_center.duplicate.subtitle"
        case .subscriptionAnomaly: return "pending_center.subscription.subtitle"
        case .cleaningSuggestion: return "pending_center.cleaning.subtitle"
        }
    }

    var systemImage: String {
        switch self {
        case .receiptReview: return "doc.text.magnifyingglass"
        case .hotelReview: return "bed.double.fill"
        case .duplicateReview: return "doc.on.doc.fill"
        case .subscriptionAnomaly: return "bell.badge.fill"
        case .cleaningSuggestion: return "wand.and.sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .receiptReview: return AppTheme.accent
        case .hotelReview: return AppTheme.accentSecondary
        case .duplicateReview: return Color(red: 0.82, green: 0.36, blue: 0.24)
        case .subscriptionAnomaly: return Color(red: 0.78, green: 0.52, blue: 0.08)
        case .cleaningSuggestion: return Color(red: 0.34, green: 0.39, blue: 0.78)
        }
    }
}
