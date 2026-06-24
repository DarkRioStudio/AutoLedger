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
sed '/import AutoLedgerCore/d' "$ROOT/AutoLedger/AutoLedger/Domain/Services/LedgerTextInterpreter.swift" > "$PREP_DIR/LedgerTextInterpreter.swift"
sed '/import AutoLedgerCore/d' "$ROOT/AutoLedger/AutoLedger/Domain/Services/ReceiptParser.swift" > "$PREP_DIR/ReceiptParser.swift"

cat > "$PREP_DIR/SmartReceiptParserStub.swift" << 'STUB'
import Foundation

enum LLMProvider: String, Sendable {
    case apple
    case gemma

    var displayName: String {
        switch self {
        case .apple: return "Apple Foundation Models"
        case .gemma: return "Gemma"
        }
    }

    static var userSelected: LLMProvider { .apple }
    static var isEnhancementEnabled: Bool { false }
}

struct SmartReceiptParser {
    struct LLMTrace {
        let prompt: String
        let response: String
        let providerID: String
        let providerDisplayName: String
        let latencyMs: Int

        init(prompt: String, response: String, provider: LLMProvider, latencyMs: Int) {
            self.prompt = prompt
            self.response = response
            self.providerID = provider.rawValue
            self.providerDisplayName = provider.displayName
            self.latencyMs = latencyMs
        }
    }

    struct SmartResult {
        let receipt: ImportedReceipt
        let llmTrace: LLMTrace?
        let usedRuleFallback: Bool
    }

    private let parser = ReceiptParser()

    func parse(
        text: String,
        source: ReceiptSource,
        fallbackMerchant: String? = nil,
        ocrMinConfidence: Float? = nil,
        provider: LLMProvider = .apple
    ) async -> SmartResult? {
        guard let receipt = parser.parse(text: text, source: source, fallbackMerchant: fallbackMerchant) else {
            return nil
        }
        return SmartResult(receipt: receipt, llmTrace: nil, usedRuleFallback: true)
    }

    func parseWithRules(
        text: String,
        source: ReceiptSource,
        fallbackMerchant: String? = nil
    ) -> ImportedReceipt? {
        parser.parse(text: text, source: source, fallbackMerchant: fallbackMerchant)
    }

    func parseWithExternalAssist(
        text: String,
        source: ReceiptSource,
        fallbackMerchant: String? = nil
    ) async -> SmartResult? {
        let baseReceipt = parser.parse(text: text, source: source, fallbackMerchant: fallbackMerchant)
        let receipt = ImportedReceipt(
            source: source,
            merchant: "LLM should not run",
            amount: baseReceipt?.amount ?? 999,
            occurredAt: baseReceipt?.occurredAt ?? Date(),
            rawText: text,
            summary: "External assist stub",
            confidence: 0.99,
            suggestedCategory: baseReceipt?.suggestedCategory ?? .other
        )
        return SmartResult(receipt: receipt, llmTrace: nil, usedRuleFallback: true)
    }
}
STUB

cat > "$PREP_DIR/IOSStubs.swift" << 'IOSTUB'
import Foundation

enum ExternalReceiptAssistSettings {
    static var isEnabled: Bool = false
}

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

final class UIDevice {
    static let current = UIDevice()
    var model: String { "Offline" }
    var systemName: String { "macOS" }
    var systemVersion: String { "offline" }
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

enum OCRTextCleaner {
    static func clean(_ text: String) -> String { text }
}

// --- NotificationService stub (uses UserNotifications, iOS only) ---
final class NotificationService: Sendable {
    static let shared = NotificationService()
    func requestPermissionIfNeeded() {}
    func scheduleUpcomingChargeReminders(for subscriptions: [Subscription]) {}
    func cancelSubscriptionReminder(id: UUID) {}
}

enum ICloudBackupServiceError: Error {
    case containerUnavailable
}

struct ICloudBackupService {
    func write(bundle: BackupBundle) throws -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("AutoLedgerBackup.json")
    }

    func readBundleIfAvailable() throws -> BackupBundle? { nil }
}

enum LedgerCloudKitSyncMode {
    case disabled
    case dryRun
    case live
}

struct LedgerCloudKitAccountCheck {
    let canUsePrivateDatabase: Bool
    let message: String
}

struct LedgerCloudKitPushResult {
    let savedRecordNames: [String]
}

struct LedgerCloudKitSyncAdapter {
    init(mode: LedgerCloudKitSyncMode = .disabled, allowsLiveCloudKitWrites: Bool = false) {}

    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
    }

    func checkAccountStatus() async -> LedgerCloudKitAccountCheck {
        LedgerCloudKitAccountCheck(canUsePrivateDatabase: false, message: "Offline CloudKit stub")
    }

    func push(batch: LedgerSyncPushBatch) async throws -> LedgerCloudKitPushResult {
        LedgerCloudKitPushResult(savedRecordNames: [])
    }

    func pushConfiguration(_ payload: LedgerConfigurationSyncPayload) async throws -> LedgerCloudKitPushResult {
        LedgerCloudKitPushResult(savedRecordNames: [])
    }

    func pushDashboardSnapshot(_ payload: LedgerDashboardCloudSnapshot) async throws -> LedgerCloudKitPushResult {
        LedgerCloudKitPushResult(savedRecordNames: [])
    }

    func fetchAllTransactionRecords() async throws -> [LedgerTransactionSyncPayload] {
        []
    }

    func fetchConfigurationRecord() async throws -> LedgerConfigurationSyncPayload? {
        nil
    }
}
IOSTUB

swiftc \
  -o "$TMP_BIN" \
  -lsqlite3 \
  "$CORE/Enums/ReceiptSource.swift" \
  "$CORE/Enums/TransactionCategory.swift" \
  "$CORE/Models/ImportedReceipt.swift" \
  "$CORE/Models/ImportDebugRecord.swift" \
  "$CORE/Models/LedgerInterpretationModels.swift" \
  "$CORE/Models/BatchImportQueue.swift" \
  "$CORE/Models/SampleReceipt.swift" \
  "$CORE/Models/MonthlySnapshot.swift" \
  "$CORE/Models/TodaySpendingSummary.swift" \
  "$CORE/Models/SyncMetadata.swift" \
  "$CORE/Models/LedgerSyncPlan.swift" \
  "$CORE/Models/LedgerDashboardCloudSnapshot.swift" \
  "$CORE/Models/HotelStay.swift" \
  "$CORE/Models/Transaction.swift" \
  "$CORE/Models/Subscription.swift" \
  "$CORE/Models/BackupBundle.swift" \
  "$PREP_DIR/ReceiptParser.swift" \
  "$CORE/Services/VoiceLedgerParser.swift" \
  "$CORE/Services/BillRelevanceGate.swift" \
  "$CORE/Services/LedgerAmountInputParser.swift" \
  "$CORE/Services/PaymentAmountExtractor.swift" \
  "$CORE/Services/MerchantResolver.swift" \
  "$CORE/Services/CategoryResolver.swift" \
  "$CORE/Services/SmartReceiptMergePolicy.swift" \
  "$CORE/Services/ExternalReceiptAssistCache.swift" \
  "$CORE/Services/ExternalReceiptAssistPayload.swift" \
  "$CORE/Services/HotelFolioParsePipeline.swift" \
  "$CORE/Services/HotelStayLedgerPostingService.swift" \
  "$CORE/Services/HotelStayReviewForm.swift" \
  "$CORE/Services/LedgerTextInterpreterCore.swift" \
  "$CORE/Services/BatchImportRecognitionExecutor.swift" \
  "$CORE/Services/DataCleaningPreviewPlanner.swift" \
  "$CORE/Services/MerchantAliasResolver.swift" \
  "$CORE/Services/LedgerCSVCodec.swift" \
  "$CORE/Services/StructuredLedgerJSONParser.swift" \
  "$CORE/Services/SampleReceiptProvider.swift" \
  "$CORE/Services/SubscriptionDetector.swift" \
  "$CORE/Persistence/TransactionStore.swift" \
  "$CORE/Persistence/SQLiteTransactionStore.swift" \
  "$PREP_DIR/LedgerTextInterpreter.swift" \
  "$PREP_DIR/LedgerStore.swift" \
  "$PREP_DIR/SmartReceiptParserStub.swift" \
  "$PREP_DIR/IOSStubs.swift" \
  "$CORE/Utils/AppFormatters.swift" \
  "$CORE/Utils/ImportDuplicateDetector.swift" \
  "$CORE/Utils/TextSimilarity.swift" \
  "$ROOT/scripts/OfflineRegression.swift"

"$TMP_BIN"
