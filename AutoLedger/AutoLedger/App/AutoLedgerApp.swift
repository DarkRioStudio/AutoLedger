//
//  AutoLedgerApp.swift
//  AutoLedger
//
//  Created by 张津铖 on 2026/3/27.
//

import SwiftUI

@main
struct AutoLedgerApp: App {
    @StateObject private var store = LedgerStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.refreshFromStore()
                    }
                }
        }
    }
}
