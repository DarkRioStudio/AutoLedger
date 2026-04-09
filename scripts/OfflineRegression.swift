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
    static func main() throws {
        let reporter = RegressionReporter()
        let parser = ReceiptParser()
        let sampleProvider = SampleReceiptProvider()

        verifySampleParsing(using: parser, samples: sampleProvider.samples, reporter: reporter)
        try verifySQLiteRoundTrip(reporter: reporter)
        try verifyLedgerImportFlow(using: reporter)

        reporter.finish()
    }

    private static func verifySampleParsing(
        using parser: ReceiptParser,
        samples: [SampleReceipt],
        reporter: RegressionReporter
    ) {
        let expectedDates: [String: String] = [
            "微信买菜截图": "2026-03-26 19:42",
            "支付宝出行截图": "2026-03-25 08:10",
            "App Store 订阅截图": "2026-03-22 12:14"
        ]

        let expectedMerchants: [String: String] = [
            "微信买菜截图": "盒马鲜生",
            "支付宝出行截图": "滴滴出行",
            "App Store 订阅截图": "Apple Services",
            "天津地铁储值卡截图": "地铁：内江路 → 东丽文体中心"
        ]

        let expectedAmounts: [String: Double] = [
            "微信买菜截图": 86.30,
            "支付宝出行截图": 23.80,
            "App Store 订阅截图": 28.00,
            "天津地铁储值卡截图": 2.70
        ]

        let expectedCategories: [String: TransactionCategory] = [
            "微信买菜截图": .groceries,
            "支付宝出行截图": .transport,
            "App Store 订阅截图": .digital,
            "天津地铁储值卡截图": .transport
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
            // Samples without an expected date fixture (e.g. transit notifications) skip date verification.
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

    private static func verifyLedgerImportFlow(using reporter: RegressionReporter) throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerLedgerRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let store = try SQLiteTransactionStore(baseDirectoryURL: rootURL, filename: "ledger.sqlite3")
        let ledger = LedgerStore(transactionStore: store)

        let initialCount = ledger.transactions.count
        reporter.check(initialCount == 3, "LedgerStore bootstraps seed data in empty store")

        let rawText = """
        支付宝
        交易成功
        商户：离线回归咖啡
        金额：￥12.50
        时间：2026/03/27 09:15
        备注：离线回归
        """

        ledger.importRecognizedText(rawText, preferredSource: .alipay)
        reporter.check(ledger.transactions.count == initialCount + 1, "LedgerStore imports unique OCR text")

        ledger.importRecognizedText(rawText, preferredSource: .alipay)
        reporter.check(ledger.transactions.count == initialCount + 1, "LedgerStore skips duplicate OCR text")

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
