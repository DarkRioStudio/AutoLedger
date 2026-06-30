import AutoLedgerCore
import Charts
import SwiftUI

struct ReportView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    @AppStorage("monthlyAnomalyThresholdPercent") private var anomalyThresholdPercent = 150.0
    @ScaledMetric(relativeTo: .largeTitle) private var totalAmountFontSize: CGFloat = 36
    @ScaledMetric(relativeTo: .caption) private var rankBadgeSize: CGFloat = 26
    @State private var selectedCategoryID: String?
    @State private var selectedMonth: Date = .now
    @State private var selectedTrendLabel: String?
    private let insightService = MonthlyInsightService()
    private let summaryColumns = [
        GridItem(.adaptive(minimum: 88), spacing: 12, alignment: .top)
    ]

    private var isCurrentMonth: Bool {
        AppFormatters.calendar.isDate(selectedMonth, equalTo: .now, toGranularity: .month)
    }

    private func stepMonth(by value: Int) {
        guard let next = AppFormatters.calendar.date(byAdding: .month, value: value, to: selectedMonth) else { return }
        selectedMonth = next
        selectedCategoryID = nil
        selectedTrendLabel = nil
    }

    var body: some View {
        let snapshot = store.monthlySnapshot(for: selectedMonth)
        let scopedTransactions = store.visibleTransactions
        let anomalyAlerts = isCurrentMonth ? insightService.detectAnomalies(
            transactions: scopedTransactions,
            thresholdPercent: anomalyThresholdPercent
        ) : []

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AutoLedgerPageTitle("tab.report")

                    summaryCard(snapshot)

                    if !anomalyAlerts.isEmpty {
                        anomalySection(anomalyAlerts)
                    }

                    sectionTitle("report.category_breakdown.title")
                    if snapshot.categoryBreakdown.isEmpty {
                        emptyState("report.empty.month")
                    } else {
                        categoryDonut(snapshot)

                        ForEach(snapshot.categoryBreakdown) { metric in
                            let activeID = activeCategoryID(in: snapshot)
                            CategoryBreakdownRow(
                                metric: metric,
                                isSelected: activeID == metric.id,
                                isDimmed: activeID != nil && activeID != metric.id
                            )
                                .onTapGesture {
                                    changeSelectedCategory(to: selectedCategoryID == metric.id ? nil : metric.id)
                                }
                        }
                    }

                    sectionTitle("report.six_month_trend.title")
                    monthlyTrendChart(snapshot, selectedLabel: $selectedTrendLabel)

                    sectionTitle("report.top_merchants.title")
                    topMerchantRanking(snapshot)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .autoLedgerScreenChrome()
            .autoLedgerSolidNavigationBarChrome()
            .autoLedgerContentTitleNavigation("tab.report")
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { withOptionalAnimation(.easeInOut(duration: 0.18)) { stepMonth(by: -1) } } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel(Text("ledger.filter.previous_month"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { withOptionalAnimation(.easeInOut(duration: 0.18)) { stepMonth(by: 1) } } label: {
                        Image(systemName: "chevron.right")
                            .fontWeight(.semibold)
                    }
                    .disabled(isCurrentMonth)
                    .opacity(isCurrentMonth ? 0.35 : 1)
                    .accessibilityLabel(Text("ledger.filter.next_month"))
                }
            }
        }
    }

    private func anomalySection(_ alerts: [AnomalyAlert]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(AppTheme.accentSecondary)
                Text("report.anomaly.title")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(String(format: String(localized: "report.anomaly.threshold_format"), Int(anomalyThresholdPercent)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            ForEach(alerts.prefix(3)) { alert in
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: String(localized: "report.anomaly.category_high_format"), alert.categoryTitle))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text(String(format: String(localized: "report.anomaly.detail_format"), AppFormatters.currency(alert.currentTotal), AppFormatters.currency(alert.baselineAverage), alert.ratioPercent))
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.accentSecondary.opacity(0.10))
                )
            }
        }
        .padding(18)
        .autoLedgerCardSurface(cornerRadius: 22)
    }

    private func summaryCard(_ snapshot: MonthlySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.monthLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))

                Text(AppFormatters.currency(snapshot.totalExpense))
                    .font(.system(size: totalAmountFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 12) {
                summaryPill(titleKey: "report.summary.transactions", value: transactionCountText(snapshot.transactionCount))
                summaryPill(titleKey: "report.summary.top1", value: snapshot.topMerchant)
                summaryPill(
                    titleKey: "report.summary.merchant_count",
                    value: merchantCountText(snapshot.topMerchantMetrics.count)
                )
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerHeroSurface(cornerRadius: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(summaryAccessibilityLabel(snapshot)))
    }

    private func summaryPill(titleKey: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleKey)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.14))
        )
    }

    private func sectionTitle(_ titleKey: LocalizedStringKey) -> some View {
        Text(titleKey)
            .font(.title3.weight(.bold))
            .foregroundStyle(AppTheme.ink)
    }

    private func emptyState(_ textKey: LocalizedStringKey) -> some View {
        Text(textKey)
            .font(.subheadline)
            .foregroundStyle(AppTheme.mutedInk)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 20)
    }

    private func categoryDonut(_ snapshot: MonthlySnapshot) -> some View {
        let highlighted = highlightedCategory(in: snapshot)

        return ZStack {
            Chart(snapshot.categoryBreakdown) { metric in
                SectorMark(
                    angle: .value(String(localized: "report.chart.expense"), metric.total),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .foregroundStyle(metric.tint)
                .opacity(categoryOpacity(metric, in: snapshot))
            }
            .chartLegend(.hidden)
            .frame(height: 220)

            VStack(spacing: 4) {
                Text(highlighted?.title ?? String(localized: "report.all_categories"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(AppFormatters.currency(highlighted?.total ?? snapshot.totalExpense))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                if let highlighted {
                    Text("\(Int((highlighted.ratio * 100).rounded()))%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }
            .frame(width: 118)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .autoLedgerCardSurface(cornerRadius: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(categoryChartAccessibilityLabel(snapshot)))
    }

    private func monthlyTrendChart(_ snapshot: MonthlySnapshot, selectedLabel: Binding<String?>) -> some View {
        let activeLabel = selectedLabel.wrappedValue
        let activeMetric = activeLabel.flatMap { label in snapshot.monthlyTrend.first { $0.label == label } }

        return VStack(alignment: .leading, spacing: 14) {
            Chart(snapshot.monthlyTrend) { metric in
                BarMark(
                    x: .value(String(localized: "report.chart.month"), metric.label),
                    y: .value(String(localized: "report.chart.expense"), metric.total)
                )
                .foregroundStyle(metric.isCurrentMonth ? AppTheme.accentSecondary : AppTheme.accent)
                .opacity(activeLabel == nil || metric.label == activeLabel ? 1 : dimmedChartOpacity)
                .annotation(position: .top, alignment: .center, spacing: 4) {
                    if metric.label == activeLabel || (differentiateWithoutColor && metric.isCurrentMonth) {
                        Text(AppFormatters.currency(metric.total))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(AppTheme.card)
                                    .shadow(color: .black.opacity(reduceMotion ? 0 : 0.10), radius: reduceMotion ? 0 : 4, x: 0, y: 1)
                            )
                            .transition(reduceMotion ? .identity : .scale(scale: 0.8).combined(with: .opacity))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks()
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let xInPlot = value.location.x - geo[plotFrame].origin.x
                                    if let tapped: String = proxy.value(atX: xInPlot) {
                                        withOptionalAnimation(.spring(duration: 0.18)) {
                                            selectedLabel.wrappedValue = selectedLabel.wrappedValue == tapped ? nil : tapped
                                        }
                                    }
                                }
                        )
                }
            }
            .frame(height: 210)

            HStack {
                if let metric = activeMetric {
                    Text(metric.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(AppFormatters.currency(metric.total))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text(transactionCountText(metric.transactionCount))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                } else {
                    Text(snapshot.monthLabel)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                    Spacer()
                    Text(AppFormatters.currency(snapshot.totalExpense))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: activeLabel)
        }
        .padding(18)
        .autoLedgerCardSurface(cornerRadius: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(trendChartAccessibilityLabel(snapshot)))
    }

    private func topMerchantRanking(_ snapshot: MonthlySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if snapshot.topMerchantMetrics.isEmpty {
                Text("report.top_merchants.empty")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            } else {
                ForEach(Array(snapshot.topMerchantMetrics.prefix(5).enumerated()), id: \.element.id) { index, metric in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: rankBadgeSize, height: rankBadgeSize)
                                .background(Circle().fill(index == 0 ? AppTheme.accentSecondary : AppTheme.accent))
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.merchant)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                                Text(transactionCountText(metric.transactionCount))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.mutedInk)
                            }

                            Spacer()

                            Text(AppFormatters.currency(metric.total))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppTheme.accent.opacity(0.12))
                                Capsule()
                                    .fill(index == 0 ? AppTheme.accentSecondary : AppTheme.accent)
                                    .frame(width: max(proxy.size.width * metric.ratio, 10))
                            }
                        }
                        .frame(height: 8)
                        .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(merchantAccessibilityLabel(metric, rank: index + 1)))

                    if index < min(snapshot.topMerchantMetrics.count, 5) - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(18)
        .autoLedgerCardSurface(cornerRadius: 22)
    }

    private func activeCategoryID(in snapshot: MonthlySnapshot) -> String? {
        guard let selectedCategoryID,
              snapshot.categoryBreakdown.contains(where: { $0.id == selectedCategoryID })
        else {
            return nil
        }
        return selectedCategoryID
    }

    private func highlightedCategory(in snapshot: MonthlySnapshot) -> MonthlySnapshot.CategoryMetric? {
        guard let activeID = activeCategoryID(in: snapshot) else {
            return snapshot.categoryBreakdown.first
        }
        return snapshot.categoryBreakdown.first { $0.id == activeID }
    }

    private func categoryOpacity(_ metric: MonthlySnapshot.CategoryMetric, in snapshot: MonthlySnapshot) -> Double {
        guard let activeID = activeCategoryID(in: snapshot) else {
            return 1
        }
        return metric.id == activeID ? 1 : 0.28
    }

    private var dimmedChartOpacity: Double {
        colorSchemeContrast == .increased ? 0.46 : 0.30
    }

    private func changeSelectedCategory(to id: String?) {
        withOptionalAnimation(.easeInOut(duration: 0.16)) {
            selectedCategoryID = id
        }
    }

    private func withOptionalAnimation(_ animation: Animation, _ body: () -> Void) {
        if reduceMotion {
            body()
        } else {
            withAnimation(animation, body)
        }
    }

    private func transactionCountText(_ count: Int) -> String {
        String(format: String(localized: "report.transaction_count_format"), count)
    }

    private func merchantCountText(_ count: Int) -> String {
        String(format: String(localized: "report.merchant_count_format"), count)
    }

    private func percentageText(_ ratio: Double) -> String {
        String(format: String(localized: "report.percentage_format"), Int((ratio * 100).rounded()))
    }

    private func summaryAccessibilityLabel(_ snapshot: MonthlySnapshot) -> String {
        String(
            format: String(localized: "report.summary.accessibility_format"),
            snapshot.monthLabel,
            AppFormatters.currency(snapshot.totalExpense),
            transactionCountText(snapshot.transactionCount),
            snapshot.topMerchant,
            merchantCountText(snapshot.topMerchantMetrics.count)
        )
    }

    private func categoryChartAccessibilityLabel(_ snapshot: MonthlySnapshot) -> String {
        let items = snapshot.categoryBreakdown.prefix(5).map { metric in
            String(
                format: String(localized: "report.category.accessibility_format"),
                metric.title,
                AppFormatters.currency(metric.total),
                percentageText(metric.ratio)
            )
        }
        return [String(localized: "report.category_breakdown.title"), items.joined(separator: "，")]
            .filter { !$0.isEmpty }
            .joined(separator: "：")
    }

    private func trendChartAccessibilityLabel(_ snapshot: MonthlySnapshot) -> String {
        let items = snapshot.monthlyTrend.map { metric in
            String(
                format: String(localized: "report.trend.accessibility_item_format"),
                metric.label,
                AppFormatters.currency(metric.total),
                transactionCountText(metric.transactionCount)
            )
        }
        return String(
            format: String(localized: "report.trend.accessibility_format"),
            items.joined(separator: "，")
        )
    }

    private func merchantAccessibilityLabel(_ metric: MonthlySnapshot.MerchantMetric, rank: Int) -> String {
        String(
            format: String(localized: "report.merchant.accessibility_format"),
            rank,
            metric.merchant,
            AppFormatters.currency(metric.total),
            transactionCountText(metric.transactionCount),
            percentageText(metric.ratio)
        )
    }
}

#Preview {
    ReportView()
        .environmentObject(LedgerStore())
}
