#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 "$ROOT/scripts/check_adaptive_layout_rules.py"
python3 "$ROOT/scripts/check_accessibility_smoke.py"
python3 "$ROOT/scripts/check_deep_link_smoke.py"
python3 "$ROOT/scripts/check_cloudkit_sync_smoke.py"
python3 "$ROOT/scripts/check_cloudkit_hotel_pdf_asset_smoke.py"
python3 "$ROOT/scripts/check_hotel_email_import_smoke.py"
python3 "$ROOT/scripts/check_app_intents_smoke.py"
python3 "$ROOT/scripts/check_widget_smoke.py"
python3 "$ROOT/scripts/check_reliability_smoke.py"
python3 "$ROOT/scripts/check_long_list_performance_smoke.py"
python3 "$ROOT/scripts/check_performance_fixture_smoke.py"
python3 "$ROOT/scripts/check_l10n_release_smoke.py"
python3 "$ROOT/scripts/check_visionos_review_smoke.py"
python3 "$ROOT/scripts/check_data_cleaning_ios_entry_smoke.py"
python3 "$ROOT/scripts/check_pending_action_center_smoke.py"
python3 "$ROOT/scripts/check_advanced_search_ui_smoke.py"
python3 "$ROOT/scripts/check_cloud_inbox_entitlement_smoke.py"
python3 "$ROOT/scripts/check_subscription_anomaly_ui_smoke.py"
python3 "$ROOT/scripts/check_monthly_export_ui_smoke.py"
python3 "$ROOT/scripts/check_share_cards_smoke.py"
python3 "$ROOT/scripts/check_advanced_rule_automation_ui_smoke.py"
python3 "$ROOT/scripts/check_pro_page_copy_smoke.py"
python3 "$ROOT/scripts/check_asc_metadata_as_code_smoke.py"
python3 "$ROOT/scripts/check_screenshot_localization_smoke.py"
python3 "$ROOT/scripts/check_app_preview_v003_smoke.py"
python3 "$ROOT/scripts/check_hotel_weather_ui_smoke.py"
python3 "$ROOT/scripts/check_documentation_truth_smoke.py"

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
sed '/import AutoLedgerCore/d' "$ROOT/AutoLedger/AutoLedger/Domain/Services/MonthlyInsightService.swift" > "$PREP_DIR/MonthlyInsightService.swift"

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

enum ExpenseCurrencyPreference {
    static let userDefaultsKey = "expenseDefaultCurrencyCode"
    static let systemValue = "system"
    static var systemCurrencyCode: String { "CNY" }
    static var currentCode: String { "CNY" }
    static func normalizedRawValue(_ value: String?) -> String { value ?? systemValue }
}

struct CurrencyConversionPreviewQuote: Equatable {
    let sourceAmount: Double
    let sourceCurrencyCode: String
    let targetCurrencyCode: String
    let convertedAmount: Double
    let rate: Double
    let rateDate: String
    let provider: String
}

struct LedgerCurrencyOption: Identifiable, Hashable {
    static let defaultCode = "CNY"

    let code: String
    let symbol: String
    let decimalDigits: Int

    var id: String { code }

    static var common: [LedgerCurrencyOption] {
        [
            .init(code: "CNY", symbol: "¥", decimalDigits: 2),
            .init(code: "USD", symbol: "$", decimalDigits: 2),
            .init(code: "EUR", symbol: "€", decimalDigits: 2),
            .init(code: "JPY", symbol: "¥", decimalDigits: 0),
            .init(code: "GBP", symbol: "£", decimalDigits: 2),
            .init(code: "HKD", symbol: "HK$", decimalDigits: 2),
            .init(code: "MOP", symbol: "MOP$", decimalDigits: 2),
            .init(code: "TWD", symbol: "NT$", decimalDigits: 2),
            .init(code: "SGD", symbol: "S$", decimalDigits: 2),
            .init(code: "KRW", symbol: "₩", decimalDigits: 0),
            .init(code: "THB", symbol: "฿", decimalDigits: 2),
            .init(code: "MYR", symbol: "RM", decimalDigits: 2),
            .init(code: "IDR", symbol: "Rp", decimalDigits: 0),
            .init(code: "PHP", symbol: "₱", decimalDigits: 2),
            .init(code: "VND", symbol: "₫", decimalDigits: 0),
            .init(code: "AUD", symbol: "A$", decimalDigits: 2),
            .init(code: "CAD", symbol: "C$", decimalDigits: 2),
            .init(code: "CHF", symbol: "CHF", decimalDigits: 2),
            .init(code: "NZD", symbol: "NZ$", decimalDigits: 2),
            .init(code: "AED", symbol: "د.إ", decimalDigits: 2)
        ]
    }

    static func supportedCode(matching value: String?) -> String {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        return common.contains { $0.code == normalized } ? normalized : defaultCode
    }
}

enum CommonAPIExchangeRateService {
    struct Quote: Sendable {
        let baseCurrencyCode: String
        let quoteCurrencyCode: String
        let date: String
        let rate: Double
        let provider: String
    }

    nonisolated static func quote(
        baseCurrencyCode: String,
        quoteCurrencyCode: String,
        date: Date
    ) async throws -> Quote {
        Quote(
            baseCurrencyCode: baseCurrencyCode,
            quoteCurrencyCode: quoteCurrencyCode,
            date: "offline",
            rate: 1,
            provider: "offline-regression"
        )
    }
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
    var assetFallbackRecordNames: [String] = []
}

struct LedgerCloudKitSyncAdapter {
    static let hasDefaultContainerEntitlement = false

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

    func pushSyncManifest(_ payload: LedgerCloudSyncManifest) async throws -> LedgerCloudKitPushResult {
        LedgerCloudKitPushResult(savedRecordNames: [])
    }

    func pushDashboardSnapshot(_ payload: LedgerDashboardCloudSnapshot) async throws -> LedgerCloudKitPushResult {
        LedgerCloudKitPushResult(savedRecordNames: [])
    }

    func pushHotelStayArchive(
        records: [LedgerHotelStayRecordSyncPayload],
        drafts: [LedgerHotelStayDraftSyncPayload]
    ) async throws -> LedgerCloudKitPushResult {
        LedgerCloudKitPushResult(savedRecordNames: [])
    }

    func fetchAllTransactionRecords() async throws -> [LedgerTransactionSyncPayload] {
        []
    }

    func fetchAllTransactionRecords(recordNames: [String]) async throws -> [LedgerTransactionSyncPayload] {
        []
    }

    func fetchAllHotelStayRecords() async throws -> [LedgerHotelStayRecordSyncPayload] {
        []
    }

    func fetchAllHotelStayRecords(recordNames: [String]) async throws -> [LedgerHotelStayRecordSyncPayload] {
        []
    }

    func fetchAllHotelStayDrafts() async throws -> [LedgerHotelStayDraftSyncPayload] {
        []
    }

    func fetchAllHotelStayDrafts(recordNames: [String]) async throws -> [LedgerHotelStayDraftSyncPayload] {
        []
    }

    func fetchConfigurationRecord() async throws -> LedgerConfigurationSyncPayload? {
        nil
    }

    func fetchSyncManifest() async throws -> LedgerCloudSyncManifest? {
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
  "$CORE/Models/LedgerProfile.swift" \
  "$CORE/Models/SyncMetadata.swift" \
  "$CORE/Models/LedgerSyncPlan.swift" \
  "$CORE/Models/LedgerDashboardCloudSnapshot.swift" \
  "$CORE/Models/HotelStay.swift" \
  "$CORE/Models/ProAccessPolicy.swift" \
  "$CORE/Models/Transaction.swift" \
  "$CORE/Models/Subscription.swift" \
  "$CORE/Models/BackupBundle.swift" \
  "$PREP_DIR/ReceiptParser.swift" \
  "$CORE/Services/VoiceLedgerParser.swift" \
  "$CORE/Services/LedgerRecognitionLanguagePack.swift" \
  "$CORE/Services/LedgerDateCandidateExtractor.swift" \
  "$CORE/Services/BillRelevanceGate.swift" \
  "$CORE/Services/LedgerAmountInputParser.swift" \
  "$CORE/Services/PaymentAmountExtractor.swift" \
  "$CORE/Services/ReceiptCurrencyDetector.swift" \
  "$CORE/Services/MerchantResolver.swift" \
  "$CORE/Services/CategoryResolver.swift" \
  "$CORE/Services/SmartReceiptMergePolicy.swift" \
  "$CORE/Services/ExternalReceiptAssistCache.swift" \
  "$CORE/Services/ExternalReceiptAssistPayload.swift" \
  "$CORE/Services/HotelCurrencyCodeNormalizer.swift" \
  "$CORE/Services/HotelFolioTextPDFBuilder.swift" \
  "$CORE/Services/HotelFolioEmailImportPlanning.swift" \
  "$CORE/Services/HotelFolioCloudInboxPlanning.swift" \
  "$CORE/Services/HotelFolioDebugTraceBuilder.swift" \
  "$CORE/Services/HotelFolioParsePipeline.swift" \
  "$CORE/Services/HotelStayArchivePresenter.swift" \
  "$CORE/Services/HotelStayLedgerPostingService.swift" \
  "$CORE/Services/HotelStayReviewForm.swift" \
  "$CORE/Services/LedgerTextInterpreterCore.swift" \
  "$CORE/Services/BatchImportRecognitionExecutor.swift" \
  "$CORE/Services/LedgerAdvancedSearch.swift" \
  "$CORE/Services/DataCleaningPreviewPlanner.swift" \
  "$CORE/Services/AdvancedRuleAutomationPlanner.swift" \
  "$CORE/Services/PendingActionCenterPlanner.swift" \
  "$CORE/Services/DataCleaningAssistPayload.swift" \
  "$CORE/Services/MerchantAliasResolver.swift" \
  "$CORE/Services/LedgerCSVCodec.swift" \
  "$CORE/Services/StructuredLedgerJSONParser.swift" \
  "$CORE/Services/SampleReceiptProvider.swift" \
  "$CORE/Services/SubscriptionDetector.swift" \
  "$CORE/Services/SubscriptionAnomalyDetector.swift" \
  "$CORE/Services/MonthlyExportPackageBuilder.swift" \
  "$CORE/Persistence/TransactionStore.swift" \
  "$CORE/Persistence/SQLiteTransactionStore.swift" \
  "$PREP_DIR/MonthlyInsightService.swift" \
  "$PREP_DIR/LedgerTextInterpreter.swift" \
  "$PREP_DIR/LedgerStore.swift" \
  "$PREP_DIR/SmartReceiptParserStub.swift" \
  "$PREP_DIR/IOSStubs.swift" \
  "$CORE/Utils/AppFormatters.swift" \
  "$CORE/Utils/ImportDuplicateDetector.swift" \
  "$CORE/Utils/TextSimilarity.swift" \
  "$ROOT/scripts/OfflineRegression.swift"

AUTOLEDGER_OFFLINE_REGRESSION=1 "$TMP_BIN"
