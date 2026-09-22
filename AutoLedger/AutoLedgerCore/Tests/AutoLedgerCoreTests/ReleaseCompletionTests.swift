import XCTest
@testable import AutoLedgerCore

final class ReleaseCompletionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_780_272_000)

    func testReopenSurvivesOlderCompletionAndMergeOrder() {
        let old = MonthCloseRecord(completedAt: start, updatedAt: start, exportedAt: start)
        let reopened = MonthCloseRecord(updatedAt: start.addingTimeInterval(1))
        let first = MonthCloseRecord.merge(["month": old], ["month": reopened])
        XCTAssertNil(first["month"]?.completedAt)
        XCTAssertEqual(first["month"]?.exportedAt, start)
        XCTAssertEqual(first, MonthCloseRecord.merge(["month": reopened], ["month": old]))
    }

    func testMonthCloseKeySeparatesLedgerAndMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let next = try XCTUnwrap(calendar.date(byAdding: .month, value: 1, to: start))
        XCTAssertNotEqual(MonthCloseRecord.key(month: start, ledgerID: "a", calendar: calendar),
                          MonthCloseRecord.key(month: start, ledgerID: "b", calendar: calendar))
        XCTAssertNotEqual(MonthCloseRecord.key(month: start, ledgerID: "a", calendar: calendar),
                          MonthCloseRecord.key(month: next, ledgerID: "a", calendar: calendar))
    }

    func testMonthlyOutstandingIncludesDeferredButNotHandledOrOtherMonths() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let month = try XCTUnwrap(calendar.dateInterval(of: .month, for: start))
        let current = try PendingActionItem(kind: .missingInformation, source: .init(type: .transaction, id: "a"), reason: .categoryMissing, createdAt: start)
        let deferred = try current.applying(.deferUntil(start.addingTimeInterval(90 * 86_400)), at: start)
        let outside = try PendingActionItem(kind: .missingInformation, source: .init(type: .transaction, id: "b"), reason: .categoryMissing, createdAt: month.end)
        let snapshot = PendingActionCenterPlanner().buildSnapshot(items: [deferred, outside], at: start)
        XCTAssertEqual(MonthClosePlanner.outstanding(in: snapshot, month: start, calendar: calendar).map(\.id), [current.id])
        let handled = PendingActionCenterPlanner().buildSnapshot(items: [try current.applying(.dismiss, at: start)])
        XCTAssertTrue(MonthClosePlanner.outstanding(in: handled, month: start, calendar: calendar).isEmpty)
    }

    func testSourceRevisionPreventsOldDecisionHidingNewConflict() throws {
        let source = PendingActionSourceReference(type: .transactionSync, id: "tx", revision: "1")
        let old = try PendingActionItem(kind: .syncConflict, source: source, reason: .syncConflictNeedsReview, createdAt: start)
        XCTAssertFalse(old.availableActions.contains(.dismiss))
        let decision = try PendingActionDecision(item: old, mutation: .deferUntil(nil), updatedAt: start)
        let fresh = try PendingActionItem(kind: .syncConflict, source: .init(type: .transactionSync, id: "tx", revision: "2"), reason: .syncConflictNeedsReview, createdAt: start)
        let result = PendingActionDecisionOverlay.applying([decision.id.rawValue: decision], to: [fresh], at: start)
        XCTAssertEqual(result.first?.state, .pending)
    }

    func testReopenedDecisionTombstoneBeatsOldDismissal() throws {
        let item = try PendingActionItem(kind: .emailCandidate, source: .init(type: .emailCandidate, id: "opaque"), reason: .emailNeedsReview, createdAt: start)
        let old = try PendingActionDecision(item: item, mutation: .dismiss, updatedAt: start)
        let reopened = try PendingActionDecision(item: item, mutation: .reopen, updatedAt: start.addingTimeInterval(1))
        let normalized = PendingActionDecision.normalizedDictionary(["old": old, "new": reopened])
        XCTAssertEqual(normalized[item.id.rawValue]?.disposition, .reopened)
        XCTAssertEqual(PendingActionDecisionOverlay.applying(normalized, to: [item]).first?.state, .pending)
    }

    func testRetryStatePersistsAndBacksOff() throws {
        var state = DataCleaningAssistRetryState()
        state.recordFailure(at: start)
        XCTAssertEqual(state.nextEligibleAt, start.addingTimeInterval(60))
        state = try JSONDecoder().decode(DataCleaningAssistRetryState.self, from: JSONEncoder().encode(state))
        state.recordFailure(at: start)
        XCTAssertEqual(state.nextEligibleAt, start.addingTimeInterval(120))
        state.recordFailure(at: start, retryAfter: 3_600)
        XCTAssertEqual(state.nextEligibleAt, start.addingTimeInterval(3_600))
        state.recordSuccess(at: start)
        XCTAssertEqual(state.failures, 0)
        XCTAssertEqual(state.nextEligibleAt, start.addingTimeInterval(21_600))
    }
    private func configuration(records: [String: MonthCloseRecord]) -> LedgerConfigurationSyncPayload {
        LedgerConfigurationSyncPayload(updatedAt: start, deviceID: "device", subscriptions: [],
            categoryCorrections: [], customCategories: [], customSources: [], merchantAliases: [:],
            subscriptionMetadata: BackupSubscriptionMetadata(annualPriceOverrides: [:], notes: [:]),
            monthCloseRecords: records,
            appSettings: BackupAppSettings(subscriptionReminderEnabled: false, monthlyAnomalyThresholdPercent: 150,
                llmEnhancementEnabled: false, autoClipboardImportEnabled: false, iCloudBackupEnabled: false))
    }

    func testConfigurationRoundTripAndOldPayloadCompatibility() throws {
        let original = configuration(records: ["m": MonthCloseRecord(completedAt: start, updatedAt: start)])
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(LedgerConfigurationSyncPayload.self, from: data), original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "monthCloseRecords")
        let legacy = try JSONDecoder().decode(LedgerConfigurationSyncPayload.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(legacy.monthCloseRecords.isEmpty)
        let merged = LedgerConfigurationSyncPolicy.merge(local: original, remote: legacy)
        XCTAssertEqual(merged.monthCloseRecords, original.monthCloseRecords)
        XCTAssertTrue(LedgerConfigurationSyncPolicy.hasDifferentUserConfigurationContent(original, legacy))
    }

    func testAllNewSourcesHaveDistinctIdentityAndTargets() throws {
        let kinds: [PendingActionKind] = [.emailCandidate, .cloudInboxCandidate, .syncConflict, .missingInformation]
        let items = try kinds.map { try PendingActionItem(kind: $0, source: .init(type: .transaction, id: "same"), reason: .categoryMissing, createdAt: start) }
        XCTAssertEqual(Set(items.map(\.id)).count, 4)
        XCTAssertEqual(Set(items.map(\.target)).count, 4)
        let roundTrip = try JSONDecoder().decode([PendingActionItem].self, from: JSONEncoder().encode(items))
        XCTAssertEqual(roundTrip, items)
    }

    func testNewDecisionKindsDoNotBreakOlderConfigurationReaders() throws {
        let item = try PendingActionItem(kind: .emailCandidate, source: .init(type: .emailCandidate, id: "mail"), reason: .emailNeedsReview, createdAt: start)
        let decision = try PendingActionDecision(item: item, mutation: .dismiss, updatedAt: start)
        let config = configuration(records: [:])
        let value = LedgerConfigurationSyncPayload(updatedAt: start, deviceID: "new", subscriptions: [],
            categoryCorrections: [], customCategories: [], customSources: [], merchantAliases: [:],
            subscriptionMetadata: config.subscriptionMetadata,
            pendingActionDecisions: [decision.id.rawValue: decision], appSettings: config.appSettings)
        let data = try JSONEncoder().encode(value)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual((object["pendingActionDecisions"] as? [String: Any])?.count, 0)
        XCTAssertEqual((object["extendedPendingActionDecisions"] as? [String: Any])?.count, 1)
        XCTAssertEqual(try JSONDecoder().decode(LedgerConfigurationSyncPayload.self, from: data).pendingActionDecisions, value.pendingActionDecisions)
    }

}
