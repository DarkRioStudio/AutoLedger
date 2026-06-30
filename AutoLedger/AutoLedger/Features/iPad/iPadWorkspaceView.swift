import AutoLedgerCore
import Charts
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum IPadWorkspaceSection: String, CaseIterable, Identifiable, Hashable {
    case overview
    case capture
    case ledger
    case hotelStays
    case reports
    case reviewQueue
    case cleaning
    case settings

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .overview: return "ipad.workspace.overview"
        case .capture: return "ipad.workspace.capture"
        case .ledger: return "ipad.workspace.ledger"
        case .hotelStays: return "hotel_stay.list.title"
        case .reports: return "ipad.workspace.reports"
        case .reviewQueue: return "ipad.workspace.review_queue"
        case .cleaning: return "ipad.workspace.cleaning"
        case .settings: return "ipad.workspace.settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "rectangle.grid.2x2.fill"
        case .capture: return "tray.full.fill"
        case .ledger: return "list.bullet.rectangle"
        case .hotelStays: return "bed.double.fill"
        case .reports: return "chart.pie.fill"
        case .reviewQueue: return "checklist"
        case .cleaning: return "wand.and.sparkles"
        case .settings: return "gearshape.fill"
        }
    }

}

struct IPadWorkspaceView: View {
    @EnvironmentObject private var navigationState: AutoLedgerNavigationState
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    @State private var selection: IPadWorkspaceSection
    @State private var sidebarSelection: IPadWorkspaceSection?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var settingsResetID = UUID()
    @State private var detailResetID = UUID()

    init(initialSection: IPadWorkspaceSection = .overview) {
        _selection = State(initialValue: initialSection)
        _sidebarSelection = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $sidebarSelection) {
                ForEach(IPadWorkspaceSection.allCases) { section in
                    Button {
                        select(section)
                    } label: {
                        HStack(spacing: 12) {
                            Label(section.titleKey, systemImage: section.systemImage)
                            Spacer()
                            if selection == section {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selection == section ? AppTheme.accent : AppTheme.ink)
                    .listRowBackground(selection == section ? AppTheme.accent.opacity(0.10) : Color.clear)
                    .tag(section)
                }
            }
            .navigationTitle("ipad.workspace.title")
            .tint(AppTheme.accent)
        } detail: {
            detailView
                .id(detailResetID)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(AppTheme.accent)
        .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
        .onAppear {
            consumeQuickLedgerPendingNavigationIfNeeded()
        }
        .onChange(of: sidebarSelection) { _, newValue in
            guard let newValue else {
                sidebarSelection = selection
                return
            }
            select(newValue)
        }
        .onChange(of: navigationState.selectedHomeTab) { _, newValue in
            routeSharedHomeTab(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationService.quickLedgerOpenLedgerEvent)) { _ in
            consumeQuickLedgerPendingNavigationIfNeeded()
        }
        #if targetEnvironment(macCatalyst)
        .onReceive(NotificationCenter.default.publisher(for: AutoLedgerMacCommandCenter.didPerformCommand)) { _ in
            handleMacCommandRoutingIfNeeded()
        }
        #endif
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .overview:
            IPadWorkspaceOverviewView(
                openLedger: { select(.ledger) },
                openImport: { select(.capture) },
                openReviewQueue: { select(.reviewQueue) },
                openCleaning: { select(.cleaning) }
            )
        case .capture:
            IPadBatchImportWorkspaceView(
                initialFilter: .all,
                showsImportActions: true,
                openReviewQueue: { select(.reviewQueue) }
            )
        case .ledger:
            LedgerView {
                openLedgerProfilesFromSharedLedger()
            }
        case .hotelStays:
            HotelStayWorkspaceView()
        case .reports:
            IPadReportWorkspaceView()
        case .reviewQueue:
            IPadBatchImportWorkspaceView(
                initialFilter: .candidate,
                showsImportActions: false,
                openReviewQueue: { select(.reviewQueue) }
            )
        case .cleaning:
            IPadCleaningPreviewWorkspaceView()
        case .settings:
            SettingsView()
                .id(settingsResetID)
        }
    }

    private func select(_ section: IPadWorkspaceSection) {
        guard selection != section else { return }
        resetDetailColumn(leaving: selection)
        selection = section
        sidebarSelection = section
    }

    private func resetDetailColumn(leaving oldSection: IPadWorkspaceSection) {
        if oldSection == .settings {
            settingsResetID = UUID()
        }
        detailResetID = UUID()
    }

    private func openLedgerProfilesFromSharedLedger() {
        navigationState.settingsPath = [.ledgerProfiles]
        select(.settings)
    }

    private func routeSharedHomeTab(_ rawValue: Int) {
        guard let tab = AutoLedgerHomeTab(rawValue: rawValue) else { return }
        switch tab {
        case .inbox:
            select(.capture)
        case .ledger:
            select(.ledger)
        case .hotelStays:
            select(.hotelStays)
        case .report:
            select(.reports)
        case .settings:
            select(.settings)
        }
    }

    #if targetEnvironment(macCatalyst)
    @MainActor
    private func handleMacCommandRoutingIfNeeded() {
        guard let command = AutoLedgerMacCommandCenter.shared.pendingCommand else { return }
        switch command {
        case .openSettings:
            _ = AutoLedgerMacCommandCenter.shared.consume(command)
            select(.settings)
        case .importFiles, .importCSV, .exportCSV, .exportJSON:
            select(.capture)
        }
    }
    #endif

    @MainActor
    private func consumeQuickLedgerPendingNavigationIfNeeded() {
        guard QuickLedgerNavigationState.shared.consumeOpenLedgerPending() else { return }
        select(.ledger)
    }
}

private struct IPadWorkspaceOverviewView: View {
    @EnvironmentObject private var store: LedgerStore

    let openLedger: () -> Void
    let openImport: () -> Void
    let openReviewQueue: () -> Void
    let openCleaning: () -> Void

    private var snapshot: MonthlySnapshot {
        store.monthlySnapshot
    }

    private var recentTransactions: [Transaction] {
        store.visibleTransactions
            .sorted { $0.occurredAt > $1.occurredAt }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                        MetricCard(
                            title: String(localized: "ipad.workspace.metric.month"),
                            value: AppFormatters.currency(snapshot.totalExpense),
                            detail: String(format: String(localized: "report.transaction_count_format"), snapshot.transactionCount),
                            accent: AppTheme.accent
                        )

                        MetricCard(
                            title: String(localized: "ipad.workspace.metric.recent"),
                            value: "\(store.visibleTransactions.count)",
                            detail: String(localized: "ipad.workspace.metric.recent.detail"),
                            accent: AppTheme.accentSecondary
                        )

                        MetricCard(
                            title: String(localized: "ipad.workspace.metric.top_merchant"),
                            value: snapshot.topMerchant,
                            detail: String(localized: "report.top_merchants.title"),
                            accent: Color(red: 0.33, green: 0.35, blue: 0.78)
                        )
                    }

                    HStack(alignment: .top, spacing: 18) {
                        overviewPanel(titleKey: "ipad.workspace.recent_transactions") {
                            if recentTransactions.isEmpty {
                                emptyText("report.empty.month")
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(recentTransactions) { transaction in
                                        IPadTransactionCompactRow(transaction: transaction)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                openLedger()
                                            }

                                        if transaction.id != recentTransactions.last?.id {
                                            Divider()
                                                .padding(.leading, 44)
                                        }
                                    }
                                }
                            }
                        }

                        overviewPanel(titleKey: "ipad.workspace.next_steps") {
                            VStack(spacing: 12) {
                                workspaceAction(
                                    titleKey: "ipad.workspace.capture",
                                    detailKey: "ipad.workspace.next.import",
                                    systemImage: "tray.full.fill",
                                    action: openImport
                                )
                                workspaceAction(
                                    titleKey: "ipad.workspace.review_queue",
                                    detailKey: "ipad.workspace.next.review",
                                    systemImage: "checklist",
                                    action: openReviewQueue
                                )
                                workspaceAction(
                                    titleKey: "ipad.workspace.cleaning",
                                    detailKey: "ipad.workspace.next.cleaning",
                                    systemImage: "wand.and.sparkles",
                                    action: openCleaning
                                )
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("ipad.workspace.title")
        }
    }

    private func overviewPanel<Content: View>(
        titleKey: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(titleKey)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func workspaceAction(
        titleKey: LocalizedStringKey,
        detailKey: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(detailKey)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(12)
            .background(AppTheme.canvas.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func emptyText(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.subheadline)
            .foregroundStyle(AppTheme.mutedInk)
            .frame(maxWidth: .infinity, minHeight: 80)
    }
}

private enum IPadBatchImportFilter: String, CaseIterable, Identifiable {
    case all
    case rawInput
    case candidate
    case failed
    case duplicate

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: return "ipad.batch_import.filter.all"
        case .rawInput: return "ipad.batch_import.filter.raw"
        case .candidate: return "ipad.batch_import.filter.candidate"
        case .failed: return "ipad.batch_import.filter.failed"
        case .duplicate: return "ipad.batch_import.filter.duplicate"
        }
    }

    func matches(_ item: BatchImportQueueItem) -> Bool {
        switch self {
        case .all:
            return true
        case .rawInput:
            return item.state == .rawInput
        case .candidate:
            return item.state == .candidate
        case .failed:
            return item.failureReason != nil
        case .duplicate:
            return item.failureReason == .duplicateSuspected || item.warnings.contains(.duplicateSuspected)
        }
    }
}

private enum IPadBatchImportSheet: Identifiable {
    case camera
    case voice
    case pro

    var id: String {
        switch self {
        case .camera: return "camera"
        case .voice: return "voice"
        case .pro: return "pro"
        }
    }
}

private struct IPadBatchCandidateDraft: Equatable {
    var merchant: String
    var amountText: String
    var occurredAt: Date
    var category: TransactionCategory
    var source: ReceiptSource
    var note: String

    static let empty = IPadBatchCandidateDraft(
        merchant: "",
        amountText: "",
        occurredAt: .now,
        category: .other,
        source: .manual,
        note: ""
    )

    init(
        merchant: String,
        amountText: String,
        occurredAt: Date,
        category: TransactionCategory,
        source: ReceiptSource,
        note: String
    ) {
        self.merchant = merchant
        self.amountText = amountText
        self.occurredAt = occurredAt
        self.category = category
        self.source = source
        self.note = note
    }

    init(item: BatchImportQueueItem) {
        self.merchant = item.merchant ?? ""
        self.amountText = item.amount.map { String(format: "%.2f", $0) } ?? ""
        self.occurredAt = item.occurredAt ?? .now
        self.category = item.category.flatMap(TransactionCategory.init(rawValue:)) ?? .other
        self.source = item.source.flatMap(ReceiptSource.init(rawValue:)) ?? .manual
        self.note = item.note
    }

    var amount: Double? {
        let normalized = amountText
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized)
    }

    var isValid: Bool {
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (amount ?? 0) > 0
    }

    func transaction() -> Transaction? {
        guard isValid, let amount else { return nil }
        return Transaction(
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            occurredAt: occurredAt,
            category: category,
            source: source,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

private struct IPadCleaningPreviewWorkspaceView: View {
    @EnvironmentObject private var store: LedgerStore
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared
    @State private var selectedPreviewID: String?
    @State private var previewPendingApplication: DataCleaningPreviewItem?
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

    private var selectedPreview: DataCleaningPreviewItem? {
        if let selectedPreviewID,
           let preview = previews.first(where: { $0.id == selectedPreviewID }) {
            return preview
        }
        return previews.first
    }

    private var affectedTransactions: [Transaction] {
        guard let selectedPreview else { return [] }
        let ids = Set(selectedPreview.affectedTransactionIDs)
        return store.visibleTransactions
            .filter { ids.contains($0.id) }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if proEntitlement.canUse(.advancedDeduplication) {
                    HStack(spacing: 0) {
                        previewList
                            .frame(minWidth: 390, idealWidth: 460, maxWidth: 540)

                        Divider()

                        previewDetail
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    cleaningProGate
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("ipad.workspace.cleaning")
            .onAppear {
                if selectedPreviewID == nil {
                    selectedPreviewID = previews.first?.id
                }
            }
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
                    previewPendingApplication = nil
                }
            } message: {
                Text("ipad.cleaning.apply_confirm_message")
            }
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

    private var cleaningProGate: some View {
        VStack {
            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 18) {
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
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)

            Spacer(minLength: 24)
        }
        .padding(24)
    }

    private var previewList: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ipad.cleaning.title")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text("ipad.cleaning.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            summaryRow

            if previews.isEmpty {
                emptyPreview
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(DataCleaningPreviewKind.allCases, id: \.rawValue) { kind in
                            let kindItems = snapshot.items(kind: kind)
                            if !kindItems.isEmpty {
                                Text(kindTitle(kind))
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.ink)
                                    .padding(.top, 4)

                                ForEach(kindItems) { item in
                                    previewRow(item)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .padding(24)
        .background(AppTheme.canvas.opacity(0.45))
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
            Text(titleKey)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(tint)
                .frame(height: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var emptyPreview: some View {
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
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .padding(20)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func previewRow(_ item: DataCleaningPreviewItem) -> some View {
        Button {
            selectedPreviewID = item.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kindIcon(item.kind))
                    .font(.headline)
                    .foregroundStyle(kindTint(item.kind))
                    .frame(width: 38, height: 38)
                    .background(kindTint(item.kind).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text(previewSubtitle(item))
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineLimit(2)
                }

                Spacer()

                Text("\(item.affectedTransactionIDs.count)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .monospacedDigit()
            }
            .padding(12)
            .background(selectedPreview?.id == item.id ? kindTint(item.kind).opacity(0.12) : AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var previewDetail: some View {
        if let selectedPreview {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: kindIcon(selectedPreview.kind))
                            .font(.title2)
                            .foregroundStyle(kindTint(selectedPreview.kind))
                            .frame(width: 48, height: 48)
                            .background(kindTint(selectedPreview.kind).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(selectedPreview.title)
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                            Text(kindTitle(selectedPreview.kind))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(kindTint(selectedPreview.kind))
                        }
                        Spacer()
                    }

                    previewDetailCard(titleKey: "ipad.cleaning.preview") {
                        detailRow("ipad.cleaning.current", value: selectedPreview.currentValue)
                        detailRow("ipad.cleaning.proposed", value: selectedPreview.proposedValue)
                        detailRow("ipad.cleaning.affected_count", value: "\(selectedPreview.affectedTransactionIDs.count)")
                        if let score = selectedPreview.score {
                            detailRow("ipad.cleaning.score", value: String(format: "%.0f%%", score * 100))
                        }
                        detailRow("ipad.cleaning.reason", value: localizedReason(selectedPreview))
                    }

                    previewDetailCard(titleKey: "ipad.cleaning.affected_transactions") {
                        VStack(spacing: 0) {
                            ForEach(affectedTransactions) { transaction in
                                IPadTransactionCompactRow(transaction: transaction)
                                if transaction.id != affectedTransactions.last?.id {
                                    Divider()
                                        .padding(.leading, 44)
                                }
                            }
                        }
                    }

                    cleaningActions(for: selectedPreview)

                    if let result = store.lastDataCleaningApplicationResult {
                        applicationResultCard(result)
                    }
                }
                .padding(28)
            }
        } else {
            IPadPlanningWorkspaceView(
                titleKey: "ipad.cleaning.empty.title",
                subtitleKey: "ipad.cleaning.empty.subtitle",
                systemImage: "checkmark.seal.fill",
                items: [
                    "ipad.workspace.cleaning.item.merchant",
                    "ipad.workspace.cleaning.item.category",
                    "ipad.workspace.cleaning.item.duplicates"
                ]
            )
        }
    }

    private func previewDetailCard<Content: View>(
        titleKey: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleKey)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            content()
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func detailRow(_ titleKey: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 132, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func cleaningActions(for item: DataCleaningPreviewItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ipad.cleaning.apply_note", systemImage: "checkmark.shield")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)

            HStack(spacing: 12) {
                Button {
                    previewPendingApplication = item
                    showsApplyConfirmation = true
                } label: {
                    Label(applyButtonTitle(for: item.kind), systemImage: item.kind == .duplicateCandidate ? "trash" : "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(kindTint(item.kind))

                Button {
                    _ = store.undoLastDataCleaningApplication()
                    selectedPreviewID = previews.first?.id
                } label: {
                    Label("ipad.cleaning.undo_last", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.lastDataCleaningApplicationResult?.canUndo != true)
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func applicationResultCard(_ result: DataCleaningApplicationResult) -> some View {
        previewDetailCard(titleKey: "ipad.cleaning.result") {
            Text(String(
                format: String(localized: "ipad.cleaning.result_format"),
                result.updatedCount,
                result.deletedCount,
                result.skippedCount
            ))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
        }
    }

    private func applyPendingPreview() {
        guard let previewPendingApplication else { return }
        _ = store.applyDataCleaningPreview(previewPendingApplication)
        self.previewPendingApplication = nil
        selectedPreviewID = previews.first?.id
    }

    private func applyButtonTitle(for kind: DataCleaningPreviewKind) -> LocalizedStringKey {
        switch kind {
        case .merchantAlias, .categoryCorrection:
            return "ipad.cleaning.apply"
        case .duplicateCandidate:
            return "ipad.cleaning.apply_duplicate"
        }
    }

    private func previewSubtitle(_ item: DataCleaningPreviewItem) -> String {
        switch item.kind {
        case .merchantAlias, .categoryCorrection:
            return "\(item.currentValue) -> \(item.proposedValue)"
        case .duplicateCandidate:
            if let score = item.score {
                return String(format: String(localized: "ipad.cleaning.duplicate_score_format"), score * 100)
            }
            return String(localized: "ipad.cleaning.kind.duplicate")
        }
    }

    private func localizedReason(_ item: DataCleaningPreviewItem) -> String {
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

private struct IPadBatchImportWorkspaceView: View {
    @EnvironmentObject private var store: LedgerStore
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared
    @State private var filter: IPadBatchImportFilter
    @State private var selectedItemID: UUID?
    @State private var activeSheet: IPadBatchImportSheet?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImageData: Data?
    @State private var showsFileImporter = false
    @State private var showsCSVImporter = false
    @State private var showsJSONImporter = false
    @State private var showExportShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var pendingJSONImportURL: URL?
    @State private var showJSONRestoreConfirmation = false
    @State private var isImportingPhoto = false
    @State private var isImportingCamera = false
    @State private var isImportingClipboard = false
    @State private var isImportingFiles = false
    @State private var isDropTargeted = false
    @State private var queueSnapshot = BatchImportQueueSnapshot()
    @State private var isRecognizing = false
    @State private var recognitionLogs: [BatchImportRecognitionLog] = []
    @State private var lastRecognitionSummary: String?
    @State private var candidateDraft = IPadBatchCandidateDraft.empty
    @State private var draftItemID: UUID?

    private let showsImportActions: Bool
    private let ocrService = OCRService()

    private var showsMacDropImportTarget: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        false
        #endif
    }

    private var showsMacDataExchangeActions: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        false
        #endif
    }

    private var supportedDropTypeIdentifiers: [String] {
        [
            UTType.fileURL.identifier,
            UTType.image.identifier,
            UTType.pdf.identifier,
            UTType.text.identifier,
            UTType.plainText.identifier
        ]
    }

    private var canUseBatchCandidateImport: Bool {
        proEntitlement.canUse(.batchCandidateImport)
    }

    private var batchFileImportButtonTitleKey: LocalizedStringKey {
        if isImportingFiles {
            return "ipad.batch_import.importing_files"
        }
        return canUseBatchCandidateImport ? "ipad.batch_import.import_files" : "pro.cta.view_plans"
    }

    private var items: [BatchImportQueueItem] {
        queueSnapshot.items
            .filter(filter.matches)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var selectedItem: BatchImportQueueItem? {
        if let selectedItemID,
           let item = items.first(where: { $0.id == selectedItemID }) {
            return item
        }
        return items.first
    }

    private var titleKey: LocalizedStringKey {
        showsImportActions ? "ipad.import.title" : "ipad.import.batch.title"
    }

    private var subtitleKey: LocalizedStringKey {
        showsImportActions ? "ipad.import.subtitle" : "ipad.batch_import.subtitle"
    }

    private let openReviewQueue: () -> Void

    init(initialFilter: IPadBatchImportFilter, showsImportActions: Bool, openReviewQueue: @escaping () -> Void) {
        self._filter = State(initialValue: initialFilter)
        self.showsImportActions = showsImportActions
        self.openReviewQueue = openReviewQueue
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                header
                if showsImportActions {
                    importActions
                    if showsMacDataExchangeActions {
                        macDataExchangeActions
                    }
                    if showsMacDropImportTarget {
                        dropImportTarget
                    }
                } else {
                    if showsMacDropImportTarget {
                        dropImportTarget
                    }
                    if !canUseBatchCandidateImport {
                        batchProGateBanner
                    }
                    filterBar

                    HStack(alignment: .top, spacing: 18) {
                        queueList
                            .frame(minWidth: 360, idealWidth: 460, maxWidth: 520)

                        detailPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .camera:
                    CameraPicker(imageData: $capturedImageData)
                case .voice:
                    VoiceLedgerConfirmView()
                case .pro:
                    NavigationStack {
                        AutoLedgerProView()
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("common.close") {
                                        activeSheet = nil
                                    }
                                }
                            }
                    }
                }
            }
            .fileImporter(
                isPresented: $showsFileImporter,
                allowedContentTypes: [.image, .pdf, .text, .plainText],
                allowsMultipleSelection: true
            ) { result in
                Task {
                    await importSelectedFiles(result)
                }
            }
            .fileImporter(
                isPresented: $showsCSVImporter,
                allowedContentTypes: [.commaSeparatedText, .text, .plainText],
                allowsMultipleSelection: false
            ) { result in
                importSelectedCSV(result)
            }
            .fileImporter(
                isPresented: $showsJSONImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    pendingJSONImportURL = urls.first
                    showJSONRestoreConfirmation = pendingJSONImportURL != nil
                case let .failure(error):
                    lastRecognitionSummary = String(
                        format: String(localized: "mac.data_exchange.file_selection_failed_format"),
                        error.localizedDescription
                    )
                }
            }
            .confirmationDialog(
                "mac.data_exchange.json_restore.confirm_title",
                isPresented: $showJSONRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button("mac.data_exchange.json_restore.confirm_action", role: .destructive) {
                    importPendingJSONBackup()
                }
                Button("common.cancel", role: .cancel) {
                    pendingJSONImportURL = nil
                }
            } message: {
                Text("mac.data_exchange.json_restore.confirm_message")
            }
            .sheet(isPresented: $showExportShareSheet) {
                if let exportedFileURL {
                    ActivityShareSheet(activityItems: [exportedFileURL])
                }
            }
            .onAppear {
                selectedItemID = selectedItem?.id
                syncCandidateDraft()
                handleMacBatchCommandIfNeeded()
            }
            .task {
                await proEntitlement.loadProducts()
                await proEntitlement.refreshEntitlements()
            }
            .onChange(of: filter) { _, _ in
                selectedItemID = items.first?.id
                syncCandidateDraft()
            }
            .onChange(of: selectedItemID) { _, _ in
                syncCandidateDraft()
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto else { return }
                await importPickedPhoto(selectedPhoto)
            }
            .task(id: capturedImageData) {
                guard let data = capturedImageData else { return }
                capturedImageData = nil
                await importCapturedPhoto(data)
            }
            #if targetEnvironment(macCatalyst)
            .onReceive(NotificationCenter.default.publisher(for: AutoLedgerMacCommandCenter.didPerformCommand)) { _ in
                handleMacBatchCommandIfNeeded()
            }
            #endif
        }
    }

    @MainActor
    private func handleMacBatchCommandIfNeeded() {
        #if targetEnvironment(macCatalyst)
        guard let command = AutoLedgerMacCommandCenter.shared.pendingCommand else { return }
        switch command {
        case .importFiles:
            _ = AutoLedgerMacCommandCenter.shared.consume(command)
            requestBatchFileImport()
        case .importCSV:
            _ = AutoLedgerMacCommandCenter.shared.consume(command)
            showsCSVImporter = true
        case .exportCSV:
            _ = AutoLedgerMacCommandCenter.shared.consume(command)
            exportCSV()
        case .exportJSON:
            _ = AutoLedgerMacCommandCenter.shared.consume(command)
            exportJSONBackup()
        case .openSettings:
            break
        }
        #endif
    }

    private var dropImportTarget: some View {
        VStack(alignment: .center, spacing: 10) {
            Label {
                Text(isImportingFiles ? "ipad.batch_import.importing_files" : "mac.import.drop.title")
                    .font(.headline.weight(.semibold))
            } icon: {
                if isImportingFiles {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.doc.fill")
                }
            }

            Text("mac.import.drop.subtitle")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(isDropTargeted ? AppTheme.accent : AppTheme.ink)
        .frame(maxWidth: .infinity, minHeight: 86)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDropTargeted ? AppTheme.accent.opacity(0.12) : AppTheme.card.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isDropTargeted ? AppTheme.accent : AppTheme.mutedInk.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                )
        )
        .contentShape(Rectangle())
        .onDrop(of: supportedDropTypeIdentifiers, isTargeted: $isDropTargeted) { providers in
            guard !providers.isEmpty else { return false }
            guard canUseBatchCandidateImport else {
                presentBatchProGate()
                return false
            }
            Task {
                await importDroppedProviders(providers)
            }
            return true
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(titleKey)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text(subtitleKey)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            if !showsImportActions {
                HStack(spacing: 12) {
                    Button {
                        requestBatchFileImport()
                    } label: {
                        if isImportingFiles {
                            ProgressView()
                        } else {
                            Label(
                                batchFileImportButtonTitleKey,
                                systemImage: canUseBatchCandidateImport ? "folder.badge.plus" : "sparkles"
                            )
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accentSecondary)
                    .disabled(isImportingFiles)

                    Button {
                        requestBatchRecognition()
                    } label: {
                        if isRecognizing {
                            ProgressView()
                        } else {
                            Label("ipad.batch_import.run_recognition", systemImage: "text.viewfinder")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .disabled(isRecognizing || queueSnapshot.items.allSatisfy { $0.state != .rawInput })
                }
            }
        }
    }

    private var importActions: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
            importActionCard(
                titleKey: "ipad.import.payment.title",
                subtitleKey: "ipad.import.payment.subtitle",
                systemImage: "doc.text.viewfinder",
                tint: AppTheme.accent
            ) {
                VStack(spacing: 10) {
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        preferredItemEncoding: .automatic
                    ) {
                        importActionButtonLabel(
                            titleKey: isImportingPhoto ? "inbox.import.processing" : "inbox.import.photo",
                            systemImage: "photo.on.rectangle",
                            isLoading: isImportingPhoto
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)

                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            activeSheet = .camera
                        } label: {
                            importActionButtonLabel(
                                titleKey: isImportingCamera ? "inbox.import.processing" : "inbox.import.camera",
                                systemImage: "camera.fill",
                                isLoading: isImportingCamera
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.accent)
                    }

                    Button {
                        Task { await importFromClipboard() }
                    } label: {
                        importActionButtonLabel(
                            titleKey: isImportingClipboard ? "inbox.import.processing" : "inbox.import.clipboard",
                            systemImage: "doc.on.clipboard",
                            isLoading: isImportingClipboard
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accentSecondary)

                    if let summary = store.lastImportSummary {
                        Label(summary, systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            importActionCard(
                titleKey: "ipad.import.voice.title",
                subtitleKey: "ipad.import.voice.subtitle",
                systemImage: "waveform",
                tint: AppTheme.accentSecondary
            ) {
                Button {
                    activeSheet = .voice
                } label: {
                    importActionButtonLabel(
                        titleKey: "voice_ledger_title",
                        systemImage: "waveform.circle.fill",
                        isLoading: false
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentSecondary)
            }

            importActionCard(
                titleKey: "ipad.import.batch.title",
                subtitleKey: "ipad.import.batch.subtitle",
                systemImage: "square.stack.3d.up.fill",
                tint: Color(red: 0.33, green: 0.35, blue: 0.78)
            ) {
                VStack(spacing: 10) {
                    compactQueueSummary

                    if !canUseBatchCandidateImport {
                        batchProInlineNote
                    }

                    Button {
                        requestBatchFileImport()
                    } label: {
                        importActionButtonLabel(
                            titleKey: batchFileImportButtonTitleKey,
                            systemImage: canUseBatchCandidateImport ? "folder.badge.plus" : "sparkles",
                            isLoading: isImportingFiles
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(Color(red: 0.33, green: 0.35, blue: 0.78))
                    .disabled(isImportingFiles)

                    Button {
                        openReviewQueue()
                    } label: {
                        importActionButtonLabel(
                            titleKey: "ipad.batch_import.show_queue",
                            systemImage: "checklist",
                            isLoading: false
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.33, green: 0.35, blue: 0.78))
                }
            }
        }
    }

    private var batchProGateBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(red: 0.33, green: 0.35, blue: 0.78))
                .frame(width: 42, height: 42)
                .background(Color(red: 0.33, green: 0.35, blue: 0.78).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("ipad.batch_import.pro.title")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text("ipad.batch_import.pro.free_note")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button {
                presentBatchProGate()
            } label: {
                Label("pro.cta.view_plans", systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.33, green: 0.35, blue: 0.78))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var batchProInlineNote: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text("ipad.batch_import.pro.title")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text("ipad.batch_import.pro.body")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: "sparkles")
                .foregroundStyle(Color(red: 0.33, green: 0.35, blue: 0.78))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var macDataExchangeActions: some View {
        HStack(alignment: .top, spacing: 14) {
            dataExchangeCard(
                titleKey: "mac.data_exchange.csv.title",
                subtitleKey: "mac.data_exchange.csv.subtitle",
                systemImage: "tablecells",
                tint: AppTheme.accent
            ) {
                HStack(spacing: 10) {
                    Button {
                        exportCSV()
                    } label: {
                        importActionButtonLabel(
                            titleKey: "mac.data_exchange.export_csv",
                            systemImage: "square.and.arrow.up",
                            isLoading: false
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)

                    Button {
                        showsCSVImporter = true
                    } label: {
                        importActionButtonLabel(
                            titleKey: "mac.data_exchange.import_csv",
                            systemImage: "square.and.arrow.down",
                            isLoading: false
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
                }
            }

            dataExchangeCard(
                titleKey: "mac.data_exchange.json.title",
                subtitleKey: "mac.data_exchange.json.subtitle",
                systemImage: "doc.zipper",
                tint: Color(red: 0.33, green: 0.35, blue: 0.78)
            ) {
                HStack(spacing: 10) {
                    Button {
                        exportJSONBackup()
                    } label: {
                        importActionButtonLabel(
                            titleKey: "mac.data_exchange.export_json",
                            systemImage: "square.and.arrow.up",
                            isLoading: false
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.33, green: 0.35, blue: 0.78))

                    Button {
                        showsJSONImporter = true
                    } label: {
                        importActionButtonLabel(
                            titleKey: "mac.data_exchange.import_json",
                            systemImage: "arrow.down.doc.fill",
                            isLoading: false
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(Color(red: 0.33, green: 0.35, blue: 0.78))
                }
            }
        }
    }

    private func dataExchangeCard<Content: View>(
        titleKey: LocalizedStringKey,
        subtitleKey: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(subtitleKey)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.card.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var compactQueueSummary: some View {
        HStack(spacing: 10) {
            queueSummaryValue("ipad.batch_import.summary.total", value: queueSnapshot.items.count)
            queueSummaryValue("ipad.batch_import.summary.candidates", value: queueSnapshot.items(in: .candidate).count)
            queueSummaryValue("ipad.batch_import.summary.failed", value: queueSnapshot.items.filter { $0.failureReason != nil }.count)
        }
        .frame(maxWidth: .infinity)
    }

    private func queueSummaryValue(_ titleKey: LocalizedStringKey, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text(titleKey)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func importActionCard<Content: View>(
        titleKey: LocalizedStringKey,
        subtitleKey: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(titleKey)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(subtitleKey)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 216, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func importActionButtonLabel(
        titleKey: LocalizedStringKey,
        systemImage: String,
        isLoading: Bool
    ) -> some View {
        HStack {
            if isLoading {
                ProgressView()
            } else {
                Image(systemName: systemImage)
            }
            Text(titleKey)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("ipad.batch_import.filter", selection: $filter) {
                ForEach(IPadBatchImportFilter.allCases) { option in
                    Text(option.titleKey)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                summaryPill("ipad.batch_import.summary.total", value: "\(queueSnapshot.items.count)", tint: AppTheme.accent)
                summaryPill("ipad.batch_import.summary.candidates", value: "\(queueSnapshot.items(in: .candidate).count)", tint: AppTheme.accentSecondary)
                summaryPill("ipad.batch_import.summary.failed", value: "\(queueSnapshot.items.filter { $0.failureReason != nil }.count)", tint: Color(red: 0.82, green: 0.28, blue: 0.22))
                summaryPill("ipad.batch_import.summary.official", value: "\(queueSnapshot.officialTransactionIDs.count)", tint: Color(red: 0.33, green: 0.35, blue: 0.78))
            }

            if let lastRecognitionSummary {
                Label(lastRecognitionSummary, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private func summaryPill(_ titleKey: LocalizedStringKey, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(titleKey)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var queueList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ipad.batch_import.queue")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            if items.isEmpty {
                Text("ipad.batch_import.empty")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            queueRow(item)
                        }
                    }
                }
            }
        }
    }

    private func queueRow(_ item: BatchImportQueueItem) -> some View {
        Button {
            selectedItemID = item.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconName(for: item))
                    .font(.headline)
                    .foregroundStyle(color(for: item))
                    .frame(width: 36, height: 36)
                    .background(color(for: item).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.merchant ?? itemTitleFallback(for: item))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(stateTitle(for: item.state))
                        Text("·")
                        Text(item.amount.map(AppFormatters.currency) ?? String(localized: "common.none"))
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                if item.needsReview {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color(red: 0.82, green: 0.28, blue: 0.22))
                }
            }
            .padding(12)
            .background(selectedItem?.id == item.id ? AppTheme.accent.opacity(0.12) : AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let item = selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: iconName(for: item))
                            .font(.title2)
                            .foregroundStyle(color(for: item))
                            .frame(width: 48, height: 48)
                            .background(color(for: item).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.merchant ?? itemTitleFallback(for: item))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                            Text(stateTitle(for: item.state))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.mutedInk)
                        }

                        Spacer()
                    }

                    candidateFields(for: item)

                    detailCard(titleKey: "ipad.batch_import.detail.status") {
                        detailRow("ipad.batch_import.detail.confidence", value: confidenceText(item.confidence))
                        detailRow("ipad.batch_import.detail.failure", value: item.failureReason.map(failureTitle) ?? String(localized: "common.none"))
                        detailRow("ipad.batch_import.detail.warnings", value: warningSummary(item.warnings))
                        recognitionLogCard(for: item)
                    }

                    if item.failureReason == .duplicateSuspected {
                        detailCard(titleKey: "ipad.batch_import.detail.duplicate") {
                            detailRow("ipad.batch_import.detail.duplicate_score", value: String(format: "%.0f%%", (item.duplicateScore ?? 0) * 100))
                            detailRow("ipad.batch_import.detail.duplicate_reason", value: item.duplicateReason ?? String(localized: "common.none"))
                        }
                    }

                    HStack(spacing: 12) {
                        if canSaveCandidate(item) {
                            Button {
                                saveCandidate(item)
                            } label: {
                                Label("ipad.batch_import.confirm_save", systemImage: "tray.and.arrow.down.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                            .disabled(!candidateDraft.isValid)
                        }

                        if item.canRetry {
                            Button {
                                retry(item)
                            } label: {
                                Label("ipad.batch_import.retry", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                        }

                        if item.state == .candidate || item.state == .reviewed || item.failureReason != nil {
                            Button(role: .destructive) {
                                rejectCandidate(item)
                            } label: {
                                Label("ipad.batch_import.reject", systemImage: "xmark.circle")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(18)
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            IPadPlanningWorkspaceView(
                titleKey: "ipad.batch_import.empty",
                subtitleKey: "ipad.workspace.review_queue.placeholder",
                systemImage: "tray.full.fill",
                items: [
                    "ipad.workspace.review_queue.item.raw_input",
                    "ipad.workspace.review_queue.item.candidate",
                    "ipad.workspace.review_queue.item.reviewed"
                ]
            )
        }
    }

    @ViewBuilder
    private func candidateFields(for item: BatchImportQueueItem) -> some View {
        if canSaveCandidate(item) {
            detailCard(titleKey: "ipad.batch_import.detail.fields") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("transaction_editor.merchant", text: $candidateDraft.merchant)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        TextField("transaction_editor.amount", text: $candidateDraft.amountText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        DatePicker(
                            "transaction_editor.date",
                            selection: $candidateDraft.occurredAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    HStack(spacing: 12) {
                        Picker("transaction_editor.category", selection: $candidateDraft.category) {
                            ForEach(TransactionCategory.allCases) { category in
                                Text(category.title).tag(category)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("transaction_editor.source", selection: $candidateDraft.source) {
                            ForEach(ReceiptSource.allCases) { source in
                                Text(source.title).tag(source)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    TextField("transaction_editor.note", text: $candidateDraft.note, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)

                    if !candidateDraft.isValid {
                        Label("ipad.batch_import.validation.required", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.82, green: 0.28, blue: 0.22))
                    }
                }
            }
        } else {
            detailCard(titleKey: "ipad.batch_import.detail.fields") {
                detailRow("transaction_editor.merchant", value: item.merchant ?? String(localized: "common.none"))
                detailRow("transaction_editor.amount", value: item.amount.map(AppFormatters.currency) ?? String(localized: "common.none"))
                detailRow("transaction_editor.category", value: item.category ?? String(localized: "common.none"))
                detailRow("transaction_editor.source", value: item.source ?? String(localized: "common.none"))
                detailRow("transaction_editor.date", value: item.occurredAt.map(AppFormatters.exportDateTime) ?? String(localized: "common.none"))
            }
        }
    }

    @ViewBuilder
    private func recognitionLogCard(for item: BatchImportQueueItem) -> some View {
        let itemLogs = recognitionLogs
            .filter { $0.itemID == item.id }
            .suffix(3)
        if !itemLogs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("ipad.batch_import.detail.logs")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                ForEach(Array(itemLogs.enumerated()), id: \.offset) { _, log in
                    Label(log.message, systemImage: "terminal")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }
        }
    }

    private func requestBatchFileImport() {
        guard canUseBatchCandidateImport else {
            presentBatchProGate()
            return
        }
        showsFileImporter = true
    }

    private func requestBatchRecognition() {
        guard canUseBatchCandidateImport else {
            presentBatchProGate()
            return
        }
        recognizeQueuedItems()
    }

    private func presentBatchProGate() {
        lastRecognitionSummary = String(localized: "ipad.batch_import.pro.required_summary")
        activeSheet = .pro
    }

    private func recognizeQueuedItems() {
        runRecognition(itemIDs: nil)
    }

    private func retry(_ item: BatchImportQueueItem) {
        guard canUseBatchCandidateImport else {
            presentBatchProGate()
            return
        }
        updateQueueItem(item.retryRequested())
        runRecognition(itemIDs: [item.id])
    }

    private func canSaveCandidate(_ item: BatchImportQueueItem) -> Bool {
        item.state == .candidate || item.state == .reviewed
    }

    private func saveCandidate(_ item: BatchImportQueueItem) {
        guard canSaveCandidate(item),
              let transaction = candidateDraft.transaction() else { return }
        store.addTransaction(transaction)
        updateQueueItem(item.converted(transactionID: transaction.id))
        selectedItemID = item.id
        syncCandidateDraft(force: true)
        lastRecognitionSummary = String(localized: "ipad.batch_import.save_summary")
    }

    private func rejectCandidate(_ item: BatchImportQueueItem) {
        updateQueueItem(item.markedFailed(reason: .userRejected))
        selectedItemID = item.id
        syncCandidateDraft(force: true)
        lastRecognitionSummary = String(localized: "ipad.batch_import.reject_summary")
    }

    private func runRecognition(itemIDs: Set<UUID>?) {
        guard canUseBatchCandidateImport else {
            presentBatchProGate()
            return
        }
        guard !isRecognizing else { return }
        isRecognizing = true
        let executor = BatchImportRecognitionExecutor()
        let result = executor.process(snapshot: queueSnapshot, itemIDs: itemIDs)
        queueSnapshot = result.snapshot
        recognitionLogs = (result.logs + recognitionLogs).prefix(12).map { $0 }
        lastRecognitionSummary = String(
            format: String(localized: "ipad.batch_import.recognition_summary"),
            result.processedCount,
            result.candidateCount,
            result.failedCount
        )
        if selectedItemID == nil || !items.contains(where: { $0.id == selectedItemID }) {
            selectedItemID = items.first?.id
        }
        syncCandidateDraft(force: true)
        isRecognizing = false
    }

    private func updateQueueItem(_ item: BatchImportQueueItem) {
        guard let index = queueSnapshot.items.firstIndex(where: { $0.id == item.id }) else { return }
        queueSnapshot.items[index] = item
    }

    private func appendBatchRawInputs(_ rawInputs: [BatchRawInput], failedReasons: [UUID: BatchImportFailureReason] = [:]) {
        guard !rawInputs.isEmpty else { return }
        let now = Date()
        let batchID = rawInputs.first?.batchID ?? UUID()
        let batch = BatchImportBatch(
            id: batchID,
            sourceKind: .files,
            status: failedReasons.count == rawInputs.count ? .failed : .pending,
            itemCount: rawInputs.count,
            createdAt: now,
            updatedAt: now
        )
        let importedItems = rawInputs.map { rawInput -> BatchImportQueueItem in
            let item = BatchImportQueueItem.rawInput(rawInput: rawInput, createdAt: now)
            guard let reason = failedReasons[rawInput.id] else { return item }
            return item.markedFailed(reason: reason, now: now)
        }

        var baseSnapshot = queueSnapshot
        baseSnapshot.batches.insert(batch, at: 0)
        baseSnapshot.rawInputs = rawInputs + baseSnapshot.rawInputs
        baseSnapshot.items = importedItems + baseSnapshot.items
        queueSnapshot = baseSnapshot
        selectedItemID = importedItems.first?.id
        filter = .all
        syncCandidateDraft(force: true)
    }

    private func syncCandidateDraft(force: Bool = false) {
        guard let item = selectedItem else {
            candidateDraft = .empty
            draftItemID = nil
            return
        }
        guard force || draftItemID != item.id else { return }
        candidateDraft = IPadBatchCandidateDraft(item: item)
        draftItemID = item.id
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

    private func importFromClipboard() async {
        isImportingClipboard = true
        store.prepareForLiveImport()
        defer { isImportingClipboard = false }

        guard let image = UIPasteboard.general.image,
              let data = image.pngData() else {
            store.setImportError(String(localized: "inbox.clipboard.empty"), imageSource: .clipboard)
            return
        }

        do {
            let text = try ocrService.recognizeText(from: data)
            store.importRecognizedText(text, imageSource: .clipboard)
        } catch {
            store.setImportError(error.localizedDescription, imageSource: .clipboard)
        }
    }

    private func exportCSV() {
        do {
            exportedFileURL = try store.writeCSVExportFile()
            lastRecognitionSummary = String(
                format: String(localized: "mac.data_exchange.csv_exported_summary"),
                store.transactions.count
            )
            showExportShareSheet = true
        } catch {
            lastRecognitionSummary = String(
                format: String(localized: "mac.data_exchange.export_failed_format"),
                error.localizedDescription
            )
        }
    }

    private func exportJSONBackup() {
        do {
            exportedFileURL = try store.writeManualBackupFile()
            lastRecognitionSummary = store.lastBackupSummary
            showExportShareSheet = true
        } catch {
            lastRecognitionSummary = String(
                format: String(localized: "mac.data_exchange.export_failed_format"),
                error.localizedDescription
            )
        }
    }

    private func importSelectedCSV(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            let importResult = try LedgerCSVCodec.decode(data: data)
            appendCSVImportResult(importResult, fileName: url.lastPathComponent)
            lastRecognitionSummary = String(
                format: String(localized: "mac.data_exchange.csv_imported_summary"),
                importResult.rows.count,
                importResult.validCount,
                importResult.failedCount
            )
        } catch {
            lastRecognitionSummary = String(
                format: String(localized: "mac.data_exchange.import_failed_format"),
                error.localizedDescription
            )
        }
    }

    private func importPendingJSONBackup() {
        guard let pendingJSONImportURL else { return }
        do {
            try store.importBackup(from: pendingJSONImportURL)
            lastRecognitionSummary = store.lastImportSummary ?? String(localized: "mac.data_exchange.json_restore_success")
        } catch {
            lastRecognitionSummary = String(
                format: String(localized: "mac.data_exchange.import_failed_format"),
                error.localizedDescription
            )
        }
        self.pendingJSONImportURL = nil
    }

    private func appendCSVImportResult(_ result: LedgerCSVImportResult, fileName: String) {
        guard !result.rows.isEmpty else { return }
        let now = Date()
        let batchID = UUID()
        var rawInputs: [BatchRawInput] = []
        var importedItems: [BatchImportQueueItem] = []

        for row in result.rows {
            let rawInput = BatchRawInput(
                batchID: batchID,
                sourceKind: .files,
                originalFileName: "\(fileName):\(row.lineNumber)",
                originalUTType: UTType.commaSeparatedText.identifier,
                inputHash: "csv-\(batchID.uuidString)-\(row.lineNumber)",
                fileRef: fileName,
                rawText: row.rawText,
                createdAt: now,
                updatedAt: now
            )
            rawInputs.append(rawInput)

            let item: BatchImportQueueItem
            if let transaction = row.transaction {
                item = BatchImportQueueItem(
                    rawInputID: rawInput.id,
                    batchID: batchID,
                    state: .candidate,
                    merchant: transaction.merchant,
                    amount: transaction.amount,
                    occurredAt: transaction.occurredAt,
                    category: transaction.category,
                    source: transaction.source,
                    note: transaction.note,
                    confidence: 0.95,
                    needsReview: true,
                    createdAt: now,
                    updatedAt: now
                )
            } else {
                item = BatchImportQueueItem(
                    rawInputID: rawInput.id,
                    batchID: batchID,
                    state: .candidate,
                    note: row.rawText,
                    confidence: 0.15,
                    needsReview: true,
                    warnings: warning(for: row.failureReason).map { [$0] } ?? [],
                    failureReason: row.failureReason ?? .parseFailed,
                    createdAt: now,
                    updatedAt: now
                )
            }
            importedItems.append(item)
        }

        let batch = BatchImportBatch(
            id: batchID,
            sourceKind: .files,
            status: result.validCount == 0 ? .failed : .pending,
            itemCount: result.rows.count,
            createdAt: now,
            updatedAt: now
        )

        var baseSnapshot = queueSnapshot
        baseSnapshot.batches.insert(batch, at: 0)
        baseSnapshot.rawInputs = rawInputs + baseSnapshot.rawInputs
        baseSnapshot.items = importedItems + baseSnapshot.items
        queueSnapshot = baseSnapshot
        selectedItemID = importedItems.first?.id
        filter = .all
        syncCandidateDraft(force: true)
    }

    private func warning(for reason: BatchImportFailureReason?) -> BatchImportWarning? {
        switch reason {
        case .emptyInput:
            return .emptyOCRText
        case .missingAmount:
            return .missingAmount
        case .missingMerchant:
            return .missingMerchant
        case .missingDate:
            return .missingDate
        case .lowConfidence:
            return .lowConfidence
        case .duplicateSuspected:
            return .duplicateSuspected
        case .unsupportedFileType:
            return .unsupportedFileType
        case .parseFailed:
            return .parseFailed
        case .nonBillImage, .ocrFailed, .multipleReceipts, .userRejected, .permissionDenied, .none:
            return nil
        }
    }

    private func importSelectedFiles(_ result: Result<[URL], Error>) async {
        guard canUseBatchCandidateImport else {
            presentBatchProGate()
            return
        }
        isImportingFiles = true
        defer { isImportingFiles = false }

        do {
            let urls = try result.get()
            await importFileURLs(urls, successSummaryKey: "ipad.batch_import.files_imported_summary")
        } catch {
            lastRecognitionSummary = String(
                format: String(localized: "ipad.batch_import.files_failed_format"),
                error.localizedDescription
            )
        }
    }

    private func importDroppedProviders(_ providers: [NSItemProvider]) async {
        guard canUseBatchCandidateImport else {
            presentBatchProGate()
            return
        }
        guard !isImportingFiles else { return }
        isImportingFiles = true
        defer { isImportingFiles = false }

        var urls: [URL] = []
        for provider in providers {
            if let url = await loadDroppedFileURL(from: provider) {
                urls.append(url)
            }
        }

        guard !urls.isEmpty else {
            lastRecognitionSummary = String(localized: "mac.import.drop.no_files")
            return
        }

        await importFileURLs(urls, successSummaryKey: "mac.import.drop.imported_summary")
    }

    private func importFileURLs(_ urls: [URL], successSummaryKey: String) async {
        guard canUseBatchCandidateImport else {
            presentBatchProGate()
            return
        }
        guard !urls.isEmpty else { return }

        let batchID = UUID()
        var rawInputs: [BatchRawInput] = []
        var failedReasons: [UUID: BatchImportFailureReason] = [:]

        for url in urls {
            let imported = await importFileAsRawInput(url, batchID: batchID)
            rawInputs.append(imported.rawInput)
            if let failureReason = imported.failureReason {
                failedReasons[imported.rawInput.id] = failureReason
            }
        }

        appendBatchRawInputs(rawInputs, failedReasons: failedReasons)
        lastRecognitionSummary = String(
            format: String(localized: String.LocalizationValue(successSummaryKey)),
            rawInputs.count
        )
    }

    private func loadDroppedFileURL(from provider: NSItemProvider) async -> URL? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                continuation.resume(returning: Self.fileURL(from: item))
            }
        }
    }

    private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let url = item as? NSURL {
            return url as URL
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        return nil
    }

    private func importFileAsRawInput(
        _ url: URL,
        batchID: UUID
    ) async -> (rawInput: BatchRawInput, failureReason: BatchImportFailureReason?) {
        let now = Date()
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let fileName = url.lastPathComponent
        let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey])
        let contentType = resourceValues?.contentType
        let typeIdentifier = contentType?.identifier
        let inputID = UUID()

        if resourceValues?.isDirectory == true {
            return (
                BatchRawInput(
                    id: inputID,
                    batchID: batchID,
                    sourceKind: .files,
                    originalFileName: fileName,
                    originalUTType: typeIdentifier,
                    inputHash: "file-\(inputID.uuidString)",
                    fileRef: fileName,
                    rawText: nil,
                    createdAt: now,
                    updatedAt: now
                ),
                .unsupportedFileType
            )
        }

        do {
            let data = try Data(contentsOf: url)
            if contentType?.conforms(to: .image) == true {
                let text = try ocrService.recognizeText(from: data)
                return (
                    BatchRawInput(
                        id: inputID,
                        batchID: batchID,
                        sourceKind: .files,
                        originalFileName: fileName,
                        originalUTType: typeIdentifier,
                        inputHash: "file-\(inputID.uuidString)",
                        fileRef: fileName,
                        rawText: text,
                        createdAt: now,
                        updatedAt: now
                    ),
                    nil
                )
            }

            if contentType?.conforms(to: .text) == true || contentType == .plainText {
                let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .unicode)
                    ?? ""
                return (
                    BatchRawInput(
                        id: inputID,
                        batchID: batchID,
                        sourceKind: .files,
                        originalFileName: fileName,
                        originalUTType: typeIdentifier,
                        inputHash: "file-\(inputID.uuidString)",
                        fileRef: fileName,
                        rawText: text,
                        createdAt: now,
                        updatedAt: now
                    ),
                    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .emptyInput : nil
                )
            }

            return (
                BatchRawInput(
                    id: inputID,
                    batchID: batchID,
                    sourceKind: .files,
                    originalFileName: fileName,
                    originalUTType: typeIdentifier,
                    inputHash: "file-\(inputID.uuidString)",
                    fileRef: fileName,
                    rawText: nil,
                    createdAt: now,
                    updatedAt: now
                ),
                contentType?.conforms(to: .pdf) == true ? .unsupportedFileType : .unsupportedFileType
            )
        } catch let error as OCRServiceError {
            return (
                BatchRawInput(
                    id: inputID,
                    batchID: batchID,
                    sourceKind: .files,
                    originalFileName: fileName,
                    originalUTType: typeIdentifier,
                    inputHash: "file-\(inputID.uuidString)",
                    fileRef: fileName,
                    rawText: nil,
                    createdAt: now,
                    updatedAt: now
                ),
                error == .emptyText ? .ocrFailed : .parseFailed
            )
        } catch {
            return (
                BatchRawInput(
                    id: inputID,
                    batchID: batchID,
                    sourceKind: .files,
                    originalFileName: fileName,
                    originalUTType: typeIdentifier,
                    inputHash: "file-\(inputID.uuidString)",
                    fileRef: fileName,
                    rawText: nil,
                    createdAt: now,
                    updatedAt: now
                ),
                .permissionDenied
            )
        }
    }

    private func detailCard<Content: View>(
        titleKey: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleKey)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            content()
        }
        .padding(16)
        .background(AppTheme.canvas.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func detailRow(_ titleKey: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 132, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func iconName(for item: BatchImportQueueItem) -> String {
        switch item.state {
        case .rawInput: return "doc.viewfinder"
        case .candidate: return item.failureReason == .duplicateSuspected ? "doc.on.doc.fill" : "doc.text.magnifyingglass"
        case .reviewed: return "checkmark.seal.fill"
        case .transaction: return "tray.and.arrow.down.fill"
        case .rejected: return "xmark.octagon.fill"
        }
    }

    private func color(for item: BatchImportQueueItem) -> Color {
        if item.failureReason == .duplicateSuspected { return Color(red: 0.84, green: 0.45, blue: 0.12) }
        switch item.state {
        case .rawInput: return AppTheme.accentSecondary
        case .candidate: return AppTheme.accent
        case .reviewed: return Color(red: 0.33, green: 0.35, blue: 0.78)
        case .transaction: return Color(red: 0.18, green: 0.48, blue: 0.34)
        case .rejected: return Color(red: 0.82, green: 0.28, blue: 0.22)
        }
    }

    private func itemTitleFallback(for item: BatchImportQueueItem) -> String {
        switch item.state {
        case .rawInput: return String(localized: "ipad.batch_import.item.raw")
        case .candidate: return String(localized: "ipad.batch_import.item.candidate")
        case .reviewed: return String(localized: "ipad.batch_import.item.reviewed")
        case .transaction: return String(localized: "ipad.batch_import.item.transaction")
        case .rejected: return String(localized: "ipad.batch_import.item.rejected")
        }
    }

    private func stateTitle(for state: BatchImportItemState) -> String {
        switch state {
        case .rawInput: return String(localized: "ipad.batch_import.state.rawInput")
        case .candidate: return String(localized: "ipad.batch_import.state.candidate")
        case .reviewed: return String(localized: "ipad.batch_import.state.reviewed")
        case .transaction: return String(localized: "ipad.batch_import.state.transaction")
        case .rejected: return String(localized: "ipad.batch_import.state.rejected")
        }
    }

    private func failureTitle(_ reason: BatchImportFailureReason) -> String {
        switch reason {
        case .emptyInput: return String(localized: "ipad.batch_import.failure.emptyInput")
        case .ocrFailed: return String(localized: "ipad.batch_import.failure.ocrFailed")
        case .nonBillImage: return String(localized: "ipad.batch_import.failure.nonBillImage")
        case .missingAmount: return String(localized: "ipad.batch_import.failure.missingAmount")
        case .missingMerchant: return String(localized: "ipad.batch_import.failure.missingMerchant")
        case .missingDate: return String(localized: "ipad.batch_import.failure.missingDate")
        case .lowConfidence: return String(localized: "ipad.batch_import.failure.lowConfidence")
        case .multipleReceipts: return String(localized: "ipad.batch_import.failure.multipleReceipts")
        case .duplicateSuspected: return String(localized: "ipad.batch_import.failure.duplicateSuspected")
        case .unsupportedFileType: return String(localized: "ipad.batch_import.failure.unsupportedFileType")
        case .parseFailed: return String(localized: "ipad.batch_import.failure.parseFailed")
        case .userRejected: return String(localized: "ipad.batch_import.failure.userRejected")
        case .permissionDenied: return String(localized: "ipad.batch_import.failure.permissionDenied")
        }
    }

    private func warningSummary(_ warnings: [BatchImportWarning]) -> String {
        guard !warnings.isEmpty else { return String(localized: "common.none") }
        return warnings
            .map(warningTitle)
            .joined(separator: " / ")
    }

    private func warningTitle(_ warning: BatchImportWarning) -> String {
        switch warning {
        case .nonBillImage: return String(localized: "ipad.batch_import.warning.nonBillImage")
        case .emptyOCRText: return String(localized: "ipad.batch_import.warning.emptyOCRText")
        case .missingAmount: return String(localized: "ipad.batch_import.warning.missingAmount")
        case .missingMerchant: return String(localized: "ipad.batch_import.warning.missingMerchant")
        case .missingDate: return String(localized: "ipad.batch_import.warning.missingDate")
        case .lowConfidence: return String(localized: "ipad.batch_import.warning.lowConfidence")
        case .multipleReceipts: return String(localized: "ipad.batch_import.warning.multipleReceipts")
        case .duplicateSuspected: return String(localized: "ipad.batch_import.warning.duplicateSuspected")
        case .unsupportedFileType: return String(localized: "ipad.batch_import.warning.unsupportedFileType")
        case .parseFailed: return String(localized: "ipad.batch_import.warning.parseFailed")
        }
    }

    private func confidenceText(_ confidence: Double) -> String {
        String(format: "%.0f%%", confidence * 100)
    }

}

struct HotelStayWorkspaceView: View {
    @EnvironmentObject private var store: LedgerStore
    @EnvironmentObject private var navigationState: AutoLedgerNavigationState
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    @State private var showsPDFImporter = false
    @State private var showsEmailImporter = false
    @State private var showsCloudInboxImporter = false
    @State private var reviewDraft: HotelStayDraft?
    @State private var statusMessage: String?
    @State private var isImporting = false
    @State private var pendingCloudCandidateID: UUID?

    private var ledgerID: String? {
        store.isShowingAllLedgers ? nil : store.selectedLedgerID
    }

    var body: some View {
        HotelStayListView(
            records: store.hotelStayRecords,
            drafts: store.hotelStayDrafts,
            transactions: store.visibleTransactions,
            ledgerID: ledgerID,
            isImporting: isImporting,
            statusMessage: statusMessage,
            selectedRecordID: $navigationState.selectedHotelStayRecordID,
            onImportPDF: {
                showsPDFImporter = true
            },
            onImportEmail: {
                showsEmailImporter = true
            },
            onImportCloudInbox: {
                pendingCloudCandidateID = nil
                showsCloudInboxImporter = true
            },
            onReviewDraft: { draft in
                reviewDraft = draft
            },
            onUpdateRecord: { record, linkedTransaction in
                let didUpdate = store.updateHotelStayRecord(record, linkedTransaction: linkedTransaction)
                statusMessage = store.lastImportSummary
                return didUpdate
            },
            onDeleteRecord: { record in
                let didDelete = store.deleteHotelStayRecord(record)
                statusMessage = store.lastImportSummary
                return didDelete
            }
        )
        .fileImporter(
            isPresented: $showsPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await importSelectedPDF(result)
            }
        }
        .sheet(isPresented: $showsEmailImporter) {
            HotelFolioEmailImportView(
                targetLedgerID: store.targetLedgerIDForNewTransactions,
                onDraftsReady: { drafts in
                    showsEmailImporter = false
                    Task {
                        await prepareEmailDraftsForReview(drafts)
                    }
                }
            )
        }
        .sheet(isPresented: $showsCloudInboxImporter) {
            HotelFolioInboxImportView(
                targetLedgerID: store.targetLedgerIDForNewTransactions,
                targetCandidateID: pendingCloudCandidateID,
                onDraftsReady: { drafts in
                    showsCloudInboxImporter = false
                    Task {
                        await prepareEmailDraftsForReview(drafts)
                    }
                }
            )
        }
        .sheet(item: $reviewDraft) { draft in
            HotelStayReviewView(
                draft: draft,
                onConfirm: { confirmedDraft in
                    if store.postConfirmedHotelStayDraft(confirmedDraft) {
                        statusMessage = String(localized: "hotel_stay.import.status.posted")
                    } else {
                        statusMessage = store.lastImportSummary
                    }
                },
                onReject: { rejectedDraft in
                    if store.rejectHotelStayDraft(rejectedDraft) {
                        statusMessage = String(localized: "hotel_stay.import.status.rejected")
                    } else {
                        statusMessage = store.lastImportSummary
                    }
                }
            )
        }
        .onAppear {
            consumePendingDraftReviewIfNeeded()
            consumePendingCloudCandidateIfNeeded()
        }
        .onChange(of: navigationState.pendingHotelStayDraftReviewID) { _, _ in
            consumePendingDraftReviewIfNeeded()
        }
        .onChange(of: navigationState.pendingHotelCloudCandidateID) { _, _ in
            consumePendingCloudCandidateIfNeeded()
        }
        .onChange(of: navigationState.isPresentingHotelCloudInbox) { _, _ in
            consumePendingCloudCandidateIfNeeded()
        }
        .onChange(of: store.hotelStayDrafts.map(\.id)) { _, _ in
            consumePendingDraftReviewIfNeeded()
        }
        .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
    }

    @MainActor
    private func importSelectedPDF(_ result: Result<[URL], Error>) async {
        isImporting = true
        statusMessage = String(localized: "hotel_stay.import.status.extracting")
        defer {
            isImporting = false
        }

        do {
            guard let url = try result.get().first else {
                statusMessage = String(localized: "hotel_stay.import.error.no_file")
                return
            }

            let draft = try HotelFolioManualPDFImporter().importPDF(
                at: url,
                targetLedgerID: store.targetLedgerIDForNewTransactions
            )
            statusMessage = String(localized: "hotel_stay.import.status.text_extracted")
            await prepareDraftForReview(draft, managesImportingState: false)
        } catch {
            statusMessage = String(
                format: String(localized: "hotel_stay.import.status.failed_format"),
                error.localizedDescription
            )
        }
    }

    @MainActor
    private func prepareEmailDraftsForReview(_ drafts: [HotelStayDraft]) async {
        guard !drafts.isEmpty else { return }
        if drafts.count == 1, let draft = drafts.first {
            await prepareDraftForReview(draft)
            return
        }

        isImporting = true
        statusMessage = String(format: String(localized: "hotel_stay.email.status.batch_parsing_format"), drafts.count)
        defer {
            isImporting = false
        }

        var savedCount = 0
        for draft in drafts {
            if await prepareDraftForReview(draft, managesImportingState: false, opensReview: false) != nil {
                savedCount += 1
            }
        }

        statusMessage = String(format: String(localized: "hotel_stay.email.status.batch_saved_format"), savedCount, drafts.count)
    }

    @discardableResult
    @MainActor
    private func prepareDraftForReview(
        _ draft: HotelStayDraft,
        managesImportingState: Bool = true,
        opensReview: Bool = true
    ) async -> HotelStayDraft? {
        if managesImportingState {
            isImporting = true
            statusMessage = String(localized: "hotel_stay.import.status.text_extracted")
        }
        defer {
            if managesImportingState {
                isImporting = false
            }
        }

        var preparedDraft = draft
        store.recordHotelFolioDebugRecord(
            HotelFolioDebugTraceBuilder.makeTextExtractedRecord(draft: preparedDraft)
        )
        do {
            let parseResult = try await HotelFolioExternalParseClient().parseWithDebug(preparedDraft)
            preparedDraft = parseResult.draft
            store.recordHotelFolioDebugRecords(parseResult.debugRecords)
            statusMessage = String(localized: "hotel_stay.import.status.parsed")
        } catch let failure as HotelFolioExternalParseFailure {
            store.recordHotelFolioDebugRecords(failure.debugRecords)
            statusMessage = String(
                format: String(localized: "hotel_stay.import.status.manual_review_format"),
                failure.localizedDescription
            )
        } catch {
            store.recordHotelFolioDebugRecord(
                HotelFolioDebugTraceBuilder.makeParseFailedRecord(
                    draft: preparedDraft,
                    message: error.localizedDescription
                )
            )
            statusMessage = String(
                format: String(localized: "hotel_stay.import.status.manual_review_format"),
                error.localizedDescription
            )
        }

        if store.saveHotelStayDraft(preparedDraft) {
            if opensReview {
                reviewDraft = preparedDraft
            }
            return preparedDraft
        } else {
            statusMessage = store.lastImportSummary
            return nil
        }
    }

    @MainActor
    private func consumePendingDraftReviewIfNeeded() {
        guard !isImporting,
              reviewDraft == nil,
              let draftID = navigationState.pendingHotelStayDraftReviewID,
              let draft = store.hotelStayDrafts.first(where: { $0.id == draftID }) else {
            return
        }

        navigationState.pendingHotelStayDraftReviewID = nil
        if draft.status == .needsReview || draft.parsedPayload != nil {
            reviewDraft = draft
            return
        }

        Task {
            await prepareDraftForReview(draft)
        }
    }

    @MainActor
    private func consumePendingCloudCandidateIfNeeded() {
        guard !isImporting,
              navigationState.isPresentingHotelCloudInbox else {
            return
        }

        let candidateID = navigationState.pendingHotelCloudCandidateID
        navigationState.pendingHotelCloudCandidateID = nil
        navigationState.isPresentingHotelCloudInbox = false
        pendingCloudCandidateID = candidateID
        showsCloudInboxImporter = true
    }
}

private struct IPadReportWorkspaceView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedMonth: Date = .now
    @State private var selectedTrendLabel: String?
    private let analysisPanelHeight: CGFloat = 396

    private var snapshot: MonthlySnapshot {
        store.monthlySnapshot(for: selectedMonth)
    }

    private var isCurrentMonth: Bool {
        AppFormatters.calendar.isDate(selectedMonth, equalTo: .now, toGranularity: .month)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    metricGrid
                    analysisGrid
                }
                .padding(24)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("ipad.workspace.reports")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        stepMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel(Text("ledger.filter.previous_month"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        stepMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .fontWeight(.semibold)
                    }
                    .disabled(isCurrentMonth)
                    .opacity(isCurrentMonth ? 0.35 : 1)
                    .accessibilityLabel(Text("ledger.filter.next_month"))
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ipad.analysis.title")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text(snapshot.monthLabel)
                    .font(.headline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            Text(AppFormatters.currency(snapshot.totalExpense))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(22)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var metricGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
            MetricCard(
                title: String(localized: "report.summary.transactions"),
                value: transactionCountText(snapshot.transactionCount),
                detail: String(localized: "ipad.analysis.metric.transactions.detail"),
                accent: AppTheme.accent
            )

            MetricCard(
                title: String(localized: "report.summary.top1"),
                value: snapshot.topMerchant,
                detail: String(localized: "ipad.analysis.metric.top_merchant.detail"),
                accent: AppTheme.accentSecondary
            )

            MetricCard(
                title: String(localized: "report.summary.merchant_count"),
                value: merchantCountText(snapshot.topMerchantMetrics.count),
                detail: String(localized: "report.top_merchants.title"),
                accent: Color(red: 0.33, green: 0.35, blue: 0.78)
            )

            MetricCard(
                title: String(localized: "report.category_breakdown.title"),
                value: snapshot.categoryBreakdown.first?.title ?? String(localized: "report.all_categories"),
                detail: snapshot.categoryBreakdown.first.map { percentageText($0.ratio) } ?? String(localized: "report.empty.month"),
                accent: snapshot.categoryBreakdown.first?.tint ?? AppTheme.accent
            )
        }
    }

    private var analysisGrid: some View {
        Grid(horizontalSpacing: 18, verticalSpacing: 18) {
            GridRow {
                categoryPanel
                trendPanel
            }

            GridRow {
                topMerchantPanel
                recentMonthPanel
            }
        }
    }

    private var categoryPanel: some View {
        analysisPanel(titleKey: "report.category_breakdown.title") {
            if snapshot.categoryBreakdown.isEmpty {
                emptyState("report.empty.month")
            } else {
                VStack(spacing: 12) {
                    ForEach(snapshot.categoryBreakdown.prefix(6)) { metric in
                        IPadAnalysisProgressRow(
                            title: metric.title,
                            value: AppFormatters.currency(metric.total),
                            ratioText: percentageText(metric.ratio),
                            ratio: metric.ratio,
                            tint: metric.tint,
                            systemImage: metric.iconName
                        )
                    }
                }
            }
        }
    }

    private var trendPanel: some View {
        analysisPanel(titleKey: "report.six_month_trend.title") {
            VStack(alignment: .leading, spacing: 12) {
                Chart(snapshot.monthlyTrend) { metric in
                    BarMark(
                        x: .value(String(localized: "report.chart.month"), metric.label),
                        y: .value(String(localized: "report.chart.expense"), metric.total)
                    )
                    .foregroundStyle(metric.isCurrentMonth ? AppTheme.accentSecondary : AppTheme.accent)
                    .opacity(selectedTrendLabel == nil || selectedTrendLabel == metric.label ? 1 : 0.36)
                }
                .chartLegend(.hidden)
                .frame(height: 230)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let xInPlot = value.location.x - geo[plotFrame].origin.x
                                        if let tapped: String = proxy.value(atX: xInPlot) {
                                            withOptionalAnimation {
                                                selectedTrendLabel = selectedTrendLabel == tapped ? nil : tapped
                                            }
                                        }
                                    }
                            )
                    }
                }

                HStack {
                    let activeMetric = selectedTrendLabel.flatMap { label in
                        snapshot.monthlyTrend.first { $0.label == label }
                    } ?? snapshot.monthlyTrend.last

                    Text(activeMetric?.label ?? snapshot.monthLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedInk)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(AppFormatters.currency(activeMetric?.total ?? snapshot.totalExpense))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(transactionCountText(activeMetric?.transactionCount ?? snapshot.transactionCount))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }
            }
        }
    }

    private var topMerchantPanel: some View {
        analysisPanel(titleKey: "report.top_merchants.title") {
            if snapshot.topMerchantMetrics.isEmpty {
                emptyState("report.top_merchants.empty")
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(snapshot.topMerchantMetrics.prefix(6).enumerated()), id: \.element.id) { index, metric in
                        IPadAnalysisProgressRow(
                            title: metric.merchant,
                            value: AppFormatters.currency(metric.total),
                            ratioText: transactionCountText(metric.transactionCount),
                            ratio: metric.ratio,
                            tint: index == 0 ? AppTheme.accentSecondary : AppTheme.accent,
                            rank: index + 1
                        )
                    }
                }
            }
        }
    }

    private var recentMonthPanel: some View {
        analysisPanel(titleKey: "ipad.analysis.month_detail") {
            VStack(alignment: .leading, spacing: 14) {
                IPadAnalysisDetailRow(
                    titleKey: "report.summary.transactions",
                    value: transactionCountText(snapshot.transactionCount)
                )
                IPadAnalysisDetailRow(
                    titleKey: "report.summary.top1",
                    value: snapshot.topMerchant
                )
                IPadAnalysisDetailRow(
                    titleKey: "report.summary.merchant_count",
                    value: merchantCountText(snapshot.topMerchantMetrics.count)
                )
                IPadAnalysisDetailRow(
                    titleKey: "report.category_breakdown.title",
                    value: snapshot.categoryBreakdown.first?.title ?? String(localized: "report.all_categories")
                )
                Divider()
                Text("ipad.analysis.month_detail.note")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
    }

    private func analysisPanel<Content: View>(
        titleKey: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(titleKey)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: analysisPanelHeight, idealHeight: analysisPanelHeight, maxHeight: analysisPanelHeight, alignment: .topLeading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func emptyState(_ textKey: LocalizedStringKey) -> some View {
        Text(textKey)
            .font(.subheadline)
            .foregroundStyle(AppTheme.mutedInk)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
    }

    private func stepMonth(by value: Int) {
        guard let next = AppFormatters.calendar.date(byAdding: .month, value: value, to: selectedMonth) else { return }
        withOptionalAnimation {
            selectedMonth = next
            selectedTrendLabel = nil
        }
    }

    private func withOptionalAnimation(_ body: () -> Void) {
        if reduceMotion {
            body()
        } else {
            withAnimation(.easeInOut(duration: 0.18), body)
        }
    }

    private func transactionCountText(_ count: Int) -> String {
        String(format: String(localized: "report.transaction_count_format"), count)
    }

    private func merchantCountText(_ count: Int) -> String {
        String(format: String(localized: "report.merchant_count_format"), count)
    }

    private func percentageText(_ ratio: Double) -> String {
        String(format: String(localized: "report.percentage_format"), Int((ratio * 100).rounded()))
    }
}

private struct IPadAnalysisProgressRow: View {
    let title: String
    let value: String
    let ratioText: String
    let ratio: Double
    let tint: Color
    var systemImage: String?
    var rank: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let rank {
                    Text("\(rank)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(tint))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(width: 26, height: 26)
                        .background(tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)
                    Text(ratioText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer()

                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(proxy.size.width * min(max(ratio, 0), 1), 8))
                }
            }
            .frame(height: 7)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct IPadAnalysisDetailRow: View {
    let titleKey: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
        }
    }
}

private struct IPadLedgerWorkspaceView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var selectedTransactionID: UUID?
    @State private var selectedTransactionIDs: Set<UUID> = []
    @State private var editingTransaction: Transaction?
    @State private var isAddingTransaction = false
    @State private var isShowingVoiceLedger = false
    @State private var macSearchText = ""
    @State private var macSortMode: MacLedgerSortMode = .dateDescending
    @State private var batchMerchant = ""
    @State private var batchCategory = TransactionCategory.other.rawValue
    @State private var pendingBatchAction: MacLedgerBatchAction?
    @State private var selectedDuplicatePreviewID: String?
    @State private var pendingDuplicatePreview: DataCleaningPreviewItem?
    @State private var showsDuplicateApplyConfirmation = false

    private var transactions: [Transaction] {
        sortedTransactions(store.visibleTransactions)
    }

    private var filteredTransactions: [Transaction] {
        let query = macSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return transactions }
        return transactions.filter { transaction in
            transaction.merchant.localizedCaseInsensitiveContains(query) ||
            transaction.categoryTitle.localizedCaseInsensitiveContains(query) ||
            transaction.sourceTitle.localizedCaseInsensitiveContains(query) ||
            transaction.note.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedTransaction: Transaction? {
        if let selectedTransactionID,
           let transaction = store.visibleTransactions.first(where: { $0.id == selectedTransactionID }) {
            return transaction
        }
        if let firstSelectedID = selectedTransactionIDs.first,
           let transaction = store.visibleTransactions.first(where: { $0.id == firstSelectedID }) {
            return transaction
        }
        return filteredTransactions.first
    }

    private var selectedTransactions: [Transaction] {
        store.visibleTransactions.filter { selectedTransactionIDs.contains($0.id) }
    }

    private var ledgerScopeTitle: String {
        store.isShowingAllLedgers
            ? String(localized: "ledger.scope.all")
            : store.ledgerName(for: store.selectedLedgerID)
    }

    private var batchCategoryTitle: String {
        TransactionCategory(rawValue: batchCategory)?.title ?? batchCategory
    }

    private var macDuplicatePreviews: [DataCleaningPreviewItem] {
        DataCleaningPreviewPlanner()
            .buildSnapshot(
                transactions: store.visibleTransactions,
                merchantAliases: store.merchantAliases,
                categoryCorrections: store.categoryCorrections
            )
            .items(kind: .duplicateCandidate)
    }

    private var selectedDuplicatePreview: DataCleaningPreviewItem? {
        if let selectedDuplicatePreviewID,
           let preview = macDuplicatePreviews.first(where: { $0.id == selectedDuplicatePreviewID }) {
            return preview
        }
        return macDuplicatePreviews.first
    }

    private var selectedDuplicateTransactions: [Transaction] {
        guard let selectedDuplicatePreview else { return [] }
        let affectedIDs = Set(selectedDuplicatePreview.affectedTransactionIDs)
        return store.visibleTransactions
            .filter { affectedIDs.contains($0.id) }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    var body: some View {
        NavigationStack {
            ledgerContent
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("ipad.workspace.ledger")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingVoiceLedger = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel(Text(String(localized: "voice_ledger_title")))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddingTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel(Text("transaction_editor.title.new"))
                }
            }
            .onAppear {
                if selectedTransactionID == nil {
                    selectedTransactionID = filteredTransactions.first?.id
                }
                consumePendingNewTransactionIfNeeded()
            }
            .onChange(of: selectedTransactionIDs) { _, newSelection in
                guard let first = newSelection.first else { return }
                selectedTransactionID = first
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationService.openNewTransactionEvent)) { _ in
                consumePendingNewTransactionIfNeeded()
            }
            .sheet(item: $editingTransaction) { transaction in
                TransactionEditorView(
                    transaction: transaction,
                    onDuplicate: { transaction in
                        duplicateTransaction(transaction)
                    },
                    onDelete: { transaction in
                        deleteTransaction(transaction)
                    }
                ) { updated, refreshSameMerchantCategory, saveMerchantAlias in
                    let didSave = store.updateTransaction(
                        updated,
                        refreshSameMerchantCategory: refreshSameMerchantCategory,
                        saveMerchantAlias: saveMerchantAlias
                    )
                    if didSave {
                        selectedTransactionID = updated.id
                    }
                    return didSave
                }
            }
            .sheet(isPresented: $isAddingTransaction) {
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
                    let didSave = store.addTransaction(newTransaction)
                    if didSave {
                        selectedTransactionID = newTransaction.id
                    }
                    return didSave
                }
            }
            .sheet(isPresented: $isShowingVoiceLedger) {
                VoiceLedgerConfirmView()
            }
            .confirmationDialog(
                batchConfirmationTitle,
                isPresented: Binding(
                    get: { pendingBatchAction != nil },
                    set: { if !$0 { pendingBatchAction = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(batchConfirmationButtonTitle, role: .none) {
                    applyPendingBatchAction()
                }
                Button("common.cancel", role: .cancel) {
                    pendingBatchAction = nil
                }
            } message: {
                Text(batchConfirmationMessage)
            }
            .confirmationDialog(
                "mac.ledger.duplicate.confirm_title",
                isPresented: $showsDuplicateApplyConfirmation,
                titleVisibility: .visible
            ) {
                Button("mac.ledger.duplicate.apply", role: .destructive) {
                    applyPendingDuplicatePreview()
                }
                Button("common.cancel", role: .cancel) {
                    pendingDuplicatePreview = nil
                }
            } message: {
                Text(duplicateConfirmationMessage)
            }
        }
    }

    @ViewBuilder
    private var ledgerContent: some View {
        #if targetEnvironment(macCatalyst)
        macLedgerWorkspace
        #else
        ipadLedgerWorkspace
        #endif
    }

    private var ipadLedgerWorkspace: some View {
        HStack(spacing: 0) {
            transactionList
                .frame(minWidth: 360, idealWidth: 420, maxWidth: 500)

            Divider()

            transactionInspector
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var transactionList: some View {
        List {
            Section {
                ledgerScopeMenu
            }

            Section {
                ForEach(transactions) { transaction in
                    Button {
                        selectedTransactionID = transaction.id
                    } label: {
                        IPadTransactionCompactRow(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                    .autoLedgerSelectableRowBackground(selectedTransactionID == transaction.id)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            duplicateTransaction(transaction)
                        } label: {
                            Label("ledger.action.copy", systemImage: "doc.on.doc")
                        }
                        .tint(AppTheme.accent)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteTransaction(transaction)
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            duplicateTransaction(transaction)
                        } label: {
                            Label("ledger.action.copy", systemImage: "doc.on.doc")
                        }

                        Button {
                            editingTransaction = transaction
                        } label: {
                            Label("common.edit", systemImage: "square.and.pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteTransaction(transaction)
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text(String(format: String(localized: "ledger.footer_format"), transactions.count))
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.canvas.opacity(0.45))
        .refreshable {
            await store.pullLedgerFromCloudKitIfEnabled(reason: "iPad 账本下拉刷新，正在从 iCloud 拉取数据。")
        }
    }

    private var transactionInspector: some View {
        IPadTransactionInspector(
            transaction: selectedTransaction,
            edit: { transaction in editingTransaction = transaction },
            duplicate: duplicateTransaction,
            delete: deleteTransaction
        )
    }

    private func duplicateTransaction(_ transaction: Transaction) {
        guard let duplicated = store.duplicateTransaction(transaction) else { return }
        selectedTransactionID = duplicated.id
        selectedTransactionIDs = [duplicated.id]
    }

    private func deleteTransaction(_ transaction: Transaction) {
        store.deleteTransaction(transaction)
        selectedTransactionIDs.remove(transaction.id)
        if selectedTransactionID == transaction.id {
            selectedTransactionID = filteredTransactions.first(where: { $0.id != transaction.id })?.id
        }
    }

    private var ledgerScopeMenu: some View {
        Menu {
            Button {
                store.selectAllLedgers()
                selectedTransactionIDs.removeAll()
                selectedTransactionID = filteredTransactions.first?.id
            } label: {
                Label("ledger.scope.all", systemImage: store.isShowingAllLedgers ? "checkmark.circle.fill" : "books.vertical")
            }

            Divider()

            ForEach(store.activeLedgerProfiles) { profile in
                Button {
                    store.selectLedgerProfile(profile)
                    selectedTransactionIDs.removeAll()
                    selectedTransactionID = filteredTransactions.first?.id
                } label: {
                    Label(
                        profile.name,
                        systemImage: !store.isShowingAllLedgers && store.selectedLedgerID == profile.id ? "checkmark.circle.fill" : (profile.iconName ?? "wallet.pass")
                    )
                }
            }
        } label: {
            Label(ledgerScopeTitle, systemImage: store.isShowingAllLedgers ? "books.vertical" : "wallet.pass")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
    }

    #if targetEnvironment(macCatalyst)
    private var macLedgerWorkspace: some View {
        GeometryReader { geometry in
            let showsInspector = geometry.size.width >= 1_220
            let inspectorWidth = min(360, max(320, geometry.size.width * 0.28))

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    macLedgerToolbar
                    macBatchEditPanel
                    macDuplicateReviewPanel
                    macTransactionTable
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(AppTheme.canvas.opacity(0.45))

                if showsInspector {
                    Divider()

                    transactionInspector
                        .frame(width: inspectorWidth)
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }

    private var macLedgerToolbar: some View {
        HStack(spacing: 12) {
            ledgerScopeMenu

            TextField("mac.ledger.search", text: $macSearchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 240, maxWidth: 360)

            Picker("mac.ledger.sort", selection: $macSortMode) {
                ForEach(MacLedgerSortMode.allCases) { mode in
                    Text(mode.titleKey).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            Spacer()

            Text(String(format: String(localized: "mac.ledger.selection_format"), selectedTransactionIDs.count, filteredTransactions.count))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)

            Button {
                selectedTransactionIDs = Set(filteredTransactions.map(\.id))
                selectedTransactionID = filteredTransactions.first?.id
            } label: {
                Label("mac.ledger.select_all", systemImage: "checklist.checked")
            }
            .buttonStyle(.bordered)
            .disabled(filteredTransactions.isEmpty)

            Button {
                selectedTransactionIDs.removeAll()
            } label: {
                Label("mac.ledger.clear_selection", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(selectedTransactionIDs.isEmpty)
        }
    }

    private var macBatchEditPanel: some View {
        HStack(spacing: 12) {
            Label("mac.ledger.batch.title", systemImage: "square.stack.3d.up")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            TextField("mac.ledger.batch.merchant_placeholder", text: $batchMerchant)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            Button {
                pendingBatchAction = .merchant
            } label: {
                Label("mac.ledger.batch.apply_merchant", systemImage: "textformat.alt")
            }
            .buttonStyle(.bordered)
            .disabled(selectedTransactionIDs.isEmpty || batchMerchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Picker("transaction_editor.category", selection: $batchCategory) {
                ForEach(TransactionCategory.allCases, id: \.rawValue) { category in
                    Text(category.title).tag(category.rawValue)
                }
                ForEach(store.customCategories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            Button {
                pendingBatchAction = .category
            } label: {
                Label("mac.ledger.batch.apply_category", systemImage: "tag.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .disabled(selectedTransactionIDs.isEmpty)
        }
        .padding(12)
        .background(AppTheme.card.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var macTransactionTable: some View {
        Table(filteredTransactions, selection: $selectedTransactionIDs) {
            TableColumn(String(localized: "transaction_editor.date")) { transaction in
                let isSelected = selectedTransactionIDs.contains(transaction.id)
                Text(AppFormatters.shortDateTime(transaction.occurredAt))
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.86) : AppTheme.mutedInk)
            }
            .width(min: 132, ideal: 150)

            TableColumn(String(localized: "transaction_editor.merchant")) { transaction in
                let isSelected = selectedTransactionIDs.contains(transaction.id)
                Text(transaction.merchant)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : AppTheme.ink)
                    .lineLimit(1)
            }
            .width(min: 180, ideal: 260)

            TableColumn(String(localized: "transaction_editor.amount")) { transaction in
                let isSelected = selectedTransactionIDs.contains(transaction.id)
                Text(AppFormatters.currency(transaction.amount))
                    .font(.body.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white : AppTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 96, ideal: 118)

            TableColumn(String(localized: "transaction_editor.category")) { transaction in
                let isSelected = selectedTransactionIDs.contains(transaction.id)
                Label(transaction.categoryTitle, systemImage: transaction.categoryEnum.iconName)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.90) : AppTheme.ink)
                    .lineLimit(1)
            }
            .width(min: 128, ideal: 160)

            TableColumn(String(localized: "transaction_editor.source")) { transaction in
                let isSelected = selectedTransactionIDs.contains(transaction.id)
                Text(transaction.sourceTitle)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.78) : AppTheme.mutedInk)
                    .lineLimit(1)
            }
            .width(min: 96, ideal: 128)

            TableColumn(String(localized: "transaction_editor.note")) { transaction in
                let isSelected = selectedTransactionIDs.contains(transaction.id)
                Text(transaction.note.isEmpty ? "-" : transaction.note)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.78) : AppTheme.mutedInk)
                    .lineLimit(1)
            }
            .width(min: 160, ideal: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var macDuplicateReviewPanel: some View {
        if let selectedDuplicatePreview {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Label("mac.ledger.duplicate.title", systemImage: "doc.on.doc.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Text(String(format: String(localized: "mac.ledger.duplicate.count_format"), macDuplicatePreviews.count))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.84, green: 0.45, blue: 0.12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.84, green: 0.45, blue: 0.12).opacity(0.12))
                        .clipShape(Capsule())

                    Picker("mac.ledger.duplicate.group", selection: Binding(
                        get: { selectedDuplicatePreview.id },
                        set: { selectedDuplicatePreviewID = $0 }
                    )) {
                        ForEach(macDuplicatePreviews) { preview in
                            Text(duplicatePreviewTitle(preview)).tag(preview.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 220)

                    Spacer()

                    Button {
                        selectedTransactionIDs = Set(selectedDuplicatePreview.affectedTransactionIDs)
                        selectedTransactionID = selectedDuplicatePreview.affectedTransactionIDs.first
                    } label: {
                        Label("mac.ledger.duplicate.select_affected", systemImage: "checklist.checked")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        pendingDuplicatePreview = selectedDuplicatePreview
                        showsDuplicateApplyConfirmation = true
                    } label: {
                        Label("mac.ledger.duplicate.apply", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.84, green: 0.45, blue: 0.12))
                }

                HStack(spacing: 10) {
                    Text(duplicatePreviewSubtitle(selectedDuplicatePreview))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineLimit(1)

                    ForEach(selectedDuplicateTransactions) { transaction in
                        Text("\(transaction.merchant) \(AppFormatters.currency(transaction.amount))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.canvas.opacity(0.78))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(12)
            .background(Color(red: 0.84, green: 0.45, blue: 0.12).opacity(0.10))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(red: 0.84, green: 0.45, blue: 0.12).opacity(0.22), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    #endif

    @MainActor
    private func consumePendingNewTransactionIfNeeded() {
        guard QuickLedgerNavigationState.shared.consumeCreateTransactionPending() else { return }
        isAddingTransaction = true
    }

    private func sortedTransactions(_ source: [Transaction]) -> [Transaction] {
        switch macSortMode {
        case .dateDescending:
            return source.sorted { $0.occurredAt > $1.occurredAt }
        case .amountDescending:
            return source.sorted {
                if $0.amount == $1.amount { return $0.occurredAt > $1.occurredAt }
                return $0.amount > $1.amount
            }
        case .merchantAscending:
            return source.sorted {
                let merchantCompare = $0.merchant.localizedStandardCompare($1.merchant)
                if merchantCompare == .orderedSame { return $0.occurredAt > $1.occurredAt }
                return merchantCompare == .orderedAscending
            }
        }
    }

    private var batchConfirmationTitle: String {
        guard let pendingBatchAction else { return "" }
        switch pendingBatchAction {
        case .merchant:
            return String(localized: "mac.ledger.batch.confirm_merchant_title")
        case .category:
            return String(localized: "mac.ledger.batch.confirm_category_title")
        }
    }

    private var batchConfirmationButtonTitle: String {
        guard let pendingBatchAction else { return String(localized: "common.ok") }
        switch pendingBatchAction {
        case .merchant:
            return String(localized: "mac.ledger.batch.apply_merchant")
        case .category:
            return String(localized: "mac.ledger.batch.apply_category")
        }
    }

    private var batchConfirmationMessage: String {
        guard let pendingBatchAction else { return "" }
        switch pendingBatchAction {
        case .merchant:
            return String(
                format: String(localized: "mac.ledger.batch.confirm_merchant_message"),
                selectedTransactions.count,
                batchMerchant.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        case .category:
            return String(
                format: String(localized: "mac.ledger.batch.confirm_category_message"),
                selectedTransactions.count,
                batchCategoryTitle
            )
        }
    }

    private func applyPendingBatchAction() {
        guard let pendingBatchAction else { return }
        switch pendingBatchAction {
        case .merchant:
            _ = store.applyBatchTransactionEdits(
                transactionIDs: selectedTransactionIDs,
                merchant: batchMerchant,
                category: nil
            )
            batchMerchant = ""
        case .category:
            _ = store.applyBatchTransactionEdits(
                transactionIDs: selectedTransactionIDs,
                merchant: nil,
                category: batchCategory
            )
        }
        self.pendingBatchAction = nil
    }

    private var duplicateConfirmationMessage: String {
        guard let pendingDuplicatePreview else { return "" }
        return String(
            format: String(localized: "mac.ledger.duplicate.confirm_message"),
            max(0, pendingDuplicatePreview.affectedTransactionIDs.count - 1)
        )
    }

    private func applyPendingDuplicatePreview() {
        guard let pendingDuplicatePreview else { return }
        _ = store.applyDataCleaningPreview(pendingDuplicatePreview)
        selectedTransactionIDs.subtract(pendingDuplicatePreview.affectedTransactionIDs)
        self.pendingDuplicatePreview = nil
        selectedDuplicatePreviewID = macDuplicatePreviews.first?.id
    }

    private func duplicatePreviewTitle(_ preview: DataCleaningPreviewItem) -> String {
        String(
            format: String(localized: "mac.ledger.duplicate.group_format"),
            preview.title,
            preview.affectedTransactionIDs.count
        )
    }

    private func duplicatePreviewSubtitle(_ preview: DataCleaningPreviewItem) -> String {
        let score = (preview.score ?? 0) * 100
        return String(
            format: String(localized: "mac.ledger.duplicate.subtitle_format"),
            score,
            preview.affectedTransactionIDs.count
        )
    }
}

private enum MacLedgerSortMode: String, CaseIterable, Identifiable {
    case dateDescending
    case amountDescending
    case merchantAscending

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .dateDescending:
            return "mac.ledger.sort.date_desc"
        case .amountDescending:
            return "mac.ledger.sort.amount_desc"
        case .merchantAscending:
            return "mac.ledger.sort.merchant_asc"
        }
    }
}

private enum MacLedgerBatchAction {
    case merchant
    case category
}

private struct IPadTransactionCompactRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: transaction.categoryEnum.iconName)
                .font(.headline)
                .foregroundStyle(transaction.categoryEnum.tint)
                .frame(width: 34, height: 34)
                .background(transaction.categoryEnum.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(transaction.merchant)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)

                    Spacer()

                    Text(AppFormatters.currency(transaction.amount))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(transaction.categoryTitle)
                    Text(transaction.sourceTitle)
                    Text(AppFormatters.shortDateTime(transaction.occurredAt))
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct IPadTransactionInspector: View {
    let transaction: Transaction?
    let edit: (Transaction) -> Void
    let duplicate: (Transaction) -> Void
    let delete: (Transaction) -> Void

    var body: some View {
        Group {
            if let transaction {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(transaction.merchant)
                                    .font(.largeTitle.weight(.bold))
                                    .foregroundStyle(AppTheme.ink)

                                Text(AppFormatters.shortDateTime(transaction.occurredAt))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.mutedInk)
                            }

                            Spacer()

                            Text(AppFormatters.currency(transaction.amount))
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }

                        HStack(spacing: 12) {
                            inspectorChip(transaction.categoryTitle, systemImage: transaction.categoryEnum.iconName)
                            inspectorChip(transaction.sourceTitle, systemImage: "square.and.arrow.down")
                        }

                        if !transaction.note.isEmpty {
                            inspectorSection(titleKey: "transaction_editor.note") {
                                Text(transaction.note)
                                    .font(.body)
                                    .foregroundStyle(AppTheme.ink)
                            }
                        }

                        inspectorSection(titleKey: "ipad.workspace.detail") {
                            VStack(alignment: .leading, spacing: 12) {
                                detailRow("transaction_editor.merchant", value: transaction.merchant)
                                detailRow("transaction_editor.category", value: transaction.categoryTitle)
                                detailRow("transaction_editor.source", value: transaction.sourceTitle)
                                detailRow("transaction_editor.date", value: AppFormatters.exportDateTime(transaction.occurredAt))
                            }
                        }

                        HStack(spacing: 12) {
                            Button {
                                duplicate(transaction)
                            } label: {
                                Label("ledger.action.copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                edit(transaction)
                            } label: {
                                Label("common.edit", systemImage: "square.and.pencil")
                            }
                            .buttonStyle(.borderedProminent)

                            Button(role: .destructive) {
                                delete(transaction)
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(28)
                }
                .background(AppTheme.screenGradient.ignoresSafeArea())
            } else {
                IPadPlanningWorkspaceView(
                    titleKey: "ipad.workspace.ledger.empty",
                    subtitleKey: "ipad.workspace.ledger.empty.placeholder",
                    systemImage: "list.bullet.rectangle",
                    items: [
                        "ipad.workspace.next.import",
                        "ipad.workspace.next.review",
                        "ipad.workspace.next.cleaning"
                    ]
                )
            }
        }
    }

    private func inspectorChip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func inspectorSection<Content: View>(
        titleKey: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleKey)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func detailRow(_ titleKey: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Spacer()
        }
    }
}

private struct IPadPlanningWorkspaceView: View {
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let systemImage: String
    let items: [LocalizedStringKey]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 72, height: 72)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)

                Text(titleKey)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Text(subtitleKey)
                    .font(.body)
                    .foregroundStyle(AppTheme.mutedInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items.indices, id: \.self) { index in
                        Label(items[index], systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink)
                    }
                }
                .padding(16)
                .frame(maxWidth: 420, alignment: .leading)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle(titleKey)
        }
    }
}

#Preview {
    IPadWorkspaceView()
        .environmentObject(LedgerStore())
        .environmentObject(AutoLedgerNavigationState())
}
