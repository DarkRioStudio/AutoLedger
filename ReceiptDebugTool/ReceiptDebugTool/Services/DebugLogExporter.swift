import AutoLedgerCore
import Foundation

struct DebugLogExporter {
    func exportCurrentCase(_ debugCase: ReceiptDebugCase, includeRaw: Bool) throws -> DebugExportSummary {
        try export(
            cases: [debugCase],
            includeRaw: includeRaw,
            directoryPrefix: "receipt-debug-current-\(Self.safePathComponent(debugCase.id))"
        )
    }

    func clipboardDebugLog(for debugCase: ReceiptDebugCase, includeRaw: Bool) -> String {
        ledgerInterpreterDebugMarkdown(for: debugCase, includeRaw: includeRaw)
    }

    func export(cases: [ReceiptDebugCase], includeRaw: Bool) throws -> DebugExportSummary {
        try export(cases: cases, includeRaw: includeRaw, directoryPrefix: "receipt-debug-log")
    }

    private func export(cases: [ReceiptDebugCase], includeRaw: Bool, directoryPrefix: String) throws -> DebugExportSummary {
        let stamp = Self.stampFormatter.string(from: Date())
        let directory = RuntimePaths.defaultOutputDirectory
            .appendingPathComponent("\(directoryPrefix)-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(cases).write(to: directory.appendingPathComponent("cases.json"), options: [.atomic])

        try writeJSONL(cases.map { RedactedOCRRecord($0) }, to: directory.appendingPathComponent("redacted_ocr.jsonl"))
        try writeJSONL(cases.map { ParseRecord($0) }, to: directory.appendingPathComponent("parse.jsonl"))
        try writeJSONL(cases.flatMap { debugCase in debugCase.fieldDiffs.map { DiffRecord(caseID: debugCase.id, diff: $0) } }, to: directory.appendingPathComponent("diffs.jsonl"))
        try redactedDebugMarkdown(for: cases).write(to: directory.appendingPathComponent("redacted_debug.md"), atomically: true, encoding: .utf8)
        if cases.count == 1, let debugCase = cases.first {
            try ledgerInterpreterDebugMarkdown(for: debugCase, includeRaw: false)
                .write(to: directory.appendingPathComponent("ledger_interpreter_debug.md"), atomically: true, encoding: .utf8)
            try encoder.encode(LedgerInterpreterDebugRecord(debugCase, includeRaw: false))
                .write(to: directory.appendingPathComponent("ledger_interpreter_debug.json"), options: [.atomic])
        }

        let goldenURL = directory.appendingPathComponent("golden_candidates.jsonl")
        try GoldenCaseWriter().writeCandidates(from: cases, to: goldenURL)
        try summary(for: cases).write(to: directory.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)

        if includeRaw {
            let rawDirectory = directory.appendingPathComponent("private_raw", isDirectory: true)
            try FileManager.default.createDirectory(at: rawDirectory, withIntermediateDirectories: true)
            try writeJSONL(cases.map { RawOCRRecord($0) }, to: rawDirectory.appendingPathComponent("private_raw_ocr.jsonl"))
            try rawDebugMarkdown(for: cases).write(to: rawDirectory.appendingPathComponent("private_raw_debug.md"), atomically: true, encoding: .utf8)
            if cases.count == 1, let debugCase = cases.first {
                try ledgerInterpreterDebugMarkdown(for: debugCase, includeRaw: true)
                    .write(to: rawDirectory.appendingPathComponent("private_ledger_interpreter_debug.md"), atomically: true, encoding: .utf8)
                try encoder.encode(LedgerInterpreterDebugRecord(debugCase, includeRaw: true))
                    .write(to: rawDirectory.appendingPathComponent("private_ledger_interpreter_debug.json"), options: [.atomic])
            }
            for debugCase in cases {
                let destination = rawDirectory.appendingPathComponent(debugCase.id + "-" + debugCase.originalFileName)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: debugCase.imageURL, to: destination)
            }
        }

        return DebugExportSummary(directory: directory, goldenURL: goldenURL)
    }

    private func writeJSONL<T: Encodable>(_ records: [T], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let lines = try records.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
        try lines.joined(separator: "\n").appending(lines.isEmpty ? "" : "\n")
            .write(to: url, atomically: true, encoding: .utf8)
    }

    private func summary(for cases: [ReceiptDebugCase]) -> String {
        let ocrSuccess = cases.filter { $0.ocrError == nil && !$0.ocrTextOriginal.isEmpty }.count
        let parsed = cases.filter { $0.parseResult != nil }.count
        let nonBill = cases.filter { $0.testStatus == .nonBill }.count
        let obvious = cases.filter(\.isObviousError).count
        let diffs = cases.flatMap(\.fieldDiffs)
        let counts = Dictionary(grouping: diffs, by: \.status).mapValues(\.count)
        let warnings = Dictionary(grouping: cases.flatMap { $0.parseResult?.warnings.map(\.rawValue) ?? [] }, by: { $0 }).mapValues(\.count)
        let topWarnings = warnings.sorted { $0.value > $1.value }.map { "- \($0.key): \($0.value)" }.joined(separator: "\n")
        let failed = cases.filter { $0.fieldDiffs.contains { $0.status == .fail || $0.status == .missing } }
            .map { "- \($0.id) \($0.originalFileName)" }
            .joined(separator: "\n")

        return """
        # Receipt Debug Summary

        - Images: \(cases.count)
        - OCR success: \(ocrSuccess)
        - Parsed: \(parsed)
        - Non bill: \(nonBill)
        - Obvious errors: \(obvious)
        - Diff pass: \(counts[.pass] ?? 0)
        - Diff fail: \(counts[.fail] ?? 0)
        - Diff missing: \(counts[.missing] ?? 0)
        - Diff ignored: \(counts[.ignored] ?? 0)

        ## Top Warnings

        \(topWarnings.isEmpty ? "None" : topWarnings)

        ## Failed Samples

        \(failed.isEmpty ? "None" : failed)
        """
    }

    private func rawDebugMarkdown(for cases: [ReceiptDebugCase]) -> String {
        cases.map { debugCase in
            """
            ## \(debugCase.id)

            \(debugCase.ocrTextOriginal)
            """
        }.joined(separator: "\n\n")
    }

    private func redactedDebugMarkdown(for cases: [ReceiptDebugCase]) -> String {
        cases.map { debugCase in
            """
            ## \(debugCase.id)

            Status: \(debugCase.testStatus.rawValue)

            \(debugCase.redactedText)
            """
        }.joined(separator: "\n\n")
    }

    private func ledgerInterpreterDebugMarkdown(for debugCase: ReceiptDebugCase, includeRaw: Bool) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let resultJSON = debugCase.parseResult
            .flatMap { try? String(decoding: encoder.encode($0), as: UTF8.self) }
            ?? "null"
        let expectationJSON = debugCase.expectation
            .flatMap { try? String(decoding: encoder.encode($0), as: UTF8.self) }
            ?? "null"
        let text = includeRaw ? debugCase.activeOCRText : debugCase.redactedText
        let textTitle = includeRaw ? "Active OCR Text" : "Redacted OCR Text"
        let parsedAt = debugCase.parsedAt.map(Self.isoFormatter.string(from:)) ?? "-"
        let meanConfidence = debugCase.ocrMeanConfidence.map { String($0) } ?? "-"
        let sourceType = debugCase.sourceType.rawValue
        let sourceHint = debugCase.sourceHint.rawValue

        var lines: [String] = []
        lines.append("# LedgerTextInterpreterCore Debug")
        lines.append("")
        lines.append("## Case")
        lines.append("")
        lines.append("- ID: \(debugCase.id)")
        lines.append("- File: \(debugCase.originalFileName)")
        lines.append("- Status: \(debugCase.testStatus.rawValue)")
        lines.append("- Source type: \(sourceType)")
        lines.append("- Source hint: \(sourceHint)")
        lines.append("- OCR lines: \(debugCase.ocrLineCount)")
        lines.append("- OCR mean confidence: \(meanConfidence)")
        lines.append("- Parsed at: \(parsedAt)")
        lines.append("")
        lines.append("## Reproduction Input")
        lines.append("")
        lines.append("```swift")
        lines.append("LedgerTextInterpreterCore().interpret(")
        lines.append("    InterpretInput(")
        lines.append("        rawText: \"\"\"")
        lines.append(text)
        lines.append("        \"\"\",")
        lines.append("        sourceType: LedgerInputSourceType(rawValue: \"\(sourceType)\") ?? .ocr,")
        lines.append("        hints: LedgerInterpretHints(sourceHint: LedgerSourceHint(rawValue: \"\(sourceHint)\") ?? .unknown)")
        lines.append("    )")
        lines.append(")")
        lines.append("```")
        lines.append("")
        lines.append("## \(textTitle)")
        lines.append("")
        lines.append("```text")
        lines.append(text)
        lines.append("```")
        lines.append("")
        lines.append("## Parse Result")
        lines.append("")
        lines.append("```json")
        lines.append(resultJSON)
        lines.append("```")
        lines.append("")
        lines.append("## Expected Snapshot")
        lines.append("")
        lines.append("```json")
        lines.append(expectationJSON)
        lines.append("```")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct RedactedOCRRecord: Encodable {
    var id: String
    var originalFileName: String
    var imagePathHash: String
    var imageContentHash: String
    var width: Int?
    var height: Int?
    var ocrText: String
    var minConfidence: Float?
    var meanConfidence: Float?
    var lineCount: Int
    var durationMs: Int?
    var error: String?

    init(_ debugCase: ReceiptDebugCase) {
        id = debugCase.id
        originalFileName = debugCase.originalFileName
        imagePathHash = debugCase.imagePathHash
        imageContentHash = debugCase.imageContentHash
        width = debugCase.imageWidth
        height = debugCase.imageHeight
        ocrText = debugCase.redactedText
        minConfidence = debugCase.ocrMinConfidence
        meanConfidence = debugCase.ocrMeanConfidence
        lineCount = debugCase.ocrLineCount
        durationMs = debugCase.ocrDurationMs
        error = debugCase.ocrError
    }
}

private struct RawOCRRecord: Encodable {
    var id: String
    var originalFileName: String
    var ocrText: String

    init(_ debugCase: ReceiptDebugCase) {
        id = debugCase.id
        originalFileName = debugCase.originalFileName
        ocrText = debugCase.ocrTextOriginal
    }
}

private struct ParseRecord: Encodable {
    var id: String
    var result: InterpretResult?

    init(_ debugCase: ReceiptDebugCase) {
        id = debugCase.id
        result = debugCase.parseResult
    }
}

private struct DiffRecord: Encodable {
    var caseID: String
    var diff: FieldDiff
}

private struct LedgerInterpreterDebugRecord: Encodable {
    var id: String
    var originalFileName: String
    var sourceType: String
    var sourceHint: String
    var ocrText: String
    var ocrTextKind: String
    var parseResult: InterpretResult?
    var expectation: GoldenExpectation?
    var fieldDiffs: [FieldDiff]
    var obviousErrorReasons: [String]

    init(_ debugCase: ReceiptDebugCase, includeRaw: Bool) {
        id = debugCase.id
        originalFileName = debugCase.originalFileName
        sourceType = debugCase.sourceType.rawValue
        sourceHint = debugCase.sourceHint.rawValue
        ocrText = includeRaw ? debugCase.activeOCRText : debugCase.redactedText
        ocrTextKind = includeRaw ? "rawActiveOCR" : "redactedOCR"
        parseResult = debugCase.parseResult
        expectation = debugCase.expectation
        fieldDiffs = debugCase.fieldDiffs
        obviousErrorReasons = debugCase.obviousErrorReasons.map(\.rawValue)
    }
}
