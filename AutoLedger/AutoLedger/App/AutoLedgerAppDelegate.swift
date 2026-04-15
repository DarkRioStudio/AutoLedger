import Foundation
import UIKit
import UserNotifications

final class AutoLedgerAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
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

        UserDefaults.standard.set(true, forKey: NotificationService.quickLedgerPendingOpenLedgerKey)
        NotificationCenter.default.post(name: NotificationService.quickLedgerOpenLedgerEvent, object: nil)
        completionHandler()
    }
}
