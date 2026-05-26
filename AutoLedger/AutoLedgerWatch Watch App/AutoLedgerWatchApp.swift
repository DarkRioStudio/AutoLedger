//
//  AutoLedgerWatchApp.swift
//  AutoLedgerWatch Watch App
//
//  Created by 张津铖 on 2026/5/13.
//

import SwiftUI

@main
struct AutoLedgerWatch_Watch_AppApp: App {

    var body: some Scene {
        WindowGroup {
            if WatchScreenshotModeConfig.isEnabled {
                WatchScreenshotHostView(scene: WatchScreenshotModeConfig.scene)
            } else {
                WatchAppRootView()
            }
        }
    }
}

private struct WatchAppRootView: View {
    @State private var viewModel = WatchLedgerViewModel()

    var body: some View {
        ContentView()
            .environment(viewModel)
    }
}
