import AutoLedgerCore
import SwiftUI

struct CurrencyConversionPreviewQuote: Equatable {
    let sourceAmount: Double
    let sourceCurrencyCode: String
    let targetCurrencyCode: String
    let convertedAmount: Double
    let rate: Double
    let rateDate: String
    let provider: String
}

enum CurrencyConversionPreviewState: Equatable {
    case idle
    case loading
    case loaded(CurrencyConversionPreviewQuote)
    case failed

    var quote: CurrencyConversionPreviewQuote? {
        guard case .loaded(let quote) = self else { return nil }
        return quote
    }
}

struct CurrencyConversionPreviewCard: View {
    let sourceAmount: Double?
    let sourceCurrencyCode: String
    let targetCurrencyCode: String
    let state: CurrencyConversionPreviewState
    let onRetry: (() -> Void)?

    init(
        sourceAmount: Double?,
        sourceCurrencyCode: String,
        targetCurrencyCode: String,
        state: CurrencyConversionPreviewState = .idle,
        onRetry: (() -> Void)? = nil
    ) {
        self.sourceAmount = sourceAmount
        self.sourceCurrencyCode = sourceCurrencyCode
        self.targetCurrencyCode = targetCurrencyCode
        self.state = state
        self.onRetry = onRetry
    }

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

            stateContent

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

    @ViewBuilder
    private var stateContent: some View {
        switch state {
        case .idle:
            targetCurrencyText
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("currency_conversion.preview.loading")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        case .loaded(let quote):
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    String(
                        format: String(localized: "currency_conversion.preview.converted_format"),
                        AppFormatters.currency(quote.convertedAmount, code: quote.targetCurrencyCode)
                    )
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

                Text(
                    String(
                        format: String(localized: "currency_conversion.preview.rate_format"),
                        quote.sourceCurrencyCode,
                        quote.targetCurrencyCode,
                        formattedRate(quote.rate)
                    )
                )
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)

                Text(
                    String(
                        format: String(localized: "currency_conversion.preview.metadata_format"),
                        quote.rateDate,
                        quote.provider
                    )
                )
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }
        case .failed:
            VStack(alignment: .leading, spacing: 6) {
                Text("currency_conversion.preview.failed")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
                targetCurrencyText
                if let onRetry {
                    Button("currency_conversion.preview.retry") {
                        onRetry()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private var targetCurrencyText: some View {
        Text(
            String(
                format: String(localized: "currency_conversion.preview.target_format"),
                targetCurrencyCode
            )
        )
        .font(.footnote)
        .foregroundStyle(AppTheme.mutedInk)
    }

    private func formattedRate(_ rate: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: rate)) ?? String(format: "%.6f", rate)
    }
}
