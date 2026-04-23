import AutoLedgerCore
import Foundation
import os.log
import UserNotifications

final class NotificationService: Sendable {
    static let shared = NotificationService()
    static let quickLedgerOpenLedgerEvent = Notification.Name("AutoLedger.quickLedgerOpenLedgerEvent")
    static let openNewTransactionEvent = Notification.Name("AutoLedger.openNewTransactionEvent")
    /// Intent 入账成功后发送，通知 LedgerStore 刷新
    static let didSaveTransactionFromIntent = Notification.Name("AutoLedger.didSaveTransactionFromIntent")
    static let quickLedgerDestinationUserInfoKey = "destination"
    static let quickLedgerDestinationLedgerValue = "ledger"
    static let quickLedgerTransactionIDUserInfoKey = "transactionID"
    /// 略微延迟，避免与快捷指令完成瞬间的系统 UI 切换抢占展示
    static let quickLedgerNotificationDelay: TimeInterval = 1
    private static let logger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "NotificationService")

    private init() {}

    // MARK: - Permission

    func requestPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
                guard let error else { return }
                Self.logger.error("Failed to request notification authorization: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Schedule

    func scheduleUpcomingChargeReminders(for subscriptions: [Subscription]) {
        let center = UNUserNotificationCenter.current()
        // 移除旧的订阅提醒
        center.removePendingNotificationRequests(withIdentifiers:
            subscriptions.map { "sub-\($0.id.uuidString)" }
        )

        guard UserDefaults.standard.bool(forKey: "subscriptionReminder") else { return }

        for sub in subscriptions {
            scheduleReminder(for: sub)
        }
    }

    func scheduleQuickLedgerSuccessNotification(merchant: String, amount: Double, transactionID: UUID) {
        let center = UNUserNotificationCenter.current()
        let formattedAmountText = String(format: "¥%.2f", amount)
        center.getNotificationSettings { settings in
            let scheduleNotification: () -> Void = {
                let content = UNMutableNotificationContent()
                content.title = String(localized: "notification.quick_ledger.title")
                content.body = String(
                    format: String(localized: "notification.quick_ledger.body_format"),
                    merchant,
                    formattedAmountText
                )
                content.sound = .default
                content.userInfo = [
                    Self.quickLedgerDestinationUserInfoKey: Self.quickLedgerDestinationLedgerValue,
                    Self.quickLedgerTransactionIDUserInfoKey: transactionID.uuidString
                ]

                let request = UNNotificationRequest(
                    identifier: "quick-ledger-success-\(transactionID.uuidString)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: Self.quickLedgerNotificationDelay, repeats: false)
                )
                center.add(request) { error in
                    if let error {
                        Self.logger.error("Failed to schedule quick ledger notification: \(error.localizedDescription)")
                    } else {
                        Self.logger.debug("Scheduled quick ledger success notification")
                    }
                }
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                scheduleNotification()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error {
                        Self.logger.error("Failed to request quick ledger notification authorization: \(error.localizedDescription)")
                    }
                    guard granted else { return }
                    scheduleNotification()
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    // MARK: - Private

    private func scheduleReminder(for sub: Subscription) {
        let center = UNUserNotificationCenter.current()

        // 提前 1 天提醒
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: sub.nextChargedAt) else { return }

        // 只提醒未来的日期
        guard reminderDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.subscription.title")
        content.body = String(
            format: String(localized: "notification.subscription.body_format"),
            sub.merchant,
            formattedAmount(sub.amount),
            sub.period.title
        )
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(
            identifier: "sub-\(sub.id.uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    private func formattedAmount(_ amount: Double) -> String {
        String(format: "¥%.2f", amount)
    }
}
