import AutoLedgerCore
import Foundation

struct WatchCategoryOption: Identifiable, Hashable, Sendable {
    let rawValue: String
    let title: String
    let iconName: String

    var id: String { rawValue }

    static let builtIn: [WatchCategoryOption] = TransactionCategory.allCases.map {
        WatchCategoryOption(rawValue: $0.rawValue, title: $0.title, iconName: $0.iconName)
    }

    static func all(customCategories: [String]) -> [WatchCategoryOption] {
        let custom = customCategories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { custom in
                !TransactionCategory.allCases.contains { builtIn in
                    builtIn.rawValue == custom || builtIn.title == custom
                }
            }
            .map { WatchCategoryOption(rawValue: $0, title: $0, iconName: "tag.fill") }

        return builtIn + custom
    }
}
