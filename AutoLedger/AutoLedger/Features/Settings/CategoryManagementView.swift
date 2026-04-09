import AutoLedgerCore
import SwiftUI

struct CategoryManagementView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showAddAlert = false
    @State private var newCategoryName = ""

    var body: some View {
        List {
            Section("内置分类") {
                ForEach(TransactionCategory.allCases) { category in
                    HStack(spacing: 12) {
                        Image(systemName: category.iconName)
                            .foregroundStyle(category.tint)
                            .frame(width: 28)

                        Text(category.title)
                            .foregroundStyle(AppTheme.ink)

                        Spacer()

                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }
            }

            Section {
                ForEach(store.customCategories, id: \.self) { category in
                    HStack(spacing: 12) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(AppTheme.accentSecondary)
                            .frame(width: 28)

                        Text(category)
                            .foregroundStyle(AppTheme.ink)
                    }
                }
                .onDelete { indices in
                    store.customCategories.remove(atOffsets: indices)
                    store.saveCustomCategories()
                }

                Button {
                    showAddAlert = true
                } label: {
                    Label("添加分类", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            } header: {
                Text("自定义分类")
            } footer: {
                Text("自定义分类可在手动记账时使用，内置分类由系统自动推断。")
            }
        }
        .navigationTitle("分类管理")
        .alert("添加自定义分类", isPresented: $showAddAlert) {
            TextField("分类名称", text: $newCategoryName)
            Button("取消", role: .cancel) { newCategoryName = "" }
            Button("添加") {
                let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !store.customCategories.contains(trimmed) {
                    store.customCategories.append(trimmed)
                    store.saveCustomCategories()
                }
                newCategoryName = ""
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryManagementView()
            .environmentObject(LedgerStore())
    }
}
