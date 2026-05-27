import AutoLedgerCore
import SwiftUI

/// Watch 快速记账面板：分类选择 + 金额 + 商户（可选）。
struct QuickAddView: View {

    @Environment(WatchLedgerViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isAmountPadPresented = false

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(spacing: 12) {
                amountHeader

                if isAmountPadPresented {
                    WatchAmountPad(text: $vm.quickAddAmountText)
                }

                // MARK: 分类选择
                Text("transaction_editor.category")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                WatchCategoryGrid(options: viewModel.categoryOptions, selection: $vm.quickAddCategoryRaw)

                Divider()

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
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var amountHeader: some View {
        @Bindable var vm = viewModel
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("¥")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Button {
                    isAmountPadPresented.toggle()
                } label: {
                    Text(amountDisplayText)
                        .font(Font.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("transaction_editor.amount"))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            TextField(viewModel.quickAddCategoryOption.title, text: $vm.quickAddMerchant)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel(Text("transaction_editor.merchant"))
        }
        .padding(.bottom, 4)
    }

    private var amountDisplayText: String {
        let raw = viewModel.quickAddAmountText.trimmingCharacters(in: .whitespaces)
        return raw.isEmpty ? "0.00" : raw
    }
}

private struct WatchAmountPad: View {
    @Binding var text: String

    private let rows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "delete.left"]
    ]

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        Button {
                            apply(key)
                        } label: {
                            if key == "delete.left" {
                                Image(systemName: key)
                                    .font(.caption.weight(.semibold))
                            } else {
                                Text(key)
                                    .font(.caption.weight(.bold).monospacedDigit())
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func apply(_ key: String) {
        switch key {
        case "delete.left":
            if !text.isEmpty {
                text.removeLast()
            }
        case ".":
            if !text.contains(".") && !text.contains("，") {
                text = text.isEmpty ? "0." : text + "."
            }
        default:
            guard text.count < 8 else { return }
            if let dotIndex = text.firstIndex(of: ".") {
                let decimals = text[text.index(after: dotIndex)...]
                guard decimals.count < 2 else { return }
            }
            text = text == "0" ? key : text + key
        }
    }
}
