import AutoLedgerCore
import SwiftUI

struct CategoryLearningView: View {
    @EnvironmentObject private var store: LedgerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.categoryCorrections.isEmpty {
                    emptyState
                } else {
                    correctionsList
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("settings.category_learning.title")
    }

    private var correctionsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("category_learning.learned_title")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Text(String(format: String(localized: "category_learning.count_format"), store.categoryCorrections.count))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Text("category_learning.description")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)

            let sorted = store.categoryCorrections.sorted { $0.key < $1.key }
            ForEach(sorted, id: \.key) { merchant, category in
                correctionCard(merchant: merchant, category: category)
            }
        }
    }

    private func correctionCard(merchant: String, category: TransactionCategory) -> some View {
        HStack(spacing: 14) {
            Image(systemName: category.iconName)
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 40, height: 40)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(merchant)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text("→ \(category.title)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.card)
        )
        .contextMenu {
            Button(role: .destructive) {
                store.deleteCategoryCorrection(merchant: merchant)
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.mutedInk.opacity(0.5))

            Text("category_learning.empty.title")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text("category_learning.empty.description")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }
}

#Preview {
    NavigationStack {
        CategoryLearningView()
    }
    .environmentObject(LedgerStore())
}
