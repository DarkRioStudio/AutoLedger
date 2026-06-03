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
    var transactionCount: Int
    var recentDisplayName: String?
    var updatedAt: Date?
    var isSnapshotStale: Bool
    var savedAt: Date?

    static let empty = WatchLedgerWidgetSnapshot(
        ledgerName: WatchLedgerWidgetCopy.defaultLedgerName,
        totalExpense: 0,
        transactionCount: 0,
        recentDisplayName: nil,
        updatedAt: nil,
        isSnapshotStale: true,
        savedAt: nil
    )

    init(
        ledgerName: String,
        totalExpense: Double,
        transactionCount: Int,
        recentDisplayName: String?,
        updatedAt: Date?,
        isSnapshotStale: Bool,
        savedAt: Date?
    ) {
        self.ledgerName = ledgerName
        self.totalExpense = totalExpense
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
        String(format: "¥%.2f", totalExpense)
    }

    var compactAmount: String {
        if totalExpense >= 10_000 {
            return String(format: "¥%.1f万", totalExpense / 10_000)
        }
        if totalExpense >= 1_000 {
            return String(format: "¥%.0f", totalExpense)
        }
        return String(format: "¥%.2f", totalExpense)
    }

    var cornerAmount: String {
        if totalExpense >= 10_000 {
            return String(format: "¥%.0f万", totalExpense / 10_000)
        }
        return String(format: "¥%.0f", totalExpense)
    }

    var updatedDisplayText: String? {
        guard let updatedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: updatedAt)
    }
}

private enum WatchLedgerWidgetCopy {
    private static func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, bundle: .main, value: fallback, comment: "")
    }

    static var title: String {
        localized("widget.today.title", fallback: "Today")
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
            Image(systemName: "yensign.circle.fill")
        }
    }

    private var circularView: some View {
        Gauge(value: spendingProgress, in: 0...1) {
            Image(systemName: "yensign")
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
        Gauge(value: spendingProgress, in: 0...1) {
            Text(entry.snapshot.cornerAmount)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)
        } currentValueLabel: {
            EmptyView()
        } minimumValueLabel: {
            EmptyView()
        } maximumValueLabel: {
            EmptyView()
        }
        .gaugeStyle(.accessoryLinearCapacity)
        .tint(spendingTint)
        .widgetAccentable()
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "yensign.circle.fill")
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
