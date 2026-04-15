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
    @UIApplicationDelegateAdaptor(AutoLedgerAppDelegate.self) private var appDelegate
    @StateObject private var store = LedgerStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 注册默认设置
        UserDefaults.standard.register(defaults: [
            "subscriptionReminder": true
        ])

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
                        // 订阅提醒通知调度
                        if UserDefaults.standard.bool(forKey: "subscriptionReminder") {
                            NotificationService.shared.requestPermissionIfNeeded()
                            NotificationService.shared.scheduleUpcomingChargeReminders(for: store.subscriptions)
                        }
                    }
                }
        }
    }
}
