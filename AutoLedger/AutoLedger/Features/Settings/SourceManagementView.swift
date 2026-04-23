import AutoLedgerCore
import SwiftUI

struct SourceManagementView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showAddAlert = false
    @State private var newSourceName = ""

    var body: some View {
        List {
            Section("source_management.built_in") {
                ForEach(ReceiptSource.allCases) { source in
                    HStack(spacing: 12) {
                        Image(systemName: "creditcard.fill")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 28)

                        Text(source.title)
                            .foregroundStyle(AppTheme.ink)

                        Spacer()

                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }
            }

            Section {
                ForEach(store.customSources, id: \.self) { source in
                    HStack(spacing: 12) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(AppTheme.accentSecondary)
                            .frame(width: 28)

                        Text(source)
                            .foregroundStyle(AppTheme.ink)
                    }
                }
                .onDelete { indices in
                    store.customSources.remove(atOffsets: indices)
                    store.saveCustomSources()
                }

                Button {
                    showAddAlert = true
                } label: {
                    Label("source_management.add", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            } header: {
                Text("source_management.custom")
            } footer: {
                Text("source_management.footer")
            }
        }
        .navigationTitle("source_management.title")
        .alert("source_management.alert.title", isPresented: $showAddAlert) {
            TextField("source_management.alert.placeholder", text: $newSourceName)
            Button("common.cancel", role: .cancel) { newSourceName = "" }
            Button("common.add") {
                let trimmed = newSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !store.customSources.contains(trimmed) {
                    store.customSources.append(trimmed)
                    store.saveCustomSources()
                }
                newSourceName = ""
            }
        }
    }
}

#Preview {
    NavigationStack {
        SourceManagementView()
            .environmentObject(LedgerStore())
    }
}
