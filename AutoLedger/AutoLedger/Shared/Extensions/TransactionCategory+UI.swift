import SwiftUI
import AutoLedgerCore

extension TransactionCategory {
    var tint: Color {
        switch self {
        case .groceries:     return Color(red: 0.19, green: 0.51, blue: 0.34)
        case .dining:        return Color(red: 0.80, green: 0.35, blue: 0.18)
        case .transport:     return Color(red: 0.08, green: 0.39, blue: 0.64)
        case .hotel:         return Color(red: 0.20, green: 0.50, blue: 0.42)
        case .shopping:      return Color(red: 0.72, green: 0.29, blue: 0.30)
        case .digital:       return Color(red: 0.33, green: 0.35, blue: 0.78)
        case .utilities:     return Color(red: 0.68, green: 0.52, blue: 0.13)
        case .entertainment: return Color(red: 0.58, green: 0.21, blue: 0.57)
        case .other:         return Color(red: 0.39, green: 0.43, blue: 0.47)
        }
    }
}

extension MonthlySnapshot.CategoryMetric {
    var tint: Color {
        if let category {
            return category.tint
        }

        let palette: [Color] = [
            Color(red: 0.12, green: 0.45, blue: 0.56),
            Color(red: 0.56, green: 0.34, blue: 0.72),
            Color(red: 0.67, green: 0.36, blue: 0.22),
            Color(red: 0.22, green: 0.50, blue: 0.45),
            Color(red: 0.63, green: 0.25, blue: 0.39)
        ]
        let seed = id.unicodeScalars.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1.value) }
        return palette[Int(seed % UInt64(palette.count))]
    }
}
