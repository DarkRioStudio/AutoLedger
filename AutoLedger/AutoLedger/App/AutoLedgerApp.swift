//
//  AutoLedgerApp.swift
//  AutoLedger
//
//  Created by 张津铖 on 2026/3/27.
//

import SwiftUI
import AutoLedgerCore

@main
struct AutoLedgerApp: App {
    @StateObject private var store = LedgerStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        ClipboardImportIntent.handler = {
            LedgerStore.shared?.attemptClipboardImport(force: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.refreshFromStore()
                        if UserDefaults.standard.bool(forKey: "autoClipboardImport") {
                            store.attemptClipboardImport()
                        }
                    }
                }
        }
    }
}
