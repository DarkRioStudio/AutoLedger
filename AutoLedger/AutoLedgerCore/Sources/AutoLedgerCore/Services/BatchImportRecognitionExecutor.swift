import Foundation

public struct BatchImportRecognitionLog: Codable, Equatable, Sendable {
    public var itemID: UUID
    public var message: String
    public var createdAt: Date

    public init(itemID: UUID, message: String, createdAt: Date = Date()) {
        self.itemID = itemID
        self.message = message
        self.createdAt = createdAt
    }
}

public struct BatchImportRecognitionResult: Codable, Equatable, Sendable {
    public var snapshot: BatchImportQueueSnapshot
    public var processedCount: Int
    public var candidateCount: Int
    public var failedCount: Int
    public var logs: [BatchImportRecognitionLog]

    public init(
        snapshot: BatchImportQueueSnapshot,
        processedCount: Int,
        candidateCount: Int,
        failedCount: Int,
        logs: [BatchImportRecognitionLog]
    ) {
        self.snapshot = snapshot
        self.processedCount = processedCount
        self.candidateCount = candidateCount
        self.failedCount = failedCount
        self.logs = logs
    }
}

public struct BatchImportRecognitionExecutor: Sendable {
    private let interpreter: LedgerTextInterpreterCore
    private let localeIdentifier: String?
    private let timeZoneIdentifier: String?

    public init(
        interpreter: LedgerTextInterpreterCore = LedgerTextInterpreterCore(),
        localeIdentifier: String? = Locale.autoupdatingCurrent.identifier,
        timeZoneIdentifier: String? = TimeZone.autoupdatingCurrent.identifier
    ) {
        self.interpreter = interpreter
        self.localeIdentifier = localeIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public func process(
        snapshot: BatchImportQueueSnapshot,
        itemIDs: Set<UUID>? = nil,
        now: Date = Date()
    ) -> BatchImportRecognitionResult {
        let rawInputsByID = Dictionary(uniqueKeysWithValues: snapshot.rawInputs.map { ($0.id, $0) })
        var nextItems: [BatchImportQueueItem] = []
        var logs: [BatchImportRecognitionLog] = []
        var processedCount = 0
        var candidateCount = 0
        var failedCount = 0

        for item in snapshot.items {
            guard shouldProcess(item, itemIDs: itemIDs) else {
                nextItems.append(item)
                continue
            }

            guard let rawInput = rawInputsByID[item.rawInputID] else {
                let failed = item.markedFailed(reason: .parseFailed, now: now)
                nextItems.append(failed)
                logs.append(BatchImportRecognitionLog(itemID: item.id, message: "Raw input missing", createdAt: now))
                processedCount += 1
                failedCount += 1
                continue
            }

            let processed = process(item: item, rawInput: rawInput, now: now)
            nextItems.append(processed.item)
            logs.append(BatchImportRecognitionLog(itemID: item.id, message: processed.message, createdAt: now))
            processedCount += 1
            if processed.item.state == .candidate {
                candidateCount += 1
            }
            if processed.item.failureReason != nil {
                failedCount += 1
            }
        }

        let nextBatches = snapshot.batches.map { batch -> BatchImportBatch in
            var next = batch
            guard itemIDs == nil || nextItems.contains(where: { $0.batchID == batch.id && itemIDs?.contains($0.id) == true }) else {
                return next
            }
            next.status = nextBatchStatus(for: nextItems.filter { $0.batchID == batch.id })
            next.updatedAt = now
            return next
        }

        return BatchImportRecognitionResult(
            snapshot: BatchImportQueueSnapshot(
                batches: nextBatches,
                rawInputs: snapshot.rawInputs,
                items: nextItems
            ),
            processedCount: processedCount,
            candidateCount: candidateCount,
            failedCount: failedCount,
            logs: logs
        )
    }

    private func shouldProcess(_ item: BatchImportQueueItem, itemIDs: Set<UUID>?) -> Bool {
        if let itemIDs, !itemIDs.contains(item.id) {
            return false
        }
        return item.state == .rawInput
    }

    private func process(
        item: BatchImportQueueItem,
        rawInput: BatchRawInput,
        now: Date
    ) -> (item: BatchImportQueueItem, message: String) {
        guard supportsRecognition(rawInput) else {
            return (
                item.markedFailed(reason: .unsupportedFileType, now: now),
                "Unsupported batch input type"
            )
        }

        let text = rawInput.rawText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            let reason: BatchImportFailureReason = rawInput.sourceKind == .text || rawInput.sourceKind == .clipboard
                ? .emptyInput
                : .ocrFailed
            return (item.markedFailed(reason: reason, now: now), reason == .emptyInput ? "Empty text input" : "OCR text unavailable")
        }

        let input = InterpretInput(
            rawText: text,
            sourceType: sourceType(for: rawInput.sourceKind),
            localeIdentifier: localeIdentifier,
            timeZoneIdentifier: timeZoneIdentifier,
            hints: LedgerInterpretHints(sourceHint: sourceHint(for: rawInput))
        )
        let interpreted = interpreter.interpret(input)
        let nextItem = item.applyingInterpretation(interpreted, now: now)
        let message: String
        if nextItem.state == .candidate {
            message = nextItem.failureReason == nil ? "Candidate generated" : "Candidate needs review"
        } else {
            message = "Recognition did not produce a candidate"
        }
        return (nextItem, message)
    }

    private func supportsRecognition(_ rawInput: BatchRawInput) -> Bool {
        switch rawInput.sourceKind {
        case .photos, .clipboard, .share, .shortcut, .camera, .text:
            return true
        case .files:
            guard let type = rawInput.originalUTType?.lowercased() ?? rawInput.originalFileName?.lowercased() else {
                return rawInput.rawText != nil
            }
            return rawInput.rawText != nil || type.contains("text") || type.hasSuffix(".txt")
        }
    }

    private func sourceType(for sourceKind: BatchImportSourceKind) -> LedgerInputSourceType {
        switch sourceKind {
        case .clipboard:
            return .clipboard
        case .share:
            return .share
        case .shortcut:
            return .siri
        case .photos, .files, .camera, .text:
            return .ocr
        }
    }

    private func sourceHint(for rawInput: BatchRawInput) -> LedgerSourceHint {
        switch rawInput.sourceKind {
        case .shortcut:
            return .sentence
        case .text, .clipboard, .share, .photos, .files, .camera:
            return .receipt
        }
    }

    private func nextBatchStatus(for items: [BatchImportQueueItem]) -> BatchImportBatchStatus {
        guard !items.isEmpty else { return .pending }
        if items.contains(where: { $0.state == .rawInput && $0.failureReason == nil }) {
            return .running
        }
        if items.allSatisfy({ $0.state == .rejected || $0.failureReason != nil }) {
            return .failed
        }
        return .completed
    }
}
