import SwiftUI

struct ReportView: View {
    @EnvironmentObject private var store: LedgerStore

    var body: some View {
        let snapshot = store.monthlySnapshot

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(snapshot.monthLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.76))

                        Text(AppFormatters.currency(snapshot.totalExpense))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("共 \(snapshot.transactionCount) 笔支出，当前消费最高商户是 \(snapshot.topMerchant)。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(AppTheme.heroGradient)
                    )

                    Text("分类拆分")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    if snapshot.categoryBreakdown.isEmpty {
                        Text("还没有可用于汇总的数据。")
                            .foregroundStyle(AppTheme.mutedInk)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(AppTheme.card)
                            )
                    } else {
                        ForEach(snapshot.categoryBreakdown) { metric in
                            CategoryBreakdownRow(metric: metric)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("月报")
        }
    }
}

#Preview {
    ReportView()
        .environmentObject(LedgerStore())
}
