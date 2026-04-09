import Foundation

public enum ReceiptSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case wechat
    case alipay
    case appStore
    case taobao
    case eleme
    case manual

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wechat:   return "微信支付"
        case .alipay:   return "支付宝"
        case .appStore: return "App Store"
        case .taobao:   return "淘宝"
        case .eleme:    return "饿了么"
        case .manual:   return "手动录入"
        }
    }

    public var shortTitle: String {
        switch self {
        case .wechat:   return "微信"
        case .alipay:   return "支付宝"
        case .appStore: return "App Store"
        case .taobao:   return "淘宝"
        case .eleme:    return "饿了么"
        case .manual:   return "手动"
        }
    }

    public static func infer(from text: String) -> ReceiptSource {
        let normalized = text.lowercased()

        // Apple 收据优先
        if normalized.contains("app store") || normalized.contains("apple") {
            return .appStore
        }
        // 外卖/电商平台优先于支付渠道
        if normalized.contains("淘宝") || normalized.contains("闪购") || normalized.contains("taobao") {
            return .taobao
        }
        if normalized.contains("饿了么") || normalized.contains("eleme") {
            return .eleme
        }
        if normalized.contains("微信") || normalized.contains("wechat")
            || normalized.contains("收单机构") || normalized.contains("商户单号") {
            return .wechat
        }
        if normalized.contains("支付宝") || normalized.contains("alipay") {
            return .alipay
        }

        return .manual
    }
}
