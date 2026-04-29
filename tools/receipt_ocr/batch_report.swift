import Foundation

struct ParseRecord: Decodable {
    let id: String
    let amount: Double?
    let merchant: String?
    let category: String?
    let confidence: String
    let needsReview: Bool
    let warnings: [String]
    let debugTrace: [String]
}

@main
struct BatchReport {
    static func main() throws {
        guard CommandLine.arguments.count >= 2 else {
            FileHandle.standardError.write(Data("Usage: batch_report <parse.jsonl> [output.md]\n".utf8))
            exit(2)
        }

        let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let input = try String(contentsOf: inputURL, encoding: .utf8)
        let decoder = JSONDecoder()
        let records: [ParseRecord] = try input
            .split(separator: "\n")
            .map { try decoder.decode(ParseRecord.self, from: Data($0.utf8)) }

        let total = records.count
        guard total > 0 else {
            print("No records found.")
            return
        }

        let withAmount = records.filter { $0.amount != nil && $0.amount! > 0 }
        let withMerchant = records.filter { $0.merchant != nil && !$0.merchant!.isEmpty && $0.merchant != "待确认商户" }
        let needsReview = records.filter { $0.needsReview }
        let highConf = records.filter { $0.confidence == "high" }
        let mediumConf = records.filter { $0.confidence == "medium" }
        let lowConf = records.filter { $0.confidence == "low" }

        let categories = Dictionary(grouping: records.compactMap { $0.category }.filter { !$0.isEmpty }) { $0 }.mapValues { $0.count }
        let sortedCategories = categories.sorted { $0.value > $1.value }

        let warnings = Dictionary(grouping: records.flatMap { $0.warnings }) { $0 }.mapValues { $0.count }
        let sortedWarnings = warnings.sorted { $0.value > $1.value }

        let noAmount = records.filter { $0.amount == nil || $0.amount! <= 0 }
        let noMerchant = records.filter { $0.merchant == nil || $0.merchant!.isEmpty || $0.merchant == "待确认商户" }
        let nonBill = records.filter { $0.warnings.contains("nonBillImage") }

        var md = "# Batch Parse Report\n\n"
        md += "Generated: \(ISO8601DateFormatter().string(from: Date()))\n\n"
        md += "## Summary\n\n"
        md += "| Metric | Value |\n"
        md += "|--------|-------|\n"
        md += "| Total samples | \(total) |\n"
        md += "| Amount hit rate | \(String(format: "%.1f", Double(withAmount.count) / Double(total) * 100))% (\(withAmount.count)/\(total)) |\n"
        md += "| Merchant non-empty rate | \(String(format: "%.1f", Double(withMerchant.count) / Double(total) * 100))% (\(withMerchant.count)/\(total)) |\n"
        md += "| Needs review | \(String(format: "%.1f", Double(needsReview.count) / Double(total) * 100))% (\(needsReview.count)/\(total)) |\n"
        md += "| High confidence | \(String(format: "%.1f", Double(highConf.count) / Double(total) * 100))% (\(highConf.count)/\(total)) |\n"
        md += "| Medium confidence | \(String(format: "%.1f", Double(mediumConf.count) / Double(total) * 100))% (\(mediumConf.count)/\(total)) |\n"
        md += "| Low confidence | \(String(format: "%.1f", Double(lowConf.count) / Double(total) * 100))% (\(lowConf.count)/\(total)) |\n"
        md += "| Non-bill images intercepted | \(nonBill.count) |\n"
        md += "| Amount missing | \(noAmount.count) |\n"
        md += "| Merchant missing | \(noMerchant.count) |\n\n"

        if !sortedCategories.isEmpty {
            md += "## Category Distribution\n\n"
            md += "| Category | Count | Percentage |\n"
            md += "|----------|-------|------------|\n"
            for (cat, count) in sortedCategories {
                md += "| \(cat) | \(count) | \(String(format: "%.1f", Double(count) / Double(total) * 100))% |\n"
            }
            md += "\n"
        }

        if !sortedWarnings.isEmpty {
            md += "## Warnings\n\n"
            md += "| Warning | Count |\n"
            md += "|---------|-------|\n"
            for (warn, count) in sortedWarnings {
                md += "| \(warn) | \(count) |\n"
            }
            md += "\n"
        }

        let failedAmounts = records
            .filter { $0.amount == nil || $0.amount! <= 0 }
            .prefix(10)
        if !failedAmounts.isEmpty {
            md += "## Top Amount Failures\n\n"
            md += "| ID | Confidence | Warnings | Debug Trace |\n"
            md += "|----|------------|----------|-------------|\n"
            for record in failedAmounts {
                md += "| \(record.id) | \(record.confidence) | \(record.warnings.joined(separator: ", ")) | `\(record.debugTrace.joined(separator: "; "))` |\n"
            }
            md += "\n"
        }

        let curiousAmounts = records
            .filter { r in
                guard let a = r.amount else { return false }
                return a > 10_000 || (a > 0 && a < 0.5)
            }
            .prefix(10)
        if !curiousAmounts.isEmpty {
            md += "## Suspicious Amounts (>10k or <0.5)\n\n"
            md += "| ID | Amount | Confidence | Merchant |\n"
            md += "|----|--------|------------|----------|\n"
            for record in curiousAmounts {
                md += "| \(record.id) | \(record.amount ?? -1) | \(record.confidence) | \(record.merchant ?? "") |\n"
            }
            md += "\n"
        }

        if let outputPath = CommandLine.arguments.dropFirst(1).dropFirst(1).first {
            try md.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
            print("Wrote report to \(outputPath)")
        } else {
            print(md)
        }
    }
}
