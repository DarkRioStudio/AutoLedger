import Foundation

public enum ImportDuplicateDetector {
    public static func hasOCRTextDuplicate(
        rawText: String,
        debugRecords: [ImportDebugRecord],
        activeTransactionIDs: Set<UUID>,
        imageSource: ImageSource? = nil,
        parsedAmount: Double? = nil,
        amountTolerance: Double = 0.01,
        threshold: Double = 0.8,
        limit: Int = 30
    ) -> Bool {
        guard !rawText.isEmpty else { return false }

        let recentTexts = debugRecords
            .filter { record in
                guard record.stage == .persisted,
                      let transactionID = record.transactionID,
                      activeTransactionIDs.contains(transactionID) else {
                    return false
                }
                if let imageSource {
                    return record.imageSource == imageSource
                }
                return true
            }
            .prefix(limit)
            .filter { record in
                amountsAreCompatible(
                    current: parsedAmount,
                    previous: record.parsedAmount,
                    tolerance: amountTolerance
                )
            }
            .map(\.rawText)

        return recentTexts.contains {
            !$0.isEmpty && TextSimilarity.jaccard(rawText, $0) > threshold
        }
    }

    private static func amountsAreCompatible(current: Double?, previous: Double?, tolerance: Double) -> Bool {
        guard let current, let previous else { return true }
        return abs(current - previous) < tolerance
    }
}
