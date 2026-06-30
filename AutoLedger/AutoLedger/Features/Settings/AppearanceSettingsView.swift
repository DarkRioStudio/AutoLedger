import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared
    @AppStorage(AppThemePreset.userDefaultsKey) private var selectedThemeRawValue = AppThemePreset.fresh.rawValue
    @AppStorage(AppColorSchemePreference.userDefaultsKey) private var selectedColorSchemeRawValue = AppColorSchemePreference.system.rawValue
    @AppStorage(AppThemeCustomTheme.surfaceHexKey) private var customSurfaceHex = AppThemeCustomTheme.defaultSurfaceHex
    @AppStorage(AppThemeCustomTheme.accentHexKey) private var customAccentHex = AppThemeCustomTheme.defaultAccentHex
    @AppStorage(AppThemeCustomTheme.secondaryHexKey) private var customSecondaryHex = AppThemeCustomTheme.defaultSecondaryHex
    @State private var isPresentingProSheet = false

    private let themeColumns = [GridItem(.adaptive(minimum: 146), spacing: 12)]

    private var selectedPreset: AppThemePreset {
        AppThemePreset(rawValue: selectedThemeRawValue) ?? .fresh
    }

    private var canUseCustomTheme: Bool {
        proEntitlement.isProActive
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

                themePickerGrid
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

                AppearancePreviewCard()
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
            enforceCustomThemeAccess()
        }
        .onChange(of: proEntitlement.isProActive) { _, _ in
            enforceCustomThemeAccess()
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

    private var themePickerGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("appearance.theme_picker")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            LazyVGrid(columns: themeColumns, spacing: 12) {
                ForEach(AppThemePreset.allCases) { preset in
                    Button {
                        selectTheme(preset)
                    } label: {
                        AppearanceThemeOptionCard(
                            preset: preset,
                            isSelected: selectedPreset == preset,
                            isLocked: preset.isCustom && !canUseCustomTheme
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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

            AppearanceThemeSwatches(colors: selectedPreset.previewColors)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .autoLedgerCardSurface(cornerRadius: 22)
        .id(selectedThemeRawValue)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .autoLedgerMotion(AppMotion.theme, value: selectedThemeRawValue)
    }

    private func selectTheme(_ preset: AppThemePreset) {
        if preset.isCustom && !canUseCustomTheme {
            isPresentingProSheet = true
            return
        }

        selectedThemeRawValue = preset.rawValue
    }

    private func enforceCustomThemeAccess() {
        guard selectedPreset.isCustom, !canUseCustomTheme else { return }
        selectedThemeRawValue = AppThemePreset.fresh.rawValue
    }

    private func resetCustomTheme() {
        customSurfaceHex = AppThemeCustomTheme.defaultSurfaceHex
        customAccentHex = AppThemeCustomTheme.defaultAccentHex
        customSecondaryHex = AppThemeCustomTheme.defaultSecondaryHex
    }
}

private struct AppearanceThemeOptionCard: View {
    let preset: AppThemePreset
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                AppearanceThemeSwatches(colors: preset.previewColors, swatchSize: 20)

                Spacer(minLength: 6)

                if isLocked {
                    Image(systemName: "crown.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(preset.localizedTitleKey)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                Text(preset.localizedSubtitleKey)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? AppTheme.accent.opacity(0.14) : AppTheme.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? AppTheme.accent.opacity(0.72) : AppTheme.cardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
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
