import Foundation

enum ReceiptSource: String, CaseIterable, Codable, Identifiable {
    case wechat
    case alipay
    case appStore
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wechat:
            return "微信支付"
        case .alipay:
            return "支付宝"
        case .appStore:
            return "App Store"
        case .manual:
            return "手动录入"
        }
    }

    var shortTitle: String {
        switch self {
        case .wechat:
            return "微信"
        case .alipay:
            return "支付宝"
        case .appStore:
            return "App Store"
        case .manual:
            return "手动"
        }
    }

    static func infer(from text: String) -> ReceiptSource {
        let normalized = text.lowercased()

        if normalized.contains("微信") || normalized.contains("wechat") {
            return .wechat
        }
        if normalized.contains("支付宝") || normalized.contains("alipay") {
            return .alipay
        }
        if normalized.contains("app store") || normalized.contains("apple") {
            return .appStore
        }

        return .manual
    }
}
