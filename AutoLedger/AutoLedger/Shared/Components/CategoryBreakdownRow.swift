import AutoLedgerCore
import SwiftUI

struct CategoryBreakdownRow: View {
    let metric: MonthlySnapshot.CategoryMetric
    var isSelected = false
    var isDimmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(metric.title, systemImage: metric.iconName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityHidden(true)
                }

                Text(AppFormatters.currency(metric.total))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(metric.tint.opacity(0.14))
                    Capsule()
                        .fill(metric.tint)
                        .frame(width: max(proxy.size.width * metric.ratio, 12))
                    if isSelected {
                        Capsule()
                            .strokeBorder(AppTheme.ink.opacity(0.34), lineWidth: 1)
                    }
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)

            Text(String(format: String(localized: "report.category.percentage_format"), Int((metric.ratio * 100).rounded())))
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(16)
        .opacity(isDimmed ? 0.72 : 1)
        .autoLedgerCardSurface(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isSelected ? AppTheme.accent : .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                String(
                    format: String(localized: "report.category.accessibility_format"),
                    metric.title,
                    AppFormatters.currency(metric.total),
                    String(format: String(localized: "report.percentage_format"), Int((metric.ratio * 100).rounded()))
                )
            )
        )
        .accessibilityHint(Text("report.category.accessibility_hint"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
