import SwiftUI
import UIKit

enum AppTheme {
    // MARK: - 自适应基础色（Light / Dark 双模式）

    /// 页面主背景：浅米黄 / 暖近黑
    static let canvas = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.10, alpha: 1)
            : UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1)
    })

    /// 卡片背景：白色半透明 / 深灰
    static let card = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.20, blue: 0.19, alpha: 1)
            : UIColor(white: 1, alpha: 0.94)
    })

    static let cardStroke = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.07)
            : UIColor(red: 0.82, green: 0.79, blue: 0.70, alpha: 0.30)
    })

    static let softShadow = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0, alpha: 0.34)
            : UIColor(red: 0.30, green: 0.25, blue: 0.16, alpha: 0.10)
    })

    /// 主文字：深墨绿 / 暖白
    static let ink = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.93, green: 0.92, blue: 0.90, alpha: 1)
            : UIColor(red: 0.14, green: 0.16, blue: 0.15, alpha: 1)
    })

    /// 次要文字：暖灰绿 / 中灰
    static let mutedInk = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.60, green: 0.62, blue: 0.60, alpha: 1)
            : UIColor(red: 0.39, green: 0.43, blue: 0.41, alpha: 1)
    })

    // MARK: - 强调色（不随深色模式改变）

    static let accent = Color(red: 0.17, green: 0.47, blue: 0.34)
    static let accentSecondary = Color(red: 0.80, green: 0.47, blue: 0.16)

    // MARK: - 渐变

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.15, green: 0.44, blue: 0.32),
            Color(red: 0.72, green: 0.45, blue: 0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenGradient = LinearGradient(
        colors: [
            canvas,
            Color(uiColor: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
                    : UIColor(red: 0.92, green: 0.91, blue: 0.85, alpha: 1)
            })
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

private struct AutoLedgerSurfaceBackground: View {
    var body: some View {
        ZStack {
            AppTheme.screenGradient
            Rectangle()
                .fill(.regularMaterial)
                .opacity(0.28)
        }
        .ignoresSafeArea()
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
            .shadow(color: AppTheme.softShadow, radius: 14, x: 0, y: 8)
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
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: AppTheme.softShadow.opacity(1.25), radius: 18, x: 0, y: 10)
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
                        .animation(.easeInOut(duration: 0.16), value: showsToolbarTitle)
                }
            }
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
