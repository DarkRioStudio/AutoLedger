//
//  HomeView.swift
//  AutoLedger
//
//  Created by 张津铖 on 2026/3/27.
//

import SwiftUI

private enum HomeTabIndex {
    static let ledger = 1
    static let settings = 3
}

struct HomeView: View {
    @State private var selectedTab = 0
    @State private var pendingSettingsNavigationTarget: SettingsNavigationTarget?

    var body: some View {
        TabView(selection: $selectedTab) {
            InboxView(selectedTab: $selectedTab)
                .tabItem {
                    Label("tab.inbox", systemImage: "tray.full.fill")
                }
                .tag(0)

            LedgerView {
                selectedTab = HomeTabIndex.settings
                pendingSettingsNavigationTarget = .ledgerProfiles
            }
                .tabItem {
                    Label("tab.ledger", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(1)

            ReportView()
                .tabItem {
                    Label("tab.report", systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView(pendingNavigationTarget: $pendingSettingsNavigationTarget)
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.accent)
        .onAppear {
            consumeQuickLedgerPendingNavigationIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationService.quickLedgerOpenLedgerEvent)) { _ in
            consumeQuickLedgerPendingNavigationIfNeeded()
        }
    }

    @MainActor
    private func consumeQuickLedgerPendingNavigationIfNeeded() {
        guard QuickLedgerNavigationState.shared.consumeOpenLedgerPending() else { return }
        selectedTab = HomeTabIndex.ledger
    }
}

#Preview {
    HomeView()
        .environmentObject(LedgerStore())
}
