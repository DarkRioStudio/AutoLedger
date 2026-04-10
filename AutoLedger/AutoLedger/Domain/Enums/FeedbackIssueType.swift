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
        case .feedback:             return "一般反馈"
        case .ocr_parse_wrong:      return "OCR 识别错误"
        case .merchant_parse_wrong: return "商户识别错误"
        case .amount_parse_wrong:   return "金额识别错误"
        case .time_parse_wrong:     return "时间解析错误"
        case .save_failed:          return "保存失败"
        case .shortcut_flow:        return "快捷指令异常"
        case .share_extension:      return "分享导入异常"
        case .camera_import:        return "相机导入异常"
        case .clipboard_import:     return "剪切板导入异常"
        case .ui_bug:               return "界面问题"
        case .performance:          return "性能问题"
        case .crash:                return "崩溃"
        case .other:                return "其他"
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
