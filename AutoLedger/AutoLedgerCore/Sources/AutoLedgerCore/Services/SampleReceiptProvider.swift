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
        SampleReceipt(
            title: "支付宝碰一下支付截图（7-11）",
            source: .alipay,
            rawText: """
            08:48
            ：！⑤
            回首页
            支付成功
            ¥4.30
            获得森林能量（20g）
            Example Convenience Store
            付款方式
            ¥4.80
            -¥0.50
            Example Bank Card (1234)
            碰一下支付
            便捷 安全优惠
            """,
            preview: "Example Convenience Store · ¥4.30"
        ),
        SampleReceipt(
            title: "抖音团购麦当劳截图",
            source: .douyin,
            rawText: """
            12:34
            89
            经验 直播 团购 天津 精）
            天津，Demo Burger团购 目
            搜索
            订单
            99
            00
            更多
            × 待使用
            6
            客服
            请在 2026.04.24（含）前到店消费
            门店自取时，请注意选择正确的【取餐门店】 和【预⋯＞
            小食任意搭4件套
            B
            【一人食】Demo Burger小食任意＞
            搭2+2【小食趴专属】【...
            ¥44
            ×1
            实付 ¥26.90〉
            周一至周日10:30-次日05:00可用•过期自动退•免预约＞
            方式1
            到店验券
            方式2
            自助使用
            券号 MCD64P00201RX.＞复制
            查看详细步骤＞
            适用门店（6673家）
            U 直播中
            Demo Burger (Example Branch)
            营业中 06:30-23:00
            最近273m
            • 河西区郁江道14号
            全部门店＞
            1
            6g
            交易快照
            可作为交易争执的判断依据
            申请退款
            再来一单
            """,
            preview: "Demo Burger (Example Branch)· ¥26.90"
        ),
    ]
}
