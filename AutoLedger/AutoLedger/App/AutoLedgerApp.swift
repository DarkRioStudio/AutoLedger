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
    @AppStorage(AppLanguagePreference.userDefaultsKey) private var languagePreferenceRawValue = AppLanguagePreference.system.rawValue

    init() {
        // 注册默认设置
        UserDefaults.standard.register(defaults: [
            "subscriptionReminder": true,
            "monthlyAnomalyThresholdPercent": 150.0,
            AppThemePreset.userDefaultsKey: AppThemePreset.fresh.rawValue,
            AppColorSchemePreference.userDefaultsKey: AppColorSchemePreference.system.rawValue,
            AppThemeCustomTheme.surfaceHexKey: AppThemeCustomTheme.defaultSurfaceHex,
            AppThemeCustomTheme.accentHexKey: AppThemeCustomTheme.defaultAccentHex,
            AppThemeCustomTheme.secondaryHexKey: AppThemeCustomTheme.defaultSecondaryHex,
            AppLanguagePreference.userDefaultsKey: AppLanguagePreference.system.rawValue
        ])
        ScreenshotModeConfig.installRuntimeOverrides()

        ClipboardImportIntent.handler = {
            guard !PerformanceFixtureConfiguration.isEnabled else { return }
            LedgerStore.shared?.attemptClipboardImport(force: true)
        }

        if !ScreenshotModeConfig.isEnabled && !PerformanceFixtureConfiguration.isEnabled {
            // 激活 WatchConnectivity 会话（Watch 端连接前预备）
            LedgerStore.watchSyncHandler = {
                WatchConnectivityHost.shared.publishLatestLedgerSnapshot()
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
            .environment(
                \.locale,
                (AppLanguagePreference(rawValue: languagePreferenceRawValue) ?? .system).locale
            )
            .preferredColorScheme(
                (AppColorSchemePreference(rawValue: colorSchemePreferenceRawValue) ?? .system).colorScheme
            )
            .autoLedgerMotion(AppMotion.theme, value: themeRawValue)
            .autoLedgerMotion(AppMotion.theme, value: colorSchemePreferenceRawValue)
            .autoLedgerMotion(AppMotion.theme, value: customThemeSurfaceHex)
            .autoLedgerMotion(AppMotion.theme, value: customThemeAccentHex)
            .autoLedgerMotion(AppMotion.theme, value: customThemeSecondaryHex)
            .autoLedgerMotion(AppMotion.theme, value: languagePreferenceRawValue)
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

    @StateObject private var store: LedgerStore
    @StateObject private var navigationState = AutoLedgerNavigationState()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppThemePreset.userDefaultsKey) private var themeRawValue = AppThemePreset.fresh.rawValue
    @AppStorage(AppColorSchemePreference.userDefaultsKey) private var colorSchemePreferenceRawValue = AppColorSchemePreference.system.rawValue
    @AppStorage(AppThemeCustomTheme.surfaceHexKey) private var customThemeSurfaceHex = AppThemeCustomTheme.defaultSurfaceHex
    @AppStorage(AppThemeCustomTheme.accentHexKey) private var customThemeAccentHex = AppThemeCustomTheme.defaultAccentHex
    @AppStorage(AppThemeCustomTheme.secondaryHexKey) private var customThemeSecondaryHex = AppThemeCustomTheme.defaultSecondaryHex
    @State private var didScheduleLaunchSync = false
    @State private var didScheduleAnalyticsUpload = false
    @State private var pendingStructuredJSONHandoff: StructuredLedgerJSONIntentHandoff?

    init() {
        _store = StateObject(
            wrappedValue: PerformanceFixtureConfiguration.makeLedgerStoreIfRequested()
                ?? LedgerStore(deferSQLiteStateHydration: true)
        )
    }

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
            .overlay {
                if store.isPersistentStateLoading {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()

                        ProgressView(localizedRootString("ledger.persistence.loading", fallback: "正在加载本地账本…"))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .allowsHitTesting(!store.isPersistentStateLoading)
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
            .alert(
                localizedRootString("ledger.persistence.alert.title", fallback: "本地账本暂不可用"),
                isPresented: Binding(
                    get: { store.persistenceInitializationErrorMessage != nil },
                    set: { if !$0 { store.dismissPersistenceInitializationError() } }
                )
            ) {
                Button(localizedRootString("common.ok", fallback: "好")) {
                    store.dismissPersistenceInitializationError()
                }
            } message: {
                Text(store.persistenceInitializationErrorMessage ?? "")
            }
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
                guard !PerformanceFixtureConfiguration.isEnabled else { return }
                SupportPurchaseManager.shared.startTransactionListener()
                ProEntitlementManager.shared.startTransactionListener()
                scheduleLaunchCloudSyncIfNeeded()
                scheduleCommonAPIRefresh()
                scheduleAnalyticsUploadIfNeeded()
                scheduleGemmaWarmupIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationService.didSaveTransactionFromIntent)) { _ in
                guard !PerformanceFixtureConfiguration.isEnabled else { return }
                Task { @MainActor in
                    await refreshStoreWithPerformanceTracking(operation: "refresh_from_intent_notification")
                    await store.pushPendingIntentLedgerSaveIfNeeded(reason: "外部入口记账完成，开始推送 iCloud。")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationService.openDeepLinkEvent)) { _ in
                guard !PerformanceFixtureConfiguration.isEnabled else { return }
                consumeNotificationDeepLinkHandoffIfNeeded()
            }
            .sheet(item: $pendingStructuredJSONHandoff) { handoff in
                StructuredLedgerJSONConfirmView(handoff: handoff)
                    .environmentObject(store)
            }
            .onOpenURL { url in
                guard !PerformanceFixtureConfiguration.isEnabled else { return }
                _ = navigationState.openDeepLink(url, store: store)
                Task { @MainActor in
                    await consumeSharedHotelFolioDraftReviewHandoffIfNeeded()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard !PerformanceFixtureConfiguration.isEnabled else { return }
                if newPhase == .active {
                    AppSessionDiagnosticsService.markActive()
                    Task { @MainActor in
                        await handleSceneBecameActive()
                    }
                } else if newPhase == .background {
                    AppSessionDiagnosticsService.markCleanBackground()
                    store.backupOnAppBackground()
                }
            }
            .onAppear {
                guard !PerformanceFixtureConfiguration.isEnabled else { return }
                Task { @MainActor in
                    await store.refreshFromStoreInBackground()
                    consumeAppIntentNavigationHandoffIfNeeded()
                    consumeNotificationDeepLinkHandoffIfNeeded()
                    consumeStructuredJSONHandoffIfNeeded()
                    await consumeSharedHotelFolioDraftReviewHandoffIfNeeded()
                    consumeClipboardImportIntentHandoffIfNeeded()
                }
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

    private func localizedRootString(_ key: String, fallback: String) -> String {
        AppLanguagePreference.localizedString(
            key,
            languageKey: AppLanguagePreference.current.catalogLanguageKey,
            fallback: fallback
        )
    }

    @MainActor
    private func handleSceneBecameActive() async {
        consumeStructuredJSONHandoffIfNeeded()
        await refreshStoreWithPerformanceTracking(operation: "refresh_from_foreground")
        await ProEntitlementManager.shared.refreshEntitlements()
        scheduleLaunchCloudSyncIfNeeded()
        scheduleCommonAPIRefresh()
        scheduleAnalyticsUploadIfNeeded()
        await store.pushPendingIntentLedgerSaveIfNeeded(reason: "App 回到前台，开始补推外部入口账单。")
        WatchConnectivityHost.shared.publishLatestLedgerSnapshot()

        if store.isLocalDataEmptyForRestore {
            store.detectICloudBackupForRestore()
        }
        if UserDefaults.standard.bool(forKey: "autoClipboardImport") {
            store.attemptClipboardImport()
        }
        await consumeSharedHotelFolioDraftReviewHandoffIfNeeded()
        consumeAppIntentNavigationHandoffIfNeeded()
        consumeNotificationDeepLinkHandoffIfNeeded()
        consumeClipboardImportIntentHandoffIfNeeded()

        if UserDefaults.standard.bool(forKey: "subscriptionReminder") {
            NotificationService.shared.requestPermissionIfNeeded()
            NotificationService.shared.scheduleUpcomingChargeReminders(for: store.subscriptions)
        }
    }

    private func scheduleCommonAPIRefresh() {
        Task(priority: .background) {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await CommonAPICatalogService.refreshIfNeeded()
        }
    }

    private func scheduleAnalyticsUploadIfNeeded() {
        guard !didScheduleAnalyticsUpload else { return }
        didScheduleAnalyticsUpload = true
        Task(priority: .background) {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await CommonAPIAnalyticsService.uploadLaunchEvent()
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
    private func consumeSharedHotelFolioDraftReviewHandoffIfNeeded() async {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier),
              let data = defaults.data(forKey: Self.hotelFolioDraftReviewKey),
              let request = try? JSONDecoder().decode(HotelFolioDraftReviewRequest.self, from: data) else {
            return
        }

        defaults.removeObject(forKey: Self.hotelFolioDraftReviewKey)
        await refreshStoreWithPerformanceTracking(operation: "refresh_from_hotel_handoff")
        navigationState.openHotelReviewQueue(draftID: request.draftID)
    }

    @MainActor
    private func refreshStoreWithPerformanceTracking(operation: String) async {
        let startedAt = Date()
        await store.refreshFromStoreInBackground()
        CommonAPIAnalyticsService.trackPerformanceDiagnostic(
            diagnosticType: "store_operation",
            surface: "ledger_store",
            operation: operation,
            startedAt: startedAt
        )
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
