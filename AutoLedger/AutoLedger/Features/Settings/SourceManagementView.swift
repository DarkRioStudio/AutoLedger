import AutoLedgerCore
import SwiftUI

struct SourceManagementView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showAddAlert = false
    @State private var newSourceName = ""

    var body: some View {
        List {
            Section("内置来源") {
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
                    Label("添加来源", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            } header: {
                Text("自定义来源")
            } footer: {
                Text("自定义来源可在手动记账时使用，内置来源由系统自动识别。")
            }
        }
        .navigationTitle("来源管理")
        .alert("添加自定义来源", isPresented: $showAddAlert) {
            TextField("来源名称", text: $newSourceName)
            Button("取消", role: .cancel) { newSourceName = "" }
            Button("添加") {
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
