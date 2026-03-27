import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.96, green: 0.94, blue: 0.89)
    static let card = Color.white.opacity(0.88)
    static let ink = Color(red: 0.14, green: 0.16, blue: 0.15)
    static let mutedInk = Color(red: 0.39, green: 0.43, blue: 0.41)
    static let accent = Color(red: 0.17, green: 0.47, blue: 0.34)
    static let accentSecondary = Color(red: 0.80, green: 0.47, blue: 0.16)

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.17, green: 0.47, blue: 0.34),
            Color(red: 0.74, green: 0.42, blue: 0.17)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenGradient = LinearGradient(
        colors: [
            canvas,
            Color(red: 0.92, green: 0.91, blue: 0.85)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
