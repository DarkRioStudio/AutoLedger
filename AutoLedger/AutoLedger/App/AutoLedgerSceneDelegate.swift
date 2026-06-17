import UIKit

final class AutoLedgerSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        #if targetEnvironment(macCatalyst)
        if let windowScene = scene as? UIWindowScene {
            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 1320, height: 760)
        }
        #endif

        guard let shortcutItem = connectionOptions.shortcutItem else { return }
        AutoLedgerAppDelegate.handleHomeQuickAction(shortcutItem)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(AutoLedgerAppDelegate.handleHomeQuickAction(shortcutItem))
    }
}
