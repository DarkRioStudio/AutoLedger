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
                cloudKitSyncCard
                manualBackupCard

                if let statusMessage {
                    statusCard(statusMessage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("settings.data_management.title")
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
                statusMessage = String(format: String(localized: "data_management.file_selection_failed_format"), error.localizedDescription)
            }
        }
        .confirmationDialog(
            "data_management.restore.confirm_title",
            isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("data_management.restore.confirm_action", role: .destructive) {
                importPendingBackup()
            }
            Button("common.cancel", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("data_management.restore.confirm_message")
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("data_management.current_data")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metric("data_management.metric.transactions", "\(store.transactions.count)")
                metric("data_management.metric.deleted", "\(store.deletedTransactions.count)")
                metric("data_management.metric.subscriptions", "\(store.subscriptions.count)")
                metric("data_management.metric.aliases", "\(store.merchantAliases.count)")
            }

            if let lastBackupAt = store.lastBackupAt {
                Text(String(format: String(localized: "data_management.last_backup_format"), AppFormatters.exportDateTime(lastBackupAt)))
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
            Label("data_management.icloud_auto_backup", systemImage: "icloud.and.arrow.up.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text("data_management.icloud_description")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)

            if let bundle = store.detectedICloudBackup {
                Divider()
                Text(String(format: String(localized: "data_management.icloud_detected_format"), store.summaryText(for: bundle)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                actionButton(
                    titleKey: "data_management.restore_icloud",
                    systemImage: "icloud.and.arrow.down.fill",
                    style: .primary
                ) {
                    do {
                        try store.restoreDetectedICloudBackup()
                        statusMessage = String(localized: "data_management.restore_icloud_success")
                    } catch {
                        statusMessage = String(format: String(localized: "data_management.restore_icloud_failed_format"), error.localizedDescription)
                    }
                }
            }

            actionButton(
                titleKey: "data_management.backup_now",
                systemImage: "arrow.triangle.2.circlepath",
                style: .secondary
            ) {
                do {
                    try store.backupToICloudNow()
                    statusMessage = store.lastBackupSummary ?? String(localized: "data_management.backup_icloud_success")
                } catch {
                    statusMessage = String(format: String(localized: "data_management.backup_icloud_failed_format"), error.localizedDescription)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.card))
    }

    private var cloudKitSyncCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("data_management.cloudkit_sync", systemImage: "icloud.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Toggle(isOn: Binding(
                get: { store.isLedgerCloudSyncEnabled },
                set: { enabled in
                    Task {
                        await store.setLedgerCloudSyncEnabled(enabled)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("data_management.cloudkit_enable")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("data_management.cloudkit_enable_description")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }
            .tint(AppTheme.accent)
            .disabled(store.isLedgerCloudSyncRunning)

            if store.isLedgerCloudSyncRunning {
                ProgressView()
                    .tint(AppTheme.accent)
            }

            cloudKitUserStatusSection
            cloudKitConflictSection

            actionButton(
                titleKey: store.isLedgerCloudSyncRunning
                    ? LocalizedStringKey("data_management.cloudkit_syncing")
                    : LocalizedStringKey("data_management.cloudkit_force_refresh"),
                systemImage: "arrow.triangle.2.circlepath.icloud",
                style: .primary
            ) {
                Task {
                    await store.syncLedgerWithCloudKitNow(forceFull: true)
                }
            }
            .disabled(store.isLedgerCloudSyncRunning || !store.isLedgerCloudSyncEnabled)
            .opacity(store.isLedgerCloudSyncRunning || !store.isLedgerCloudSyncEnabled ? 0.65 : 1)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.card))
    }

    private var cloudKitUserStatusSection: some View {
        let status = store.ledgerUserSyncStatus
        let tint = cloudKitStatusTint(status.state)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: cloudKitStatusSystemImage(status.state))
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(cloudKitStatusTitle(status.state))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(cloudKitStatusDetail(status.state))
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)

                if let lastSuccessfulSyncAt = status.lastSuccessfulSyncAt {
                    Text(
                        String(
                            format: String(localized: "data_management.cloudkit_last_success_format"),
                            AppFormatters.shortDateTime(lastSuccessfulSyncAt)
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mutedInk)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.canvas.opacity(0.74)))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var cloudKitConflictSection: some View {
        let conflicts = store.ledgerSyncConflictRecords
        if !conflicts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("data_management.cloudkit_conflict.title")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text("data_management.cloudkit_conflict.detail")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                    Spacer(minLength: 12)
                    Text("\(conflicts.count)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.accent))
                }

                ForEach(Array(conflicts.prefix(4)), id: \.transaction.id) { record in
                    cloudKitConflictRow(record)
                }

                if conflicts.count > 4 {
                    Text(
                        String(
                            format: String(localized: "data_management.cloudkit_conflict.more_format"),
                            conflicts.count - 4
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Button {
                    _ = store.keepLocalVersionsForAllLedgerSyncConflicts()
                } label: {
                    Label("data_management.cloudkit_conflict.keep_all_local", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .tint(AppTheme.accent)
                .disabled(store.isLedgerCloudSyncRunning)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.canvas.opacity(0.74)))
        }
    }

    private func cloudKitConflictRow(_ record: TransactionSyncRecord) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.transaction.merchant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(AppFormatters.currency(record.transaction.amount))
                        .font(.caption.weight(.semibold))
                    Text(AppFormatters.shortDateTime(record.transaction.occurredAt))
                        .font(.caption)
                    Text(record.transaction.categoryTitle)
                        .font(.caption)
                }
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                _ = store.keepLocalVersionForLedgerSyncConflict(transactionID: record.transaction.id)
            } label: {
                Label("data_management.cloudkit_conflict.keep_local", systemImage: "checkmark")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            .tint(AppTheme.accent)
            .disabled(store.isLedgerCloudSyncRunning)
            .accessibilityLabel(Text("data_management.cloudkit_conflict.keep_local_accessibility"))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card.opacity(0.72)))
    }

    private func cloudKitStatusTitle(_ state: LedgerUserSyncState) -> LocalizedStringKey {
        LocalizedStringKey("data_management.cloudkit_state.\(state.rawValue).title")
    }

    private func cloudKitStatusDetail(_ state: LedgerUserSyncState) -> LocalizedStringKey {
        LocalizedStringKey("data_management.cloudkit_state.\(state.rawValue).detail")
    }

    private func cloudKitStatusSystemImage(_ state: LedgerUserSyncState) -> String {
        switch state {
        case .disabled: return "icloud.slash"
        case .checkingAccount: return "person.crop.circle.badge.questionmark"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .waitingToUpload: return "icloud.and.arrow.up"
        case .upToDate: return "checkmark.icloud.fill"
        case .offline: return "wifi.slash"
        case .needsConflictReview: return "exclamationmark.arrow.triangle.2.circlepath"
        case .failedWithLocalDataSafe: return "exclamationmark.icloud"
        }
    }

    private func cloudKitStatusTint(_ state: LedgerUserSyncState) -> Color {
        switch state {
        case .disabled: return AppTheme.mutedInk
        case .checkingAccount, .syncing, .waitingToUpload: return AppTheme.accent
        case .upToDate: return .green
        case .offline, .needsConflictReview: return .orange
        case .failedWithLocalDataSafe: return .red
        }
    }

    private var manualBackupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("data_management.json_backup", systemImage: "doc.zipper")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text("data_management.json_description")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)

            HStack(spacing: 12) {
                actionButton(
                    titleKey: "data_management.export_json",
                    systemImage: "square.and.arrow.up",
                    style: .primary
                ) {
                    do {
                        exportedURL = try store.writeManualBackupFile()
                        statusMessage = store.lastBackupSummary
                        showShareSheet = true
                    } catch {
                        statusMessage = String(format: String(localized: "data_management.export_failed_format"), error.localizedDescription)
                    }
                }
                .frame(maxWidth: .infinity)

                actionButton(
                    titleKey: "data_management.import_json",
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

    private func metric(_ titleKey: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text(titleKey)
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
        titleKey: LocalizedStringKey,
        systemImage: String,
        style: ActionButtonStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(titleKey)
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
            statusMessage = store.lastImportSummary ?? String(localized: "data_management.restore_json_success")
        } catch {
            statusMessage = String(format: String(localized: "data_management.restore_failed_format"), error.localizedDescription)
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
