import AutoLedgerCore
import SwiftUI

private enum HotelFolioEmailImportAllowanceStore {
    private static let storageKey = "hotelFolioEmailImportAllowanceState"

    static func current() -> LocalEmailFolioImportAllowanceState {
        let decoded: LocalEmailFolioImportAllowanceState?
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            decoded = try? JSONDecoder().decode(LocalEmailFolioImportAllowanceState.self, from: data)
        } else {
            decoded = nil
        }
        let state = decoded ?? .fresh()
        let normalized = state.normalized()
        if normalized != state {
            save(normalized)
        }
        return normalized
    }

    static func save(_ state: LocalEmailFolioImportAllowanceState) {
        guard let data = try? JSONEncoder().encode(state.normalized()) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

struct HotelFolioEmailImportView: View {
    private static let phoneSearchDays = 30
    private static let phoneMaxMessages = 100
    private static let macSearchDayOptions = [0, 30, 90, 180, 365]
    private static let macMaxMessageOptions = [0, 20, 50, 100]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore
    @ObservedObject private var proEntitlement = ProEntitlementManager.shared
    let targetLedgerID: String?
    let onDraftsReady: ([HotelStayDraft]) -> Void

    @State private var settings: HotelEmailAccountSettings
    @State private var portText: String
    @State private var searchDaysText: String
    @State private var maxMessagesText: String
    @State private var credentialInput = ""
    @State private var hasStoredCredential: Bool
    @State private var candidates: [HotelFolioEmailMessage] = []
    @State private var selectedAttachmentIDs: Set<String> = []
    @State private var statusMessage: String?
    @State private var isScanning = false
    @State private var isImportingSelection = false
    @State private var isPresentingProSheet = false
    @State private var importAllowanceState: LocalEmailFolioImportAllowanceState

    init(
        targetLedgerID: String?,
        onDraftsReady: @escaping ([HotelStayDraft]) -> Void
    ) {
        self.targetLedgerID = targetLedgerID
        self.onDraftsReady = onDraftsReady

        let current = HotelEmailAccountSettingsStore.current
        _settings = State(initialValue: current)
        _portText = State(initialValue: String(current.imapPort))
        _searchDaysText = State(initialValue: String(current.searchDays))
        _maxMessagesText = State(initialValue: String(current.maxMessages))
        _hasStoredCredential = State(initialValue: HotelEmailCredentialStore.hasStoredCredential(for: current.emailAddress))
        _importAllowanceState = State(initialValue: HotelFolioEmailImportAllowanceStore.current())
    }

    var body: some View {
        NavigationStack {
            Form {
                introSection
                providerGuideSection
                accountSection
                entitlementSection
                scanSection
                resultSection
            }
            .autoLedgerFormChrome()
            .autoLedgerSolidNavigationBarChrome()
            .navigationTitle("hotel_stay.email.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("hotel_stay.email.title")
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
        .onChange(of: settings.provider) { _, provider in
            applyProviderDefaults(provider)
        }
        .onChange(of: settings.emailAddress) { _, _ in
            refreshStoredCredentialState()
        }
        .task {
            await proEntitlement.loadProducts()
            await proEntitlement.refreshEntitlements()
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

    private var hasUnlimitedLocalEmailImport: Bool {
        proEntitlement.canUse(.localEmailFolioScan)
    }

    private var normalizedImportAllowance: LocalEmailFolioImportAllowanceState {
        importAllowanceState.normalized()
    }

    private var remainingFreeLocalEmailImports: Int {
        normalizedImportAllowance.remainingFreeImports
    }

    private var canImportSelectedEmailFolio: Bool {
        normalizedImportAllowance.allowsImport(isProActive: hasUnlimitedLocalEmailImport)
    }

    private var emailImportEntitlementTitle: String {
        if hasUnlimitedLocalEmailImport {
            return String(localized: "hotel_stay.email.pro.active")
        }
        if remainingFreeLocalEmailImports > 0 {
            return String(localized: "hotel_stay.email.pro.free_available")
        }
        return String(localized: "hotel_stay.email.pro.free_used")
    }

    private var emailImportEntitlementDescription: String {
        if hasUnlimitedLocalEmailImport {
            return String(localized: "hotel_stay.email.pro.active_description")
        }
        if remainingFreeLocalEmailImports > 0 {
            return String(
                format: String(localized: "hotel_stay.email.pro.free_available_description_format"),
                remainingFreeLocalEmailImports
            )
        }
        return String(localized: "hotel_stay.email.pro.free_used_description")
    }

    private var introSection: some View {
        Section {
            emailInfoRow(
                icon: "envelope.badge",
                tint: AppTheme.accent,
                titleKey: "hotel_stay.email.intro.value.title",
                bodyKey: "hotel_stay.email.intro.value.body"
            )
            emailInfoRow(
                icon: "lock.shield.fill",
                tint: .blue,
                titleKey: "hotel_stay.email.intro.privacy.title",
                bodyKey: "hotel_stay.email.intro.privacy.body"
            )
            emailInfoRow(
                icon: "checkmark.seal.fill",
                tint: .orange,
                titleKey: "hotel_stay.email.intro.review.title",
                bodyKey: "hotel_stay.email.intro.review.body"
            )
        } header: {
            Text("hotel_stay.email.section.intro")
        }
    }

    private var providerGuideSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 6) {
                    Text("hotel_stay.email.guide.title")
                        .font(.body.weight(.semibold))
                    Text(LocalizedStringKey(settings.provider.authorizationGuideKey))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("hotel_stay.email.guide.password_note")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "key.horizontal.fill")
                    .foregroundStyle(AppTheme.accent)
            }
        } header: {
            Text("hotel_stay.email.section.guide")
        }
    }

    private func emailInfoRow(
        icon: String,
        tint: Color,
        titleKey: LocalizedStringKey,
        bodyKey: LocalizedStringKey
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleKey)
                    .font(.body.weight(.semibold))
                Text(bodyKey)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(tint)
        }
    }

    private var accountSection: some View {
        Section {
            Picker("hotel_stay.email.provider", selection: $settings.provider) {
                ForEach(HotelEmailAccountSettings.Provider.allCases) { provider in
                    Text(LocalizedStringKey(provider.localizedTitleKey)).tag(provider)
                }
            }
            TextField("hotel_stay.email.address", text: $settings.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #if os(iOS)
                .keyboardType(.emailAddress)
                #endif

            TextField("hotel_stay.email.host", text: $settings.imapHost)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("hotel_stay.email.port", text: $portText)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif

            Toggle("hotel_stay.email.tls", isOn: $settings.useTLS)

            if shouldShowScanScopeFields {
                macScanScopeFields
            }

            HStack {
                SecureField("hotel_stay.email.auth_code", text: $credentialInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if hasStoredCredential {
                    Image(systemName: "key.fill")
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityLabel(Text("hotel_stay.email.credential_saved"))
                }
            }

            credentialActionButtons
        } header: {
            Text("hotel_stay.email.section.account")
        } footer: {
            Text("hotel_stay.email.account_footer")
        }
    }

    private var shouldShowScanScopeFields: Bool {
        #if os(macOS) || targetEnvironment(macCatalyst)
        true
        #else
        false
        #endif
    }

    private var macScanScopeFields: some View {
        Group {
            Picker("hotel_stay.email.search_days", selection: scanDaysSelection) {
                ForEach(Self.macSearchDayOptions, id: \.self) { days in
                    scanScopeOptionLabel(value: days).tag(days)
                }
            }
            .pickerStyle(.menu)

            Picker("hotel_stay.email.max_messages", selection: maxMessagesSelection) {
                ForEach(Self.macMaxMessageOptions, id: \.self) { count in
                    scanScopeOptionLabel(value: count).tag(count)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var scanDaysSelection: Binding<Int> {
        Binding(
            get: { Int(searchDaysText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 },
            set: { searchDaysText = String($0) }
        )
    }

    private var maxMessagesSelection: Binding<Int> {
        Binding(
            get: { Int(maxMessagesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 },
            set: { maxMessagesText = String($0) }
        )
    }

    private func scanScopeOptionLabel(value: Int) -> Text {
        value == 0 ? Text("ledger.filter.all") : Text(verbatim: "\(value)")
    }

    private var credentialActionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                saveCredentialButton
                clearCredentialButton
            }

            VStack(spacing: 10) {
                saveCredentialButton
                clearCredentialButton
            }
        }
    }

    private var saveCredentialButton: some View {
        Button {
            saveSettingsAndCredential()
        } label: {
            emailActionButtonLabel("hotel_stay.email.save", systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(.borderedProminent)
    }

    private var clearCredentialButton: some View {
        Button(role: .destructive) {
            HotelEmailCredentialStore.deleteCredential(for: settings.emailAddress)
            credentialInput = ""
            refreshStoredCredentialState()
            statusMessage = String(localized: "hotel_stay.email.status.credential_cleared")
        } label: {
            emailActionButtonLabel("hotel_stay.email.clear_credential", systemImage: "trash")
        }
        .buttonStyle(.bordered)
        .disabled(!hasStoredCredential)
    }

    private func emailActionButtonLabel(_ titleKey: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .accessibilityHidden(true)
            Text(titleKey)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)
        }
        .font(.body.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 34)
        .contentShape(Rectangle())
    }

    private var entitlementSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(emailImportEntitlementTitle)
                        .font(.body.weight(.semibold))
                    Text(emailImportEntitlementDescription)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.mutedInk)
                }
            } icon: {
                Image(systemName: hasUnlimitedLocalEmailImport ? "checkmark.seal.fill" : (remainingFreeLocalEmailImports > 0 ? "1.circle.fill" : "sparkles"))
                    .foregroundStyle(hasUnlimitedLocalEmailImport || remainingFreeLocalEmailImports > 0 ? AppTheme.accent : .orange)
            }

            if !hasUnlimitedLocalEmailImport {
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

    private var scanSection: some View {
        Section {
            Button {
                Task {
                    await scanMailbox()
                }
            } label: {
                HStack {
                    if isScanning {
                        ProgressView()
                    } else {
                        Image(systemName: "envelope.badge")
                    }
                    Text(isScanning ? "hotel_stay.email.scanning" : "hotel_stay.email.scan")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScanning || isImportingSelection)

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
                    .textSelection(.enabled)
            }
        } header: {
            Text("hotel_stay.email.section.scan")
        }
    }

    private var resultSection: some View {
        Section {
            if candidates.isEmpty {
                Text("hotel_stay.email.no_results")
                    .foregroundStyle(AppTheme.mutedInk)
            } else {
                selectionToolbar
                ForEach(candidates) { message in
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.subject.isEmpty ? String(localized: "hotel_stay.email.untitled") : message.subject)
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(2)
                            Text(message.from)
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedInk)
                                .lineLimit(2)
                            if let dateText = message.dateText {
                                Text(dateText)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.mutedInk)
                            }
                            if let match = candidateMatch(for: message) {
                                Label(candidateReasonTitle(for: match.reason), systemImage: candidateReasonIcon(for: match.reason))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }

                        ForEach(message.attachments) { attachment in
                            let isSelected = selectedAttachmentIDs.contains(attachment.id)
                            Button {
                                toggleAttachmentSelection(attachment.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(AppTheme.accent)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(attachment.fileName)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.size), countStyle: .file))
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.mutedInk)
                                    }
                                    Spacer(minLength: 8)
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isSelected ? AppTheme.accent.opacity(0.12) : AppTheme.canvas.opacity(0.45))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isSelected ? AppTheme.accent.opacity(0.28) : AppTheme.cardStroke, lineWidth: 1)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isImportingSelection)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Button {
                    if canImportSelectedEmailFolio {
                        Task {
                            await importSelectedAttachments()
                        }
                    } else {
                        statusMessage = String(localized: "hotel_stay.email.status.free_quota_used")
                        isPresentingProSheet = true
                    }
                } label: {
                    HStack {
                        if isImportingSelection {
                            ProgressView()
                                .controlSize(.small)
                        } else if canImportSelectedEmailFolio {
                            Image(systemName: "tray.and.arrow.down")
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isImportingSelection ? "hotel_stay.email.importing_selected" : (canImportSelectedEmailFolio ? "hotel_stay.email.import_selected" : "pro.cta.view_plans"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAttachmentIDs.isEmpty || isImportingSelection || isScanning)
            }
        } header: {
            Text("hotel_stay.email.section.results")
        } footer: {
            if !candidates.isEmpty {
                Text(String(format: String(localized: "hotel_stay.email.selected_count_format"), selectedAttachmentIDs.count))
            }
        }
    }

    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            Button("hotel_stay.email.select_all") {
                selectedAttachmentIDs = Set(allAttachmentIDs)
            }
            .disabled(selectedAttachmentIDs.count == allAttachmentIDs.count)

            Button("hotel_stay.email.clear_selection") {
                selectedAttachmentIDs.removeAll()
            }
            .disabled(selectedAttachmentIDs.isEmpty)
        }
        .font(.footnote.weight(.semibold))
        .buttonStyle(.borderless)
    }

    private var allAttachmentIDs: [String] {
        candidates.flatMap { $0.attachments.map(\.id) }
    }

    private var defaultSelectedAttachmentIDs: [String] {
        candidates.flatMap { message -> [String] in
            guard candidateMatch(for: message)?.defaultSelected == true else { return [] }
            return message.attachments.map(\.id)
        }
    }

    private var selectedAttachmentPairs: [(message: HotelFolioEmailMessage, attachment: HotelFolioEmailAttachment)] {
        candidates.flatMap { message in
            message.attachments.compactMap { attachment in
                selectedAttachmentIDs.contains(attachment.id) ? (message, attachment) : nil
            }
        }
    }

    private func toggleAttachmentSelection(_ attachmentID: String) {
        if selectedAttachmentIDs.contains(attachmentID) {
            selectedAttachmentIDs.remove(attachmentID)
        } else {
            selectedAttachmentIDs.insert(attachmentID)
        }
    }

    private func applyProviderDefaults(_ provider: HotelEmailAccountSettings.Provider) {
        guard provider != .custom else { return }
        let preset = HotelEmailAccountSettings.preset(provider: provider, emailAddress: settings.emailAddress)
        settings.imapHost = preset.imapHost
        settings.imapPort = preset.imapPort
        settings.useTLS = preset.useTLS
        portText = String(preset.imapPort)
    }

    private func saveSettingsAndCredential() {
        do {
            let normalized = try makeSettings()
            HotelEmailAccountSettingsStore.save(normalized)
            settings = normalized
            portText = String(normalized.imapPort)
            searchDaysText = String(normalized.searchDays)
            maxMessagesText = String(normalized.maxMessages)
            if !credentialInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try HotelEmailCredentialStore.saveCredential(credentialInput, for: normalized.emailAddress)
                credentialInput = ""
            }
            refreshStoredCredentialState()
            statusMessage = String(localized: "hotel_stay.email.status.saved")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func scanMailbox() async {
        guard !isScanning, !isImportingSelection else { return }
        isScanning = true
        statusMessage = String(localized: "hotel_stay.email.status.scanning")
        recordEmailScanDebug("邮箱水单扫描：用户手动触发扫描")
        defer {
            isScanning = false
            refreshStoredCredentialState()
        }

        do {
            let normalized = try makeSettings()
            HotelEmailAccountSettingsStore.save(normalized)
            settings = normalized
            if !credentialInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try HotelEmailCredentialStore.saveCredential(credentialInput, for: normalized.emailAddress)
                credentialInput = ""
            }
            guard let credential = try HotelEmailCredentialStore.readCredential(for: normalized.emailAddress),
                  !credential.isEmpty else {
                throw HotelFolioEmailImportError.missingCredential
            }

            candidates = try await HotelFolioIMAPClient().scan(
                settings: normalized,
                credential: credential,
                onProgress: { progress in
                    handleScanProgress(progress)
                }
            )
            selectedAttachmentIDs = Set(defaultSelectedAttachmentIDs)
            statusMessage = candidates.isEmpty
                ? String(localized: "hotel_stay.email.status.no_results")
                : String(format: String(localized: "hotel_stay.email.status.results_format"), candidates.count)
            recordEmailScanDebug("邮箱水单扫描：结果已显示 · candidates=\(candidates.count) · attachments=\(allAttachmentIDs.count) · selected=\(selectedAttachmentIDs.count)")
        } catch {
            statusMessage = error.localizedDescription
            recordEmailScanDebug("邮箱水单扫描失败：\(error.localizedDescription)")
        }
    }

    private func importSelectedAttachments() async {
        guard !isImportingSelection, !isScanning else { return }
        let selection = selectedAttachmentPairs
        guard !selection.isEmpty else {
            statusMessage = String(localized: "hotel_stay.email.status.no_selection")
            return
        }
        guard canImportSelectedEmailFolio else {
            statusMessage = String(localized: "hotel_stay.email.status.free_quota_used")
            isPresentingProSheet = true
            return
        }
        isImportingSelection = true
        statusMessage = String(localized: "hotel_stay.email.importing_selected")
        recordEmailScanDebug("邮箱水单批量导入：开始 · selected=\(selection.count)")
        defer { isImportingSelection = false }

        var drafts: [HotelStayDraft] = []
        var failures: [String] = []
        let importer = HotelFolioEmailAttachmentImporter()
        for (message, attachment) in selection {
            statusMessage = String(format: String(localized: "hotel_stay.email.status.importing_attachment_format"), attachment.fileName)
            recordEmailScanDebug("邮箱水单批量导入：提取 PDF 文本 · file=\(attachment.fileName)", rawText: message.subject)
            do {
                let draft = try importer.makeDraft(
                    message: message,
                    attachment: attachment,
                    targetLedgerID: targetLedgerID
                )
                drafts.append(draft)
                recordEmailScanDebug("邮箱水单批量导入：已生成待确认草稿 · file=\(attachment.fileName) · chars=\(draft.rawText.count)", rawText: draft.rawText)
            } catch {
                failures.append("\(attachment.fileName): \(error.localizedDescription)")
                recordEmailScanDebug("邮箱水单批量导入失败：file=\(attachment.fileName) · error=\(error.localizedDescription)")
            }
        }

        if drafts.isEmpty {
            statusMessage = failures.first ?? String(localized: "hotel_stay.email.status.no_selection")
            return
        }

        let message: String
        if failures.isEmpty {
            message = String(format: String(localized: "hotel_stay.email.status.imported_selected_format"), drafts.count)
        } else {
            message = String(format: String(localized: "hotel_stay.email.status.import_partial_format"), drafts.count, failures.count)
        }
        statusMessage = message
        if !hasUnlimitedLocalEmailImport, !drafts.isEmpty {
            let updatedAllowance = normalizedImportAllowance.consumingSuccessfulImport(
                isProActive: false,
                importedDraftCount: drafts.count
            )
            importAllowanceState = updatedAllowance
            HotelFolioEmailImportAllowanceStore.save(updatedAllowance)
            recordEmailScanDebug("邮箱水单批量导入：已使用本月免费额度 · remaining=\(updatedAllowance.remainingFreeImports)")
        }
        recordEmailScanDebug("邮箱水单批量导入：完成 · drafts=\(drafts.count) · failures=\(failures.count)")
        onDraftsReady(drafts)
        dismiss()
    }

    private func handleScanProgress(_ progress: HotelFolioEmailScanProgress) {
        Task { @MainActor in
            statusMessage = localizedStatus(for: progress.phase)
            recordEmailScanDebug(progress.debugSummary, rawText: progress.rawText)
        }
    }

    private func localizedStatus(for phase: HotelFolioEmailScanPhase) -> String {
        switch phase {
        case .connecting:
            return String(localized: "hotel_stay.email.status.connecting")
        case .authenticating:
            return String(localized: "hotel_stay.email.status.authenticating")
        case .selectingMailbox:
            return String(localized: "hotel_stay.email.status.selecting_mailbox")
        case .searching:
            return String(localized: "hotel_stay.email.status.searching")
        case .foundMessages(let count):
            return String(format: String(localized: "hotel_stay.email.status.found_messages_format"), count)
        case .fetching(let index, let total):
            return String(format: String(localized: "hotel_stay.email.status.fetching_format"), index, total)
        case .candidateAccepted(let subject):
            return String(format: String(localized: "hotel_stay.email.status.candidate_found_format"), subject)
        case .messageSkipped:
            return String(localized: "hotel_stay.email.status.skipping")
        case .completed(let count):
            return String(format: String(localized: "hotel_stay.email.status.results_format"), count)
        }
    }

    private func recordEmailScanDebug(_ summary: String, rawText: String = "") {
        store.recordHotelFolioDebugRecord(
            HotelFolioDebugTraceBuilder.makeEmailScanRecord(
                summary: summary,
                rawText: rawText
            )
        )
    }

    private func importAttachment(_ attachment: HotelFolioEmailAttachment, from message: HotelFolioEmailMessage) async {
        guard canImportSelectedEmailFolio else {
            statusMessage = String(localized: "hotel_stay.email.status.free_quota_used")
            isPresentingProSheet = true
            return
        }
        do {
            let draft = try HotelFolioEmailAttachmentImporter().makeDraft(
                message: message,
                attachment: attachment,
                targetLedgerID: targetLedgerID
            )
            if !hasUnlimitedLocalEmailImport {
                let updatedAllowance = normalizedImportAllowance.consumingSuccessfulImport(
                    isProActive: false,
                    importedDraftCount: 1
                )
                importAllowanceState = updatedAllowance
                HotelFolioEmailImportAllowanceStore.save(updatedAllowance)
            }
            onDraftsReady([draft])
            dismiss()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func makeSettings() throws -> HotelEmailAccountSettings {
        guard let port = Int(portText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw HotelFolioEmailImportError.invalidSettings
        }
        let searchDays: Int
        let maxMessages: Int
        if shouldShowScanScopeFields {
            guard let parsedSearchDays = Int(searchDaysText.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let parsedMaxMessages = Int(maxMessagesText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw HotelFolioEmailImportError.invalidSettings
            }
            searchDays = parsedSearchDays
            maxMessages = parsedMaxMessages
        } else {
            searchDays = Self.phoneSearchDays
            maxMessages = Self.phoneMaxMessages
        }

        let scoped = effectiveScanScopeSettings(from: HotelEmailAccountSettings(
            emailAddress: settings.emailAddress,
            provider: settings.provider,
            imapHost: settings.imapHost,
            imapPort: port,
            useTLS: settings.useTLS,
            searchDays: searchDays,
            maxMessages: maxMessages
        ))
        let normalized = scoped.normalized
        guard !normalized.emailAddress.isEmpty, !normalized.imapHost.isEmpty else {
            throw HotelFolioEmailImportError.invalidSettings
        }
        return normalized
    }

    private func effectiveScanScopeSettings(from settings: HotelEmailAccountSettings) -> HotelEmailAccountSettings {
        guard !shouldShowScanScopeFields else { return settings }
        var copy = settings
        copy.searchDays = Self.phoneSearchDays
        copy.maxMessages = Self.phoneMaxMessages
        return copy
    }

    private func refreshStoredCredentialState() {
        hasStoredCredential = HotelEmailCredentialStore.hasStoredCredential(for: settings.emailAddress)
    }

    private func candidateMatch(for message: HotelFolioEmailMessage) -> HotelFolioEmailCandidateMatch? {
        HotelFolioEmailCandidateFilter().evaluate(message)
    }

    private func candidateReasonTitle(for reason: HotelFolioEmailCandidateReason) -> LocalizedStringKey {
        switch reason {
        case .pdfFolioSubjectOrAttachment:
            return "hotel_stay.email.candidate_reason.pdf_folio"
        case .pdfHotelSenderOrBody:
            return "hotel_stay.email.candidate_reason.pdf_hotel"
        case .bodySubjectFolio:
            return "hotel_stay.email.candidate_reason.body_subject"
        }
    }

    private func candidateReasonIcon(for reason: HotelFolioEmailCandidateReason) -> String {
        switch reason {
        case .pdfFolioSubjectOrAttachment:
            return "doc.text.magnifyingglass"
        case .pdfHotelSenderOrBody:
            return "building.2.crop.circle"
        case .bodySubjectFolio:
            return "text.page.badge.magnifyingglass"
        }
    }
}

private extension HotelEmailAccountSettings.Provider {
    var localizedTitleKey: String {
        "hotel_stay.email.provider.\(rawValue)"
    }

    var authorizationGuideKey: String {
        "hotel_stay.email.guide.\(rawValue)"
    }
}
