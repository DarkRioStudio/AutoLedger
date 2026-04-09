//
//  HomeView.swift
//  AutoLedger
//
//  Created by 张津铖 on 2026/3/27.
//

import SwiftUI

struct HomeView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            InboxView(selectedTab: $selectedTab)
                .tabItem {
                    Label("收件箱", systemImage: "tray.full.fill")
                }
                .tag(0)

            LedgerView()
                .tabItem {
                    Label("账本", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(1)

            ReportView()
                .tabItem {
                    Label("月报", systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.accent)
    }
}

#Preview {
    HomeView()
        .environmentObject(LedgerStore())
}
