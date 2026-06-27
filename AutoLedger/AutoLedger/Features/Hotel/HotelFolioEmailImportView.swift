import AutoLedgerCore
import SwiftUI

struct HotelFolioEmailImportView: View {
    @Environment(\.dismiss) private var dismiss
    let targetLedgerID: String?
    let onDraftReady: (HotelStayDraft) -> Void

    @State private var settings = HotelEmailAccountSettingsStore.current
    @State private var portText = String(HotelEmailAccountSettingsStore.current.imapPort)
    @State private var searchDaysText = String(HotelEmailAccountSettingsStore.current.searchDays)
    @State private var maxMessagesText = String(HotelEmailAccountSettingsStore.current.maxMessages)
    @State private var credentialInput = ""
    @State private var hasStoredCredential = HotelEmailCredentialStore.hasStoredCredential(
        for: HotelEmailAccountSettingsStore.current.emailAddress
    )
    @State private var candidates: [HotelFolioEmailMessage] = []
    @State private var statusMessage: String?
    @State private var isScanning = false
    @State private var importingAttachmentID: String?

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                demoSection
                scanSection
                resultSection
            }
            .autoLedgerFormChrome()
            .navigationTitle("hotel_stay.email.title")
            .toolbar {
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
    }

    private var accountSection: some View {
        Section {
            Picker("hotel_stay.email.provider", selection: $settings.provider) {
                Text("hotel_stay.email.provider.qq").tag(HotelEmailAccountSettings.Provider.qq)
                Text("hotel_stay.email.provider.custom").tag(HotelEmailAccountSettings.Provider.custom)
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

            TextField("hotel_stay.email.search_days", text: $searchDaysText)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif

            TextField("hotel_stay.email.max_messages", text: $maxMessagesText)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif

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
            .disabled(isScanning)

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

    @ViewBuilder
    private var demoSection: some View {
        if HotelFolioEmailDemoMode.isAvailable {
            Section {
                Button {
                    loadDemoMode()
                } label: {
                    Label("hotel_stay.email.demo_load", systemImage: "play.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isScanning || importingAttachmentID != nil)
            } header: {
                Text("hotel_stay.email.section.demo")
            } footer: {
                Text("hotel_stay.email.demo_footer")
            }
        }
    }

    private var resultSection: some View {
        Section {
            if candidates.isEmpty {
                Text("hotel_stay.email.no_results")
                    .foregroundStyle(AppTheme.mutedInk)
            } else {
                ForEach(candidates) { message in
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.subject.isEmpty ? String(localized: "hotel_stay.email.untitled") : message.subject)
                                .font(.headline)
                            Text(message.from)
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedInk)
                                .lineLimit(2)
                            if let dateText = message.dateText {
                                Text(dateText)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.mutedInk)
                            }
                        }

                        ForEach(message.attachments) { attachment in
                            Button {
                                Task {
                                    await importAttachment(attachment, from: message)
                                }
                            } label: {
                                HStack {
                                    if importingAttachmentID == attachment.id {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "paperclip")
                                    }
                                    Text(attachment.fileName)
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.size), countStyle: .file))
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.mutedInk)
                                }
                            }
                            .disabled(importingAttachmentID != nil)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        } header: {
            Text("hotel_stay.email.section.results")
        }
    }

    private func applyProviderDefaults(_ provider: HotelEmailAccountSettings.Provider) {
        guard provider == .qq else { return }
        let qq = HotelEmailAccountSettings.qq(emailAddress: settings.emailAddress)
        settings.imapHost = qq.imapHost
        settings.imapPort = qq.imapPort
        settings.useTLS = qq.useTLS
        portText = String(qq.imapPort)
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
        guard !isScanning else { return }
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

            isScanning = true
            statusMessage = String(localized: "hotel_stay.email.status.scanning")
            defer {
                isScanning = false
                refreshStoredCredentialState()
            }

            candidates = try await HotelFolioIMAPClient().scan(settings: normalized, credential: credential)
            statusMessage = candidates.isEmpty
                ? String(localized: "hotel_stay.email.status.no_results")
                : String(format: String(localized: "hotel_stay.email.status.results_format"), candidates.count)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func loadDemoMode() {
        candidates = [HotelFolioEmailDemoMode.makeMessage()]
        statusMessage = String(localized: "hotel_stay.email.status.demo_loaded")
    }

    private func importAttachment(_ attachment: HotelFolioEmailAttachment, from message: HotelFolioEmailMessage) async {
        guard importingAttachmentID == nil else { return }
        importingAttachmentID = attachment.id
        defer { importingAttachmentID = nil }

        do {
            let draft: HotelStayDraft
            if HotelFolioEmailDemoMode.isDemoMessage(message) {
                draft = try HotelFolioEmailDemoMode.makeDraft(
                    message: message,
                    attachment: attachment,
                    targetLedgerID: targetLedgerID
                )
            } else {
                draft = try HotelFolioEmailAttachmentImporter().makeDraft(
                    message: message,
                    attachment: attachment,
                    targetLedgerID: targetLedgerID
                )
            }
            onDraftReady(draft)
            dismiss()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func makeSettings() throws -> HotelEmailAccountSettings {
        guard let port = Int(portText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let searchDays = Int(searchDaysText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let maxMessages = Int(maxMessagesText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw HotelFolioEmailImportError.invalidSettings
        }
        let normalized = HotelEmailAccountSettings(
            emailAddress: settings.emailAddress,
            provider: settings.provider,
            imapHost: settings.imapHost,
            imapPort: port,
            useTLS: settings.useTLS,
            searchDays: searchDays,
            maxMessages: maxMessages
        ).normalized
        guard !normalized.emailAddress.isEmpty, !normalized.imapHost.isEmpty else {
            throw HotelFolioEmailImportError.invalidSettings
        }
        return normalized
    }

    private func refreshStoredCredentialState() {
        hasStoredCredential = HotelEmailCredentialStore.hasStoredCredential(for: settings.emailAddress)
    }
}
