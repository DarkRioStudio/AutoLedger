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
    @State private var reproducible = "是"
    @State private var extraNote = ""
    @State private var includeScreenshot = false

    @State private var showPreview = false
    @State private var showL3Confirmation = false
    @State private var previewBundle: PreviewBundle?

    struct PreviewBundle {
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
            .navigationTitle("问题反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .sheet(isPresented: $showPreview) {
                if let bundle = previewBundle {
                    FeedbackPreviewView(bundle: bundle) {
                        sendFeedback(bundle: bundle)
                    }
                    .environmentObject(store)
                }
            }
            .alert("发送结果", isPresented: Binding(
                get: { feedbackService.sendResult != nil },
                set: { if !$0 { feedbackService.sendResult = nil } }
            )) {
                Button("好的") {
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
            Text("问题类型")
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
            Text("反馈级别")
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
        .alert("确认使用 L3 完整诊断？", isPresented: $showL3Confirmation) {
            Button("确认", role: .destructive) { level = .L3 }
            Button("取消", role: .cancel) {}
        } message: {
            Text("L3 级别可能包含完整的 OCR 识别文本和原始截图，请确认你了解并同意。")
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("问题描述")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            feedbackField("描述你遇到的问题…", text: $userDescription, minHeight: 80)
            feedbackField("预期结果（可选）", text: $expectedResult)
            feedbackField("实际结果（可选）", text: $actualResult)

            HStack(spacing: 12) {
                Text("是否可复现")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Picker("", selection: $reproducible) {
                    Text("是").tag("是")
                    Text("否").tag("否")
                    Text("不确定").tag("不确定")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            feedbackField("补充说明（可选）", text: $extraNote)

            if level == .L3 {
                Toggle(isOn: $includeScreenshot) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("附带最近截图")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink)
                        Text("将最近导入的截图附加到诊断包中")
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
            Text("L3 完整诊断包可能包含更多个人账单信息，仅建议在你明确知情并同意的情况下使用。")
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
            Text("预览并发送")
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
                actualResult: actualResult, reproducible: reproducible, extraNote: extraNote
            )
            previewBundle = PreviewBundle(
                feedbackID: feedbackID, subject: subject, body: body,
                bundleDir: bundleDir, zipURL: zipURL, zipData: zipData
            )
            showPreview = true
        } catch {
            feedbackService.sendResult = .failed("无法构建反馈包：\(error.localizedDescription)")
        }
    }

    private func sendFeedback(bundle: PreviewBundle) {
        showPreview = false
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
