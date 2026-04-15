import Foundation
import UIKit
import UserNotifications

final class AutoLedgerAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let quickLedgerNavigationLock = NSLock()
    private static var quickLedgerOpenLedgerPending = false

    static func markQuickLedgerOpenLedgerPending() {
        quickLedgerNavigationLock.lock()
        quickLedgerOpenLedgerPending = true
        quickLedgerNavigationLock.unlock()
    }

    static func consumeQuickLedgerOpenLedgerPending() -> Bool {
        quickLedgerNavigationLock.lock()
        let pending = quickLedgerOpenLedgerPending
        quickLedgerOpenLedgerPending = false
        quickLedgerNavigationLock.unlock()
        return pending
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
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
        let destination = response.notification.request.content.userInfo[NotificationService.quickLedgerDestinationUserInfoKey] as? String
        guard destination == NotificationService.quickLedgerDestinationLedgerValue else {
            completionHandler()
            return
        }

        Self.markQuickLedgerOpenLedgerPending()
        NotificationCenter.default.post(name: NotificationService.quickLedgerOpenLedgerEvent, object: nil)
        completionHandler()
    }
}
