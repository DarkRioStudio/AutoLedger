import AppKit
import AutoLedgerCore
import CryptoKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ReceiptDebugStore: ObservableObject {
    @Published var cases: [ReceiptDebugCase] = []
    @Published var selectedCaseID: String?
    @Published var statusMessage = "就绪"
    @Published var includeRawExports = false
    @Published var isWorking = false

    private let ocrService = ReceiptOCRService()
    private let parser = ReceiptDebugParser()
    private let redactor = ReceiptTextRedactor()
    private let writer = GoldenCaseWriter()
    private let validator = GoldenCaseValidator()
    private let exporter = DebugLogExporter()

    var selectedCase: ReceiptDebugCase? {
        guard let selectedCaseID else { return nil }
        return cases.first { $0.id == selectedCaseID }
    }

    func clearSession() {
        cases.removeAll()
        selectedCaseID = nil
        statusMessage = "已清空当前会话"
    }

    func importProviders(_ providers: [NSItemProvider]) async {
        let urls = await fileURLs(from: providers)
        await importURLs(urls)
    }

    func importURLs(_ urls: [URL]) async {
        isWorking = true
        defer { isWorking = false }

        let imageURLs = urls.flatMap { imageFiles(from: $0) }
        var imported = 0

        for url in imageURLs {
            do {
                let debugCase = try makeCase(from: url)
                if !cases.contains(where: { $0.id == debugCase.id }) {
                    cases.append(debugCase)
                    imported += 1
                }
            } catch {
                statusMessage = "导入失败：\(url.lastPathComponent)，\(error.localizedDescription)"
            }
        }

        if selectedCaseID == nil {
            selectedCaseID = cases.first?.id
        }
        statusMessage = "已导入 \(imported) 张图片"
    }

    func refreshOCRForSelectionOrAll() async {
        let targetIDs = selectedCaseID.map { [$0] } ?? cases.map(\.id)
        await refreshOCR(caseIDs: targetIDs)
    }

    func refreshOCR(caseIDs: [String]) async {
        isWorking = true
        defer { isWorking = false }

        for id in caseIDs {
            guard let index = cases.firstIndex(where: { $0.id == id }) else { continue }
            let url = cases[index].imageURL
            do {
                let output = try await ocrService.recognize(url: url)
                cases[index].ocrTextOriginal = output.text
                cases[index].ocrTextEdited = nil
                cases[index].redactedText = redactor.redact(output.text)
                cases[index].ocrMinConfidence = output.minConfidence
                cases[index].ocrMeanConfidence = output.meanConfidence
                cases[index].ocrLineCount = output.lineCount
                cases[index].ocrDurationMs = output.durationMs
                cases[index].imageWidth = output.width
                cases[index].imageHeight = output.height
                cases[index].ocrError = nil
                cases[index].testStatus = .ocrReady
                recomputeCaseState(at: index)
            } catch {
                cases[index].ocrError = error.localizedDescription
                cases[index].testStatus = .failed
            }
        }

        statusMessage = "已刷新 \(caseIDs.count) 个样本的 OCR 文本"
    }

    func refreshParseForSelectionOrAll() {
        let targetIDs = selectedCaseID.map { [$0] } ?? cases.filter { !$0.activeOCRText.isEmpty }.map(\.id)
        refreshParse(caseIDs: targetIDs)
    }

    func refreshParse(caseIDs: [String]) {
        for id in caseIDs {
            guard let index = cases.firstIndex(where: { $0.id == id }) else { continue }
            let result = parser.parse(cases[index])
            cases[index].parseResult = result
            cases[index].parsedAt = Date()
            cases[index].redactedText = redactor.redact(cases[index].activeOCRText)
            cases[index].testStatus = result.warnings.contains(.nonBillImage) ? .nonBill : .parsed
            recomputeCaseState(at: index)
        }
        statusMessage = "已解析 \(caseIDs.count) 个样本"
    }

    func fillExpectationFromParse(for id: String) {
        guard let index = cases.firstIndex(where: { $0.id == id }),
              let result = cases[index].parseResult else { return }

        if let draft = result.draft {
            cases[index].expectation = GoldenExpectation(
                draftExists: true,
                amount: draft.amount,
                amountTolerance: 0.01,
                merchantEquals: draft.merchant,
                merchantContains: nil,
                category: draft.category,
                source: nil,
                confidence: nil,
                needsReview: nil,
                warningsContains: nil
            )
        } else {
            cases[index].expectation = GoldenExpectation(
                draftExists: false,
                amount: nil,
                amountTolerance: nil,
                merchantEquals: nil,
                merchantContains: nil,
                category: nil,
                source: nil,
                confidence: result.confidence.rawValue,
                needsReview: result.needsReview,
                warningsContains: result.warnings.map(\.rawValue)
            )
        }
        cases[index].expectationSource = .parseSnapshot
        cases[index].testStatus = .expectedReady
        recomputeCaseState(at: index)
    }

    func applyNonBillExpectation(for id: String) {
        guard let index = cases.firstIndex(where: { $0.id == id }) else { return }
        cases[index].expectation = GoldenExpectation(
            draftExists: false,
            amount: nil,
            amountTolerance: nil,
            merchantEquals: nil,
            merchantContains: nil,
            category: nil,
            source: nil,
            confidence: "low",
            needsReview: true,
            warningsContains: ["nonBillImage"]
        )
        cases[index].expectationSource = .manual
        recomputeCaseState(at: index)
    }

    func toggleObviousReason(_ reason: ObviousErrorReason, for id: String) {
        guard let index = cases.firstIndex(where: { $0.id == id }) else { return }
        if cases[index].obviousErrorReasons.contains(reason) {
            cases[index].obviousErrorReasons.removeAll { $0 == reason }
        } else {
            cases[index].obviousErrorReasons.append(reason)
        }
        cases[index].isObviousError = !cases[index].obviousErrorReasons.isEmpty
    }

    func didEditCase(id: String) {
        guard let index = cases.firstIndex(where: { $0.id == id }) else { return }
        cases[index].redactedText = redactor.redact(cases[index].activeOCRText)
        recomputeCaseState(at: index)
    }

    func exportGoldenCandidates() async {
        isWorking = true
        defer { isWorking = false }

        let outputURL = RuntimePaths.defaultOutputDirectory.appendingPathComponent("golden_candidates.jsonl")
        do {
            let candidates = cases.filter { $0.expectation != nil }
            try writer.writeCandidates(from: candidates, to: outputURL)
            let validationOutput = try validator.validate(candidatesURL: outputURL)
            for index in cases.indices where cases[index].expectation != nil {
                cases[index].testStatus = .goldenCandidate
            }
            statusMessage = "Golden 候选已导出并验证通过：\(validationOutput.trimmingCharacters(in: .whitespacesAndNewlines))"
        } catch {
            for index in cases.indices where cases[index].expectation != nil {
                cases[index].testStatus = .validatorFailed
            }
            statusMessage = "Golden 导出或验证失败：\(error.localizedDescription)"
        }
    }

    func exportDebugLog() {
        guard let selectedCaseID,
              let index = cases.firstIndex(where: { $0.id == selectedCaseID }) else {
            statusMessage = "请先选择一个条目再导出调试日志"
            return
        }

        if !cases[index].activeOCRText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let result = parser.parse(cases[index])
            cases[index].parseResult = result
            cases[index].parsedAt = Date()
            cases[index].redactedText = redactor.redact(cases[index].activeOCRText)
            cases[index].testStatus = result.warnings.contains(.nonBillImage) ? .nonBill : .parsed
            recomputeCaseState(at: index)
        }

        let log = exporter.clipboardDebugLog(for: cases[index], includeRaw: includeRawExports)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(log, forType: .string)
        statusMessage = "当前条目调试日志已复制到剪切板"
    }

    private func recomputeCaseState(at index: Int) {
        cases[index].fieldDiffs = ReceiptDebugComparator.compare(expectation: cases[index].expectation, result: cases[index].parseResult)
        let automatic = ReceiptDebugComparator.obviousErrors(for: cases[index])
        let combined = cases[index].obviousErrorReasons + automatic.filter { !cases[index].obviousErrorReasons.contains($0) }
        cases[index].obviousErrorReasons = combined
        cases[index].isObviousError = !cases[index].obviousErrorReasons.isEmpty || cases[index].fieldDiffs.contains { $0.status == .fail || $0.status == .missing }

        if cases[index].expectation != nil && !cases[index].fieldDiffs.isEmpty {
            cases[index].testStatus = .compared
        }
    }

    private func makeCase(from url: URL) throws -> ReceiptDebugCase {
        let data = try Data(contentsOf: url)
        let contentHash = sha256(data)
        let id = "\(sanitized(url.deletingPathExtension().lastPathComponent))-\(contentHash.prefix(12))"
        let image = NSImage(contentsOf: url)
        let size = image?.representations.first

        return ReceiptDebugCase(
            id: id,
            originalFileName: url.lastPathComponent,
            imageURL: url,
            securityScopedBookmarkData: nil,
            imagePathHash: stableHash(url.path),
            imageContentHash: contentHash,
            imageWidth: size?.pixelsWide,
            imageHeight: size?.pixelsHigh,
            importedAt: Date(),
            ocrTextOriginal: "",
            ocrTextEdited: nil,
            redactedText: "",
            ocrMinConfidence: nil,
            ocrMeanConfidence: nil,
            ocrLineCount: 0,
            ocrDurationMs: nil,
            ocrError: nil,
            sourceType: .ocr,
            sourceHint: .unknown,
            parseResult: nil,
            parsedAt: nil,
            expectation: nil,
            expectationSource: .manual,
            testStatus: .imported,
            fieldDiffs: [],
            isObviousError: false,
            obviousErrorReasons: []
        )
    }

    private func imageFiles(from url: URL) -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }

        if !isDirectory.boolValue {
            return isSupportedImage(url) ? [url] : []
        }

        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey])
        return (enumerator?.compactMap { $0 as? URL }.filter(isSupportedImage) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func isSupportedImage(_ url: URL) -> Bool {
        ["jpg", "jpeg", "png", "heic", "tif", "tiff"].contains(url.pathExtension.lowercased())
    }

    private func fileURLs(from providers: [NSItemProvider]) async -> [URL] {
        await withTaskGroup(of: URL?.self) { group in
            for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.addTask {
                    await withCheckedContinuation { continuation in
                        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                            if let data = item as? Data {
                                continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
                            } else if let url = item as? URL {
                                continuation.resume(returning: url)
                            } else {
                                continuation.resume(returning: nil)
                            }
                        }
                    }
                }
            }

            var urls: [URL] = []
            for await url in group {
                if let url {
                    urls.append(url)
                }
            }
            return urls
        }
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func stableHash(_ value: String) -> String {
        String(value.unicodeScalars.reduce(UInt64(1469598103934665603)) { hash, scalar in
            (hash ^ UInt64(scalar.value)) &* 1099511628211
        }, radix: 16)
    }

    private func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .lowercased()
    }
}
