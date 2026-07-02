import AutoLedgerCore
import SwiftUI

struct CurrencyConversionPreviewCard: View {
    let sourceAmount: Double?
    let sourceCurrencyCode: String
    let targetCurrencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("currency_conversion.preview.title", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            if let sourceAmount, sourceAmount > 0 {
                Text(
                    String(
                        format: String(localized: "currency_conversion.preview.source_format"),
                        AppFormatters.currency(sourceAmount, code: sourceCurrencyCode)
                    )
                )
                .font(.footnote)
                .foregroundStyle(AppTheme.ink)
            }

            Text(
                String(
                    format: String(localized: "currency_conversion.preview.target_format"),
                    targetCurrencyCode
                )
            )
            .font(.footnote)
            .foregroundStyle(AppTheme.mutedInk)

            Text("currency_conversion.preview.footer")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.accent.opacity(0.10))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.22), lineWidth: 1)
        }
    }
}
