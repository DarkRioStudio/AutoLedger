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
        SampleReceipt(
            title: "天津地铁储值卡截图",
            source: .manual,
            rawText: """
            18:15
            S ［WIP］ Add method to retrieve
            TestFlight invitation link
            正在进行•智能体正在运行
            View Session
            现在
            支
            消费成功通知
            你的储值消费成功，查看详情>
            现在
            天津互联互通城市卡
            地铁：
            CN¥2.70
            ExampleStationA ExampleStationB
            你的新余额为CN¥67.75。
            现在
            Dungeon Escape st...
            Escape the depths to reach the
            Ultimate Reward！
            13分钟前
            大家都在问
            17分钟前
            救护车截单致抢救延误，院前急救
            响应机制如何优化才更可靠？
            Hosen Ryan
            近期照片
            详情。使用花呗支付，请及时还款。
            """,
            preview: "地铁：ExampleStationA → ExampleStationB · CN¥2.70"
        ),
    ]
}
