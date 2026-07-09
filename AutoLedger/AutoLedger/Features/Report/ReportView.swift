import AutoLedgerCore
import Charts
import SwiftUI

private struct MonthlyExportSharePayload: Identifiable {
    let id = UUID()
    let urls: [URL]
}

struct ReportView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared
    @AppStorage("monthlyAnomalyThresholdPercent") private var anomalyThresholdPercent = 150.0
    @ScaledMetric(relativeTo: .largeTitle) private var totalAmountFontSize: CGFloat = 36
    @ScaledMetric(relativeTo: .caption) private var rankBadgeSize: CGFloat = 26
    @ScaledMetric(relativeTo: .subheadline) private var summaryPillMinHeight: CGFloat = 68
    @State private var selectedCategoryID: String?
    @State private var selectedMonth: Date = .now
    @State private var selectedTrendLabel: String?
    @State private var shouldRedactMonthlyExport = true
    @State private var monthlyExportStatusMessage: String?
    @State private var monthlyExportSharePayload: MonthlyExportSharePayload?
    @State private var shareCardPreviewMode: ShareCardPreviewSheet.Mode?
    @State private var isPresentingProSheet = false

    private var isCurrentMonth: Bool {
        AppFormatters.calendar.isDate(selectedMonth, equalTo: .now, toGranularity: .month)
    }

    private var monthMenuOptions: [Date] {
        var months = store.reportMonthOptions()
        if let selectedMonthStart = monthStart(for: selectedMonth),
           !months.contains(where: { AppFormatters.calendar.isDate($0, equalTo: selectedMonthStart, toGranularity: .month) }) {
            months.append(selectedMonthStart)
            months.sort(by: >)
        }
        return months
    }

    var body: some View {
        let snapshot = store.monthlySnapshot(for: selectedMonth)
        let anomalyAlerts = isCurrentMonth
            ? store.monthlyAnomalyAlerts(for: selectedMonth, thresholdPercent: anomalyThresholdPercent)
            : []

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AutoLedgerPageTitle("tab.report")

                    summaryCard(snapshot)

                    monthlyExportSection(snapshot)

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
            .sheet(item: $monthlyExportSharePayload) { payload in
                ActivityShareSheet(activityItems: payload.urls.map { $0 as Any })
            }
            .sheet(item: $shareCardPreviewMode) { mode in
                ShareCardPreviewSheet(mode: mode)
            }
            .sheet(isPresented: $isPresentingProSheet) {
                NavigationStack {
                    AutoLedgerProView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("common.close") {
                                    isPresentingProSheet = false
                                }
                            }
                        }
                }
            }
            .onAppear {
                CommonAPIAnalyticsService.trackFeatureSurfaceOpened(
                    surface: "report",
                    entrySurface: "tab_bar",
                    openReason: "view_appear"
                )
            }
            .task {
                await proEntitlement.loadProducts()
                await proEntitlement.refreshEntitlements()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    monthPickerMenu(snapshot)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarShareButton(snapshot)
                }
            }
        }
    }

    private func monthPickerMenu(_ snapshot: MonthlySnapshot) -> some View {
        Menu {
            ForEach(monthMenuOptions, id: \.self) { month in
                Button {
                    selectMonth(month)
                } label: {
                    if isSelectedMonth(month) {
                        Label(monthMenuTitle(for: month), systemImage: "checkmark")
                    } else {
                        Text(monthMenuTitle(for: month))
                    }
                }
            }
        } label: {
            Label {
                HStack(spacing: 4) {
                    Text(snapshot.monthLabel)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
            } icon: {
                Image(systemName: "calendar")
            }
            .font(.subheadline.weight(.semibold))
        }
        .accessibilityLabel(Text("report.month_picker.accessibility_label"))
    }

    private func toolbarShareButton(_ snapshot: MonthlySnapshot) -> some View {
        Button {
            CommonAPIAnalyticsService.trackFeatureSurfaceOpened(
                surface: "monthly_share_card",
                entrySurface: "report",
                openReason: "toolbar_share"
            )
            shareCardPreviewMode = .monthly(monthlyShareCardData(from: snapshot))
        } label: {
            Image(systemName: "square.and.arrow.up")
                .fontWeight(.semibold)
        }
        .accessibilityLabel(Text("share_card.monthly.accessibility_label"))
    }

    private func selectMonth(_ month: Date) {
        guard let monthStart = monthStart(for: month) else { return }
        let startedAt = Date()
        withOptionalAnimation(.easeInOut(duration: 0.18)) {
            selectedMonth = monthStart
            selectedCategoryID = nil
            selectedTrendLabel = nil
        }
        CommonAPIAnalyticsService.trackUIResponsiveness(
            surface: "report",
            operation: "month_switch",
            startedAt: startedAt
        )
    }

    private func monthStart(for date: Date) -> Date? {
        AppFormatters.calendar.dateInterval(of: .month, for: date)?.start
    }

    private func isSelectedMonth(_ month: Date) -> Bool {
        AppFormatters.calendar.isDate(month, equalTo: selectedMonth, toGranularity: .month)
    }

    private func monthMenuTitle(for month: Date) -> String {
        if AppFormatters.calendar.isDate(month, equalTo: .now, toGranularity: .month) {
            return String(localized: "report.month_picker.current_month")
        }
        return AppFormatters.month(month)
    }

    private func monthlyExportSection(_ snapshot: MonthlySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "tray.and.arrow.up.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text("report.monthly_export.title")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text("Pro")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
                    }

                    Text(String(format: String(localized: "report.monthly_export.body_format"), snapshot.monthLabel))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                }
                Spacer(minLength: 0)
            }

            Toggle(isOn: $shouldRedactMonthlyExport) {
                Text("report.monthly_export.redact_toggle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }
            .tint(AppTheme.accent)

            Button {
                exportMonthlyPackage()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: proEntitlement.canUse(.monthlyExportPackage) ? "square.and.arrow.up.fill" : "lock.fill")
                    if proEntitlement.canUse(.monthlyExportPackage) {
                        Text("report.monthly_export.export_action")
                    } else {
                        Text("report.monthly_export.pro.action")
                    }
                    Spacer()
                    Text(transactionCountText(snapshot.transactionCount))
                        .font(.caption.weight(.semibold))
                        .opacity(0.78)
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.accent)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("report.monthly_export.accessibility_label"))

            if let monthlyExportStatusMessage {
                Text(monthlyExportStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .padding(18)
        .autoLedgerCardSurface(cornerRadius: 22)
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

            HStack(alignment: .top, spacing: 12) {
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
        .frame(maxWidth: .infinity, minHeight: summaryPillMinHeight, alignment: .leading)
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

    private func exportMonthlyPackage() {
        guard proEntitlement.canUse(.monthlyExportPackage) else {
            CommonAPIAnalyticsService.trackProGateViewed(
                surface: "report",
                featureArea: "monthly_export_package",
                userAction: "view_plans",
                dismissReasonCode: "requires_pro"
            )
            isPresentingProSheet = true
            return
        }

        let startedAt = Date()
        CommonAPIAnalyticsService.trackFeatureSurfaceOpened(
            surface: "monthly_export_package",
            entrySurface: "report",
            isProSurface: true,
            openReason: "export_tap"
        )
        CommonAPIAnalyticsService.trackImportStarted(
            flowType: "monthly_export_package",
            inputType: "local_ledger",
            entrySurface: "report",
            isProSurface: true
        )
        do {
            let urls = try store.writeMonthlyExportPackage(
                referenceDate: selectedMonth,
                redactSensitiveFields: shouldRedactMonthlyExport
            )
            monthlyExportStatusMessage = String(
                format: String(localized: "report.monthly_export.status_ready_format"),
                urls.count
            )
            monthlyExportSharePayload = MonthlyExportSharePayload(urls: urls)
            CommonAPIAnalyticsService.trackImportCompleted(
                flowType: "monthly_export_package",
                inputType: "local_ledger",
                status: "success",
                startedAt: startedAt
            )
        } catch {
            monthlyExportStatusMessage = String(
                format: String(localized: "report.monthly_export.status_failed_format"),
                error.localizedDescription
            )
            CommonAPIAnalyticsService.trackImportCompleted(
                flowType: "monthly_export_package",
                inputType: "local_ledger",
                status: "failed",
                startedAt: startedAt,
                errorCode: CommonAPIAnalyticsService.errorCode(for: error)
            )
        }
    }

    private func monthlyShareCardData(from snapshot: MonthlySnapshot) -> MonthlySummaryShareCardData {
        let categories = snapshot.categoryBreakdown.prefix(3).map { metric in
            MonthlySummaryShareCardData.CategoryItem(
                id: metric.id,
                title: metric.title,
                amountText: AppFormatters.currency(metric.total),
                percentText: percentageText(metric.ratio),
                iconName: metric.iconName
            )
        }

        return MonthlySummaryShareCardData(
            monthLabel: snapshot.monthLabel,
            transactionCountText: transactionCountText(snapshot.transactionCount),
            totalAmountText: AppFormatters.currency(snapshot.totalExpense),
            categories: categories,
            summary: monthlyShareSummary(for: snapshot)
        )
    }

    private func monthlyShareSummary(for snapshot: MonthlySnapshot) -> String {
        if snapshot.transactionCount == 0 {
            return String(localized: "share_card.monthly.summary_empty")
        }
        if let topCategory = snapshot.categoryBreakdown.first {
            return String(
                format: String(localized: "share_card.monthly.summary_top_category_format"),
                topCategory.title,
                transactionCountText(snapshot.transactionCount)
            )
        }
        return String(
            format: String(localized: "share_card.monthly.summary_simple_format"),
            transactionCountText(snapshot.transactionCount)
        )
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
