import AutoLedgerCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NavigationLink {
                        DebugView()
                    } label: {
                        settingsRow(
                            icon: "ladybug.fill",
                            iconColor: AppTheme.accent,
                            title: "调试与回归",
                            subtitle: "查看 OCR 原文、解析结果、导入状态和最近账单"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SourceManagementView()
                    } label: {
                        settingsRow(
                            icon: "arrow.triangle.branch",
                            iconColor: Color(red: 0.07, green: 0.47, blue: 0.87),
                            title: "来源管理",
                            subtitle: "管理支付来源，查看或新增自定义来源"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        CategoryManagementView()
                    } label: {
                        settingsRow(
                            icon: "square.grid.2x2.fill",
                            iconColor: AppTheme.accentSecondary,
                            title: "分类管理",
                            subtitle: "管理支出分类，查看或新增自定义分类"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        MerchantAliasView()
                    } label: {
                        settingsRow(
                            icon: "person.text.rectangle.fill",
                            iconColor: Color(red: 0.33, green: 0.59, blue: 0.41),
                            title: "商户别名",
                            subtitle: "将解析到的商户全称映射为熟悉的短名称，如「广州骑安科技有限公司 → 青桔单车」"
                        )
                    }
                    .buttonStyle(.plain)

                    toggleCard(
                        icon: "doc.on.clipboard",
                        iconColor: .orange,
                        title: "回到前台自动读取剪切板",
                        subtitle: "开启后，每次回到 App 时自动检测剪切板中的支付截图并导入记账。",
                        key: "autoClipboardImport"
                    )

                    infoCard(
                        title: "当前版本",
                        body: "v0.1.1 — 快捷指令一键记账、Share Extension 分享导入、LLM + 规则混合解析、相机拍照 / 剪切板导入、调试记录全链路追溯。"
                    )

                    infoCard(
                        title: "隐私策略",
                        body: "所有数据留在设备本地，不接入任何云端同步或第三方分析。OCR 与解析均在本地完成。"
                    )

                    infoCard(
                        title: "版本状态",
                        body: "功能收口中，接下来以问题修复和日常使用测试回归为主。"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("设置")
        }
    }

    private func settingsRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text(subtitle)
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

    private func toggleCard(icon: String, iconColor: Color, title: String, subtitle: String, key: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: key) },
                set: { UserDefaults.standard.set($0, forKey: key) }
            ))
            .labelsHidden()
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
