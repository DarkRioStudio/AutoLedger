import AutoLedgerCore
import Foundation
import UserNotifications

final class NotificationService: Sendable {
    static let shared = NotificationService()

    private init() {}

    // MARK: - Permission

    func requestPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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

    // MARK: - Private

    private func scheduleReminder(for sub: Subscription) {
        let center = UNUserNotificationCenter.current()

        // 提前 1 天提醒
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: sub.nextChargedAt) else { return }

        // 只提醒未来的日期
        guard reminderDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "明日扣费提醒"
        content.body = "\(sub.merchant) 将于明天扣费 \(formattedAmount(sub.amount))（\(sub.period.title)）"
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
