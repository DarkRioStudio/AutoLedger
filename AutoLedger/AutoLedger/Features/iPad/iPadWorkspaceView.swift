import SwiftUI

private enum IPadWorkspaceSection: String, CaseIterable, Identifiable {
    case capture
    case ledger
    case reports
    case reviewQueue
    case cleaning
    case settings

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
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
        case .reviewQueue, .cleaning: return nil
        }
    }

    static func fromTabIndex(_ index: Int) -> IPadWorkspaceSection? {
        allCases.first { $0.tabIndex == index }
    }
}

struct IPadWorkspaceView: View {
    @State private var selection: IPadWorkspaceSection = .capture
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
        case .capture:
            InboxView(selectedTab: selectedTabBinding)
        case .ledger:
            LedgerView()
        case .reports:
            ReportView()
        case .reviewQueue:
            IPadWorkspacePlaceholder(
                titleKey: "ipad.workspace.review_queue",
                subtitleKey: "ipad.workspace.review_queue.placeholder",
                systemImage: "checklist"
            )
        case .cleaning:
            IPadWorkspacePlaceholder(
                titleKey: "ipad.workspace.cleaning",
                subtitleKey: "ipad.workspace.cleaning.placeholder",
                systemImage: "wand.and.sparkles"
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

private struct IPadWorkspacePlaceholder: View {
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
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
