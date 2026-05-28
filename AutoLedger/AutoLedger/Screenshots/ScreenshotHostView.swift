import AutoLedgerCore
import SwiftUI

struct ScreenshotHostView: View {
    let scene: ScreenshotScene

    var body: some View {
        Group {
            switch scene {
            case .preview, .quickCapture:
                ScreenshotAppPage(scene: .inbox)
            case .importMethods:
                ScreenshotImportMethodsHost()
            case .autoExtract:
                ScreenshotAppPage(scene: .ledger)
            case .reviewEdit:
                ScreenshotTransactionEditorHost()
            case .monthlyReport:
                ScreenshotAppPage(scene: .report)
            case .settingsManagement:
                ScreenshotAppPage(scene: .settings)
            }
        }
        .dynamicTypeSize(.large)
    }
}

private struct ScreenshotAppPage: View {
    enum Scene {
        case inbox
        case ledger
        case report
        case settings
    }

    let scene: Scene
    @StateObject private var store: LedgerStore

    init(scene: Scene) {
        self.scene = scene
        ScreenshotFixtures.installUserDefaults()
        _store = StateObject(wrappedValue: LedgerStore(transactionStore: ScreenshotTransactionStore()))
    }

    var body: some View {
        Group {
            switch scene {
            case .inbox:
                InboxView(selectedTab: .constant(0))
            case .ledger:
                LedgerView()
            case .report:
                ReportView()
            case .settings:
                SettingsView()
            }
        }
        .environmentObject(store)
        .preferredColorScheme(.light)
    }
}

private struct ScreenshotTransactionEditorHost: View {
    @StateObject private var store: LedgerStore

    init() {
        ScreenshotFixtures.installUserDefaults()
        _store = StateObject(wrappedValue: LedgerStore(transactionStore: ScreenshotTransactionStore()))
    }

    var body: some View {
        TransactionEditorView(transaction: ScreenshotFixtures.transactions[0]) { _, _ in }
            .environmentObject(store)
            .preferredColorScheme(.light)
    }
}

private struct ScreenshotImportMethodsHost: View {
    private var copy: ScreenshotCopy { .current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("inbox.import.title")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        Text("inbox.import.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                    .padding(.top, 10)

                    ImportMethodRow(
                        icon: "photo.on.rectangle",
                        title: String(localized: "inbox.import.photo"),
                        subtitle: copy.text("读取支付截图和相册收据", "讀取支付截圖和相簿收據", "Read payment screenshots and saved receipts"),
                        tint: AppTheme.accent
                    )
                    ImportMethodRow(
                        icon: "camera.fill",
                        title: String(localized: "inbox.import.camera"),
                        subtitle: copy.text("现场拍摄纸质小票", "現場拍攝紙本收據", "Capture paper receipts on the spot"),
                        tint: AppTheme.accent
                    )
                    ImportMethodRow(
                        icon: "doc.on.clipboard",
                        title: String(localized: "inbox.import.clipboard"),
                        subtitle: String(localized: "inbox.import.hint"),
                        tint: AppTheme.accentSecondary
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("AutoLedger")
        }
        .preferredColorScheme(.light)
    }
}

private struct ImportMethodRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(18)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ScreenshotCopy {
    let languageCode: String

    static var current: ScreenshotCopy {
        let locale = ScreenshotModeConfig.localeIdentifier.lowercased()
        if locale.hasPrefix("en") {
            return ScreenshotCopy(languageCode: "en")
        }
        if locale.hasPrefix("zh_hant") || locale.hasPrefix("zh-hant") || locale.hasPrefix("zh_tw") {
            return ScreenshotCopy(languageCode: "zh-Hant")
        }
        return ScreenshotCopy(languageCode: "zh-Hans")
    }

    func text(_ zhHans: String, _ zhHant: String, _ en: String) -> String {
        switch languageCode {
        case "en":
            en
        case "zh-Hant":
            zhHant
        default:
            zhHans
        }
    }
}

private enum ScreenshotFixtures {
    static let baseDate: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 8
        components.hour = 10
        components.minute = 24
        return components.date ?? Date(timeIntervalSince1970: 1_778_203_440)
    }()

    static let transactions: [Transaction] = [
        Transaction(merchant: "Blue Bottle Coffee", amount: 36, occurredAt: baseDate, category: .dining, source: .wechat, note: String(localized: "note.photo_import")),
        Transaction(merchant: "Apple Services", amount: 68, occurredAt: baseDate.addingTimeInterval(-7_200), category: .digital, source: .appStore, note: String(localized: "quick_ledger.note")),
        Transaction(merchant: "City Metro", amount: 7, occurredAt: baseDate.addingTimeInterval(-18_000), category: .transport, source: .alipay, note: ""),
        Transaction(merchant: "Hema Fresh", amount: 128.6, occurredAt: baseDate.addingTimeInterval(-86_400), category: .groceries, source: .unionPay, note: ""),
        Transaction(merchant: "MUJI", amount: 239, occurredAt: baseDate.addingTimeInterval(-172_800), category: .shopping, source: .manual, note: ""),
        Transaction(merchant: "Spotify", amount: 18, occurredAt: baseDate.addingTimeInterval(-259_200), category: .digital, source: .appStore, note: "Subscription")
    ]

    static func installUserDefaults() {
        UserDefaults.standard.set(["WeChat Pay", "Alipay", "App Store", "Watch"], forKey: "customSources")
        UserDefaults.standard.set(["Coffee", "Work", "Family"], forKey: "customCategories")
        UserDefaults.standard.set(["BlueBottle": "Blue Bottle Coffee"], forKey: "merchantAliases")
        UserDefaults.standard.set(false, forKey: "subscriptionReminder")
        UserDefaults.standard.set(false, forKey: "autoClipboardImport")
    }
}

private final class ScreenshotTransactionStore: TransactionStore, @unchecked Sendable {
    private var transactions = ScreenshotFixtures.transactions

    func loadTransactions() throws -> [Transaction] {
        transactions
    }

    func save(transaction: Transaction) throws {
        transactions.insert(transaction, at: 0)
    }

    func update(transaction: Transaction) throws {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        transactions[index] = transaction
    }

    func delete(transactionID: UUID) throws {
        transactions.removeAll { $0.id == transactionID }
    }

    func bootstrapIfNeeded(with transactions: [Transaction]) throws -> [Transaction] {
        self.transactions
    }
}

#Preview {
    ScreenshotHostView(scene: .preview)
}
