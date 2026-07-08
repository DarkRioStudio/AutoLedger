import AutoLedgerCore
import StoreKit
import SwiftUI

struct AutoLedgerProView: View {
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    private let gold = Color(red: 0.82, green: 0.58, blue: 0.12)
    private let privacyPolicyURL = URL(string: "https://getautoledger.app/privacy")!
    private let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroPanel

                subscriptionStatusCard
                subscriptionActionsCard

                featureGrid
                roadmapSection
                assurancePanel
                productSection
                boundaryCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .autoLedgerReadableContent(maxWidth: 720, alignment: .leading)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("pro.title")
        .task {
            await proEntitlement.loadProducts()
            await proEntitlement.refreshEntitlements()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await proEntitlement.loadProducts(forceRefresh: true)
                await proEntitlement.refreshEntitlements()
            }
        }
        .alert(item: $proEntitlement.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("support.alert.ok"))
            )
        }
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                appMark

                Text("AutoLedger")
                    .font(.title3.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Text("pro.hero.badge")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .continuous).fill(gold))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("pro.hero.title")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)

                Text("pro.hero.subtitle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)

                Label(heroPriceLineText, systemImage: "tag.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(gold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ProDashboardPreview(gold: gold)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.card,
                            heroWarmOverlayFill
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(gold.opacity(0.15))
                .frame(width: 118, height: 118)
                .offset(x: 42, y: -54)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(gold.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var appMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.ink)
                .frame(width: 42, height: 42)

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(gold)
        }
        .accessibilityHidden(true)
    }

    private var featureGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("pro.features.title")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 146), spacing: 12)], spacing: 12) {
                ForEach(featureItems) { item in
                    ProFeatureCard(item: item)
                }
            }
        }
    }

    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("pro.roadmap.title")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Spacer(minLength: 8)
            }

            Text("pro.roadmap.subtitle")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12)], spacing: 12) {
                ForEach(roadmapItems) { item in
                    ProRoadmapCard(item: item, badge: "pro.roadmap.item_badge")
                }
            }
        }
    }

    private var assurancePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("pro.assurance.title")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(assuranceItems) { item in
                    ProAssuranceRow(item: item)
                }
            }

            Label("pro.assurance.free_note", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private var subscriptionStatusCard: some View {
        let presentation = subscriptionStatusPresentation

        return Label {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(presentation.title)
                        .font(.headline.weight(.bold))
                    Text(presentation.badge)
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(presentation.tint))
                }

                Text(presentation.body)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = presentation.detail {
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(presentation.tint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let checkedText = lastVerifiedText {
                    Text(checkedText)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }
        } icon: {
            Image(systemName: presentation.icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(presentation.tint)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(presentation.tint.opacity(0.10))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(presentation.tint.opacity(0.18), lineWidth: 1)
        }
    }

    private var subscriptionActionsCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                restoreButton
                manageSubscriptionButton
            }

            VStack(spacing: 10) {
                restoreButton
                manageSubscriptionButton
            }
        }
    }

    private var restoreButton: some View {
        Button {
            Task { await proEntitlement.restorePurchases() }
        } label: {
            subscriptionActionLabel(
                titleKey: "pro.restore",
                systemImage: "arrow.clockwise.circle.fill",
                isLoading: proEntitlement.isRestoringPurchases
            )
        }
        .buttonStyle(.plain)
        .disabled(proEntitlement.isRestoringPurchases || proEntitlement.isManagingSubscriptions)
    }

    private var manageSubscriptionButton: some View {
        Button {
            Task { await proEntitlement.manageSubscriptions() }
        } label: {
            subscriptionActionLabel(
                titleKey: "pro.manage",
                systemImage: "person.crop.circle.badge.gearshape",
                isLoading: proEntitlement.isManagingSubscriptions
            )
        }
        .buttonStyle(.plain)
        .disabled(proEntitlement.isRestoringPurchases || proEntitlement.isManagingSubscriptions)
    }

    private func subscriptionActionLabel(
        titleKey: LocalizedStringKey,
        systemImage: String,
        isLoading: Bool
    ) -> some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: systemImage)
                    .imageScale(.medium)
            }

            Text(titleKey)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(AppTheme.accent)
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private var subscriptionStatusPresentation: ProStatusPresentation {
        if proEntitlement.isDevelopmentOverrideActive {
            return ProStatusPresentation(
                title: "pro.status.debug.title",
                badge: "pro.status.debug.badge",
                body: "pro.status.debug.body",
                detail: nil,
                icon: "wrench.and.screwdriver.fill",
                tint: .orange
            )
        }

        if proEntitlement.isProActive {
            return ProStatusPresentation(
                title: "pro.status.active.title",
                badge: "pro.status.active.badge",
                body: "pro.status.active.body",
                detail: activeSubscriptionDetail,
                icon: "checkmark.seal.fill",
                tint: AppTheme.accent
            )
        }

        return ProStatusPresentation(
            title: "pro.status.inactive.title",
            badge: "pro.status.inactive.badge",
            body: "pro.status.inactive.body",
            detail: nil,
            icon: "sparkles",
            tint: gold
        )
    }

    private var activeSubscriptionDetail: String? {
        guard let subscription = proEntitlement.primaryActiveSubscription else { return nil }
        let productName = productTitle(for: subscription.productID)
        if let expirationDate = subscription.expirationDate {
            return String(
                format: String(localized: "pro.status.expiration_format"),
                productName,
                AppFormatters.exportDateTime(expirationDate)
            )
        }
        return String(
            format: String(localized: "pro.status.product_format"),
            productName
        )
    }

    private var lastVerifiedText: String? {
        guard let date = proEntitlement.lastVerifiedAt else { return nil }
        return String(
            format: String(localized: "pro.status.verified_format"),
            AppFormatters.exportDateTime(date)
        )
    }

    private var heroPriceLineText: String {
        guard let monthlyPrice = proEntitlement.displayPrice(for: .monthly),
              let yearlyPrice = proEntitlement.displayPrice(for: .yearly) else {
            return String(localized: "pro.price.loading")
        }

        return String(
            format: String(localized: "pro.hero.price_line_format"),
            monthlyPrice,
            yearlyPrice
        )
    }

    private var pricingSubtitleText: String {
        guard let monthlyPrice = proEntitlement.displayPrice(for: .monthly),
              let yearlyPrice = proEntitlement.displayPrice(for: .yearly) else {
            return String(localized: "pro.price.loading")
        }

        return String(
            format: String(localized: "pro.pricing.subtitle_format"),
            monthlyPrice,
            yearlyPrice
        )
    }

    @ViewBuilder
    private var productSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("pro.pricing.title")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Text(pricingSubtitleText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Label("pro.pricing.launch_note", systemImage: "tag.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(gold)
                .fixedSize(horizontal: false, vertical: true)

            purchaseFlowLegalLinks

            switch proEntitlement.loadState {
            case .idle, .loading:
                loadingCard

            case .loaded:
                if proEntitlement.products.isEmpty {
                    subscriptionUnavailableCard(String(localized: "pro.products.empty"))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                        ForEach(proEntitlement.products, id: \.id) { product in
                            productCard(for: product)
                        }
                    }
                }

            case .failed(let message):
                subscriptionUnavailableCard(message)
            }
        }
    }

    private var purchaseFlowLegalLinks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("pro.legal.title")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text("pro.legal.body")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    legalLinkButton(titleKey: "pro.legal.privacy", systemImage: "lock.shield.fill", destination: privacyPolicyURL)
                    legalLinkButton(titleKey: "pro.legal.terms", systemImage: "doc.text.fill", destination: termsOfUseURL)
                }

                VStack(spacing: 10) {
                    legalLinkButton(titleKey: "pro.legal.privacy", systemImage: "lock.shield.fill", destination: privacyPolicyURL)
                    legalLinkButton(titleKey: "pro.legal.terms", systemImage: "doc.text.fill", destination: termsOfUseURL)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.accent.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.16), lineWidth: 1)
        }
    }

    private func legalLinkButton(
        titleKey: LocalizedStringKey,
        systemImage: String,
        destination: URL
    ) -> some View {
        Link(destination: destination) {
            Label(titleKey, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }

    private func productCard(for product: Product) -> some View {
        let isPurchasing = proEntitlement.purchasingProductID == product.id
        let isRecommended = AutoLedgerProProduct(rawValue: product.id) == .yearly
        let isPurchaseDisabled = proEntitlement.isProActive || proEntitlement.purchasingProductID != nil

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(productTitle(for: product))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text(productDescription(for: product))
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if isRecommended {
                    Text("pro.product.recommended")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(gold))
                }
            }

            Text(product.displayPrice)
                .font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(isRecommended ? gold : AppTheme.ink)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("pro.product.cancel_anytime")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Button {
                Task { await proEntitlement.purchase(product) }
            } label: {
                purchaseCallToAction(
                    titleKey: productActionTitle(for: product),
                    isRecommended: isRecommended,
                    isPurchasing: isPurchasing
                )
            }
            .buttonStyle(.plain)
            .disabled(isPurchaseDisabled)
            .accessibilityHint("pro.purchase.accessibility_hint")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isRecommended ? recommendedProductCardFill : AppTheme.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isRecommended ? gold.opacity(0.62) : AppTheme.mutedInk.opacity(0.12), lineWidth: 1)
        }
    }

    private func purchaseCallToAction(
        titleKey: LocalizedStringKey,
        isRecommended: Bool,
        isPurchasing: Bool
    ) -> some View {
        HStack(spacing: 8) {
            if isPurchasing {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                    .accessibilityLabel("pro.purchase.loading")
            } else {
                Image(systemName: isRecommended ? "crown.fill" : "sparkles")
            }

            Text(titleKey)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .font(.headline.weight(.bold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isRecommended ? gold : AppTheme.accent)
        )
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("pro.loading")
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

    private func subscriptionUnavailableCard(_ message: String) -> some View {
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
                Task { await proEntitlement.loadProducts(forceRefresh: true) }
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

    private var boundaryCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 8) {
                Text("pro.boundary.title")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text("pro.boundary.body")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private var featureItems: [ProFeatureItem] {
        [
            ProFeatureItem(
                id: "email",
                icon: "envelope.fill",
                title: "pro.feature.email.title",
                body: "pro.feature.email.body",
                colors: [Color.blue, Color.cyan]
            ),
            ProFeatureItem(
                id: "cloudInbox",
                icon: "tray.full.fill",
                title: "pro.feature.cloud_inbox.title",
                body: "pro.feature.cloud_inbox.body",
                colors: [AppTheme.accent, Color.teal]
            ),
            ProFeatureItem(
                id: "batch",
                icon: "doc.on.doc.fill",
                title: "pro.feature.batch.title",
                body: "pro.feature.batch.body",
                colors: [Color.purple, Color.pink]
            ),
            ProFeatureItem(
                id: "dedupe",
                icon: "scope",
                title: "pro.feature.dedupe.title",
                body: "pro.feature.dedupe.body",
                colors: [Color.orange, gold]
            ),
            ProFeatureItem(
                id: "search",
                icon: "magnifyingglass",
                title: "pro.feature.search.title",
                body: "pro.feature.search.body",
                colors: [Color.teal, AppTheme.accent]
            ),
            ProFeatureItem(
                id: "alerts",
                icon: "bell.badge.fill",
                title: "pro.feature.alerts.title",
                body: "pro.feature.alerts.body",
                colors: [Color.cyan, Color.blue]
            ),
            ProFeatureItem(
                id: "export",
                icon: "archivebox.fill",
                title: "pro.feature.export.title",
                body: "pro.feature.export.body",
                colors: [Color.indigo, Color.blue]
            ),
            ProFeatureItem(
                id: "rules",
                icon: "wand.and.sparkles",
                title: "pro.feature.rules.title",
                body: "pro.feature.rules.body",
                colors: [gold, Color.orange]
            )
        ]
    }

    private var roadmapItems: [ProRoadmapItem] {
        [
            ProRoadmapItem(
                id: "cloudAssist",
                icon: "sparkles",
                title: "pro.roadmap.cloud_assist.title",
                body: "pro.roadmap.cloud_assist.body",
                tint: AppTheme.accent
            ),
            ProRoadmapItem(
                id: "reviewQueue",
                icon: "checklist",
                title: "pro.roadmap.review_queue.title",
                body: "pro.roadmap.review_queue.body",
                tint: Color.teal
            ),
            ProRoadmapItem(
                id: "shareTemplates",
                icon: "photo.on.rectangle.angled",
                title: "pro.roadmap.share_templates.title",
                body: "pro.roadmap.share_templates.body",
                tint: Color.indigo
            ),
            ProRoadmapItem(
                id: "crossDevice",
                icon: "icloud.fill",
                title: "pro.roadmap.cross_device.title",
                body: "pro.roadmap.cross_device.body",
                tint: gold
            )
        ]
    }

    private var assuranceItems: [ProAssuranceItem] {
        [
            ProAssuranceItem(
                id: "local",
                icon: "lock.shield.fill",
                title: "pro.assurance.local.title",
                body: "pro.assurance.local.body"
            ),
            ProAssuranceItem(
                id: "review",
                icon: "checkmark.seal.fill",
                title: "pro.assurance.review.title",
                body: "pro.assurance.review.body"
            ),
            ProAssuranceItem(
                id: "control",
                icon: "arrow.uturn.backward.circle.fill",
                title: "pro.assurance.control.title",
                body: "pro.assurance.control.body"
            )
        ]
    }

    private func productTitle(for product: Product) -> String {
        switch AutoLedgerProProduct(rawValue: product.id) {
        case .monthly:
            String(localized: "pro.product.monthly.title")
        case .yearly:
            String(localized: "pro.product.yearly.title")
        case .none:
            product.displayName
        }
    }

    private func productTitle(for productID: String) -> String {
        switch AutoLedgerProProduct(rawValue: productID) {
        case .monthly:
            String(localized: "pro.product.monthly.title")
        case .yearly:
            String(localized: "pro.product.yearly.title")
        case .none:
            productID
        }
    }

    private func productDescription(for product: Product) -> String {
        switch AutoLedgerProProduct(rawValue: product.id) {
        case .monthly:
            String(
                format: String(localized: "pro.product.monthly.description_format"),
                product.displayPrice
            )
        case .yearly:
            String(
                format: String(localized: "pro.product.yearly.description_format"),
                product.displayPrice
            )
        case .none:
            product.description
        }
    }

    private func productActionTitle(for product: Product) -> LocalizedStringKey {
        switch AutoLedgerProProduct(rawValue: product.id) {
        case .monthly:
            "pro.product.monthly.action"
        case .yearly:
            "pro.product.yearly.action"
        case .none:
            "pro.product.choose"
        }
    }

    private var heroWarmOverlayFill: Color {
        colorScheme == .dark
            ? gold.opacity(0.18)
            : Color(red: 1.00, green: 0.97, blue: 0.87).opacity(0.90)
    }

    private var recommendedProductCardFill: Color {
        colorScheme == .dark
            ? gold.opacity(0.18)
            : Color(red: 1.0, green: 0.97, blue: 0.86).opacity(0.95)
    }
}

private struct ProFeatureItem: Identifiable {
    let id: String
    let icon: String
    let title: LocalizedStringKey
    let body: LocalizedStringKey
    let colors: [Color]
}

private struct ProRoadmapItem: Identifiable {
    let id: String
    let icon: String
    let title: LocalizedStringKey
    let body: LocalizedStringKey
    let tint: Color
}

private struct ProAssuranceItem: Identifiable {
    let id: String
    let icon: String
    let title: LocalizedStringKey
    let body: LocalizedStringKey
}

private struct ProStatusPresentation {
    let title: LocalizedStringKey
    let badge: LocalizedStringKey
    let body: LocalizedStringKey
    let detail: String?
    let icon: String
    let tint: Color
}

private struct ProDashboardPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let gold: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("pro.preview.title")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Label("pro.preview.saved_time", systemImage: "clock.badge.checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.accent.opacity(0.12))
                    )
            }

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("pro.preview.month")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(metricSecondaryText)
                    Text("¥8,952")
                        .font(.system(size: 28, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(metricPrimaryText)
                    Text("pro.preview.records")
                        .font(.caption)
                        .foregroundStyle(metricTertiaryText)
                }

                Spacer(minLength: 8)

                ProMiniDonut(
                    gold: gold,
                    centerFill: metricPanelFill,
                    trackFill: metricTrackFill
                )
                    .frame(width: 72, height: 72)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(metricPanelFill)
            )

            VStack(spacing: 10) {
                ProPreviewTaskRow(icon: "building.2.fill", title: "pro.preview.folio", count: "5", tint: AppTheme.accent)
                ProPreviewTaskRow(icon: "doc.text.viewfinder", title: "pro.preview.batch", count: "12", tint: Color.blue)
                ProPreviewTaskRow(icon: "exclamationmark.triangle.fill", title: "pro.preview.duplicates", count: "7", tint: gold)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(previewCardFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(previewCardStroke, lineWidth: 1)
        }
    }

    private var previewCardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.72)
    }

    private var previewCardStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.white.opacity(0.58)
    }

    private var metricPanelFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : AppTheme.ink
    }

    private var metricPrimaryText: Color {
        colorScheme == .dark ? AppTheme.ink : .white
    }

    private var metricSecondaryText: Color {
        colorScheme == .dark ? AppTheme.mutedInk : .white.opacity(0.80)
    }

    private var metricTertiaryText: Color {
        colorScheme == .dark ? AppTheme.mutedInk.opacity(0.82) : .white.opacity(0.70)
    }

    private var metricTrackFill: Color {
        colorScheme == .dark ? AppTheme.mutedInk.opacity(0.28) : .white.opacity(0.16)
    }
}

private struct ProMiniDonut: View {
    let gold: Color
    let centerFill: Color
    let trackFill: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackFill, lineWidth: 13)
            Circle()
                .trim(from: 0, to: 0.34)
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0.38, to: 0.64)
                .stroke(gold, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0.70, to: 0.90)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(centerFill)
                .frame(width: 36, height: 36)
        }
    }
}

private struct ProPreviewTaskRow: View {
    let icon: String
    let title: LocalizedStringKey
    let count: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.12))
                )

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            Spacer()

            Text(count)
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(AppTheme.mutedInk)
        }
    }
}

private struct ProRoadmapCard: View {
    let item: ProRoadmapItem
    let badge: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: item.icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(item.tint)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(item.tint.opacity(0.12))
                    )

                Spacer(minLength: 8)

                Text(badge)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(item.tint)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(item.tint.opacity(0.10)))
            }

            Text(item.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.88)

            Text(item.body)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(item.tint.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct ProFeatureCard: View {
    let item: ProFeatureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: item.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: item.icon)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Text(item.body)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.mutedInk.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct ProAssuranceRow: View {
    let item: ProAssuranceItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Text(item.body)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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
