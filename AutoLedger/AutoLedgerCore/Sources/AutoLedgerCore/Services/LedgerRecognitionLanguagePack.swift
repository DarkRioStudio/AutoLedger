import Foundation

public enum LedgerRecognitionPackProvenance: String, Codable, Sendable, Equatable {
    case builtIn
    case builtInHotfix
    case userOverride
    case reviewedCommunity
}

public struct LedgerAmountFormat: Codable, Sendable, Equatable {
    public let currencySymbols: [String]
    public let decimalSeparator: String
    public let groupingSeparator: String?
    public let fractionDigits: Int

    public init(
        currencySymbols: [String],
        decimalSeparator: String,
        groupingSeparator: String?,
        fractionDigits: Int
    ) {
        self.currencySymbols = currencySymbols
        self.decimalSeparator = decimalSeparator
        self.groupingSeparator = groupingSeparator
        self.fractionDigits = fractionDigits
    }

    public static let generic = LedgerAmountFormat(
        currencySymbols: ["¥", "￥", "$", "€", "£", "RM"],
        decimalSeparator: ".",
        groupingSeparator: ",",
        fractionDigits: 2
    )
}

public struct LedgerAmountLabelSet: Codable, Sendable, Equatable {
    public let actualPaid: [String]
    public let total: [String]
    public let subtotal: [String]
    public let tax: [String]
    public let discount: [String]
    public let deposit: [String]
    public let refund: [String]
    public let change: [String]
    public let serviceCharge: [String]

    public init(
        actualPaid: [String] = [],
        total: [String] = [],
        subtotal: [String] = [],
        tax: [String] = [],
        discount: [String] = [],
        deposit: [String] = [],
        refund: [String] = [],
        change: [String] = [],
        serviceCharge: [String] = []
    ) {
        self.actualPaid = actualPaid
        self.total = total
        self.subtotal = subtotal
        self.tax = tax
        self.discount = discount
        self.deposit = deposit
        self.refund = refund
        self.change = change
        self.serviceCharge = serviceCharge
    }
}

public struct LedgerDateFormat: Codable, Sendable, Equatable {
    public let pattern: String
    public let example: String?

    public init(pattern: String, example: String? = nil) {
        self.pattern = pattern
        self.example = example
    }
}

public struct LedgerRecognitionLanguagePack: Codable, Sendable, Equatable {
    public let id: String
    public let schemaVersion: Int
    public let packVersion: String
    public let localeIdentifiers: [String]
    public let billKeywords: [String]
    public let paymentKeywords: [String]
    public let amountLabels: [String]
    public let totalLabels: [String]
    public let discountLabels: [String]
    public let taxLabels: [String]
    public let dateLabels: [String]
    public let merchantLabels: [String]
    public let nonMerchantKeywords: [String]
    public let categoryKeywordMap: [String: TransactionCategory]
    public let provenance: LedgerRecognitionPackProvenance
    public let amountFormat: LedgerAmountFormat
    public let amountLabelSet: LedgerAmountLabelSet
    public let dateFormats: [LedgerDateFormat]
    public let ocrRecognitionLanguages: [String]

    public init(
        id: String,
        schemaVersion: Int,
        packVersion: String,
        localeIdentifiers: [String],
        billKeywords: [String],
        paymentKeywords: [String],
        amountLabels: [String],
        totalLabels: [String],
        discountLabels: [String],
        taxLabels: [String],
        dateLabels: [String],
        merchantLabels: [String],
        nonMerchantKeywords: [String],
        categoryKeywordMap: [String: TransactionCategory],
        provenance: LedgerRecognitionPackProvenance,
        amountFormat: LedgerAmountFormat = .generic,
        amountLabelSet: LedgerAmountLabelSet? = nil,
        dateFormats: [LedgerDateFormat] = [],
        ocrRecognitionLanguages: [String] = []
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.packVersion = packVersion
        self.localeIdentifiers = localeIdentifiers
        self.billKeywords = billKeywords
        self.paymentKeywords = paymentKeywords
        self.amountLabels = amountLabels
        self.totalLabels = totalLabels
        self.discountLabels = discountLabels
        self.taxLabels = taxLabels
        self.dateLabels = dateLabels
        self.merchantLabels = merchantLabels
        self.nonMerchantKeywords = nonMerchantKeywords
        self.categoryKeywordMap = categoryKeywordMap
        self.provenance = provenance
        self.amountFormat = amountFormat
        self.amountLabelSet = amountLabelSet ?? LedgerAmountLabelSet(
            actualPaid: amountLabels,
            total: totalLabels,
            subtotal: totalLabels.filter {
                $0.localizedCaseInsensitiveContains("小计") ||
                    $0.localizedCaseInsensitiveContains("小計") ||
                    $0.localizedCaseInsensitiveContains("subtotal")
            },
            tax: taxLabels,
            discount: discountLabels
        )
        self.dateFormats = dateFormats
        self.ocrRecognitionLanguages = ocrRecognitionLanguages
    }
}

public struct LedgerRecognitionLanguagePackSet: Sendable {
    public static let builtIn = LedgerRecognitionLanguagePackSet(
        packs: [
            .builtInSimplifiedChinese,
            .builtInTraditionalChinese,
            .builtInEnglish,
            .builtInJapanese,
        ],
        fallbackPackIDs: ["en"]
    )

    public let packs: [LedgerRecognitionLanguagePack]
    public let fallbackPackIDs: [String]

    public init(packs: [LedgerRecognitionLanguagePack], fallbackPackIDs: [String] = ["en"]) {
        self.packs = packs
        self.fallbackPackIDs = fallbackPackIDs
    }

    public func packs(for localeIdentifier: String?) -> [LedgerRecognitionLanguagePack] {
        var result: [LedgerRecognitionLanguagePack] = []
        if let primary = primaryPack(for: localeIdentifier) {
            result.append(primary)
        }

        for fallbackID in fallbackPackIDs {
            guard !result.contains(where: { $0.id == fallbackID }),
                  let fallback = packs.first(where: { $0.id == fallbackID }) else {
                continue
            }
            result.append(fallback)
        }

        if result.isEmpty, let first = packs.first {
            result.append(first)
        }
        return result
    }

    public func mergedPack(for localeIdentifier: String?) -> LedgerRecognitionLanguagePack? {
        let chain = packs(for: localeIdentifier)
        guard let first = chain.first else { return nil }

        return LedgerRecognitionLanguagePack(
            id: first.id,
            schemaVersion: chain.map(\.schemaVersion).max() ?? first.schemaVersion,
            packVersion: first.packVersion,
            localeIdentifiers: unique(chain.flatMap(\.localeIdentifiers)),
            billKeywords: unique(chain.flatMap(\.billKeywords)),
            paymentKeywords: unique(chain.flatMap(\.paymentKeywords)),
            amountLabels: unique(chain.flatMap(\.amountLabels)),
            totalLabels: unique(chain.flatMap(\.totalLabels)),
            discountLabels: unique(chain.flatMap(\.discountLabels)),
            taxLabels: unique(chain.flatMap(\.taxLabels)),
            dateLabels: unique(chain.flatMap(\.dateLabels)),
            merchantLabels: unique(chain.flatMap(\.merchantLabels)),
            nonMerchantKeywords: unique(chain.flatMap(\.nonMerchantKeywords)),
            categoryKeywordMap: mergedCategoryMap(chain),
            provenance: first.provenance,
            amountFormat: first.amountFormat,
            amountLabelSet: mergedAmountLabelSet(chain),
            dateFormats: uniqueDateFormats(chain.flatMap(\.dateFormats)),
            ocrRecognitionLanguages: unique(chain.flatMap(\.ocrRecognitionLanguages))
        )
    }

    public func ocrRecognitionLanguages(for localeIdentifier: String?) -> [String] {
        mergedPack(for: localeIdentifier)?.ocrRecognitionLanguages ?? []
    }

    private func primaryPack(for localeIdentifier: String?) -> LedgerRecognitionLanguagePack? {
        guard let localeIdentifier else { return nil }
        let normalized = Self.normalize(localeIdentifier)
        return packs.first { pack in
            if Self.normalize(pack.id) == normalized { return true }
            if normalized.hasPrefix(Self.normalize(pack.id) + "-") { return true }
            return pack.localeIdentifiers.contains { candidate in
                let normalizedCandidate = Self.normalize(candidate)
                return normalizedCandidate == normalized || normalized.hasPrefix(normalizedCandidate + "-")
            }
        }
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let key = value.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(value)
        }
        return result
    }

    private func mergedCategoryMap(_ packs: [LedgerRecognitionLanguagePack]) -> [String: TransactionCategory] {
        packs.reduce(into: [:]) { partial, pack in
            for (keyword, category) in pack.categoryKeywordMap where partial[keyword] == nil {
                partial[keyword] = category
            }
        }
    }

    private func mergedAmountLabelSet(_ packs: [LedgerRecognitionLanguagePack]) -> LedgerAmountLabelSet {
        LedgerAmountLabelSet(
            actualPaid: unique(packs.flatMap(\.amountLabelSet.actualPaid)),
            total: unique(packs.flatMap(\.amountLabelSet.total)),
            subtotal: unique(packs.flatMap(\.amountLabelSet.subtotal)),
            tax: unique(packs.flatMap(\.amountLabelSet.tax)),
            discount: unique(packs.flatMap(\.amountLabelSet.discount)),
            deposit: unique(packs.flatMap(\.amountLabelSet.deposit)),
            refund: unique(packs.flatMap(\.amountLabelSet.refund)),
            change: unique(packs.flatMap(\.amountLabelSet.change)),
            serviceCharge: unique(packs.flatMap(\.amountLabelSet.serviceCharge))
        )
    }

    private func uniqueDateFormats(_ values: [LedgerDateFormat]) -> [LedgerDateFormat] {
        var seen = Set<String>()
        var result: [LedgerDateFormat] = []
        for value in values {
            guard !seen.contains(value.pattern) else { continue }
            seen.insert(value.pattern)
            result.append(value)
        }
        return result
    }

    private static func normalize(_ localeIdentifier: String) -> String {
        localeIdentifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }
}

public extension LedgerRecognitionLanguagePack {
    static let builtInSimplifiedChinese = LedgerRecognitionLanguagePack(
        id: "zh-Hans",
        schemaVersion: 2,
        packVersion: "1.0.0",
        localeIdentifiers: ["zh", "zh-Hans", "zh-CN", "zh-SG"],
        billKeywords: [
            "付款成功", "支付成功", "交易成功", "交易详情", "订单详情", "账单", "小票",
            "发票", "收据", "合计", "总计", "总额", "实付", "付款金额", "支付金额"
        ],
        paymentKeywords: ["微信支付", "支付宝", "云闪付", "银联", "银行卡", "信用卡", "付款方式"],
        amountLabels: ["金额", "实付", "支付金额", "付款金额", "交易金额"],
        totalLabels: ["合计", "总计", "总金额", "总额", "小计", "应付", "实付"],
        discountLabels: ["优惠", "折扣", "立减", "满减"],
        taxLabels: ["税", "税费", "增值税"],
        dateLabels: ["时间", "交易时间", "付款时间", "账单日期"],
        merchantLabels: ["商户", "商户名称", "收款方", "店铺", "门店"],
        nonMerchantKeywords: [
            "订单号", "交易单号", "流水号", "验证码", "广告", "发票号", "终端号",
            "房号", "收银员", "税号", "纳税人识别号", "会员号"
        ],
        categoryKeywordMap: [
            "星巴克": .dining,
            "咖啡": .dining,
            "便利店": .groceries,
            "超市": .groceries,
            "滴滴": .transport,
            "地铁": .transport,
            "公交": .transport,
            "app store": .digital,
        ],
        provenance: .builtIn,
        amountFormat: LedgerAmountFormat(
            currencySymbols: ["¥", "￥", "CNY", "RMB"],
            decimalSeparator: ".",
            groupingSeparator: ",",
            fractionDigits: 2
        ),
        amountLabelSet: LedgerAmountLabelSet(
            actualPaid: ["金额", "实付", "支付金额", "付款金额", "交易金额"],
            total: ["合计", "总计", "总金额", "总额", "应付", "实付"],
            subtotal: ["小计"],
            tax: ["税", "税费", "增值税"],
            discount: ["优惠", "折扣", "立减", "满减"],
            deposit: ["押金", "保证金", "预授权"],
            refund: ["退款", "退货", "返还"],
            change: ["找零", "找回"],
            serviceCharge: ["服务费"]
        ),
        dateFormats: [
            LedgerDateFormat(pattern: "yyyy-MM-dd", example: "2026-06-25"),
            LedgerDateFormat(pattern: "yyyy/MM/dd", example: "2026/06/25"),
            LedgerDateFormat(pattern: "yyyy年M月d日", example: "2026年6月25日"),
        ],
        ocrRecognitionLanguages: ["zh-Hans", "en-US"]
    )

    static let builtInTraditionalChinese = LedgerRecognitionLanguagePack(
        id: "zh-Hant",
        schemaVersion: 2,
        packVersion: "1.0.0",
        localeIdentifiers: ["zh-Hant", "zh-TW", "zh-HK", "zh-MO"],
        billKeywords: [
            "付款成功", "支付成功", "交易成功", "交易詳情", "訂單詳情", "帳單", "小票",
            "發票", "收據", "合計", "總計", "總額", "實付", "付款金額", "支付金額"
        ],
        paymentKeywords: ["微信支付", "支付寶", "雲閃付", "銀聯", "銀行卡", "信用卡", "付款方式"],
        amountLabels: ["金額", "實付", "支付金額", "付款金額", "交易金額"],
        totalLabels: ["合計", "總計", "總金額", "總額", "小計", "應付", "實付"],
        discountLabels: ["優惠", "折扣", "立減", "滿減"],
        taxLabels: ["稅", "稅費", "營業稅"],
        dateLabels: ["時間", "交易時間", "付款時間", "帳單日期"],
        merchantLabels: ["商戶", "商戶名稱", "收款方", "店鋪", "門店"],
        nonMerchantKeywords: [
            "訂單號", "交易單號", "流水號", "驗證碼", "廣告", "發票號", "終端號",
            "房號", "收銀員", "稅號", "會員號"
        ],
        categoryKeywordMap: [
            "星巴克": .dining,
            "咖啡": .dining,
            "便利店": .groceries,
            "超市": .groceries,
            "地鐵": .transport,
            "公交": .transport,
            "app store": .digital,
        ],
        provenance: .builtIn,
        amountFormat: LedgerAmountFormat(
            currencySymbols: ["NT$", "HK$", "MOP$", "¥", "￥"],
            decimalSeparator: ".",
            groupingSeparator: ",",
            fractionDigits: 2
        ),
        amountLabelSet: LedgerAmountLabelSet(
            actualPaid: ["金額", "實付", "支付金額", "付款金額", "交易金額"],
            total: ["合計", "總計", "總金額", "總額", "應付", "實付"],
            subtotal: ["小計"],
            tax: ["稅", "稅費", "營業稅"],
            discount: ["優惠", "折扣", "立減", "滿減"],
            deposit: ["押金", "保證金", "預授權"],
            refund: ["退款", "退貨", "返還"],
            change: ["找零", "找回"],
            serviceCharge: ["服務費"]
        ),
        dateFormats: [
            LedgerDateFormat(pattern: "yyyy-MM-dd", example: "2026-06-25"),
            LedgerDateFormat(pattern: "yyyy/MM/dd", example: "2026/06/25"),
            LedgerDateFormat(pattern: "yyyy年M月d日", example: "2026年6月25日"),
        ],
        ocrRecognitionLanguages: ["zh-Hant", "en-US"]
    )

    static let builtInEnglish = LedgerRecognitionLanguagePack(
        id: "en",
        schemaVersion: 2,
        packVersion: "1.0.0",
        localeIdentifiers: ["en", "en-US", "en-GB", "en-SG", "en-MY"],
        billKeywords: [
            "receipt", "invoice", "tax invoice", "payment", "paid", "transaction", "order",
            "total", "grand total", "subtotal", "amount", "amount due", "cashier", "tax"
        ],
        paymentKeywords: ["visa", "mastercard", "amex", "card", "cash", "apple pay", "google pay", "paypal"],
        amountLabels: ["amount", "paid", "payment amount", "amount due", "total due"],
        totalLabels: ["total", "grand total", "subtotal", "amount due", "total due", "total sales"],
        discountLabels: ["discount", "coupon", "promotion"],
        taxLabels: ["tax", "gst", "vat", "service charge"],
        dateLabels: ["date", "time", "transaction time", "invoice date"],
        merchantLabels: ["merchant", "store", "shop", "seller", "cashier"],
        nonMerchantKeywords: [
            "order no", "invoice no", "receipt#", "ref no", "advertisement", "terminal no",
            "room no", "room number", "cashier", "tax id", "vat no", "member no"
        ],
        categoryKeywordMap: [
            "mcdonald": .dining,
            "starbucks": .dining,
            "kfc": .dining,
            "fairprice": .groceries,
            "supermarket": .groceries,
            "grab": .transport,
            "uber": .transport,
            "app store": .digital,
            "netflix": .digital,
        ],
        provenance: .builtIn,
        amountFormat: LedgerAmountFormat(
            currencySymbols: ["$", "US$", "S$", "£", "RM"],
            decimalSeparator: ".",
            groupingSeparator: ",",
            fractionDigits: 2
        ),
        amountLabelSet: LedgerAmountLabelSet(
            actualPaid: ["amount", "paid", "payment amount", "amount due", "total due"],
            total: ["total", "grand total", "amount due", "total due", "total sales"],
            subtotal: ["subtotal", "sub total"],
            tax: ["tax", "gst", "vat"],
            discount: ["discount", "coupon", "promotion"],
            deposit: ["deposit", "preauth", "pre-authorization"],
            refund: ["refund", "return"],
            change: ["change", "change due"],
            serviceCharge: ["service charge"]
        ),
        dateFormats: [
            LedgerDateFormat(pattern: "yyyy-MM-dd", example: "2026-06-25"),
            LedgerDateFormat(pattern: "MM/dd/yyyy", example: "06/25/2026"),
            LedgerDateFormat(pattern: "dd/MM/yyyy", example: "25/06/2026"),
        ],
        ocrRecognitionLanguages: ["en-US"]
    )

    static let builtInJapanese = LedgerRecognitionLanguagePack(
        id: "ja",
        schemaVersion: 2,
        packVersion: "1.0.0",
        localeIdentifiers: ["ja", "ja-JP"],
        billKeywords: [
            "領収書", "レシート", "請求書", "お買上げ", "お買い上げ", "合計", "小計",
            "支払金額", "お支払い", "支払い", "税込", "税", "取引", "決済"
        ],
        paymentKeywords: ["カード", "クレジット", "現金", "電子マネー", "PayPay", "Suica", "支払方法", "お支払い方法"],
        amountLabels: ["金額", "支払金額", "お支払い金額", "決済金額"],
        totalLabels: ["合計", "小計", "総合計", "税込合計", "お支払い合計"],
        discountLabels: ["割引", "値引", "クーポン"],
        taxLabels: ["税", "税込", "消費税", "税抜"],
        dateLabels: ["日付", "日時", "取引日時", "発行日"],
        merchantLabels: ["店舗", "加盟店", "店名", "販売者"],
        nonMerchantKeywords: [
            "注文番号", "取引番号", "伝票番号", "広告", "発票番号", "端末番号",
            "部屋番号", "客室番号", "レジ担当", "担当者", "税番号", "会員番号"
        ],
        categoryKeywordMap: [
            "コーヒー": .dining,
            "カフェ": .dining,
            "コンビニ": .groceries,
            "スーパー": .groceries,
            "電車": .transport,
            "バス": .transport,
            "タクシー": .transport,
            "app store": .digital,
        ],
        provenance: .builtIn,
        amountFormat: LedgerAmountFormat(
            currencySymbols: ["¥", "￥", "JPY"],
            decimalSeparator: ".",
            groupingSeparator: ",",
            fractionDigits: 0
        ),
        amountLabelSet: LedgerAmountLabelSet(
            actualPaid: ["金額", "支払金額", "お支払い金額", "決済金額"],
            total: ["合計", "総合計", "税込合計", "お支払い合計"],
            subtotal: ["小計"],
            tax: ["税", "税込", "消費税", "税抜"],
            discount: ["割引", "値引", "クーポン"],
            deposit: ["預り金", "保証金", "デポジット"],
            refund: ["返金", "返品"],
            change: ["お釣り", "釣銭"],
            serviceCharge: ["サービス料"]
        ),
        dateFormats: [
            LedgerDateFormat(pattern: "yyyy/MM/dd", example: "2026/06/25"),
            LedgerDateFormat(pattern: "yyyy-MM-dd", example: "2026-06-25"),
            LedgerDateFormat(pattern: "yyyy年M月d日", example: "2026年6月25日"),
        ],
        ocrRecognitionLanguages: ["ja-JP", "en-US"]
    )
}
