import AppIntents
import AutoLedgerCore
import Foundation

enum AutoLedgerIntentNavigationDestination: String, Codable, Sendable {
    case monthlyReport
    case ledger
    case receiptScan
    case hotelReviewQueue
}

struct AutoLedgerIntentNavigationRequest: Codable, Sendable {
    let destination: AutoLedgerIntentNavigationDestination
    let ledgerID: String?
    let createdAt: Date

    init(
        destination: AutoLedgerIntentNavigationDestination,
        ledgerID: String? = nil,
        createdAt: Date = Date()
    ) {
        self.destination = destination
        self.ledgerID = ledgerID
        self.createdAt = createdAt
    }
}

enum AutoLedgerIntentNavigationHandoff {
    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let pendingRequestKey = "autoLedgerIntentNavigationPendingRequest.v1"

    static func submit(destination: AutoLedgerIntentNavigationDestination, ledgerID: String? = nil) {
        let request = AutoLedgerIntentNavigationRequest(destination: destination, ledgerID: ledgerID)
        guard let data = try? JSONEncoder().encode(request) else { return }
        UserDefaults.standard.set(data, forKey: pendingRequestKey)
        UserDefaults(suiteName: appGroupIdentifier)?.set(data, forKey: pendingRequestKey)
    }

    static func consume() -> AutoLedgerIntentNavigationRequest? {
        let stores = [UserDefaults(suiteName: appGroupIdentifier), UserDefaults.standard].compactMap { $0 }
        let data = stores.lazy.compactMap { $0.data(forKey: pendingRequestKey) }.first
        stores.forEach { $0.removeObject(forKey: pendingRequestKey) }
        guard let data else { return nil }
        return try? JSONDecoder().decode(AutoLedgerIntentNavigationRequest.self, from: data)
    }
}

struct LedgerProfileEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "ledger_profile.entity.type"
    static var defaultQuery = LedgerProfileEntityQuery()

    let id: String
    let name: String
    let isDefault: Bool

    init(id: String, name: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }

    init(profile: LedgerProfile) {
        self.init(id: profile.id, name: profile.name, isDefault: profile.isDefault)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: isDefault ? "wallet.pass.fill" : "wallet.pass")
        )
    }
}

struct LedgerProfileEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [LedgerProfileEntity.ID]) async throws -> [LedgerProfileEntity] {
        let requested = Set(identifiers)
        return loadEntities().filter { requested.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [LedgerProfileEntity] {
        let keyword = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return loadEntities() }
        return loadEntities().filter { $0.name.lowercased().contains(keyword) }
    }

    func suggestedEntities() async throws -> [LedgerProfileEntity] {
        loadEntities()
    }

    func defaultResult() async -> LedgerProfileEntity? {
        loadEntities().first { $0.isDefault } ?? loadEntities().first
    }

    private func loadEntities() -> [LedgerProfileEntity] {
        let profiles: [LedgerProfile]
        if let store = try? SQLiteTransactionStore() {
            profiles = (try? store.loadLedgerProfiles(includeArchived: false)) ?? []
        } else {
            profiles = []
        }
        let activeProfiles = profiles.isEmpty ? [LedgerProfile.defaultLocal()] : profiles
        return activeProfiles.map(LedgerProfileEntity.init(profile:))
    }
}

struct OpenMonthlyReportIntent: AppIntent {
    static var title: LocalizedStringResource = "open_monthly_report.intent.title"
    static var description: IntentDescription = IntentDescription("open_monthly_report.intent.description")
    static var openAppWhenRun: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("open_monthly_report.parameter_summary")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AutoLedgerIntentNavigationHandoff.submit(destination: .monthlyReport)
        return .result(value: String(localized: "open_monthly_report.launched"))
    }
}

struct OpenLedgerProfileIntent: AppIntent {
    static var title: LocalizedStringResource = "open_ledger.intent.title"
    static var description: IntentDescription = IntentDescription("open_ledger.intent.description")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "open_ledger.ledger.title", description: "open_ledger.ledger.description")
    var ledger: LedgerProfileEntity

    static var parameterSummary: some ParameterSummary {
        Summary("open_ledger.parameter_summary")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AutoLedgerIntentNavigationHandoff.submit(destination: .ledger, ledgerID: ledger.id)
        return .result(value: String(format: String(localized: "open_ledger.launched_format"), ledger.name))
    }
}

struct StartReceiptScanIntent: AppIntent {
    static var title: LocalizedStringResource = "start_receipt_scan.intent.title"
    static var description: IntentDescription = IntentDescription("start_receipt_scan.intent.description")
    static var openAppWhenRun: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("start_receipt_scan.parameter_summary")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AutoLedgerIntentNavigationHandoff.submit(destination: .receiptScan)
        return .result(value: String(localized: "start_receipt_scan.launched"))
    }
}

struct OpenHotelReviewQueueIntent: AppIntent {
    static var title: LocalizedStringResource = "open_hotel_review_queue.intent.title"
    static var description: IntentDescription = IntentDescription("open_hotel_review_queue.intent.description")
    static var openAppWhenRun: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("open_hotel_review_queue.parameter_summary")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AutoLedgerIntentNavigationHandoff.submit(destination: .hotelReviewQueue)
        return .result(value: String(localized: "open_hotel_review_queue.launched"))
    }
}
