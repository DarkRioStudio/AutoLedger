import AutoLedgerCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HotelFolioInboxImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared

    let targetLedgerID: String?
    let targetCandidateID: UUID?
    let onDraftsReady: ([HotelStayDraft]) -> Void

    @State private var endpoint: String
    @State private var token: String
    @State private var candidates: [CloudHotelFolioCandidate] = []
    @State private var selectedCandidateIDs: Set<UUID> = []
    @State private var statusMessage: String?
    @State private var isClaimingAddress = false
    @State private var isRefreshing = false
    @State private var isImporting = false
    @State private var isPresentingProSheet = false
    @State private var cloudInboxAccess: ProAccessResolution = .requiresServerVerification

    private let client = HotelFolioInboxClient()

    init(
        targetLedgerID: String?,
        targetCandidateID: UUID? = nil,
        onDraftsReady: @escaping ([HotelStayDraft]) -> Void
    ) {
        self.targetLedgerID = targetLedgerID
        self.targetCandidateID = targetCandidateID
        self.onDraftsReady = onDraftsReady
        let settings = HotelFolioInboxSettings()
        _endpoint = State(initialValue: settings.endpoint)
        _token = State(initialValue: settings.token)
    }

    private var settings: HotelFolioInboxSettings {
        HotelFolioInboxSettings(endpoint: endpoint, token: token)
    }

    private var canUseCloudInbox: Bool {
        cloudInboxAccess.allowsAccess
    }

    private var canClaimCloudInboxAddress: Bool {
        cloudInboxAccess.allowsAccess
    }

    private var cloudInboxEntitlementTitleKey: LocalizedStringKey {
        switch cloudInboxAccess {
        case .allowed, .freeFeature:
            return "hotel_stay.cloud_inbox.pro.active"
        case .requiresPurchase:
            return "hotel_stay.cloud_inbox.pro.required"
        case .plannedButUnavailable, .requiresServerVerification, .serverVerificationFailed:
            return "hotel_stay.cloud_inbox.pro.server_verification_required"
        }
    }

    private var cloudInboxEntitlementDescriptionKey: LocalizedStringKey {
        switch cloudInboxAccess {
        case .allowed, .freeFeature:
            return "hotel_stay.cloud_inbox.pro.description"
        case .requiresPurchase:
            return "hotel_stay.cloud_inbox.pro.trial_description"
        case .plannedButUnavailable, .requiresServerVerification, .serverVerificationFailed:
            return "hotel_stay.cloud_inbox.pro.server_verification_description"
        }
    }

    private var selectedCandidates: [CloudHotelFolioCandidate] {
        candidates.filter { selectedCandidateIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                entitlementSection
                addressSection
                candidateSection
            }
            .autoLedgerFormChrome()
            .autoLedgerSolidNavigationBarChrome()
            .navigationTitle("hotel_stay.cloud_inbox.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("hotel_stay.cloud_inbox.title")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await proEntitlement.loadProducts()
            await proEntitlement.refreshEntitlements()
            await refreshCloudInboxAccess()
            await registerRemoteDeviceTokenIfAvailable()
            if settings.canRequest {
                await refreshCandidates()
            }
        }
        .sheet(isPresented: $isPresentingProSheet) {
            NavigationStack {
                AutoLedgerProView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.close") {
                                isPresentingProSheet = false
                            }
                        }
                    }
            }
        }
    }

    private var entitlementSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cloudInboxEntitlementTitleKey)
                            .font(.body.weight(.semibold))
                        Text(cloudInboxEntitlementDescriptionKey)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                } icon: {
                    Image(systemName: canUseCloudInbox ? "checkmark.seal.fill" : "sparkles")
                        .foregroundStyle(canUseCloudInbox ? AppTheme.accent : .orange)
                }

                if !canUseCloudInbox {
                    Button {
                        isPresentingProSheet = true
                    } label: {
                        Label("pro.cta.view_plans", systemImage: "sparkles")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addressSection: some View {
        Section {
            if settings.normalizedToken.isEmpty {
                Label {
                    Text("hotel_stay.cloud_inbox.address_not_claimed")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                } icon: {
                    Image(systemName: "envelope.badge")
                        .foregroundStyle(AppTheme.accent)
                }
            } else {
                LabeledContent("hotel_stay.cloud_inbox.address") {
                    Text(settings.inboxAddress)
                        .textSelection(.enabled)
                        .font(.callout.monospaced())
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                cloudInboxActionButton(
                    titleKey: isClaimingAddress ? "hotel_stay.cloud_inbox.claiming_address" : "hotel_stay.cloud_inbox.claim_address",
                    systemImage: "envelope.badge",
                    isPrimary: true,
                    isLoading: isClaimingAddress,
                    isDisabled: !canClaimCloudInboxAddress || isClaimingAddress || isRefreshing || isImporting
                ) {
                    Task {
                        await claimInboxAddress()
                    }
                }

                cloudInboxActionButton(
                    titleKey: "hotel_stay.cloud_inbox.copy_address",
                    systemImage: "doc.on.doc",
                    isPrimary: false,
                    isDisabled: settings.normalizedToken.isEmpty
                ) {
                    copyInboxAddress()
                }
            }
        } header: {
            Text("hotel_stay.cloud_inbox.section.address")
        } footer: {
            Text("hotel_stay.cloud_inbox.address_footer")
        }
    }

    private func cloudInboxActionButton(
        titleKey: LocalizedStringKey,
        systemImage: String,
        isPrimary: Bool,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(isPrimary ? .white : AppTheme.accent)
                } else {
                    Image(systemName: systemImage)
                }

                Text(titleKey)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isPrimary ? Color.white : AppTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isPrimary ? AppTheme.accent : AppTheme.accent.opacity(0.12))
            )
            .opacity(isDisabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var candidateSection: some View {
        Section {
            Button {
                Task {
                    await refreshCandidates()
                }
            } label: {
                HStack {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "icloud.and.arrow.down")
                    }
                    Text(isRefreshing ? "hotel_stay.cloud_inbox.refreshing" : "hotel_stay.cloud_inbox.refresh")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!settings.canRequest || isRefreshing || isImporting)

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
                    .textSelection(.enabled)
            }

            if candidates.isEmpty {
                if statusMessage == nil {
                    Text("hotel_stay.cloud_inbox.no_results")
                        .foregroundStyle(AppTheme.mutedInk)
                }
            } else {
                selectionToolbar

                ForEach(candidates) { candidate in
                    Button {
                        toggleCandidate(candidate.id)
                    } label: {
                        CloudHotelFolioCandidateRow(
                            candidate: candidate,
                            isSelected: selectedCandidateIDs.contains(candidate.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)
                }

                Button {
                    Task {
                        await importSelectedCandidates()
                    }
                } label: {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: canUseCloudInbox ? "tray.and.arrow.down" : "lock.open.display")
                        }
                        Text(isImporting ? "hotel_stay.cloud_inbox.importing" : "hotel_stay.cloud_inbox.import_selected")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCandidateIDs.isEmpty || isImporting || isRefreshing)
            }
        } header: {
            Text("hotel_stay.cloud_inbox.section.candidates")
        } footer: {
            if !candidates.isEmpty {
                Text(String(format: String(localized: "hotel_stay.cloud_inbox.selected_count_format"), selectedCandidateIDs.count))
            }
        }
    }

    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            Button("hotel_stay.email.select_all") {
                selectedCandidateIDs = Set(candidates.map(\.id))
            }
            .disabled(selectedCandidateIDs.count == candidates.count)

            Button("hotel_stay.email.clear_selection") {
                selectedCandidateIDs.removeAll()
            }
            .disabled(selectedCandidateIDs.isEmpty)
        }
        .font(.footnote.weight(.semibold))
        .buttonStyle(.borderless)
    }

    @MainActor
    private func claimInboxAddress() async {
        guard !isClaimingAddress, !isRefreshing, !isImporting else { return }
        await refreshCloudInboxAccess()
        guard canClaimCloudInboxAddress else {
            statusMessage = String(localized: "hotel_stay.cloud_inbox.status.server_verification_required")
            return
        }

        isClaimingAddress = true
        statusMessage = String(localized: "hotel_stay.cloud_inbox.claiming_address")
        recordCloudInboxDebug("云端酒店水单收件箱：开始领取专属地址")
        defer { isClaimingAddress = false }

        do {
            let claim = try await client.claimInboxToken(settings: settings)
            let normalizedToken = HotelCloudFolioInboxAddress(token: claim.token).normalizedToken
            guard !normalizedToken.isEmpty else {
                throw HotelFolioInboxClientError.invalidTokenClaimResponse
            }
            let updatedSettings = HotelFolioInboxSettings(endpoint: endpoint, token: normalizedToken)
            try updatedSettings.save()
            token = normalizedToken
            statusMessage = String(localized: "hotel_stay.cloud_inbox.status.address_claimed")
            recordCloudInboxDebug("云端酒店水单收件箱：专属地址已领取 · tokenHash=\(claim.tokenHash)")
            NotificationService.shared.requestPermissionIfNeeded()
            #if canImport(UIKit)
            UIApplication.shared.registerForRemoteNotifications()
            #endif
            await registerRemoteDeviceTokenIfAvailable()
        } catch {
            statusMessage = error.localizedDescription
            recordCloudInboxDebug("云端酒店水单收件箱领取地址失败：\(error.localizedDescription)")
        }
    }

    @MainActor
    private func refreshCloudInboxAccess() async {
        cloudInboxAccess = await proEntitlement.resolveAccess(.cloudFolioInbox)
    }

    private func copyInboxAddress() {
        #if canImport(UIKit)
        UIPasteboard.general.string = settings.inboxAddress
        statusMessage = String(localized: "hotel_stay.cloud_inbox.status.address_copied")
        #endif
    }

    private func toggleCandidate(_ id: UUID) {
        if selectedCandidateIDs.contains(id) {
            selectedCandidateIDs.remove(id)
        } else {
            selectedCandidateIDs.insert(id)
        }
    }

    @MainActor
    private func refreshCandidates() async {
        guard !isRefreshing, !isImporting else { return }

        isRefreshing = true
        statusMessage = String(localized: "hotel_stay.cloud_inbox.refreshing")
        recordCloudInboxDebug("云端酒店水单收件箱：开始拉取候选")
        defer { isRefreshing = false }

        do {
            try settings.save()
            token = settings.normalizedToken
            let fetched = try await client.listCandidates(settings: settings)
            candidates = fetched
            if let targetCandidateID, fetched.contains(where: { $0.id == targetCandidateID }) {
                selectedCandidateIDs = [targetCandidateID]
            } else {
                selectedCandidateIDs = Set(fetched.map(\.id))
            }
            statusMessage = fetched.isEmpty
                ? String(localized: "hotel_stay.cloud_inbox.status.no_results")
                : String(format: String(localized: "hotel_stay.cloud_inbox.status.results_format"), fetched.count)
            recordCloudInboxDebug("云端酒店水单收件箱：候选已显示 · candidates=\(fetched.count)")
        } catch {
            statusMessage = error.localizedDescription
            recordCloudInboxDebug("云端酒店水单收件箱拉取失败：\(error.localizedDescription)")
        }
    }

    @MainActor
    private func importSelectedCandidates() async {
        guard !isImporting, !isRefreshing else { return }
        let selection = selectedCandidates
        guard !selection.isEmpty else {
            statusMessage = String(localized: "hotel_stay.email.status.no_selection")
            return
        }
        guard canUseCloudInbox else {
            statusMessage = String(localized: "hotel_stay.cloud_inbox.status.pro_required")
            isPresentingProSheet = true
            return
        }

        isImporting = true
        statusMessage = String(localized: "hotel_stay.cloud_inbox.importing")
        recordCloudInboxDebug("云端酒店水单收件箱：开始导入 · selected=\(selection.count)")
        defer { isImporting = false }

        var drafts: [HotelStayDraft] = []
        var failures: [String] = []
        let importer = HotelFolioCloudCandidatePDFImporter()

        for candidate in selection {
            do {
                statusMessage = String(format: String(localized: "hotel_stay.cloud_inbox.status.downloading_format"), candidate.attachmentFileName)
                let pdfData = try await client.downloadPDF(candidate: candidate, settings: settings)
                let draft = try importer.makeDraft(
                    candidate: candidate,
                    pdfData: pdfData,
                    targetLedgerID: targetLedgerID
                )
                _ = try? await client.updateStatus(
                    candidate: candidate,
                    status: .converted,
                    deleteCloudPDF: true,
                    settings: settings
                )
                drafts.append(draft)
                recordCloudInboxDebug(
                    "云端酒店水单收件箱：已生成本地草稿 · file=\(candidate.attachmentFileName) · chars=\(draft.rawText.count)",
                    rawText: draft.rawText
                )
            } catch {
                failures.append("\(candidate.attachmentFileName): \(error.localizedDescription)")
                _ = try? await client.updateStatus(
                    candidate: candidate,
                    status: .failed,
                    failureReason: error.localizedDescription,
                    settings: settings
                )
                recordCloudInboxDebug("云端酒店水单收件箱导入失败：file=\(candidate.attachmentFileName) · error=\(error.localizedDescription)")
            }
        }

        if drafts.isEmpty {
            statusMessage = failures.first ?? String(localized: "hotel_stay.cloud_inbox.status.no_results")
            return
        }

        statusMessage = failures.isEmpty
            ? String(format: String(localized: "hotel_stay.cloud_inbox.status.imported_format"), drafts.count)
            : String(format: String(localized: "hotel_stay.email.status.import_partial_format"), drafts.count, failures.count)
        recordCloudInboxDebug("云端酒店水单收件箱：完成 · drafts=\(drafts.count) · failures=\(failures.count)")
        onDraftsReady(drafts)
        dismiss()
    }

    private func recordCloudInboxDebug(_ summary: String, rawText: String = "") {
        store.recordHotelFolioDebugRecord(
            HotelFolioDebugTraceBuilder.makeEmailScanRecord(
                summary: summary,
                rawText: rawText
            )
        )
    }

    @MainActor
    private func registerRemoteDeviceTokenIfAvailable() async {
        guard canUseCloudInbox,
              settings.canRequest,
              let deviceToken = NotificationService.remoteDeviceToken else {
            return
        }
        do {
            try await client.registerDeviceToken(
                settings: settings,
                deviceToken: deviceToken
            )
            recordCloudInboxDebug("云端酒店水单收件箱：设备推送 token 已登记")
        } catch {
            recordCloudInboxDebug("云端酒店水单收件箱设备推送登记失败：\(error.localizedDescription)")
        }
    }
}

private struct CloudHotelFolioCandidateRow: View {
    let candidate: CloudHotelFolioCandidate
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundStyle(AppTheme.accent)
                .font(.body.weight(.semibold))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(candidate.sourceEmailSubject?.nilIfBlank ?? candidate.attachmentFileName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)

                if let sender = candidate.sourceEmailFrom?.nilIfBlank {
                    Text(sender)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(candidate.attachmentFileName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(candidate.objectByteSize), countStyle: .file))
                }
                .font(.caption2)
                .foregroundStyle(AppTheme.mutedInk)

                Text(AppFormatters.exportDateTime(candidate.receivedAt))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer(minLength: 8)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? AppTheme.accent.opacity(0.12) : AppTheme.canvas.opacity(0.45))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? AppTheme.accent.opacity(0.28) : AppTheme.cardStroke, lineWidth: 1)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
