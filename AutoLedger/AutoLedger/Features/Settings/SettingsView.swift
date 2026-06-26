import AutoLedgerCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @EnvironmentObject private var navigationState: AutoLedgerNavigationState
    @State private var versionTapCount = 0
    @State private var showDebugUnlocked = false
    @State private var showFeedbackComposer = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack(path: $navigationState.settingsPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if showDebugUnlocked {
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
                        SubscriptionListView()
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            icon: "repeat.circle.fill",
                            iconColor: Color(red: 0.80, green: 0.47, blue: 0.16),
                            title: "settings.subscriptions.title",
                            subtitle: "settings.subscriptions.subtitle"
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

                    toggleCard(
                        icon: "bell.badge.fill",
                        iconColor: Color(red: 0.80, green: 0.47, blue: 0.16),
                        title: "settings.subscription_reminder.title",
                        subtitle: "settings.subscription_reminder.subtitle",
                        key: "subscriptionReminder"
                    )

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

                    toggleCard(
                        icon: "doc.on.clipboard",
                        iconColor: .orange,
                        title: "settings.clipboard_auto_import.title",
                        subtitle: "settings.clipboard_auto_import.subtitle",
                        key: "autoClipboardImport"
                    )

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
                        Text("settings.version.title")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text("v\(appVersion) — \(String(localized: "settings.version.body"))")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .onTapGesture {
                        versionTapCount += 1
                        if versionTapCount >= 5 && !showDebugUnlocked {
                            showDebugUnlocked = true
                            versionTapCount = 0
                        }
                    }

                    infoCard(
                        title: "settings.privacy.title",
                        body: "settings.privacy.body"
                    )

                    infoCard(
                        title: "settings.release_status.title",
                        body: "settings.release_status.body"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("settings.title")
            .navigationDestination(for: SettingsNavigationTarget.self) { target in
                switch target {
                case .ledgerProfiles:
                    LedgerProfileManagementView()
                        .environmentObject(store)
                }
            }
            .sheet(isPresented: $showFeedbackComposer) {
                FeedbackComposerView()
                    .environmentObject(store)
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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func infoCard(title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

}


#Preview {
    SettingsView()
        .environmentObject(LedgerStore())
        .environmentObject(AutoLedgerNavigationState())
}
