import Foundation
import Darwin

final class RegressionReporter {
    private(set) var failures: [String] = []

    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            print("PASS: \(message)")
        } else {
            failures.append(message)
            print("FAIL: \(message)")
        }
    }

    func finish() -> Never {
        if failures.isEmpty {
            print("Offline regression passed.")
            exit(EXIT_SUCCESS)
        }

        print("Offline regression failed with \(failures.count) issue(s):")
        for failure in failures {
            print("- \(failure)")
        }
        exit(EXIT_FAILURE)
    }
}

@main
struct OfflineRegression {
    static func main() async throws {
        let reporter = RegressionReporter()
        let parser = ReceiptParser()
        let sampleProvider = SampleReceiptProvider()

        verifySampleParsing(using: parser, samples: sampleProvider.samples, reporter: reporter)
        verifyVoiceLedgerParsing(reporter: reporter)
        verifyLedgerTextInterpreterCore(reporter: reporter)
        verifySubscriptionDetection(reporter: reporter)
        try verifySQLiteRoundTrip(reporter: reporter)
        try await verifyLedgerImportFlow(using: reporter)
        try verifyBackupRoundTrip(reporter: reporter)

        reporter.finish()
    }

    private static func verifyVoiceLedgerParsing(reporter: RegressionReporter) {
        let fixedNow = AppFormatters.parseFlexibleDate("2026-04-26 12:00") ?? Date(timeIntervalSince1970: 0)
        let parser = VoiceLedgerParser(now: { fixedNow })

        let lunch = parser.parse("午饭 28")
        reporter.check(lunch.confidence == .high, "VoiceLedgerParser marks simple lunch as high confidence")
        reporter.check(lunch.merchant == "午饭", "VoiceLedgerParser extracts lunch merchant")
        reporter.check(abs((lunch.amount ?? 0) - 28) < 0.001, "VoiceLedgerParser extracts lunch amount")
        reporter.check(lunch.category == .dining, "VoiceLedgerParser infers dining category")

        let taxi = parser.parse("昨天打车 23.8")
        let expectedYesterday = AppFormatters.parseFlexibleDate("2026-04-25 12:00") ?? fixedNow
        reporter.check(taxi.confidence == .high, "VoiceLedgerParser marks taxi as high confidence")
        reporter.check(taxi.category == .transport, "VoiceLedgerParser infers transport category")
        reporter.check(sameMinute(taxi.occurredAt, expectedYesterday), "VoiceLedgerParser resolves yesterday")

        let multiAmount = parser.parse("今天花了 20 和 30")
        reporter.check(multiAmount.confidence == .failed, "VoiceLedgerParser rejects multiple amounts")
        reporter.check(multiAmount.failureReason == .multipleAmounts, "VoiceLedgerParser reports multiple amount reason")

        let income = parser.parse("收到报销 200")
        reporter.check(income.confidence == .failed, "VoiceLedgerParser rejects income/refund phrases")
        reporter.check(income.failureReason == .unsupportedIncomeOrTransfer, "VoiceLedgerParser reports income/transfer reason")

        let noAmount = parser.parse("午饭")
        reporter.check(noAmount.confidence == .failed, "VoiceLedgerParser rejects text without amount")
        reporter.check(noAmount.failureReason == .noAmount, "VoiceLedgerParser reports no amount reason")
    }

    private static func verifyLedgerTextInterpreterCore(reporter: RegressionReporter) {
        let gate = BillRelevanceGate()
        let billText = """
        支付宝
        交易成功
        商户：测试咖啡
        金额：￥12.50
        """
        let billResult = gate.evaluate(billText, sourceHint: .payment)
        reporter.check(billResult.isRelevant, "BillRelevanceGate accepts payment-like OCR text")

        let nonBillText = """
        今天风很大
        记得下班后买牛奶
        """
        let nonBillResult = gate.evaluate(nonBillText)
        reporter.check(!nonBillResult.isRelevant, "BillRelevanceGate rejects unrelated text")

        let interpreter = LedgerTextInterpreterCore()
        let nonBillInterpretation = interpreter.interpret(
            InterpretInput(rawText: nonBillText, sourceType: .ocr)
        )
        reporter.check(nonBillInterpretation.draft == nil, "LedgerTextInterpreterCore does not draft non-bill image text")
        reporter.check(nonBillInterpretation.warnings.contains(.nonBillImage), "LedgerTextInterpreterCore reports nonBillImage")

        let voiceInterpretation = interpreter.interpret(
            InterpretInput(rawText: "午饭 28 元", sourceType: .voice)
        )
        reporter.check(voiceInterpretation.draft?.merchant == "午饭", "LedgerTextInterpreterCore drafts voice merchant")
        reporter.check(abs((voiceInterpretation.draft?.amount ?? 0) - 28) < 0.001, "LedgerTextInterpreterCore drafts voice amount")

        let noisyAmountText = """
        支付宝
        交易成功
        1
        数量 1
        商户：测试咖啡
        支付金额：23.80
        """
        let noisyAmountInterpretation = interpreter.interpret(
            InterpretInput(
                rawText: noisyAmountText,
                sourceType: .ocr,
                hints: LedgerInterpretHints(sourceHint: .payment)
            )
        )
        reporter.check(
            abs((noisyAmountInterpretation.draft?.amount ?? 0) - 23.80) < 0.001,
            "LedgerTextInterpreterCore ignores OCR list/quantity numbers before amount"
        )
    }

    private static func verifySubscriptionDetection(reporter: RegressionReporter) {
        let detector = SubscriptionDetector()
        let base = AppFormatters.parseFlexibleDate("2026-01-05 09:00") ?? .now
        let calendar = Calendar(identifier: .gregorian)

        func date(monthOffset: Int) -> Date {
            calendar.date(byAdding: .month, value: monthOffset, to: base) ?? base
        }

        let transactions = [
            Transaction(
                merchant: "Apple Services",
                amount: 28,
                occurredAt: date(monthOffset: 0),
                category: .digital,
                source: .appStore,
                note: "订阅"
            ),
            Transaction(
                merchant: "Apple Services",
                amount: 28,
                occurredAt: date(monthOffset: 1),
                category: .digital,
                source: .appStore,
                note: "订阅"
            ),
            Transaction(
                merchant: "麦当劳",
                amount: 19.9,
                occurredAt: date(monthOffset: 0),
                category: .dining,
                source: .alipay,
                note: "午餐"
            ),
            Transaction(
                merchant: "麦当劳",
                amount: 19.9,
                occurredAt: date(monthOffset: 1),
                category: .dining,
                source: .alipay,
                note: "午餐"
            ),
            Transaction(
                merchant: "地铁：内江路 → 东丽文体中心",
                amount: 2.7,
                occurredAt: date(monthOffset: 0),
                category: .transport,
                source: .manual,
                note: "地铁"
            ),
            Transaction(
                merchant: "地铁：内江路 → 东丽文体中心",
                amount: 2.7,
                occurredAt: date(monthOffset: 1),
                category: .transport,
                source: .manual,
                note: "地铁"
            )
        ]

        let detected = detector.detectFromHistory(transactions)
        reporter.check(detected.contains { $0.merchant == "Apple Services" }, "SubscriptionDetector scans digital service subscriptions")
        reporter.check(!detected.contains { $0.merchant == "麦当劳" }, "SubscriptionDetector excludes dining transactions")
        reporter.check(!detected.contains { $0.merchant.contains("地铁") }, "SubscriptionDetector excludes transport transactions")
    }

    private static func verifySampleParsing(
        using parser: ReceiptParser,
        samples: [SampleReceipt],
        reporter: RegressionReporter
    ) {
        let expectedDates: [String: String] = [
            "微信买菜截图": "2026-03-26 19:42",
            "微信支付详情个体工商户跨行截图": "2026-04-13 16:42:09",
            "支付宝出行截图": "2026-03-25 08:10",
            "App Store 订阅截图": "2026-03-22 12:14",
            "微信支付全部账单截图（7-11）": "2026-04-20 18:17:58",
            "云闪付账单详情截图": "2026-04-21 18:46:58"
        ]

        let expectedMerchants: [String: String] = [
            "微信买菜截图": "盒马鲜生",
            "微信支付详情个体工商户跨行截图": "宜春市赵一鸣商贸有限公司",
            "支付宝出行截图": "滴滴出行",
            "App Store 订阅截图": "Apple Services",
            "天津地铁储值卡截图": "地铁：内江路 → 东丽文体中心",
            "互联互通城市卡CN¥嵌入格式截图": "地铁：萧山国际机场 → 火车东站",
            "抖音团购麦当劳截图": "麦当劳（怒江道店）",
            "支付宝碰一下支付截图（7-11）": "柒一拾壹（天津）商业有限公司",
            "滴滴出行结束订单截图": "滴滴出行",
            "滴滴出行通知截图": "滴滴出行",
            "滴滴出行优享出租车截图": "滴滴出行",
            "滴滴出行微信扣费凭证截图": "滴滴出行",
            "支付宝麦当劳支付成功截图": "麦当劳湖州德清米兰洲际酒店餐厅",
            "淘宝闪购订单进行中截图": "和府捞面（杭州空港新天地卫星店）",
            "微信支付全部账单截图（7-11）": "柒一拾壹（天津）商业有限公司",
            "云闪付付款成功截图": "瑞幸咖啡（杭州东站店）",
            "云闪付账单详情截图": "小谷姐姐麻辣烫（利津路店）",
            "银联二维码支付详情截图": "罗森便利店（南京西路店）",
            "英文超市纸质小票TOTAL": "NTUC FAIRPRICE",
            "英文超市纸质小票无TOTAL": "WALMART"
        ]

        let expectedAmounts: [String: Double] = [
            "微信买菜截图": 86.30,
            "微信支付详情个体工商户跨行截图": 6.15,
            "支付宝出行截图": 23.80,
            "App Store 订阅截图": 28.00,
            "天津地铁储值卡截图": 2.70,
            "互联互通城市卡CN¥嵌入格式截图": 7.00,
            "抖音团购麦当劳截图": 26.90,
            "支付宝碰一下支付截图（7-11）": 4.30,
            "滴滴出行结束订单截图": 19.60,
            "滴滴出行通知截图": 9.70,
            "滴滴出行优享出租车截图": 45.00,
            "滴滴出行微信扣费凭证截图": 24.90,
            "支付宝麦当劳支付成功截图": 60.80,
            "淘宝闪购订单进行中截图": 47.4,
            "微信支付全部账单截图（7-11）": 16.80,
            "云闪付付款成功截图": 18.60,
            "云闪付账单详情截图": 13.52,
            "银联二维码支付详情截图": 12.80,
            "英文超市纸质小票TOTAL": 12.30,
            "英文超市纸质小票无TOTAL": 7.10
        ]

        let expectedCategories: [String: TransactionCategory] = [
            "微信买菜截图": .groceries,
            "微信支付详情个体工商户跨行截图": .groceries,
            "支付宝出行截图": .transport,
            "App Store 订阅截图": .digital,
            "天津地铁储值卡截图": .transport,
            "互联互通城市卡CN¥嵌入格式截图": .transport,
            "抖音团购麦当劳截图": .dining,
            "支付宝碰一下支付截图（7-11）": .other,
            "滴滴出行结束订单截图": .transport,
            "滴滴出行通知截图": .transport,
            "滴滴出行优享出租车截图": .transport,
            "滴滴出行微信扣费凭证截图": .transport,
            "支付宝麦当劳支付成功截图": .dining,
            "淘宝闪购订单进行中截图": .dining,
            "微信支付全部账单截图（7-11）": .other,
            "云闪付付款成功截图": .dining,
            "云闪付账单详情截图": .dining,
            "银联二维码支付详情截图": .groceries,
            "英文超市纸质小票TOTAL": .groceries,
            "英文超市纸质小票无TOTAL": .groceries
        ]

        for sample in samples {
            guard let receipt = parser.parse(text: sample.rawText, source: sample.source) else {
                reporter.check(false, "\(sample.title) should parse successfully")
                continue
            }

            reporter.check(receipt.source == sample.source, "\(sample.title) source matches")
            reporter.check(receipt.merchant == expectedMerchants[sample.title], "\(sample.title) merchant matches")
            reporter.check(abs(receipt.amount - (expectedAmounts[sample.title] ?? 0)) < 0.001, "\(sample.title) amount matches")
            let expectedCategory = expectedCategories[sample.title]
            reporter.check(
                receipt.suggestedCategory == expectedCategory,
                "\(sample.title) category matches (got \(receipt.suggestedCategory.rawValue), expected \(expectedCategory?.rawValue ?? "nil"))"
            )

            if sample.title == "英文超市纸质小票TOTAL" {
                reporter.check(receipt.parseDiagnostics?.isMultiItemReceipt == true, "英文超市纸质小票TOTAL flagged as receipt")
                reporter.check(receipt.parseDiagnostics?.totalMatched == true, "英文超市纸质小票TOTAL matches TOTAL")
                reporter.check(receipt.merchant != "FRESH MILK", "英文超市纸质小票TOTAL does not use first item as merchant")
            }

            if sample.title == "英文超市纸质小票无TOTAL" {
                reporter.check(receipt.parseDiagnostics?.isMultiItemReceipt == true, "英文超市纸质小票无TOTAL flagged as receipt")
                reporter.check(receipt.parseDiagnostics?.totalMatched == false, "英文超市纸质小票无TOTAL stays low confidence")
                reporter.check(receipt.confidence < 0.5, "英文超市纸质小票无TOTAL confidence stays low")
            }

            if let expectedDate = expectedDates[sample.title],
               let parsedDate = AppFormatters.parseFlexibleDate(expectedDate) {
                reporter.check(
                    sameMinute(receipt.occurredAt, parsedDate),
                    "\(sample.title) date matches"
                )
            }
            // Skip date check for samples that have no expected date fixture.
        }
    }

    private static func verifySQLiteRoundTrip(reporter: RegressionReporter) throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerOfflineRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let store = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "offline.sqlite3")
        let transaction = Transaction(
            merchant: "离线回归商户",
            amount: 12.50,
            occurredAt: AppFormatters.parseFlexibleDate("2026-03-27 09:15") ?? .now,
            category: .dining,
            source: .alipay,
            note: "offline regression"
        )
        try store.save(transaction: transaction)

        let loaded = try store.loadTransactions()
        reporter.check(loaded.contains(transaction), "SQLite save/load retains inserted transaction")

        let updated = Transaction(
            id: transaction.id,
            merchant: "离线回归商户-更新",
            amount: 13.37,
            occurredAt: AppFormatters.parseFlexibleDate("2026-03-27 10:20") ?? .now,
            category: .shopping,
            source: .wechat,
            note: "updated note"
        )
        try store.update(transaction: updated)

        let reloaded = try store.loadTransactions()
        reporter.check(reloaded.contains(updated), "SQLite update persists modified transaction")

        try store.delete(transactionID: updated.id)
        let activeAfterDelete = try store.loadTransactions()
        let deletedAfterDelete = try store.loadDeletedTransactions()
        reporter.check(!activeAfterDelete.contains(updated), "SQLite soft delete hides transaction from active load")
        reporter.check(deletedAfterDelete.contains(updated), "SQLite soft delete exposes transaction in deleted load")

        let reopenedStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "offline.sqlite3")
        let reopenedDeleted = try reopenedStore.loadDeletedTransactions()
        reporter.check(reopenedDeleted.contains(updated), "SQLite deleted transactions survive store reopen")

        try store.restoreTransaction(id: updated.id)
        let activeAfterRestore = try store.loadTransactions()
        reporter.check(activeAfterRestore.contains(updated), "SQLite restore returns transaction to active load")

        try store.delete(transactionID: updated.id)
        try store.permanentlyDeleteTransaction(id: updated.id)
        let activeAfterPermanentDelete = try store.loadTransactions()
        let deletedAfterPermanentDelete = try store.loadDeletedTransactions()
        reporter.check(
            !activeAfterPermanentDelete.contains(updated) && !deletedAfterPermanentDelete.contains(updated),
            "SQLite permanent delete removes transaction completely"
        )

        let subscription = Subscription(
            merchant: "离线订阅",
            planName: "月度会员",
            period: .monthly,
            amount: 18.00,
            lastChargedAt: AppFormatters.parseFlexibleDate("2026-03-01 09:00") ?? .now
        )
        try store.saveSubscription(subscription)
        let persistedSubscription = try store.loadSubscriptions().first { $0.id == subscription.id } ?? subscription

        let editedSubscription = Subscription(
            id: persistedSubscription.id,
            merchant: "离线订阅 Pro",
            planName: "年度对比会员",
            period: .yearly,
            amount: 188.00,
            lastChargedAt: persistedSubscription.lastChargedAt,
            nextChargedAt: AppFormatters.parseFlexibleDate("2027-03-01 09:00") ?? persistedSubscription.nextChargedAt,
            createdAt: persistedSubscription.createdAt
        )
        try store.updateSubscription(editedSubscription)

        let loadedSubscriptions = try store.loadSubscriptions()
        reporter.check(
            loadedSubscriptions.contains(editedSubscription),
            "SQLite subscription update persists edited fields"
        )
    }

    private static func verifyLedgerImportFlow(using reporter: RegressionReporter) async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerLedgerRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let store = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger.sqlite3")
        UserDefaults.standard.removeObject(forKey: "merchantAliases")
        let ledger = LedgerStore(transactionStore: store)

        let initialCount = ledger.transactions.count
        reporter.check(initialCount == 0, "LedgerStore bootstraps seed data in empty store")

        let rawText = """
        支付宝
        交易成功
        商户：离线回归咖啡
        金额：￥12.50
        时间：2026/03/27 09:15
        备注：离线回归
        """

        ledger.importRecognizedText(rawText, preferredSource: .alipay)
        try await Task.sleep(nanoseconds: 200_000_000)  // 等待 Task 完成
        reporter.check(ledger.transactions.count == initialCount + 1, "LedgerStore imports unique OCR text")

        ledger.setMerchantAlias(original: "离线回归咖啡", alias: "回归咖啡")
        reporter.check(ledger.transactions.first?.merchant == "回归咖啡", "Merchant alias refreshes existing transactions")

        ledger.importRecognizedText(rawText, preferredSource: .alipay)
        try await Task.sleep(nanoseconds: 200_000_000)
        reporter.check(ledger.transactions.count == initialCount + 1, "LedgerStore skips duplicate OCR text")

        // Jaccard 相似度去重：略微修改的文本应被判定为重复
        let similarText = """
        支付宝
        交易成功
        商户：离线回归咖啡
        金额：￥12.50
        时间：2026/03/27 09:15
        备注：离线回归测试
        """
        ledger.importRecognizedText(similarText, preferredSource: .alipay)
        try await Task.sleep(nanoseconds: 200_000_000)
        reporter.check(ledger.transactions.count == initialCount + 1, "LedgerStore skips OCR-similar duplicate (Jaccard > 0.8)")

        do {
            let legacyStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "legacy-debug.sqlite3")
            let legacyLedger = LedgerStore(transactionStore: legacyStore)
            legacyLedger.importRecognizedText(rawText, preferredSource: .alipay)
            try await Task.sleep(nanoseconds: 200_000_000)
            if let importedCoffee = legacyLedger.transactions.first(where: { abs($0.amount - 12.50) < 0.01 }) {
                try legacyStore.saveDebugEvent(
                    ImportDebugRecord(
                        stage: .persisted,
                        source: .alipay,
                        rawText: similarText,
                        parsedReceipt: nil,
                        summary: "legacy persisted debug event without transaction id"
                    )
                )
                legacyLedger.deleteTransaction(importedCoffee)
                legacyLedger.permanentlyDeleteTransaction(importedCoffee)

                reporter.check(
                    !ImportDuplicateDetector.hasOCRTextDuplicate(
                        rawText: rawText,
                        debugRecords: (try? legacyStore.loadDebugEvents()) ?? [],
                        activeTransactionIDs: [],
                        threshold: 0.8
                    ),
                    "ImportDuplicateDetector ignores deleted and legacy debug text"
                )

                let reloadedLedger = LedgerStore(transactionStore: legacyStore)
                reloadedLedger.importRecognizedText(rawText, preferredSource: .alipay)
                try await Task.sleep(nanoseconds: 200_000_000)
                reporter.check(
                    reloadedLedger.transactions.count == 1,
                    "LedgerStore reimports after permanent delete despite legacy debug text"
                )
            } else {
                reporter.check(false, "LedgerStore finds imported coffee transaction for delete/reimport regression")
            }
        }

        let aliasLearningText = """
        支付宝
        交易成功
        商户：杭州测试餐饮管理有限公司
        金额：￥18.80
        时间：2026/03/28 12:15
        备注：商户别名学习
        """
        ledger.importRecognizedText(aliasLearningText, preferredSource: .alipay)
        try await Task.sleep(nanoseconds: 200_000_000)
        let importedForAlias = ledger.transactions.first { $0.merchant == "杭州测试餐饮管理有限公司" }
        reporter.check(importedForAlias != nil, "LedgerStore imports full merchant before alias learning")
        if let importedForAlias {
            ledger.updateTransaction(
                Transaction(
                    id: importedForAlias.id,
                    merchant: "测试餐饮",
                    amount: importedForAlias.amount,
                    occurredAt: importedForAlias.occurredAt,
                    categoryLabel: importedForAlias.category,
                    sourceLabel: importedForAlias.source,
                    note: importedForAlias.note
                )
            )
            reporter.check(
                ledger.merchantAliases["杭州测试餐饮管理有限公司"] == "测试餐饮",
                "LedgerStore learns merchant alias from high-confidence edit"
            )
        }

        let multiItemNoTotalText = """
        WALMART
        450 MARKET ST
        FRESH MILK        2.00
        BREAD             3.20
        APPLES            7.10
        CASHIER 12
        04/23/2026 18:02
        """
        ledger.importRecognizedText(multiItemNoTotalText, preferredSource: .manual)
        try await Task.sleep(nanoseconds: 200_000_000)
        reporter.check(ledger.transactions.count == initialCount + 2, "LedgerStore does not persist multi-item receipt without reliable total")
        reporter.check(
            ledger.lastImportSummary?.contains("总金额") == true || ledger.lastImportSummary?.contains("total amount") == true,
            "LedgerStore reports multi-item receipt total-missing guidance"
        )

        // TextSimilarity 单元验证
        let sim = TextSimilarity.jaccard(rawText, similarText)
        reporter.check(sim > 0.8, "TextSimilarity.jaccard returns > 0.8 for similar texts (got \(String(format: "%.3f", sim)))")

        let unrelatedText = "美团外卖订单 金额 ¥88.00 商户 麦当劳"
        let lowSim = TextSimilarity.jaccard(rawText, unrelatedText)
        reporter.check(lowSim < 0.5, "TextSimilarity.jaccard returns < 0.5 for unrelated texts (got \(String(format: "%.3f", lowSim)))")

        let reloadedStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger.sqlite3")
        let reloadedTransactions = try reloadedStore.loadTransactions()
        reporter.check(reloadedTransactions.count == initialCount + 2, "SQLite store reload keeps imported transactions")
    }

    private static func verifyBackupRoundTrip(reporter: RegressionReporter) throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerBackupRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        UserDefaults.standard.removeObject(forKey: "customSources")
        UserDefaults.standard.removeObject(forKey: "customCategories")
        UserDefaults.standard.removeObject(forKey: "merchantAliases")
        UserDefaults.standard.removeObject(forKey: "subscriptionAnnualPriceOverrides")
        UserDefaults.standard.removeObject(forKey: "subscriptionNotes")

        let sourceStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "source.sqlite3")
        let sourceLedger = LedgerStore(transactionStore: sourceStore)
        let active = Transaction(
            merchant: "备份回归咖啡",
            amount: 21.00,
            occurredAt: AppFormatters.parseFlexibleDate("2026-04-24 08:30") ?? .now,
            categoryLabel: "咖啡",
            sourceLabel: "测试来源",
            note: "active"
        )
        let deleted = Transaction(
            merchant: "备份回归删除",
            amount: 9.90,
            occurredAt: AppFormatters.parseFlexibleDate("2026-04-23 18:30") ?? .now,
            category: .dining,
            source: .wechat,
            note: "deleted"
        )
        sourceLedger.addTransaction(active)
        sourceLedger.addTransaction(deleted)
        sourceLedger.deleteTransaction(deleted)
        sourceLedger.customCategories = ["咖啡"]
        sourceLedger.customSources = ["测试来源"]
        sourceLedger.merchantAliases = ["原始商户": "别名商户"]
        sourceLedger.saveCustomCategories()
        sourceLedger.saveCustomSources()
        sourceLedger.saveMerchantAliases()
        sourceLedger.recordCategoryCorrection(merchant: "备份回归咖啡", category: .dining)

        let subscription = Subscription(
            merchant: "备份订阅",
            planName: "Pro",
            period: .monthly,
            amount: 18,
            lastChargedAt: AppFormatters.parseFlexibleDate("2026-04-01 09:00") ?? .now
        )
        sourceLedger.upsertSubscription(subscription)
        UserDefaults.standard.set([subscription.id.uuidString: 168.0], forKey: "subscriptionAnnualPriceOverrides")
        UserDefaults.standard.set([subscription.id.uuidString: "年度价备注"], forKey: "subscriptionNotes")

        let bundle = try sourceLedger.makeBackupBundle()
        reporter.check(bundle.summary.transactionCount == 1, "BackupBundle summary counts active transactions")
        reporter.check(bundle.summary.deletedTransactionCount == 1, "BackupBundle summary counts deleted transactions")
        reporter.check(bundle.customCategories == ["咖啡"], "BackupBundle includes custom categories")
        reporter.check(bundle.subscriptionMetadata.annualPriceOverrides[subscription.id.uuidString] == 168.0, "BackupBundle includes subscription annual price metadata")

        let restoreStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "restore.sqlite3")
        let restoreLedger = LedgerStore(transactionStore: restoreStore)
        try restoreLedger.restoreBackup(bundle)

        reporter.check(restoreLedger.transactions.contains(active), "Backup restore keeps active transaction")
        reporter.check(restoreLedger.deletedTransactions.contains(deleted), "Backup restore keeps deleted transaction")
        let restoredSubscription = restoreLedger.subscriptions.first { $0.id == subscription.id }
        reporter.check(
            restoredSubscription?.merchant == subscription.merchant &&
            restoredSubscription?.planName == subscription.planName &&
            restoredSubscription?.period == subscription.period &&
            abs((restoredSubscription?.amount ?? 0) - subscription.amount) < 0.001,
            "Backup restore keeps subscriptions"
        )
        reporter.check(restoreLedger.customCategories == ["咖啡"], "Backup restore keeps custom categories")
        reporter.check(restoreLedger.customSources == ["测试来源"], "Backup restore keeps custom sources")
        reporter.check(restoreLedger.merchantAliases["原始商户"] == "别名商户", "Backup restore keeps merchant aliases")
        reporter.check(restoreLedger.categoryCorrections["备份回归咖啡"] == .dining, "Backup restore keeps category corrections")
    }

    private static func sameMinute(_ lhs: Date, _ rhs: Date) -> Bool {
        let calendar = AppFormatters.calendar
        let lhsComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: lhs)
        let rhsComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rhs)
        return lhsComponents == rhsComponents
    }
}
