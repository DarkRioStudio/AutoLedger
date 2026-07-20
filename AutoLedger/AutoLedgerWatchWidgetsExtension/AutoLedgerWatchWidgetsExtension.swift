//
//  AutoLedgerWatchWidgetsExtension.swift
//  AutoLedgerWatchWidgetsExtension
//
//  Created by 张津铖 on 2026/6/3.
//

import SwiftUI
import WidgetKit

private enum WatchLedgerWidgetSnapshotStore {
    static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    static let summaryKey = "WatchLedgerWidget.todaySummary"

    static func load() -> WatchLedgerWidgetSnapshot {
        guard
            let defaults = UserDefaults(suiteName: appGroupIdentifier),
            let dict = defaults.dictionary(forKey: summaryKey)
        else {
            return .empty
        }
        return WatchLedgerWidgetSnapshot(from: dict)
    }
}

private struct WatchLedgerWidgetSnapshot: Equatable {
    var ledgerName: String
    var totalExpense: Double
    var currencyCode: String
    var transactionCount: Int
    var recentDisplayName: String?
    var updatedAt: Date?
    var isSnapshotStale: Bool
    var savedAt: Date?

    static let empty = WatchLedgerWidgetSnapshot(
        ledgerName: WatchLedgerWidgetCopy.defaultLedgerName,
        totalExpense: 0,
        currencyCode: WatchLedgerWidgetFormatters.systemCurrencyCode,
        transactionCount: 0,
        recentDisplayName: nil,
        updatedAt: nil,
        isSnapshotStale: true,
        savedAt: nil
    )

    init(
        ledgerName: String,
        totalExpense: Double,
        currencyCode: String = WatchLedgerWidgetFormatters.systemCurrencyCode,
        transactionCount: Int,
        recentDisplayName: String?,
        updatedAt: Date?,
        isSnapshotStale: Bool,
        savedAt: Date?
    ) {
        self.ledgerName = ledgerName
        self.totalExpense = totalExpense
        self.currencyCode = WatchLedgerWidgetFormatters.resolvedCurrencyCode(currencyCode)
        self.transactionCount = transactionCount
        self.recentDisplayName = recentDisplayName
        self.updatedAt = updatedAt
        self.isSnapshotStale = isSnapshotStale
        self.savedAt = savedAt
    }

    init(from dict: [String: Any]) {
        let ledgerName = (dict["ledgerName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.ledgerName = ledgerName?.isEmpty == false
            ? ledgerName ?? WatchLedgerWidgetCopy.defaultLedgerName
            : WatchLedgerWidgetCopy.defaultLedgerName
        self.totalExpense = dict["totalExpense"] as? Double ?? 0
        self.currencyCode = WatchLedgerWidgetFormatters.resolvedCurrencyCode(dict["currencyCode"] as? String)
        self.transactionCount = dict["transactionCount"] as? Int ?? 0

        let recent = (dict["recentDisplayName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.recentDisplayName = recent?.isEmpty == false ? recent : nil

        if let updatedAt = dict["updatedAt"] as? Double {
            self.updatedAt = Date(timeIntervalSince1970: updatedAt)
        } else {
            self.updatedAt = nil
        }
        if let savedAt = dict["savedAt"] as? Double {
            self.savedAt = Date(timeIntervalSince1970: savedAt)
        } else {
            self.savedAt = nil
        }
        self.isSnapshotStale = dict["isSnapshotStale"] as? Bool ?? false
    }

    var formattedAmount: String {
        WatchLedgerWidgetFormatters.currency(totalExpense, code: currencyCode)
    }

    var compactAmount: String {
        WatchLedgerWidgetFormatters.currency(totalExpense, code: currencyCode, compact: true)
    }

    var cornerAmount: String {
        WatchLedgerWidgetFormatters.decimal(totalExpense, code: currencyCode)
    }

    var updatedDisplayText: String? {
        guard let updatedAt else { return nil }
        return WatchLedgerWidgetFormatters.time(updatedAt)
    }
}

private enum WatchLedgerWidgetFormatters {
    static var systemCurrencyCode: String {
        Locale.autoupdatingCurrent.currency?.identifier.uppercased() ?? "USD"
    }

    static func resolvedCurrencyCode(_ value: String?) -> String {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        return normalized.count == 3 ? normalized : systemCurrencyCode
    }

    static func currency(_ amount: Double, code: String?, compact: Bool = false) -> String {
        let resolvedCode = resolvedCurrencyCode(code)
        let digits = ["JPY", "KRW", "VND", "IDR"].contains(resolvedCode) ? 0 : 2
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .currency
        formatter.currencyCode = resolvedCode
        formatter.minimumFractionDigits = compact ? 0 : digits
        formatter.maximumFractionDigits = compact ? min(digits, 1) : digits
        return formatter.string(from: NSNumber(value: amount)) ?? "\(resolvedCode) \(amount)"
    }

    static func decimal(_ amount: Double, code: String?) -> String {
        let resolvedCode = resolvedCurrencyCode(code)
        let digits = ["JPY", "KRW", "VND", "IDR"].contains(resolvedCode) ? 0 : 2
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: date)
    }
}

private enum WatchLedgerWidgetCopy {
    private static func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, bundle: .main, value: fallback, comment: "")
    }

    static var title: String {
        localized("widget.today.title", fallback: "Today")
    }

    static var cornerTextTitle: String {
        localized("widget.corner_text.title", fallback: "Today Text")
    }

    static var defaultLedgerName: String {
        localized("widget.default_ledger", fallback: "Local Ledger")
    }

    static var emptyTitle: String {
        localized("widget.no_expense", fallback: "No expense")
    }

    static func countText(_ count: Int) -> String {
        String(format: localized("widget.count_format", fallback: "%d items"), count)
    }

    static func updatedText(_ time: String) -> String {
        String(format: localized("widget.updated_format", fallback: "Updated %@"), time)
    }

    static var staleText: String {
        localized("widget.sync_pending", fallback: "Sync pending")
    }

    static var configurationDescription: String {
        localized(
            "widget.today.description",
            fallback: "View today's AutoLedger spending on the watch face."
        )
    }

    static var cornerTextConfigurationDescription: String {
        localized(
            "widget.corner_text.description",
            fallback: "Show today's spending as a watch face corner label."
        )
    }

    static func cornerText(_ amount: String) -> String {
        String(format: localized("widget.corner_text.format", fallback: "Today: %@"), amount)
    }
}

private struct WatchDailyExpenseEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchLedgerWidgetSnapshot
}

private struct WatchDailyExpenseProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchDailyExpenseEntry {
        WatchDailyExpenseEntry(
            date: .now,
            snapshot: WatchLedgerWidgetSnapshot(
                ledgerName: WatchLedgerWidgetCopy.defaultLedgerName,
                totalExpense: 32.80,
                transactionCount: 2,
                recentDisplayName: "Demo Coffee",
                updatedAt: .now,
                isSnapshotStale: false,
                savedAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchDailyExpenseEntry) -> Void) {
        completion(WatchDailyExpenseEntry(date: .now, snapshot: WatchLedgerWidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchDailyExpenseEntry>) -> Void) {
        let entry = WatchDailyExpenseEntry(date: .now, snapshot: WatchLedgerWidgetSnapshotStore.load())
        let nextRefresh = Calendar.autoupdatingCurrent.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private struct WatchDailyExpenseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchDailyExpenseEntry

    private var spendingProgress: Double {
        min(max(entry.snapshot.totalExpense / 200, 0), 1)
    }

    private var spendingTint: Color {
        switch spendingProgress {
        case ..<0.5:
            return .green
        case ..<0.8:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineView
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryRectangular:
            rectangularView
        default:
            rectangularView
        }
    }

    private var inlineView: some View {
        Label {
            Text("\(WatchLedgerWidgetCopy.title) \(entry.snapshot.compactAmount)")
        } icon: {
            Image(systemName: "banknote.fill")
        }
    }

    private var circularView: some View {
        Gauge(value: spendingProgress, in: 0...1) {
            Image(systemName: "banknote")
        } currentValueLabel: {
            Text(entry.snapshot.compactAmount)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .lineLimit(1)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(spendingTint)
    }

    private var cornerView: some View {
        Text(entry.snapshot.cornerAmount)
            .font(.system(size: 36, weight: .black, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.32)
            .lineLimit(1)
            .widgetAccentable()
            .widgetLabel {
                cornerGauge
            }
            .accessibilityLabel("\(WatchLedgerWidgetCopy.title) \(entry.snapshot.cornerAmount)")
    }

    private var cornerGauge: some View {
        Gauge(value: spendingProgress, in: 0...1) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        } minimumValueLabel: {
            EmptyView()
        } maximumValueLabel: {
            EmptyView()
        }
        .gaugeStyle(.accessoryLinearCapacity)
        .tint(
            LinearGradient(
                colors: [.green, .yellow, .orange, .red],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .accessibilityLabel(WatchLedgerWidgetCopy.title)
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "banknote.fill")
                Text(WatchLedgerWidgetCopy.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.snapshot.formattedAmount)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.64)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Text(secondaryText)
                    .lineLimit(1)
                if entry.snapshot.isSnapshotStale {
                    Image(systemName: "icloud.slash")
                        .imageScale(.small)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .widgetAccentable()
    }

    private var secondaryText: String {
        if entry.snapshot.isSnapshotStale {
            return WatchLedgerWidgetCopy.staleText
        }
        if let recentDisplayName = entry.snapshot.recentDisplayName {
            return recentDisplayName
        }
        if let updatedDisplayText = entry.snapshot.updatedDisplayText {
            return WatchLedgerWidgetCopy.updatedText(updatedDisplayText)
        }
        return entry.snapshot.transactionCount == 0
            ? WatchLedgerWidgetCopy.emptyTitle
            : WatchLedgerWidgetCopy.countText(entry.snapshot.transactionCount)
    }
}

private struct WatchDailyExpenseCornerTextWidgetView: View {
    let entry: WatchDailyExpenseEntry

    var body: some View {
        Image(systemName: "banknote.fill")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .widgetAccentable()
            .widgetLabel {
                Text(WatchLedgerWidgetCopy.cornerText(entry.snapshot.cornerAmount))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .accessibilityLabel(WatchLedgerWidgetCopy.cornerText(entry.snapshot.cornerAmount))
    }
}

struct AutoLedgerWatchWidgetsExtension: Widget {
    let kind: String = "AutoLedgerWatchDailyExpenseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchDailyExpenseProvider()) { entry in
            WatchDailyExpenseWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(WatchLedgerWidgetCopy.title)
        .description(WatchLedgerWidgetCopy.configurationDescription)
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular, .accessoryCorner])
    }
}

struct AutoLedgerWatchCornerTextWidget: Widget {
    let kind: String = "AutoLedgerWatchCornerTextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchDailyExpenseProvider()) { entry in
            WatchDailyExpenseCornerTextWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(WatchLedgerWidgetCopy.cornerTextTitle)
        .description(WatchLedgerWidgetCopy.cornerTextConfigurationDescription)
        .supportedFamilies([.accessoryCorner])
    }
}

#Preview(as: .accessoryCorner) {
    AutoLedgerWatchWidgetsExtension()
} timeline: {
    WatchDailyExpenseEntry(
        date: .now,
        snapshot: WatchLedgerWidgetSnapshot(
            ledgerName: WatchLedgerWidgetCopy.defaultLedgerName,
            totalExpense: 32.80,
            transactionCount: 2,
            recentDisplayName: "Demo Coffee",
            updatedAt: .now,
            isSnapshotStale: false,
            savedAt: .now
        )
    )
}

#Preview("Corner Text", as: .accessoryCorner) {
    AutoLedgerWatchCornerTextWidget()
} timeline: {
    WatchDailyExpenseEntry(
        date: .now,
        snapshot: WatchLedgerWidgetSnapshot(
            ledgerName: WatchLedgerWidgetCopy.defaultLedgerName,
            totalExpense: 32.80,
            transactionCount: 2,
            recentDisplayName: "Demo Coffee",
            updatedAt: .now,
            isSnapshotStale: false,
            savedAt: .now
        )
    )
}

#Preview(as: .accessoryRectangular) {
    AutoLedgerWatchWidgetsExtension()
} timeline: {
    WatchDailyExpenseEntry(
        date: .now,
        snapshot: WatchLedgerWidgetSnapshot(
            ledgerName: WatchLedgerWidgetCopy.defaultLedgerName,
            totalExpense: 32.80,
            transactionCount: 2,
            recentDisplayName: "Demo Coffee",
            updatedAt: .now,
            isSnapshotStale: false,
            savedAt: .now
        )
    )
}
