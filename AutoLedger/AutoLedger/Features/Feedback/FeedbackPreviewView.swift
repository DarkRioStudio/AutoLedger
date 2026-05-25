import SwiftUI

struct FeedbackPreviewView: View {
    let bundle: FeedbackComposerView.PreviewBundle
    let onConfirmSend: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    subjectCard
                    bodyCard
                    bundleCard
                    sendButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("feedback.preview.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("feedback.preview.back") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "eye")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
                Text("feedback.preview.header")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }

            Text("feedback.preview.description")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)

            HStack(spacing: 16) {
                previewTag("ID", bundle.feedbackID)
                previewTag(String(localized: "feedback.preview.recipient"), FeedbackService.supportEmail)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.card))
    }

    private var subjectCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("feedback.preview.email_subject")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text(bundle.subject)
                .font(.subheadline.monospaced())
                .foregroundStyle(AppTheme.ink.opacity(0.85))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.card))
    }

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("feedback.preview.email_body")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text(bundle.body)
                .font(.caption.monospaced())
                .foregroundStyle(AppTheme.ink.opacity(0.8))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.card))
    }

    private var bundleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("feedback.preview.bundle")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            HStack(spacing: 10) {
                Image(systemName: "doc.zipper")
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bundle.zipURL.lastPathComponent)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ink)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(bundle.zipData.count), countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }

            if let contents = bundleContents {
                Text("feedback.preview.included_files")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                ForEach(contents, id: \.self) { file in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.mutedInk)
                        Text(file)
                            .font(.caption.monospaced())
                            .foregroundStyle(AppTheme.ink.opacity(0.8))
                    }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.card))
    }

    private var sendButton: some View {
        Button {
            onConfirmSend()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: FeedbackService.shared.canSendMail ? "envelope.fill" : "doc.on.clipboard.fill")
                Text(FeedbackService.shared.canSendMail ? String(localized: "feedback.preview.send_email") : String(localized: "feedback.preview.copy_clipboard"))
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.accent)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func previewTag(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(.caption)
                .foregroundStyle(AppTheme.ink)
        }
    }

    private var bundleContents: [String]? {
        guard let enumerator = FileManager.default.enumerator(
            at: bundle.bundleDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var files: [String] = []
        while let url = enumerator.nextObject() as? URL {
            if !url.hasDirectoryPath {
                files.append(url.lastPathComponent)
            }
        }
        return files.sorted()
    }
}
