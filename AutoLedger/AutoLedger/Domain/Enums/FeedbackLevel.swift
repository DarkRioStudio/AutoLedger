import Foundation

enum FeedbackLevel: String, CaseIterable, Identifiable {
    case L1
    case L2
    case L3

    var id: String { rawValue }

    var title: String {
        switch self {
        case .L1: return String(localized: "feedback.level.l1.title")
        case .L2: return String(localized: "feedback.level.l2.title")
        case .L3: return String(localized: "feedback.level.l3.title")
        }
    }

    var subtitle: String {
        switch self {
        case .L1: return String(localized: "feedback.level.l1.subtitle")
        case .L2: return String(localized: "feedback.level.l2.subtitle")
        case .L3: return String(localized: "feedback.level.l3.subtitle")
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
