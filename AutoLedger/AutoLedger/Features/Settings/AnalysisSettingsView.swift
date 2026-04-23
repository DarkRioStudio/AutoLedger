import SwiftUI

struct AnalysisSettingsView: View {
    @AppStorage("monthlyAnomalyThresholdPercent") private var thresholdPercent = 150.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("异常消费阈值")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)

                            Text("本月分类支出高于近 3 个月月均值时提醒。")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.mutedInk)
                        }

                        Spacer()

                        Text("\(Int(thresholdPercent))%")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.accentSecondary)
                            .monospacedDigit()
                    }

                    Slider(value: $thresholdPercent, in: 100...300, step: 10)
                        .tint(AppTheme.accentSecondary)

                    HStack {
                        Text("敏感")
                        Spacer()
                        Text("稳健")
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.card)
                )

                Button {
                    thresholdPercent = 150
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("恢复默认阈值")
                    }
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("当前口径")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Text("仅当分类在过去 3 个完整月份中有历史支出，且本月金额达到阈值时展示提示。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.card)
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("消费分析")
    }
}

#Preview {
    NavigationStack {
        AnalysisSettingsView()
    }
}
