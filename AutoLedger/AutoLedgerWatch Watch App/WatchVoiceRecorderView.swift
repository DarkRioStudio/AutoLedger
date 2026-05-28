import AutoLedgerCore
import SwiftUI
import WatchKit

/// Watch 侧语音记账录入视图。
/// 点击语音输入按钮触发系统听写，提交后调用 VoiceLedgerParser 解析，
/// 将草稿写入 ViewModel 并进入确认页。
struct WatchVoiceRecorderView: View {

    @Environment(WatchLedgerViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""
    @State private var isRequestingInput = false
    @State private var isParsing = false
    @State private var parseError: String? = nil
    @State private var navigateToConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 9) {

                    // MARK: 图标提示
                    if !isParsing {
                        Image(systemName: "mic.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)

                        Text("watch.voice.input_hint")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // MARK: 语音输入按钮（触发系统听写）
                    Button {
                        presentVoiceInput()
                    } label: {
                        if isRequestingInput {
                            ProgressView()
                        } else if inputText.isEmpty {
                            Label("watch.voice.dictate_button", systemImage: "mic.fill")
                        } else {
                            Label("watch.voice.dictate_again", systemImage: "mic.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequestingInput || isParsing)
                    .accessibilityLabel(Text("watch.voice.dictate_accessibility"))

                    // MARK: 识别文本（可修改后重新解析）
                    TextField(String(localized: "watch.voice.placeholder"), text: $inputText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.body)
                        .frame(minHeight: 44)
                        .accessibilityLabel(Text("watch.voice.content"))
                        .accessibilityHint(Text("watch.voice.content_hint"))
                    // MARK: 错误提示
                    if let err = parseError {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // MARK: 解析按钮
                    Button {
                        parseDictatedText()
                    } label: {
                        if isParsing {
                            ProgressView()
                        } else {
                            Label("voice_ledger_parse", systemImage: "arrow.right")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isParsing)
                    .accessibilityLabel(Text("watch.voice.parse_accessibility"))

                    // MARK: 跳转确认页（解析成功后）
                    NavigationLink(
                        destination: WatchVoiceConfirmView()
                            .environment(viewModel),
                        isActive: $navigateToConfirm
                    ) { EmptyView() }
                        .hidden()

                    Button("common.cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Private

    private func presentVoiceInput() {
        parseError = nil
        isRequestingInput = true

        guard let controller = WKExtension.shared().visibleInterfaceController ?? WKExtension.shared().rootInterfaceController else {
            isRequestingInput = false
            parseError = String(localized: "watch.voice.input_unavailable")
            return
        }

        controller.presentTextInputController(
            withSuggestions: voiceInputSuggestions,
            allowedInputMode: .plain
        ) { results in
            Task { @MainActor in
                isRequestingInput = false

                guard let recognizedText = Self.firstRecognizedText(from: results) else {
                    return
                }

                inputText = recognizedText
                parseDictatedText()
            }
        }
    }

    private func parseDictatedText() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isParsing = true
        parseError = nil

        let result = VoiceLedgerParser().parse(text)
        isParsing = false

        guard result.isSaveable, let amount = result.amount else {
            parseError = String(localized: "watch.voice.amount_missing")
            return
        }

        let draft = WatchLedgerDraft(
            merchant: result.merchant.isEmpty ? result.category.title : result.merchant,
            amount: amount,
            category: result.category,
            note: text,
            occurredAt: result.occurredAt
        )
        viewModel.voiceDraft = draft
        navigateToConfirm = true
    }

    private var voiceInputSuggestions: [String] {
        [
            String(localized: "watch.voice.suggestion.coffee"),
            String(localized: "watch.voice.suggestion.lunch"),
            String(localized: "watch.voice.suggestion.taxi")
        ]
    }

    private static func firstRecognizedText(from results: [Any]?) -> String? {
        results?
            .compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
