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

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }
                .onDelete { indices in
                    let keys = sortedKeys
                    store.deleteMerchantAliases(for: indices.map { keys[$0] })
                }

                Button {
                    showAddAlert = true
                } label: {
                    Label("添加映射", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            } header: {
                Text("商户别名")
            } footer: {
                Text("解析到的商户名与左侧完全匹配时，自动替换为右侧显示名，分类也会重新推断。")
            }
        }
        .navigationTitle("商户别名")
        .alert("添加商户别名", isPresented: $showAddAlert) {
            TextField("原始商户名", text: $newOriginal)
            TextField("显示别名", text: $newAlias)
            Button("取消", role: .cancel) {
                newOriginal = ""
                newAlias = ""
            }
            Button("添加") {
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
