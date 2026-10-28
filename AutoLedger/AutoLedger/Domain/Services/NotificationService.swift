import AutoLedgerCore
import Foundation
import os.log
import UserNotifications
import WidgetKit

final class NotificationService: Sendable {
    static let shared = NotificationService()
    static let quickLedgerOpenLedgerEvent = Notification.Name("AutoLedger.quickLedgerOpenLedgerEvent")
    static let openNewTransactionEvent = Notification.Name("AutoLedger.openNewTransactionEvent")
    static let openDeepLinkEvent = Notification.Name("AutoLedger.openDeepLinkEvent")
    static let editQuickLedgerTransactionEvent = Notification.Name("AutoLedger.editQuickLedgerTransactionEvent")
    static let quickLedgerCategoryIdentifier = "AUTOLEDGER_QUICK_LEDGER_SUCCESS"
    static let quickLedgerEditActionIdentifier = "AUTOLEDGER_QUICK_LEDGER_EDIT"
    static let quickLedgerUndoActionIdentifier = "AUTOLEDGER_QUICK_LEDGER_UNDO"
    /// 外部入口入账或撤销成功后发送，通知 LedgerStore 刷新
    static let didSaveTransactionFromIntent = Notification.Name("AutoLedger.didSaveTransactionFromIntent")
    static let quickLedgerDestinationUserInfoKey = "destination"
    static let quickLedgerDestinationLedgerValue = "ledger"
    static let quickLedgerTransactionIDUserInfoKey = "transactionID"
    static let deepLinkUserInfoKey = "autoledgerDeepLink"
    /// 略微延迟，避免与快捷指令完成瞬间的系统 UI 切换抢占展示
    static let quickLedgerNotificationDelay: TimeInterval = 1
    private static let pendingIntentLedgerCloudPushKey = "pendingIntentLedgerCloudPush"
    private static let remoteDeviceTokenKey = "autoLedgerRemoteDeviceToken"
    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let logger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "NotificationService")
    private static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
    }
    private static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

    static var hasPendingIntentLedgerCloudPush: Bool {
        UserDefaults.standard.bool(forKey: pendingIntentLedgerCloudPushKey) ||
            (appGroupDefaults?.bool(forKey: pendingIntentLedgerCloudPushKey) ?? false)
    }

    static func markIntentLedgerSaveNeedsCloudPush() {
        UserDefaults.standard.set(true, forKey: pendingIntentLedgerCloudPushKey)
        appGroupDefaults?.set(true, forKey: pendingIntentLedgerCloudPushKey)
    }

    static func clearIntentLedgerSaveNeedsCloudPush() {
        UserDefaults.standard.removeObject(forKey: pendingIntentLedgerCloudPushKey)
        appGroupDefaults?.removeObject(forKey: pendingIntentLedgerCloudPushKey)
    }

    @discardableResult
    static func storeRemoteDeviceToken(_ deviceToken: Data) -> String {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: remoteDeviceTokenKey)
        appGroupDefaults?.set(token, forKey: remoteDeviceTokenKey)
        return token
    }

    static var remoteDeviceToken: String? {
        let token = UserDefaults.standard.string(forKey: remoteDeviceTokenKey) ??
            appGroupDefaults?.string(forKey: remoteDeviceTokenKey)
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    // MARK: - Permission

    func requestPermissionIfNeeded() {
        guard !Self.isScreenshotMode else { return }
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

    func registerNotificationCategories() {
        let edit = UNNotificationAction(
            identifier: Self.quickLedgerEditActionIdentifier,
            title: String(localized: "common.edit"),
            options: [.foreground]
        )
        let undo = UNNotificationAction(
            identifier: Self.quickLedgerUndoActionIdentifier,
            title: String(localized: "notification.quick_ledger.undo"),
            options: [.authenticationRequired, .destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.quickLedgerCategoryIdentifier,
            actions: [edit, undo],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func removeQuickLedgerSuccessNotification(transactionID: UUID) {
        let identifiers = ["quick-ledger-success-\(transactionID.uuidString)"]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func undoQuickLedgerTransaction(transactionID: UUID) async {
        do {
            // A background notification response may have no SwiftUI scene or
            // LedgerStore. Use the same durable trash as in-app deletion.
            let didDelete = try await Task.detached(priority: .userInitiated) {
                try SQLiteTransactionStore().deleteIfActive(transactionID: transactionID)
            }.value

            if didDelete {
                Self.markIntentLedgerSaveNeedsCloudPush()
                WidgetCenter.shared.reloadAllTimelines()
                // Watch snapshots prefer the live store when one exists.
                await LedgerStore.shared?.refreshFromStoreInBackground(afterExternalChange: true)
                WatchConnectivityHost.shared.publishLatestLedgerSnapshot()
                NotificationCenter.default.post(name: Self.didSaveTransactionFromIntent, object: nil)
            }
            removeQuickLedgerSuccessNotification(transactionID: transactionID)
            await scheduleQuickLedgerActionResult(
                transactionID: transactionID,
                title: didDelete
                    ? String(localized: "notification.quick_ledger.undone.title")
                    : String(localized: "notification.quick_ledger.unavailable.title"),
                body: didDelete
                    ? String(localized: "notification.quick_ledger.undone.body")
                    : String(localized: "notification.quick_ledger.unavailable.body")
            )
        } catch {
            Self.logger.error("Failed to undo quick ledger entry: \(error.localizedDescription)")
            await scheduleQuickLedgerActionResult(
                transactionID: transactionID,
                title: String(localized: "notification.quick_ledger.undo_failed.title"),
                body: String(localized: "notification.quick_ledger.undo_failed.body")
            )
        }
    }

    private func scheduleQuickLedgerActionResult(transactionID: UUID, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = [Self.quickLedgerDestinationUserInfoKey: Self.quickLedgerDestinationLedgerValue]
        let request = UNNotificationRequest(
            identifier: "quick-ledger-action-result-\(transactionID.uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Self.logger.error("Failed to schedule quick ledger action result: \(error.localizedDescription)")
        }
    }

    func scheduleUpcomingChargeReminders(for subscriptions: [Subscription]) {
        guard !Self.isScreenshotMode else { return }
        let center = UNUserNotificationCenter.current()
        // 移除旧的订阅提醒
        center.removePendingNotificationRequests(withIdentifiers:
            subscriptions.map { "sub-\($0.id.uuidString)" }
        )

        guard UserDefaults.standard.bool(forKey: "subscriptionReminder") else { return }

        for sub in subscriptions where sub.status.isActive {
            scheduleReminder(for: sub)
        }
    }

    func cancelSubscriptionReminder(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "sub-\(id.uuidString)"
        ])
    }

    func scheduleQuickLedgerSuccessNotification(
        merchant: String,
        amount: Double,
        currencyCode: String?,
        transactionID: UUID
    ) {
        guard !Self.isScreenshotMode else { return }
        registerNotificationCategories()
        let center = UNUserNotificationCenter.current()
        let formattedAmountText = AppFormatters.currency(amount, code: currencyCode)
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
                content.categoryIdentifier = Self.quickLedgerCategoryIdentifier
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
            AppFormatters.currency(sub.amount, code: sub.currencyCode),
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

}
