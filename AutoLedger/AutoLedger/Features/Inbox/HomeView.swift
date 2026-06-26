//
//  HomeView.swift
//  AutoLedger
//
//  Created by 张津铖 on 2026/3/27.
//

import SwiftUI

private enum HomeTabIndex {
    static let ledger = 1
    static let settings = 4
}

struct HomeView: View {
    @State private var selectedTab = 0
    @State private var pendingSettingsNavigationTarget: SettingsNavigationTarget?

    var body: some View {
        adaptiveTabs
            .tint(AppTheme.accent)
            .onAppear {
                consumeQuickLedgerPendingNavigationIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationService.quickLedgerOpenLedgerEvent)) { _ in
                consumeQuickLedgerPendingNavigationIfNeeded()
            }
    }

    @ViewBuilder
    private var adaptiveTabs: some View {
        if #available(iOS 27.0, *) {
            tabs
                .tabViewStyle(.sidebarAdaptable)
                .defaultTabBarPlacement(.sidebar)
        } else {
            tabs
        }
    }

    private var tabs: some View {
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

            HotelStayWorkspaceView()
                .tabItem {
                    Label("hotel_stay.list.title", systemImage: "building.2.fill")
                }
                .tag(2)

            ReportView()
                .tabItem {
                    Label("tab.report", systemImage: "chart.bar.fill")
                }
                .tag(3)

            SettingsView(pendingNavigationTarget: $pendingSettingsNavigationTarget)
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape.fill")
                }
                .tag(4)
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
