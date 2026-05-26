import AutoLedgerCore
import SwiftUI

/// Watch 侧语音记账确认页。
/// 展示 VoiceLedgerParser 的解析结果，允许用户调整分类后保存。
struct WatchVoiceConfirmView: View {

    @Environment(WatchLedgerViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    /// 解析后的分类（允许用户在确认页修改）
    @State private var selectedCategory: TransactionCategory = .dining

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

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 6
                    ) {
                        ForEach(TransactionCategory.allCases) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: cat.iconName)
                                        .font(.caption)
                                        .accessibilityHidden(true)
                                    Text(cat.title)
                                        .font(.caption2)
                                        .lineLimit(1)
                                    if selectedCategory == cat {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(
                                    selectedCategory == cat
                                        ? Color.accentColor.opacity(0.25)
                                        : Color.secondary.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .strokeBorder(
                                            selectedCategory == cat ? Color.accentColor : .clear,
                                            lineWidth: 1.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(cat.title)
                            .accessibilityAddTraits(selectedCategory == cat ? [.isSelected] : [])
                        }
                    }

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
                selectedCategory = d.category
            }
        }
    }

    // MARK: - Private

    private func confirmAndSave() {
        guard var draft = viewModel.voiceDraft else { return }
        draft.categoryRaw = selectedCategory.rawValue
        viewModel.submitVoiceDraft(draft)
        dismiss()
    }
}
