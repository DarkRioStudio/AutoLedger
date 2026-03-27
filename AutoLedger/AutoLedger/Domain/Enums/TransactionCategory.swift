import SwiftUI

enum TransactionCategory: String, CaseIterable, Codable, Identifiable {
    case groceries
    case dining
    case transport
    case shopping
    case digital
    case utilities
    case entertainment
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groceries:
            return "日用杂货"
        case .dining:
            return "餐饮"
        case .transport:
            return "出行"
        case .shopping:
            return "购物"
        case .digital:
            return "数字服务"
        case .utilities:
            return "生活缴费"
        case .entertainment:
            return "娱乐"
        case .other:
            return "其他"
        }
    }

    var iconName: String {
        switch self {
        case .groceries:
            return "basket.fill"
        case .dining:
            return "fork.knife"
        case .transport:
            return "car.fill"
        case .shopping:
            return "bag.fill"
        case .digital:
            return "sparkles.tv.fill"
        case .utilities:
            return "bolt.fill"
        case .entertainment:
            return "ticket.fill"
        case .other:
            return "square.grid.2x2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .groceries:
            return Color(red: 0.19, green: 0.51, blue: 0.34)
        case .dining:
            return Color(red: 0.80, green: 0.35, blue: 0.18)
        case .transport:
            return Color(red: 0.08, green: 0.39, blue: 0.64)
        case .shopping:
            return Color(red: 0.72, green: 0.29, blue: 0.30)
        case .digital:
            return Color(red: 0.33, green: 0.35, blue: 0.78)
        case .utilities:
            return Color(red: 0.68, green: 0.52, blue: 0.13)
        case .entertainment:
            return Color(red: 0.58, green: 0.21, blue: 0.57)
        case .other:
            return Color(red: 0.39, green: 0.43, blue: 0.47)
        }
    }

    static func infer(from text: String) -> TransactionCategory {
        let lowered = text.lowercased()

        if lowered.contains("apple") || lowered.contains("spotify") || lowered.contains("会员") || lowered.contains("store") {
            return .digital
        }
        if lowered.contains("咖啡") || lowered.contains("奶茶") || lowered.contains("餐") || lowered.contains("美团") {
            return .dining
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
