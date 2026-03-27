import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NavigationLink {
                        DebugView()
                    } label: {
                        debugEntryCard
                    }
                    .buttonStyle(.plain)

                    infoCard(
                        title: "当前版本范围",
                        body: "v0.1.0 已接上真实截图导入、Vision OCR、SQLite 本地账本、账单修正、账本展示和月度汇总。当前主要剩发布级回归和规则精调。"
                    )

                    infoCard(
                        title: "隐私策略",
                        body: "所有演示数据都留在设备本地，本轮没有接入任何云端同步或第三方分析。"
                    )

                    infoCard(
                        title: "下一轮重点",
                        body: "补多支付样例人工回归、继续收紧 ReceiptParser 规则，并把版本门禁和发布收口文档更新到可决策状态。"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("设置")
        }
    }

    private var debugEntryCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "ladybug.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 40, height: 40)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("调试与回归")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text("集中查看最近 OCR 原文、解析结果、导入状态和最近账单，方便真机回归。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.mutedInk)
                .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func infoCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text(body)
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
}

#Preview {
    SettingsView()
        .environmentObject(LedgerStore())
}
