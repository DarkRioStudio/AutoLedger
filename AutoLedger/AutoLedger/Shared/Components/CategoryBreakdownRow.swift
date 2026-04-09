import AutoLedgerCore
import SwiftUI

struct CategoryBreakdownRow: View {
    let metric: MonthlySnapshot.CategoryMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(metric.category.title, systemImage: metric.category.iconName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Text(AppFormatters.currency(metric.total))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(metric.category.tint.opacity(0.14))
                    Capsule()
                        .fill(metric.category.tint)
                        .frame(width: max(proxy.size.width * metric.ratio, 12))
                }
            }
            .frame(height: 10)

            Text("占比 \(Int(metric.ratio * 100))%")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.card)
        )
    }
}
