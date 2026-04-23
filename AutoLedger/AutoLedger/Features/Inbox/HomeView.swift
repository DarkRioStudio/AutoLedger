//
//  HomeView.swift
//  AutoLedger
//
//  Created by 张津铖 on 2026/3/27.
//

import SwiftUI

private enum HomeTabIndex {
    static let ledger = 1
}

struct HomeView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            InboxView(selectedTab: $selectedTab)
                .tabItem {
                    Label("tab.inbox", systemImage: "tray.full.fill")
                }
                .tag(0)

            LedgerView()
                .tabItem {
                    Label("tab.ledger", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(1)

            ReportView()
                .tabItem {
                    Label("tab.report", systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView()
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
