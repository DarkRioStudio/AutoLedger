import AutoLedgerCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @EnvironmentObject private var navigationState: AutoLedgerNavigationState
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared
    private let topContentPadding: CGFloat
    @State private var versionTapCount = 0
    @State private var showDebugUnlocked = false
    @State private var showFeedbackComposer = false
    @State private var releaseNotes: CommonAPIReleaseNotesService.ReleaseNotes?

    init(topContentPadding: CGFloat = 20) {
        self.topContentPadding = topContentPadding
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var releaseNotesTaskID: String {
        "\(appVersion)-\(AppLanguagePreference.current.catalogLanguageKey)"
    }

    private var currentVersionTitle: String {
        releaseNotes?.current.title ?? String(localized: "settings.version.title")
    }

    private var currentVersionBody: String {
        releaseNotes?.current.body ?? String(localized: "settings.version.body")
    }

    private var upcomingVersionTitle: String {
        releaseNotes?.upcoming.title ?? String(localized: "settings.release_status.title")
    }

    private var upcomingVersionBody: String {
        releaseNotes?.upcoming.body ?? String(localized: "settings.release_status.body")
    }

    private var privacyPolicyURL: URL {
        URL(string: "https://getautoledger.app/privacy")!
    }

    var body: some View {
        NavigationStack(path: $navigationState.settingsPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AutoLedgerPageTitle("settings.title")

                    NavigationLink {
                        AutoLedgerProView()
                    } label: {
                        proHighlightCard()
                    }
                    .buttonStyle(.plain)

                    settingsSection(title: "settings.section.appearance") {
                        NavigationLink(value: SettingsNavigationTarget.appearance) {
                            settingsRow(
                                icon: "paintpalette.fill",
                                iconColor: AppTheme.accentSecondary,
                                title: "settings.appearance.title",
                                subtitle: "settings.appearance.subtitle"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection(title: "settings.section.language_region") {
                        NavigationLink(value: SettingsNavigationTarget.language) {
                            settingsRow(
                                icon: "globe",
                                iconColor: Color(red: 0.20, green: 0.51, blue: 0.70),
                                title: "settings.language.title",
                                subtitle: "settings.language.subtitle"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection(title: "settings.section.ledger_sync") {
                        NavigationLink(value: SettingsNavigationTarget.ledgerProfiles) {
                            settingsRow(
                                icon: "books.vertical.fill",
                                iconColor: Color(red: 0.17, green: 0.47, blue: 0.34),
                                title: "settings.ledger_profiles.title",
                                subtitle: "settings.ledger_profiles.subtitle"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            DataManagementView()
                                .environmentObject(store)
                        } label: {
                            settingsRow(
                                icon: "externaldrive.fill.badge.icloud",
                                iconColor: Color(red: 0.16, green: 0.45, blue: 0.73),
                                title: "settings.data_management.title",
                                subtitle: "settings.data_management.subtitle"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection(title: "settings.section.recognition") {
                        NavigationLink {
                            AIModelSettingsView()
                        } label: {
                            settingsRow(
                                icon: "cpu.fill",
                                iconColor: Color(red: 0.17, green: 0.47, blue: 0.34),
                                title: "settings.ai_model.title",
                                subtitle: "settings.ai_model.subtitle"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ExternalReceiptAssistSettingsView()
                        } label: {
                            settingsRow(
                                icon: "sparkles.rectangle.stack.fill",
                                iconColor: Color(red: 0.35, green: 0.38, blue: 0.82),
                                title: "settings.external_assist.title",
                                subtitle: "settings.external_assist.subtitle"
                            )
                        }
                        .buttonStyle(.plain)

                        toggleCard(
                            icon: "doc.on.clipboard",
                            iconColor: .orange,
                            title: "settings.clipboard_auto_import.title",
                            subtitle: "settings.clipboard_auto_import.subtitle",
                            key: "autoClipboardImport"
                        )

                        NavigationLink {
                            AnalysisSettingsView()
                        } label: {
                            settingsRow(
                                icon: "chart.line.uptrend.xyaxis",
                                iconColor: Color(red: 0.20, green: 0.51, blue: 0.70),
                                title: "settings.analysis.title",
                                subtitle: "settings.analysis.subtitle"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection(title: "settings.section.rules") {
                        NavigationLink {
                            CategoryManagementView()
                                .environmentObject(store)
                        } label: {
                            settingsRow(
                                icon: "square.grid.2x2.fill",
                                iconColor: AppTheme.accentSecondary,
                                title: "settings.categories.title",
                                subtitle: "settings.categories.subtitle"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SourceManagementView()
                                .environmentObject(store)
                        } label: {
                            settingsRow(
                                icon: "arrow.triangle.branch",
                                iconColor: Color(red: 0.07, green: 0.47, blue: 0.87),
                                title: "settings.sources.title",
                                subtitle: "settings.sources.subtitle"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            MerchantAliasView()
                                .environmentObject(store)
                        } label: {
                            settingsRow(
                                icon: "person.text.rectangle.fill",
                                iconColor: Color(red: 0.33, green: 0.59, blue: 0.41),
                                title: "settings.aliases.title",
                                subtitle: "settings.aliases.subtitle"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            CategoryLearningView()
                                .environmentObject(store)
                        } label: {
                            settingsRow(
                                icon: "brain.head.profile",
                                iconColor: Color(red: 0.55, green: 0.36, blue: 0.69),
                                title: "settings.category_learning.title",
                                subtitle: "settings.category_learning.subtitle"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection(title: "settings.section.recurring") {
                        NavigationLink(value: SettingsNavigationTarget.subscriptions) {
                            settingsRow(
                                icon: "repeat.circle.fill",
                                iconColor: Color(red: 0.80, green: 0.47, blue: 0.16),
                                title: "settings.subscriptions.title",
                                subtitle: "settings.subscriptions.subtitle"
                            )
                        }
                        .buttonStyle(.plain)

                        toggleCard(
                            icon: "bell.badge.fill",
                            iconColor: Color(red: 0.80, green: 0.47, blue: 0.16),
                            title: "settings.subscription_reminder.title",
                            subtitle: "settings.subscription_reminder.subtitle",
                            key: "subscriptionReminder"
                        )
                    }

                    settingsSection(title: "settings.section.support") {
                        Button {
                            showFeedbackComposer = true
                        } label: {
                            settingsRow(
                                icon: "envelope.fill",
                                iconColor: Color(red: 0.20, green: 0.56, blue: 0.82),
                                title: "settings.feedback.title",
                                subtitle: "settings.feedback.subtitle"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SupportAutoLedgerView()
                        } label: {
                            settingsRow(
                                icon: "heart.circle.fill",
                                iconColor: AppTheme.accentSecondary,
                                title: "settings.support.title",
                                subtitle: "settings.support.subtitle"
                            )
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(currentVersionTitle)
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            Text("v\(appVersion) — \(currentVersionBody)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.mutedInk)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .autoLedgerCardSurface(cornerRadius: 22)
                        .onTapGesture {
                            versionTapCount += 1
                            if versionTapCount >= 5 && !showDebugUnlocked {
                                showDebugUnlocked = true
                                versionTapCount = 0
                            }
                        }

                        privacyCard()

                        infoCard(
                            title: upcomingVersionTitle,
                            body: upcomingVersionBody
                        )
                    }

                    if showDebugUnlocked {
                        settingsSection(title: "settings.section.developer") {
                            NavigationLink {
                                DebugView()
                                    .environmentObject(store)
                            } label: {
                                settingsRow(
                                    icon: "ladybug.fill",
                                    iconColor: AppTheme.accent,
                                    title: "settings.debug.title",
                                    subtitle: "settings.debug.subtitle"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, topContentPadding)
                .padding(.bottom, 20)
                .autoLedgerReadableContent(maxWidth: 760)
            }
            .autoLedgerScreenChrome()
            .autoLedgerSolidNavigationBarChrome()
            .autoLedgerContentTitleNavigation("settings.title")
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
            .navigationDestination(for: SettingsNavigationTarget.self) { target in
                switch target {
                case .appearance:
                    AppearanceSettingsView()
                case .language:
                    LanguageSettingsView()
                case .ledgerProfiles:
                    LedgerProfileManagementView()
                        .environmentObject(store)
                case .subscriptions:
                    SubscriptionListView()
                        .environmentObject(store)
                }
            }
            .sheet(isPresented: $showFeedbackComposer) {
                FeedbackComposerView()
                    .environmentObject(store)
            }
            .task {
                guard proEntitlement.products.isEmpty else { return }
                await proEntitlement.loadProducts()
            }
            .task(id: releaseNotesTaskID) {
                releaseNotes = CommonAPIReleaseNotesService.cachedReleaseNotes(appVersion: appVersion)
                releaseNotes = await CommonAPIReleaseNotesService.refreshReleaseNotes(appVersion: appVersion)
            }
        }
    }

    private func proHighlightCard() -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.26), lineWidth: 1)
                    }

                Image(systemName: "crown.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.30))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("settings.pro.title")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.84)

                    Text("pro.hero.badge")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.08))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 1.0, green: 0.82, blue: 0.30))
                        )
                }

                Text("settings.pro.subtitle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                proPriceStack

                Label("pro.cta.view_plans", systemImage: "arrow.right.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.14, green: 0.16, blue: 0.15))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.92))
                    )
            }

            Image(systemName: "chevron.right")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.22, blue: 0.34),
                            AppTheme.accent,
                            Color(red: 0.76, green: 0.51, blue: 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: AppTheme.softShadow.opacity(1.6), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .combine)
    }

    private var proPriceStack: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "tag.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.84))
                .frame(width: 14, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(settingsPriceLine(for: .monthly))
                Text(settingsPriceLine(for: .yearly))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.84))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(2)
        }
    }

    private func settingsPriceLine(for proProduct: AutoLedgerProProduct) -> String {
        guard let price = proEntitlement.displayPrice(for: proProduct) else {
            return String(localized: "pro.price.loading_short")
        }

        switch proProduct {
        case .monthly:
            return String(format: String(localized: "pro.hero.price_monthly_format"), price)
        case .yearly:
            return String(format: String(localized: "pro.hero.price_yearly_format"), price)
        }
    }

    private func settingsSection<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.mutedInk)
                .padding(.horizontal, 2)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
    }

    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.mutedInk)
                .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 22)
    }

    private func toggleCard(
        icon: String,
        iconColor: Color,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        key: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: key) },
                set: { UserDefaults.standard.set($0, forKey: key) }
            ))
            .labelsHidden()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 22)
    }

    private func infoCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text(body)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 22)
    }

    private func privacyCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.privacy.title")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text("settings.privacy.body")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)

            Link(destination: privacyPolicyURL) {
                Label("settings.privacy.link", systemImage: "safari.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 22)
    }

}


#Preview {
    SettingsView()
        .environmentObject(LedgerStore())
        .environmentObject(AutoLedgerNavigationState())
}
