import AutoLedgerCore
import Foundation

struct ReceiptDebugComparator {
    static func compare(expectation: GoldenExpectation?, result: InterpretResult?) -> [FieldDiff] {
        guard let expectation else { return [] }
        var diffs: [FieldDiff] = []
        let draft = result?.draft

        appendBool(&diffs, field: "draftExists", expected: expectation.draftExists, actual: draft != nil)
        appendDouble(&diffs, field: "amount", expected: expectation.amount, actual: draft?.amount, tolerance: expectation.amountTolerance ?? 0.01)
        appendString(&diffs, field: "merchantEquals", expected: expectation.merchantEquals, actual: draft?.merchant, mode: .equals)
        appendString(&diffs, field: "merchantContains", expected: expectation.merchantContains, actual: draft?.merchant, mode: .contains)
        appendString(&diffs, field: "category", expected: expectation.category, actual: draft?.category, mode: .equals)
        appendString(&diffs, field: "source", expected: expectation.source, actual: draft?.sourceType.rawValue, mode: .equals)
        appendString(&diffs, field: "confidence", expected: expectation.confidence, actual: result?.confidence.rawValue, mode: .equals)
        appendBool(&diffs, field: "needsReview", expected: expectation.needsReview, actual: result?.needsReview)

        if let expectedWarnings = expectation.warningsContains {
            let actual = Set(result?.warnings.map(\.rawValue) ?? [])
            for warning in expectedWarnings {
                diffs.append(
                    FieldDiff(
                        field: "warningsContains",
                        expected: warning,
                        actual: actual.sorted().joined(separator: ", "),
                        status: actual.contains(warning) ? .pass : .fail
                    )
                )
            }
        }

        return diffs
    }

    static func obviousErrors(for debugCase: ReceiptDebugCase) -> [ObviousErrorReason] {
        var reasons: [ObviousErrorReason] = []
        let text = debugCase.activeOCRText.lowercased()
        let warnings = Set(debugCase.parseResult?.warnings.map(\.rawValue) ?? [])
        let hasBillSignal = ["¥", "￥", "$", "total", "合计", "支付", "交易", "金额"].contains { text.contains($0.lowercased()) }

        if debugCase.parseResult?.draft == nil && hasBillSignal {
            reasons.append(.missingAmount)
        }
        if warnings.contains("missingReliableTotal") {
            reasons.append(.totalNotFound)
        }
        if let merchant = debugCase.parseResult?.draft?.merchant.lowercased() {
            let itemWords = ["milk", "bread", "fresh milk", "牛奶", "面包"]
            if itemWords.contains(where: { merchant.contains($0) }) {
                reasons.append(.merchantFromItemName)
            }
        }
        return reasons
    }

    private enum StringMode {
        case equals
        case contains
    }

    private static func appendBool(_ diffs: inout [FieldDiff], field: String, expected: Bool?, actual: Bool?) {
        guard let expected else {
            diffs.append(FieldDiff(field: field, expected: "", actual: "", status: .ignored))
            return
        }
        guard let actual else {
            diffs.append(FieldDiff(field: field, expected: String(expected), actual: "nil", status: .missing))
            return
        }
        diffs.append(FieldDiff(field: field, expected: String(expected), actual: String(actual), status: expected == actual ? .pass : .fail))
    }

    private static func appendDouble(_ diffs: inout [FieldDiff], field: String, expected: Double?, actual: Double?, tolerance: Double) {
        guard let expected else {
            diffs.append(FieldDiff(field: field, expected: "", actual: "", status: .ignored))
            return
        }
        guard let actual else {
            diffs.append(FieldDiff(field: field, expected: "\(expected)", actual: "nil", status: .missing))
            return
        }
        let status: FieldCheckStatus = abs(expected - actual) <= tolerance ? .pass : .fail
        diffs.append(FieldDiff(field: field, expected: "\(expected)", actual: "\(actual)", status: status))
    }

    private static func appendString(_ diffs: inout [FieldDiff], field: String, expected: String?, actual: String?, mode: StringMode) {
        guard let expected, !expected.isEmpty else {
            diffs.append(FieldDiff(field: field, expected: "", actual: "", status: .ignored))
            return
        }
        guard let actual, !actual.isEmpty else {
            diffs.append(FieldDiff(field: field, expected: expected, actual: "nil", status: .missing))
            return
        }
        let passes = mode == .equals ? actual == expected : actual.localizedCaseInsensitiveContains(expected)
        diffs.append(FieldDiff(field: field, expected: expected, actual: actual, status: passes ? .pass : .fail))
    }
}
