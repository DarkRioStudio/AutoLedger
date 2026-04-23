import Foundation

public enum ReceiptSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case wechat
    case alipay
    case appStore
    case taobao
    case eleme
    case douyin
    case unionPay
    case manual

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wechat:   return NSLocalizedString("source.wechat.title", comment: "")
        case .alipay:   return NSLocalizedString("source.alipay.title", comment: "")
        case .appStore: return NSLocalizedString("source.app_store.title", comment: "")
        case .taobao:   return NSLocalizedString("source.taobao.title", comment: "")
        case .eleme:    return NSLocalizedString("source.eleme.title", comment: "")
        case .douyin:   return NSLocalizedString("source.douyin.title", comment: "")
        case .unionPay: return NSLocalizedString("source.union_pay.title", comment: "")
        case .manual:   return NSLocalizedString("source.manual.title", comment: "")
        }
    }

    public var shortTitle: String {
        switch self {
        case .wechat:   return NSLocalizedString("source.wechat.short", comment: "")
        case .alipay:   return NSLocalizedString("source.alipay.short", comment: "")
        case .appStore: return NSLocalizedString("source.app_store.short", comment: "")
        case .taobao:   return NSLocalizedString("source.taobao.short", comment: "")
        case .eleme:    return NSLocalizedString("source.eleme.short", comment: "")
        case .douyin:   return NSLocalizedString("source.douyin.short", comment: "")
        case .unionPay: return NSLocalizedString("source.union_pay.short", comment: "")
        case .manual:   return NSLocalizedString("source.manual.short", comment: "")
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
        // 抖音团购券码页：含"待使用"加"券号"或"适用门店"
        if normalized.contains("待使用") && (normalized.contains("券号") || normalized.contains("适用门店")) {
            return .douyin
        }
        let paymentDetailKeywords = ["交易详情", "交易成功", "付款成功", "支付成功", "订单详情",
                                     "付款记录", "支付金额", "交易金额", "商户名称", "商户名"]
        let looksLikePaymentDetail = paymentDetailKeywords.contains { normalized.contains($0.lowercased()) }
        if normalized.contains("云闪付")
            || ((normalized.contains("银联") || normalized.contains("unionpay")) && looksLikePaymentDetail) {
            return .unionPay
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
