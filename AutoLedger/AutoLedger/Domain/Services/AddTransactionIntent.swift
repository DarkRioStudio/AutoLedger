import AppIntents
import AutoLedgerCore
import Foundation
import OSLog
import WidgetKit

nonisolated(unsafe) private let addTxLogger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "AddTransactionIntent")

// MARK: - CategoryAppEnum

/// AppIntents 专用分类枚举包装，rawValue 与 TransactionCategory.rawValue 一一对应。
enum CategoryAppEnum: String, AppEnum {
    case groceries
    case dining
    case transport
    case shopping
    case digital
    case utilities
    case entertainment
    case other

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "分类"

    static var caseDisplayRepresentations: [CategoryAppEnum: DisplayRepresentation] = [
        .groceries:     DisplayRepresentation(title: "category.groceries.title",
                                              image: .init(systemName: "basket.fill")),
        .dining:        DisplayRepresentation(title: "category.dining.title",
                                              image: .init(systemName: "fork.knife")),
        .transport:     DisplayRepresentation(title: "category.transport.title",
                                              image: .init(systemName: "car.fill")),
        .shopping:      DisplayRepresentation(title: "category.shopping.title",
                                              image: .init(systemName: "bag.fill")),
        .digital:       DisplayRepresentation(title: "category.digital.title",
                                              image: .init(systemName: "sparkles.tv.fill")),
        .utilities:     DisplayRepresentation(title: "category.utilities.title",
                                              image: .init(systemName: "bolt.fill")),
        .entertainment: DisplayRepresentation(title: "category.entertainment.title",
                                              image: .init(systemName: "ticket.fill")),
        .other:         DisplayRepresentation(title: "category.other.title",
                                              image: .init(systemName: "square.grid.2x2.fill")),
    ]

    var coreCategory: TransactionCategory {
        TransactionCategory(rawValue: rawValue) ?? .other
    }
}

// MARK: - AddTransactionIntent

/// Shortcuts / Siri 动作：手动指定金额、分类和商户直接入账。
struct AddTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "add_transaction.intent.title"
    static var description: IntentDescription = IntentDescription("add_transaction.intent.description")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "add_transaction.amount.title",
               description: "add_transaction.amount.description",
               controlStyle: .field,
               inclusiveRange: (0.01, 9_999_999.99))
    var amount: Double

    @Parameter(title: "add_transaction.category.title",
               description: "add_transaction.category.description",
               default: .other)
    var category: CategoryAppEnum

    @Parameter(title: "add_transaction.merchant.title",
               description: "add_transaction.merchant.description")
    var merchant: String

    @Parameter(title: "add_transaction.note.title",
               description: "add_transaction.note.description")
    var note: String?

    @Parameter(title: "add_transaction.date.title",
               description: "add_transaction.date.description")
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("记录 \(\.$amount) 元 \(\.$merchant) 至 \(\.$category)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let merchantTrimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merchantTrimmed.isEmpty else {
            return .result(value: String(localized: "add_transaction.merchant_empty"))
        }
        guard amount > 0 else {
            return .result(value: String(localized: "add_transaction.amount_invalid"))
        }

        let store: SQLiteTransactionStore
        do {
            store = try SQLiteTransactionStore()
        } catch {
            addTxLogger.error("[AddTx] 数据库初始化失败：\(error.localizedDescription)")
            return .result(value: String(localized: "quick_ledger.database_failed"))
        }

        let occurredAt = date ?? Date()
        let transaction = Transaction(
            merchant: merchantTrimmed,
            amount: amount,
            occurredAt: occurredAt,
            category: category.coreCategory,
            source: .manual,
            note: note ?? ""
        )

        do {
            try store.save(transaction: transaction)
        } catch {
            addTxLogger.error("[AddTx] 保存失败：\(error.localizedDescription)")
            return .result(value: String(localized: "add_transaction.save_failed"))
        }

        WidgetCenter.shared.reloadAllTimelines()
        addTxLogger.info("[AddTx] 已记录：\(merchantTrimmed) ¥\(amount)")

        let msg = String(
            format: String(localized: "add_transaction.success_format"),
            merchantTrimmed,
            amount,
            category.coreCategory.title
        )
        return .result(value: msg)
    }
}
