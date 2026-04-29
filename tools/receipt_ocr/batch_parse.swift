import Foundation

struct OCRRecord: Decodable {
    let id: String
    let ocrText: String
    let minConfidence: Float?
    let error: String?
}

struct ParseRecord: Encodable {
    let id: String
    let amount: Double?
    let merchant: String?
    let category: String?
    let confidence: String
    let needsReview: Bool
    let warnings: [String]
    let debugTrace: [String]
}

@main
struct BatchParse {
    static func main() throws {
        guard CommandLine.arguments.count >= 3 else {
            FileHandle.standardError.write(Data("Usage: batch_parse <ocr.jsonl> <parse.jsonl>\n".utf8))
            exit(2)
        }

        let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let input = try String(contentsOf: inputURL, encoding: .utf8)
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let interpreter = LedgerTextInterpreterCore()

        let outputLines = try input
            .split(separator: "\n")
            .map { line -> String in
                let record = try decoder.decode(OCRRecord.self, from: Data(line.utf8))
                let result = interpreter.interpret(
                    InterpretInput(
                        rawText: record.ocrText,
                        sourceType: .ocr,
                        hints: LedgerInterpretHints(sourceHint: .receipt)
                    )
                )
                let parsed = ParseRecord(
                    id: record.id,
                    amount: result.draft?.amount,
                    merchant: result.draft?.merchant,
                    category: result.draft?.category,
                    confidence: result.confidence.rawValue,
                    needsReview: result.needsReview,
                    warnings: result.warnings.map(\.rawValue),
                    debugTrace: result.debugTrace
                )
                return String(decoding: try encoder.encode(parsed), as: UTF8.self)
            }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try outputLines.joined(separator: "\n").appending("\n").write(to: outputURL, atomically: true, encoding: .utf8)
        print("Wrote \(outputLines.count) parse records to \(outputURL.path)")
    }
}
