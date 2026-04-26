import AutoLedgerCore
import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var exportedURL: URL?
    @State private var showShareSheet = false
    @State private var showFileImporter = false
    @State private var showRestoreConfirmation = false
    @State private var pendingImportURL: URL?
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                overviewCard
                iCloudCard
                manualBackupCard

                if let statusMessage {
                    statusCard(statusMessage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("数据管理")
        .sheet(isPresented: $showShareSheet) {
            if let exportedURL {
                ActivityShareSheet(activityItems: [exportedURL])
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                pendingImportURL = urls.first
                showRestoreConfirmation = pendingImportURL != nil
            case let .failure(error):
                statusMessage = "选择文件失败：\(error.localizedDescription)"
            }
        }
        .confirmationDialog(
            "覆盖恢复会替换当前本地数据",
            isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("覆盖恢复", role: .destructive) {
                importPendingBackup()
            }
            Button("取消", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("恢复前会生成一份内存安全备份；如果导入失败，将尝试恢复当前数据。")
        }
        .onAppear {
            store.detectICloudBackupForRestore()
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前数据")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metric("账单", "\(store.transactions.count)")
                metric("最近删除", "\(store.deletedTransactions.count)")
                metric("订阅", "\(store.subscriptions.count)")
                metric("商户别名", "\(store.merchantAliases.count)")
            }

            if let lastBackupAt = store.lastBackupAt {
                Text("上次备份：\(AppFormatters.exportDateTime(lastBackupAt))")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.card))
    }

    private var iCloudCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(
                get: { store.iCloudBackupEnabled },
                set: { store.iCloudBackupEnabled = $0 }
            )) {
                Label("iCloud 自动备份", systemImage: "icloud.and.arrow.up.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
            }

            Text("开启后会把最新备份写入 iCloud Drive 的 AutoLedgerBackup.json。它是恢复文件，不会作为主数据库实时同步。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)

            if let bundle = store.detectedICloudBackup {
                Divider()
                Text("检测到 iCloud 备份：\(store.summaryText(for: bundle))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                actionButton(
                    title: "恢复 iCloud 备份",
                    systemImage: "icloud.and.arrow.down.fill",
                    style: .primary
                ) {
                    do {
                        try store.restoreDetectedICloudBackup()
                        statusMessage = "已从 iCloud 备份恢复。"
                    } catch {
                        statusMessage = "iCloud 恢复失败：\(error.localizedDescription)"
                    }
                }
            }

            actionButton(
                title: "立即备份",
                systemImage: "arrow.triangle.2.circlepath",
                style: .secondary
            ) {
                do {
                    try store.backupToICloudNow()
                    statusMessage = store.lastBackupSummary ?? "已备份到 iCloud。"
                } catch {
                    statusMessage = "iCloud 备份失败：\(error.localizedDescription)"
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.card))
    }

    private var manualBackupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("JSON 备份", systemImage: "doc.zipper")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text("手动导出的 JSON 可保存到 Files、iCloud Drive 或 AirDrop。导入时会覆盖当前本地账本和用户配置。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)

            HStack(spacing: 12) {
                actionButton(
                    title: "导出 JSON",
                    systemImage: "square.and.arrow.up",
                    style: .primary
                ) {
                    do {
                        exportedURL = try store.writeManualBackupFile()
                        statusMessage = store.lastBackupSummary
                        showShareSheet = true
                    } catch {
                        statusMessage = "导出失败：\(error.localizedDescription)"
                    }
                }
                .frame(maxWidth: .infinity)

                actionButton(
                    title: "导入 JSON",
                    systemImage: "square.and.arrow.down",
                    style: .secondary
                ) {
                    showFileImporter = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.card))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text(title)
                .font(.footnote)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.canvas.opacity(0.7)))
    }

    private func statusCard(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(AppTheme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.card))
    }

    private enum ActionButtonStyle {
        case primary
        case secondary
    }

    private func actionButton(
        title: String,
        systemImage: String,
        style: ActionButtonStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            } icon: {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
            }
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .padding(.horizontal, 14)
            .foregroundStyle(style == .primary ? Color.white : AppTheme.accent)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(style == .primary ? AppTheme.accent : AppTheme.accent.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
    }

    private func importPendingBackup() {
        guard let pendingImportURL else { return }
        do {
            try store.importBackup(from: pendingImportURL)
            statusMessage = store.lastImportSummary ?? "已从 JSON 备份恢复。"
        } catch {
            statusMessage = "恢复失败：\(error.localizedDescription)"
        }
        self.pendingImportURL = nil
    }
}

#Preview {
    NavigationStack {
        DataManagementView()
            .environmentObject(LedgerStore())
    }
}
