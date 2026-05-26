import AutoLedgerCore
import SwiftUI

/// Watch 快速记账面板：分类选择 + 金额 + 商户（可选）。
struct QuickAddView: View {

    @Environment(WatchLedgerViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(spacing: 10) {

                // MARK: 分类选择
                Text("transaction_editor.category")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 6) {
                    ForEach(TransactionCategory.allCases) { cat in
                        Button {
                            vm.quickAddCategory = cat
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: cat.iconName)
                                    .font(.caption)
                                    .accessibilityHidden(true)
                                Text(cat.title)
                                    .font(.caption2)
                                    .lineLimit(1)
                                if vm.quickAddCategory == cat {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                vm.quickAddCategory == cat
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.secondary.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        vm.quickAddCategory == cat ? Color.accentColor : .clear,
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(cat.title)
                        .accessibilityAddTraits(vm.quickAddCategory == cat ? [.isSelected] : [])
                    }
                }

                Divider()

                // MARK: 金额
                Text("transaction_editor.amount")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("0.00", text: $vm.quickAddAmountText)
                    .font(.title3.monospacedDigit())
                    .accessibilityLabel(Text("transaction_editor.amount"))

                // MARK: 商户（可选）
                Text("watch.quick_add.merchant_optional")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField(vm.quickAddCategory.title, text: $vm.quickAddMerchant)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .accessibilityLabel(Text("transaction_editor.merchant"))

                Divider()

                // MARK: 操作按钮
                Button {
                    viewModel.submitDraftAdd()
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Label("watch.quick_add.submit", systemImage: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.quickAddAmountValid || viewModel.isSubmitting)
                .accessibilityLabel(Text("watch.quick_add.submit"))

                Button("common.cancel", role: .cancel) {
                    viewModel.resetQuickAddInput()
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}
