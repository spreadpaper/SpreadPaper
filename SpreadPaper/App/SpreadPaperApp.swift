//
//  SpreadPaperApp.swift
//  SpreadPaper
//
//  Created by Robin van Baalen on 21-11-2025.
//

import SwiftUI

@main
struct SpreadPaperApp: App {
    @State private var updateChecker = UpdateChecker.shared
    @State private var hasCheckedForUpdates = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await checkForUpdatesOnStartup()
                }
        }

        Settings {
            SettingsView()
        }
    }

    private func checkForUpdatesOnStartup() async {
        guard !hasCheckedForUpdates else { return }
        hasCheckedForUpdates = true
        try? await Task.sleep(for: .seconds(1))
        await updateChecker.checkForUpdates()
        if let info = updateChecker.updateInfo, info.isUpdateAvailable {
            try? await Task.sleep(for: .milliseconds(500))
            NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)
        }
    }
}
