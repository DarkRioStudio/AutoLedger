#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TMP_BIN="$(mktemp /tmp/autoledger-offline-regression.XXXXXX)"
trap 'rm -f "$TMP_BIN"' EXIT

CORE="$ROOT/AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore"

# LedgerStore has 'import AutoLedgerCore' which doesn't exist as a module in flat compilation.
# Also depends on SmartReceiptParser (Foundation Models) — stub it out for offline use.
PREP_DIR="$(mktemp -d /tmp/autoledger-prep.XXXXXX)"
trap 'rm -f "$TMP_BIN"; rm -rf "$PREP_DIR"' EXIT
sed '/import AutoLedgerCore/d; /import UIKit/d; /import UserNotifications/d; /typealias Subscription/d' "$ROOT/AutoLedger/AutoLedger/App/LedgerStore.swift" > "$PREP_DIR/LedgerStore.swift"

cat > "$PREP_DIR/SmartReceiptParserStub.swift" << 'STUB'
import Foundation
struct SmartReceiptParser {
    struct LLMTrace { let prompt: String; let response: String }
    private let parser = ReceiptParser()
    func parse(text: String, source: ReceiptSource, fallbackMerchant: String? = nil) async -> (receipt: ImportedReceipt, llmTrace: LLMTrace?)? {
        guard let receipt = parser.parse(text: text, source: source) else { return nil }
        return (receipt, nil)
    }
}
STUB

cat > "$PREP_DIR/IOSStubs.swift" << 'IOSTUB'
import Foundation

// --- UIKit stubs ---
enum UIPasteboard {
    static let general = UIPasteboardInstance()
}
struct UIPasteboardInstance {
    var changeCount: Int { 0 }
    var hasImages: Bool { false }
    var image: UIPasteboardImage? { nil }
}
struct UIPasteboardImage {
    func pngData() -> Data? { nil }
}

// --- OCRService stub (uses Vision, iOS only) ---
struct OCRResult: Sendable {
    let text: String
    let minimumWordConfidence: Float
}
struct OCRService: Sendable {
    func recognizeTextWithConfidence(from data: Data) throws -> OCRResult { OCRResult(text: "", minimumWordConfidence: 1.0) }
    func recognizeText(from data: Data) throws -> String { "" }
}

// --- NotificationService stub (uses UserNotifications, iOS only) ---
final class NotificationService: Sendable {
    static let shared = NotificationService()
    func requestPermissionIfNeeded() {}
    func scheduleUpcomingChargeReminders(for subscriptions: [Subscription]) {}
}
IOSTUB

swiftc \
  -o "$TMP_BIN" \
  -lsqlite3 \
  "$CORE/Enums/ReceiptSource.swift" \
  "$CORE/Enums/TransactionCategory.swift" \
  "$CORE/Models/ImportedReceipt.swift" \
  "$CORE/Models/ImportDebugRecord.swift" \
  "$CORE/Models/SampleReceipt.swift" \
  "$CORE/Models/MonthlySnapshot.swift" \
  "$CORE/Models/Transaction.swift" \
  "$CORE/Models/Subscription.swift" \
  "$CORE/Services/ReceiptParser.swift" \
  "$CORE/Services/SampleReceiptProvider.swift" \
  "$CORE/Services/SubscriptionDetector.swift" \
  "$CORE/Persistence/TransactionStore.swift" \
  "$CORE/Persistence/SQLiteTransactionStore.swift" \
  "$PREP_DIR/LedgerStore.swift" \
  "$PREP_DIR/SmartReceiptParserStub.swift" \
  "$PREP_DIR/IOSStubs.swift" \
  "$CORE/Utils/AppFormatters.swift" \
  "$CORE/Utils/TextSimilarity.swift" \
  "$ROOT/scripts/OfflineRegression.swift"

"$TMP_BIN"
