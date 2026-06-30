import SwiftUI
import UIKit

enum AppThemePreset: String, CaseIterable, Identifiable {
    case fresh
    case classic
    case graphite

    static let userDefaultsKey = "appThemePreset"

    var id: String { rawValue }

    var localizedTitleKey: LocalizedStringKey {
        switch self {
        case .fresh:
            return "appearance.theme.fresh"
        case .classic:
            return "appearance.theme.classic"
        case .graphite:
            return "appearance.theme.graphite"
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
        }
    }

    static var current: AppThemePreset {
        let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey)
        return rawValue.flatMap(AppThemePreset.init(rawValue:)) ?? .fresh
    }

    fileprivate var palette: AppThemePalette {
        switch self {
        case .fresh:
            return AppThemePalette(
                canvasLight: UIColor(red: 0.945, green: 0.965, blue: 0.955, alpha: 1),
                canvasDark: UIColor(red: 0.055, green: 0.075, blue: 0.068, alpha: 1),
                cardLight: UIColor(white: 1, alpha: 0.92),
                cardDark: UIColor(red: 0.125, green: 0.145, blue: 0.135, alpha: 0.96),
                cardStrokeLight: UIColor(red: 0.55, green: 0.64, blue: 0.60, alpha: 0.26),
                cardStrokeDark: UIColor(white: 1, alpha: 0.10),
                shadowLight: UIColor(red: 0.07, green: 0.18, blue: 0.15, alpha: 0.12),
                shadowDark: UIColor(white: 0, alpha: 0.42),
                inkLight: UIColor(red: 0.105, green: 0.150, blue: 0.135, alpha: 1),
                inkDark: UIColor(red: 0.925, green: 0.950, blue: 0.935, alpha: 1),
                mutedInkLight: UIColor(red: 0.375, green: 0.455, blue: 0.430, alpha: 1),
                mutedInkDark: UIColor(red: 0.630, green: 0.690, blue: 0.665, alpha: 1),
                accent: Color(red: 0.055, green: 0.435, blue: 0.345),
                accentSecondary: Color(red: 0.125, green: 0.385, blue: 0.700),
                heroColors: [
                    Color(red: 0.045, green: 0.380, blue: 0.320),
                    Color(red: 0.110, green: 0.405, blue: 0.705),
                    Color(red: 0.770, green: 0.515, blue: 0.245)
                ],
                screenLight: [
                    UIColor(red: 0.960, green: 0.980, blue: 0.970, alpha: 1),
                    UIColor(red: 0.920, green: 0.955, blue: 0.965, alpha: 1),
                    UIColor(red: 0.945, green: 0.955, blue: 0.930, alpha: 1)
                ],
                screenDark: [
                    UIColor(red: 0.045, green: 0.060, blue: 0.058, alpha: 1),
                    UIColor(red: 0.070, green: 0.080, blue: 0.085, alpha: 1),
                    UIColor(red: 0.055, green: 0.065, blue: 0.060, alpha: 1)
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
                canvasLight: UIColor(red: 0.930, green: 0.940, blue: 0.945, alpha: 1),
                canvasDark: UIColor(red: 0.050, green: 0.055, blue: 0.065, alpha: 1),
                cardLight: UIColor(white: 1, alpha: 0.93),
                cardDark: UIColor(red: 0.105, green: 0.115, blue: 0.130, alpha: 0.97),
                cardStrokeLight: UIColor(red: 0.520, green: 0.555, blue: 0.590, alpha: 0.25),
                cardStrokeDark: UIColor(white: 1, alpha: 0.10),
                shadowLight: UIColor(red: 0.060, green: 0.075, blue: 0.095, alpha: 0.13),
                shadowDark: UIColor(white: 0, alpha: 0.45),
                inkLight: UIColor(red: 0.105, green: 0.120, blue: 0.145, alpha: 1),
                inkDark: UIColor(red: 0.925, green: 0.935, blue: 0.950, alpha: 1),
                mutedInkLight: UIColor(red: 0.385, green: 0.420, blue: 0.465, alpha: 1),
                mutedInkDark: UIColor(red: 0.620, green: 0.655, blue: 0.705, alpha: 1),
                accent: Color(red: 0.165, green: 0.360, blue: 0.690),
                accentSecondary: Color(red: 0.080, green: 0.485, blue: 0.405),
                heroColors: [
                    Color(red: 0.070, green: 0.130, blue: 0.220),
                    Color(red: 0.175, green: 0.380, blue: 0.700),
                    Color(red: 0.080, green: 0.485, blue: 0.405)
                ],
                screenLight: [
                    UIColor(red: 0.965, green: 0.970, blue: 0.975, alpha: 1),
                    UIColor(red: 0.925, green: 0.940, blue: 0.955, alpha: 1),
                    UIColor(red: 0.940, green: 0.950, blue: 0.945, alpha: 1)
                ],
                screenDark: [
                    UIColor(red: 0.040, green: 0.045, blue: 0.055, alpha: 1),
                    UIColor(red: 0.070, green: 0.080, blue: 0.095, alpha: 1),
                    UIColor(red: 0.050, green: 0.065, blue: 0.070, alpha: 1)
                ]
            )
        }
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

private struct AutoLedgerSurfaceBackground: View {
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
        .autoLedgerMotion(AppMotion.theme, value: AppThemePreset.current.rawValue)
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
    func body(content: Content) -> some View {
        content
            .background {
                AutoLedgerSurfaceBackground()
            }
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
        .autoLedgerMotion(AppMotion.quick, value: isSelected)
    }
}

private struct AutoLedgerCardSurfaceModifier: ViewModifier {
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
    }
}

private struct AutoLedgerHeroSurfaceModifier: ViewModifier {
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
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct AutoLedgerSolidNavigationBarChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(AppTheme.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct AutoLedgerContentTitleNavigationModifier: ViewModifier {
    let title: LocalizedStringKey
    let toolbarRevealOffset: CGFloat
    @State private var showsToolbarTitle = false

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: AutoLedgerTitleScrollCoordinateSpace.name)
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

    func autoLedgerContentTitleNavigation(_ title: LocalizedStringKey, toolbarRevealOffset: CGFloat = -12) -> some View {
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
