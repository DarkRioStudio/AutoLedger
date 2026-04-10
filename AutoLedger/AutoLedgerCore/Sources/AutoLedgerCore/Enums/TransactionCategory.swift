import Foundation

public enum TransactionCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case groceries
    case dining
    case transport
    case shopping
    case digital
    case utilities
    case entertainment
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .groceries:     return "日用杂货"
        case .dining:        return "餐饮"
        case .transport:     return "出行"
        case .shopping:      return "购物"
        case .digital:       return "数字服务"
        case .utilities:     return "生活缴费"
        case .entertainment: return "娱乐"
        case .other:         return "其他"
        }
    }

    public var iconName: String {
        switch self {
        case .groceries:     return "basket.fill"
        case .dining:        return "fork.knife"
        case .transport:     return "car.fill"
        case .shopping:      return "bag.fill"
        case .digital:       return "sparkles.tv.fill"
        case .utilities:     return "bolt.fill"
        case .entertainment: return "ticket.fill"
        case .other:         return "square.grid.2x2.fill"
        }
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
            || lowered.contains("米线") || lowered.contains("面") || lowered.contains("饭") {
            return .dining
        }
        if lowered.contains("apple") || lowered.contains("spotify") || lowered.contains("会员")
            || lowered.contains("app store") || lowered.contains("订阅") {
            return .digital
        }
        if lowered.contains("滴滴") || lowered.contains("地铁") || lowered.contains("出行") || lowered.contains("taxi") {
            return .transport
        }
        if lowered.contains("盒马") || lowered.contains("超市") || lowered.contains("便利店") {
            return .groceries
        }
        if lowered.contains("电费") || lowered.contains("水费") || lowered.contains("燃气") {
            return .utilities
        }
        if lowered.contains("影院") || lowered.contains("电影") || lowered.contains("游戏") {
            return .entertainment
        }
        if lowered.contains("淘宝") || lowered.contains("京东") || lowered.contains("mall") {
            return .shopping
        }

        return .other
    }
}
