import AutoLedgerCore
import SwiftUI

struct ExternalReceiptAssistSettingsView: View {
    @State private var isEnabled = ExternalReceiptAssistSettings.isEnabled
    @State private var provider = ExternalReceiptAssistSettings.provider
    @State private var endpoint = ExternalReceiptAssistSettings.endpointURLString ?? ""
    @State private var modelName = ExternalReceiptAssistSettings.modelName
    @State private var apiKeyInput = ""
    @State private var hasStoredAPIKey = ExternalReceiptAssistSettings.hasStoredAPIKey
    @State private var statusMessage: LocalizedStringKey?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                infoCard(
                    title: "external_assist.info.title",
                    body: "external_assist.info.body"
                )

                Toggle(isOn: $isEnabled) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("external_assist.enable.title")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text("external_assist.enable.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }
                .tint(AppTheme.accent)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.card)
                )
                .onChange(of: isEnabled) { _, newValue in
                    ExternalReceiptAssistSettings.isEnabled = newValue
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("external_assist.provider.title")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Picker("external_assist.provider.title", selection: $provider) {
                        ForEach(ExternalReceiptAssistProvider.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: provider) { _, newValue in
                        ExternalReceiptAssistSettings.provider = newValue
                        endpoint = ExternalReceiptAssistSettings.endpointURLString ?? ""
                        modelName = ExternalReceiptAssistSettings.modelName
                        statusMessage = "external_assist.status.provider_saved"
                    }

                    Text("external_assist.model.title")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)

                    TextField("external_assist.model.placeholder", text: $modelName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.canvas.opacity(0.72))
                        )

                    Text("external_assist.endpoint.title")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)

                    TextField("external_assist.endpoint.placeholder", text: $endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.canvas.opacity(0.72))
                        )

                    Button {
                        saveProviderConfiguration()
                    } label: {
                        Label("external_assist.provider.save", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.card)
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("external_assist.api_key.title")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)

                        if hasStoredAPIKey {
                            Text("external_assist.api_key.saved")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AppTheme.accent))
                        }
                    }

                    SecureField("external_assist.api_key.placeholder", text: $apiKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.canvas.opacity(0.72))
                        )

                    HStack(spacing: 12) {
                        Button {
                            saveAPIKey()
                        } label: {
                            Label("external_assist.api_key.save", systemImage: "key.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button(role: .destructive) {
                            clearAPIKey()
                        } label: {
                            Label("external_assist.api_key.clear", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!hasStoredAPIKey)
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.card)
                )

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.mutedInk)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("external_assist.title")
    }

    private func saveProviderConfiguration() {
        ExternalReceiptAssistSettings.provider = provider
        ExternalReceiptAssistSettings.modelName = modelName
        ExternalReceiptAssistSettings.endpointURLString = endpoint
        endpoint = ExternalReceiptAssistSettings.endpointURLString ?? ""
        modelName = ExternalReceiptAssistSettings.modelName
        statusMessage = "external_assist.status.provider_saved"
    }

    private func saveAPIKey() {
        do {
            try ExternalReceiptAssistSettings.saveAPIKey(apiKeyInput)
            apiKeyInput = ""
            hasStoredAPIKey = ExternalReceiptAssistSettings.hasStoredAPIKey
            statusMessage = "external_assist.status.key_saved"
        } catch {
            statusMessage = "external_assist.status.key_failed"
        }
    }

    private func clearAPIKey() {
        ExternalReceiptAssistSettings.clearStoredAPIKey()
        apiKeyInput = ""
        hasStoredAPIKey = ExternalReceiptAssistSettings.hasStoredAPIKey
        statusMessage = "external_assist.status.key_cleared"
    }

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
        ExternalReceiptAssistSettingsView()
    }
}
