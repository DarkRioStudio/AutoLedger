import AutoLedgerCore
import Charts
import SwiftUI

struct ReportView: View {
    @EnvironmentObject private var store: LedgerStore
    @AppStorage("monthlyAnomalyThresholdPercent") private var anomalyThresholdPercent = 150.0
    @State private var selectedCategoryID: String?
    private let insightService = MonthlyInsightService()

    var body: some View {
        let snapshot = store.monthlySnapshot
        let anomalyAlerts = insightService.detectAnomalies(
            transactions: store.transactions,
            thresholdPercent: anomalyThresholdPercent
        )

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    summaryCard(snapshot)

                    if !anomalyAlerts.isEmpty {
                        anomalySection(anomalyAlerts)
                    }

                    sectionTitle("分类占比")
                    if snapshot.categoryBreakdown.isEmpty {
                        emptyState("还没有可用于汇总的数据。")
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

                    sectionTitle("近 6 个月趋势")
                    monthlyTrendChart(snapshot)

                    sectionTitle("TOP5 商户")
                    topMerchantRanking(snapshot)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("月报")
        }
    }

    private func anomalySection(_ alerts: [AnomalyAlert]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(AppTheme.accentSecondary)
                Text("消费提醒")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("阈值 \(Int(anomalyThresholdPercent))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            ForEach(alerts.prefix(3)) { alert in
                VStack(alignment: .leading, spacing: 6) {
                    Text("本月 \(alert.categoryTitle) 支出偏高")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text("\(AppFormatters.currency(alert.currentTotal))，约为近 3 个月月均 \(AppFormatters.currency(alert.baselineAverage)) 的 \(alert.ratioPercent)%")
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
                summaryPill(title: "账单", value: "\(snapshot.transactionCount) 笔")
                summaryPill(title: "TOP1", value: snapshot.topMerchant)
                summaryPill(
                    title: "商户数",
                    value: "\(snapshot.topMerchantMetrics.count) 家"
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

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
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

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(AppTheme.ink)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
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
                    angle: .value("支出", metric.total),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .foregroundStyle(metric.tint)
                .opacity(categoryOpacity(metric, in: snapshot))
            }
            .chartLegend(.hidden)
            .frame(height: 220)

            VStack(spacing: 4) {
                Text(highlighted?.title ?? "全部分类")
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

    private func monthlyTrendChart(_ snapshot: MonthlySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Chart(snapshot.monthlyTrend) { metric in
                BarMark(
                    x: .value("月份", metric.label),
                    y: .value("支出", metric.total)
                )
                .foregroundStyle(metric.isCurrentMonth ? AppTheme.accentSecondary : AppTheme.accent)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks()
            }
            .frame(height: 190)

            HStack {
                Text("本月")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                Spacer()
                Text(AppFormatters.currency(snapshot.totalExpense))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }
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
                Text("本月还没有商户排行。")
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
                                Text("\(metric.transactionCount) 笔")
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
}

#Preview {
    ReportView()
        .environmentObject(LedgerStore())
}
