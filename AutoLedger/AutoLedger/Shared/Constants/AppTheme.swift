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
            : UIColor(white: 1, alpha: 0.88)
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
            Color(red: 0.17, green: 0.47, blue: 0.34),
            Color(red: 0.74, green: 0.42, blue: 0.17)
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

    func autoLedgerFormChrome(maxWidth: CGFloat = 720) -> some View {
        modifier(AutoLedgerFormChromeModifier(maxWidth: maxWidth))
    }

    func autoLedgerNavigationBarChrome() -> some View {
        modifier(AutoLedgerNavigationBarChromeModifier())
    }

    func autoLedgerSolidNavigationBarChrome() -> some View {
        modifier(AutoLedgerSolidNavigationBarChromeModifier())
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
