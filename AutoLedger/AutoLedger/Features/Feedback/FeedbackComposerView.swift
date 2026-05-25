import AutoLedgerCore
import SwiftUI

struct FeedbackComposerView: View {
    @EnvironmentObject private var store: LedgerStore
    @StateObject private var feedbackService = FeedbackService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var issueType: FeedbackIssueType = .feedback
    @State private var level: FeedbackLevel = .L1
    @State private var userDescription = ""
    @State private var expectedResult = ""
    @State private var actualResult = ""
    @State private var reproducible = "yes"
    @State private var extraNote = ""
    @State private var includeScreenshot = false

    @State private var showL3Confirmation = false
    @State private var previewBundle: PreviewBundle?

    struct PreviewBundle: Identifiable {
        let id = UUID()
        let feedbackID: String
        let subject: String
        let body: String
        let bundleDir: URL
        let zipURL: URL
        let zipData: Data
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    issueTypeSection
                    levelSection
                    descriptionSection
                    if level == .L3 {
                        l3WarningCard
                    }
                    previewButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("settings.feedback.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .sheet(item: $previewBundle) { bundle in
                FeedbackPreviewView(bundle: bundle) {
                    sendFeedback(bundle: bundle)
                }
                .environmentObject(store)
            }
            .alert("feedback.result.title", isPresented: Binding(
                get: { feedbackService.sendResult != nil },
                set: { if !$0 { feedbackService.sendResult = nil } }
            )) {
                Button("feedback.result.ok") {
                    if case .sent = feedbackService.sendResult { dismiss() }
                    feedbackService.sendResult = nil
                }
            } message: {
                Text(feedbackService.sendResult?.message ?? "")
            }
        }
    }

    // MARK: - Sections

    private var issueTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("feedback.issue_type")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(FeedbackIssueType.allCases) { type in
                    Button {
                        issueType = type
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.caption)
                            Text(type.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(issueType == type ? AppTheme.accent.opacity(0.15) : AppTheme.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(issueType == type ? AppTheme.accent : .clear, lineWidth: 1.5)
                        )
                        .foregroundStyle(issueType == type ? AppTheme.accent : AppTheme.ink)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.card))
    }

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("feedback.level")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            ForEach(FeedbackLevel.allCases) { lv in
                Button {
                    if lv == .L3 {
                        showL3Confirmation = true
                    } else {
                        level = lv
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: lv == .L1 ? "shield" : lv == .L2 ? "shield.lefthalf.filled" : "shield.fill")
                            .foregroundStyle(lv == level ? AppTheme.accent : AppTheme.mutedInk)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(lv.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(lv.subtitle)
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedInk)
                        }

                        Spacer()

                        if lv == level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(lv == level ? AppTheme.accent.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(lv == level ? AppTheme.accent : AppTheme.mutedInk.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.card))
        .alert("feedback.l3.confirm_title", isPresented: $showL3Confirmation) {
            Button("feedback.l3.confirm", role: .destructive) { level = .L3 }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("feedback.l3.confirm_message")
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("feedback.description")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            feedbackField(String(localized: "feedback.field.problem_placeholder"), text: $userDescription, minHeight: 80)
            feedbackField(String(localized: "feedback.field.expected_placeholder"), text: $expectedResult)
            feedbackField(String(localized: "feedback.field.actual_placeholder"), text: $actualResult)

            HStack(spacing: 12) {
                Text("feedback.reproducible")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Picker("", selection: $reproducible) {
                    Text("feedback.reproducible.yes").tag("yes")
                    Text("feedback.reproducible.no").tag("no")
                    Text("feedback.reproducible.unsure").tag("unsure")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            feedbackField(String(localized: "feedback.field.extra_placeholder"), text: $extraNote)

            if level == .L3 {
                Toggle(isOn: $includeScreenshot) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("feedback.include_screenshot")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink)
                        Text("feedback.include_screenshot.subtitle")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.card))
    }

    private var l3WarningCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("feedback.l3.warning")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }

    private var previewButton: some View {
        Button {
            buildPreview()
        } label: {
            Text("feedback.preview_and_send")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(userDescription.isEmpty ? AppTheme.mutedInk : AppTheme.accent)
                )
        }
        .disabled(userDescription.isEmpty)
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func feedbackField(_ placeholder: String, text: Binding<String>, minHeight: CGFloat = 44) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(.subheadline)
            .padding(12)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.04))
            )
    }

    private func buildPreview() {
        let feedbackID = FeedbackBundleBuilder.generateFeedbackID()
        do {
            let bundleDir = try FeedbackBundleBuilder.buildBundle(
                feedbackID: feedbackID,
                level: level,
                issueType: issueType,
                userDescription: userDescription,
                expectedResult: expectedResult,
                actualResult: actualResult,
                reproducible: reproducible,
                entryPoint: "settings_feedback",
                debugRecords: store.debugRecords,
                transactions: store.transactions,
                lastOCRText: store.lastRecognizedText,
                lastReceipt: store.lastParsedReceipt,
                includeRawImage: includeScreenshot
            )
            let zipURL = try FeedbackBundleBuilder.zipBundle(at: bundleDir, feedbackID: feedbackID, level: level)
            let zipData = try Data(contentsOf: zipURL)
            let subject = FeedbackBundleBuilder.emailSubject(level: level, issueType: issueType, summary: userDescription.prefix(40).description)
            let body = FeedbackBundleBuilder.emailBody(
                level: level, issueType: issueType, feedbackID: feedbackID,
                userDescription: userDescription, expectedResult: expectedResult,
                actualResult: actualResult, reproducible: reproducibleDisplay, extraNote: extraNote
            )
            previewBundle = PreviewBundle(
                feedbackID: feedbackID, subject: subject, body: body,
                bundleDir: bundleDir, zipURL: zipURL, zipData: zipData
            )
        } catch {
            feedbackService.sendResult = .failed(String(format: String(localized: "feedback.build_failed_format"), error.localizedDescription))
        }
    }

    private var reproducibleDisplay: String {
        switch reproducible {
        case "yes": return String(localized: "feedback.reproducible.yes")
        case "no": return String(localized: "feedback.reproducible.no")
        default: return String(localized: "feedback.reproducible.unsure")
        }
    }

    private func sendFeedback(bundle: PreviewBundle) {
        previewBundle = nil
        let service = FeedbackService.shared
        if service.canSendMail {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else { return }
            var presenter = root
            while let presented = presenter.presentedViewController { presenter = presented }
            service.sendViaEmail(
                subject: bundle.subject,
                body: bundle.body,
                zipData: bundle.zipData,
                zipFileName: bundle.zipURL.lastPathComponent,
                from: presenter
            )
        } else {
            service.copyToClipboard(subject: bundle.subject, body: bundle.body)
        }
    }
}

#Preview {
    FeedbackComposerView()
        .environmentObject(LedgerStore())
}
