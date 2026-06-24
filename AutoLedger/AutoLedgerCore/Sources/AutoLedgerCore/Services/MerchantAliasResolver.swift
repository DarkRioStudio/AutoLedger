import Foundation

public enum MerchantAliasResolver {
    public static func resolvedMerchant(
        for merchant: String,
        aliases: [String: String]
    ) -> String {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMerchant.isEmpty else { return merchant }

        if let alias = aliases[merchant] ?? aliases[trimmedMerchant] {
            let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedAlias.isEmpty ? merchant : trimmedAlias
        }

        for (original, alias) in aliases
            where original.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedMerchant {
            let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedAlias.isEmpty ? merchant : trimmedAlias
        }

        return merchant
    }

    public static func applyingAlias(
        to receipt: ImportedReceipt,
        aliases: [String: String],
        categoryCorrections: [String: TransactionCategory],
        contextText: String
    ) -> ImportedReceipt {
        let resolvedMerchant = resolvedMerchant(for: receipt.merchant, aliases: aliases)
        let correctedCategory = categoryCorrections[resolvedMerchant] ?? categoryCorrections[receipt.merchant]

        guard resolvedMerchant != receipt.merchant || correctedCategory != nil else {
            return receipt
        }

        let category: TransactionCategory
        if let correctedCategory {
            category = correctedCategory
        } else {
            category = TransactionCategory.infer(
                from: "\(resolvedMerchant)\n\(contextText)",
                corrections: categoryCorrections
            )
        }

        return ImportedReceipt(
            source: receipt.source,
            merchant: resolvedMerchant,
            amount: receipt.amount,
            occurredAt: receipt.occurredAt,
            rawText: receipt.rawText,
            summary: receipt.summary,
            confidence: receipt.confidence,
            suggestedCategory: category,
            parseDiagnostics: receipt.parseDiagnostics
        )
    }

    public static func applyingAlias(
        to transaction: Transaction,
        aliases: [String: String]
    ) -> Transaction {
        let resolvedMerchant = resolvedMerchant(for: transaction.merchant, aliases: aliases)
        guard resolvedMerchant != transaction.merchant else { return transaction }

        return Transaction(
            id: transaction.id,
            merchant: resolvedMerchant,
            amount: transaction.amount,
            occurredAt: transaction.occurredAt,
            categoryLabel: transaction.category,
            sourceLabel: transaction.source,
            note: transaction.note,
            ledgerID: transaction.ledgerID,
            hotelStayRecordID: transaction.hotelStayRecordID
        )
    }
}
