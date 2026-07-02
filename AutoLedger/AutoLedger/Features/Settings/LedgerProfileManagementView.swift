import AutoLedgerCore
import SwiftUI

struct LedgerProfileManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    @EnvironmentObject private var store: LedgerStore
    @State private var editorMode: LedgerProfileEditorMode?
    let allowsSelection: Bool
    let showsDoneButton: Bool

    init(allowsSelection: Bool = false, showsDoneButton: Bool = false) {
        self.allowsSelection = allowsSelection
        self.showsDoneButton = showsDoneButton
    }

    private var activeProfiles: [LedgerProfile] {
        store.ledgerProfiles.filter { !$0.isArchived }
    }

    private var archivedProfiles: [LedgerProfile] {
        store.ledgerProfiles.filter(\.isArchived)
    }

    var body: some View {
        List {
            Section {
                Picker(
                    "ledger_profiles.default_write.current",
                    selection: Binding(
                        get: { store.defaultWriteLedgerID },
                        set: { ledgerID in
                            guard let profile = activeProfiles.first(where: { $0.id == ledgerID }) else { return }
                            store.setDefaultWriteLedgerProfile(profile)
                        }
                    )
                ) {
                    ForEach(activeProfiles) { profile in
                        Text(profile.name)
                            .tag(profile.id)
                    }
                }
                .tint(AppTheme.accent)
                .listRowBackground(AppTheme.card)

                Text("ledger_profiles.default_write.description")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                    .listRowBackground(AppTheme.card)
            } header: {
                Text("ledger_profiles.default_write.section")
            }

            Section {
                ForEach(activeProfiles) { profile in
                    ledgerRow(profile)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard allowsSelection else { return }
                            store.selectLedgerProfile(profile)
                        }
                        .listRowBackground(AppTheme.card)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if profile.id != TodaySpendingSummary.defaultLedgerID {
                                Button(role: .destructive) {
                                    store.archiveLedgerProfile(profile)
                                } label: {
                                    Label("ledger_profiles.action.archive", systemImage: "archivebox.fill")
                                }
                            }

                            Button {
                                beginEdit(profile)
                            } label: {
                                Label("ledger_profiles.action.edit", systemImage: "square.and.pencil")
                            }
                            .tint(AppTheme.accentSecondary)

                            if !profile.isDefault {
                                Button {
                                    store.setDefaultLedgerProfile(profile)
                                } label: {
                                    Label("ledger_profiles.action.set_default", systemImage: "checkmark.circle.fill")
                                }
                                .tint(AppTheme.accent)
                            }

                            if store.defaultWriteLedgerID != profile.id {
                                Button {
                                    store.setDefaultWriteLedgerProfile(profile)
                                } label: {
                                    Label("ledger_profiles.action.set_default_write", systemImage: "square.and.pencil")
                                }
                                .tint(AppTheme.accentSecondary)
                            }
                        }
                }
            } header: {
                Text("ledger_profiles.active")
            }

            if !archivedProfiles.isEmpty {
                Section {
                    ForEach(archivedProfiles) { profile in
                        ledgerRow(profile)
                            .listRowBackground(AppTheme.card)
                    }
                } header: {
                    Text("ledger_profiles.archived")
                }
            }
        }
        .autoLedgerListChrome()
        .autoLedgerNavigationBarChrome()
        .tint(AppTheme.accent)
        .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
        .navigationTitle("ledger_profiles.title")
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .add
                } label: {
                    Label("ledger_profiles.add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            LedgerProfileEditorSheet(mode: mode) { name, currency in
                switch mode {
                case .add:
                    store.createLedgerProfile(
                        name: name,
                        iconName: "wallet.pass",
                        colorName: "accent",
                        currency: currency
                    )
                case .edit(let profile):
                    store.updateLedgerProfile(profile, name: name, currency: currency)
                }
            }
        }
    }

    private func ledgerRow(_ profile: LedgerProfile) -> some View {
        let isSelected = allowsSelection && !store.isShowingAllLedgers && store.selectedLedgerID == profile.id
        return HStack(spacing: 12) {
            Image(systemName: profile.iconName ?? "wallet.pass")
                .foregroundStyle(color(for: profile))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 5) {
                Text(profile.name)
                    .foregroundStyle(AppTheme.ink)

                HStack(spacing: 6) {
                    let currency = profile.currency?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let currency, !currency.isEmpty {
                        Text(currency)
                    } else {
                        Text(LedgerCurrencyOption.defaultCode)
                    }

                    if profile.isDefault {
                        statusBadge("ledger_profiles.badge.default")
                    }

                    if store.defaultWriteLedgerID == profile.id {
                        statusBadge("ledger_profiles.badge.default_write")
                    }

                    if profile.isArchived {
                        statusBadge("ledger_profiles.badge.archived")
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            profileRenameButton(profile)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
    }

    private func profileRenameButton(_ profile: LedgerProfile) -> some View {
        Button {
            beginEdit(profile)
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 30, height: 30)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("ledger_profiles.action.edit"))
        .accessibilityValue(Text(profile.name))
    }

    private func statusBadge(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppTheme.accent.opacity(0.12))
            .clipShape(Capsule())
    }

    private func beginEdit(_ profile: LedgerProfile) {
        editorMode = .edit(profile)
    }

    private func color(for profile: LedgerProfile) -> Color {
        switch profile.colorName {
        case "teal":
            return Color(red: 0.11, green: 0.55, blue: 0.56)
        case "orange":
            return Color(red: 0.80, green: 0.47, blue: 0.16)
        case "green":
            return Color(red: 0.33, green: 0.59, blue: 0.41)
        default:
            return AppTheme.accent
        }
    }
}

private enum LedgerProfileEditorMode: Identifiable {
    case add
    case edit(LedgerProfile)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let profile):
            return profile.id
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .add:
            return "ledger_profiles.add.title"
        case .edit:
            return "ledger_profiles.edit.title"
        }
    }

    var saveTitleKey: LocalizedStringKey {
        switch self {
        case .add:
            return "common.add"
        case .edit:
            return "common.save"
        }
    }

    var initialName: String {
        switch self {
        case .add:
            return ""
        case .edit(let profile):
            return profile.name
        }
    }

    var initialCurrency: String {
        switch self {
        case .add:
            return LedgerCurrencyOption.defaultCode
        case .edit(let profile):
            return LedgerCurrencyOption.supportedCode(matching: profile.currency)
        }
    }
}

private struct LedgerProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    let mode: LedgerProfileEditorMode
    let onSave: (String, String) -> Void
    @State private var ledgerName: String
    @State private var selectedCurrency: String

    init(mode: LedgerProfileEditorMode, onSave: @escaping (String, String) -> Void) {
        self.mode = mode
        self.onSave = onSave
        _ledgerName = State(initialValue: mode.initialName)
        _selectedCurrency = State(initialValue: mode.initialCurrency)
    }

    private var canSave: Bool {
        !ledgerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ledger_profiles.name.placeholder", text: $ledgerName)
                        .textInputAutocapitalization(.words)
                    Picker("ledger_profiles.currency.label", selection: $selectedCurrency) {
                        ForEach(LedgerCurrencyOption.common) { option in
                            Text(option.localizedTitle)
                                .tag(option.code)
                        }
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text("ledger_profiles.currency.description")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle(mode.titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(mode.saveTitleKey) {
                        onSave(ledgerName, selectedCurrency)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .tint(AppTheme.accent)
            .autoLedgerNavigationBarChrome()
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack {
        LedgerProfileManagementView()
            .environmentObject(LedgerStore())
    }
}
