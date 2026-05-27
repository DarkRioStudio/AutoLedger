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

    init() {
        // 注册默认设置
        UserDefaults.standard.register(defaults: [
            "subscriptionReminder": true,
            "monthlyAnomalyThresholdPercent": 150.0
        ])

        ClipboardImportIntent.handler = {
            LedgerStore.shared?.attemptClipboardImport(force: true)
        }

        if !ScreenshotModeConfig.isEnabled {
            // 激活 WatchConnectivity 会话（Watch 端连接前预备）
            LedgerStore.watchSyncHandler = {
                WatchConnectivityHost.shared.pushRecentTransactionsIfReachable()
            }
            _ = WatchConnectivityHost.shared
        }
    }

    var body: some Scene {
        WindowGroup {
            if ScreenshotModeConfig.isEnabled {
                ScreenshotHostView(scene: ScreenshotModeConfig.scene)
            } else {
                AutoLedgerRootView()
            }
        }
    }
}

private struct AutoLedgerRootView: View {
    @StateObject private var store = LedgerStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HomeView()
            .environmentObject(store)
            .alert("检测到 iCloud 备份", isPresented: Binding(
                get: { store.isLocalDataEmptyForRestore && store.detectedICloudBackup != nil },
                set: { if !$0 { store.detectedICloudBackup = nil } }
            )) {
                Button("立即恢复") {
                    do {
                        try store.restoreDetectedICloudBackup()
                    } catch {
                        store.lastImportSummary = "iCloud 恢复失败：\(error.localizedDescription)"
                    }
                }
                Button("暂不恢复", role: .cancel) {
                    store.detectedICloudBackup = nil
                }
            } message: {
                if let bundle = store.detectedICloudBackup {
                    Text("备份时间：\(AppFormatters.exportDateTime(bundle.exportedAt))\n\(store.summaryText(for: bundle))")
                } else {
                    Text("")
                }
            }
            .task {
                // App 启动后台预热 Gemma（如已下载），避免首次推理时才加载
                if LLMProvider.userSelected == .gemma {
                    await GemmaService.shared.ensureLoaded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationService.didSaveTransactionFromIntent)) { _ in
                store.refreshFromStore()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    store.refreshFromStore()
                    WatchConnectivityHost.shared.pushRecentTransactionsIfReachable()
                    if store.isLocalDataEmptyForRestore {
                        store.detectICloudBackupForRestore()
                    }
                    if UserDefaults.standard.bool(forKey: "autoClipboardImport") {
                        store.attemptClipboardImport()
                    }
                    // 订阅提醒通知调度
                    if UserDefaults.standard.bool(forKey: "subscriptionReminder") {
                        NotificationService.shared.requestPermissionIfNeeded()
                        NotificationService.shared.scheduleUpcomingChargeReminders(for: store.subscriptions)
                    }
                } else if newPhase == .background {
                    store.backupOnAppBackground()
                }
            }
    }
}
