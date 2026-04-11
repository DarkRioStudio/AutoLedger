import Foundation

public struct ReceiptParser: Sendable {
    public init() {}

    public func parse(text: String, source: ReceiptSource, fallbackMerchant: String? = nil) -> ImportedReceipt? {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let amount = extractAmount(from: normalized) else {
            return nil
        }

        let cleanedLines = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 微信支付详情页：标签块→值块格式，优先提取商户全称和支付时间
        let wechatDetail = parseWeChatDetailBlock(lines: cleanedLines)

        // 抖音团购券码页：从"适用门店"区块提取门店名称
        let douyinMerchant = parseDouyinVoucher(lines: cleanedLines)

        // 滴滴出行结束订单页：含"行程已结束"特征，直接返回"滴滴出行"
        let didiMerchant = parseDidiTrip(lines: cleanedLines)

        let merchant = wechatDetail?.merchant
            ?? douyinMerchant
            ?? didiMerchant
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
        // 支持两种 OCR 版式：
        //   (A) 独立行 "地铁：" + 金额行 + 站点行（如 "ExampleStationA ExampleStationB"）
        //   (B) 同一行 "地铁：ExampleStationA ExampleStationB"
        let transitKeywords: Set<String> = ["地铁", "公交"]
        for (idx, line) in lines.enumerated() {
            // 用 rangeOfCharacter 找第一个冒号，避免多次分割时字符类型不一致
            guard let colonRange = line.rangeOfCharacter(from: CharacterSet(charactersIn: ":：")) else { continue }
            let label = String(line[line.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard transitKeywords.contains(label) else { continue }
            let inlinePart = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let stationText: String
            if !inlinePart.isEmpty {
                // (B) 同一行：地铁：ExampleStationA ExampleStationB
                stationText = inlinePart
            } else {
                // (A) 独立 "地铁：" 行 — 向后查找站点行（跳过金额行）
                guard let stationLine = lines.dropFirst(idx + 1).first(where: { sl in
                    !sl.isEmpty && amountCandidate(in: sl) == nil
                }) else { continue }
                stationText = stationLine
            }
            // 将 "ExampleStationA ExampleStationB" 规范化为 "ExampleStationA → ExampleStationB"
            let route: String
            if stationText.contains("→") || stationText.contains("->") {
                route = stationText
            } else {
                let stations = stationText.components(separatedBy: " ").filter { !$0.isEmpty }
                route = stations.count >= 2 ? stations.joined(separator: " → ") : stationText
            }
            return "\(label)：\(route)"
        }

        // 跳过纯时间、纯数字、极短行、平台 UI 文案
        let skipContainsFallback = ["成功", "金额", "时间", "Total", "全部账单",
                                     "可在支持的商户", "扫码退款", "收单机构", "账单详情"]
        let timePattern = #"^\s*\d{1,2}:\d{2,3}\s*$"#
        let pureNumberPattern = #"^\s*\d{1,5}\s*$"#
        return lines.first(where: { line in
            !skipContainsFallback.contains(where: { line.contains($0) }) &&
            !fieldLabels.contains(line) &&
            line.count >= 2 &&
            // 跳过无实质字母内容的行（如 "：！⑤"，来自系统通知徽标的 OCR 噪声）
            line.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) &&
            amountCandidate(in: line) == nil &&
            (try? NSRegularExpression(pattern: timePattern))?
                .firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) == nil &&
            (try? NSRegularExpression(pattern: pureNumberPattern))?
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

    // MARK: - 滴滴出行结束订单页解析

    /// 滴滴出行结束订单页识别：
    /// 特征：含"行程已"（行程已结束，OCR 可能误读为"行程已给束"等）
    /// 且含滴滴车型关键词（快车、专车等）或"呼叫返程"。
    private func parseDidiTrip(lines: [String]) -> String? {
        let hasTripEnd = lines.contains(where: { $0.contains("行程已") })
        let didiSignals = ["快车", "专车", "优享", "豪华车", "顺风车", "两轮车", "呼叫返程"]
        let hasSignal = lines.contains(where: { line in
            didiSignals.contains(where: { line.contains($0) })
        })
        guard hasTripEnd && hasSignal else { return nil }
        return "滴滴出行"
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
}
