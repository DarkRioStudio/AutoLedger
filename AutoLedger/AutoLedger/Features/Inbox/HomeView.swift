//
//  HomeView.swift
//  AutoLedger
//
//  Created by 张津铖 on 2026/3/27.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var navigationState: AutoLedgerNavigationState

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
        TabView(selection: $navigationState.selectedHomeTab) {
            InboxView(selectedTab: $navigationState.selectedHomeTab)
                .tabItem {
                    Label("tab.inbox", systemImage: "tray.full.fill")
                }
                .tag(AutoLedgerHomeTab.inbox.rawValue)

            LedgerView {
                navigationState.openLedgerProfiles()
            }
                .tabItem {
                    Label("tab.ledger", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(AutoLedgerHomeTab.ledger.rawValue)

            HotelStayWorkspaceView()
                .tabItem {
                    Label("hotel_stay.list.title", systemImage: "building.2.fill")
                }
                .tag(AutoLedgerHomeTab.hotelStays.rawValue)

            ReportView()
                .tabItem {
                    Label("tab.report", systemImage: "chart.bar.fill")
                }
                .tag(AutoLedgerHomeTab.report.rawValue)

            SettingsView()
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape.fill")
                }
                .tag(AutoLedgerHomeTab.settings.rawValue)
        }
    }

    @MainActor
    private func consumeQuickLedgerPendingNavigationIfNeeded() {
        guard QuickLedgerNavigationState.shared.consumeOpenLedgerPending() else { return }
        navigationState.openLedgerTab()
    }
}

#Preview {
    HomeView()
        .environmentObject(LedgerStore())
        .environmentObject(AutoLedgerNavigationState())
}
