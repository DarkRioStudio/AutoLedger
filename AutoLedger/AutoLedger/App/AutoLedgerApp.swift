//
//  AutoLedgerApp.swift
//  AutoLedger
//
//  Created by 张津铖 on 2026/3/27.
//

import SwiftUI
import UIKit
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
                ScreenshotHostView(
                    platform: ScreenshotModeConfig.platform,
                    sceneIdentifier: ScreenshotModeConfig.sceneIdentifier
                )
            } else {
                AutoLedgerRootView()
            }
        }
        #if targetEnvironment(macCatalyst)
        .commands {
            AutoLedgerMacCommands()
        }
        #endif
    }
}

private struct AutoLedgerRootView: View {
    @StateObject private var store = LedgerStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var didScheduleLaunchSync = false
    @State private var pendingStructuredJSONHandoff: StructuredLedgerJSONIntentHandoff?

    var body: some View {
        rootContent
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
                SupportPurchaseManager.shared.startTransactionListener()
                scheduleLaunchCloudSyncIfNeeded()
                scheduleGemmaWarmupIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationService.didSaveTransactionFromIntent)) { _ in
                store.refreshFromStore()
                Task {
                    await store.pushPendingIntentLedgerSaveIfNeeded(reason: "外部入口记账完成，开始推送 iCloud。")
                }
            }
            .sheet(item: $pendingStructuredJSONHandoff) { handoff in
                StructuredLedgerJSONConfirmView(handoff: handoff)
                    .environmentObject(store)
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    consumeStructuredJSONHandoffIfNeeded()
                    store.refreshFromStore()
                    scheduleLaunchCloudSyncIfNeeded()
                    Task {
                        await store.pushPendingIntentLedgerSaveIfNeeded(reason: "App 回到前台，开始补推外部入口账单。")
                    }
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
            .onAppear {
                consumeStructuredJSONHandoffIfNeeded()
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            IPadWorkspaceView()
        } else {
            HomeView()
        }
    }

    private func scheduleLaunchCloudSyncIfNeeded() {
        guard !didScheduleLaunchSync else { return }
        didScheduleLaunchSync = true
        Task(priority: .background) {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await store.syncLedgerWithCloudKitOnLaunchIfNeeded()
        }
    }

    private func scheduleGemmaWarmupIfNeeded() {
        guard LLMProvider.userSelected == .gemma else { return }
        Task(priority: .background) {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            await GemmaService.shared.ensureLoaded()
        }
    }

    @MainActor
    private func consumeStructuredJSONHandoffIfNeeded() {
        guard pendingStructuredJSONHandoff == nil,
              let handoff = StructuredLedgerJSONIntentHandoffStore.consume() else { return }
        pendingStructuredJSONHandoff = handoff
    }

    @MainActor
    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "autoledger" else { return }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let destinationParts = [url.host].compactMap { $0 } + pathComponents
        guard destinationParts.contains("ledger") || destinationParts.contains("today") else { return }

        QuickLedgerNavigationState.shared.markOpenLedgerPending()
        NotificationCenter.default.post(name: NotificationService.quickLedgerOpenLedgerEvent, object: nil)
    }
}
