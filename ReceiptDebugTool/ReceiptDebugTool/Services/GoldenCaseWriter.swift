import Foundation

struct GoldenCaseWriter {
    func writeCandidates(from cases: [ReceiptDebugCase], to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let lines = try cases.compactMap { debugCase -> String? in
            guard let expectation = debugCase.expectation else { return nil }
            let record = GoldenCandidateRecord(
                id: "receipt_debug_\(debugCase.id)",
                rawText: debugCase.redactedText,
                sourceType: debugCase.sourceType.rawValue,
                sourceHint: debugCase.sourceHint.rawValue,
                expected: expectation
            )
            return String(decoding: try encoder.encode(record), as: UTF8.self)
        }

        try lines.joined(separator: "\n").appending(lines.isEmpty ? "" : "\n")
            .write(to: outputURL, atomically: true, encoding: .utf8)
    }
}
