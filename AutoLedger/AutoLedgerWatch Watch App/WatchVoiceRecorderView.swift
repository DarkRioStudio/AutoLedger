import AutoLedgerCore
import SwiftUI

/// Watch 侧语音记账录入视图。
/// 点击输入框即触发系统输入 UI（含听写），
/// 提交后调用 VoiceLedgerParser 解析，将草稿写入 ViewModel。
struct WatchVoiceRecorderView: View {

    @Environment(WatchLedgerViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""
    @State private var isParsing = false
    @State private var parseError: String? = nil
    @State private var navigateToConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {

                // MARK: 图标提示
                if !isParsing {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 4)
                        .accessibilityHidden(true)

                    Text("点击输入框后选择听写")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // MARK: 输入框（触发系统输入/听写）
                TextField("如：咖啡 28 元", text: $inputText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)                    .accessibilityLabel("语音内容")
                    .accessibilityHint("输入记账语句，如和啊 28 元")
                // MARK: 错误提示
                if let err = parseError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // MARK: 解析按钮
                Button {
                    parseDictatedText()
                } label: {
                    if isParsing {
                        ProgressView()
                    } else {
                        Label("解析", systemImage: "arrow.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isParsing)
                .accessibilityLabel("解析并进入确认")

                // MARK: 跳转确认页（解析成功后）
                NavigationLink(
                    destination: WatchVoiceConfirmView()
                        .environment(viewModel),
                    isActive: $navigateToConfirm
                ) { EmptyView() }
                    .hidden()

                Button("取消") {
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
            .navigationTitle("语音记账")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Private

    private func parseDictatedText() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isParsing = true
        parseError = nil

        let result = VoiceLedgerParser().parse(text)
        isParsing = false

        guard result.isSaveable, let amount = result.amount else {
            parseError = "未能识别金额，请重试"
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
}
