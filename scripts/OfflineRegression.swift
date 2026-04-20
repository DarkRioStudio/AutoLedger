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
        try verifySQLiteRoundTrip(reporter: reporter)
        try await verifyLedgerImportFlow(using: reporter)

        reporter.finish()
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
            "微信支付全部账单截图（7-11）": "2026-04-20 18:17:58"
        ]

        let expectedMerchants: [String: String] = [
            "微信买菜截图": "Example Supermarket",
            "微信支付详情个体工商户跨行截图": "宜春市Example Mini Market商贸有限公司",
            "支付宝出行截图": "滴滴出行",
            "App Store 订阅截图": "Apple Services",
            "天津地铁储值卡截图": "地铁：ExampleStationA → ExampleStationB",
            "互联互通城市卡CN¥嵌入格式截图": "地铁：ExampleAirport → ExampleEastStation",
            "抖音团购麦当劳截图": "Demo Burger (Example Branch)",
            "支付宝碰一下支付截图（7-11）": "Example Convenience Store",
            "滴滴出行结束订单截图": "滴滴出行",
            "滴滴出行通知截图": "滴滴出行",
            "滴滴出行优享出租车截图": "滴滴出行",
            "滴滴出行微信扣费凭证截图": "滴滴出行",
            "支付宝麦当劳支付成功截图": "Demo Burger Restaurant",
            "淘宝闪购订单进行中截图": "Sample Restaurant（Example Branch）",
            "微信支付全部账单截图（7-11）": "Example Convenience Store"
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
            "微信支付全部账单截图（7-11）": 16.80
        ]

        let expectedCategories: [String: TransactionCategory] = [
            "微信买菜截图": .groceries,
            "微信支付详情个体工商户跨行截图": .shopping,
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
            "微信支付全部账单截图（7-11）": .other
        ]

        for sample in samples {
            guard let receipt = parser.parse(text: sample.rawText, source: sample.source) else {
                reporter.check(false, "\(sample.title) should parse successfully")
                continue
            }

            reporter.check(receipt.source == sample.source, "\(sample.title) source matches")
            reporter.check(receipt.merchant == expectedMerchants[sample.title], "\(sample.title) merchant matches")
            reporter.check(abs(receipt.amount - (expectedAmounts[sample.title] ?? 0)) < 0.001, "\(sample.title) amount matches")
            reporter.check(receipt.suggestedCategory == expectedCategories[sample.title], "\(sample.title) category matches")

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
    }

    private static func verifyLedgerImportFlow(using reporter: RegressionReporter) async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerLedgerRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let store = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger.sqlite3")
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

        // TextSimilarity 单元验证
        let sim = TextSimilarity.jaccard(rawText, similarText)
        reporter.check(sim > 0.8, "TextSimilarity.jaccard returns > 0.8 for similar texts (got \(String(format: "%.3f", sim)))")

        let unrelatedText = "美团外卖订单 金额 ¥88.00 商户 麦当劳"
        let lowSim = TextSimilarity.jaccard(rawText, unrelatedText)
        reporter.check(lowSim < 0.5, "TextSimilarity.jaccard returns < 0.5 for unrelated texts (got \(String(format: "%.3f", lowSim)))")

        let reloadedStore = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger.sqlite3")
        let reloadedTransactions = try reloadedStore.loadTransactions()
        reporter.check(reloadedTransactions.count == initialCount + 1, "SQLite store reload keeps imported transaction")
    }

    private static func sameMinute(_ lhs: Date, _ rhs: Date) -> Bool {
        let calendar = AppFormatters.calendar
        let lhsComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: lhs)
        let rhsComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rhs)
        return lhsComponents == rhsComponents
    }
}
