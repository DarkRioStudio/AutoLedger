import Foundation

enum ImportDebugStage: String, CaseIterable, Identifiable {
    case ocrFailed
    case parseFailed
    case duplicateSkipped
    case persisted
    case persistenceFailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ocrFailed:
            return "OCR 失败"
        case .parseFailed:
            return "解析失败"
        case .duplicateSkipped:
            return "重复跳过"
        case .persisted:
            return "已入账"
        case .persistenceFailed:
            return "落盘失败"
        }
    }
}

struct ImportDebugRecord: Identifiable {
    let id = UUID()
    let createdAt: Date
    let stage: ImportDebugStage
    let source: ReceiptSource
    let rawText: String
    let parsedReceipt: ImportedReceipt?
    let summary: String
}
