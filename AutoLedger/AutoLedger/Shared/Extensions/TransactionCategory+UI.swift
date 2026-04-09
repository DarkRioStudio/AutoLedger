import SwiftUI
import AutoLedgerCore

extension TransactionCategory {
    var tint: Color {
        switch self {
        case .groceries:     return Color(red: 0.19, green: 0.51, blue: 0.34)
        case .dining:        return Color(red: 0.80, green: 0.35, blue: 0.18)
        case .transport:     return Color(red: 0.08, green: 0.39, blue: 0.64)
        case .shopping:      return Color(red: 0.72, green: 0.29, blue: 0.30)
        case .digital:       return Color(red: 0.33, green: 0.35, blue: 0.78)
        case .utilities:     return Color(red: 0.68, green: 0.52, blue: 0.13)
        case .entertainment: return Color(red: 0.58, green: 0.21, blue: 0.57)
        case .other:         return Color(red: 0.39, green: 0.43, blue: 0.47)
        }
    }
}
