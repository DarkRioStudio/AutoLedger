import Foundation

public struct ReceiptParser: Sendable {
    public init() {}

    public func parse(text: String, source: ReceiptSource, fallbackMerchant: String? = nil) -> ImportedReceipt? {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanedLines = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 滴滴行程结束页：优先使用专用金额提取器，避免将评价人数等无关数字误识别为车费
        let amount: Double
        if let didiAmt = extractDidiTripAmount(lines: cleanedLines) {
            amount = didiAmt
        } else if let genericAmt = extractAmount(from: normalized) {
            amount = genericAmt
        } else {
            return nil
        }

        // 微信支付详情页：标签块→值块格式，优先提取商户全称和支付时间
        let wechatDetail = parseWeChatDetailBlock(lines: cleanedLines)

        // 抖音团购券码页：从"适用门店"区块提取门店名称
        let douyinMerchant = parseDouyinVoucher(lines: cleanedLines)

        // 滴滴出行结束订单页：含"行程已结束"特征，直接返回"滴滴出行"
        let didiMerchant = parseDidiTrip(lines: cleanedLines)

        // 淘宝闪购订单进行中页：含"骑士"+"闪购"，从"闪购"标签后提取店铺名
        let taobaoFlashMerchant = parseTaobaoFlashOrder(lines: cleanedLines)

        // 微信代扣凭证页：含"扣费凭证"+"扣费内容"，提取服务内容名称（如"先购后付"）
        let wechatDeductionMerchant = parseWeChatDeductionVoucher(lines: cleanedLines)

        let merchant = wechatDetail?.merchant
            ?? douyinMerchant
            ?? didiMerchant
            ?? taobaoFlashMerchant
            ?? wechatDeductionMerchant
            ?? extractMerchant(from: normalized, source: source)
            ?? fallbackMerchant
            ?? "待确认商户"
        let date = wechatDetail?.date
            ?? extractDate(from: normalized)
            ?? .now
        let category = TransactionCategory.infer(from: "\(merchant)\n\(normalized)")

        return ImportedReceipt(
            source: source,
            merchant: merchant,
            amount: amount,
            occurredAt: date,
            rawText: normalized,
            summary: "\(source.title) OCR 解析草稿",
            confidence: wechatDetail != nil ? 0.90 : 0.82,
            suggestedCategory: category
        )
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

        // 带 ¥/￥ 前缀的行优先
        let currencyPrefixPattern = #"[¥￥]\s*([0-9]+(?:\.[0-9]{1,2})?)"#

        // 实付/实际支付行最优先（外卖、电商常有优惠前金额干扰）
        let actualPayKeywords = ["实付", "实际支付", "实际付款", "合计支付"]
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

        // 关键词行回退
        let keywords = ["金额", "支付", "总计", "总额", "实际支付", "Price", "Total", "CNY", "RMB"]
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
        // 跳过疑似状态栏时间/信号格式，如 "10:131" 或 "9:41"
        let timeOnlyPattern = #"^\s*\d{1,2}:\d{2,3}\s*$"#
        if (try? NSRegularExpression(pattern: timeOnlyPattern))?
            .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil {
            return nil
        }

        let pattern = #"(?:(?:¥|￥|RMB|CNY)\s*)?([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = regex.matches(in: line, range: nsRange)

        let candidates = matches.compactMap { match -> Double? in
            guard let range = Range(match.range(at: 1), in: line) else {
                return nil
            }
            return Double(String(line[range]))
        }

        return candidates
            .filter { $0 < 100000 }
            .sorted(by: >)
            .first
    }

    /// 判断字符串是否是一个独立的金额（整行基本就是货币符号 + 数字）。
    /// 例如 "CN¥7.00"、"CN￥3.60"（全角￥）、"¥2.70"、"CNY 3.50" 均返回 true；
    /// "T2航站楼"、"3号线"、"萧山国际机场" 等含有非数字字符的站名返回 false。
    private func isStandaloneAmount(_ string: String) -> Bool {
        // CN¥ 为半角（U+00A5），CN￥ 为全角（U+FFE5），OCR 可能混用，均需支持
        let pattern = #"^\s*(?:CN¥|CN￥|¥|￥|CNY|RMB)\s*[0-9]+(?:\.[0-9]{1,2})?\s*$"#
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
            "当前状态", "支付时间", "商品", "备注", "附言"
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
        //   (A) 独立行 "地铁：" + 金额行 + 站点行（如 "内江路 东丽文体中心"）
        //   (B) 同一行 "地铁：内江路 东丽文体中心"
        //   (C) 同一行 "地铁：CN¥7.00"（金额嵌入冒号后）+ 下一行站点（如 "萧山国际机场 -火车东站"）
        let transitKeywords: Set<String> = ["地铁", "公交"]
        for (idx, line) in lines.enumerated() {
            // 用 rangeOfCharacter 找第一个冒号，避免多次分割时字符类型不一致
            guard let colonRange = line.rangeOfCharacter(from: CharacterSet(charactersIn: ":：")) else { continue }
            let label = String(line[line.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard transitKeywords.contains(label) else { continue }
            let inlinePart = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let stationText: String
            if !inlinePart.isEmpty && !isStandaloneAmount(inlinePart) {
                // (B) 同一行：地铁：内江路 东丽文体中心（内联部分不是独立金额）
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

        // 抖音直播状态前缀可能粘连在门店名之前（如 "U 直播中麦当劳（怒江道店）"）
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
    private func parseWeChatDetailBlock(lines: [String]) -> (merchant: String?, date: Date?)? {
        guard lines.contains(where: { $0.contains("交易详情") }) else { return nil }

        let knownLabels: Set<String> = [
            "当前状态", "支付时间", "商品", "商户全称", "收单机构",
            "支付方式", "交易单号", "商户单号", "备注"
        ]

        // 找最长的连续标签块
        var bestRun: [(index: Int, label: String)] = []
        var currentRun: [(index: Int, label: String)] = []

        for (i, line) in lines.enumerated() {
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
        var date: Date?

        for (offset, item) in bestRun.enumerated() {
            let valueIdx = valueStart + offset
            guard valueIdx < lines.count else { break }
            let value = lines[valueIdx]

            if item.label == "商户全称" && !value.isEmpty {
                merchant = value
            }
            if item.label == "支付时间" && !value.isEmpty {
                date = AppFormatters.parseFlexibleDate(value)
            }
        }

        return (merchant, date)
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
        // 店铺名特征：含中文全角括号"（xxx）"的地址格式（如"和府捞面（杭州空港新天地卫星店）＞"）
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
