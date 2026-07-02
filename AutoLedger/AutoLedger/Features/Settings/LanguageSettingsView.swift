import SwiftUI

struct LanguageSettingsView: View {
    @AppStorage(AppLanguagePreference.userDefaultsKey) private var selectedLanguageRawValue = AppLanguagePreference.system.rawValue

    private var selectedLanguage: AppLanguagePreference {
        AppLanguagePreference(rawValue: selectedLanguageRawValue) ?? .system
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
        .sensoryFeedback(.selection, trigger: selectedLanguageRawValue)
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
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
