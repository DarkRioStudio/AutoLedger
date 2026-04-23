import AutoLedgerCore
import SwiftUI

struct CategoryManagementView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showAddAlert = false
    @State private var newCategoryName = ""

    var body: some View {
        List {
            Section("category_management.built_in") {
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
                    Label("category_management.add", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            } header: {
                Text("category_management.custom")
            } footer: {
                Text("category_management.footer")
            }
        }
        .navigationTitle("category_management.title")
        .alert("category_management.alert.title", isPresented: $showAddAlert) {
            TextField("category_management.alert.placeholder", text: $newCategoryName)
            Button("common.cancel", role: .cancel) { newCategoryName = "" }
            Button("common.add") {
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
