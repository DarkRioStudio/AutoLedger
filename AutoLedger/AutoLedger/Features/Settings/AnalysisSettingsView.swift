import SwiftUI

struct AnalysisSettingsView: View {
    @AppStorage("monthlyAnomalyThresholdPercent") private var thresholdPercent = 150.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("analysis.threshold.title")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)

                            Text("analysis.threshold.subtitle")
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
                        Text("analysis.threshold.sensitive")
                        Spacer()
                        Text("analysis.threshold.stable")
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
                        Text("analysis.threshold.reset")
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
                    Text("analysis.method.title")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Text("analysis.method.body")
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
        .navigationTitle("settings.analysis.title")
    }
}

#Preview {
    NavigationStack {
        AnalysisSettingsView()
    }
}
