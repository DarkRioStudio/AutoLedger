import SwiftUI

struct AIModelSettingsView: View {
    @State private var selectedProvider = LLMProvider.userSelected
    @State private var enhancementEnabled = LLMProvider.isEnhancementEnabled
    private var gemmaService: GemmaService { GemmaService.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                infoCard(
                    title: "ai_model.info.title",
                    body: enhancementEnabled
                        ? "ai_model.info.enabled.body"
                        : "ai_model.info.disabled.body"
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
                            Text("ai_model.delete_gemma")
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
        .navigationTitle("ai_model.title")
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
                        Text("ai_model.available")
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
                Label("ai_model.download_gemma", systemImage: "arrow.down.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

        case .checkingManifest:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("ai_model.checking_version")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.top, 4)

        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                    .tint(AppTheme.accent)
                Text(String(format: String(localized: "ai_model.downloading_format"), Int(progress * 100)))
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.top, 4)

        case .verifying:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("ai_model.verifying")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.top, 4)

        case .ready:
            HStack(spacing: 8) {
                Label("ai_model.ready", systemImage: "checkmark.seal.fill")
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
                Text(String(format: String(localized: "ai_model.update_available_format"), remote, local))
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button {
                    Task { await gemmaService.downloadModel() }
                } label: {
                    Label("ai_model.update_model", systemImage: "arrow.down.circle.fill")
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
                    Label("ai_model.retry", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Info Card

    private func infoCard(title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
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
