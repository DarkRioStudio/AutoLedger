import AutoLedgerCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var versionTapCount = 0
    @State private var showDebugUnlocked = false
    @State private var showFeedbackComposer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if showDebugUnlocked {
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
                    }

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
                    NavigationLink {
                        SubscriptionListView()
                    } label: {
                        settingsRow(
                            icon: "repeat.circle.fill",
                            iconColor: Color(red: 0.80, green: 0.47, blue: 0.16),
                            title: "订阅管理",
                            subtitle: "查看已识别的周期性订阅，管理扣费提醒"
                        )
                    }
                    .buttonStyle(.plain)

                    toggleCard(
                        icon: "bell.badge.fill",
                        iconColor: Color(red: 0.80, green: 0.47, blue: 0.16),
                        title: "订阅扣费提醒",
                        subtitle: "开启后，在预测扣费前 1 天发送本地通知。",
                        key: "subscriptionReminder"
                    )

                    NavigationLink {
                        CategoryLearningView()
                    } label: {
                        settingsRow(
                            icon: "brain.head.profile",
                            iconColor: Color(red: 0.55, green: 0.36, blue: 0.69),
                            title: "分类学习",
                            subtitle: "查看已学习的商户→分类偏好，支持删除"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AIModelSettingsView()
                    } label: {
                        settingsRow(
                            icon: "cpu.fill",
                            iconColor: Color(red: 0.17, green: 0.47, blue: 0.34),
                            title: "AI 模型",
                            subtitle: "选择端侧大模型，管理 Gemma 模型下载"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AnalysisSettingsView()
                    } label: {
                        settingsRow(
                            icon: "chart.line.uptrend.xyaxis",
                            iconColor: Color(red: 0.20, green: 0.51, blue: 0.70),
                            title: "消费分析",
                            subtitle: "调整月报异常消费检测阈值"
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

                    Button {
                        showFeedbackComposer = true
                    } label: {
                        settingsRow(
                            icon: "envelope.fill",
                            iconColor: Color(red: 0.20, green: 0.56, blue: 0.82),
                            title: "问题反馈",
                            subtitle: "遇到问题？发送分级日志帮助我们快速定位"
                        )
                    }
                    .buttonStyle(.plain)

                    infoCard(
                        title: "当前版本",
                        body: "v1.2.0-dev — Gemma-2 2B 端侧 LLM 集成（CDN 分发 + SHA-256 校验）、LLM + 规则混合解析、模型异步加载与自动卸载、订阅识别、快捷指令一键记账、Share Extension 分享导入。"
                    )
                    .onTapGesture {
                        versionTapCount += 1
                        if versionTapCount >= 5 && !showDebugUnlocked {
                            showDebugUnlocked = true
                            versionTapCount = 0
                        }
                    }

                    infoCard(
                        title: "隐私策略",
                        body: "所有数据留在设备本地，不接入任何云端同步或第三方分析。OCR 与 LLM 推理均在本地完成。唯一网络请求：Gemma 模型版本检查与下载（CDN），不传输任何用户数据。"
                    )

                    infoCard(
                        title: "版本状态",
                        body: "端侧 LLM、月报分析、云闪付 / 银联基础适配、订阅管理增强、软删除持久化与回归门禁草稿已落地。接下来推进真机回归与发布判定。"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("设置")
            .sheet(isPresented: $showFeedbackComposer) {
                FeedbackComposerView()
                    .environmentObject(store)
            }
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
