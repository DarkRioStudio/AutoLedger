import Foundation

public struct CategoryResolutionResult: Sendable {
    public let category: TransactionCategory
    public let confidence: Double
    public let ruleName: String
    public let debugTrace: [String]

    public init(category: TransactionCategory, confidence: Double, ruleName: String, debugTrace: [String]) {
        self.category = category
        self.confidence = confidence
        self.ruleName = ruleName
        self.debugTrace = debugTrace
    }
}

public struct CategoryResolver: Sendable {
    private static let merchantCategoryMap: [(keywords: [String], category: TransactionCategory)] = [
        (["mr d.i.y.", "mr diy", "mr. d.i.y."], .shopping),
        (["perniagaan zheng hui", "sin nathamby", "yongfatt", "abc ho trading"], .shopping),
        (["soon huat machinery", "indah gift", "ted heng", "fy eagle"], .shopping),
        (["mynews retail", "mynews"], .shopping),
        (["pasar nine jin seng", "pasar"], .groceries),
        (["ntuc fairprice", "walmart", "supermarket", "fairprice", "tesco", "aeon", "lotus"], .groceries),
        (["7-eleven", "seven eleven", "7 eleven", "family mart", "罗森", "便利店"], .groceries),
        (["mcdonald", "gerbang alaf restaurants", "golden arches"], .dining),
        (["kfc", "burger king", "pizza hut", "starbucks", "subway"], .dining),
        (["sheraton", "marriott", "hilton", "hyatt", "hotel"], .entertainment),
        (["滴滴", "didi", "grab", "gojek", "uber"], .transport),
        (["shell", "petronas", "caltex", "esso", "汽油", "加油站"], .transport),
        (["apple services", "apple.com", "app store", "spotify", "netflix"], .digital),
        (["icloud", "google one", "chatgpt", "openai"], .digital),
    ]

    public init() {}

    public func resolve(text: String) -> TransactionCategory {
        resolveDetailed(text: text).category
    }

    public func resolveDetailed(text: String) -> CategoryResolutionResult {
        let lowered = text.lowercased()
        for (keywords, category) in Self.merchantCategoryMap {
            for keyword in keywords where lowered.contains(keyword) {
                return CategoryResolutionResult(
                    category: category,
                    confidence: 0.92,
                    ruleName: "known_merchant_keyword",
                    debugTrace: ["category_source=known_merchant_keyword", "category_keyword=\(keyword)"]
                )
            }
        }

        let inferred = TransactionCategory.infer(from: text)
        return CategoryResolutionResult(
            category: inferred,
            confidence: inferred == .other ? 0.45 : 0.70,
            ruleName: "category_keyword_infer",
            debugTrace: ["category_source=category_keyword_infer"]
        )
    }
}
