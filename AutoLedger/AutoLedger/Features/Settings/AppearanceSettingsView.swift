import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared
    @AppStorage(AppThemePreset.userDefaultsKey) private var selectedThemeRawValue = AppThemePreset.fresh.rawValue
    @AppStorage(AppColorSchemePreference.userDefaultsKey) private var selectedColorSchemeRawValue = AppColorSchemePreference.system.rawValue
    @AppStorage(AppThemeCustomTheme.surfaceHexKey) private var customSurfaceHex = AppThemeCustomTheme.defaultSurfaceHex
    @AppStorage(AppThemeCustomTheme.accentHexKey) private var customAccentHex = AppThemeCustomTheme.defaultAccentHex
    @AppStorage(AppThemeCustomTheme.secondaryHexKey) private var customSecondaryHex = AppThemeCustomTheme.defaultSecondaryHex
    @State private var isPresentingProSheet = false

    private var selectedPreset: AppThemePreset {
        let preset = AppThemePreset(rawValue: selectedThemeRawValue) ?? .fresh
        return AppThemePreset.selectableCases.contains(preset) ? preset : .fresh
    }

    private var canUseCustomTheme: Bool {
        proEntitlement.isProActive
    }

    private var selectedPreviewColors: [Color] {
        selectedPreset.resolvedPreviewColors(
            customSurfaceHex: customSurfaceHex,
            customAccentHex: customAccentHex,
            customSecondaryHex: customSecondaryHex
        )
    }

    private var customSurfaceColor: Binding<Color> {
        Binding(
            get: {
                AppThemeCustomTheme.color(
                    hex: customSurfaceHex,
                    fallback: AppThemeCustomTheme.defaultSurfaceHex
                )
            },
            set: { color in
                customSurfaceHex = AppThemeCustomTheme.hexString(
                    from: color,
                    fallback: AppThemeCustomTheme.defaultSurfaceHex
                )
            }
        )
    }

    private var customAccentColor: Binding<Color> {
        Binding(
            get: {
                AppThemeCustomTheme.color(
                    hex: customAccentHex,
                    fallback: AppThemeCustomTheme.defaultAccentHex
                )
            },
            set: { color in
                customAccentHex = AppThemeCustomTheme.hexString(
                    from: color,
                    fallback: AppThemeCustomTheme.defaultAccentHex
                )
            }
        )
    }

    private var customSecondaryColor: Binding<Color> {
        Binding(
            get: {
                AppThemeCustomTheme.color(
                    hex: customSecondaryHex,
                    fallback: AppThemeCustomTheme.defaultSecondaryHex
                )
            },
            set: { color in
                customSecondaryHex = AppThemeCustomTheme.hexString(
                    from: color,
                    fallback: AppThemeCustomTheme.defaultSecondaryHex
                )
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AutoLedgerPageTitle("appearance.title")

                themeMenuCard
                appearanceModeCard
                selectedThemeCard

                if selectedPreset.isCustom, canUseCustomTheme {
                    AppearanceCustomThemeControls(
                        surfaceColor: customSurfaceColor,
                        accentColor: customAccentColor,
                        secondaryColor: customSecondaryColor,
                        resetAction: resetCustomTheme
                    )
                    .autoLedgerMotion(AppMotion.theme, value: customSurfaceHex)
                    .autoLedgerMotion(AppMotion.theme, value: customAccentHex)
                    .autoLedgerMotion(AppMotion.theme, value: customSecondaryHex)
                } else if !canUseCustomTheme {
                    AppearanceCustomThemeLockedCard {
                        isPresentingProSheet = true
                    }
                }

                AppearancePreviewCard(
                    preset: selectedPreset,
                    customSurfaceHex: customSurfaceHex,
                    customAccentHex: customAccentHex,
                    customSecondaryHex: customSecondaryHex
                )
                    .autoLedgerMotion(AppMotion.theme, value: selectedThemeRawValue)
                    .autoLedgerMotion(AppMotion.theme, value: selectedColorSchemeRawValue)
                    .autoLedgerMotion(AppMotion.theme, value: customSurfaceHex)
                    .autoLedgerMotion(AppMotion.theme, value: customAccentHex)
                    .autoLedgerMotion(AppMotion.theme, value: customSecondaryHex)

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
        .sensoryFeedback(.selection, trigger: customSurfaceHex)
        .sensoryFeedback(.selection, trigger: customAccentHex)
        .sensoryFeedback(.selection, trigger: customSecondaryHex)
        .task {
            await proEntitlement.refreshEntitlements()
        }
        .onAppear {
            enforceThemeAvailability()
        }
        .onChange(of: selectedThemeRawValue) { _, _ in
            enforceThemeAvailability()
        }
        .onChange(of: proEntitlement.isProActive) { _, _ in
            enforceThemeAvailability()
        }
        .sheet(isPresented: $isPresentingProSheet) {
            NavigationStack {
                AutoLedgerProView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.done") {
                                isPresentingProSheet = false
                            }
                        }
                    }
            }
        }
    }

    private var themeMenuCard: some View {
        Menu {
            ForEach(AppThemePreset.selectableCases) { preset in
                Button {
                    selectTheme(preset)
                } label: {
                    if preset == selectedPreset {
                        Label(preset.localizedTitleKey, systemImage: "checkmark")
                    } else {
                        Text(preset.localizedTitleKey)
                    }
                }
            }
        } label: {
            themeDropdownLabel
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("appearance.theme_picker"))
        .accessibilityValue(Text(selectedPreset.localizedTitleKey))
        .autoLedgerMotion(AppMotion.theme, value: selectedThemeRawValue)
    }

    private var themeDropdownLabel: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("appearance.theme_picker")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                HStack(spacing: 8) {
                    Text(selectedPreset.localizedTitleKey)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.accent)

                    if selectedPreset.isCustom {
                        Text("appearance.custom.pro_badge")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule(style: .continuous).fill(AppTheme.accent))
                    }
                }

                Text(selectedPreset.localizedSubtitleKey)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 14) {
                AppearanceThemeSwatches(colors: selectedPreviewColors, swatchSize: 22)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 22)
    }

    private var appearanceModeCard: some View {
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
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 22)
        .autoLedgerMotion(AppMotion.theme, value: selectedColorSchemeRawValue)
    }

    private var selectedThemeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(selectedPreset.localizedTitleKey)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                if selectedPreset.isCustom {
                    Text("appearance.custom.pro_badge")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(AppTheme.accent))
                }
            }

            Text(selectedPreset.localizedSubtitleKey)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            AppearanceThemeSwatches(colors: selectedPreviewColors)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 22)
        .id(selectedThemeRawValue)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .autoLedgerMotion(AppMotion.theme, value: selectedThemeRawValue)
    }

    private func selectTheme(_ preset: AppThemePreset) {
        guard AppThemePreset.selectableCases.contains(preset) else {
            selectedThemeRawValue = AppThemePreset.fresh.rawValue
            return
        }

        if preset.isCustom && !canUseCustomTheme {
            isPresentingProSheet = true
            return
        }

        selectedThemeRawValue = preset.rawValue
    }

    private func enforceThemeAvailability() {
        let storedPreset = AppThemePreset(rawValue: selectedThemeRawValue) ?? .fresh

        guard AppThemePreset.selectableCases.contains(storedPreset) else {
            selectedThemeRawValue = AppThemePreset.fresh.rawValue
            return
        }

        guard storedPreset.isCustom, !canUseCustomTheme else { return }
        selectedThemeRawValue = AppThemePreset.fresh.rawValue
    }

    private func resetCustomTheme() {
        customSurfaceHex = AppThemeCustomTheme.defaultSurfaceHex
        customAccentHex = AppThemeCustomTheme.defaultAccentHex
        customSecondaryHex = AppThemeCustomTheme.defaultSecondaryHex
    }
}

private struct AppearanceThemeSwatches: View {
    let colors: [Color]
    var swatchSize: CGFloat = 42

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: swatchSize * 0.24, style: .continuous)
                    .fill(color)
                    .frame(width: swatchSize, height: swatchSize)
                    .overlay {
                        RoundedRectangle(cornerRadius: swatchSize * 0.24, style: .continuous)
                            .stroke(AppTheme.cardStroke, lineWidth: 1)
                    }
            }
        }
    }
}

private struct AppearanceCustomThemeControls: View {
    @Binding var surfaceColor: Color
    @Binding var accentColor: Color
    @Binding var secondaryColor: Color
    let resetAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("appearance.custom.controls.title")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text("appearance.custom.controls.body")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                AppearanceCustomColorPickerRow(
                    title: "appearance.custom.surface",
                    color: $surfaceColor
                )

                AppearanceCustomColorPickerRow(
                    title: "appearance.custom.accent",
                    color: $accentColor
                )

                AppearanceCustomColorPickerRow(
                    title: "appearance.custom.secondary",
                    color: $secondaryColor
                )
            }

            Button(action: resetAction) {
                Label("appearance.custom.reset", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.accent)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 22)
    }
}

private struct AppearanceCustomColorPickerRow: View {
    let title: LocalizedStringKey
    @Binding var color: Color

    var body: some View {
        ColorPicker(selection: $color, supportsOpacity: false) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
    }
}

private struct AppearanceCustomThemeLockedCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("appearance.custom.locked.title")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Text("appearance.custom.locked.body")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Label("appearance.custom.locked.action", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }

                Spacer(minLength: 8)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .autoLedgerCardSurface(cornerRadius: 22)
        }
        .buttonStyle(.plain)
    }
}

private struct AppearancePreviewCard: View {
    let preset: AppThemePreset
    let customSurfaceHex: String
    let customAccentHex: String
    let customSecondaryHex: String

    private var previewStyle: AppThemePreviewStyle {
        preset.resolvedPreviewStyle(
            customSurfaceHex: customSurfaceHex,
            customAccentHex: customAccentHex,
            customSecondaryHex: customSecondaryHex
        )
    }

    var body: some View {
        let style = previewStyle

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(style.accent)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("appearance.preview.title")
                        .font(.headline)
                        .foregroundStyle(style.ink)

                    Text("appearance.preview.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(style.mutedInk)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                AppearancePreviewMetric(title: "appearance.preview.month", value: "$1,428", style: style)
                AppearancePreviewMetric(title: "appearance.preview.queue", value: "4", style: style)
            }

            VStack(spacing: 0) {
                AppearancePreviewRow(icon: "cup.and.saucer.fill", title: "Blue Bottle", subtitle: "Food & drink", amount: "-$6.80", style: style)
                Divider().overlay(style.cardStroke)
                AppearancePreviewRow(icon: "building.2.fill", title: "Conference hotel", subtitle: "Travel", amount: "-$284.12", style: style)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(style.card.opacity(0.78))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(style.cardStroke, lineWidth: 1)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(style.canvas)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(style.cardStroke, lineWidth: 1)
        }
        .shadow(color: style.accent.opacity(0.14), radius: 18, x: 0, y: 10)
    }
}

private struct AppearancePreviewMetric: View {
    let title: LocalizedStringKey
    let value: String
    let style: AppThemePreviewStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.mutedInk)

            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(style.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(style.accent.opacity(0.12))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style.cardStroke.opacity(0.8), lineWidth: 1)
        }
    }
}

private struct AppearancePreviewRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let amount: String
    let style: AppThemePreviewStyle

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(style.accent)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(style.accent.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(style.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(style.mutedInk)
            }

            Spacer()

            Text(amount)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(style.ink)
        }
        .padding(12)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
