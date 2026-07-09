import Foundation
import os.log
import UIKit
import UserNotifications

@MainActor
final class AutoLedgerAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let logger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "AutoLedgerAppDelegate")

    private enum HomeQuickAction {
        static let addTransaction = "top.darkrio326.AutoLedger.addTransaction"
    }

    static func handleHomeQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type == HomeQuickAction.addTransaction else { return false }

        QuickLedgerNavigationState.shared.markCreateTransactionPending()
        NotificationCenter.default.post(name: NotificationService.quickLedgerOpenLedgerEvent, object: nil)
        NotificationCenter.default.post(name: NotificationService.openNewTransactionEvent, object: nil)
        return true
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if !ProcessInfo.processInfo.arguments.contains("--screenshot-mode") {
            UNUserNotificationCenter.current().delegate = self
            AppDiagnosticsAnalyticsMonitor.shared.startIfNeeded()
            AppSessionDiagnosticsService.recordLaunchRecoveryIfNeeded()
        }
        configureHomeQuickActions(for: application)
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = AutoLedgerSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(Self.handleHomeQuickAction(shortcutItem))
    }

    func applicationWillTerminate(_ application: UIApplication) {
        AppSessionDiagnosticsService.markCleanBackground()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = NotificationService.storeRemoteDeviceToken(deviceToken)
        Task {
            await Self.registerHotelFolioInboxDeviceTokenIfPossible(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Self.logger.error("Failed to register remote notifications: \(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let deepLink = response.notification.request.content.userInfo[NotificationService.deepLinkUserInfoKey] as? String {
            AutoLedgerDeepLinkHandoff.submit(deepLink)
            NotificationCenter.default.post(name: NotificationService.openDeepLinkEvent, object: nil)
            completionHandler()
            return
        }

        let destination = response.notification.request.content.userInfo[NotificationService.quickLedgerDestinationUserInfoKey] as? String
        guard destination == NotificationService.quickLedgerDestinationLedgerValue else {
            completionHandler()
            return
        }

        QuickLedgerNavigationState.shared.markOpenLedgerPending()
        NotificationCenter.default.post(name: NotificationService.quickLedgerOpenLedgerEvent, object: nil)
        completionHandler()
    }

    private func configureHomeQuickActions(for application: UIApplication) {
        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: HomeQuickAction.addTransaction,
                localizedTitle: String(localized: "home_quick_action.add_transaction.title"),
                localizedSubtitle: String(localized: "home_quick_action.add_transaction.subtitle"),
                icon: UIApplicationShortcutIcon(systemImageName: "plus.circle"),
                userInfo: nil
            )
        ]
    }

    private static func registerHotelFolioInboxDeviceTokenIfPossible(_ deviceToken: String) async {
        let settings = HotelFolioInboxSettings()
        guard settings.canRequest else { return }
        do {
            try await HotelFolioInboxClient().registerDeviceToken(
                settings: settings,
                deviceToken: deviceToken
            )
        } catch {
            logger.error("Failed to register hotel folio inbox device token: \(error.localizedDescription)")
        }
    }
}
