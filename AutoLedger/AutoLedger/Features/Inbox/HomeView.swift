//
//  HomeView.swift
//  AutoLedger
//
//  Created by 张津铖 on 2026/3/27.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        TabView {
            InboxView()
                .tabItem {
                    Label("收件箱", systemImage: "tray.full.fill")
                }

            LedgerView()
                .tabItem {
                    Label("账本", systemImage: "list.bullet.rectangle.portrait.fill")
                }

            ReportView()
                .tabItem {
                    Label("月报", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .tint(AppTheme.accent)
    }
}

#Preview {
    HomeView()
        .environmentObject(LedgerStore())
}
