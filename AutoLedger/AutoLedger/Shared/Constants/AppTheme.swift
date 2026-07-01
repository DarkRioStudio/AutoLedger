import SwiftUI
import UIKit

enum AppThemePreset: String, CaseIterable, Identifiable {
    case fresh
    case classic
    case graphite
    case ledgerInk
    case nightFolio
    case harbor
    case sunrise
    case custom

    static let userDefaultsKey = "appThemePreset"
    static let selectableCases: [AppThemePreset] = [.fresh, .classic, .graphite, .ledgerInk, .harbor, .custom]

    var id: String { rawValue }

    var isCustom: Bool {
        self == .custom
    }

    var localizedTitleKey: LocalizedStringKey {
        switch self {
        case .fresh:
            return "appearance.theme.fresh"
        case .classic:
            return "appearance.theme.classic"
        case .graphite:
            return "appearance.theme.graphite"
        case .ledgerInk:
            return "appearance.theme.ledger_ink"
        case .nightFolio:
            return "appearance.theme.night_folio"
        case .harbor:
            return "appearance.theme.harbor"
        case .sunrise:
            return "appearance.theme.sunrise"
        case .custom:
            return "appearance.theme.custom"
        }
    }

    var localizedSubtitleKey: LocalizedStringKey {
        switch self {
        case .fresh:
            return "appearance.theme.fresh.subtitle"
        case .classic:
            return "appearance.theme.classic.subtitle"
        case .graphite:
            return "appearance.theme.graphite.subtitle"
        case .ledgerInk:
            return "appearance.theme.ledger_ink.subtitle"
        case .nightFolio:
            return "appearance.theme.night_folio.subtitle"
        case .harbor:
            return "appearance.theme.harbor.subtitle"
        case .sunrise:
            return "appearance.theme.sunrise.subtitle"
        case .custom:
            return "appearance.theme.custom.subtitle"
        }
    }

    var previewColors: [Color] {
        [
            previewCanvas,
            previewCard,
            previewAccent,
            previewAccentSecondary
        ]
    }

    var previewCanvas: Color {
        Color(uiColor: palette.canvasLight)
    }

    var previewCard: Color {
        Color(uiColor: palette.cardLight)
    }

    var previewCardStroke: Color {
        Color(uiColor: palette.cardStrokeLight)
    }

    var previewInk: Color {
        Color(uiColor: palette.inkLight)
    }

    var previewMutedInk: Color {
        Color(uiColor: palette.mutedInkLight)
    }

    var previewAccent: Color {
        palette.accent
    }

    var previewAccentSecondary: Color {
        palette.accentSecondary
    }

    var previewHeroGradient: LinearGradient {
        LinearGradient(
            colors: palette.heroColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func resolvedPreviewColors(customSurfaceHex: String,
                               customAccentHex: String,
                               customSecondaryHex: String) -> [Color] {
        let palette = resolvedPreviewPalette(
            customSurfaceHex: customSurfaceHex,
            customAccentHex: customAccentHex,
            customSecondaryHex: customSecondaryHex
        )
        return [
            Color(uiColor: palette.canvasLight),
            Color(uiColor: palette.cardLight),
            palette.accent,
            palette.accentSecondary
        ]
    }

    func resolvedPreviewStyle(customSurfaceHex: String,
                              customAccentHex: String,
                              customSecondaryHex: String) -> AppThemePreviewStyle {
        let palette = resolvedPreviewPalette(
            customSurfaceHex: customSurfaceHex,
            customAccentHex: customAccentHex,
            customSecondaryHex: customSecondaryHex
        )
        return AppThemePreviewStyle(
            canvas: Color(uiColor: palette.canvasLight),
            card: Color(uiColor: palette.cardLight),
            cardStroke: Color(uiColor: palette.cardStrokeLight),
            ink: Color(uiColor: palette.inkLight),
            mutedInk: Color(uiColor: palette.mutedInkLight),
            accent: palette.accent
        )
    }

    private func resolvedPreviewPalette(customSurfaceHex: String,
                                        customAccentHex: String,
                                        customSecondaryHex: String) -> AppThemePalette {
        guard isCustom else { return palette }
        return AppThemeCustomTheme.palette(
            surfaceHex: customSurfaceHex,
            accentHex: customAccentHex,
            secondaryHex: customSecondaryHex
        )
    }

    static var current: AppThemePreset {
        let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey)
        let preset = rawValue.flatMap(AppThemePreset.init(rawValue:)) ?? .fresh
        return selectableCases.contains(preset) ? preset : .fresh
    }

    private static func uiColor(_ hex: String, alpha: CGFloat = 1) -> UIColor {
        (UIColor(hexRGB: hex) ?? .systemTeal).withAlphaComponent(alpha)
    }

    private static func color(_ hex: String) -> Color {
        Color(uiColor: uiColor(hex))
    }

    fileprivate var palette: AppThemePalette {
        switch self {
        case .fresh:
            return AppThemePalette(
                canvasLight: Self.uiColor("F6FAF7"),
                canvasDark: Self.uiColor("0E1714"),
                cardLight: Self.uiColor("FFFFFF", alpha: 0.94),
                cardDark: Self.uiColor("13211C", alpha: 0.97),
                cardStrokeLight: Self.uiColor("D7E8DF", alpha: 0.88),
                cardStrokeDark: Self.uiColor("294038", alpha: 0.88),
                shadowLight: Self.uiColor("133427", alpha: 0.13),
                shadowDark: Self.uiColor("000000", alpha: 0.40),
                inkLight: Self.uiColor("14231D"),
                inkDark: Self.uiColor("EDF7F2"),
                mutedInkLight: Self.uiColor("62746D"),
                mutedInkDark: Self.uiColor("9DAEA7"),
                accent: Self.color("1F7D56"),
                accentSecondary: Self.color("3D7891"),
                heroColors: [
                    Self.color("1F7D56"),
                    Self.color("3D7891"),
                    Self.color("317B68")
                ],
                screenLight: [
                    Self.uiColor("F2F8F5"),
                    Self.uiColor("F6FAF7"),
                    Self.uiColor("EAF5EF")
                ],
                screenDark: [
                    Self.uiColor("0B1713"),
                    Self.uiColor("0E1714"),
                    Self.uiColor("10201A")
                ]
            )
        case .classic:
            return AppThemePalette(
                canvasLight: UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1),
                canvasDark: UIColor(red: 0.11, green: 0.11, blue: 0.10, alpha: 1),
                cardLight: UIColor(white: 1, alpha: 0.94),
                cardDark: UIColor(red: 0.20, green: 0.20, blue: 0.19, alpha: 1),
                cardStrokeLight: UIColor(red: 0.82, green: 0.79, blue: 0.70, alpha: 0.30),
                cardStrokeDark: UIColor(white: 1, alpha: 0.07),
                shadowLight: UIColor(red: 0.30, green: 0.25, blue: 0.16, alpha: 0.10),
                shadowDark: UIColor(white: 0, alpha: 0.34),
                inkLight: UIColor(red: 0.14, green: 0.16, blue: 0.15, alpha: 1),
                inkDark: UIColor(red: 0.93, green: 0.92, blue: 0.90, alpha: 1),
                mutedInkLight: UIColor(red: 0.39, green: 0.43, blue: 0.41, alpha: 1),
                mutedInkDark: UIColor(red: 0.60, green: 0.62, blue: 0.60, alpha: 1),
                accent: Color(red: 0.17, green: 0.47, blue: 0.34),
                accentSecondary: Color(red: 0.80, green: 0.47, blue: 0.16),
                heroColors: [
                    Color(red: 0.15, green: 0.44, blue: 0.32),
                    Color(red: 0.72, green: 0.45, blue: 0.18)
                ],
                screenLight: [
                    UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1),
                    UIColor(red: 0.92, green: 0.91, blue: 0.85, alpha: 1)
                ],
                screenDark: [
                    UIColor(red: 0.11, green: 0.11, blue: 0.10, alpha: 1),
                    UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
                ]
            )
        case .graphite:
            return AppThemePalette(
                canvasLight: Self.uiColor("F3F6F8"),
                canvasDark: Self.uiColor("0E141A"),
                cardLight: Self.uiColor("FFFFFF", alpha: 0.94),
                cardDark: Self.uiColor("151B22", alpha: 0.97),
                cardStrokeLight: Self.uiColor("D6E0E8", alpha: 0.90),
                cardStrokeDark: Self.uiColor("2B3641", alpha: 0.92),
                shadowLight: Self.uiColor("13202B", alpha: 0.14),
                shadowDark: Self.uiColor("000000", alpha: 0.42),
                inkLight: Self.uiColor("14202A"),
                inkDark: Self.uiColor("EDF4FA"),
                mutedInkLight: Self.uiColor("667683"),
                mutedInkDark: Self.uiColor("9EADB9"),
                accent: Self.color("2F7A8A"),
                accentSecondary: Self.color("406C92"),
                heroColors: [
                    Self.color("244C5A"),
                    Self.color("406C92"),
                    Self.color("2F7A8A")
                ],
                screenLight: [
                    Self.uiColor("EEF3F7"),
                    Self.uiColor("F3F6F8"),
                    Self.uiColor("E7EEF4")
                ],
                screenDark: [
                    Self.uiColor("0C1117"),
                    Self.uiColor("0E141A"),
                    Self.uiColor("121A22")
                ]
            )
        case .ledgerInk:
            return AppThemePalette(
                canvasLight: Self.uiColor("F5F8F7"),
                canvasDark: Self.uiColor("0D1516"),
                cardLight: Self.uiColor("FFFFFF", alpha: 0.94),
                cardDark: Self.uiColor("121F20", alpha: 0.97),
                cardStrokeLight: Self.uiColor("D7E5E4", alpha: 0.90),
                cardStrokeDark: Self.uiColor("283C3E", alpha: 0.90),
                shadowLight: Self.uiColor("0D292B", alpha: 0.13),
                shadowDark: Self.uiColor("000000", alpha: 0.40),
                inkLight: Self.uiColor("112426"),
                inkDark: Self.uiColor("ECF6F6"),
                mutedInkLight: Self.uiColor("5F7475"),
                mutedInkDark: Self.uiColor("9AAFAF"),
                accent: Self.color("11766E"),
                accentSecondary: Self.color("4B697A"),
                heroColors: [
                    Self.color("11766E"),
                    Self.color("4B697A"),
                    Self.color("2D746F")
                ],
                screenLight: [
                    Self.uiColor("F4F8F8"),
                    Self.uiColor("F5F8F7"),
                    Self.uiColor("EAF3F2")
                ],
                screenDark: [
                    Self.uiColor("0B1516"),
                    Self.uiColor("0D1516"),
                    Self.uiColor("121F20")
                ]
            )
        case .nightFolio:
            return AppThemePalette(
                canvasLight: Self.uiColor("F6F7FA"),
                canvasDark: Self.uiColor("0B1020"),
                cardLight: Self.uiColor("FFFFFF", alpha: 0.94),
                cardDark: Self.uiColor("121A2B", alpha: 0.97),
                cardStrokeLight: Self.uiColor("DAE1EA", alpha: 0.90),
                cardStrokeDark: Self.uiColor("293449", alpha: 0.92),
                shadowLight: Self.uiColor("0C1A2E", alpha: 0.14),
                shadowDark: Self.uiColor("000000", alpha: 0.44),
                inkLight: Self.uiColor("111E2E"),
                inkDark: Self.uiColor("EEF3FA"),
                mutedInkLight: Self.uiColor("617085"),
                mutedInkDark: Self.uiColor("A0ABBA"),
                accent: Self.color("2C6FAE"),
                accentSecondary: Self.color("A06D2A"),
                heroColors: [
                    Self.color("0B1020"),
                    Self.color("2C6FAE"),
                    Self.color("A06D2A")
                ],
                screenLight: [
                    Self.uiColor("F5F7FA"),
                    Self.uiColor("F6F7FA"),
                    Self.uiColor("EAEFF6")
                ],
                screenDark: [
                    Self.uiColor("0B1020"),
                    Self.uiColor("11172A"),
                    Self.uiColor("151D30")
                ]
            )
        case .harbor:
            return AppThemePalette(
                canvasLight: UIColor(red: 0.925, green: 0.960, blue: 0.965, alpha: 1),
                canvasDark: UIColor(red: 0.025, green: 0.070, blue: 0.090, alpha: 1),
                cardLight: UIColor(red: 0.985, green: 0.995, blue: 0.995, alpha: 0.95),
                cardDark: UIColor(red: 0.055, green: 0.115, blue: 0.135, alpha: 0.98),
                cardStrokeLight: UIColor(red: 0.355, green: 0.600, blue: 0.650, alpha: 0.26),
                cardStrokeDark: UIColor(red: 0.620, green: 0.850, blue: 0.880, alpha: 0.13),
                shadowLight: UIColor(red: 0.025, green: 0.145, blue: 0.170, alpha: 0.13),
                shadowDark: UIColor(white: 0, alpha: 0.50),
                inkLight: UIColor(red: 0.060, green: 0.140, blue: 0.160, alpha: 1),
                inkDark: UIColor(red: 0.890, green: 0.955, blue: 0.960, alpha: 1),
                mutedInkLight: UIColor(red: 0.330, green: 0.475, blue: 0.500, alpha: 1),
                mutedInkDark: UIColor(red: 0.570, green: 0.735, blue: 0.755, alpha: 1),
                accent: Color(red: 0.000, green: 0.520, blue: 0.570),
                accentSecondary: Color(red: 0.070, green: 0.345, blue: 0.700),
                heroColors: [
                    Color(red: 0.000, green: 0.315, blue: 0.360),
                    Color(red: 0.050, green: 0.345, blue: 0.700),
                    Color(red: 0.000, green: 0.620, blue: 0.600)
                ],
                screenLight: [
                    UIColor(red: 0.950, green: 0.985, blue: 0.985, alpha: 1),
                    UIColor(red: 0.910, green: 0.955, blue: 0.965, alpha: 1),
                    UIColor(red: 0.935, green: 0.960, blue: 0.950, alpha: 1)
                ],
                screenDark: [
                    UIColor(red: 0.020, green: 0.055, blue: 0.070, alpha: 1),
                    UIColor(red: 0.030, green: 0.085, blue: 0.105, alpha: 1),
                    UIColor(red: 0.025, green: 0.070, blue: 0.090, alpha: 1)
                ]
            )
        case .sunrise:
            return AppThemePalette(
                canvasLight: UIColor(red: 0.990, green: 0.955, blue: 0.910, alpha: 1),
                canvasDark: UIColor(red: 0.105, green: 0.060, blue: 0.075, alpha: 1),
                cardLight: UIColor(red: 1.000, green: 0.990, blue: 0.970, alpha: 0.95),
                cardDark: UIColor(red: 0.170, green: 0.095, blue: 0.110, alpha: 0.98),
                cardStrokeLight: UIColor(red: 0.880, green: 0.560, blue: 0.330, alpha: 0.28),
                cardStrokeDark: UIColor(red: 0.980, green: 0.640, blue: 0.420, alpha: 0.14),
                shadowLight: UIColor(red: 0.420, green: 0.165, blue: 0.070, alpha: 0.12),
                shadowDark: UIColor(white: 0, alpha: 0.48),
                inkLight: UIColor(red: 0.210, green: 0.105, blue: 0.085, alpha: 1),
                inkDark: UIColor(red: 0.970, green: 0.910, blue: 0.865, alpha: 1),
                mutedInkLight: UIColor(red: 0.520, green: 0.360, blue: 0.295, alpha: 1),
                mutedInkDark: UIColor(red: 0.780, green: 0.620, blue: 0.560, alpha: 1),
                accent: Color(red: 0.820, green: 0.360, blue: 0.180),
                accentSecondary: Color(red: 0.520, green: 0.235, blue: 0.540),
                heroColors: [
                    Color(red: 0.760, green: 0.300, blue: 0.170),
                    Color(red: 0.520, green: 0.235, blue: 0.540),
                    Color(red: 0.950, green: 0.660, blue: 0.260)
                ],
                screenLight: [
                    UIColor(red: 1.000, green: 0.965, blue: 0.925, alpha: 1),
                    UIColor(red: 0.985, green: 0.930, blue: 0.890, alpha: 1),
                    UIColor(red: 0.975, green: 0.945, blue: 0.955, alpha: 1)
                ],
                screenDark: [
                    UIColor(red: 0.085, green: 0.045, blue: 0.060, alpha: 1),
                    UIColor(red: 0.125, green: 0.065, blue: 0.090, alpha: 1),
                    UIColor(red: 0.095, green: 0.055, blue: 0.080, alpha: 1)
                ]
            )
        case .custom:
            return AppThemeCustomTheme.palette
        }
    }
}

struct AppThemePreviewStyle {
    let canvas: Color
    let card: Color
    let cardStroke: Color
    let ink: Color
    let mutedInk: Color
    let accent: Color
}

enum AppThemeCustomTheme {
    static let surfaceHexKey = "appCustomThemeSurfaceHex"
    static let accentHexKey = "appCustomThemeAccentHex"
    static let secondaryHexKey = "appCustomThemeSecondaryHex"

    static let defaultSurfaceHex = "EAF4F0"
    static let defaultAccentHex = "0E6F59"
    static let defaultSecondaryHex = "2F63B7"

    static func color(hex: String, fallback: String) -> Color {
        Color(uiColor: uiColor(hex: hex, fallback: fallback))
    }

    static func uiColor(hex: String, fallback: String) -> UIColor {
        UIColor(hexRGB: normalizedHex(hex, fallback: fallback)) ?? UIColor(hexRGB: fallback) ?? .systemTeal
    }

    static func hexString(from color: Color, fallback: String) -> String {
        UIColor(color)
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            .hexRGBString ?? fallback
    }

    static func normalizedHex(_ rawValue: String, fallback: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard hex.count == 6, Int(hex, radix: 16) != nil else { return fallback }
        return hex.uppercased()
    }
}

enum AppColorSchemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let userDefaultsKey = "appColorSchemePreference"

    var id: String { rawValue }

    var localizedTitleKey: LocalizedStringKey {
        switch self {
        case .system:
            return "appearance.mode.system"
        case .light:
            return "appearance.mode.light"
        case .dark:
            return "appearance.mode.dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    static var current: AppColorSchemePreference {
        let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey)
        return rawValue.flatMap(AppColorSchemePreference.init(rawValue:)) ?? .system
    }
}

enum AppMotion {
    static let quick = Animation.easeInOut(duration: 0.16)
    static let standard = Animation.easeInOut(duration: 0.22)
    static let theme = Animation.easeInOut(duration: 0.26)
    static let emphasis = Animation.spring(response: 0.34, dampingFraction: 0.86)

    static func run(reduceMotion: Bool, animation: Animation = AppMotion.standard, _ updates: () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(animation, updates)
        }
    }
}

private struct AppThemePalette {
    let canvasLight: UIColor
    let canvasDark: UIColor
    let cardLight: UIColor
    let cardDark: UIColor
    let cardStrokeLight: UIColor
    let cardStrokeDark: UIColor
    let shadowLight: UIColor
    let shadowDark: UIColor
    let inkLight: UIColor
    let inkDark: UIColor
    let mutedInkLight: UIColor
    let mutedInkDark: UIColor
    let accent: Color
    let accentSecondary: Color
    let heroColors: [Color]
    let screenLight: [UIColor]
    let screenDark: [UIColor]
}

fileprivate extension AppThemeCustomTheme {
    static var palette: AppThemePalette {
        palette(
            surfaceHex: UserDefaults.standard.string(forKey: surfaceHexKey) ?? defaultSurfaceHex,
            accentHex: UserDefaults.standard.string(forKey: accentHexKey) ?? defaultAccentHex,
            secondaryHex: UserDefaults.standard.string(forKey: secondaryHexKey) ?? defaultSecondaryHex
        )
    }

    static func palette(surfaceHex: String, accentHex: String, secondaryHex: String) -> AppThemePalette {
        let surface = uiColor(hex: surfaceHex, fallback: defaultSurfaceHex)
        let accentUIColor = uiColor(hex: accentHex, fallback: defaultAccentHex)
        let secondaryUIColor = uiColor(hex: secondaryHex, fallback: defaultSecondaryHex)

        return AppThemePalette(
            canvasLight: surface.blended(towards: .white, amount: 0.78),
            canvasDark: surface.blended(towards: .black, amount: 0.88),
            cardLight: surface.blended(towards: .white, amount: 0.92).withAlphaComponent(0.96),
            cardDark: surface.blended(towards: .black, amount: 0.76).withAlphaComponent(0.98),
            cardStrokeLight: accentUIColor.blended(towards: surface, amount: 0.42).withAlphaComponent(0.28),
            cardStrokeDark: secondaryUIColor.blended(towards: .white, amount: 0.25).withAlphaComponent(0.16),
            shadowLight: accentUIColor.blended(towards: .black, amount: 0.50).withAlphaComponent(0.13),
            shadowDark: UIColor(white: 0, alpha: 0.50),
            inkLight: surface.blended(towards: .black, amount: 0.78),
            inkDark: surface.blended(towards: .white, amount: 0.84),
            mutedInkLight: surface.blended(towards: .black, amount: 0.52),
            mutedInkDark: surface.blended(towards: .white, amount: 0.58),
            accent: Color(uiColor: accentUIColor),
            accentSecondary: Color(uiColor: secondaryUIColor),
            heroColors: [
                Color(uiColor: accentUIColor.blended(towards: .black, amount: 0.20)),
                Color(uiColor: secondaryUIColor),
                Color(uiColor: surface.blended(towards: accentUIColor, amount: 0.55))
            ],
            screenLight: [
                surface.blended(towards: .white, amount: 0.86),
                surface.blended(towards: .white, amount: 0.70),
                secondaryUIColor.blended(towards: .white, amount: 0.88)
            ],
            screenDark: [
                surface.blended(towards: .black, amount: 0.92),
                accentUIColor.blended(towards: .black, amount: 0.84),
                secondaryUIColor.blended(towards: .black, amount: 0.86)
            ]
        )
    }
}

fileprivate extension UIColor {
    convenience init?(hexRGB: String) {
        let normalized = hexRGB.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard normalized.count == 6, let value = Int(normalized, radix: 16) else {
            return nil
        }

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }

    func blended(towards target: UIColor, amount: CGFloat) -> UIColor {
        let clampedAmount = min(max(amount, 0), 1)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var targetRed: CGFloat = 0
        var targetGreen: CGFloat = 0
        var targetBlue: CGFloat = 0
        var targetAlpha: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        target.getRed(&targetRed, green: &targetGreen, blue: &targetBlue, alpha: &targetAlpha)

        return UIColor(
            red: red + (targetRed - red) * clampedAmount,
            green: green + (targetGreen - green) * clampedAmount,
            blue: blue + (targetBlue - blue) * clampedAmount,
            alpha: alpha + (targetAlpha - alpha) * clampedAmount
        )
    }

    var hexRGBString: String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }

        return String(
            format: "%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
}

enum AppTheme {
    private static var palette: AppThemePalette {
        AppThemePreset.current.palette
    }

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark ? dark : light
        })
    }

    // MARK: - 自适应基础色（Light / Dark 双模式）

    static var canvas: Color {
        adaptiveColor(light: palette.canvasLight, dark: palette.canvasDark)
    }

    static var card: Color {
        adaptiveColor(light: palette.cardLight, dark: palette.cardDark)
    }

    static var cardStroke: Color {
        adaptiveColor(light: palette.cardStrokeLight, dark: palette.cardStrokeDark)
    }

    static var softShadow: Color {
        adaptiveColor(light: palette.shadowLight, dark: palette.shadowDark)
    }

    static var ink: Color {
        adaptiveColor(light: palette.inkLight, dark: palette.inkDark)
    }

    static var mutedInk: Color {
        adaptiveColor(light: palette.mutedInkLight, dark: palette.mutedInkDark)
    }

    // MARK: - 强调色（不随深色模式改变）

    static var accent: Color { palette.accent }
    static var accentSecondary: Color { palette.accentSecondary }

    // MARK: - 渐变

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: palette.heroColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var screenGradient: LinearGradient {
        LinearGradient(
            colors: zip(palette.screenLight, palette.screenDark).map { light, dark in
                adaptiveColor(light: light, dark: dark)
            },
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct AutoLedgerThemeRefreshIDKey: EnvironmentKey {
    static let defaultValue = AppThemePreset.current.rawValue
}

extension EnvironmentValues {
    var autoLedgerThemeRefreshID: String {
        get { self[AutoLedgerThemeRefreshIDKey.self] }
        set { self[AutoLedgerThemeRefreshIDKey.self] = newValue }
    }
}

private struct AutoLedgerSurfaceBackground: View {
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID

    var body: some View {
        ZStack {
            AppTheme.screenGradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.accent.opacity(0.10),
                            AppTheme.accentSecondary.opacity(0.07),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Rectangle()
                .fill(.thinMaterial)
                .opacity(0.18)
        }
        .ignoresSafeArea()
        .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
    }
}

private enum AutoLedgerTitleScrollCoordinateSpace {
    static let name = "AutoLedgerTitleScrollCoordinateSpace"
}

private struct AutoLedgerPageTitleOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

struct AutoLedgerPageTitle: View {
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(AppTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: AutoLedgerPageTitleOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named(AutoLedgerTitleScrollCoordinateSpace.name)).minY
                    )
                }
            }
    }
}

private struct AutoLedgerReadableContentModifier: ViewModifier {
    let maxWidth: CGFloat
    let alignment: Alignment

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

private struct AutoLedgerScreenChromeModifier: ViewModifier {
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID

    func body(content: Content) -> some View {
        content
            .background {
                AutoLedgerSurfaceBackground()
            }
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
    }
}

private struct AutoLedgerListChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .modifier(AutoLedgerScreenChromeModifier())
    }
}

private struct AutoLedgerSelectableRowBackground: View {
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? AppTheme.accent.opacity(0.20) : AppTheme.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? AppTheme.accent.opacity(0.60) : AppTheme.cardStroke, lineWidth: 1)
                }

            if isSelected {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(AppTheme.accent)
                    .frame(width: 4)
                    .padding(.vertical, 8)
                    .padding(.leading, 1)
            }
        }
        .padding(.vertical, 2)
        .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
        .autoLedgerMotion(AppMotion.quick, value: isSelected)
    }
}

private struct AutoLedgerCardSurfaceModifier: ViewModifier {
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
                    .blendMode(.plusLighter)
            }
            .shadow(color: AppTheme.softShadow, radius: 18, x: 0, y: 10)
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
    }
}

private struct AutoLedgerHeroSurfaceModifier: ViewModifier {
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.heroGradient)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: AppTheme.softShadow.opacity(1.35), radius: 22, x: 0, y: 12)
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
    }
}

private struct AutoLedgerFormChromeModifier: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .modifier(AutoLedgerReadableContentModifier(maxWidth: maxWidth, alignment: .center))
            .modifier(AutoLedgerScreenChromeModifier())
            .modifier(AutoLedgerNavigationBarChromeModifier())
    }
}

private struct AutoLedgerNavigationBarChromeModifier: ViewModifier {
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID

    func body(content: Content) -> some View {
        content
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
    }
}

private struct AutoLedgerSolidNavigationBarChromeModifier: ViewModifier {
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID

    func body(content: Content) -> some View {
        content
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
    }
}

private struct AutoLedgerContentTitleNavigationModifier: ViewModifier {
    @Environment(\.autoLedgerThemeRefreshID) private var themeRefreshID
    let title: LocalizedStringKey
    let toolbarRevealOffset: CGFloat
    @State private var showsToolbarTitle = false

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: AutoLedgerTitleScrollCoordinateSpace.name)
            .autoLedgerMotion(AppMotion.theme, value: themeRefreshID)
            .onPreferenceChange(AutoLedgerPageTitleOffsetPreferenceKey.self) { minY in
                guard minY.isFinite else { return }
                showsToolbarTitle = minY < toolbarRevealOffset
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .opacity(showsToolbarTitle ? 1 : 0)
                        .accessibilityHidden(!showsToolbarTitle)
                        .autoLedgerMotion(AppMotion.quick, value: showsToolbarTitle)
                }
            }
    }
}

private struct AutoLedgerMotionValueModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    func autoLedgerReadableContent(maxWidth: CGFloat = 760, alignment: Alignment = .center) -> some View {
        modifier(AutoLedgerReadableContentModifier(maxWidth: maxWidth, alignment: alignment))
    }

    func autoLedgerScreenChrome() -> some View {
        modifier(AutoLedgerScreenChromeModifier())
    }

    func autoLedgerListChrome() -> some View {
        modifier(AutoLedgerListChromeModifier())
    }

    func autoLedgerSelectableRowBackground(_ isSelected: Bool) -> some View {
        listRowBackground(AutoLedgerSelectableRowBackground(isSelected: isSelected))
    }

    func autoLedgerCardSurface(cornerRadius: CGFloat = 22) -> some View {
        modifier(AutoLedgerCardSurfaceModifier(cornerRadius: cornerRadius))
    }

    func autoLedgerHeroSurface(cornerRadius: CGFloat = 28) -> some View {
        modifier(AutoLedgerHeroSurfaceModifier(cornerRadius: cornerRadius))
    }

    func autoLedgerFormChrome(maxWidth: CGFloat = 720) -> some View {
        modifier(AutoLedgerFormChromeModifier(maxWidth: maxWidth))
    }

    func autoLedgerNavigationBarChrome() -> some View {
        modifier(AutoLedgerNavigationBarChromeModifier())
    }

    func autoLedgerSolidNavigationBarChrome() -> some View {
        modifier(AutoLedgerSolidNavigationBarChromeModifier())
    }

    func autoLedgerContentTitleNavigation(_ title: LocalizedStringKey, toolbarRevealOffset: CGFloat = 0) -> some View {
        modifier(AutoLedgerContentTitleNavigationModifier(title: title, toolbarRevealOffset: toolbarRevealOffset))
    }

    func autoLedgerMotion<Value: Equatable>(_ animation: Animation = AppMotion.standard, value: Value) -> some View {
        modifier(AutoLedgerMotionValueModifier(animation: animation, value: value))
    }

    @ViewBuilder
    func autoLedgerAdaptiveTabBar() -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            self
                .tabViewStyle(.sidebarAdaptable)
                .defaultTabBarPlacement(.sidebar)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
