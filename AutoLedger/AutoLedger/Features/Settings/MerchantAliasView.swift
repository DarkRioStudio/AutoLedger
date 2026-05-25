import AutoLedgerCore
import SwiftUI

struct MerchantAliasView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showAddAlert = false
    @State private var newOriginal = ""
    @State private var newAlias = ""

    private var sortedKeys: [String] {
        store.merchantAliases.keys.sorted()
    }

    var body: some View {
        List {
            Section {
                ForEach(sortedKeys, id: \.self) { key in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(key)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.mutedInk)
                                .lineLimit(1)
                            Text(store.merchantAliases[key] ?? "")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(1)
                        }

                        Spacer()

                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedInk)

                            Button {
                                store.refreshTransactionsForMerchantAlias(original: key)
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(AppTheme.accent)
                            .accessibilityLabel(Text(String(format: String(localized: "merchant_alias.refresh_accessibility_format"), key)))
                        }
                    }
                }
                .onDelete { indices in
                    let keys = sortedKeys
                    store.deleteMerchantAliases(for: indices.map { keys[$0] })
                }

                Button {
                    showAddAlert = true
                } label: {
                    Label("merchant_alias.add_mapping", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            } header: {
                Text("merchant_alias.title")
            } footer: {
                Text("merchant_alias.footer")
            }
        }
        .navigationTitle("merchant_alias.title")
        .alert("merchant_alias.alert.title", isPresented: $showAddAlert) {
            TextField("merchant_alias.original.placeholder", text: $newOriginal)
            TextField("merchant_alias.alias.placeholder", text: $newAlias)
            Button("common.cancel", role: .cancel) {
                newOriginal = ""
                newAlias = ""
            }
            Button("common.add") {
                let original = newOriginal.trimmingCharacters(in: .whitespacesAndNewlines)
                let alias = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
                store.setMerchantAlias(original: original, alias: alias)
                newOriginal = ""
                newAlias = ""
            }
        }
    }
}

#Preview {
    NavigationStack {
        MerchantAliasView()
            .environmentObject(LedgerStore())
    }
}
