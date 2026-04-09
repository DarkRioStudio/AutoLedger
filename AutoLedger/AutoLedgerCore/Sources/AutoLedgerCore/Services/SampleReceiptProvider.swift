import Foundation

public protocol SampleReceiptProviding: Sendable {
    var samples: [SampleReceipt] { get }
}

public struct SampleReceiptProvider: SampleReceiptProviding {
    public init() {}

    public let samples: [SampleReceipt] = [
        SampleReceipt(
            title: "微信买菜截图",
            source: .wechat,
            rawText: """
            微信支付
            支付成功
            收款方：Example Supermarket
            支付金额：¥86.30
            交易时间：2026-03-26 19:42
            备注：生鲜采购
            """,
            preview: "Example Supermarket · ¥86.30 · 2026-03-26 19:42"
        ),
        SampleReceipt(
            title: "支付宝出行截图",
            source: .alipay,
            rawText: """
            支付宝
            交易成功
            商户：滴滴出行
            金额：￥23.80
            时间：2026/03/25 08:10
            备注：通勤打车
            """,
            preview: "滴滴出行 · ￥23.80 · 2026/03/25 08:10"
        ),
        SampleReceipt(
            title: "App Store 订阅截图",
            source: .appStore,
            rawText: """
            App Store
            Apple Services
            Total CNY 28.00
            Date 2026-03-22 12:14
            Subscription: iCloud+
            """,
            preview: "Apple Services · CNY 28.00 · 2026-03-22 12:14"
        ),
    ]
}
