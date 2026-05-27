import AutoLedgerCore
import SwiftUI

/// Watch 侧语音记账确认页。
/// 展示 VoiceLedgerParser 的解析结果，允许用户调整分类后保存。
struct WatchVoiceConfirmView: View {

    @Environment(WatchLedgerViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    /// 解析后的分类（允许用户在确认页修改）
    @State private var selectedCategoryRaw: String = TransactionCategory.dining.rawValue

    var body: some View {
        ScrollView {
            if let draft = viewModel.voiceDraft {
                VStack(spacing: 10) {

                    // MARK: 金额展示
                    VStack(spacing: 2) {
                        Text("¥ \(draft.amount, specifier: "%.2f")")
                            .font(.title2.bold())
                        Text(draft.merchant)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        Text(String(format: String(localized: "watch.voice.confirm.amount_accessibility_format"), draft.amount, draft.merchant))
                    )

                    Divider()

                    // MARK: 分类选择
                    Text("transaction_editor.category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    WatchCategoryGrid(options: viewModel.categoryOptions, selection: $selectedCategoryRaw)

                    Divider()

                    // MARK: 保存按钮
                    Button {
                        confirmAndSave()
                    } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                            Label("common.save", systemImage: "checkmark")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSubmitting)
                    .accessibilityLabel(Text("watch.voice.confirm.save_accessibility"))
                    .accessibilityHint(Text("watch.voice.confirm.save_hint"))

                    Button("common.cancel", role: .cancel) {
                        viewModel.voiceDraft = nil
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView("watch.voice.confirm.empty", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("watch.voice.confirm.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let d = viewModel.voiceDraft {
                selectedCategoryRaw = d.categoryRaw
            }
        }
    }

    // MARK: - Private

    private func confirmAndSave() {
        guard var draft = viewModel.voiceDraft else { return }
        draft.categoryRaw = selectedCategoryRaw
        viewModel.submitVoiceDraft(draft)
        dismiss()
    }
}
