//
//  AutoLedgerWatchApp.swift
//  AutoLedgerWatch Watch App
//
//  Created by 张津铖 on 2026/5/13.
//

import SwiftUI

@main
struct AutoLedgerWatch_Watch_AppApp: App {

    @State private var viewModel = WatchLedgerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
    }
}
