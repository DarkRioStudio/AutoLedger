import AutoLedgerCore
import SwiftUI

struct WatchScreenshotHostView: View {
    let scene: WatchScreenshotScene

    private var copy: WatchScreenshotCopy { .current }

    var body: some View {
        Group {
            switch scene {
            case .quickAdd:
                WatchQuickAddScreenshot()
            case .recent:
                WatchRecentScreenshot()
            case .complication:
                WatchComplicationScreenshot(copy: copy)
            case .sync:
                WatchSyncScreenshot(copy: copy)
            }
        }
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.large)
    }
}

private struct WatchScreenshotCopy {
    let languageCode: String

    static var current: WatchScreenshotCopy {
        let locale = WatchScreenshotModeConfig.localeIdentifier.lowercased()
        if locale.hasPrefix("en") {
            return WatchScreenshotCopy(languageCode: "en")
        }
        if locale.hasPrefix("ja") {
            return WatchScreenshotCopy(languageCode: "ja")
        }
        if locale.hasPrefix("ko") {
            return WatchScreenshotCopy(languageCode: "ko")
        }
        if locale.hasPrefix("zh_hant") || locale.hasPrefix("zh-hant") || locale.hasPrefix("zh_tw") {
            return WatchScreenshotCopy(languageCode: "zh-Hant")
        }
        return WatchScreenshotCopy(languageCode: "zh-Hans")
    }

    func text(_ zhHans: String, _ zhHant: String, _ en: String, _ ja: String? = nil) -> String {
        switch languageCode {
        case "en":
            en
        case "ja":
            ja ?? en
        case "ko":
            Self.korean[zhHans] ?? en
        case "zh-Hant":
            zhHant
        default:
            zhHans
        }
    }

    private static let korean: [String: String] = [
        "午饭": "점심",
        "咖啡": "커피",
        "快速记账": "빠른 기록",
        "表盘可见": "시계 페이스",
        "今日支出": "오늘 지출",
        "把今日支出和快速入口放到表盘上。": "오늘 지출과 빠른 실행을 시계 페이스에 표시하세요.",
        "与 iPhone 保持同步": "iPhone과 동기화",
        "手机端继续编辑和查看统计": "iPhone에서 편집하고 통계를 확인하세요",
        "待同步": "동기화 대기",
        "最近更新": "최근 업데이트",
        "同步": "동기화",
    ]
}

private enum WatchScreenshotFixtures {
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

    static func recentViewModel() -> WatchLedgerViewModel {
        let viewModel = WatchLedgerViewModel()
        viewModel.recentTransactions = [
            WatchTransaction(merchant: "Demo Coffee", amount: 18, note: "Dining", occurredAt: baseDate),
            WatchTransaction(merchant: "City Metro", amount: 4, note: "Transport", occurredAt: baseDate.addingTimeInterval(-18_000)),
            WatchTransaction(merchant: "Example Market", amount: 86.5, note: "Groceries", occurredAt: baseDate.addingTimeInterval(-86_400))
        ]
        viewModel.todaySummary = WatchTodaySummary(
            ledgerName: "Local Ledger",
            totalExpense: 108.5,
            transactionCount: 3,
            recentDisplayName: "Demo Coffee",
            updatedAt: baseDate
        )
        viewModel.pendingCount = 0
        return viewModel
    }

    static func quickAddViewModel(copy: WatchScreenshotCopy = .current) -> WatchLedgerViewModel {
        let viewModel = WatchLedgerViewModel()
        viewModel.quickAddCategoryRaw = TransactionCategory.dining.rawValue
        viewModel.quickAddAmountText = "28.00"
        viewModel.quickAddMerchant = copy.text("午饭", "午餐", "Lunch", "ランチ")
        viewModel.customCategories = [copy.text("咖啡", "咖啡", "Coffee", "コーヒー")]
        return viewModel
    }
}

private struct WatchQuickAddScreenshot: View {
    @State private var viewModel = WatchScreenshotFixtures.quickAddViewModel(copy: .current)

    var body: some View {
        NavigationStack {
            QuickAddView()
                .environment(viewModel)
                .navigationTitle(copy.text("快速记账", "快速記帳", "Quick Add", "クイック記録"))
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var copy: WatchScreenshotCopy { .current }
}

private struct WatchRecentScreenshot: View {
    @State private var viewModel = WatchScreenshotFixtures.recentViewModel()

    var body: some View {
        ContentView()
            .environment(viewModel)
    }
}

private struct WatchComplicationScreenshot: View {
    let copy: WatchScreenshotCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: 0.54)
                        .stroke(
                            AngularGradient(
                                colors: [.green, .yellow, .orange, .red],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(135))
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .offset(x: -24, y: 18)
                    Text("52.26")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "applewatch")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.green)
                    Text(copy.text("表盘可见", "錶盤可見", "Face", "文字盤"))
                        .font(.headline)
                        .lineLimit(2)
                    Text(copy.text("今日支出", "今日支出", "Today", "今日"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(copy.text(
                "把今日支出和快速入口放到表盘上。",
                "把今日支出和快速入口放到錶盤上。",
                "Keep today's spending and quick access on the watch face.",
                "今日の支出とクイックアクセスを文字盤に置けます。"
            ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .preferredColorScheme(.dark)
    }
}

private struct WatchSyncScreenshot: View {
    let copy: WatchScreenshotCopy

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(spacing: 10) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                        Text(copy.text("与 iPhone 保持同步", "與 iPhone 保持同步", "Syncs with iPhone", "iPhone と同期"))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(copy.text(
                            "手机端继续编辑和查看统计",
                            "手機端繼續編輯和查看統計",
                            "Continue editing and reviewing reports on iPhone",
                            "iPhone で編集とレポート確認を続けられます"
                        ))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    WatchField(label: copy.text("待同步", "待同步", "Pending", "同期待ち"), value: "1", icon: "arrow.triangle.2.circlepath")
                    WatchField(label: copy.text("最近更新", "最近更新", "Latest", "最新更新"), value: "10:24", icon: "clock.badge.checkmark")
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(copy.text("同步", "同步", "Sync", "同期"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct WatchField: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 18)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 3)
    }
}

#Preview {
    WatchScreenshotHostView(scene: .quickAdd)
}
