import SwiftUI
import UIKit

struct DebugView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var copyStatusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                overviewCard

                if let summary = store.lastImportSummary {
                    summaryCard(summary)
                }

                if let receipt = store.lastParsedReceipt {
                    parsedReceiptCard(receipt)
                }

                if !store.lastRecognizedText.isEmpty {
                    rawTextCard(title: "最近 OCR 文本", text: store.lastRecognizedText)
                }

                if !store.debugRecords.isEmpty {
                    Text("最近调试记录")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    ForEach(store.debugRecords.prefix(10)) { record in
                        debugRecordCard(record)
                    }
                }

                Text("最近账单")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                ForEach(store.transactions.prefix(5)) { transaction in
                    transactionCard(transaction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("调试与回归")
        .alert("测试记录已准备好", isPresented: Binding(
            get: { copyStatusMessage != nil },
            set: { if !$0 { copyStatusMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {
                copyStatusMessage = nil
            }
        } message: {
            Text(copyStatusMessage ?? "")
        }
        .toolbar {
            if hasExportableContent {
                Button("拷贝记录") {
                    UIPasteboard.general.string = exportText
                    copyStatusMessage = "已将当前测试记录复制到剪贴板，可以直接粘贴到备忘录、Issue 或回归文档。"
                }
                .foregroundStyle(AppTheme.accent)
            }

            if !store.debugRecords.isEmpty || !store.lastRecognizedText.isEmpty || store.lastParsedReceipt != nil || store.lastImportSummary != nil {
                Button("清空") {
                    store.clearDebugRecords()
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("真实截图调试面板")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            Text("这里集中展示最近一次 OCR 原文、解析结果、导入状态和最近账单，方便在真机上拿真实截图做回归。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)

            HStack(spacing: 12) {
                MetricCard(
                    title: "调试记录",
                    value: "\(store.debugRecords.count)",
                    detail: "最近导入链路",
                    accent: AppTheme.accent
                )

                MetricCard(
                    title: "最近账单",
                    value: "\(store.transactions.count)",
                    detail: "本地 SQLite",
                    accent: AppTheme.accentSecondary
                )
            }

            Text("回归完成后可直接点右上角“拷贝记录”，导出当前调试快照。")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func summaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近状态")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func parsedReceiptCard(_ receipt: ImportedReceipt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近解析结果")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            receiptRow("来源", receipt.source.title)
            receiptRow("商户", receipt.merchant)
            receiptRow("金额", AppFormatters.currency(receipt.amount))
            receiptRow("分类", receipt.suggestedCategory.title)
            receiptRow("时间", AppFormatters.shortDateTime(receipt.occurredAt))
            receiptRow("摘要", receipt.summary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func rawTextCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text(text)
                .font(.footnote.monospaced())
                .foregroundStyle(AppTheme.ink.opacity(0.84))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func debugRecordCard(_ record: ImportDebugRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.stage.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Text("\(record.source.title) · \(AppFormatters.shortDateTime(record.createdAt))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Text(record.stage.title)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(stageColor(record.stage).opacity(0.14))
                    .foregroundStyle(stageColor(record.stage))
                    .clipShape(Capsule())
            }

            Text(record.summary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)

            Button {
                UIPasteboard.general.string = singleRecordExportText(record)
                copyStatusMessage = "已将这条调试记录复制到剪贴板，可以只粘贴这个问题样例。"
            } label: {
                Label("拷贝这条", systemImage: "doc.on.doc")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)

            if let receipt = record.parsedReceipt {
                Text("商户 \(receipt.merchant) · \(AppFormatters.currency(receipt.amount)) · \(receipt.suggestedCategory.title)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            if !record.rawText.isEmpty {
                Text(record.rawText)
                    .font(.footnote.monospaced())
                    .foregroundStyle(AppTheme.ink.opacity(0.78))
                    .lineLimit(6)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func transactionCard(_ transaction: Transaction) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: transaction.category.iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(transaction.category.tint)
                .frame(width: 34, height: 34)
                .background(transaction.category.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(transaction.merchant)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text("\(transaction.category.title) · \(transaction.source.title) · \(AppFormatters.shortDateTime(transaction.occurredAt))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }

            Spacer()

            Text(AppFormatters.currency(transaction.amount))
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func receiptRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 52, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stageColor(_ stage: ImportDebugStage) -> Color {
        switch stage {
        case .persisted:
            return Color(red: 0.18, green: 0.67, blue: 0.36)
        case .duplicateSkipped:
            return Color(red: 0.75, green: 0.57, blue: 0.14)
        case .ocrFailed, .parseFailed, .persistenceFailed:
            return Color(red: 0.74, green: 0.28, blue: 0.28)
        }
    }

    private var hasExportableContent: Bool {
        store.lastImportSummary != nil ||
        !store.lastRecognizedText.isEmpty ||
        store.lastParsedReceipt != nil ||
        !store.debugRecords.isEmpty
    }

    private var exportText: String {
        var lines: [String] = [
            "AutoLedger 测试记录",
            "导出时间：\(AppFormatters.exportDateTime(.now))"
        ]

        if let summary = store.lastImportSummary {
            lines.append("最近状态：\(summary)")
        }

        if let receipt = store.lastParsedReceipt {
            lines.append("最近解析结果：")
            lines.append("- 来源：\(receipt.source.title)")
            lines.append("- 商户：\(receipt.merchant)")
            lines.append("- 金额：\(AppFormatters.currency(receipt.amount))")
            lines.append("- 分类：\(receipt.suggestedCategory.title)")
            lines.append("- 时间：\(AppFormatters.exportDateTime(receipt.occurredAt))")
            lines.append("- 摘要：\(receipt.summary)")
        }

        if !store.lastRecognizedText.isEmpty {
            lines.append("最近 OCR 文本：")
            lines.append(store.lastRecognizedText)
        }

        if !store.debugRecords.isEmpty {
            lines.append("最近调试记录：")
            for record in store.debugRecords.prefix(10) {
                lines.append("- [\(record.stage.title)] \(record.source.title) · \(AppFormatters.exportDateTime(record.createdAt))")
                lines.append("  结论：\(record.summary)")
                if let receipt = record.parsedReceipt {
                    lines.append("  解析：\(receipt.merchant) · \(AppFormatters.currency(receipt.amount)) · \(receipt.suggestedCategory.title)")
                }
                if !record.rawText.isEmpty {
                    lines.append("  OCR：\(record.rawText)")
                }
            }
        }

        if !store.transactions.isEmpty {
            lines.append("最近账单：")
            for transaction in store.transactions.prefix(5) {
                lines.append("- \(transaction.merchant) · \(AppFormatters.currency(transaction.amount)) · \(transaction.category.title) · \(AppFormatters.exportDateTime(transaction.occurredAt))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func singleRecordExportText(_ record: ImportDebugRecord) -> String {
        var lines: [String] = [
            "AutoLedger 单条测试记录",
            "导出时间：\(AppFormatters.exportDateTime(.now))",
            "记录时间：\(AppFormatters.exportDateTime(record.createdAt))",
            "阶段：\(record.stage.title)",
            "来源：\(record.source.title)",
            "结论：\(record.summary)"
        ]

        if let receipt = record.parsedReceipt {
            lines.append("解析结果：")
            lines.append("- 商户：\(receipt.merchant)")
            lines.append("- 金额：\(AppFormatters.currency(receipt.amount))")
            lines.append("- 分类：\(receipt.suggestedCategory.title)")
            lines.append("- 时间：\(AppFormatters.exportDateTime(receipt.occurredAt))")
            lines.append("- 摘要：\(receipt.summary)")
        }

        if !record.rawText.isEmpty {
            lines.append("OCR 文本：")
            lines.append(record.rawText)
        }

        return lines.joined(separator: "\n")
    }
}

#Preview {
    NavigationStack {
        DebugView()
            .environmentObject(LedgerStore())
    }
}
