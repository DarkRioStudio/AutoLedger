import AutoLedgerCore
import SwiftUI

@MainActor
enum PendingActionCenterLoader {
    static func revision(for store: LedgerStore) -> String {
        var components: [String] = []
        components.reserveCapacity(11)
        components.append(String(store.visibleTransactions.count))
        components.append(String(store.visibleSubscriptions.count))
        components.append(String(store.hotelStayDrafts.count))
        components.append(String(store.merchantAliases.count))
        components.append(String(store.categoryCorrections.count))
        components.append(String(store.ignoredDataCleaningPreviewIDs.count))
        components.append(String(store.dataCleaningRevision))
        components.append(String(store.subscriptionAnomalyDecisionRevision))
        components.append(String(store.pendingActionDecisionRevision))
        components.append(store.pendingReceiptReview?.id.uuidString ?? "none")
        components.append(store.lastImportSummary ?? "")
        return components.joined(separator: "|")
    }

    static func load(from store: LedgerStore) async -> PendingActionCenterSnapshot {
        let transactions = store.visibleTransactions
        let subscriptions = store.visibleSubscriptions
        let merchantAliases = store.merchantAliases
        let categoryCorrections = store.categoryCorrections
        let ignoredPreviewIDs = store.ignoredDataCleaningPreviewIDs
        let handledSubscriptionAnomalyIDs = Set(store.subscriptionAnomalyDecisions.keys)
        let pendingActionDecisions = store.pendingActionDecisions
        let receiptReviewSeed = store.pendingReceiptReview.map {
            (id: $0.id.uuidString, createdAt: $0.createdAt)
        }
        let hotelDrafts = store.hotelStayDrafts.filter {
            ![HotelStayDraftStatus.confirmed, .rejected, .postedToLedger].contains($0.status)
        }

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
            var items: [PendingActionItem] = []

            if let receiptReviewSeed,
               let item = try? PendingActionItem(
                   kind: .receiptConfirmation,
                   source: PendingActionSourceReference(
                       type: .receiptImportReview,
                       id: receiptReviewSeed.id
                   ),
                   reason: .receiptNeedsConfirmation,
                   createdAt: receiptReviewSeed.createdAt
               ) {
                items.append(item)
            }

            items.append(contentsOf: hotelDrafts.compactMap { draft in
                try? PendingActionItem(
                    kind: .hotelDraftReview,
                    source: PendingActionSourceReference(
                        type: .hotelStayDraft,
                        id: draft.id.uuidString,
                        revision: "\(draft.status.rawValue):\(Int(draft.updatedAt.timeIntervalSince1970))"
                    ),
                    reason: .hotelDraftNeedsReview,
                    createdAt: draft.createdAt,
                    updatedAt: draft.updatedAt
                )
            })

            let transactionDates = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0.occurredAt) })
            items.append(contentsOf: cleaningSnapshot.items.compactMap { preview in
                let kind: PendingActionKind = preview.kind == .duplicateCandidate
                    ? .duplicateCandidate
                    : .cleaningSuggestion
                let reason: PendingActionReasonCode
                switch preview.kind {
                case .duplicateCandidate:
                    reason = .suspectedDuplicate
                case .merchantAlias:
                    reason = .merchantNormalizationSuggested
                case .categoryCorrection:
                    reason = .categoryCorrectionSuggested
                }
                let evidenceDate = preview.affectedTransactionIDs
                    .compactMap { transactionDates[$0] }
                    .max() ?? Date(timeIntervalSince1970: 0)
                return try? PendingActionItem(
                    kind: kind,
                    source: PendingActionSourceReference(
                        type: .dataCleaningPreview,
                        id: PendingActionSourceReference.opaqueID(for: preview.id)
                    ),
                    reason: reason,
                    createdAt: evidenceDate
                )
            })

            items.append(contentsOf: anomalySummary.anomalies.compactMap { anomaly in
                let reason: PendingActionReasonCode
                switch anomaly.kind {
                case .priceIncrease:
                    reason = .subscriptionPriceIncrease
                case .duplicateCharge:
                    reason = .subscriptionDuplicateCharge
                case .billingCycleDrift:
                    reason = .subscriptionBillingCycleDrift
                }
                return try? PendingActionItem(
                    kind: .subscriptionAnomaly,
                    source: PendingActionSourceReference(
                        type: .subscriptionAnomaly,
                        id: anomaly.id
                    ),
                    reason: reason,
                    createdAt: anomaly.detectedAt
                )
            })

            let timestamp = Date()
            let resolvedItems = PendingActionDecisionOverlay.applying(
                pendingActionDecisions,
                to: items,
                at: timestamp
            )
            return PendingActionCenterPlanner().buildSnapshot(
                items: resolvedItems,
                at: timestamp
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
    let onOpen: (PendingActionItem) -> Void
    let onDecision: (PendingActionItem, PendingActionMutation) -> Void

    @State private var itemPendingDismissal: PendingActionItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isRefreshing && !snapshot.hasStoredItems {
                    ProgressView("pending_center.loading")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if !snapshot.hasStoredItems {
                    ContentUnavailableView(
                        "pending_center.empty.title",
                        systemImage: "checkmark.circle.fill",
                        description: Text("pending_center.empty.detail")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    if !snapshot.items.isEmpty {
                        PendingActionSectionHeader(
                            titleKey: "pending_center.section.review",
                            count: snapshot.items.count
                        )

                        Text(String(format: String(localized: "pending_center.total_format"), snapshot.totalCount))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.mutedInk)

                        ForEach(snapshot.items) { item in
                            PendingActionItemRow(
                                item: item,
                                presentation: .active,
                                onOpen: { onOpen(item) },
                                onDefer: { date in onDecision(item, .deferUntil(date)) },
                                onDismiss: { itemPendingDismissal = item },
                                onReopen: {}
                            )
                        }
                    }

                    if !snapshot.deferredItems.isEmpty {
                        PendingActionSectionHeader(
                            titleKey: "pending_center.section.later",
                            count: snapshot.deferredItems.count
                        )
                        .padding(.top, snapshot.items.isEmpty ? 0 : 12)

                        ForEach(snapshot.deferredItems) { item in
                            PendingActionItemRow(
                                item: item,
                                presentation: .deferred,
                                onOpen: { onOpen(item) },
                                onDefer: { _ in },
                                onDismiss: { itemPendingDismissal = item },
                                onReopen: { onDecision(item, .reopen) }
                            )
                        }
                    }

                    if !snapshot.handledItems.isEmpty {
                        PendingActionSectionHeader(
                            titleKey: "pending_center.section.handled",
                            count: snapshot.handledItems.count
                        )
                        .padding(.top, snapshot.items.isEmpty && snapshot.deferredItems.isEmpty ? 0 : 12)

                        ForEach(snapshot.handledItems) { item in
                            PendingActionItemRow(
                                item: item,
                                presentation: .handled,
                                onOpen: { onOpen(item) },
                                onDefer: { _ in },
                                onDismiss: {},
                                onReopen: { onDecision(item, .reopen) }
                            )
                        }
                    }
                }
            }
            .padding(20)
            .autoLedgerReadableContent(maxWidth: 760, alignment: .center)
        }
        .autoLedgerScreenChrome()
        .navigationTitle("pending_center.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "pending_action.ignore.confirm.title",
            isPresented: Binding(
                get: { itemPendingDismissal != nil },
                set: { isPresented in
                    if !isPresented { itemPendingDismissal = nil }
                }
            ),
            presenting: itemPendingDismissal
        ) { item in
            Button("pending_action.ignore", role: .destructive) {
                onDecision(item, .dismiss)
                itemPendingDismissal = nil
            }
            Button("common.cancel", role: .cancel) {
                itemPendingDismissal = nil
            }
        } message: { _ in
            Text("pending_action.ignore.confirm.message")
        }
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
                onOpen: open,
                onDecision: recordDecision
            )
        }
        .task(id: PendingActionCenterLoader.revision(for: store)) {
            isRefreshing = true
            snapshot = await PendingActionCenterLoader.load(from: store)
            isRefreshing = false
        }
    }

    private func open(_ item: PendingActionItem) {
        switch item.category {
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

    private func recordDecision(_ item: PendingActionItem, _ mutation: PendingActionMutation) {
        do {
            try store.recordPendingActionDecision(for: item, mutation: mutation)
        } catch {
            assertionFailure("Invalid pending action transition: \(error)")
        }
    }
}

private enum PendingActionItemPresentation {
    case active
    case deferred
    case handled
}

private struct PendingActionSectionHeader: View {
    let titleKey: LocalizedStringKey
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Text("\(count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.mutedInk)
        }
    }
}

private struct PendingActionItemRow: View {
    let item: PendingActionItem
    let presentation: PendingActionItemPresentation
    let onOpen: () -> Void
    let onDefer: (Date) -> Void
    let onDismiss: () -> Void
    let onReopen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.category.systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(item.category.tint)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(item.category.tint.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(item.category.titleKey)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        if item.isProAutomation {
                            Text("Pro")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
                        }
                    }

                    Text(LocalizedStringKey(item.reason.localizationKey))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            stateSummary

            HStack(spacing: 10) {
                Button("pending_action.open", action: onOpen)
                    .buttonStyle(.borderedProminent)

                Spacer(minLength: 0)

                switch presentation {
                case .active:
                    Menu("pending_action.defer") {
                        Button("pending_action.defer.tomorrow") {
                            onDefer(deferredDate(days: 1))
                        }
                        Button("pending_action.defer.week") {
                            onDefer(deferredDate(days: 7))
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("pending_action.ignore", role: .destructive, action: onDismiss)
                        .buttonStyle(.bordered)
                case .deferred:
                    Button("pending_action.ignore", role: .destructive, action: onDismiss)
                        .buttonStyle(.bordered)
                    Button("pending_action.reopen", action: onReopen)
                        .buttonStyle(.bordered)
                case .handled:
                    Button("pending_action.reopen", action: onReopen)
                        .buttonStyle(.bordered)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 18)
    }

    @ViewBuilder
    private var stateSummary: some View {
        switch presentation {
        case .active:
            EmptyView()
        case .deferred:
            if let deferredUntil = item.deferredUntil {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text("pending_action.state.deferred_until")
                    Text(deferredUntil, format: .dateTime.month(.abbreviated).day().hour().minute())
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }
        case .handled:
            Label(
                item.state == .dismissed
                    ? "pending_action.state.dismissed"
                    : "pending_action.state.resolved",
                systemImage: item.state == .dismissed ? "eye.slash" : "checkmark.circle"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.mutedInk)
        }
    }

    private func deferredDate(days: Int) -> Date {
        Calendar.autoupdatingCurrent.date(byAdding: .day, value: days, to: .now)
            ?? Date.now.addingTimeInterval(TimeInterval(days * 86_400))
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
