import SwiftUI

struct AIModelSettingsView: View {
    @State private var selectedProvider = LLMProvider.userSelected
    @State private var enhancementEnabled = LLMProvider.isEnhancementEnabled
    private var gemmaService: GemmaService { GemmaService.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                infoCard(
                    title: "端侧模型说明",
                    body: enhancementEnabled
                        ? "所有推理均在设备本地完成，不上传任何数据。切换模型后立即生效。"
                        : "模型识别增强已关闭，当前仅使用纯规则解析。打开右上角开关可启用 AI 模型增强识别。"
                )

                ForEach(LLMProvider.allCases) { provider in
                    modelCard(provider)
                }
                .disabled(!enhancementEnabled)
                .opacity(enhancementEnabled ? 1 : 0.5)

                if enhancementEnabled, case .ready = gemmaService.state {
                    Button(role: .destructive) {
                        gemmaService.deleteModel()
                        if selectedProvider == .gemma {
                            selectedProvider = .appleFoundation
                            LLMProvider.userSelected = .appleFoundation
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除 Gemma-2 2B 模型")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.red.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("AI 模型")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("", isOn: $enhancementEnabled)
                    .labelsHidden()
                    .tint(AppTheme.accent)
                    .onChange(of: enhancementEnabled) { _, newValue in
                        LLMProvider.isEnhancementEnabled = newValue
                        if !newValue {
                            // 禁用时删除已下载的模型文件
                            if gemmaService.isModelDownloaded {
                                gemmaService.deleteModel()
                            }
                        }
                    }
            }
        }
        .task {
            // 进入页面时异步加载模型（如已下载但未加载）
            guard enhancementEnabled else { return }
            await gemmaService.ensureLoaded()
        }
    }

    // MARK: - Model Card

    @MainActor
    private func modelCard(_ provider: LLMProvider) -> some View {
        let isSelected = selectedProvider == provider
        let available = provider.isAvailable
        let canSelect = available || provider == .appleFoundation

        return Button {
            guard canSelect else { return }
            selectedProvider = provider
            LLMProvider.userSelected = provider
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: provider.iconName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
                    .frame(width: 40, height: 40)
                    .background((isSelected ? AppTheme.accent : AppTheme.mutedInk).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(provider.displayName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    if available {
                        Text("可用")
                            .font(.caption2).bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.accent))
                    } else if let reason = provider.unavailableReason {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    Text(provider.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)

                    // Gemma 下载 / 进度区域
                    if provider == .gemma {
                        gemmaActionArea
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk.opacity(0.4))
                    .font(.title3)
                    .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(isSelected ? AppTheme.accent : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gemma 操作区

    @ViewBuilder
    private var gemmaActionArea: some View {
        switch gemmaService.state {
        case .notDownloaded:
            Button {
                Task { await gemmaService.downloadModel() }
            } label: {
                Label("下载模型（~2.5 GB）", systemImage: "arrow.down.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

        case .checkingManifest:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("正在检查版本…")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.top, 4)

        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                    .tint(AppTheme.accent)
                Text("下载中 \(Int(progress * 100))%…建议使用 Wi-Fi")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.top, 4)

        case .verifying:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("校验文件完整性…")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.top, 4)

        case .ready:
            HStack(spacing: 8) {
                Label("模型已就绪", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                if let sizeMB = gemmaService.modelSizeMB {
                    Text("(\(sizeMB) MB)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.mutedInk)
                }
                if let ver = gemmaService.installedVersion {
                    Text(ver)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }
            .padding(.top, 4)

        case .updateAvailable(let remote, let local):
            VStack(alignment: .leading, spacing: 6) {
                Text("新版本可用：\(remote)（当前 \(local)）")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button {
                    Task { await gemmaService.downloadModel() }
                } label: {
                    Label("更新模型", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

        case .error(let msg):
            VStack(alignment: .leading, spacing: 6) {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button {
                    Task { await gemmaService.downloadModel() }
                } label: {
                    Label("重试", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Info Card

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
    NavigationStack {
        AIModelSettingsView()
    }
}
