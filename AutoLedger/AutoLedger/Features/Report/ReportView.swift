import AutoLedgerCore
import Charts
import SwiftUI

struct ReportView: View {
    @EnvironmentObject private var store: LedgerStore
    @AppStorage("monthlyAnomalyThresholdPercent") private var anomalyThresholdPercent = 150.0
    @State private var selectedCategoryID: String?
    @State private var selectedMonth: Date = .now
    @State private var selectedTrendLabel: String?
    private let insightService = MonthlyInsightService()

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
        let snapshot = MonthlySnapshot.build(from: store.transactions, referenceDate: selectedMonth)
        let anomalyAlerts = isCurrentMonth ? insightService.detectAnomalies(
            transactions: store.transactions,
            thresholdPercent: anomalyThresholdPercent
        ) : []

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
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
                            CategoryBreakdownRow(metric: metric)
                                .opacity(activeCategoryID(in: snapshot) == nil || activeCategoryID(in: snapshot) == metric.id ? 1 : 0.58)
                                .onTapGesture {
                                    selectedCategoryID = selectedCategoryID == metric.id ? nil : metric.id
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
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("tab.report")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { withAnimation(.easeInOut(duration: 0.18)) { stepMonth(by: -1) } } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { withAnimation(.easeInOut(duration: 0.18)) { stepMonth(by: 1) } } label: {
                        Image(systemName: "chevron.right")
                            .fontWeight(.semibold)
                    }
                    .disabled(isCurrentMonth)
                    .opacity(isCurrentMonth ? 0.35 : 1)
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
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func summaryCard(_ snapshot: MonthlySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.monthLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))

                Text(AppFormatters.currency(snapshot.totalExpense))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            HStack(spacing: 12) {
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
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppTheme.heroGradient)
        )
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
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.card)
            )
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
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
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
                .opacity(activeLabel == nil || metric.label == activeLabel ? 1 : 0.30)
                .annotation(position: .top, alignment: .center, spacing: 4) {
                    if metric.label == activeLabel {
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
                                    .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 1)
                            )
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
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
                                    let xInPlot = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                    if let tapped: String = proxy.value(atX: xInPlot) {
                                        withAnimation(.spring(duration: 0.18)) {
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
            .animation(.easeInOut(duration: 0.15), value: activeLabel)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
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
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(index == 0 ? AppTheme.accentSecondary : AppTheme.accent))

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
                    }

                    if index < min(snapshot.topMerchantMetrics.count, 5) - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
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

    private func transactionCountText(_ count: Int) -> String {
        String(format: String(localized: "report.transaction_count_format"), count)
    }

    private func merchantCountText(_ count: Int) -> String {
        String(format: String(localized: "report.merchant_count_format"), count)
    }
}

#Preview {
    ReportView()
        .environmentObject(LedgerStore())
}
