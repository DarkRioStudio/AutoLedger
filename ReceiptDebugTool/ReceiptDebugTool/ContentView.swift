import AutoLedgerCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = ReceiptDebugStore()

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(store: store)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                ImageDropColumn(store: store)
                    .frame(minWidth: 250, idealWidth: 290, maxWidth: 340)
                Divider()

                if let binding = selectedCaseBinding {
                    OCRTextColumn(debugCase: binding) {
                        store.didEditCase(id: binding.wrappedValue.id)
                    }
                    .frame(minWidth: 270)
                    Divider()

                    ParsedBillColumn(debugCase: binding) {
                        store.didEditCase(id: binding.wrappedValue.id)
                    }
                    .frame(minWidth: 270)
                    Divider()

                    ExpectationColumn(debugCase: binding, store: store)
                        .frame(minWidth: 320)
                } else {
                    ContentUnavailableView("拖入小票图片开始调试", systemImage: "doc.viewfinder")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            Divider()

            BottomActionBar(store: store)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var selectedCaseBinding: Binding<ReceiptDebugCase>? {
        guard let selectedCaseID = store.selectedCaseID,
              let index = store.cases.firstIndex(where: { $0.id == selectedCaseID }) else {
            return nil
        }

        return Binding(
            get: { store.cases[index] },
            set: { newValue in
                store.cases[index] = newValue
                store.didEditCase(id: newValue.id)
            }
        )
    }
}

struct ToolbarView: View {
    @ObservedObject var store: ReceiptDebugStore

    var body: some View {
        HStack(spacing: 10) {
            Button("清空图片", systemImage: "trash") {
                store.clearSession()
            }
            Button("刷新 OCR 文本", systemImage: "text.viewfinder") {
                Task { await store.refreshOCRForSelectionOrAll() }
            }
            .disabled(store.cases.isEmpty || store.isWorking)

            Button("刷新账单文本", systemImage: "doc.text.magnifyingglass") {
                store.refreshParseForSelectionOrAll()
            }
            .disabled(store.cases.isEmpty || store.isWorking)

            Button("纳入 Golden 候选", systemImage: "checkmark.seal") {
                Task { await store.exportGoldenCandidates() }
            }
            .disabled(!store.cases.contains { $0.expectation != nil } || store.isWorking)

            Spacer()

            if store.isWorking {
                ProgressView()
                    .controlSize(.small)
            }
            Text(store.statusMessage)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(10)
    }
}

struct ImageDropColumn: View {
    @ObservedObject var store: ReceiptDebugStore
    @State private var enlargedCase: ReceiptDebugCase?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("拖入图片")
                .font(.headline)
                .padding([.horizontal, .top], 12)

            List(selection: $store.selectedCaseID) {
                ForEach(store.cases) { debugCase in
                    ReceiptRow(debugCase: debugCase)
                        .tag(debugCase.id)
                }
            }
            .listStyle(.sidebar)

            if let selected = store.selectedCase {
                Divider()
                ReceiptPreview(debugCase: selected) {
                    enlargedCase = selected
                }
                    .frame(height: 160)
                    .padding(10)
            }
        }
        .sheet(item: $enlargedCase) { debugCase in
            EnlargedReceiptPreview(debugCase: debugCase)
                .frame(minWidth: 980, minHeight: 680)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            Task { await store.importProviders(providers) }
            return true
        }
    }
}

struct ReceiptRow: View {
    var debugCase: ReceiptDebugCase

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(debugCase.originalFileName)
                    .lineLimit(1)
                HStack {
                    Text(debugCase.testStatus.title)
                    if debugCase.isObviousError {
                        Text("已标记")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .listRowBackground(rowBackground)
    }

    private var iconName: String {
        switch debugCase.testStatus {
        case .failed, .validatorFailed: "exclamationmark.triangle.fill"
        case .nonBill: "minus.circle"
        case .goldenCandidate: "checkmark.seal.fill"
        default: "photo"
        }
    }

    private var iconColor: Color {
        switch debugCase.testStatus {
        case .failed, .validatorFailed: .red
        case .nonBill: .secondary
        case .goldenCandidate: .green
        default: .accentColor
        }
    }

    private var rowBackground: Color? {
        if debugCase.isObviousError || debugCase.testStatus == .failed || debugCase.testStatus == .validatorFailed {
            return Color.red.opacity(0.12)
        }
        if debugCase.testStatus == .nonBill {
            return Color.gray.opacity(0.10)
        }
        return nil
    }
}

struct ReceiptPreview: View {
    var debugCase: ReceiptDebugCase
    var onOpen: () -> Void

    var body: some View {
        if let image = NSImage(contentsOf: debugCase.imageURL) {
            Button(action: onOpen) {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Label("放大预览", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .padding(8)
                }
            }
            .buttonStyle(.plain)
            .help("点击放大预览图片和 OCR 结果")
        } else {
            ContentUnavailableView("无法预览图片", systemImage: "photo")
        }
    }
}

struct EnlargedReceiptPreview: View {
    var debugCase: ReceiptDebugCase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(debugCase.originalFileName)
                        .font(.headline)
                    Text("样本 ID：\(debugCase.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("关闭", systemImage: "xmark") {
                    dismiss()
                }
            }
            .padding(12)

            Divider()

            HSplitView {
                ScrollView([.horizontal, .vertical]) {
                    if let image = NSImage(contentsOf: debugCase.imageURL) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(minWidth: 520, minHeight: 560)
                            .padding(16)
                    } else {
                        ContentUnavailableView("无法预览图片", systemImage: "photo")
                            .frame(minWidth: 520, minHeight: 560)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("识别结果")
                        .font(.headline)
                    metadataGrid
                    Text("OCR 原文")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ocrText(debugCase.activeOCRText.isEmpty ? "暂无 OCR 文本，请先点击“刷新 OCR 文本”。" : debugCase.activeOCRText)
                    Text("脱敏预览")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ocrText(debugCase.redactedText.isEmpty ? "暂无脱敏文本。" : debugCase.redactedText)
                }
                .padding(12)
                .frame(minWidth: 360)
            }
        }
    }

    private var metadataGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow {
                Text("状态")
                Text(debugCase.testStatus.title)
                Text("行数")
                Text("\(debugCase.ocrLineCount)")
            }
            GridRow {
                Text("耗时")
                Text(debugCase.ocrDurationMs.map { "\($0) ms" } ?? "-")
                Text("尺寸")
                Text(sizeText)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func ocrText(_ value: String) -> some View {
        ScrollView {
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(8)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var sizeText: String {
        guard let width = debugCase.imageWidth, let height = debugCase.imageHeight else { return "-" }
        return "\(width)x\(height)"
    }
}

struct OCRTextColumn: View {
    @Binding var debugCase: ReceiptDebugCase
    var onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OCR 文本")
                .font(.headline)

            metadataGrid

            Text("原始 / 修订文本")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextEditor(text: editedText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("脱敏预览")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView {
                Text(debugCase.redactedText.isEmpty ? "暂无 OCR 文本。" : debugCase.redactedText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(height: 140)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(12)
    }

    private var editedText: Binding<String> {
        Binding(
            get: { debugCase.ocrTextEdited ?? debugCase.ocrTextOriginal },
            set: {
                debugCase.ocrTextEdited = $0
                onChange()
            }
        )
    }

    private var metadataGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow {
                Text("行数")
                Text("\(debugCase.ocrLineCount)")
                Text("置信度")
                Text(confidenceText)
            }
            GridRow {
                Text("耗时")
                Text(debugCase.ocrDurationMs.map { "\($0) ms" } ?? "-")
                Text("尺寸")
                Text(sizeText)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var confidenceText: String {
        guard let min = debugCase.ocrMinConfidence, let mean = debugCase.ocrMeanConfidence else { return "-" }
        return "最低 \(String(format: "%.2f", min)) / 平均 \(String(format: "%.2f", mean))"
    }

    private var sizeText: String {
        guard let width = debugCase.imageWidth, let height = debugCase.imageHeight else { return "-" }
        return "\(width)x\(height)"
    }
}

struct ParsedBillColumn: View {
    @Binding var debugCase: ReceiptDebugCase
    var onChange: () -> Void

    private let sourceHints: [LedgerSourceHint] = [.unknown, .receipt, .payment, .sentence, .subscription]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("结构化账单文本")
                .font(.headline)

            Picker("来源提示", selection: $debugCase.sourceHint) {
                ForEach(sourceHints, id: \.rawValue) { hint in
                    Text(sourceHintTitle(hint)).tag(hint)
                }
            }
            .onChange(of: debugCase.sourceHint) { _, _ in onChange() }

            if let result = debugCase.parseResult {
                parseSummary(result)
                jsonView(result)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("暂无解析结果", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("请先点击“刷新账单文本”。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func parseSummary(_ result: InterpretResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("金额", value: result.draft?.amount.formatted(.number.precision(.fractionLength(2))) ?? "-")
            LabeledContent("商户", value: result.draft?.merchant ?? "-")
            LabeledContent("分类", value: result.draft?.category ?? "-")
            LabeledContent("来源", value: result.draft?.sourceType.rawValue ?? debugCase.sourceType.rawValue)
            LabeledContent("方法", value: result.draft?.parseMethod.rawValue ?? "-")
            LabeledContent("置信度", value: result.confidence.rawValue)
            LabeledContent("需要复核", value: result.needsReview ? "是" : "否")
            LabeledContent("警告", value: result.warnings.map(\.rawValue).joined(separator: ", "))
        }
        .font(.caption)
    }

    private func jsonView(_ result: InterpretResult) -> some View {
        ScrollView {
            Text(prettyJSON(result))
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(8)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func prettyJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private func sourceHintTitle(_ hint: LedgerSourceHint) -> String {
        switch hint {
        case .unknown: "未知"
        case .receipt: "纸质小票"
        case .payment: "支付截图"
        case .sentence: "一句话"
        case .subscription: "订阅"
        }
    }
}

struct ExpectationColumn: View {
    @Binding var debugCase: ReceiptDebugCase
    @ObservedObject var store: ReceiptDebugStore
    private let categories = TransactionCategory.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("测试结果 / 期望")
                .font(.headline)

            HStack {
                Button("用当前解析填充", systemImage: "wand.and.stars") {
                    store.fillExpectationFromParse(for: debugCase.id)
                }
                .disabled(debugCase.parseResult == nil)

                Button("非账单期望", systemImage: "minus.circle") {
                    store.applyNonBillExpectation(for: debugCase.id)
                }
            }

            expectationForm
            diffList
            obviousErrorPanel
        }
        .padding(12)
    }

    private var expectationForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("应生成账单", isOn: optionalBoolBinding(\.draftExists, defaultValue: true))
            HStack {
                Text("金额")
                TextField("", value: optionalDoubleBinding(\.amount), format: .number)
                    .textFieldStyle(.roundedBorder)
                Text("容差")
                TextField("", value: optionalDoubleBinding(\.amountTolerance), format: .number)
                    .textFieldStyle(.roundedBorder)
            }
            TextField("商户等于", text: optionalStringBinding(\.merchantEquals))
                .textFieldStyle(.roundedBorder)
            TextField("商户包含", text: optionalStringBinding(\.merchantContains))
                .textFieldStyle(.roundedBorder)
            Picker("分类期望", selection: optionalStringBinding(\.category)) {
                Text("不校验分类").tag("")
                ForEach(categories) { category in
                    Text(categoryExpectationTitle(category)).tag(category.rawValue)
                }
            }
            .pickerStyle(.menu)
            TextField("警告包含，用逗号分隔", text: warningsBinding)
                .textFieldStyle(.roundedBorder)
        }
        .font(.caption)
    }

    private var diffList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("字段对比")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    ForEach(debugCase.fieldDiffs) { diff in
                        HStack(alignment: .top) {
                            Text(diff.status.title)
                                .foregroundStyle(color(for: diff.status))
                                .frame(width: 58, alignment: .leading)
                            VStack(alignment: .leading) {
                                Text(fieldTitle(diff.field))
                                Text("期望：\(diff.expected)")
                                    .foregroundStyle(.secondary)
                                Text("实际：\(diff.actual)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var obviousErrorPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("明显识别错误", isOn: $debugCase.isObviousError)
            Menu("标记原因") {
                ForEach(ObviousErrorReason.allCases) { reason in
                    Button(reason.title) {
                        store.toggleObviousReason(reason, for: debugCase.id)
                    }
                }
            }
            FlowTags(values: debugCase.obviousErrorReasons.map(\.title))
        }
        .font(.caption)
    }

    private func optionalBoolBinding(_ keyPath: WritableKeyPath<GoldenExpectation, Bool?>, defaultValue: Bool) -> Binding<Bool> {
        Binding(
            get: { (debugCase.expectation ?? .empty)[keyPath: keyPath] ?? defaultValue },
            set: { value in
                ensureExpectation()
                debugCase.expectation?[keyPath: keyPath] = value
                store.didEditCase(id: debugCase.id)
            }
        )
    }

    private func optionalDoubleBinding(_ keyPath: WritableKeyPath<GoldenExpectation, Double?>) -> Binding<Double?> {
        Binding(
            get: { (debugCase.expectation ?? .empty)[keyPath: keyPath] },
            set: { value in
                ensureExpectation()
                debugCase.expectation?[keyPath: keyPath] = value
                store.didEditCase(id: debugCase.id)
            }
        )
    }

    private func optionalStringBinding(_ keyPath: WritableKeyPath<GoldenExpectation, String?>) -> Binding<String> {
        Binding(
            get: { (debugCase.expectation ?? .empty)[keyPath: keyPath] ?? "" },
            set: { value in
                ensureExpectation()
                debugCase.expectation?[keyPath: keyPath] = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
                store.didEditCase(id: debugCase.id)
            }
        )
    }

    private var warningsBinding: Binding<String> {
        Binding(
            get: { debugCase.expectation?.warningsContains?.joined(separator: ", ") ?? "" },
            set: { value in
                ensureExpectation()
                let values = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                debugCase.expectation?.warningsContains = values.isEmpty ? nil : values
                store.didEditCase(id: debugCase.id)
            }
        )
    }

    private func ensureExpectation() {
        if debugCase.expectation == nil {
            debugCase.expectation = .empty
            debugCase.expectationSource = .manual
        }
    }

    private func color(for status: FieldCheckStatus) -> Color {
        switch status {
        case .pass: .green
        case .fail: .red
        case .missing: .orange
        case .ignored: .secondary
        }
    }

    private func fieldTitle(_ field: String) -> String {
        switch field {
        case "draftExists": "是否生成账单"
        case "amount": "金额"
        case "merchantEquals": "商户等于"
        case "merchantContains": "商户包含"
        case "category": "分类"
        case "source": "来源"
        case "confidence": "置信度"
        case "needsReview": "需要复核"
        case "warningsContains": "警告包含"
        default: field
        }
    }

    private func categoryExpectationTitle(_ category: TransactionCategory) -> String {
        switch category {
        case .groceries: "日用杂货 (groceries)"
        case .dining: "餐饮 (dining)"
        case .transport: "交通 (transport)"
        case .shopping: "购物 (shopping)"
        case .digital: "数字服务 (digital)"
        case .utilities: "水电燃气 (utilities)"
        case .entertainment: "娱乐 (entertainment)"
        case .other: "其他 (other)"
        }
    }
}

struct FlowTags: View {
    var values: [String]

    var body: some View {
        if values.isEmpty {
            Text("暂无自动原因")
                .foregroundStyle(.secondary)
        } else {
            HStack {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}

struct BottomActionBar: View {
    @ObservedObject var store: ReceiptDebugStore

    var body: some View {
        HStack {
            Toggle("导出原始图片/原文", isOn: $store.includeRawExports)
            Spacer()
            Button("复制调试日志", systemImage: "doc.on.clipboard") {
                store.exportDebugLog()
            }
            .disabled(store.selectedCaseID == nil)
        }
        .padding(10)
    }
}
