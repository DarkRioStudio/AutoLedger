import SwiftUI

struct LanguageSettingsView: View {
    @AppStorage(AppLanguagePreference.userDefaultsKey) private var selectedLanguageRawValue = AppLanguagePreference.system.rawValue
    @AppStorage(ExpenseCurrencyPreference.userDefaultsKey) private var selectedExpenseCurrencyRawValue = ExpenseCurrencyPreference.systemValue
    @Environment(\.locale) private var locale

    private var selectedLanguage: AppLanguagePreference {
        AppLanguagePreference(rawValue: selectedLanguageRawValue) ?? .system
    }

    private var selectedExpenseCurrencyCode: String {
        let rawValue = ExpenseCurrencyPreference.normalizedRawValue(selectedExpenseCurrencyRawValue)
        if rawValue == ExpenseCurrencyPreference.systemValue {
            return ExpenseCurrencyPreference.systemCurrencyCode
        }
        return LedgerCurrencyOption.supportedCode(matching: rawValue)
    }

    private var sensoryFeedbackToken: String {
        "\(selectedLanguageRawValue)-\(selectedExpenseCurrencyRawValue)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AutoLedgerPageTitle("language.title")

                VStack(alignment: .leading, spacing: 12) {
                    Text("language.body")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        ForEach(AppLanguagePreference.allCases) { preference in
                            languageRow(for: preference)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .autoLedgerCardSurface(cornerRadius: 22)

                VStack(alignment: .leading, spacing: 12) {
                    Text("language.currency.body")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    defaultCurrencyRow
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .autoLedgerCardSurface(cornerRadius: 22)

                Text("language.footer")
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
        .autoLedgerContentTitleNavigation("language.title")
        .sensoryFeedback(.selection, trigger: sensoryFeedbackToken)
    }

    private func languageRow(for preference: AppLanguagePreference) -> some View {
        let isSelected = preference == selectedLanguage

        return Button {
            selectedLanguageRawValue = preference.rawValue
        } label: {
            HStack(spacing: 12) {
                Image(systemName: preference == .system ? "gearshape.fill" : "character.book.closed.fill")
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : AppTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? AppTheme.accent : AppTheme.accent.opacity(0.12))
                    )

                Text(preference.localizedTitleKey)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.12) : AppTheme.card.opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.45) : AppTheme.cardStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(preference.localizedTitleKey))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var defaultCurrencyRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "banknote.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("language.currency.title")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(defaultCurrencySubtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button {
                    selectedExpenseCurrencyRawValue = ExpenseCurrencyPreference.systemValue
                } label: {
                    currencyMenuLabel(
                        title: String(
                            format: localizedString("language.currency.system_format"),
                            ExpenseCurrencyPreference.systemCurrencyCode
                        ),
                        isSelected: selectedExpenseCurrencyRawValue == ExpenseCurrencyPreference.systemValue
                    )
                }

                ForEach(LedgerCurrencyOption.common) { option in
                    Button {
                        selectedExpenseCurrencyRawValue = option.code
                    } label: {
                        currencyMenuLabel(
                            title: option.localizedTitle,
                            isSelected: selectedExpenseCurrencyRawValue == option.code
                        )
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedExpenseCurrencyCode)
                        .font(.headline.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppTheme.accent.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
    }

    private var defaultCurrencySubtitle: String {
        if selectedExpenseCurrencyRawValue == ExpenseCurrencyPreference.systemValue {
            return String(
                format: localizedString("language.currency.subtitle_system_format"),
                ExpenseCurrencyPreference.systemCurrencyCode
            )
        }
        return String(format: localizedString("language.currency.subtitle_custom_format"), selectedExpenseCurrencyCode)
    }

    private func localizedString(_ key: String) -> String {
        if selectedLanguage == .system {
            return AppLanguagePreference.localizedString(key, locale: locale)
        }
        return AppLanguagePreference.localizedString(key, languageKey: selectedLanguage.catalogLanguageKey)
    }

    private func currencyMenuLabel(title: String, isSelected: Bool) -> some View {
        Label {
            Text(title)
        } icon: {
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
