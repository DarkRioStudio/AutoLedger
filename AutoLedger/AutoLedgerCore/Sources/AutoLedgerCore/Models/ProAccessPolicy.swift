import Foundation

public enum AutoLedgerCapability: String, CaseIterable, Codable, Equatable, Sendable {
    case manualTransactionEntry
    case singleReceiptScan
    case manualHotelFolioImport
    case hotelStayArchiveAccess
    case basicSubscriptionManagement
    case basicMonthlyReport
    case basicWidgetAndShareExtension
    case basicDataExportAndBackup
    case historyViewEditDelete
    case supportDeveloperDonation

    case localEmailFolioScan
    case batchCandidateImport
    case advancedDeduplication
    case cloudFolioInbox

    case advancedSearch
    case subscriptionAnomalyDetection
    case monthlyExportPackage
    case advancedRuleAutomation
}

public enum ProAccessTier: String, Codable, Equatable, Sendable {
    case freeCore
    case proAutomationP0
    case proAutomationLater
}

public struct AutoLedgerProAccessPolicy: Equatable, Sendable {
    public static let current = AutoLedgerProAccessPolicy()

    public init() {}

    public func tier(for capability: AutoLedgerCapability) -> ProAccessTier {
        switch capability {
        case .manualTransactionEntry,
             .singleReceiptScan,
             .manualHotelFolioImport,
             .hotelStayArchiveAccess,
             .basicSubscriptionManagement,
             .basicMonthlyReport,
             .basicWidgetAndShareExtension,
             .basicDataExportAndBackup,
             .historyViewEditDelete,
             .supportDeveloperDonation:
            return .freeCore

        case .localEmailFolioScan,
             .batchCandidateImport,
             .advancedDeduplication,
             .cloudFolioInbox:
            return .proAutomationP0

        case .advancedSearch,
             .subscriptionAnomalyDetection,
             .monthlyExportPackage,
             .advancedRuleAutomation:
            return .proAutomationLater
        }
    }

    public var freeCoreCapabilities: [AutoLedgerCapability] {
        AutoLedgerCapability.allCases.filter { tier(for: $0) == .freeCore }
    }

    public var p0ProAutomationCapabilities: [AutoLedgerCapability] {
        AutoLedgerCapability.allCases.filter { tier(for: $0) == .proAutomationP0 }
    }

    public var laterProAutomationCapabilities: [AutoLedgerCapability] {
        AutoLedgerCapability.allCases.filter { tier(for: $0) == .proAutomationLater }
    }

    public func isAvailableWithoutPro(_ capability: AutoLedgerCapability) -> Bool {
        tier(for: capability) == .freeCore
    }

    public func requiresActiveProInCurrentRelease(_ capability: AutoLedgerCapability) -> Bool {
        tier(for: capability) == .proAutomationP0
    }

    public func isPlannedProAutomation(_ capability: AutoLedgerCapability) -> Bool {
        tier(for: capability) != .freeCore
    }

    public func remainsAvailableAfterProExpiration(_ capability: AutoLedgerCapability) -> Bool {
        tier(for: capability) == .freeCore
    }

    public func manualFallbacks(for capability: AutoLedgerCapability) -> [AutoLedgerCapability] {
        switch capability {
        case .localEmailFolioScan, .cloudFolioInbox:
            return [.manualHotelFolioImport, .hotelStayArchiveAccess]
        case .batchCandidateImport:
            return [.singleReceiptScan, .manualHotelFolioImport]
        case .advancedDeduplication, .advancedRuleAutomation:
            return [.historyViewEditDelete]
        case .advancedSearch:
            return [.historyViewEditDelete]
        case .subscriptionAnomalyDetection:
            return [.basicSubscriptionManagement]
        case .monthlyExportPackage:
            return [.basicDataExportAndBackup, .basicMonthlyReport]
        case .manualTransactionEntry,
             .singleReceiptScan,
             .manualHotelFolioImport,
             .hotelStayArchiveAccess,
             .basicSubscriptionManagement,
             .basicMonthlyReport,
             .basicWidgetAndShareExtension,
             .basicDataExportAndBackup,
             .historyViewEditDelete,
             .supportDeveloperDonation:
            return []
        }
    }
}

public struct LocalEmailFolioImportAllowanceState: Codable, Equatable, Sendable {
    public static let freeImportLimitPerMonth = 1

    public var periodIdentifier: String
    public var successfulImportCount: Int

    public init(periodIdentifier: String, successfulImportCount: Int = 0) {
        self.periodIdentifier = periodIdentifier
        self.successfulImportCount = max(0, successfulImportCount)
    }

    public var remainingFreeImports: Int {
        max(0, Self.freeImportLimitPerMonth - successfulImportCount)
    }

    public static func fresh(for date: Date = Date(), calendar: Calendar = .current) -> Self {
        LocalEmailFolioImportAllowanceState(periodIdentifier: periodIdentifier(for: date, calendar: calendar))
    }

    public static func periodIdentifier(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 1
        return String(format: "%04d-%02d", year, month)
    }

    public func normalized(for date: Date = Date(), calendar: Calendar = .current) -> Self {
        let currentPeriod = Self.periodIdentifier(for: date, calendar: calendar)
        guard periodIdentifier == currentPeriod else {
            return .fresh(for: date, calendar: calendar)
        }
        return LocalEmailFolioImportAllowanceState(
            periodIdentifier: periodIdentifier,
            successfulImportCount: successfulImportCount
        )
    }

    public func allowsImport(isProActive: Bool, at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        isProActive || normalized(for: date, calendar: calendar).remainingFreeImports > 0
    }

    public func consumingSuccessfulImport(
        isProActive: Bool,
        importedDraftCount: Int,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> Self {
        var state = normalized(for: date, calendar: calendar)
        guard !isProActive, importedDraftCount > 0 else { return state }
        state.successfulImportCount += 1
        return state
    }
}
