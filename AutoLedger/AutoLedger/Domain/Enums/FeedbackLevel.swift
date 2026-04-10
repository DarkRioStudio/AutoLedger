import Foundation

enum FeedbackLevel: String, CaseIterable, Identifiable {
    case L1
    case L2
    case L3

    var id: String { rawValue }

    var title: String {
        switch self {
        case .L1: return "L1 标准反馈"
        case .L2: return "L2 增强调试"
        case .L3: return "L3 完整诊断"
        }
    }

    var subtitle: String {
        switch self {
        case .L1: return "脱敏日志，不含原始截图和 OCR 原文"
        case .L2: return "含脱敏 OCR 上下文和解析轨迹"
        case .L3: return "含完整 OCR 原文和可选截图（需二次确认）"
        }
    }

    var containsRedactedOCR: Bool { self >= .L2 }
    var containsFullOCR: Bool { self == .L3 }
    var containsTrace: Bool { self >= .L2 }
    var containsRawImage: Bool { self == .L3 }
}

extension FeedbackLevel: Comparable {
    static func < (lhs: FeedbackLevel, rhs: FeedbackLevel) -> Bool {
        let order: [FeedbackLevel] = [.L1, .L2, .L3]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}
