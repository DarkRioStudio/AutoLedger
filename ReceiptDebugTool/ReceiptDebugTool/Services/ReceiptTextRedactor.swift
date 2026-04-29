import Foundation

struct ReceiptTextRedactor {
    func redact(_ text: String) -> String {
        var output = text
        let rules: [(String, String)] = [
            (#"[\w.%+-]+@[\w.-]+\.[A-Za-z]{2,}"#, "[EMAIL_REDACTED]"),
            (#"(?<!\d)1[3-9]\d{9}(?!\d)"#, "[PHONE_REDACTED]"),
            (#"(?<!\d)\d{15,19}(?!\d)"#, "[LONG_NUMBER_REDACTED]"),
            (#"(订单号|商户单号|交易单号|流水号|transaction\s*id|order\s*id)[:：\s]*[A-Za-z0-9_-]{6,}"#, "$1: [ORDER_ID_REDACTED]"),
            (#"(卡号|银行卡|支付卡|尾号|card)[:：\s]*(?:\*|\d|\s){4,}"#, "$1: [CARD_REDACTED]"),
            (#"([A-Za-z\u{4e00}-\u{9fa5}]+(?:路|街|道|巷|弄))\s*\d+(?:号|栋|幢|室|楼|单元)?"#, "$1[ADDRESS_NUMBER_REDACTED]"),
            (#"(?<![\d.])\d{6,14}(?![\d.])"#, "[NUMBER_REDACTED]")
        ]

        for (pattern, replacement) in rules {
            output = output.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return output
    }
}
