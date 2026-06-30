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
    @AppStorage(AppThemePreset.userDefaultsKey) private var themeRawValue = AppThemePreset.fresh.rawValue
    @AppStorage(AppColorSchemePreference.userDefaultsKey) private var colorSchemePreferenceRawValue = AppColorSchemePreference.system.rawValue
    @AppStorage(AppThemeCustomTheme.surfaceHexKey) private var customThemeSurfaceHex = AppThemeCustomTheme.defaultSurfaceHex
    @AppStorage(AppThemeCustomTheme.accentHexKey) private var customThemeAccentHex = AppThemeCustomTheme.defaultAccentHex
    @AppStorage(AppThemeCustomTheme.secondaryHexKey) private var customThemeSecondaryHex = AppThemeCustomTheme.defaultSecondaryHex

    init() {
        // 注册默认设置
        UserDefaults.standard.register(defaults: [
            "subscriptionReminder": true,
            "monthlyAnomalyThresholdPercent": 150.0,
            AppThemePreset.userDefaultsKey: AppThemePreset.fresh.rawValue,
            AppColorSchemePreference.userDefaultsKey: AppColorSchemePreference.system.rawValue,
            AppThemeCustomTheme.surfaceHexKey: AppThemeCustomTheme.defaultSurfaceHex,
            AppThemeCustomTheme.accentHexKey: AppThemeCustomTheme.defaultAccentHex,
            AppThemeCustomTheme.secondaryHexKey: AppThemeCustomTheme.defaultSecondaryHex
        ])
        ScreenshotModeConfig.installRuntimeOverrides()

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
            Group {
                if ScreenshotModeConfig.isEnabled {
                    ScreenshotHostView(
                        platform: ScreenshotModeConfig.platform,
                        sceneIdentifier: ScreenshotModeConfig.sceneIdentifier
                    )
                } else {
                    AutoLedgerRootView()
                }
            }
            .preferredColorScheme(
                (AppColorSchemePreference(rawValue: colorSchemePreferenceRawValue) ?? .system).colorScheme
            )
            .autoLedgerMotion(AppMotion.theme, value: themeRawValue)
            .autoLedgerMotion(AppMotion.theme, value: colorSchemePreferenceRawValue)
            .autoLedgerMotion(AppMotion.theme, value: customThemeSurfaceHex)
            .autoLedgerMotion(AppMotion.theme, value: customThemeAccentHex)
            .autoLedgerMotion(AppMotion.theme, value: customThemeSecondaryHex)
        }
        #if targetEnvironment(macCatalyst)
        .commands {
            AutoLedgerMacCommands()
        }
        #endif
    }
}

private struct AutoLedgerRootView: View {
    private struct HotelFolioDraftReviewRequest: Codable {
        let draftID: UUID
        let createdAt: Date
    }

    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let hotelFolioDraftReviewKey = "share_pendingHotelFolioDraftReview.v1"

    @StateObject private var store = LedgerStore()
    @StateObject private var navigationState = AutoLedgerNavigationState()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppThemePreset.userDefaultsKey) private var themeRawValue = AppThemePreset.fresh.rawValue
    @AppStorage(AppColorSchemePreference.userDefaultsKey) private var colorSchemePreferenceRawValue = AppColorSchemePreference.system.rawValue
    @AppStorage(AppThemeCustomTheme.surfaceHexKey) private var customThemeSurfaceHex = AppThemeCustomTheme.defaultSurfaceHex
    @AppStorage(AppThemeCustomTheme.accentHexKey) private var customThemeAccentHex = AppThemeCustomTheme.defaultAccentHex
    @AppStorage(AppThemeCustomTheme.secondaryHexKey) private var customThemeSecondaryHex = AppThemeCustomTheme.defaultSecondaryHex
    @State private var didScheduleLaunchSync = false
    @State private var pendingStructuredJSONHandoff: StructuredLedgerJSONIntentHandoff?

    private var themeRefreshID: String {
        [
            themeRawValue,
            colorSchemePreferenceRawValue,
            customThemeSurfaceHex,
            customThemeAccentHex,
            customThemeSecondaryHex
        ].joined(separator: "|")
    }

    var body: some View {
        sizedRootContent
            .environmentObject(store)
            .environmentObject(navigationState)
            .environment(\.autoLedgerThemeRefreshID, themeRefreshID)
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
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
                ProEntitlementManager.shared.startTransactionListener()
                scheduleLaunchCloudSyncIfNeeded()
                scheduleGemmaWarmupIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationService.didSaveTransactionFromIntent)) { _ in
                store.refreshFromStore()
                Task {
                    await store.pushPendingIntentLedgerSaveIfNeeded(reason: "外部入口记账完成，开始推送 iCloud。")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationService.openDeepLinkEvent)) { _ in
                consumeNotificationDeepLinkHandoffIfNeeded()
            }
            .sheet(item: $pendingStructuredJSONHandoff) { handoff in
                StructuredLedgerJSONConfirmView(handoff: handoff)
                    .environmentObject(store)
            }
            .onOpenURL { url in
                _ = navigationState.openDeepLink(url, store: store)
                consumeSharedHotelFolioDraftReviewHandoffIfNeeded()
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
                    consumeSharedHotelFolioDraftReviewHandoffIfNeeded()
                    consumeAppIntentNavigationHandoffIfNeeded()
                    consumeNotificationDeepLinkHandoffIfNeeded()
                    consumeClipboardImportIntentHandoffIfNeeded()
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
                consumeAppIntentNavigationHandoffIfNeeded()
                consumeNotificationDeepLinkHandoffIfNeeded()
                consumeStructuredJSONHandoffIfNeeded()
                consumeSharedHotelFolioDraftReviewHandoffIfNeeded()
                consumeClipboardImportIntentHandoffIfNeeded()
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if targetEnvironment(macCatalyst)
        IPadWorkspaceView()
        #else
        HomeView()
        #endif
    }

    @ViewBuilder
    private var sizedRootContent: some View {
        #if targetEnvironment(macCatalyst)
        rootContent
            .frame(minWidth: 640, minHeight: 520)
        #else
        rootContent
        #endif
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
    private func consumeClipboardImportIntentHandoffIfNeeded() {
        guard ClipboardImportIntentHandoff.consumePendingRequest() else { return }
        store.attemptClipboardImport(force: true)
    }

    @MainActor
    private func consumeSharedHotelFolioDraftReviewHandoffIfNeeded() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier),
              let data = defaults.data(forKey: Self.hotelFolioDraftReviewKey),
              let request = try? JSONDecoder().decode(HotelFolioDraftReviewRequest.self, from: data) else {
            return
        }

        defaults.removeObject(forKey: Self.hotelFolioDraftReviewKey)
        store.refreshFromStore()
        navigationState.openHotelReviewQueue(draftID: request.draftID)
    }

    @MainActor
    private func consumeAppIntentNavigationHandoffIfNeeded() {
        guard let request = AutoLedgerIntentNavigationHandoff.consume() else { return }
        switch request.destination {
        case .monthlyReport:
            navigationState.selectedHomeTab = AutoLedgerHomeTab.report.rawValue
        case .ledger:
            if let ledgerID = request.ledgerID,
               let profile = store.activeLedgerProfiles.first(where: { $0.id == ledgerID }) {
                store.selectLedgerProfile(profile)
            }
            navigationState.selectedHomeTab = AutoLedgerHomeTab.ledger.rawValue
        case .receiptScan:
            navigationState.selectedHomeTab = AutoLedgerHomeTab.inbox.rawValue
        case .hotelReviewQueue:
            navigationState.selectedHomeTab = AutoLedgerHomeTab.hotelStays.rawValue
            navigationState.openHotelReviewQueue()
        }
    }

    @MainActor
    private func consumeNotificationDeepLinkHandoffIfNeeded() {
        guard let url = AutoLedgerDeepLinkHandoff.consume() else { return }
        _ = navigationState.openDeepLink(url, store: store)
    }

}
