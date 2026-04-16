import AutoLedgerCore
import SwiftUI
import UIKit

struct DebugView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var copyStatusMessage: String?
    @State private var selectedDataTab: DataTab = .transactions
    @State private var showShareSheet = false
    @State private var diagnosticZipURL: URL?

    enum DataTab: String, CaseIterable, Identifiable {
        case transactions = "交易"
        case subscriptions = "订阅"
        case corrections = "分类学习"
        case debugEvents = "调试事件"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                overviewCard
                systemInfoCard
                gemmaMetricsCard
                containerInfoCard

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

                    ForEach(Array(store.debugRecords.prefix(10))) { record in
                        debugRecordCard(record)
                    }
                }

                sqliteDataBrowser

                Text("最近账单")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                ForEach(Array(store.transactions.prefix(5))) { transaction in
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
            ToolbarItemGroup(placement: .primaryAction) {
                Button("诊断包") {
                    exportDiagnosticBundle()
                }
                .foregroundStyle(AppTheme.accent)

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
        .sheet(isPresented: $showShareSheet) {
            if let url = diagnosticZipURL {
                ShareSheet(activityItems: [url])
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

    // MARK: - System Info

    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统信息")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            let device = FeedbackBundleBuilder.collectDeviceInfo()
            infoRow("App 版本", device.appVersion)
            infoRow("Build", device.buildNumber)
            infoRow("iOS", device.iosVersion)
            infoRow("设备", device.deviceModel)
            infoRow("内存使用", formatMemory())
            infoRow("磁盘可用", formatDiskSpace())
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.card))
    }

    // MARK: - Gemma Metrics

    private var gemmaMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gemma 模型加载")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            let svc = GemmaService.shared
            let stateText: String = {
                if svc.isModelReady { return "已就绪（内存中）" }
                if svc.isModelDownloaded { return "已下载（未加载）" }
                return "未下载"
            }()
            infoRow("当前状态", stateText)

            if svc.loadCount > 0 {
                if let last = svc.lastLoadTimeSeconds {
                    infoRow("最近加载耗时", String(format: "%.2f s", last))
                }
                if let avg = svc.averageLoadTimeSeconds {
                    infoRow("平均加载耗时（\(svc.loadCount) 次）", String(format: "%.2f s", avg))
                }
            } else {
                Text("暂无加载记录")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.card))
    }

    private var containerInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Group 容器")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.top.darkrio326.AutoLedger") {
                let files = (try? FileManager.default.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: [.fileSizeKey])) ?? []
                if files.isEmpty {
                    Text("容器为空")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                } else {
                    ForEach(files, id: \.absoluteString) { url in
                        HStack(spacing: 8) {
                            Image(systemName: url.hasDirectoryPath ? "folder" : "doc")
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedInk)
                            Text(url.lastPathComponent)
                                .font(.caption.monospaced())
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.mutedInk)
                            }
                        }
                    }
                }
            } else {
                Text("无法访问 App Group 容器")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.card))
    }

    // MARK: - SQLite Data Browser

    private var sqliteDataBrowser: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SQLite 数据浏览")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            Picker("", selection: $selectedDataTab) {
                ForEach(DataTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            switch selectedDataTab {
            case .transactions:
                Text("\(store.transactions.count) 条交易")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                ForEach(Array(store.transactions.prefix(20))) { tx in
                    sqliteRow("\(tx.merchant) · \(AppFormatters.currency(tx.amount)) · \(tx.categoryTitle) · \(AppFormatters.shortDateTime(tx.occurredAt))")
                }
            case .subscriptions:
                Text("\(store.subscriptions.count) 条订阅")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                ForEach(store.subscriptions) { sub in
                    sqliteRow("\(sub.merchant) · \(sub.period.rawValue) · \(AppFormatters.currency(sub.amount))")
                }
            case .corrections:
                let sorted = store.categoryCorrections.sorted { $0.key < $1.key }
                Text("\(sorted.count) 条分类学习")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                ForEach(sorted, id: \.key) { merchant, category in
                    sqliteRow("\(merchant) → \(category.title)")
                }
            case .debugEvents:
                Text("\(store.debugRecords.count) 条调试事件")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                ForEach(Array(store.debugRecords.prefix(20))) { record in
                    sqliteRow("[\(record.stage.title)] \(record.source.title) · \(record.imageSource.title) · \(AppFormatters.shortDateTime(record.createdAt))")
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.card))
    }

    private func sqliteRow(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(AppTheme.ink.opacity(0.85))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
            Spacer()
            Text(value)
                .font(.subheadline.monospaced())
                .foregroundStyle(AppTheme.ink)
        }
    }

    // MARK: - Helpers

    private func formatMemory() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            return ByteCountFormatter.string(fromByteCount: Int64(info.resident_size), countStyle: .memory)
        }
        return "N/A"
    }

    private func formatDiskSpace() -> String {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let free = attrs[.systemFreeSize] as? Int64 {
            return ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
        }
        return "N/A"
    }

    private func exportDiagnosticBundle() {
        let feedbackID = FeedbackBundleBuilder.generateFeedbackID()
        do {
            let bundleDir = try FeedbackBundleBuilder.buildBundle(
                feedbackID: feedbackID,
                level: .L3,
                issueType: .other,
                userDescription: "开发者一键导出诊断包",
                expectedResult: "",
                actualResult: "",
                reproducible: "N/A",
                entryPoint: "debug_view",
                debugRecords: store.debugRecords,
                transactions: store.transactions,
                lastOCRText: store.lastRecognizedText,
                lastReceipt: store.lastParsedReceipt
            )
            let zipURL = try FeedbackBundleBuilder.zipBundle(at: bundleDir, feedbackID: feedbackID, level: .L3)
            diagnosticZipURL = zipURL
            showShareSheet = true
        } catch {
            copyStatusMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Existing Cards

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

                    HStack(spacing: 6) {
                        Text(record.source.title)
                        Text("·")
                        Text(record.imageSource.title)
                        if record.usedLLM {
                            Text("·")
                            Text("LLM")
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)

                    Text(AppFormatters.shortDateTime(record.createdAt))
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

            if let prompt = record.llmPrompt {
                VStack(alignment: .leading, spacing: 6) {
                    Text("模型输入")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                    Text(prompt)
                        .font(.footnote.monospaced())
                        .foregroundStyle(AppTheme.ink.opacity(0.78))
                        .lineLimit(8)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.accent.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let response = record.llmResponse {
                VStack(alignment: .leading, spacing: 6) {
                    Text("模型输出")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(red: 0.18, green: 0.67, blue: 0.36))
                    Text(response)
                        .font(.footnote.monospaced())
                        .foregroundStyle(AppTheme.ink.opacity(0.78))
                        .lineLimit(8)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.18, green: 0.67, blue: 0.36).opacity(0.06))
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
            Image(systemName: transaction.categoryEnum.iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(transaction.categoryEnum.tint)
                .frame(width: 34, height: 34)
                .background(transaction.categoryEnum.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(transaction.merchant)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text("\(transaction.categoryTitle) · \(transaction.sourceTitle) · \(AppFormatters.shortDateTime(transaction.occurredAt))")
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
                lines.append("- [\(record.stage.title)] \(record.source.title) · \(record.imageSource.title) · \(record.usedLLM ? "LLM" : "规则") · \(AppFormatters.exportDateTime(record.createdAt))")
                lines.append("  结论：\(record.summary)")
                if let receipt = record.parsedReceipt {
                    lines.append("  解析：\(receipt.merchant) · \(AppFormatters.currency(receipt.amount)) · \(receipt.suggestedCategory.title)")
                }
                if let txID = record.transactionID,
                   let tx = store.transactions.first(where: { $0.id == txID }) {
                    let noteStr = tx.note.isEmpty ? "" : " · 备注：\(tx.note)"
                    lines.append("  当前账单（用户修改后）：\(tx.merchant) · \(AppFormatters.currency(tx.amount)) · \(tx.categoryTitle) · \(AppFormatters.exportDateTime(tx.occurredAt))\(noteStr)")
                }
                if !record.rawText.isEmpty {
                    lines.append("  OCR：\(record.rawText)")
                }
                if let prompt = record.llmPrompt {
                    lines.append("  模型输入：\(prompt)")
                }
                if let response = record.llmResponse {
                    lines.append("  模型输出：\(response)")
                }
            }
        }

        if !store.transactions.isEmpty {
            lines.append("最近账单：")
            for transaction in store.transactions.prefix(5) {
                lines.append("- \(transaction.merchant) · \(AppFormatters.currency(transaction.amount)) · \(transaction.categoryTitle) · \(AppFormatters.exportDateTime(transaction.occurredAt))")
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
            "图片来源：\(record.imageSource.title)",
            "解析模式：\(record.usedLLM ? "LLM 智能解析" : "纯规则解析")",
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

        if let txID = record.transactionID,
           let tx = store.transactions.first(where: { $0.id == txID }) {
            lines.append("当前账单（用户修改后）：")
            lines.append("- 商户：\(tx.merchant)")
            lines.append("- 金额：\(AppFormatters.currency(tx.amount))")
            lines.append("- 分类：\(tx.categoryTitle)")
            lines.append("- 时间：\(AppFormatters.exportDateTime(tx.occurredAt))")
            if !tx.note.isEmpty {
                lines.append("- 备注：\(tx.note)")
            }
        }

        if !record.rawText.isEmpty {
            lines.append("OCR 文本：")
            lines.append(record.rawText)
        }

        if let prompt = record.llmPrompt {
            lines.append("模型输入：")
            lines.append(prompt)
        }

        if let response = record.llmResponse {
            lines.append("模型输出：")
            lines.append(response)
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

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
