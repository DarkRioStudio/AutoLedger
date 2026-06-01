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
            case .confirm:
                WatchConfirmScreenshot()
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
        if locale.hasPrefix("zh_hant") || locale.hasPrefix("zh-hant") || locale.hasPrefix("zh_tw") {
            return WatchScreenshotCopy(languageCode: "zh-Hant")
        }
        return WatchScreenshotCopy(languageCode: "zh-Hans")
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
            WatchTransaction(merchant: "Blue Bottle", amount: 36, note: "Dining", occurredAt: baseDate),
            WatchTransaction(merchant: "City Metro", amount: 7, note: "Transport", occurredAt: baseDate.addingTimeInterval(-18_000)),
            WatchTransaction(merchant: "App Store", amount: 68, note: "Digital", occurredAt: baseDate.addingTimeInterval(-86_400))
        ]
        viewModel.todaySummary = WatchTodaySummary(
            ledgerName: "Local Ledger",
            totalExpense: 43,
            transactionCount: 2,
            recentDisplayName: "Blue Bottle",
            updatedAt: baseDate
        )
        viewModel.pendingCount = 0
        return viewModel
    }

    static func quickAddViewModel() -> WatchLedgerViewModel {
        let viewModel = WatchLedgerViewModel()
        viewModel.quickAddCategoryRaw = TransactionCategory.dining.rawValue
        viewModel.quickAddAmountText = "36.00"
        viewModel.quickAddMerchant = "Blue Bottle"
        viewModel.customCategories = ["咖啡"]
        return viewModel
    }

    static func confirmViewModel() -> WatchLedgerViewModel {
        let viewModel = WatchLedgerViewModel()
        viewModel.voiceDraft = WatchLedgerDraft(merchant: "Blue Bottle", amount: 36, category: .dining, occurredAt: baseDate)
        viewModel.customCategories = ["咖啡"]
        return viewModel
    }
}

private struct WatchQuickAddScreenshot: View {
    @State private var viewModel = WatchScreenshotFixtures.quickAddViewModel()

    var body: some View {
        NavigationStack {
            QuickAddView()
                .environment(viewModel)
        }
    }
}

private struct WatchRecentScreenshot: View {
    @State private var viewModel = WatchScreenshotFixtures.recentViewModel()

    var body: some View {
        ContentView()
            .environment(viewModel)
    }
}

private struct WatchConfirmScreenshot: View {
    @State private var viewModel = WatchScreenshotFixtures.confirmViewModel()

    var body: some View {
        NavigationStack {
            WatchVoiceConfirmView()
                .environment(viewModel)
        }
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
                        Text(copy.text("与 iPhone 保持同步", "與 iPhone 保持同步", "Syncs with iPhone"))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(copy.text("手机端继续编辑和查看统计", "手機端繼續編輯和查看統計", "Continue editing and reviewing reports on iPhone"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    WatchField(label: copy.text("待同步", "待同步", "Pending"), value: "1", icon: "arrow.triangle.2.circlepath")
                    WatchField(label: copy.text("最近更新", "最近更新", "Latest"), value: "10:24", icon: "clock.badge.checkmark")
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(copy.text("同步", "同步", "Sync"))
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
