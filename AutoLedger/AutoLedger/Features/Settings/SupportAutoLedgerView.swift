import AutoLedgerCore
import StoreKit
import SwiftUI

struct SupportAutoLedgerView: View {
    @ObservedObject private var purchaseManager = SupportPurchaseManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard

                if purchaseManager.supportPurchaseCount > 0 {
                    thankYouCard
                }

                productSection

                noteCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("support.title")
        .task {
            purchaseManager.startTransactionListener()
            purchaseManager.startStorefrontListener()
            await purchaseManager.loadProducts()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await purchaseManager.loadProducts(forceRefresh: true) }
        }
        .alert(item: $purchaseManager.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("support.alert.ok"))
            )
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(AppTheme.accentSecondary)
                .accessibilityHidden(true)

            Text("support.title")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            Text("support.description")
                .font(.body)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var productSection: some View {
        switch purchaseManager.loadState {
        case .idle, .loading:
            loadingCard

        case .loaded:
            VStack(alignment: .leading, spacing: 12) {
                ForEach(purchaseManager.products, id: \.id) { product in
                    productButton(for: product)
                }
            }

        case .failed(let message):
            errorCard(message)
        }
    }

    private func productButton(for product: Product) -> some View {
        let isPurchasing = purchaseManager.purchasingProductID == product.id
        let supportProduct = SupportProduct(rawValue: product.id)
        let title = supportProduct?.buttonTitle ?? product.displayName
        let description = supportProduct?.descriptionText ?? product.description

        return Button {
            Task { await purchaseManager.purchase(product) }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                if isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("support.purchase.loading")
                } else {
                    Text(product.displayPrice)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.card)
            )
        }
        .buttonStyle(.plain)
        .disabled(purchaseManager.purchasingProductID != nil)
        .accessibilityHint("support.purchase.accessibility_hint")
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("support.loading")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(message)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.ink)

            Button {
                Task { await purchaseManager.loadProducts() }
            } label: {
                Label("support.retry", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private var thankYouCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("support.thank_you.title")
                    .font(.headline)
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(AppTheme.accent)
            }
            .foregroundStyle(AppTheme.ink)

            Text(String(
                format: String(localized: "support.history.count_format"),
                purchaseManager.supportPurchaseCount
            ))
            .font(.subheadline)
            .foregroundStyle(AppTheme.mutedInk)

            if let date = purchaseManager.lastSupportDate {
                Text(String(
                    format: String(localized: "support.history.date_format"),
                    AppFormatters.exportDateTime(date)
                ))
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.accent.opacity(0.10))
        )
        .accessibilityElement(children: .combine)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("support.note")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("support.optional_note")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.card)
        )
    }
}

#Preview {
    NavigationStack {
        SupportAutoLedgerView()
    }
}
