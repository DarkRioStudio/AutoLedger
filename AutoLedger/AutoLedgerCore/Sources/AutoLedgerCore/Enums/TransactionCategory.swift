import Foundation

public enum TransactionCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case groceries
    case dining
    case transport
    case hotel
    case shopping
    case digital
    case utilities
    case entertainment
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .groceries:     return NSLocalizedString("category.groceries.title", comment: "")
        case .dining:        return NSLocalizedString("category.dining.title", comment: "")
        case .transport:     return NSLocalizedString("category.transport.title", comment: "")
        case .hotel:         return NSLocalizedString("category.hotel.title", comment: "")
        case .shopping:      return NSLocalizedString("category.shopping.title", comment: "")
        case .digital:       return NSLocalizedString("category.digital.title", comment: "")
        case .utilities:     return NSLocalizedString("category.utilities.title", comment: "")
        case .entertainment: return NSLocalizedString("category.entertainment.title", comment: "")
        case .other:         return NSLocalizedString("category.other.title", comment: "")
        }
    }

    public var iconName: String {
        switch self {
        case .groceries:     return "basket.fill"
        case .dining:        return "fork.knife"
        case .transport:     return "car.fill"
        case .hotel:         return "building.2.fill"
        case .shopping:      return "bag.fill"
        case .digital:       return "sparkles.tv.fill"
        case .utilities:     return "bolt.fill"
        case .entertainment: return "ticket.fill"
        case .other:         return "square.grid.2x2.fill"
        }
    }

    public static func normalizedBuiltInCategory(from label: String) -> TransactionCategory? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let exact = TransactionCategory(rawValue: trimmed) {
            return exact
        }

        let lowered = trimmed.lowercased()
        let aliases: [String: TransactionCategory] = [
            "food": .dining,
            "meal": .dining,
            "restaurant": .dining,
            "餐饮": .dining,
            "餐飲": .dining,
            "吃饭": .dining,
            "吃飯": .dining,
            "交通": .transport,
            "出行": .transport,
            "transportation": .transport,
            "transit": .transport,
            "hotel": .hotel,
            "hotels": .hotel,
            "lodging": .hotel,
            "accommodation": .hotel,
            "accommodations": .hotel,
            "酒店": .hotel,
            "酒店住宿": .hotel,
            "住宿": .hotel,
            "宾馆": .hotel,
            "賓館": .hotel,
            "飯店": .hotel,
            "旅馆": .hotel,
            "旅館": .hotel,
            "ホテル": .hotel,
            "宿泊": .hotel,
            "宿泊費": .hotel,
            "shopping": .shopping,
            "购物": .shopping,
            "購物": .shopping,
            "grocery": .groceries,
            "groceries": .groceries,
            "超市": .groceries,
            "digital": .digital,
            "subscription": .digital,
            "订阅": .digital,
            "訂閱": .digital,
            "utility": .utilities,
            "utilities": .utilities,
            "水电": .utilities,
            "水電": .utilities,
            "entertainment": .entertainment,
            "娱乐": .entertainment,
            "娛樂": .entertainment
        ]

        return aliases[lowered]
    }

    public static func infer(from text: String, corrections: [String: TransactionCategory] = [:]) -> TransactionCategory {
        // 优先查询用户修正历史
        for (merchant, category) in corrections {
            if text.localizedCaseInsensitiveContains(merchant) {
                return category
            }
        }

        let lowered = text.lowercased()

        if lowered.contains("麦当劳") || lowered.contains("肯德基") || lowered.contains("星巴克")
            || lowered.contains("咖啡") || lowered.contains("奶茶") || lowered.contains("餐")
            || lowered.contains("美团") || lowered.contains("饿了么") || lowered.contains("外卖")
            || lowered.contains("火锅") || lowered.contains("烧烤") || lowered.contains("面包")
            || lowered.contains("奶") || lowered.contains("茶饮") || lowered.contains("mcdonald")
            || lowered.contains("闪购") || lowered.contains("骑士") || lowered.contains("粉")
            || lowered.contains("米线") || lowered.contains("面") || lowered.contains("饭")
            || lowered.contains("羊汤") || lowered.contains("羊肉汤") {
            return .dining
        }
        if lowered.contains("盒马") || lowered.contains("超市") || lowered.contains("便利店")
            || lowered.contains("fairprice") || lowered.contains("walmart") || lowered.contains("supermarket") {
            return .groceries
        }
        if lowered.contains("apple") || lowered.contains("spotify") || lowered.contains("会员")
            || lowered.contains("app store") || lowered.contains("订阅") {
            return .digital
        }
        if lowered.contains("滴滴") || lowered.contains("地铁") || lowered.contains("出行") || lowered.contains("taxi")
            || lowered.contains("打车") || lowered.contains("出租车") || lowered.contains("公交")
            || lowered.contains("停车") || lowered.contains("停车费") {
            return .transport
        }
        if lowered.contains("酒店") || lowered.contains("酒店住宿") || lowered.contains("宾馆")
            || lowered.contains("賓館") || lowered.contains("飯店") || lowered.contains("旅馆")
            || lowered.contains("旅館") || lowered.contains("住宿") || lowered.contains("hotel")
            || lowered.contains("lodging") || lowered.contains("accommodation")
            || lowered.contains("ホテル") || lowered.contains("宿泊") {
            return .hotel
        }
        if lowered.contains("电费") || lowered.contains("水费") || lowered.contains("燃气") {
            return .utilities
        }
        if lowered.contains("影院") || lowered.contains("电影") || lowered.contains("游戏")
            || lowered.contains("欢乐谷") || lowered.contains("游乐园") || lowered.contains("主题公园") {
            return .entertainment
        }
        if lowered.contains("淘宝") || lowered.contains("京东") || lowered.contains("拼多多")
            || lowered.contains("mall") {
            return .shopping
        }

        return .other
    }
}
