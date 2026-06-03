import AutoLedgerCore
import Charts
import SwiftUI

private enum IPadWorkspaceSection: String, CaseIterable, Identifiable {
    case overview
    case capture
    case ledger
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
        case .reports: return "chart.pie.fill"
        case .reviewQueue: return "checklist"
        case .cleaning: return "wand.and.sparkles"
        case .settings: return "gearshape.fill"
        }
    }

    var tabIndex: Int? {
        switch self {
        case .capture: return 0
        case .ledger: return 1
        case .reports: return 2
        case .settings: return 3
        case .overview, .reviewQueue, .cleaning: return nil
        }
    }

    static func fromTabIndex(_ index: Int) -> IPadWorkspaceSection? {
        allCases.first { $0.tabIndex == index }
    }
}

struct IPadWorkspaceView: View {
    @State private var selection: IPadWorkspaceSection = .overview
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List {
                ForEach(IPadWorkspaceSection.allCases) { section in
                    Button {
                        selection = section
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
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selection == section ? AppTheme.accent : AppTheme.ink)
                    .listRowBackground(selection == section ? AppTheme.accent.opacity(0.10) : Color.clear)
                }
            }
            .navigationTitle("ipad.workspace.title")
            .tint(AppTheme.accent)
        } detail: {
            detailView
                .id(selection)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(AppTheme.accent)
        .onAppear {
            consumeQuickLedgerPendingNavigationIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationService.quickLedgerOpenLedgerEvent)) { _ in
            consumeQuickLedgerPendingNavigationIfNeeded()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .overview:
            IPadWorkspaceOverviewView(
                openLedger: { selection = .ledger },
                openImport: { selection = .capture },
                openReviewQueue: { selection = .reviewQueue },
                openCleaning: { selection = .cleaning }
            )
        case .capture:
            IPadBatchImportWorkspaceView(
                selectedTab: selectedTabBinding,
                initialFilter: .all
            )
        case .ledger:
            IPadLedgerWorkspaceView()
        case .reports:
            IPadReportWorkspaceView()
        case .reviewQueue:
            IPadBatchImportWorkspaceView(
                selectedTab: selectedTabBinding,
                initialFilter: .candidate
            )
        case .cleaning:
            IPadPlanningWorkspaceView(
                titleKey: "ipad.workspace.cleaning",
                subtitleKey: "ipad.workspace.cleaning.placeholder",
                systemImage: "wand.and.sparkles",
                items: [
                    "ipad.workspace.cleaning.item.merchant",
                    "ipad.workspace.cleaning.item.category",
                    "ipad.workspace.cleaning.item.duplicates"
                ]
            )
        case .settings:
            SettingsView()
        }
    }

    private var selectedTabBinding: Binding<Int> {
        Binding {
            selection.tabIndex ?? 0
        } set: { tabIndex in
            guard let next = IPadWorkspaceSection.fromTabIndex(tabIndex) else { return }
            selection = next
        }
    }

    @MainActor
    private func consumeQuickLedgerPendingNavigationIfNeeded() {
        guard QuickLedgerNavigationState.shared.consumeOpenLedgerPending() else { return }
        selection = .ledger
    }
}

private struct IPadWorkspaceOverviewView: View {
    @EnvironmentObject private var store: LedgerStore

    let openLedger: () -> Void
    let openImport: () -> Void
    let openReviewQueue: () -> Void
    let openCleaning: () -> Void

    private var snapshot: MonthlySnapshot {
        MonthlySnapshot.build(from: store.transactions, referenceDate: .now)
    }

    private var recentTransactions: [Transaction] {
        store.transactions
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
                            value: "\(store.transactions.count)",
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

private struct IPadBatchImportWorkspaceView: View {
    @Binding private var selectedTab: Int
    @State private var filter: IPadBatchImportFilter
    @State private var selectedItemID: UUID?
    @State private var showSingleImport = false
    @State private var retriedItemIDs: Set<UUID> = []

    private var snapshot: BatchImportQueueSnapshot {
        Self.sampleSnapshot
    }

    private var items: [BatchImportQueueItem] {
        snapshot.items
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

    init(selectedTab: Binding<Int>, initialFilter: IPadBatchImportFilter) {
        self._selectedTab = selectedTab
        self._filter = State(initialValue: initialFilter)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                header
                filterBar

                HStack(alignment: .top, spacing: 18) {
                    queueList
                        .frame(minWidth: 360, idealWidth: 460, maxWidth: 520)

                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("ipad.batch_import.title")
            .sheet(isPresented: $showSingleImport) {
                InboxView(selectedTab: $selectedTab)
            }
            .onAppear {
                selectedItemID = selectedItem?.id
            }
            .onChange(of: filter) { _, _ in
                selectedItemID = items.first?.id
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ipad.batch_import.title")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text("ipad.batch_import.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            Button {
                showSingleImport = true
            } label: {
                Label("ipad.batch_import.single_import", systemImage: "doc.text.viewfinder")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
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
                summaryPill("ipad.batch_import.summary.total", value: "\(snapshot.items.count)", tint: AppTheme.accent)
                summaryPill("ipad.batch_import.summary.candidates", value: "\(snapshot.items(in: .candidate).count)", tint: AppTheme.accentSecondary)
                summaryPill("ipad.batch_import.summary.failed", value: "\(snapshot.items.filter { $0.failureReason != nil }.count)", tint: Color(red: 0.82, green: 0.28, blue: 0.22))
                summaryPill("ipad.batch_import.summary.official", value: "\(snapshot.officialTransactionIDs.count)", tint: Color(red: 0.33, green: 0.35, blue: 0.78))
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

                    detailCard(titleKey: "ipad.batch_import.detail.fields") {
                        detailRow("transaction_editor.merchant", value: item.merchant ?? String(localized: "common.none"))
                        detailRow("transaction_editor.amount", value: item.amount.map(AppFormatters.currency) ?? String(localized: "common.none"))
                        detailRow("transaction_editor.category", value: item.category ?? String(localized: "common.none"))
                        detailRow("transaction_editor.source", value: item.source ?? String(localized: "common.none"))
                        detailRow("transaction_editor.date", value: item.occurredAt.map(AppFormatters.exportDateTime) ?? String(localized: "common.none"))
                    }

                    detailCard(titleKey: "ipad.batch_import.detail.status") {
                        detailRow("ipad.batch_import.detail.confidence", value: confidenceText(item.confidence))
                        detailRow("ipad.batch_import.detail.failure", value: item.failureReason.map(failureTitle) ?? String(localized: "common.none"))
                        detailRow("ipad.batch_import.detail.warnings", value: warningSummary(item.warnings))
                        if retriedItemIDs.contains(item.id) {
                            Label("ipad.batch_import.retry_queued", systemImage: "arrow.clockwise.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                    }

                    if item.failureReason == .duplicateSuspected {
                        detailCard(titleKey: "ipad.batch_import.detail.duplicate") {
                            detailRow("ipad.batch_import.detail.duplicate_score", value: String(format: "%.0f%%", (item.duplicateScore ?? 0) * 100))
                            detailRow("ipad.batch_import.detail.duplicate_reason", value: item.duplicateReason ?? String(localized: "common.none"))
                        }
                    }

                    HStack(spacing: 12) {
                        if item.canRetry {
                            Button {
                                retriedItemIDs.insert(item.id)
                            } label: {
                                Label("ipad.batch_import.retry", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                        }

                        Button {
                            filter = .candidate
                        } label: {
                            Label("ipad.batch_import.show_candidates", systemImage: "checklist")
                        }
                        .buttonStyle(.bordered)
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

    private static var sampleSnapshot: BatchImportQueueSnapshot {
        let batchID = UUID(uuidString: "00000000-0000-0000-0000-000000154100") ?? UUID()
        let now = Date(timeIntervalSince1970: 1_780_200_000)
        let later = Date(timeIntervalSince1970: 1_780_203_600)
        let batch = BatchImportBatch(
            id: batchID,
            sourceKind: .photos,
            status: .running,
            itemCount: 5,
            createdAt: now,
            updatedAt: later
        )

        let rawInputs = (1...5).map { index in
            BatchRawInput(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000015410\(index)") ?? UUID(),
                batchID: batchID,
                sourceKind: index == 5 ? .files : .photos,
                originalFileName: "sample_receipt_0\(index).png",
                inputHash: "sample-hash-1541-\(index)",
                rawText: index == 5 ? nil : "Sample receipt \(index)",
                createdAt: now,
                updatedAt: later
            )
        }

        let demoCoffeeDraft = TransactionDraft(
            amount: 18.8,
            merchant: "Demo Coffee",
            category: TransactionCategory.dining.rawValue,
            occurredAt: later,
            sourceType: .ocr,
            inputText: "Demo Coffee\nAmount 18.80",
            parseMethod: .rule
        )
        let exampleMarketDraft = TransactionDraft(
            amount: 62.4,
            merchant: "Example Market",
            category: TransactionCategory.groceries.rawValue,
            occurredAt: later.addingTimeInterval(-1_800),
            sourceType: .ocr,
            inputText: "Example Market\nAmount 62.40",
            parseMethod: .rule
        )

        let rawItem = BatchImportQueueItem.rawInput(rawInput: rawInputs[0], createdAt: now)
        let candidate = BatchImportQueueItem
            .rawInput(rawInput: rawInputs[1], createdAt: now)
            .applyingInterpretation(InterpretResult(draft: demoCoffeeDraft, confidence: .high, needsReview: false), now: later)
        let missingAmount = BatchImportQueueItem
            .rawInput(rawInput: rawInputs[2], createdAt: now)
            .applyingInterpretation(
                InterpretResult(draft: nil, confidence: .low, needsReview: true, warnings: [.missingAmount]),
                now: later
            )
        let duplicate = BatchImportQueueItem
            .rawInput(rawInput: rawInputs[3], createdAt: now)
            .applyingInterpretation(InterpretResult(draft: exampleMarketDraft, confidence: .medium, needsReview: true), now: later)
            .markedDuplicate(
                groupID: "sample-duplicate-1541",
                score: 0.91,
                reason: String(localized: "ipad.batch_import.sample.duplicate_reason"),
                possibleTransactionID: UUID(uuidString: "00000000-0000-0000-0000-000000154199"),
                now: later
            )
        let rejected = BatchImportQueueItem
            .rawInput(rawInput: rawInputs[4], createdAt: now)
            .markedFailed(reason: .unsupportedFileType, now: later)

        return BatchImportQueueSnapshot(
            batches: [batch],
            rawInputs: rawInputs,
            items: [rawItem, candidate, missingAmount, duplicate, rejected]
        )
    }
}

private struct IPadReportWorkspaceView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedMonth: Date = .now
    @State private var selectedTrendLabel: String?

    private var snapshot: MonthlySnapshot {
        MonthlySnapshot.build(from: store.transactions, referenceDate: selectedMonth)
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

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
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
                    Text(ratioText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineLimit(1)
                }

                Spacer()

                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct IPadLedgerWorkspaceView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var selectedTransactionID: UUID?
    @State private var editingTransaction: Transaction?
    @State private var isAddingTransaction = false
    @State private var isShowingVoiceLedger = false

    private var transactions: [Transaction] {
        store.transactions.sorted { $0.occurredAt > $1.occurredAt }
    }

    private var selectedTransaction: Transaction? {
        if let selectedTransactionID,
           let transaction = transactions.first(where: { $0.id == selectedTransactionID }) {
            return transaction
        }
        return transactions.first
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                transactionList
                    .frame(minWidth: 360, idealWidth: 420, maxWidth: 500)

                Divider()

                IPadTransactionInspector(
                    transaction: selectedTransaction,
                    edit: { transaction in editingTransaction = transaction },
                    delete: { transaction in
                        store.deleteTransaction(transaction)
                        if selectedTransactionID == transaction.id {
                            selectedTransactionID = transactions.first(where: { $0.id != transaction.id })?.id
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
                    selectedTransactionID = transactions.first?.id
                }
                consumePendingNewTransactionIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationService.openNewTransactionEvent)) { _ in
                consumePendingNewTransactionIfNeeded()
            }
            .sheet(item: $editingTransaction) { transaction in
                TransactionEditorView(transaction: transaction) { updated, refreshSameMerchantCategory in
                    store.updateTransaction(updated, refreshSameMerchantCategory: refreshSameMerchantCategory)
                    selectedTransactionID = updated.id
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
                ) { newTransaction, _ in
                    store.addTransaction(newTransaction)
                    selectedTransactionID = newTransaction.id
                }
            }
            .sheet(isPresented: $isShowingVoiceLedger) {
                VoiceLedgerConfirmView()
            }
        }
    }

    private var transactionList: some View {
        List {
            Section {
                ForEach(transactions) { transaction in
                    Button {
                        selectedTransactionID = transaction.id
                    } label: {
                        IPadTransactionCompactRow(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(selectedTransactionID == transaction.id ? AppTheme.accent.opacity(0.10) : AppTheme.card)
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

    @MainActor
    private func consumePendingNewTransactionIfNeeded() {
        guard QuickLedgerNavigationState.shared.consumeCreateTransactionPending() else { return }
        isAddingTransaction = true
    }
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
}
