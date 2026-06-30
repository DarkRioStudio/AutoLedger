import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(AppThemePreset.userDefaultsKey) private var selectedThemeRawValue = AppThemePreset.fresh.rawValue
    @AppStorage(AppColorSchemePreference.userDefaultsKey) private var selectedColorSchemeRawValue = AppColorSchemePreference.system.rawValue

    private var selectedPreset: AppThemePreset {
        AppThemePreset(rawValue: selectedThemeRawValue) ?? .fresh
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AutoLedgerPageTitle("appearance.title")

                Picker("appearance.theme_picker", selection: $selectedThemeRawValue) {
                    ForEach(AppThemePreset.allCases) { preset in
                        Text(preset.localizedTitleKey)
                            .tag(preset.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppTheme.accent)
                .accessibilityLabel(Text("appearance.theme_picker"))

                VStack(alignment: .leading, spacing: 12) {
                    Text("appearance.mode.title")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Picker("appearance.mode_picker", selection: $selectedColorSchemeRawValue) {
                        ForEach(AppColorSchemePreference.allCases) { preference in
                            Text(preference.localizedTitleKey)
                                .tag(preference.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(AppTheme.accent)
                    .accessibilityLabel(Text("appearance.mode_picker"))

                    Text("appearance.mode.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .autoLedgerCardSurface(cornerRadius: 22)
                .autoLedgerMotion(AppMotion.theme, value: selectedColorSchemeRawValue)

                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedPreset.localizedTitleKey)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text(selectedPreset.localizedSubtitleKey)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        AppearanceColorSwatch(color: AppTheme.canvas, title: "appearance.swatch.canvas")
                        AppearanceColorSwatch(color: AppTheme.card, title: "appearance.swatch.card")
                        AppearanceColorSwatch(color: AppTheme.accent, title: "appearance.swatch.accent")
                        AppearanceColorSwatch(color: AppTheme.accentSecondary, title: "appearance.swatch.secondary")
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .autoLedgerCardSurface(cornerRadius: 22)
                .id(selectedThemeRawValue)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .autoLedgerMotion(AppMotion.theme, value: selectedThemeRawValue)

                AppearancePreviewCard()
                    .autoLedgerMotion(AppMotion.theme, value: selectedThemeRawValue)
                    .autoLedgerMotion(AppMotion.theme, value: selectedColorSchemeRawValue)

                Text("appearance.footer")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .autoLedgerReadableContent(maxWidth: 760, alignment: .leading)
        }
        .autoLedgerScreenChrome()
        .autoLedgerSolidNavigationBarChrome()
        .autoLedgerContentTitleNavigation("appearance.title")
        .autoLedgerMotion(AppMotion.theme, value: selectedThemeRawValue)
        .autoLedgerMotion(AppMotion.theme, value: selectedColorSchemeRawValue)
        .sensoryFeedback(.selection, trigger: selectedThemeRawValue)
        .sensoryFeedback(.selection, trigger: selectedColorSchemeRawValue)
    }
}

private struct AppearanceColorSwatch: View {
    let color: Color
    let title: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(height: 42)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.cardStroke, lineWidth: 1)
                }

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AppearancePreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(AppTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("appearance.preview.title")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Text("appearance.preview.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                AppearancePreviewMetric(title: "appearance.preview.month", value: "$1,428")
                AppearancePreviewMetric(title: "appearance.preview.queue", value: "4")
            }

            VStack(spacing: 0) {
                AppearancePreviewRow(icon: "cup.and.saucer.fill", title: "Blue Bottle", subtitle: "Food & drink", amount: "-$6.80")
                Divider().overlay(AppTheme.cardStroke)
                AppearancePreviewRow(icon: "building.2.fill", title: "Conference hotel", subtitle: "Travel", amount: "-$284.12")
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.card.opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 22)
    }
}

private struct AppearancePreviewMetric: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)

            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.accent.opacity(0.10))
        )
    }
}

private struct AppearancePreviewRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let amount: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            Text(amount)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(12)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
