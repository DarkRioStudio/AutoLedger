import Foundation

enum FeedbackIssueType: String, CaseIterable, Identifiable {
    case feedback
    case ocr_parse_wrong
    case merchant_parse_wrong
    case amount_parse_wrong
    case time_parse_wrong
    case save_failed
    case shortcut_flow
    case share_extension
    case camera_import
    case clipboard_import
    case ui_bug
    case performance
    case crash
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feedback:             return String(localized: "feedback.issue.feedback")
        case .ocr_parse_wrong:      return String(localized: "feedback.issue.ocr_parse_wrong")
        case .merchant_parse_wrong: return String(localized: "feedback.issue.merchant_parse_wrong")
        case .amount_parse_wrong:   return String(localized: "feedback.issue.amount_parse_wrong")
        case .time_parse_wrong:     return String(localized: "feedback.issue.time_parse_wrong")
        case .save_failed:          return String(localized: "feedback.issue.save_failed")
        case .shortcut_flow:        return String(localized: "feedback.issue.shortcut_flow")
        case .share_extension:      return String(localized: "feedback.issue.share_extension")
        case .camera_import:        return String(localized: "feedback.issue.camera_import")
        case .clipboard_import:     return String(localized: "feedback.issue.clipboard_import")
        case .ui_bug:               return String(localized: "feedback.issue.ui_bug")
        case .performance:          return String(localized: "feedback.issue.performance")
        case .crash:                return String(localized: "feedback.issue.crash")
        case .other:                return String(localized: "feedback.issue.other")
        }
    }

    var icon: String {
        switch self {
        case .feedback:             return "bubble.left"
        case .ocr_parse_wrong:      return "eye.trianglebadge.exclamationmark"
        case .merchant_parse_wrong: return "person.crop.circle.badge.exclamationmark"
        case .amount_parse_wrong:   return "yensign.circle"
        case .time_parse_wrong:     return "clock.badge.exclamationmark"
        case .save_failed:          return "externaldrive.badge.xmark"
        case .shortcut_flow:        return "bolt.trianglebadge.exclamationmark"
        case .share_extension:      return "square.and.arrow.up.trianglebadge.exclamationmark"
        case .camera_import:        return "camera.badge.ellipsis"
        case .clipboard_import:     return "doc.on.clipboard"
        case .ui_bug:               return "rectangle.badge.xmark"
        case .performance:          return "gauge.with.dots.needle.33percent"
        case .crash:                return "xmark.octagon"
        case .other:                return "questionmark.circle"
        }
    }
}
