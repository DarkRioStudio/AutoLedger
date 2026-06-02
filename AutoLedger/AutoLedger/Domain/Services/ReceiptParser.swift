import AutoLedgerCore
import CoreImage
import Foundation
import Vision

public struct ReceiptParser: Sendable {
    public init() {}

    private struct PaperReceiptAnalysis {
        let isMultiItemReceipt: Bool
        let itemLineCount: Int
        let hasReceiptKeyword: Bool
        let hasCurrencySignal: Bool
        let merchantCandidate: String?
        let totalCandidates: [Double]
        let priceCandidates: [Double]
    }

    // MARK: - 多账单检测

    /// 检测 OCR 文本中是否疑似包含多笔独立账单。
    /// 启发式规则：统计"支付成功""交易成功""支付金额""实付"等交易头部关键词出现次数，
    /// 或统计独立金额行（`-XX.XX` / `¥XX.XX`）数量，超过 1 次即判定为多账单。
    public func detectMultipleReceipts(text: String) -> Bool {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 策略 1：交易头部关键词重复出现
        let headerKeywords = ["支付成功", "交易成功", "付款成功", "扣费成功", "订单支付成功"]
        let headerCount = lines.filter { line in
            headerKeywords.contains(where: { line.contains($0) })
        }.count
        if headerCount > 1 { return true }

        // 策略 2：独立金额行（微信格式 "-XX.XX" 独占一行）出现多次
        let negAmountPattern = #"^\s*-[0-9]+(?:\.[0-9]{1,2})?\s*$"#
        if let regex = try? NSRegularExpression(pattern: negAmountPattern) {
            let negAmountCount = lines.filter { line in
                regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil
            }.count
            if negAmountCount > 1 { return true }
        }

        // 策略 3："¥" 前缀的独立金额行出现多次（排除含"优惠""红包""补贴"的行）
        let currencyPattern = #"^\s*[¥￥]\s*[0-9]+(?:\.[0-9]{1,2})?\s*$"#
        let excludeKeywords = ["优惠", "红包", "补贴", "代金券", "折扣", "购物金", "立减"]
        if let regex = try? NSRegularExpression(pattern: currencyPattern) {
            let currencyLineCount = lines.filter { line in
                let hasMatch = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil
                let isDiscount = excludeKeywords.contains(where: { line.contains($0) })
                return hasMatch && !isDiscount
            }.count
            if currencyLineCount > 1 { return true }
        }

        return false
    }

    /// 对英文/国际化纸质小票做轻量检测，仅输出脱敏诊断字段，供 UI/Intent 判断提示文案。
    public func receiptDiagnostics(text: String) -> ReceiptParseDiagnostics? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let analysis = analyzePaperReceipt(lines: lines)
        guard analysis.isMultiItemReceipt else { return nil }
        return ReceiptParseDiagnostics(
            isMultiItemReceipt: true,
            totalMatched: !analysis.totalCandidates.isEmpty,
            merchantCandidate: analysis.merchantCandidate,
            totalCandidates: analysis.totalCandidates,
            itemLineCount: analysis.itemLineCount,
            rule: analysis.totalCandidates.isEmpty ? "receipt_total_missing" : "receipt_total_priority",
            note: analysis.totalCandidates.isEmpty ? "multi-item receipt without reliable total" : nil
        )
    }

    // MARK: - 单笔解析

    public func parse(text: String, source: ReceiptSource, imageData: Data? = nil, fallbackMerchant: String? = nil) -> ImportedReceipt? {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanedLines = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let paperReceipt = analyzePaperReceipt(lines: cleanedLines)

        // 多商品纸质小票：必须优先取 TOTAL/AMOUNT DUE 等总额，避免把第一条商品价记成整单金额。
        let amount: Double
        let receiptDiagnostics: ReceiptParseDiagnostics?
        if paperReceipt.isMultiItemReceipt, let total = paperReceipt.totalCandidates.first {
            amount = total
            receiptDiagnostics = ReceiptParseDiagnostics(
                isMultiItemReceipt: true,
                totalMatched: true,
                merchantCandidate: paperReceipt.merchantCandidate,
                totalCandidates: paperReceipt.totalCandidates,
                itemLineCount: paperReceipt.itemLineCount,
                rule: "receipt_total_priority"
            )
        } else if paperReceipt.isMultiItemReceipt, let fallbackAmount = paperReceipt.priceCandidates.sorted(by: >).first {
            amount = fallbackAmount
            receiptDiagnostics = ReceiptParseDiagnostics(
                isMultiItemReceipt: true,
                totalMatched: false,
                merchantCandidate: paperReceipt.merchantCandidate,
                totalCandidates: paperReceipt.totalCandidates,
                itemLineCount: paperReceipt.itemLineCount,
                rule: "receipt_total_missing",
                note: "multi-item receipt without reliable total"
            )
        } else if let didiAmt = extractDidiTripAmount(lines: cleanedLines) {
            amount = didiAmt
            receiptDiagnostics = nil
        } else if let imageData, let didiAmt = extractDidiTripAmountFromImage(data: imageData, lines: cleanedLines) {
            amount = didiAmt
            receiptDiagnostics = nil
        } else if let genericAmt = extractAmount(from: normalized) {
            amount = genericAmt
            receiptDiagnostics = nil
        } else {
            return nil
        }

        // 微信支付详情页：标签块→值块格式，优先提取商户全称和支付时间
        let wechatDetail = parseWeChatDetailBlock(lines: cleanedLines)

        // 抖音团购券码页：从"适用门店"区块提取门店名称
        let douyinMerchant = parseDouyinVoucher(lines: cleanedLines)

        // 美团团购券码页：优先提取门店名并去除分店后缀
        let meituanMerchant = parseMeituanVoucher(lines: cleanedLines)

        // 滴滴出行结束订单页：含"行程已结束"特征，直接返回"滴滴出行"
        let didiMerchant = parseDidiTrip(lines: cleanedLines)

        // 支付宝/淘宝闪购账单详情页：从"商品说明"字段提取真实店铺/商品说明
        let alipayBillDetailMerchant = parseAlipayBillDetailMerchant(lines: cleanedLines)

        // 淘宝闪购订单进行中页：含"骑士"+"闪购"，从"闪购"标签后提取店铺名
        let taobaoFlashMerchant = parseTaobaoFlashOrder(lines: cleanedLines)

        // 微信代扣凭证页：含"扣费凭证"+"扣费内容"，提取服务内容名称（如"先购后付"）
        let wechatDeductionMerchant = parseWeChatDeductionVoucher(lines: cleanedLines)

        // 云闪付 / 银联交易详情页：标签和值常分行展示，优先提取商户名称字段
        let unionPayMerchant = parseUnionPayVoucher(lines: cleanedLines)

        let merchant: String
        if paperReceipt.isMultiItemReceipt {
            merchant = paperReceipt.merchantCandidate
                ?? fallbackMerchant
                ?? extractMerchant(from: normalized, source: source)
                ?? "待确认商户"
        } else {
            merchant = wechatDetail?.merchant
                ?? douyinMerchant
                ?? meituanMerchant
                ?? didiMerchant
                ?? alipayBillDetailMerchant
                ?? taobaoFlashMerchant
                ?? wechatDeductionMerchant
                ?? unionPayMerchant
                ?? extractMerchant(from: normalized, source: source)
                ?? fallbackMerchant
                ?? "待确认商户"
        }
        let date = wechatDetail?.date
            ?? extractDate(from: normalized)
            ?? .now
        let category: TransactionCategory
        if receiptDiagnostics != nil {
            category = inferReceiptCategory(merchant: merchant, text: normalized)
        } else {
            category = TransactionCategory.infer(from: "\(merchant)\n\(normalized)")
        }
        let confidence: Double
        let summary: String
        if let receiptDiagnostics {
            confidence = receiptDiagnostics.totalMatched ? 0.88 : 0.35
            summary = receiptDiagnostics.totalMatched ? "纸质小票按总金额解析" : "纸质小票总金额待确认"
        } else {
            confidence = wechatDetail != nil ? 0.90 : 0.82
            summary = "\(source.title) OCR 解析草稿"
        }

        return ImportedReceipt(
            source: source,
            merchant: merchant,
            amount: amount,
            occurredAt: date,
            rawText: normalized,
            summary: summary,
            confidence: confidence,
            suggestedCategory: category,
            parseDiagnostics: receiptDiagnostics
        )
    }

    private func analyzePaperReceipt(lines: [String]) -> PaperReceiptAnalysis {
        let receiptSignalKeywords = [
            "receipt", "subtotal", "sub total", "tax", "gst", "vat",
            "total", "grand total", "amount due", "balance due", "cashier"
        ]
        let currencySignals = ["$", "USD", "SGD", "RM", "MYR", "£", "GBP", "€", "EUR"]
        let strongTotalKeywords = [
            "grand total", "amount due", "balance due", "total due",
            "total amount", "amount payable", "total"
        ]

        let hasReceiptKeyword = lines.contains { line in
            let lower = line.lowercased()
            return receiptSignalKeywords.contains { lower.contains($0) }
        }
        let hasCurrencySignal = lines.contains { line in
            currencySignals.contains { line.localizedCaseInsensitiveContains($0) }
        }

        let itemLines = lines.filter { isReceiptItemLine($0) }
        var totalCandidates: [Double] = []
        for line in lines {
            let lower = line.lowercased()
            guard strongTotalKeywords.contains(where: { lower.contains($0) }) else { continue }
            guard !lower.contains("subtotal"), !lower.contains("sub total") else { continue }
            totalCandidates.append(contentsOf: amountCandidates(in: line))
        }

        // 去重并保持出现顺序；小票同一 TOTAL 行可能被 OCR 拆出多个相同数字。
        var seenTotals: Set<Int> = []
        let uniqueTotals = totalCandidates.filter { amount in
            let cents = Int((amount * 100).rounded())
            guard !seenTotals.contains(cents) else { return false }
            seenTotals.insert(cents)
            return true
        }

        let itemPriceCandidates = itemLines.flatMap { amountCandidates(in: $0) }
        let isMultiItemReceipt = itemLines.count >= 2 && (hasReceiptKeyword || hasCurrencySignal || !uniqueTotals.isEmpty)

        return PaperReceiptAnalysis(
            isMultiItemReceipt: isMultiItemReceipt,
            itemLineCount: itemLines.count,
            hasReceiptKeyword: hasReceiptKeyword,
            hasCurrencySignal: hasCurrencySignal,
            merchantCandidate: isMultiItemReceipt ? receiptHeaderMerchant(lines: lines) : nil,
            totalCandidates: uniqueTotals.filter { $0 > 0 && $0 < 100000 },
            priceCandidates: itemPriceCandidates.filter { $0 > 0 && $0 < 100000 }
        )
    }

    private func isReceiptItemLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else { return false }
        guard trimmed.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { return false }

        let lower = trimmed.lowercased()
        let nonItemKeywords = [
            "total", "subtotal", "sub total", "tax", "gst", "vat", "change", "cash",
            "card", "visa", "mastercard", "debit", "credit", "amount due", "balance due"
        ]
        guard !nonItemKeywords.contains(where: { lower.contains($0) }) else { return false }

        let trailingPricePattern = #"(?i).*(?:[$£€¥]\s*)?[0-9]+(?:\.[0-9]{2})\s*$"#
        return (try? NSRegularExpression(pattern: trailingPricePattern))?
            .firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) != nil
    }

    private func receiptHeaderMerchant(lines: [String]) -> String? {
        let headerLines = Array(lines.prefix(8))
        let skipKeywords = [
            "receipt", "tax invoice", "invoice", "tel", "phone", "address",
            "cashier", "register", "date", "time", "gst", "vat", "tax id"
        ]
        let addressPattern = #"\b(?:st|street|road|rd|ave|avenue|drive|dr|mall|blk|block|unit)\b"#
        let datePattern = #"\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}"#
        let phonePattern = #"\+?\d[\d\s\-()]{7,}"#

        for line in headerLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            guard trimmed.count >= 3 else { continue }
            guard !skipKeywords.contains(where: { lower.contains($0) }) else { continue }
            guard !isReceiptItemLine(trimmed) else { continue }
            guard amountCandidate(in: trimmed) == nil else { continue }
            guard (try? NSRegularExpression(pattern: datePattern))?
                .firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) == nil else { continue }
            guard (try? NSRegularExpression(pattern: phonePattern))?
                .firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) == nil else { continue }
            guard (try? NSRegularExpression(pattern: addressPattern, options: .caseInsensitive))?
                .firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) == nil else { continue }
            return trimmed
        }
        return nil
    }

    // MARK: - 支付宝 / 淘宝账单详情解析

    /// 支付宝账单详情页的字段常以"支付时间 / 付款方式 / 商品说明"标签块展示，
    /// OCR 会先输出连续标签，再按相同顺序输出对应值。淘宝闪购的账单来源可能被识别为
    /// `taobao`，但真实商户通常藏在"商品说明"值中，如"XXX（分店）外卖订单"。
    private func parseAlipayBillDetailMerchant(lines: [String]) -> String? {
        guard lines.contains(where: { $0 == "商品说明" || $0.contains("商品说明") }) else { return nil }
        guard lines.contains(where: { $0.contains("账单详情") || $0.contains("账单分类") || $0.contains("支付成功") }) else {
            return nil
        }

        for (idx, line) in lines.enumerated() where line.contains("商品说明") {
            if let inline = inlineValue(after: "商品说明", in: line),
               let candidate = cleanedAlipayBillDetailMerchant(from: inline) {
                return candidate
            }

            if let candidate = alipayBillDetailBlockValue(lines: lines, labelIndex: idx) {
                return candidate
            }

            if let candidate = alipayBillDetailFollowingValue(lines: lines, startIndex: idx + 1) {
                return candidate
            }
        }

        return nil
    }

    private func alipayBillDetailBlockValue(lines: [String], labelIndex: Int) -> String? {
        var blockStart = labelIndex
        while blockStart > 0, isAlipayBillDetailLabel(lines[blockStart - 1]) {
            blockStart -= 1
        }

        let labelOffset = labelIndex - blockStart
        let valuesStart = labelIndex + 1
        let candidateStart = valuesStart + labelOffset
        guard candidateStart < lines.count else { return nil }
        return alipayBillDetailFollowingValue(lines: lines, startIndex: candidateStart)
    }

    private func alipayBillDetailFollowingValue(lines: [String], startIndex: Int) -> String? {
        var fragments: [String] = []

        for i in startIndex..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if shouldStopAlipayBillDetailValue(line) { break }
            if amountCandidate(in: line) != nil || AppFormatters.parseFlexibleDate(line) != nil {
                if fragments.isEmpty { continue }
                break
            }
            fragments.append(line)

            let joined = fragments.joined()
            if joined.contains("订单") || (joined.contains("（") && joined.contains("）")) {
                break
            }
        }

        guard !fragments.isEmpty else { return nil }
        return cleanedAlipayBillDetailMerchant(from: fragments.joined())
    }

    private func inlineValue(after label: String, in line: String) -> String? {
        guard let labelRange = line.range(of: label) else { return nil }
        let suffix = String(line[labelRange.upperBound...])
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":：")))
        return suffix.isEmpty ? nil : suffix
    }

    private func isAlipayBillDetailLabel(_ line: String) -> Bool {
        let labels: Set<String> = [
            "支付时间", "付款方式", "商品说明", "订单金额", "支付奖励", "收单机构",
            "清算机构", "收款方全称", "优惠", "红包", "商家订单号", "交易号",
            "订单号", "账单分类", "标签", "计入收支"
        ]
        return labels.contains(line)
    }

    private func shouldStopAlipayBillDetailValue(_ line: String) -> Bool {
        if isAlipayBillDetailLabel(line) { return true }
        let stopKeywords = [
            "更多", "账单管理", "账单分类", "请选择", "使用记账本", "计入收支",
            "查看商家订单", "交易凭证", "联系商家"
        ]
        return stopKeywords.contains { line.contains($0) }
    }

    private func cleanedAlipayBillDetailMerchant(from value: String) -> String? {
        var candidate = value
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "＞>》〉~～")))

        candidate = candidate
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\s*(?:外卖|到店|团购)?订单.*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "＞>》〉~～")))

        let genericNames: Set<String> = ["淘宝闪购", "支付宝", "付款方式", "商品说明", "支付成功"]
        guard candidate.count >= 2,
              !genericNames.contains(candidate),
              amountCandidate(in: candidate) == nil,
              AppFormatters.parseFlexibleDate(candidate) == nil else {
            return nil
        }
        return candidate
    }

    private func inferReceiptCategory(merchant: String, text: String) -> TransactionCategory {
        let lowered = "\(merchant)\n\(text)".lowercased()
        if lowered.contains("restaurant") || lowered.contains("cafe") || lowered.contains("coffee")
            || lowered.contains("mcdonald") || lowered.contains("kfc") || lowered.contains("burger")
            || lowered.contains("noodle") || lowered.contains("tea") {
            return .dining
        }
        if lowered.contains("fairprice") || lowered.contains("walmart") || lowered.contains("supermarket")
            || lowered.contains("grocery") || lowered.contains("market") || lowered.contains("milk")
            || lowered.contains("bread") || lowered.contains("apple") || lowered.contains("ntuc") {
            return .groceries
        }
        if lowered.contains("mall") {
            return .shopping
        }
        return .groceries
    }

    private func extractAmount(from text: String) -> Double? {
        let lines = text.components(separatedBy: .newlines)

        // 微信支付格式优先：独立行 "-XX.XX" 就是实际支付金额
        let wechatNegPattern = #"^\s*-([0-9]+(?:\.[0-9]{1,2})?)\s*$"#
        if let negRegex = try? NSRegularExpression(pattern: wechatNegPattern) {
            for line in lines {
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = negRegex.firstMatch(in: line, range: nsRange),
                   let range = Range(match.range(at: 1), in: line),
                   let amount = Double(String(line[range])),
                   amount > 0 {
                    return amount
                }
            }
        }

        // 带货币符号前缀的行优先（¥/￥/£/$€ 等）
        let currencyPrefixPattern = #"[¥￥£$€]\s*([0-9]+(?:\.[0-9]{1,2})?)"#

        // 实付/总额行最优先（中英文皆支持）
        let actualPayKeywords = ["实付", "实际支付", "实际付款", "合计支付",
                                  "TOTAL", "Total", "total", "GRAND TOTAL", "Grand Total",
                                  "Amount Due", "AMOUNT DUE", "Balance Due", "BALANCE DUE",
                                  "Subtotal", "SUBTOTAL"]
        if let cpRegex = try? NSRegularExpression(pattern: currencyPrefixPattern) {
            for line in lines where actualPayKeywords.contains(where: { line.contains($0) }) {
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = cpRegex.firstMatch(in: line, range: nsRange),
                   let range = Range(match.range(at: 1), in: line),
                   let amount = Double(String(line[range])),
                   amount > 0 && amount < 100000 {
                    return amount
                }
            }
        }

        // 普通 ¥ 前缀行
        if let cpRegex = try? NSRegularExpression(pattern: currencyPrefixPattern) {
            for line in lines {
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = cpRegex.firstMatch(in: line, range: nsRange),
                   let range = Range(match.range(at: 1), in: line),
                   let amount = Double(String(line[range])),
                   amount > 0 && amount < 100000 {
                    return amount
                }
            }
        }

        // TOTAL 行专用提取（英文小票 TOTAL 后通常紧跟金额，可带货币符号）
        let totalLinePattern = #"(?i)(?:grand\s+)?total[:\s]+[¥￥£$€]?\s*([0-9]+(?:\.[0-9]{1,2})?)"#
        if let totalRegex = try? NSRegularExpression(pattern: totalLinePattern) {
            for line in lines {
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = totalRegex.firstMatch(in: line, range: nsRange),
                   let range = Range(match.range(at: 1), in: line),
                   let amount = Double(String(line[range])),
                   amount > 0 && amount < 100000 {
                    return amount
                }
            }
        }

        // 关键词行回退
        let keywords = ["金额", "支付", "总计", "总额", "实际支付", "Price", "Total", "CNY", "RMB",
                        "Amount", "Subtotal", "Balance"]
        let prioritizedLines = lines.filter {
            let line = $0.lowercased()
            return keywords.contains { line.contains($0.lowercased()) }
        }

        for line in prioritizedLines where !line.isEmpty {
            if let amount = amountCandidate(in: line) {
                return amount
            }
        }

        // 全文兜底
        for line in lines {
            if let amount = amountCandidate(in: line) {
                return amount
            }
        }

        return nil
    }

    private func amountCandidate(in line: String) -> Double? {
        amountCandidates(in: line)
            .filter { $0 < 100000 }
            .sorted(by: >)
            .first
    }

    private func amountCandidates(in line: String) -> [Double] {
        // 跳过疑似状态栏时间/信号格式，如 "10:131" 或 "9:41"
        let timeOnlyPattern = #"^\s*\d{1,2}:\d{2,3}\s*$"#
        if (try? NSRegularExpression(pattern: timeOnlyPattern))?
            .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil {
            return []
        }

        let pattern = #"(?:(?:¥|￥|£|\$|€|RMB|CNY|USD|SGD|RM|MYR|GBP|EUR)\s*)?([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = regex.matches(in: line, range: nsRange)

        return matches.compactMap { match -> Double? in
            guard let range = Range(match.range(at: 1), in: line) else {
                return nil
            }
            return Double(String(line[range]))
        }
    }

    /// 判断字符串是否是一个独立的金额（整行基本就是货币符号 + 数字）。
    /// 例如 "CN¥7.00"、"CN￥3.60"（全角￥）、"¥2.70"、"CNY 3.50" 均返回 true；
    /// "T2航站楼"、"3号线"、"ExampleAirport" 等含有非数字字符的站名返回 false。
    private func isStandaloneAmount(_ string: String) -> Bool {
        // CN¥ 为半角（U+00A5），CN￥ 为全角（U+FFE5），OCR 可能混用，均需支持
        // 同时兼容英文货币符号 £/$€
        let pattern = #"^\s*(?:CN¥|CN￥|¥|￥|£|\$|€|CNY|RMB)\s*[0-9]+(?:\.[0-9]{1,2})?\s*$"#
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        return (try? NSRegularExpression(pattern: pattern))?
            .firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) != nil
    }

    private func extractMerchant(from text: String, source: ReceiptSource) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 这些是微信支付等平台的字段标签名，不是商户名
        let fieldLabels: Set<String> = [
            "商户全称", "收单机构", "支付方式", "交易单号", "商户单号",
            "当前状态", "支付时间", "商品", "备注", "附言",
            "商户名称", "商户名", "收款商户", "收款方", "付款方式",
            "交易金额", "订单金额", "交易时间", "订单号", "付款记录",
            "交易详情", "订单详情"
        ]

        // ── 来源专用逻辑优先 ──
        if source == .appStore {
            // Apple 收据：先找含中文订阅标记的产品行（如 "Apple Developer Program（自动续期）"）
            if let subLine = lines.first(where: { $0.contains("自动续期") }) {
                let cleaned = subLine
                    .replacingOccurrences(of: #"（[^）]*）"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { return cleaned }
            }
            // 回退：找第一个有效商户/产品行（跳过元数据行）
            let skipKeywords: Set<String> = ["app store", "文稿编号", "订单号", "apple 账户", "收据", "详情", "报告问题", "付款信息"]
            let skipContains = ["@", "支付", "如需", "了解", "Copyright", "总计", "续期",
                                "¥", "￥", "密码", "销售条款", "Subscription", "subscription",
                                "Date", "CHN", "保留所有权利"]
            let pureNumberPattern = #"^\s*[\d\s]+\s*$"#
            let dateLinePattern = #"^\d{4}年"#
            if let appLine = lines.first(where: { line in
                let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
                return !skipKeywords.contains(lower)
                    && !skipContains.contains(where: { line.contains($0) })
                    && line.count >= 4
                    && amountCandidate(in: line) == nil
                    && ((try? NSRegularExpression(pattern: pureNumberPattern))?.firstMatch(
                        in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) == nil)
                    && ((try? NSRegularExpression(pattern: dateLinePattern))?.firstMatch(
                        in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) == nil)
            }) {
                return appLine
            }
        }

        // ── 通用前缀匹配（要求关键词出现在冒号之前，防止误匹配语句中间的"项目"等） ──
        let merchantPrefixes = ["收款方", "商户", "Merchant", "项目", "商品"]
        for line in lines {
            let parts = line.components(separatedBy: CharacterSet(charactersIn: ":："))
            guard parts.count >= 2 else { continue }
            let label = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
            if merchantPrefixes.contains(where: { label.contains($0) }) {
                let candidate = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty, !fieldLabels.contains(candidate) {
                    return candidate
                }
            }
        }

        // 外卖平台："闪购 XXX店" / "外卖 XXX店" 格式
        let deliveryPrefixes = ["闪购", "外卖"]
        for line in lines {
            for prefix in deliveryPrefixes where line.hasPrefix(prefix) {
                let candidate = line
                    .replacingOccurrences(of: prefix, with: "")
                    .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "＞>》")))
                if !candidate.isEmpty {
                    return candidate
                }
            }
        }

        // 微信支付格式：负数金额行（如 -6.00）相邻行通常是商户名
        let wechatNegativeAmountPattern = #"^-[0-9]+(?:\.[0-9]{1,2})?$"#
        if let negLineIdx = lines.indices.first(where: { i in
            let line = lines[i]
            return (try? NSRegularExpression(pattern: wechatNegativeAmountPattern))?
                .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil
        }) {
            // 先查上一行（微信支付详情页：商户名在金额上方）
            if negLineIdx - 1 >= 0 {
                let candidate = lines[negLineIdx - 1]
                if candidate.count >= 2 && !fieldLabels.contains(candidate) && amountCandidate(in: candidate) == nil {
                    return candidate
                }
            }
            // 再查下一行（转账/红包等其他格式）
            if negLineIdx + 1 < lines.count {
                let candidate = lines[negLineIdx + 1]
                if !candidate.isEmpty && !fieldLabels.contains(candidate) && amountCandidate(in: candidate) == nil {
                    return candidate
                }
            }
        }

        // ── 含工商登记主体关键词的行（有限公司等）→ 直接作为商户全称 ──
        // 适用于支付宝碰一下、银联等在截图中直接显示公司全称的场景
        let companyKeywords = ["有限公司", "股份有限", "有限责任", "集团公司"]
        if let companyLine = lines.first(where: { line in
            companyKeywords.contains(where: { line.contains($0) }) &&
            !fieldLabels.contains(line)
        }) {
            return companyLine
        }

        // ── 地铁 / 公交储值卡格式 ──
        // 支持三种 OCR 版式：
        //   (A) 独立行 "地铁：" + 金额行 + 站点行（如 "ExampleStationA ExampleStationB"）
        //   (B) 同一行 "地铁：ExampleStationA ExampleStationB"
        //   (C) 同一行 "地铁：CN¥7.00"（金额嵌入冒号后）+ 下一行站点（如 "ExampleAirport - ExampleEastStation"）
        let transitKeywords: Set<String> = ["地铁", "公交"]
        for (idx, line) in lines.enumerated() {
            // 用 rangeOfCharacter 找第一个冒号，避免多次分割时字符类型不一致
            guard let colonRange = line.rangeOfCharacter(from: CharacterSet(charactersIn: ":：")) else { continue }
            let label = String(line[line.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard transitKeywords.contains(label) else { continue }
            let inlinePart = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let stationText: String
            if !inlinePart.isEmpty && !isStandaloneAmount(inlinePart) {
                // (B) 同一行：地铁：ExampleStationA ExampleStationB（内联部分不是独立金额）
                stationText = inlinePart
            } else {
                // (A)/(C) 独立 "地铁：" 行 或 "地铁：CN¥X.XX" — 向后查找站点行（跳过金额行）
                guard let stationLine = lines.dropFirst(idx + 1).first(where: { sl in
                    !sl.isEmpty && amountCandidate(in: sl) == nil
                }) else { continue }
                stationText = stationLine
            }
            // 将站名文本规范化为 "站A → 站B"
            let route: String
            if stationText.contains("→") || stationText.contains("->") {
                route = stationText
            } else {
                let hyphenSet = CharacterSet(charactersIn: "-")
                let stations = stationText.components(separatedBy: " ")
                    .map { $0.trimmingCharacters(in: hyphenSet) }
                    .filter { !$0.isEmpty }
                route = stations.count >= 2 ? stations.joined(separator: " → ") : stationText
            }
            return "\(label)：\(route)"
        }

        // ── 通知类收据："感谢使用XXX" 通常包含真实服务/商户名 ──
        let thankYouPattern = #"感谢使用(.{2,10}?)[，,。.！!\s]"#
        if let regex = try? NSRegularExpression(pattern: thankYouPattern) {
            let nsText = text as NSString
            let range = NSRange(location: 0, length: nsText.length)
            if let match = regex.firstMatch(in: text, range: range),
               let captureRange = Range(match.range(at: 1), in: text) {
                return String(text[captureRange])
            }
        }

        // ── 英文小票 / 国际收据启发式 ──
        // 特征：含 "TOTAL" 行 → 商户名通常在小票最前几行（店名/地址/电话）
        // 产品行（"FRESH MILK  3.89"）不是商户名
        let isEnglishReceipt = lines.contains(where: {
            $0.localizedCaseInsensitiveContains("total") || $0.localizedCaseInsensitiveContains("subtotal")
        })
        if isEnglishReceipt {
            // 跳过产品行/价格行/数量行/日期行/时间行，取第一个看起来像店名的行
            let productLinePattern = #"[0-9]+(?:\.[0-9]{1,2})?\s*$"#  // 行尾有数字（价格）
            let qtyPattern = #"(?:x\s*\d|@\s*[\d£$€¥]|\d+\s*@)"#    // 数量标记
            let dateTimePattern = #"\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}"#  // 日期格式
            let phonePattern = #"\+?\d[\d\s\-]{7,}"#                  // 电话号码
            let receiptNoiseWords = ["receipt", "change", "cash", "card", "visa", "mastercard",
                                     "debit", "credit", "vat", "tax", "served by", "cashier",
                                     "thank you", "thanks"]
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let lower = trimmed.lowercased()
                // 跳过过短的行
                guard trimmed.count >= 3 else { continue }
                // 跳过行尾有价格的产品行
                if (try? NSRegularExpression(pattern: productLinePattern))?.firstMatch(
                    in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) != nil {
                    continue
                }
                // 跳过含数量标记的行
                if (try? NSRegularExpression(pattern: qtyPattern, options: .caseInsensitive))?.firstMatch(
                    in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) != nil {
                    continue
                }
                // 跳过日期行
                if (try? NSRegularExpression(pattern: dateTimePattern))?.firstMatch(
                    in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) != nil {
                    continue
                }
                // 跳过电话行
                if (try? NSRegularExpression(pattern: phonePattern))?.firstMatch(
                    in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) != nil {
                    continue
                }
                // 跳过含 TOTAL / 噪声关键词的行
                if lower.contains("total") || lower.contains("subtotal") { continue }
                if receiptNoiseWords.contains(where: { lower.contains($0) }) { continue }
                // 跳过纯金额
                if amountCandidate(in: trimmed) != nil && trimmed.count < 10 { continue }
                // 跳过时间格式
                let timeOnlyPat = #"^\s*\d{1,2}:\d{2,3}\s*$"#
                if (try? NSRegularExpression(pattern: timeOnlyPat))?.firstMatch(
                    in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) != nil {
                    continue
                }
                return trimmed
            }
        }

        // ── 兜底：取第一个有意义的行 ──
        // 状态栏运营商名称，不是商户名
        let carrierNames: Set<String> = [
            "中国联通", "中国移动", "中国电信",
            "China Unicom", "China Mobile", "China Telecom", "CMCC"
        ]
        let skipContainsFallback = ["成功", "金额", "时间", "Total", "全部账单",
                                     "可在支持的商户", "扫码退款", "收单机构", "账单详情",
                                     "通知中心", "请确认",
                                     "回首页",        // 支付宝支付成功页导航按钮
                                     "外卖红包", "骑士", "催单"]  // 外卖订单 UI 噪声
        let timePattern = #"^\s*\d{1,2}:\d{2,3}\s*$"#
        let pureNumberPattern = #"^\s*\d{1,5}\s*$"#
        // 日期行（"X月X日..."）不是商户名
        let dateLikePattern = #"^\d{1,2}月\d{1,2}日"#
        // 子弹符号开头 + 3 字以内的短噪声行（如 "•五"，来自微信侧边栏徽标或通知计数的 OCR 误读）
        let bulletShortNoisePattern = #"^[•·▪▸►▷◦‣⁃]\s*.{0,3}$"#
        return lines.first(where: { line in
            !carrierNames.contains(line) &&
            !skipContainsFallback.contains(where: { line.contains($0) }) &&
            !fieldLabels.contains(line) &&
            line.count >= 2 &&
            // 跳过无实质字母内容的行（如 "：！⑤"，来自系统通知徽标的 OCR 噪声）
            line.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) &&
            amountCandidate(in: line) == nil &&
            (try? NSRegularExpression(pattern: timePattern))?
                .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) == nil &&
            (try? NSRegularExpression(pattern: pureNumberPattern))?
                .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) == nil &&
            (try? NSRegularExpression(pattern: dateLikePattern))?
                .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) == nil &&
            (try? NSRegularExpression(pattern: bulletShortNoisePattern))?
                .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) == nil
        })
    }

    private func extractDate(from text: String) -> Date? {
        let lines = text.components(separatedBy: .newlines)
        let patterns = [
            #"(20[0-9]{2}[年/-][0-9]{1,2}[月/-][0-9]{1,2}[日]?\s+[0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?)"#,
            #"(20[0-9]{2}[年/-][0-9]{1,2}[月/-][0-9]{1,2}[日]?)"#
        ]

        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else {
                    continue
                }
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                guard let match = regex.firstMatch(in: line, range: nsRange),
                      let range = Range(match.range(at: 1), in: line) else {
                    continue
                }

                if let date = AppFormatters.parseFlexibleDate(String(line[range])) {
                    return date
                }
            }
        }

        return nil
    }

    // MARK: - 云闪付 / 银联交易详情解析

    /// 云闪付、银联二维码支付详情页常见两种格式：
    ///   1. "商户名称" 独立一行，下一行是商户名。
    ///   2. "商户名称：XXX" 与商户值在同一行。
    /// 该解析只在文本包含云闪付/银联信号时触发，避免把其他平台的通用字段误当作银联账单。
    private func parseUnionPayVoucher(lines: [String]) -> String? {
        let hasUnionPaySignal = lines.contains { line in
            line.localizedCaseInsensitiveContains("云闪付")
                || line.localizedCaseInsensitiveContains("银联")
                || line.localizedCaseInsensitiveContains("unionpay")
        }
        guard hasUnionPaySignal else { return nil }

        let merchantLabels = ["商户名称", "商户名", "收款商户", "收款方", "对方户名"]
        let fieldLabels: Set<String> = [
            "云闪付", "中国银联", "UnionPay", "交易详情", "订单详情", "账单详情", "交易成功",
            "支付成功", "付款成功", "支付金额", "交易金额", "订单金额",
            "交易时间", "支付方式", "付款方式", "银行卡", "优惠", "订单号",
            "交易单号", "参考号", "凭证号", "收款方", "商户名称", "商户名",
            "收款商户", "对方户名",
            // "收款方全称" 是复合标签（"收款方" + "全称"），其后缀 "全称" 不是商户名
            "全称"
        ]

        // ── 云闪付"账单详情"页面专用格式 ──
        // 商户名称出现在"账单详情"标题之后、支付金额（负数行）之前。
        // 该格式由用户在云闪付 App 内点击某笔交易后进入账单详情页时产生。
        if let detailIdx = lines.firstIndex(where: { $0 == "账单详情" }) {
            let negAmountPattern = #"^-[0-9]+(?:\.[0-9]{1,2})?$"#
            let negAmountRegex = try? NSRegularExpression(pattern: negAmountPattern)
            for line in lines[(detailIdx + 1)...].prefix(5) {
                if let re = negAmountRegex,
                   re.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil {
                    break
                }
                if let candidate = cleanedUnionPayMerchantCandidate(line, fieldLabels: fieldLabels) {
                    return candidate
                }
            }
        }

        for (idx, line) in lines.enumerated() {
            guard let label = merchantLabels.first(where: { line.contains($0) }) else {
                continue
            }

            if let colonRange = line.rangeOfCharacter(from: CharacterSet(charactersIn: ":：")) {
                let inline = String(line[colonRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let candidate = cleanedUnionPayMerchantCandidate(inline, fieldLabels: fieldLabels) {
                    return candidate
                }
            }

            let suffix = line.replacingOccurrences(of: label, with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":：")))
            if let candidate = cleanedUnionPayMerchantCandidate(suffix, fieldLabels: fieldLabels) {
                return candidate
            }

            guard idx + 1 < lines.count else { continue }
            for next in lines[(idx + 1)...].prefix(4) {
                if let candidate = cleanedUnionPayMerchantCandidate(next, fieldLabels: fieldLabels) {
                    return candidate
                }
            }
        }

        let companyKeywords = ["有限公司", "股份有限", "有限责任", "集团公司"]
        return lines.first { line in
            companyKeywords.contains(where: { line.contains($0) })
                && cleanedUnionPayMerchantCandidate(line, fieldLabels: fieldLabels) != nil
        }
    }

    private func cleanedUnionPayMerchantCandidate(_ value: String, fieldLabels: Set<String>) -> String? {
        let candidate = value
            .replacingOccurrences(of: #"^[·•\-\s]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !candidate.isEmpty else { return nil }
        guard !fieldLabels.contains(candidate) else { return nil }
        guard candidate.count >= 2 else { return nil }
        guard candidate.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { return nil }
        guard amountCandidate(in: candidate) == nil else { return nil }

        let skipContains = ["成功", "金额", "时间", "方式", "银行卡", "订单", "交易", "优惠", "退款", "详情", "记录"]
        guard !skipContains.contains(where: { candidate.contains($0) }) else { return nil }

        return candidate
    }

    // MARK: - 抖音团购券码页解析

    /// 抖音团购券码页的典型特征：含"待使用"、"券号"和"适用门店"。
    /// 商户名通常出现在"适用门店（X家）"之后的第一个有效门店行。
    /// 抖音直播状态标记（如"U 直播中"）可能与门店名在同一行，需剥离。
    private func parseDouyinVoucher(lines: [String]) -> String? {
        let hasVoucherStatus = lines.contains(where: { $0.contains("待使用") })
        let hasVoucherCode = lines.contains(where: { $0.contains("券号") })
        let hasStoreList = lines.contains(where: { $0.contains("适用门店") })
        guard hasVoucherStatus && (hasVoucherCode || hasStoreList) else { return nil }

        guard let storeListIdx = lines.indices.first(where: { lines[$0].contains("适用门店") }) else {
            return nil
        }

        // 抖音直播状态前缀可能粘连在门店名之前（如 "U 直播中Demo Burger (Example Branch)"）
        let douyinUIPrefixes = ["U 直播中", "直播中"]
        let skipLines = ["全部门店", "交易快照", "申请退款", "再来一单", "查看详细步骤", "适用门店"]
        // 匹配噪声行：营业时间、距离、地址、纯数字/字母组合
        let noisePatterns = [
            #"^营业中"#,
            #"^最近\d"#,
            #"^[•·]"#,
            #"^\d+[a-zA-Z]*$"#
        ]

        for line in lines[(storeListIdx + 1)...] {
            var candidate = line
            for prefix in douyinUIPrefixes where candidate.hasPrefix(prefix) {
                candidate = String(candidate.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
            }

            guard !candidate.isEmpty else { continue }
            guard candidate.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { continue }
            guard !skipLines.contains(where: { candidate.contains($0) }) else { continue }
            guard !candidate.hasPrefix("•") && !candidate.hasPrefix("·") else { continue }

            var isNoise = false
            for pattern in noisePatterns {
                if (try? NSRegularExpression(pattern: pattern))?
                    .firstMatch(in: candidate,
                                range: NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)) != nil {
                    isNoise = true
                    break
                }
            }
            if isNoise { continue }

            return candidate
        }

        return nil
    }

    // MARK: - 美团团购券码页解析

    /// 美团团购"已使用/团购详情"页面会展示"商户名（分店）"格式；
    /// 记账优先使用主商户名，去掉括号中的分店后缀。
    private func parseMeituanVoucher(lines: [String]) -> String? {
        let hasMeituanSignal = lines.contains { line in
            line.contains("美团") || line.contains("团购详情") || line.contains("已使用")
        }
        let hasPaymentSignal = lines.contains { $0.contains("实付") }
        guard hasMeituanSignal && hasPaymentSignal else { return nil }

        func normalizeMerchant(_ line: String) -> String? {
            let candidate = line
                .replacingOccurrences(of: #"^[◎•·\-\s]+"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !candidate.isEmpty else { return nil }
            guard candidate.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { return nil }
            guard amountCandidate(in: candidate) == nil else { return nil }

            let skipKeywords = ["门店", "详情", "评价", "已使用", "营业中", "安心吃保障", "保险"]
            guard !skipKeywords.contains(where: { candidate.contains($0) }) else { return nil }

            if let parenRange = candidate.range(of: "（") ?? candidate.range(of: "(") {
                let base = String(candidate[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if base.count >= 2 { return base }
            }
            return candidate
        }

        if let bizIdx = lines.firstIndex(where: { $0.contains("营业中") }) {
            let windowStart = max(0, bizIdx - 2)
            for idx in stride(from: bizIdx - 1, through: windowStart, by: -1) {
                if let merchant = normalizeMerchant(lines[idx]) {
                    return merchant
                }
            }
        }

        let storeSuffixPattern = #".+[（(][^（）()]{1,20}店[）)]"#
        let storeRegex = try? NSRegularExpression(pattern: storeSuffixPattern)
        for line in lines {
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            guard storeRegex?.firstMatch(in: line, range: nsRange) != nil else { continue }
            if let merchant = normalizeMerchant(line) {
                return merchant
            }
        }

        return nil
    }

    // MARK: - 滴滴出行车费专用提取

    /// 滴滴行程结束页的车费紧邻"费用明细"按钮之前。
    /// 通用 extractAmount 会先碰到页面顶部的评价人数等无关数字，导致误识别。
    /// 此方法仅在含"行程已"的滴滴结束页触发，在"费用明细"前 5 行内逆序搜索：
    ///   1. 带 ¥/￥ 前缀的标准格式（如 "¥45.00"、"¥19.60 优惠-¥490"）
    ///   2. OCR 将 "¥" 误读为 "4" 的情形（如 "¥45" → "445"、"¥19.60" → "419.60"），
    ///      整行符合 "4XX" / "4XX.XX" 且去除首字符后为合理金额时修正。
    private func extractDidiTripAmount(lines: [String]) -> Double? {
        // 只在行程结束页（含"行程已"关键词）触发
        guard lines.contains(where: { $0.contains("行程已") }) else { return nil }

        // 定位"费用明细"行
        guard let fareDetailIdx = lines.indices.first(where: { lines[$0].contains("费用明细") }) else {
            return nil
        }

        // 在"费用明细"前最多 5 行中逆序搜索（从近到远）
        let windowStart = max(0, fareDetailIdx - 5)
        let candidateLines = lines[windowStart..<fareDetailIdx].reversed()

        // 1. 优先：带 ¥/￥ 前缀的金额（标准 OCR 格式）
        let currencyPrefixPattern = #"[¥￥]\s*([0-9]+(?:\.[0-9]{1,2})?)"#
        if let cpRegex = try? NSRegularExpression(pattern: currencyPrefixPattern) {
            for line in candidateLines {
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = cpRegex.firstMatch(in: line, range: nsRange),
                   let range = Range(match.range(at: 1), in: line),
                   let amt = Double(String(line[range])),
                   amt > 0 && amt < 10000 {
                    return amt
                }
            }
        }

        // 2. OCR 将 "¥" 误读为 "4"：整行形如 "4XX" / "4XX.XX"，去掉首位 "4" 后为实际金额。
        //    例：OCR "¥45.00" → "445" → 修正为 45.00。
        //    要求去除首字符后至少 2 位整数（[1-9][0-9]{1,2}，即 10–999.99 元），
        //    避免误伤极小金额（如 "41" 被修正为 1.00）。
        //    仅匹配整行纯数字/小数，避免误伤含中文的行。
        let yenArtifactPattern = #"^4([1-9][0-9]{1,2}(?:\.[0-9]{1,2})?)$"#
        if let yenRegex = try? NSRegularExpression(pattern: yenArtifactPattern) {
            for line in candidateLines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if let match = yenRegex.firstMatch(in: trimmed, range: nsRange),
                   let range = Range(match.range(at: 1), in: trimmed),
                   let amt = Double(String(trimmed[range])),
                   amt > 0 && amt < 10000 {
                    return amt
                }
            }
        }

        return nil
    }

    // MARK: - 滴滴出行车费图像兜底提取

    /// 当全图 OCR 无法从文本中定位滴滴车费时（例如大字号金额区域漏识别），
    /// 对原始图像的顶部区域（行程结束页的车费显示区）进行局部重识别：
    ///
    /// 策略 1：通过 Vision `regionOfInterest` 仅扫描图像顶部 45%，
    ///          减少低相关区域干扰，适用于 OCR 读取大字号数字时偏移的情形。
    ///
    /// 策略 2：使用 CoreImage 将图像顶部 35% 裁切后 2× 放大，
    ///          再送入 Vision 重新识别，适用于字体装饰性强导致全图识别遗漏的情形。
    ///
    /// 两种策略的提取结果均依次通过：
    ///   1. ¥/￥ 前缀金额；
    ///   2. "¥→4"OCR 误读修正（如 "¥45" → "445"）；
    ///   3. 独立十进制金额行（如 "21.50"）。
    private func extractDidiTripAmountFromImage(data: Data, lines: [String]) -> Double? {
        // 仅在确认为滴滴行程结束页时触发
        guard lines.contains(where: { $0.contains("行程已") }),
              lines.contains(where: { $0.contains("费用明细") }) else { return nil }

        // 策略 1：regionOfInterest 聚焦图像顶部 45%（Vision 坐标系 y=0 在底部）
        if let amt = extractFareFromRegion(data: data,
                                           region: CGRect(x: 0, y: 0.55, width: 1.0, height: 0.45)) {
            return amt
        }

        // 策略 2：CoreImage 裁切顶部 35% 后 2× 放大，再次 OCR
        if let amt = extractFareFromCroppedImage(data: data, topFraction: 0.35, scale: 2.0) {
            return amt
        }

        return nil
    }

    /// 对指定 Vision 归一化矩形区域进行 OCR 并提取车费金额。
    private func extractFareFromRegion(data: Data, region: CGRect) -> Double? {
        let request = makeFareOCRRequest()
        request.regionOfInterest = region

        let handler = VNImageRequestHandler(data: data)
        guard (try? handler.perform([request])) != nil else { return nil }

        let regionText = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        return extractFareFromText(regionText)
    }

    /// 裁切图像顶部指定比例后等比缩放，再对完整裁切图 OCR 并提取车费金额。
    private func extractFareFromCroppedImage(data: Data, topFraction: Double, scale: Double) -> Double? {
        guard let ciImage = CIImage(data: data) else { return nil }
        let size = ciImage.extent
        let cropRect = CGRect(
            x: 0,
            y: size.height * CGFloat(1.0 - topFraction),
            width: size.width,
            height: size.height * CGFloat(topFraction)
        )
        let cropped = ciImage.cropped(to: cropRect)
        let scaled = cropped.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let request = makeFareOCRRequest()
        let handler = VNImageRequestHandler(ciImage: scaled)
        guard (try? handler.perform([request])) != nil else { return nil }

        let croppedText = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        return extractFareFromText(croppedText)
    }

    /// 返回配置好的滴滴车费 OCR 请求（关闭语言校正，避免将纯数字误修正为词汇）。
    private func makeFareOCRRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        return request
    }

    // 滴滴车费局部 OCR 共用的正则模式
    private static let fareCurrencyPattern = #"[¥￥]\s*([0-9]+(?:\.[0-9]{1,2})?)"#
    /// OCR 将"¥"误识别为数字"4"时的修正模式：整行形如"445"或"421.50"，
    /// 去掉首位"4"后还原为实际金额（如 445 → 45，421.50 → 21.50）。
    private static let fareYenArtifactPattern = #"^4([1-9][0-9]{1,2}(?:\.[0-9]{1,2})?)$"#
    private static let fareStandalonePattern = #"^([1-9][0-9]*\.[0-9]{2})$"#

    /// 从局部 OCR 文本中按优先级提取车费金额：
    ///   1. ¥/￥ 前缀金额；
    ///   2. "¥" 被误读为数字 "4" 时的修正（如 OCR "¥45" → "445"，修正回 45）；
    ///   3. 独立十进制金额行（如 "21.50"）。
    private func extractFareFromText(_ text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        let lines = text.components(separatedBy: .newlines)

        // 1. ¥/￥ 前缀金额
        if let cpRegex = try? NSRegularExpression(pattern: Self.fareCurrencyPattern) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = cpRegex.firstMatch(in: text, range: nsRange),
               let range = Range(match.range(at: 1), in: text),
               let amt = Double(String(text[range])),
               amt > 0 && amt < 10000 {
                return amt
            }
        }

        // 2. "¥" 被误读为数字 "4" 时的修正（如 OCR "¥45" → "445"，修正回 45）
        if let yenRegex = try? NSRegularExpression(pattern: Self.fareYenArtifactPattern) {
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if let match = yenRegex.firstMatch(in: trimmed, range: nsRange),
                   let range = Range(match.range(at: 1), in: trimmed),
                   let amt = Double(String(trimmed[range])),
                   amt > 0 && amt < 10000 {
                    return amt
                }
            }
        }

        // 3. 独立十进制金额行（如 "21.50"），要求整数部分 ≥ 1 位
        if let standaloneRegex = try? NSRegularExpression(pattern: Self.fareStandalonePattern) {
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if let match = standaloneRegex.firstMatch(in: trimmed, range: nsRange),
                   let range = Range(match.range(at: 1), in: trimmed),
                   let amt = Double(String(trimmed[range])),
                   amt > 0 && amt < 10000 {
                    return amt
                }
            }
        }

        return nil
    }

    // MARK: - 滴滴出行结束订单页解析

    /// 滴滴出行识别：
    /// A. 结束订单页 — 含"行程已"（行程已结束，OCR 可能误读为"行程已给束"等）
    ///    且含滴滴车型关键词（快车、专车等）或"呼叫返程"。
    /// B. 支付通知截图 — 含"滴滴" + "已支付"（来自通知中心的支付完成推送）
    /// C. 微信支付扣费凭证 — 含"滴滴" + "扣费凭证"（先乘车后付款的微信代扣卡片）
    private func parseDidiTrip(lines: [String]) -> String? {
        // A. 行程结束页
        let hasTripEnd = lines.contains(where: { $0.contains("行程已") })
        let didiSignals = ["快车", "专车", "优享", "豪华车", "顺风车", "两轮车", "呼叫返程"]
        let hasSignal = lines.contains(where: { line in
            didiSignals.contains(where: { line.contains($0) })
        })
        if hasTripEnd && hasSignal { return "滴滴出行" }

        // B. 通知截图："滴滴" + "已支付"
        let hasDidi = lines.contains(where: { $0.contains("滴滴") })
        let hasPaid = lines.contains(where: { $0.contains("已支付") })
        if hasDidi && hasPaid { return "滴滴出行" }

        // C. 微信支付扣费凭证（先乘车后付款）："滴滴" + "扣费凭证"
        let hasDeductionVoucher = lines.contains(where: { $0.contains("扣费凭证") })
        if hasDidi && hasDeductionVoucher { return "滴滴出行" }

        return nil
    }

    // MARK: - 微信支付详情页 label-block → value-block 解析

    /// 微信支付交易详情页的 OCR 输出通常为：标签连续排列（当前状态、支付时间、商户全称…），
    /// 之后是对应值按相同顺序排列。此方法检测该结构并提取商户名和支付时间。
    /// 页面标题可能为"交易详情"（从账单列表点入）或"全部账单"（从微信支付主页点入）。
    private func parseWeChatDetailBlock(lines: [String]) -> (merchant: String?, date: Date?)? {
        let isWeChatPage = lines.contains(where: { $0.contains("交易详情") || $0.contains("全部账单") })
        guard isWeChatPage else { return nil }
        let normalizedLines = mergeWrappedParenthesisLines(lines)

        let knownLabels: Set<String> = [
            "当前状态", "支付时间", "商品", "商户全称", "收单机构",
            "支付方式", "交易单号", "商户单号", "备注"
        ]

        // 找最长的连续标签块
        var bestRun: [(index: Int, label: String)] = []
        var currentRun: [(index: Int, label: String)] = []

        for (i, line) in normalizedLines.enumerated() {
            if knownLabels.contains(line) {
                currentRun.append((i, line))
            } else {
                if currentRun.count > bestRun.count { bestRun = currentRun }
                currentRun = []
            }
        }
        if currentRun.count > bestRun.count { bestRun = currentRun }

        guard bestRun.count >= 3, let lastLabelIdx = bestRun.last?.index else { return nil }

        let valueStart = lastLabelIdx + 1
        var merchant: String?
        var productName: String?   // value of 商品 label, used as fallback
        var date: Date?

        // Bare POS terminal ID pattern, e.g. （8285）— a payment terminal number, not a merchant name
        let terminalIDPattern = #"^[（(]\s*\d+\s*[）)]$"#
        let terminalIDRegex = try? NSRegularExpression(pattern: terminalIDPattern)

        for (offset, item) in bestRun.enumerated() {
            let valueIdx = valueStart + offset
            guard valueIdx < normalizedLines.count else { break }
            let value = normalizedLines[valueIdx]

            if item.label == "商户全称" && !value.isEmpty {
                let isTerminalID = terminalIDRegex?
                    .firstMatch(in: value, range: NSRange(value.startIndex..<value.endIndex, in: value)) != nil
                if !isTerminalID {
                    merchant = value
                }
            }
            if item.label == "商品" && !value.isEmpty {
                productName = value
            }
            if item.label == "支付时间" && !value.isEmpty {
                date = AppFormatters.parseFlexibleDate(value)
            }
        }

        // When 商户全称 was a bare terminal ID (or absent), try the display merchant shown above
        // the amount. Some mini-program pages put a UI title such as "• 交易详情" right there, so
        // scan upward through nearby lines and filter known WeChat chrome/noise before falling
        // back to the 商品 value.
        if merchant == nil {
            let negAmountPattern = #"^\s*-[0-9]+(?:\.[0-9]{1,2})?\s*$"#
            if let negRegex = try? NSRegularExpression(pattern: negAmountPattern),
               let negIdx = normalizedLines.indices.first(where: { i in
                   let ln = normalizedLines[i]
                   return negRegex.firstMatch(in: ln, range: NSRange(ln.startIndex..<ln.endIndex, in: ln)) != nil
               }),
               negIdx > 0 {
                merchant = nearbyWeChatDisplayMerchant(before: negIdx, in: normalizedLines, knownLabels: knownLabels)
            }
            if merchant == nil {
                merchant = productName
            }
        }

        return (merchant, date)
    }

    private func nearbyWeChatDisplayMerchant(
        before amountIndex: Int,
        in lines: [String],
        knownLabels: Set<String>
    ) -> String? {
        let lowerBound = max(0, amountIndex - 12)
        for index in stride(from: amountIndex - 1, through: lowerBound, by: -1) {
            if let candidate = cleanedWeChatDisplayMerchantCandidate(lines[index], knownLabels: knownLabels) {
                return candidate
            }
        }
        return nil
    }

    private func cleanedWeChatDisplayMerchantCandidate(_ value: String, knownLabels: Set<String>) -> String? {
        let candidate = value
            .replacingOccurrences(of: #"^[·•\-\s]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "＞>》")))

        guard candidate.count >= 2 else { return nil }
        guard !knownLabels.contains(candidate) else { return nil }
        guard amountCandidate(in: candidate) == nil else { return nil }
        guard candidate.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { return nil }

        let skipContains = [
            "交易详情", "订单详情", "账单详情", "付款详情", "支付详情",
            "当前状态", "支付时间", "支付成功", "服务", "小程序",
            "喜欢", "拼着买才便宜", "查看", "商家订单"
        ]
        guard !skipContains.contains(where: { candidate.contains($0) }) else { return nil }

        return candidate
    }

    /// 合并被 OCR 拆成多行的括号内容，避免标签块值映射被换行错位。
    /// 例如："天津市...（个" + "Fictional Sole Proprietor" -> "天津市...（个Fictional Sole Proprietor"。
    /// 同时合并因行宽限制被拆开的公司全称后缀，
    /// 例如："Example Convenience Store" + "公司" -> "Example Convenience Store"。
    private func mergeWrappedParenthesisLines(_ lines: [String]) -> [String] {
        var merged: [String] = []
        var index = 0

        while index < lines.count {
            var current = lines[index]
            var balance = parenthesisBalance(current)
            var lookahead = index + 1

            while balance > 0, lookahead < lines.count {
                current += lines[lookahead]
                balance += parenthesisBalance(lines[lookahead])
                lookahead += 1
            }

            // 公司全称被 OCR 在"有限"后换行（如"Example Convenience Store" + "公司"）时合并。
            if lookahead < lines.count && current.hasSuffix("有限") {
                current += lines[lookahead]
                lookahead += 1
            }

            merged.append(current)
            index = lookahead
        }

        return merged
    }

    private func parenthesisBalance(_ line: String) -> Int {
        let openings = line.reduce(into: 0) { partialResult, ch in
            if ch == "（" || ch == "(" { partialResult += 1 }
        }
        let closings = line.reduce(into: 0) { partialResult, ch in
            if ch == "）" || ch == ")" { partialResult += 1 }
        }
        return openings - closings
    }

    // MARK: - 微信代扣凭证页解析

    /// 微信代扣卡片（先购后付、先用后付等自动扣费服务）的典型特征：
    /// - 含"扣费凭证"
    /// - 含"扣费内容"标签
    /// 商户名优先取"扣费内容"标签后的第一个有效值行（如"先购后付"），
    /// 跳过公司名后缀行（如单独出现的"公司"，常见于两列布局 OCR 拆分）。
    /// 若无"扣费内容"，则取"扣费凭证"上方的公司名行作为商户名。
    private func parseWeChatDeductionVoucher(lines: [String]) -> String? {
        guard lines.contains(where: { $0.contains("扣费凭证") }) else { return nil }

        // 公司名后缀行（单独成行时是上一行拆分的延续，不是服务内容）
        let companySuffixes: Set<String> = ["公司", "有限公司", "责任公司"]
        // 遇到这些行时停止向后搜索
        let stopLabels: Set<String> = ["扣费凭证", "扣费服务", "扣费内容",
                                       "查看订单详情", "我的账单", "支付服务"]

        // 优先取"扣费内容"后的值行
        if let contentIdx = lines.indices.first(where: { lines[$0] == "扣费内容" }) {
            for i in (contentIdx + 1) ..< lines.count {
                let line = lines[i]
                if stopLabels.contains(line) { break }
                if companySuffixes.contains(line) { continue }
                if !line.isEmpty && line.count >= 2 {
                    return line
                }
            }
        }

        // 次选：扣费凭证上方的公司/商户名行
        if let voucherIdx = lines.indices.first(where: { lines[$0].contains("扣费凭证") }),
           voucherIdx > 0 {
            let candidate = lines[voucherIdx - 1]
            if !candidate.isEmpty && candidate.count >= 2
                && amountCandidate(in: candidate) == nil {
                return candidate
            }
        }

        return nil
    }

    // MARK: - 淘宝闪购订单进行中页解析

    /// 淘宝闪购（即时配送）订单进行中页的典型特征：
    /// - 含"骑士"（骑手配送状态），如"骑士正赶往商家"
    /// - 含独立的"闪购"标签行
    /// 商户名通常紧跟在"闪购"标签后出现，格式为"XXX（地址信息）＞"（带导航箭头）。
    /// 此方法在"闪购"行之后逐行搜索，取第一个含中文全角括号"（"的行作为店铺名，
    /// 并剥离尾部导航箭头（＞/>）后返回。
    private func parseTaobaoFlashOrder(lines: [String]) -> String? {
        guard lines.contains(where: { $0.contains("骑士") }),
              lines.contains(where: { $0.contains("闪购") }) else { return nil }

        guard let flashIdx = lines.indices.first(where: { lines[$0].contains("闪购") }) else {
            return nil
        }

        // 噪声行关键词（价格/操作按钮/骑手状态行，不会是店铺名）
        let noiseKeywords = ["价格明细", "总优惠", "实付", "备注", "订单号", "订单信息",
                             "催单", "取消订单", "联系", "骑士", "客服", "复制", "常见问题"]

        // 在"闪购"行之后搜索店铺名称行
        // 店铺名特征：含中文全角括号"（xxx）"的地址格式（如"Sample Restaurant（Example Branch）＞"）
        for i in (flashIdx + 1)..<lines.count {
            let line = lines[i]
            guard !line.isEmpty, line.count >= 3 else { continue }
            guard !noiseKeywords.contains(where: { line.contains($0) }) else { continue }
            guard amountCandidate(in: line) == nil else { continue }

            if line.contains("（") {
                return line
                    .trimmingCharacters(in: CharacterSet(charactersIn: "＞>》"))
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }
}
