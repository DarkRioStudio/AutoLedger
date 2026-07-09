//
//  HomeView.swift
//  AutoLedger
//
//  Created by 张津铖 on 2026/3/27.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    @EnvironmentObject private var navigationState: AutoLedgerNavigationState

    var body: some View {
        adaptiveTabs
            .tint(AppTheme.accent)
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
            .onAppear {
                trackSelectedTab(openReason: "initial")
                consumeQuickLedgerPendingNavigationIfNeeded()
            }
            .onChange(of: navigationState.selectedHomeTab) { _, _ in
                trackSelectedTab(openReason: "tab_selection")
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationService.quickLedgerOpenLedgerEvent)) { _ in
                consumeQuickLedgerPendingNavigationIfNeeded()
            }
    }

    @ViewBuilder
    private var adaptiveTabs: some View {
        tabs.autoLedgerAdaptiveTabBar()
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

    private func trackSelectedTab(openReason: String) {
        CommonAPIAnalyticsService.trackFeatureSurfaceOpened(
            surface: analyticsSurfaceName(for: navigationState.selectedHomeTab),
            entrySurface: "tab_bar",
            openReason: openReason
        )
    }

    private func analyticsSurfaceName(for rawValue: Int) -> String {
        switch AutoLedgerHomeTab(rawValue: rawValue) {
        case .inbox:
            return "tab_inbox"
        case .ledger:
            return "tab_ledger"
        case .hotelStays:
            return "tab_hotel_stays"
        case .report:
            return "tab_report"
        case .settings:
            return "tab_settings"
        case .none:
            return "tab_unknown"
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(LedgerStore())
        .environmentObject(AutoLedgerNavigationState())
}
