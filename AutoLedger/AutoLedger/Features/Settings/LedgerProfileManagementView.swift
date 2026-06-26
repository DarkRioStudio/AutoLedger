import AutoLedgerCore
import SwiftUI

struct LedgerProfileManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore
    @State private var showAddAlert = false
    @State private var newLedgerName = ""
    @State private var newLedgerCurrency = ""
    @State private var profilePendingRename: LedgerProfile?
    @State private var renameLedgerName = ""
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

                Text("ledger_profiles.default_write.description")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if profile.id != TodaySpendingSummary.defaultLedgerID {
                                Button(role: .destructive) {
                                    store.archiveLedgerProfile(profile)
                                } label: {
                                    Label("ledger_profiles.action.archive", systemImage: "archivebox.fill")
                                }
                            }

                            Button {
                                beginRename(profile)
                            } label: {
                                Label("ledger_profiles.action.rename", systemImage: "pencil")
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
                    }
                } header: {
                    Text("ledger_profiles.archived")
                }
            }
        }
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
                    showAddAlert = true
                } label: {
                    Label("ledger_profiles.add", systemImage: "plus")
                }
            }
        }
        .alert("ledger_profiles.add.title", isPresented: $showAddAlert) {
            TextField("ledger_profiles.name.placeholder", text: $newLedgerName)
            TextField("ledger_profiles.currency.placeholder", text: $newLedgerCurrency)
            Button("common.cancel", role: .cancel) {
                clearAddForm()
            }
            Button("common.add") {
                store.createLedgerProfile(
                    name: newLedgerName,
                    iconName: "wallet.pass",
                    colorName: "accent",
                    currency: newLedgerCurrency
                )
                clearAddForm()
            }
        }
        .alert(
            "ledger_profiles.rename.title",
            isPresented: Binding(
                get: { profilePendingRename != nil },
                set: { if !$0 { profilePendingRename = nil } }
            )
        ) {
            TextField("ledger_profiles.name.placeholder", text: $renameLedgerName)
            Button("common.cancel", role: .cancel) {
                profilePendingRename = nil
                renameLedgerName = ""
            }
            Button("common.save") {
                if let profilePendingRename {
                    store.renameLedgerProfile(profilePendingRename, name: renameLedgerName)
                }
                profilePendingRename = nil
                renameLedgerName = ""
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
                    if let currency = profile.currency, !currency.isEmpty {
                        Text(currency)
                    } else {
                        Text("ledger_profiles.currency.none")
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

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
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

    private func beginRename(_ profile: LedgerProfile) {
        profilePendingRename = profile
        renameLedgerName = profile.name
    }

    private func clearAddForm() {
        newLedgerName = ""
        newLedgerCurrency = ""
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

#Preview {
    NavigationStack {
        LedgerProfileManagementView()
            .environmentObject(LedgerStore())
    }
}
