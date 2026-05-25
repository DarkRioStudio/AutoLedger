import AutoLedgerCore
import Foundation
import UIKit

/// 组装反馈 bundle（issue_bundle.json / summary.txt / metadata.json / trace.log 等）
enum FeedbackBundleBuilder {

    // MARK: - Feedback ID

    static func generateFeedbackID() -> String {
        let vendorHash = vendorIDShort6()
        let timestamp = idDateFormatter.string(from: .now)
        let seq = nextSequence(for: timestamp)
        return "AL-\(vendorHash)-\(timestamp)-\(seq)"
    }

    // MARK: - Device / App Info

    struct DeviceInfo {
        let appVersion: String
        let buildNumber: String
        let iosVersion: String
        let deviceModel: String
    }

    static func collectDeviceInfo() -> DeviceInfo {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let ios = UIDevice.current.systemVersion
        let model = deviceModelName()
        return DeviceInfo(appVersion: version, buildNumber: build, iosVersion: ios, deviceModel: model)
    }

    // MARK: - Build Bundle Directory

    /// 在临时目录组装 bundle 文件，返回 bundle 目录 URL
    static func buildBundle(
        feedbackID: String,
        level: FeedbackLevel,
        issueType: FeedbackIssueType,
        userDescription: String,
        expectedResult: String,
        actualResult: String,
        reproducible: String,
        entryPoint: String,
        debugRecords: [ImportDebugRecord],
        transactions: [Transaction] = [],
        lastOCRText: String,
        lastReceipt: ImportedReceipt?,
        includeRawImage: Bool = false,
        screenshotData: Data? = nil
    ) throws -> URL {
        let device = collectDeviceInfo()
        let nowISO = iso8601Formatter.string(from: .now)
        let nowLocal = AppFormatters.exportDateTime(.now)

        let bundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("feedback_bundle_\(feedbackID)", isDirectory: true)
        try? FileManager.default.removeItem(at: bundleDir)
        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

        // --- metadata.json ---
        let metadata: [String: Any] = [
            "bundle_version": "1.0",
            "feedback_id": feedbackID,
            "feedback_level": level.rawValue,
            "generated_at": nowISO,
            "app_name": "AutoLedger",
            "app_version": device.appVersion,
            "build_number": device.buildNumber,
            "platform": "iOS",
            "ios_version": device.iosVersion,
            "device_model": device.deviceModel,
            "entry_point": entryPoint,
            "redaction_profile": level == .L3 ? "none" : "standard",
            "contains_raw_image": includeRawImage && level.containsRawImage,
            "contains_full_ocr_text": level.containsFullOCR
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try metadataData.write(to: bundleDir.appendingPathComponent("metadata.json"))

        // --- summary.txt ---
        let summary = buildSummaryText(
            feedbackID: feedbackID, level: level, issueType: issueType,
            device: device, entryPoint: entryPoint, eventTime: nowLocal,
            userDescription: userDescription, expectedResult: expectedResult,
            actualResult: actualResult, reproducible: reproducible
        )
        try summary.write(to: bundleDir.appendingPathComponent("summary.txt"), atomically: true, encoding: .utf8)

        // --- issue_bundle.json ---
        let issueBundle = buildIssueBundleJSON(
            feedbackID: feedbackID, level: level, issueType: issueType, device: device,
            entryPoint: entryPoint, nowLocal: nowLocal, nowISO: nowISO,
            userDescription: userDescription, expectedResult: expectedResult,
            actualResult: actualResult, reproducible: reproducible,
            debugRecords: debugRecords, transactions: transactions, lastOCRText: lastOCRText, lastReceipt: lastReceipt,
            includeRawImage: includeRawImage
        )
        let issueBundleData = try JSONSerialization.data(withJSONObject: issueBundle, options: [.prettyPrinted, .sortedKeys])
        try issueBundleData.write(to: bundleDir.appendingPathComponent("issue_bundle.json"))

        // --- L2+ trace.log ---
        if level.containsTrace {
            let trace = buildTraceLog(debugRecords: debugRecords, transactions: transactions)
            try trace.write(to: bundleDir.appendingPathComponent("trace.log"), atomically: true, encoding: .utf8)
        }

        // --- L2+ redacted_ocr_context.txt ---
        if level.containsRedactedOCR && !lastOCRText.isEmpty {
            let redacted = level == .L3 ? lastOCRText : redactText(lastOCRText)
            let fileName = level == .L3 ? "full_ocr_text.txt" : "redacted_ocr_context.txt"
            try redacted.write(to: bundleDir.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
        }

        // --- L3 full_ocr_text.txt (if L2 already wrote redacted, L3 writes full) ---
        if level.containsFullOCR && !lastOCRText.isEmpty {
            try lastOCRText.write(to: bundleDir.appendingPathComponent("full_ocr_text.txt"), atomically: true, encoding: .utf8)
        }

        // --- L3 screenshot ---
        if level.containsRawImage && includeRawImage, let data = screenshotData {
            let attachDir = bundleDir.appendingPathComponent("attachments", isDirectory: true)
            try FileManager.default.createDirectory(at: attachDir, withIntermediateDirectories: true)
            try data.write(to: attachDir.appendingPathComponent("screenshot.jpg"))
        }

        return bundleDir
    }

    /// 将 bundle 目录压缩为 zip，返回 zip 文件 URL
    static func zipBundle(at bundleDir: URL, feedbackID: String, level: FeedbackLevel) throws -> URL {
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedger_Feedback_\(level.rawValue)_\(feedbackID).zip")
        try? FileManager.default.removeItem(at: zipURL)

        var coordinatorError: NSError?
        var innerError: Error?
        NSFileCoordinator().coordinate(readingItemAt: bundleDir, options: .forUploading, error: &coordinatorError) { tempZip in
            do {
                try FileManager.default.copyItem(at: tempZip, to: zipURL)
            } catch {
                innerError = error
            }
        }
        if let err = coordinatorError { throw err }
        if let err = innerError { throw err }
        return zipURL
    }

    // MARK: - Email Composition Helpers

    static func emailSubject(level: FeedbackLevel, issueType: FeedbackIssueType, summary: String) -> String {
        let device = collectDeviceInfo()
        return "[AutoLedger][\(level.rawValue)][iOS][\(device.appVersion)(\(device.buildNumber))][\(issueType.rawValue)] \(summary)"
    }

    static func emailBody(
        level: FeedbackLevel,
        issueType: FeedbackIssueType,
        feedbackID: String,
        userDescription: String,
        expectedResult: String,
        actualResult: String,
        reproducible: String,
        extraNote: String
    ) -> String {
        let device = collectDeviceInfo()
        let nowLocal = AppFormatters.exportDateTime(.now)
        let extra = extraNote.isEmpty ? String(localized: "feedback.email.none") : extraNote

        func section(_ labelKey: String, _ value: String) -> String {
            "\(String(localized: String.LocalizationValue(labelKey)))\n\(value)"
        }

        func bulletList(_ keys: [String]) -> String {
            keys
                .map { "- \(String(localized: String.LocalizationValue($0)))" }
                .joined(separator: "\n")
        }

        var sections: [String] = []
        switch level {
        case .L1:
            sections.append(String(localized: "feedback.email.intro.l1"))
        case .L2:
            sections.append(String(localized: "feedback.email.intro.l2"))
        case .L3:
            sections.append(String(localized: "feedback.email.intro.l3"))
        }

        sections.append(section("feedback.email.label.problem", userDescription))
        sections.append(section("feedback.email.label.expected", expectedResult))
        sections.append(section("feedback.email.label.actual", actualResult))
        sections.append(section("feedback.email.label.reproducible", reproducible))
        sections.append(section("feedback.email.label.event_time", nowLocal))

        if level == .L2 {
            sections.append(section("feedback.email.label.attachments", bulletList([
                "feedback.email.attachment.l2.debug_log",
                "feedback.email.attachment.l2.redacted_context",
                "feedback.email.attachment.l2.parse_summary",
                "feedback.email.attachment.l2.trace"
            ])))
        } else if level == .L3 {
            sections.append(section("feedback.email.label.attachments", bulletList([
                "feedback.email.attachment.l3.full_debug_log",
                "feedback.email.attachment.l3.trace",
                "feedback.email.attachment.l3.optional_screenshot",
                "feedback.email.attachment.l3.ocr_text"
            ])))
            sections.append(section("feedback.email.label.important", String(localized: "feedback.email.important.l3")))
        }

        sections.append(section("feedback.email.label.note", extra))

        var body = sections.joined(separator: "\n\n")
        body += """

        \n--------------------------------
        AUTOLEDGER_FEEDBACK_META
        feedback_level=\(level.rawValue)
        issue_type=\(issueType.rawValue)
        app_version=\(device.appVersion)
        build=\(device.buildNumber)
        platform=iOS
        ios_version=\(device.iosVersion)
        device_model=\(device.deviceModel)
        entry_point=settings_feedback
        has_attachment_bundle=true
        has_screenshot=\(level == .L3)
        contains_redacted_ocr=\(level.containsRedactedOCR)
        contains_raw_image=false
        feedback_id=\(feedbackID)
        --------------------------------
        """
        return body
    }

    // MARK: - Redaction

    static func redactText(_ text: String) -> String {
        var result = text
        // Redact amounts (¥ followed by digits)
        let amountPattern = #"[¥￥]\s*[\d,]+\.?\d*"#
        if let regex = try? NSRegularExpression(pattern: amountPattern) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "¥***")
        }
        // Redact phone numbers
        let phonePattern = #"1[3-9]\d{9}"#
        if let regex = try? NSRegularExpression(pattern: phonePattern) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "[PHONE]")
        }
        // Redact email addresses
        let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "[EMAIL]")
        }
        // Redact card numbers (4 groups of 4 digits or long digit sequences)
        let cardPattern = #"\b\d{4}[\s*-]?\d{4}[\s*-]?\d{4}[\s*-]?\d{4}\b"#
        if let regex = try? NSRegularExpression(pattern: cardPattern) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "[CARD]")
        }
        return result
    }

    // MARK: - Private Helpers

    private static func vendorIDShort6() -> String {
        guard let vendorID = UIDevice.current.identifierForVendor?.uuidString else { return "000000" }
        let data = Data(vendorID.utf8)
        // Simple hash using built-in insecure hash for non-security purpose (just ID shortening)
        var hash: UInt64 = 0
        for byte in data { hash = hash &* 31 &+ UInt64(byte) }
        return String(format: "%06x", hash & 0xFFFFFF)
    }

    private static func nextSequence(for datePart: String) -> String {
        let key = "feedbackSeq_\(datePart)"
        let current = UserDefaults.standard.integer(forKey: key)
        let next = current + 1
        UserDefaults.standard.set(next, forKey: key)
        return String(format: "%04d", next)
    }

    private static func deviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    private static let idDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMddHHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func buildSummaryText(
        feedbackID: String, level: FeedbackLevel, issueType: FeedbackIssueType,
        device: DeviceInfo, entryPoint: String, eventTime: String,
        userDescription: String, expectedResult: String,
        actualResult: String, reproducible: String
    ) -> String {
        """
        AutoLedger Feedback Summary
        ===========================

        Feedback ID: \(feedbackID)
        Level: \(level.rawValue)
        Issue Type: \(issueType.rawValue)

        App Version: \(device.appVersion)
        Build: \(device.buildNumber)
        Platform: iOS
        iOS Version: \(device.iosVersion)
        Device Model: \(device.deviceModel)

        Entry Point: \(entryPoint)
        Event Time: \(eventTime)

        User Description:
        \(userDescription)

        Expected Result:
        \(expectedResult)

        Actual Result:
        \(actualResult)

        Reproducible:
        \(reproducible)

        Redaction:
        \(level == .L3 ? "None (full diagnostic)" : "Standard (amounts, phone, email, card numbers)")

        Attachments:
        \(level == .L1 ? "issue_bundle.json, summary.txt, metadata.json" : level == .L2 ? "issue_bundle.json, summary.txt, metadata.json, trace.log, redacted_ocr_context.txt" : "issue_bundle.json, summary.txt, metadata.json, trace.log, full_ocr_text.txt, attachments/")
        """
    }

    private static func buildIssueBundleJSON(
        feedbackID: String, level: FeedbackLevel, issueType: FeedbackIssueType,
        device: DeviceInfo, entryPoint: String, nowLocal: String, nowISO: String,
        userDescription: String, expectedResult: String,
        actualResult: String, reproducible: String,
        debugRecords: [ImportDebugRecord], transactions: [Transaction], lastOCRText: String, lastReceipt: ImportedReceipt?,
        includeRawImage: Bool
    ) -> [String: Any] {
        var json: [String: Any] = [
            "feedback_id": feedbackID,
            "feedback_level": level.rawValue,
            "issue_type": issueType.rawValue,
            "user_description": userDescription,
            "expected_result": expectedResult,
            "actual_result": actualResult,
            "reproducible": reproducible,
            "app": [
                "name": "AutoLedger",
                "version": device.appVersion,
                "build": device.buildNumber,
                "platform": "iOS",
                "ios_version": device.iosVersion,
                "device_model": device.deviceModel
            ],
            "event": [
                "time_local": nowLocal,
                "time_iso": nowISO,
                "entry_point": entryPoint
            ]
        ]

        // Debug section
        var debug: [String: Any] = [:]

        if let receipt = lastReceipt {
            let parsedAmount = level == .L1 ? "***" : String(format: "%.2f", receipt.amount)
            let parsedMerchant = level == .L1 ? "***" : receipt.merchant
            debug["parsed_result"] = [
                "amount": parsedAmount,
                "merchant": parsedMerchant,
                "time": AppFormatters.exportDateTime(receipt.occurredAt)
            ]
            debug["parse_status"] = "success"
            if level >= .L2 {
                debug["parsed_result_confidence"] = receipt.confidence
            }
        }

        if !debugRecords.isEmpty {
            let latest = debugRecords.first!
            debug["ocr_status"] = latest.rawText.isEmpty ? "empty" : "captured"
            debug["save_status"] = latest.stage.rawValue

            if level >= .L2 {
                debug["ocr_text_redacted"] = redactText(latest.rawText)
                debug["trace"] = debugRecords.prefix(10).map { r -> String in
                    var entry = "\(r.stage.rawValue)|\(r.source.rawValue)|\(r.imageSource.rawValue)|\(AppFormatters.exportDateTime(r.createdAt))"
                    if let txID = r.transactionID,
                       let tx = transactions.first(where: { $0.id == txID }) {
                        entry += "|user_tx=\(tx.merchant):\(String(format: "%.2f", tx.amount)):\(tx.category)"
                    }
                    return entry
                }
            }

            if level == .L3 {
                debug["trace_file"] = "trace.log"
                debug["ocr_text_full_file"] = "full_ocr_text.txt"
            }
        }

        json["debug"] = debug

        // Privacy section
        json["privacy"] = [
            "redacted": level != .L3,
            "contains_full_ocr_text": level.containsFullOCR,
            "contains_raw_image": level.containsRawImage && includeRawImage
        ]

        if level == .L3 {
            json["attachments"] = [
                "has_screenshot": includeRawImage,
                "screenshot_file": includeRawImage ? "attachments/screenshot.jpg" : ""
            ]
        }

        return json
    }

    private static func buildTraceLog(debugRecords: [ImportDebugRecord], transactions: [Transaction]) -> String {
        var lines = ["AutoLedger Import Trace Log", "Generated: \(AppFormatters.exportDateTime(.now))", ""]
        for record in debugRecords.prefix(20) {
            var entry = "[\(AppFormatters.exportDateTime(record.createdAt))] "
            entry += "stage=\(record.stage.rawValue) "
            entry += "source=\(record.source.rawValue) "
            entry += "image_source=\(record.imageSource.rawValue) "
            entry += "used_llm=\(record.usedLLM) "
            entry += "summary=\(record.summary)"
            lines.append(entry)

            if let prompt = record.llmPrompt {
                lines.append("  llm_prompt=\(prompt.prefix(500))")
            }
            if let response = record.llmResponse {
                lines.append("  llm_response=\(response.prefix(500))")
            }
            if let txID = record.transactionID,
               let tx = transactions.first(where: { $0.id == txID }) {
                let noteStr = tx.note.isEmpty ? "" : " note=\(tx.note)"
                lines.append("  user_modified_transaction: merchant=\(tx.merchant) amount=\(String(format: "%.2f", tx.amount)) category=\(tx.category) date=\(AppFormatters.exportDateTime(tx.occurredAt))\(noteStr)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
