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
            title: "微信支付详情个体工商户跨行截图",
            source: .wechat,
            rawText: """
            16:42
            Example Mini Market
            等17万+人喜欢
            3喜欢
            小程序
            会员日88折〉
            服务
            会员
            门店
            • 交易详情
            一
            -6.15
            Example Mini Market
            当前状态
            支付时间
            商品
            商户全称
            收单机构
            支付方式
            交易单号
            商户单号
            支付成功
            2026年04月13日 16:42:09
            示例便利店
            示例便利店商贸有限公司
            Example Acquiring Services Co.
            Example Bank Card (1234)
            ORDER-EXAMPLE-WECHAT-001
            MERCHANT-ORDER-001
            可在支持的商户扫码退款
            """,
            preview: "示例便利店商贸有限公司 · ¥6.15 · 2026-04-13 16:42:09"
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
            title: "互联互通城市卡CN¥嵌入格式截图",
            source: .manual,
            rawText: """
            14:47
            63
            现在
            支
            消费成功通知
            你的储值消费成功，查看详情>
            天津互联互通城市卡
            地铁：CN¥7.00
            ExampleAirport - ExampleEastStation
            你的新余额为 CN¥60.75。
            现在
            通知中心
            X
            周六2
            11
            乘坐列车G000次Example East Station..•30分钟后
            交通严重拥堵。经德胜快速路前往
            Example East Station需要19分钟。
            3
            小红书
            PLUS抽签购权益过期提醒
            1分钟前
            您有一份原价飞飞天茅台的抽签权益
            即将过期，请尽快查看，若已参与
            请忽略>
            收获一个新的赞
            【陈槿琪】点赞了你的弹幕，快来看
            看吧>
            1分钟前
            小鸡毛烫不烫啊
            160
            下雨
            20° ＄15°
            可
            """,
            preview: "地铁：ExampleAirport → ExampleEastStation · CN¥7.00"
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
            title: "抖音团购示例汉堡截图",
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
        SampleReceipt(
            title: "滴滴出行结束订单截图",
            source: .manual,
            rawText: """
            09:11
            ＜ 行程已给束
            ：！！⑦9
            您对我的服务满意吗？
            示例司机 EX-0001 5.0分
            匿名
            发红包
            很糟糕
            一般般
            太赞了
            ¥19.60 优惠-¥490
            费用明细〉
            终
            河东区
            京津塘高速
            公 收藏路线
            特惠快车 全程12.57公里 12分钟
            里桯值 +12.57
            • 08:52 Example Start School
            • 09:05 Example Airport Pickup（步行导航＞
            匿名反馈墻
            ；494.3万+人参与中
            司机是否有打电话玩手机等行为？
            是
            否
            ：
            曰
            开发票
            联系客服
            呼叫司机
            呼叫返程
            再来一单
            """,
            preview: "滴滴出行 · ¥19.60"
        ),
        SampleReceipt(
            title: "滴滴出行通知截图",
            source: .manual,
            rawText: """
            Example Carrier
            39
            4月11日周六，丙午年二月廿四
            SAMPLE-NOTIFICATION-ID
            滴滴
            已支付9.70元
            感谢使用滴滴出行，低碳出行每一天
            通知中心
            请确认
            您购买的商品将在24小时后确
            认收货，请确认是否已收到，如
            有问题可延长收货或联系商家，
            查看>>
            UnionPay
            半付一下： 显 不必何从 怀示，
            还可抽最高620元大奖！
            现在
            >14°
            微雨
            个18° 14°
            ◎
            """,
            preview: "滴滴出行 · ¥9.70"
        ),
        SampleReceipt(
            title: "滴滴出行优享出租车截图",
            source: .manual,
            rawText: """
            15:59
            ＜ 行程已给束
            71
            您对我的服务满意吗？
            示例司机 EX-0002 4.5分
            匿名
            发红包
            很糟糕
            一般般
            太赞了
            445
            9.0L
            费用明细〉
            起
            终
            收藏路线
            优享出租车|全程12.3公里 23分钟
            • 15:30 Example Resort Gate
            • 15:54 Example Hotel（步行导航＞
            里程值 +12.3
            平台提供信息技术服务，运输服务提供方为个体出租车
            匿名反馈
            69.6万+人参与中
            本次接驾车辆的车牌号与订单显示是否一致？
            不一致
            一致
            6
            呼叫返程
            联系客服 呼叫司机 功能反馈
            再来一单
            """,
            preview: "滴滴出行 · ¥45.00"
        ),
        SampleReceipt(
            title: "滴滴出行微信扣费凭证截图",
            source: .wechat,
            rawText: """
            17:44
            69
            微信支付
            收支
            查看明细
            日报设置
            17:41
            • 滴滴出行
            扣费凭证
            通过Example Bank Card (1234)扣款
            ¥24.90
            按时支付，记入微信支付分记录
            扣费服务
            扣费内容
            滴滴出行
            先乘车后付款
            查看订单详情
            我的账单
            支付服务
            摇优惠
            """,
            preview: "滴滴出行 · ¥24.90"
        ),
        SampleReceipt(
            title: "支付宝示例汉堡支付成功截图",
            source: .alipay,
            rawText: """
            18:20
            ：！
            回首页
            支付成功
            ¥60.80
            Demo Burger Restaurant
            付款方式
            ¥60.80
            Example Bank Card (1234)〉
            加入粉丝群享专属福利
            0元
            可口可乐中杯特价0.
            满15元可用
            入群领
            支付有礼|支付宝点餐更优惠
            食神卡
            你有0.13元点餐优惠待使用
            查看更多优惠
            去查看
            淘宝闪购
            支付宝下单可享
            去领取
            """,
            preview: "Demo Burger Restaurant · ¥60.80"
        ),
        SampleReceipt(
            title: "淘宝闪购订单进行中截图",
            source: .taobao,
            rawText: """
            19:46
            个 骑士正赶往商家
            13
            •••
            客服
            改订单信息
            联系商家
            联系骑士
            催单
            取消订单
            更多
            下单返 本单可计入
            ¥12
            外卖红包
            下1单，返12元外卖红包
            ） 本周还有20元免单卡可返
            立即领取
            闪购
            肉嫩酥麻
            Sample Restaurant（Example Branch）＞
            经典遗软骨
            价格明细丶
            总优惠¥23.5
            共2件
            实付¥47.4
            备注
            联系不上时
            订单号
            订单信息
            依据餐量提供餐具 修改
            可设置暂存点放置外卖|设置
            ORDER-EXAMPLE-TAOBAO-001
            复制
            常见问题
            忘记备注怎么催单
            怎么退单
            """,
            preview: "Sample Restaurant（Example Branch）· ¥47.40"
        ),
        SampleReceipt(
            title: "微信支付全部账单截图（7-11）",
            source: .wechat,
            rawText: """
            18:18
            ×
            •1 66
            全部账单
            UELEVEN
            Example Convenience
            -16.80
            当前状态
            支付时间
            商品
            商户全称
            收单机构
            支付方式
            交易单号
            商户单号
            支付成功
            2026年4月20日18:17:58
            Example Store Branch
            Example Convenience Store
            财付通支付科技有限公司
            Example Bank Card (1234)
            ORDER-EXAMPLE-WECHAT-002
            MERCHANT-ORDER-002
            可在支持的商户扫码退款
            MERCHANT-REF-EXAMPLE-002
            """,
            preview: "Example Convenience Store · ¥16.80 · 2026-04-20 18:17:58"
        ),
        SampleReceipt(
            title: "云闪付付款成功截图",
            source: .unionPay,
            rawText: """
            云闪付
            付款成功
            支付金额
            ¥18.60
            商户名称
            示例咖啡（Example Station）
            交易时间
            2026-04-20 08:32:10
            付款方式
            Example Bank Card (1234)
            订单号
            ORDER-EXAMPLE-UNIONPAY-001
            """,
            preview: "示例咖啡（Example Station）· ¥18.60 · 2026-04-20 08:32:10"
        ),
        SampleReceipt(
            title: "云闪付账单详情截图",
            source: .unionPay,
            rawText: """
            13:17
            •11 ⑥53
            <
            账单详情
            Sample Restaurant（Example Branch）
            -13.52
            交易成功
            订单金额
            碰一下立減
            支付时间
            付款方式
            商品说明
            支付奖励
            收单机构
            清算机构
            收款方全称
            推荐服务
            13.58
            -0.06
            2026-04-21 18:46:58
            Example Bank Card (1234)＞
            Example Checkout Service
            v 立即领取1积分
            北京钱袋宝支付技术有限公司
            中国银联股份有限公司
            Sample Noodle House Service Center
            点击查看今日可用信用卡优惠
            更多～去查看〉账单管理
            你因这笔消费解锁了"吃顿饭"贴纸
            账单分类餐饮美食〉
            """,
            preview: "Sample Restaurant（Example Branch）· ¥13.52 · 2026-04-21 18:46:58"
        ),
        SampleReceipt(
            title: "银联二维码支付详情截图",
            source: .unionPay,
            rawText: """
            中国银联
            交易详情
            交易成功
            商户名称：示例便利店（Example Road）
            交易金额：¥12.80
            交易时间：2026/04/21 20:15:33
            支付方式
            云闪付二维码
            参考号
            REF-EXAMPLE-001
            """,
            preview: "示例便利店（Example Road）· ¥12.80 · 2026-04-21 20:15:33"
        ),
        SampleReceipt(
            title: "微信支付全部账单截图（羊汤）",
            source: .wechat,
            rawText: """
            08:13
            ④2
            全部账单
            示例餐厅
            -20.00
            当前状态
            支付时间
            商品
            商户全称
            收单机构
            支付方式
            交易单号
            商户单号
            支付成功
            2026年5月4日 07:03:35
            示例餐厅个体店
            （8285）
            示例餐厅个体店
            Example Acquiring Services Co.
            Example Bank Card (1234)
            ORDER-EXAMPLE-WECHAT-003
            MERCHANT-ORDER-003
            MERCHANT-REF-EXAMPLE-003
            商家小程序
            〇掌银收银台＞
            账单服务
            """,
            preview: "示例餐厅 · ¥20.00 · 2026-05-04 07:03:35"
        ),
        SampleReceipt(
            title: "英文超市纸质小票TOTAL",
            source: .manual,
            rawText: """
            NTUC FAIRPRICE
            100 AM STREET
            SINGAPORE
            FRESH MILK        2.00
            BREAD             3.20
            APPLES            7.10
            SUBTOTAL         12.30
            GST               0.00
            TOTAL SGD 12.30
            23/04/2026 18:02
            """,
            preview: "NTUC FAIRPRICE · SGD 12.30"
        ),
        SampleReceipt(
            title: "英文超市纸质小票无TOTAL",
            source: .manual,
            rawText: """
            WALMART
            450 MARKET ST
            FRESH MILK        2.00
            BREAD             3.20
            APPLES            7.10
            CASHIER 12
            04/23/2026 18:02
            """,
            preview: "WALMART · total missing"
        ),
    ]
}
