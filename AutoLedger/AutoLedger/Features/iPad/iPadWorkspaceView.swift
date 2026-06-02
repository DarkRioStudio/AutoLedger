import AutoLedgerCore
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
            InboxView(selectedTab: selectedTabBinding)
        case .ledger:
            IPadLedgerWorkspaceView()
        case .reports:
            ReportView()
        case .reviewQueue:
            IPadPlanningWorkspaceView(
                titleKey: "ipad.workspace.review_queue",
                subtitleKey: "ipad.workspace.review_queue.placeholder",
                systemImage: "checklist",
                items: [
                    "ipad.workspace.review_queue.item.raw_input",
                    "ipad.workspace.review_queue.item.candidate",
                    "ipad.workspace.review_queue.item.reviewed"
                ]
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
