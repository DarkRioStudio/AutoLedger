import Foundation

struct GoldenCase: Decodable {
    let id: String
    let engine: GoldenEngine?
    let sampleTitle: String?
    let rawText: String?
    let sourceType: LedgerInputSourceType?
    let localeIdentifier: String?
    let receiptSource: ReceiptSource?
    let sourceHint: LedgerSourceHint?
    let expected: Expected
}

enum GoldenEngine: String, Decodable {
    case core
    case receiptParser
}

struct Expected: Decodable {
    let draftExists: Bool?
    let amount: Double?
    let amountTolerance: Double?
    let merchantEquals: String?
    let merchantContains: String?
    let category: String?
    let source: String?
    let confidence: String?
    let needsReview: Bool?
    let warningsContains: [String]?
}

struct Failure {
    let id: String
    let message: String
}

struct PayloadError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

@main
struct GoldenRegression {
    struct ReceiptPayload {
        let rawText: String
        let source: ReceiptSource
    }

    static func main() throws {
        let casesPath = CommandLine.arguments.dropFirst().first ?? "tests/golden/ledger_text_interpreter/cases.jsonl"
        let casesURL = URL(fileURLWithPath: casesPath)
        let contents = try String(contentsOf: casesURL, encoding: .utf8)
        let decoder = JSONDecoder()
        let coreInterpreter = LedgerTextInterpreterCore()
        let receiptParser = ReceiptParser()
        let samplesByTitle = Dictionary(
            uniqueKeysWithValues: SampleReceiptProvider().samples.map { ($0.title, $0) }
        )
        var failures: [Failure] = []
        var count = 0

        for line in contents.split(separator: "\n") {
            count += 1
            let testCase = try decoder.decode(GoldenCase.self, from: Data(line.utf8))
            switch testCase.engine ?? .core {
            case .core:
                switch resolveCorePayload(testCase, samplesByTitle: samplesByTitle) {
                case .success(let input):
                    let result = coreInterpreter.interpret(input)
                    failures.append(contentsOf: validate(testCase, result: result))
                case .failure(let error):
                    failures.append(Failure(id: testCase.id, message: error.description))
                }
            case .receiptParser:
                switch resolveReceiptPayload(testCase, samplesByTitle: samplesByTitle) {
                case .success(let input):
                    let receipt = receiptParser.parse(text: input.rawText, source: input.source)
                    failures.append(contentsOf: validate(testCase, receipt: receipt))
                case .failure(let error):
                    failures.append(Failure(id: testCase.id, message: error.description))
                }
            }
        }

        if failures.isEmpty {
            print("Golden regression passed: \(count) case(s).")
            return
        }

        print("Golden regression failed: \(failures.count) issue(s) in \(count) case(s).")
        for failure in failures {
            print("- [\(failure.id)] \(failure.message)")
        }
        exit(1)
    }

    static func resolveCorePayload(
        _ testCase: GoldenCase,
        samplesByTitle: [String: SampleReceipt]
    ) -> Result<InterpretInput, PayloadError> {
        if let sampleTitle = testCase.sampleTitle {
            guard let sample = samplesByTitle[sampleTitle] else {
                return .failure(PayloadError("sampleTitle '\(sampleTitle)' was not found"))
            }
            return .success(
                InterpretInput(
                    rawText: sample.rawText,
                    sourceType: testCase.sourceType ?? .ocr,
                    localeIdentifier: testCase.localeIdentifier,
                    hints: LedgerInterpretHints(sourceHint: testCase.sourceHint ?? .unknown)
                )
            )
        }

        guard let rawText = testCase.rawText else {
            return .failure(PayloadError("rawText is required for core engine unless sampleTitle is provided"))
        }
        guard let sourceType = testCase.sourceType else {
            return .failure(PayloadError("sourceType is required for core engine unless sampleTitle is provided"))
        }
        return .success(
            InterpretInput(
                rawText: rawText,
                sourceType: sourceType,
                localeIdentifier: testCase.localeIdentifier,
                hints: LedgerInterpretHints(sourceHint: testCase.sourceHint ?? .unknown)
            )
        )
    }

    static func resolveReceiptPayload(
        _ testCase: GoldenCase,
        samplesByTitle: [String: SampleReceipt]
    ) -> Result<ReceiptPayload, PayloadError> {
        if let sampleTitle = testCase.sampleTitle {
            guard let sample = samplesByTitle[sampleTitle] else {
                return .failure(PayloadError("sampleTitle '\(sampleTitle)' was not found"))
            }
            return .success(ReceiptPayload(rawText: sample.rawText, source: sample.source))
        }

        guard let rawText = testCase.rawText else {
            return .failure(PayloadError("rawText is required for receiptParser engine unless sampleTitle is provided"))
        }
        return .success(ReceiptPayload(rawText: rawText, source: testCase.receiptSource ?? .manual))
    }

    static func validate(_ testCase: GoldenCase, result: InterpretResult) -> [Failure] {
        var failures: [Failure] = []
        let expected = testCase.expected
        let draft = result.draft

        func fail(_ message: String) {
            failures.append(Failure(id: testCase.id, message: message))
        }

        if let draftExists = expected.draftExists, (draft != nil) != draftExists {
            fail("draftExists expected \(draftExists), got \(draft != nil)")
        }

        if let amount = expected.amount {
            let tolerance = expected.amountTolerance ?? 0.01
            guard let actual = draft?.amount else {
                fail("amount expected \(amount), got nil")
                return failures
            }
            if abs(actual - amount) > tolerance {
                fail("amount expected \(amount), got \(actual)")
            }
        }

        if let merchant = expected.merchantEquals, draft?.merchant != merchant {
            fail("merchant expected '\(merchant)', got '\(draft?.merchant ?? "nil")'")
        }

        if let merchantContains = expected.merchantContains,
           draft?.merchant.localizedCaseInsensitiveContains(merchantContains) != true {
            fail("merchant expected to contain '\(merchantContains)', got '\(draft?.merchant ?? "nil")'")
        }

        if let category = expected.category, draft?.category != category {
            fail("category expected '\(category)', got '\(draft?.category ?? "nil")'")
        }

        if let source = expected.source, draft?.sourceType.rawValue != source {
            fail("source expected '\(source)', got '\(draft?.sourceType.rawValue ?? "nil")'")
        }

        if let confidence = expected.confidence, result.confidence.rawValue != confidence {
            fail("confidence expected '\(confidence)', got '\(result.confidence.rawValue)'")
        }

        if let needsReview = expected.needsReview, result.needsReview != needsReview {
            fail("needsReview expected \(needsReview), got \(result.needsReview)")
        }

        if let warnings = expected.warningsContains {
            let actual = Set(result.warnings.map(\.rawValue))
            for warning in warnings where !actual.contains(warning) {
                fail("warnings expected to contain '\(warning)', got \(Array(actual).sorted())")
            }
        }

        return failures
    }

    static func validate(_ testCase: GoldenCase, receipt: ImportedReceipt?) -> [Failure] {
        var failures: [Failure] = []
        let expected = testCase.expected

        func fail(_ message: String) {
            failures.append(Failure(id: testCase.id, message: message))
        }

        if let draftExists = expected.draftExists, (receipt != nil) != draftExists {
            fail("draftExists expected \(draftExists), got \(receipt != nil)")
        }

        if let amount = expected.amount {
            let tolerance = expected.amountTolerance ?? 0.01
            guard let actual = receipt?.amount else {
                fail("amount expected \(amount), got nil")
                return failures
            }
            if abs(actual - amount) > tolerance {
                fail("amount expected \(amount), got \(actual)")
            }
        }

        if let merchant = expected.merchantEquals, receipt?.merchant != merchant {
            fail("merchant expected '\(merchant)', got '\(receipt?.merchant ?? "nil")'")
        }

        if let merchantContains = expected.merchantContains,
           receipt?.merchant.localizedCaseInsensitiveContains(merchantContains) != true {
            fail("merchant expected to contain '\(merchantContains)', got '\(receipt?.merchant ?? "nil")'")
        }

        if let category = expected.category, receipt?.suggestedCategory.rawValue != category {
            fail("category expected '\(category)', got '\(receipt?.suggestedCategory.rawValue ?? "nil")'")
        }

        if let source = expected.source, receipt?.source.rawValue != source {
            fail("source expected '\(source)', got '\(receipt?.source.rawValue ?? "nil")'")
        }

        return failures
    }
}
