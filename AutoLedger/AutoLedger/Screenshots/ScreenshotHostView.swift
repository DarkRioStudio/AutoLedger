import AutoLedgerCore
import SwiftUI

struct ScreenshotHostView: View {
    let platform: ScreenshotPlatform
    let sceneIdentifier: String

    var body: some View {
        Group {
            switch platform {
            case .ios:
                switch ScreenshotScene(rawValue: sceneIdentifier) ?? .preview {
                case .preview, .quickCapture:
                    ScreenshotAppPage(scene: .inbox)
                case .ocrBill:
                    ScreenshotOCRBillHost()
                case .voiceEntry:
                    ScreenshotVoiceEntryHost()
                case .watchEcosystem:
                    ScreenshotWatchEcosystemHost()
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
                case .emailFolioImport:
                    ScreenshotEmailFolioImportHost()
                case .cloudFolioInbox:
                    ScreenshotCloudFolioInboxHost()
                case .hotelStays:
                    ScreenshotHotelStaysHost()
                case .proSubscription:
                    ScreenshotProSubscriptionHost()
                }
            case .ipad:
                ScreenshotWorkspaceHost(section: screenshotWorkspaceSection(for: sceneIdentifier, platform: .ipad))
            case .mac:
                ScreenshotWorkspaceHost(section: screenshotWorkspaceSection(for: sceneIdentifier, platform: .mac))
            case .watch:
                ScreenshotAppPage(scene: .inbox)
            }
        }
        .dynamicTypeSize(.large)
    }

    private func screenshotWorkspaceSection(
        for sceneIdentifier: String,
        platform: ScreenshotPlatform
    ) -> IPadWorkspaceSection {
        switch platform {
        case .ipad:
            switch sceneIdentifier {
            case "workspace_capture":
                .capture
            case "workspace_ledger":
                .ledger
            case "workspace_reports":
                .reports
            case "workspace_review":
                .reviewQueue
            case "workspace_cleaning":
                .cleaning
            case "workspace_settings":
                .settings
            default:
                .overview
            }
        case .mac:
            switch sceneIdentifier {
            case "mac_capture":
                .capture
            case "mac_ledger":
                .ledger
            case "mac_reports":
                .reports
            case "mac_cleaning":
                .cleaning
            case "mac_settings":
                .settings
            default:
                .capture
            }
        case .ios, .watch:
            .overview
        }
    }
}

private struct ScreenshotEmailFolioImportHost: View {
    @StateObject private var store: LedgerStore

    init() {
        ScreenshotFixtures.installUserDefaults()
        if ScreenshotModeConfig.usesFreeProState {
            UserDefaults.standard.set(false, forKey: "autoLedgerProDevelopmentOverride")
        }
        _store = StateObject(wrappedValue: LedgerStore(transactionStore: ScreenshotTransactionStore()))
    }

    var body: some View {
        HotelFolioEmailImportView(targetLedgerID: nil) { _ in }
            .environmentObject(store)
            .preferredColorScheme(.light)
    }
}

private struct ScreenshotCloudFolioInboxHost: View {
    @StateObject private var store: LedgerStore

    init() {
        ScreenshotFixtures.installUserDefaults()
        _store = StateObject(wrappedValue: LedgerStore(transactionStore: ScreenshotTransactionStore()))
    }

    var body: some View {
        HotelFolioInboxImportView(targetLedgerID: nil) { _ in }
            .environmentObject(store)
            .preferredColorScheme(.light)
    }
}

private struct ScreenshotHotelStaysHost: View {
    @State private var selectedRecordID: UUID?

    var body: some View {
        HotelStayListView(
            records: ScreenshotHotelStayFixtures.records,
            drafts: ScreenshotHotelStayFixtures.drafts,
            transactions: ScreenshotHotelStayFixtures.transactions,
            selectedRecordID: $selectedRecordID,
            onImportPDF: {},
            onImportEmail: {},
            onImportCloudInbox: {},
            onReviewDraft: { _ in },
            onUpdateRecord: { _, _ in true },
            onDeleteRecord: { _ in true }
        )
        .preferredColorScheme(.light)
    }
}

private struct ScreenshotProSubscriptionHost: View {
    var body: some View {
        NavigationStack {
            AutoLedgerProView()
        }
        .preferredColorScheme(.light)
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
    @StateObject private var navigationState = AutoLedgerNavigationState()

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
        .environmentObject(navigationState)
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
        TransactionEditorView(transaction: ScreenshotFixtures.transactions[0]) { _, _, _ in true }
            .environmentObject(store)
            .preferredColorScheme(.light)
    }
}

private struct ScreenshotOCRBillHost: View {
    private var copy: ScreenshotCopy { .current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(copy.text("支付截图识别", "支付截圖識別", "Screenshot recognition", "スクリーンショット認識"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(copy.text(
                            "支付截图、小票和剪贴板文字都能整理成待保存账单。",
                            "支付截圖、小票和剪貼簿文字都能整理成待儲存帳單。",
                            "Payment screenshots, receipts, and copied text become ready-to-save records.",
                            "支払いスクリーンショット、レシート、コピーした文字を保存前の記録に整理します。"
                        ))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                    }
                    .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(copy.text("支付成功", "支付成功", "Payment complete", "支払い完了"))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            Text("¥18.00")
                                .font(.title.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                        }

                        Divider()

                        ScreenshotVoiceField(label: copy.text("商户", "商家", "Merchant", "加盟店"), value: "Demo Coffee")
                        ScreenshotVoiceField(label: copy.text("时间", "時間", "Time", "時刻"), value: copy.text("今天 09:41", "今天 09:41", "Today 09:41", "今日 09:41"))
                        ScreenshotVoiceField(label: copy.text("来源", "來源", "Source", "ソース"), value: copy.text("支付截图", "支付截圖", "Screenshot", "スクリーンショット"))
                    }
                    .padding(18)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                        Text(copy.text("自动生成待保存账单", "自動產生待儲存帳單", "Record ready to save", "保存前の記録を自動作成"))
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(copy.text("已识别", "已識別", "Recognized", "認識済み"), systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(AppTheme.accent)
                            Spacer()
                            Text("¥18.00")
                                .font(.title.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                        }

                        VStack(spacing: 10) {
                            ScreenshotVoiceField(label: copy.text("商户", "商家", "Merchant", "加盟店"), value: "Demo Coffee")
                            ScreenshotVoiceField(label: copy.text("分类", "分類", "Category", "カテゴリ"), value: copy.text("餐饮", "餐飲", "Dining", "食事"))
                            ScreenshotVoiceField(label: copy.text("时间", "時間", "Time", "時刻"), value: copy.text("今天 09:41", "今天 09:41", "Today 09:41", "今日 09:41"))
                        }
                    }
                    .padding(18)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

private struct ScreenshotWorkspaceHost: View {
    let section: IPadWorkspaceSection
    @StateObject private var store: LedgerStore
    @StateObject private var navigationState = AutoLedgerNavigationState()

    init(section: IPadWorkspaceSection) {
        self.section = section
        ScreenshotFixtures.installUserDefaults()
        if ScreenshotModeConfig.usesFreeProState {
            UserDefaults.standard.set(false, forKey: "autoLedgerProDevelopmentOverride")
        }
        _store = StateObject(wrappedValue: LedgerStore(transactionStore: ScreenshotTransactionStore()))
    }

    var body: some View {
        IPadWorkspaceView(initialSection: section)
            .environmentObject(store)
            .environmentObject(navigationState)
            .preferredColorScheme(.light)
    }
}

private struct ScreenshotWatchEcosystemHost: View {
    private var copy: ScreenshotCopy { .current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(copy.text("腕上快速记账", "腕上快速記帳", "Wrist-first logging", "手首からすばやく記録"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(copy.text(
                            "在 Apple Watch 上随手记录，回到 iPhone 继续查看和编辑。",
                            "在 Apple Watch 上隨手記錄，回到 iPhone 繼續查看和編輯。",
                            "Start from Apple Watch, then review and edit on iPhone.",
                            "Apple Watch で記録し、iPhone で確認と編集を続けられます。"
                        ))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                    }
                    .padding(.top, 10)

                    HStack(alignment: .center, spacing: 14) {
                        VStack(spacing: 12) {
                            Image(systemName: "applewatch")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(copy.text("今日支出", "今日支出", "Today", "今日"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.75))
                            Text("¥52.26")
                                .font(.title2.weight(.black))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text(copy.text("2 笔", "2 筆", "2 records", "2 件"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(width: 132, height: 172)
                        .background(.black, in: RoundedRectangle(cornerRadius: 42, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 42, style: .continuous)
                                .stroke(.white.opacity(0.16), lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            Label(copy.text("抬腕记一笔", "抬腕記一筆", "Quick add", "クイック追加"), systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.accent)
                            Text(copy.text(
                                "金额和最近账单会同步回 iPhone。",
                                "金額和最近帳單會同步回 iPhone。",
                                "Amounts and recent records sync back to iPhone.",
                                "金額と最近の記録は iPhone に同期されます。"
                            ))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Demo Coffee")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    Text(copy.text("刚刚同步", "剛剛同步", "Synced just now", "同期したばかり"))
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.mutedInk)
                                }
                                Spacer()
                                Text("¥18.00")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(AppTheme.ink)
                            }
                            .padding(12)
                            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(18)
                    .background(AppTheme.card.opacity(0.75), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Label(copy.text("iPhone 继续整理", "iPhone 繼續整理", "Continue on iPhone", "iPhone で続ける"), systemImage: "iphone")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        ScreenshotVoiceField(label: copy.text("最近", "最近", "Latest", "最新"), value: "Demo Coffee ¥18.00")
                        ScreenshotVoiceField(label: copy.text("同步", "同步", "Sync", "同期"), value: copy.text("已完成", "已完成", "Done", "完了"))
                    }
                    .padding(18)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                        subtitle: copy.text("读取支付截图和相册收据", "讀取支付截圖和相簿收據", "Read payment screenshots and saved receipts", "支払いスクリーンショットと保存済みレシートを読み取ります"),
                        tint: AppTheme.accent
                    )
                    ImportMethodRow(
                        icon: "camera.fill",
                        title: String(localized: "inbox.import.camera"),
                        subtitle: copy.text("现场拍摄纸质小票", "現場拍攝紙本收據", "Capture paper receipts on the spot", "紙のレシートをその場で撮影できます"),
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

private struct ScreenshotVoiceEntryHost: View {
    private var copy: ScreenshotCopy { .current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(copy.text("一句话记账", "一句話記帳", "Voice entry", "一言で記録"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(copy.text(
                            "输入一句“午饭 28 元”，自动整理成待保存账单。",
                            "輸入一句「午餐 28 元」，自動整理成待儲存帳單。",
                            "Enter a simple sentence and get a ready-to-save record.",
                            "「ランチ 28 元」のような一言から保存前の記録を作成します。"
                        ))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                    }
                    .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.accentSecondary)
                            Text(copy.text("午饭 28 元", "午餐 28 元", "Lunch 28 yuan", "ランチ 28 元"))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                        }
                        Text(copy.text(
                            "像说一句话一样输入，AutoLedger 会准备好待保存账单。",
                            "像說一句話一樣輸入，AutoLedger 會準備好待儲存帳單。",
                            "Type or say a short sentence and get a ready-to-save record.",
                            "短い文を入力するだけで、AutoLedger が保存前の記録を用意します。"
                        ))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                    }
                    .padding(18)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(copy.text("已生成账单", "已產生帳單", "Record ready", "記録を作成済み"), systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.accent)
                            Spacer()
                            Text("¥28.00")
                                .font(.title.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                        }

                        VStack(spacing: 10) {
                            ScreenshotVoiceField(label: copy.text("商户", "商家", "Merchant", "加盟店"), value: copy.text("午饭", "午餐", "Lunch", "ランチ"))
                            ScreenshotVoiceField(label: copy.text("分类", "分類", "Category", "カテゴリ"), value: copy.text("餐饮", "餐飲", "Dining", "食事"))
                            ScreenshotVoiceField(label: copy.text("时间", "時間", "Time", "時刻"), value: copy.text("今天 12:20", "今天 12:20", "Today 12:20", "今日 12:20"))
                        }
                    }
                    .padding(18)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

private struct ScreenshotVoiceField: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.vertical, 5)
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
        if locale.hasPrefix("ja") {
            return ScreenshotCopy(languageCode: "ja")
        }
        if locale.hasPrefix("zh_hant") || locale.hasPrefix("zh-hant") || locale.hasPrefix("zh_tw") {
            return ScreenshotCopy(languageCode: "zh-Hant")
        }
        return ScreenshotCopy(languageCode: "zh-Hans")
    }

    func text(_ zhHans: String, _ zhHant: String, _ en: String, _ ja: String? = nil) -> String {
        switch languageCode {
        case "en":
            en
        case "ja":
            ja ?? en
        case "zh-Hant":
            zhHant
        default:
            zhHans
        }
    }
}

private enum ScreenshotFixtures {
    static let baseDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        var components = calendar.dateComponents([.year, .month], from: Date())
        components.calendar = calendar
        components.day = 18
        components.hour = 10
        components.minute = 24
        return components.date ?? Date(timeIntervalSince1970: 1_780_196_640)
    }()

    static let transactions: [Transaction] = [
        Transaction(merchant: "午饭", amount: 28, occurredAt: baseDate, category: .dining, source: .manual, note: String(localized: "quick_ledger.note")),
        Transaction(merchant: "Demo Coffee", amount: 18, occurredAt: baseDate.addingTimeInterval(-7_200), category: .dining, source: .wechat, note: String(localized: "note.photo_import")),
        Transaction(merchant: "City Metro", amount: 4, occurredAt: baseDate.addingTimeInterval(-18_000), category: .transport, source: .alipay, note: ""),
        Transaction(merchant: "Example Market", amount: 86.5, occurredAt: baseDate.addingTimeInterval(-86_400), category: .groceries, source: .unionPay, note: ""),
        Transaction(merchant: "Sample Cinema", amount: 45, occurredAt: baseDate.addingTimeInterval(-172_800), category: .entertainment, source: .manual, note: ""),
        Transaction(merchant: "Mobile Carrier", amount: 50, occurredAt: baseDate.addingTimeInterval(-259_200), category: .utilities, source: .manual, note: ""),
        Transaction(merchant: "Bookstore", amount: 39, occurredAt: baseDate.addingTimeInterval(-345_600), category: .shopping, source: .manual, note: ""),
        Transaction(merchant: "Delivery Dinner", amount: 32, occurredAt: baseDate.addingTimeInterval(-432_000), category: .dining, source: .manual, note: "")
    ]

    static func installUserDefaults() {
        UserDefaults.standard.set(["WeChat Pay", "Alipay", "App Store", "Watch"], forKey: "customSources")
        UserDefaults.standard.set(["Coffee", "Work", "Family"], forKey: "customCategories")
        UserDefaults.standard.set(["DemoCafe": "Demo Coffee"], forKey: "merchantAliases")
        UserDefaults.standard.set(false, forKey: "subscriptionReminder")
        UserDefaults.standard.set(false, forKey: "autoClipboardImport")
    }
}

private enum ScreenshotHotelStayFixtures {
    static let stayID = UUID(uuidString: "00000000-0000-0000-0000-000000001920")!
    static let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000001921")!
    static let draftID = UUID(uuidString: "00000000-0000-0000-0000-000000001922")!

    static let records = [
        HotelStayRecord(
            id: stayID,
            ledgerID: TodaySpendingSummary.defaultLedgerID,
            linkedTransactionID: transactionID,
            hotelName: "重庆 Moxy 酒店",
            hotelGroup: "万豪国际集团",
            hotelBrand: "Moxy",
            city: "重庆",
            country: "中国",
            checkInDate: "2026-06-22",
            checkOutDate: "2026-06-23",
            nights: 1,
            roomType: "城市景观大床房",
            confirmationNumber: "49046209",
            currency: "CNY",
            roomCharge: 325,
            taxAmount: 28.5,
            serviceCharge: 15.89,
            foodBeverageAmount: 0,
            otherAmount: 0,
            totalAmount: 369.39,
            paymentMethod: "Visa",
            sourceType: .manualPDF,
            sourceFileName: "moxy-chongqing-folio.pdf",
            localizedData: HotelStayLocalizedData(
                hotelName: "重庆 Moxy 酒店",
                brand: "Moxy",
                group: "万豪国际集团",
                city: "重庆",
                country: "中国",
                roomType: "城市景观大床房",
                currency: "CNY",
                roomCharge: 325,
                taxAmount: 28.5,
                serviceCharge: 15.89,
                foodBeverageAmount: 0,
                otherAmount: 0,
                totalAmount: 369.39,
                paymentMethod: "Visa"
            ),
            confidence: 0.94,
            rawText: "Moxy Chongqing\nRoom charge CNY 325.00\nTax CNY 28.50\nTotal CNY 369.39"
        )
    ]

    static let drafts = [
        HotelStayDraft(
            id: draftID,
            sourceType: .cloudWorker,
            targetLedgerID: TodaySpendingSummary.defaultLedgerID,
            sourceFileName: "beihai-marriott-folio.pdf",
            sourceEmailSubject: "北海万豪度假酒店的电子账单",
            sourceEmailFrom: "folio@getautoledger.app",
            rawText: "Beihai Marriott Resort\nTotal CNY 1280.00",
            parsedPayload: HotelFolioParsedPayload(
                hotelName: "Beihai Marriott Resort",
                brand: "Marriott",
                group: "Marriott International",
                city: "Beihai",
                country: "China",
                checkInDate: "2026-06-20",
                checkOutDate: "2026-06-22",
                nights: 2,
                roomType: "Sea View King",
                confirmationNumber: "ABC123",
                currency: "CNY",
                roomCharge: 1120,
                tax: 120,
                serviceCharge: 40,
                foodBeverage: 0,
                otherCharges: 0,
                totalAmount: 1280,
                paymentMethod: "Visa",
                confidence: 0.88,
                rawTextExcerpt: "Beihai Marriott Resort Total CNY 1280.00"
            ),
            localizedData: HotelStayLocalizedData(
                hotelName: "北海万豪度假酒店",
                brand: "万豪",
                group: "万豪国际集团",
                city: "北海",
                country: "中国",
                roomType: "海景大床房",
                currency: "CNY",
                roomCharge: 1120,
                taxAmount: 120,
                serviceCharge: 40,
                foodBeverageAmount: 0,
                otherAmount: 0,
                totalAmount: 1280,
                paymentMethod: "Visa"
            ),
            confidence: 0.88,
            status: .needsReview
        )
    ]

    static let transactions = [
        Transaction(
            id: transactionID,
            merchant: "重庆 Moxy 酒店",
            amount: 369.39,
            occurredAt: AppFormatters.parseFlexibleDate("2026-06-23 16:00") ?? ScreenshotFixtures.baseDate,
            categoryLabel: TransactionCategory.hotel.rawValue,
            sourceLabel: ReceiptSource.manual.rawValue,
            note: "入住：2026-06-22；退房：2026-06-23；订单号：49046209",
            hotelStayRecordID: stayID
        )
    ]
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
    ScreenshotHostView(platform: .ios, sceneIdentifier: ScreenshotScene.preview.rawValue)
}
