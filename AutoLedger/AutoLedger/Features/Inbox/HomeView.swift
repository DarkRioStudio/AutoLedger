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
        TabView(selection: developerObservedTabSelection) {
            InboxView(selectedTab: $navigationState.selectedHomeTab)
                .developerPerformanceSurfaceReady("tab_inbox")
                .tabItem {
                    Label("tab.inbox", systemImage: "tray.full.fill")
                }
                .tag(AutoLedgerHomeTab.inbox.rawValue)

            LedgerView {
                navigationState.openLedgerProfiles()
            }
                .developerPerformanceSurfaceReady("tab_ledger")
                .tabItem {
                    Label("tab.ledger", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(AutoLedgerHomeTab.ledger.rawValue)

            HotelStayWorkspaceView()
                .developerPerformanceSurfaceReady("tab_hotel_stays")
                .tabItem {
                    Label("hotel_stay.list.title", systemImage: "building.2.fill")
                }
                .tag(AutoLedgerHomeTab.hotelStays.rawValue)

            ReportView()
                .developerPerformanceSurfaceReady("tab_report")
                .tabItem {
                    Label("tab.report", systemImage: "chart.bar.fill")
                }
                .tag(AutoLedgerHomeTab.report.rawValue)

            SettingsView()
                .developerPerformanceSurfaceReady("tab_settings")
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape.fill")
                }
                .tag(AutoLedgerHomeTab.settings.rawValue)
        }
    }

    private var developerObservedTabSelection: Binding<Int> {
        Binding(
            get: { navigationState.selectedHomeTab },
            set: { newValue in
                guard newValue != navigationState.selectedHomeTab else { return }
                CommonAPIAnalyticsService.beginDeveloperSurfaceTransition(
                    surface: analyticsSurfaceName(for: newValue)
                )
                navigationState.selectedHomeTab = newValue
            }
        )
    }

    @MainActor
    private func consumeQuickLedgerPendingNavigationIfNeeded() {
        guard QuickLedgerNavigationState.shared.consumeOpenLedgerPending() else { return }
        navigationState.openLedgerTab()
    }

    private func trackSelectedTab(openReason: String) {
        let startedAt = Date()
        let surface = analyticsSurfaceName(for: navigationState.selectedHomeTab)
        CommonAPIAnalyticsService.trackFeatureSurfaceOpened(
            surface: surface,
            entrySurface: "tab_bar",
            openReason: openReason
        )
        if openReason == "tab_selection" {
            CommonAPIAnalyticsService.trackUIResponsiveness(
                surface: surface,
                operation: "tab_switch",
                startedAt: startedAt
            )
        }
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

private struct DeveloperPerformanceSurfaceReadyModifier: ViewModifier {
    let surface: String

    func body(content: Content) -> some View {
        content.onAppear {
            CommonAPIAnalyticsService.markDeveloperSurfaceReady(surface: surface)
        }
    }
}

private extension View {
    func developerPerformanceSurfaceReady(_ surface: String) -> some View {
        modifier(DeveloperPerformanceSurfaceReadyModifier(surface: surface))
    }
}

#Preview {
    HomeView()
        .environmentObject(LedgerStore())
        .environmentObject(AutoLedgerNavigationState())
}
