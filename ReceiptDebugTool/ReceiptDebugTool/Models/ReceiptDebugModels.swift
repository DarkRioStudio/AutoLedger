import AutoLedgerCore
import Foundation

enum ReceiptDebugStatus: String, Codable, CaseIterable {
    case imported
    case ocrReady
    case parsed
    case expectedReady
    case compared
    case goldenCandidate
    case validatorFailed
    case nonBill
    case failed
}

enum FieldCheckStatus: String, Codable {
    case pass
    case fail
    case missing
    case ignored
}

enum ExpectationSource: String, Codable {
    case manual
    case parseSnapshot
    case importedGolden
    case llmDraft
}

enum ObviousErrorReason: String, Codable, CaseIterable, Identifiable {
    case amountFromItemPrice
    case merchantFromItemName
    case totalNotFound
    case missingAmount
    case nonBillMisclassified
    case dateMisread
    case categoryWrong
    case other

    var id: String { rawValue }
}

struct GoldenExpectation: Codable, Equatable {
    var draftExists: Bool?
    var amount: Double?
    var amountTolerance: Double?
    var merchantEquals: String?
    var merchantContains: String?
    var category: String?
    var source: String?
    var confidence: String?
    var needsReview: Bool?
    var warningsContains: [String]?

    static let empty = GoldenExpectation()
}

struct FieldDiff: Identifiable, Codable, Equatable {
    var id: String { field }
    var field: String
    var expected: String
    var actual: String
    var status: FieldCheckStatus
}

struct ReceiptDebugCase: Identifiable, Codable {
    var id: String
    var originalFileName: String
    var imageURL: URL
    var securityScopedBookmarkData: Data?
    var imagePathHash: String
    var imageContentHash: String
    var imageWidth: Int?
    var imageHeight: Int?
    var importedAt: Date

    var ocrTextOriginal: String
    var ocrTextEdited: String?
    var redactedText: String
    var ocrMinConfidence: Float?
    var ocrMeanConfidence: Float?
    var ocrLineCount: Int
    var ocrDurationMs: Int?
    var ocrError: String?

    var sourceType: LedgerInputSourceType
    var sourceHint: LedgerSourceHint
    var parseResult: InterpretResult?
    var parsedAt: Date?

    var expectation: GoldenExpectation?
    var expectationSource: ExpectationSource
    var testStatus: ReceiptDebugStatus
    var fieldDiffs: [FieldDiff]
    var isObviousError: Bool
    var obviousErrorReasons: [ObviousErrorReason]

    var activeOCRText: String {
        let edited = ocrTextEdited?.trimmingCharacters(in: .whitespacesAndNewlines)
        return edited?.isEmpty == false ? edited! : ocrTextOriginal
    }
}

struct GoldenCandidateRecord: Codable {
    var id: String
    var rawText: String
    var sourceType: String
    var sourceHint: String
    var expected: GoldenExpectation
}

struct DebugExportSummary {
    var directory: URL
    var goldenURL: URL
}

extension ReceiptDebugStatus {
    var title: String {
        switch self {
        case .imported: "已导入"
        case .ocrReady: "OCR 完成"
        case .parsed: "已解析"
        case .expectedReady: "期望已填"
        case .compared: "已对比"
        case .goldenCandidate: "Golden 候选"
        case .validatorFailed: "验证失败"
        case .nonBill: "非账单"
        case .failed: "失败"
        }
    }
}

extension FieldCheckStatus {
    var title: String {
        switch self {
        case .pass: "通过"
        case .fail: "失败"
        case .missing: "缺失"
        case .ignored: "忽略"
        }
    }
}

extension ObviousErrorReason {
    var title: String {
        switch self {
        case .amountFromItemPrice: "金额取成单品价格"
        case .merchantFromItemName: "商户取成商品名"
        case .totalNotFound: "未找到合计金额"
        case .missingAmount: "缺失金额"
        case .nonBillMisclassified: "非账单误判"
        case .dateMisread: "日期识别错误"
        case .categoryWrong: "分类错误"
        case .other: "其他"
        }
    }
}
