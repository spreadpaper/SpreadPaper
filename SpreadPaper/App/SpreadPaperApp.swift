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
    @State private var showUpdatePopup = false
    @State private var hasCheckedForUpdates = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .allowsHitTesting(!showUpdatePopup)
                .focusable(!showUpdatePopup)
                .overlay {
                    if showUpdatePopup {
                        updatePopupOverlay
                    }
                }
                .task {
                    await checkForUpdatesOnStartup()
                }
        }

        Settings {
            SettingsView()
        }
    }

    // MARK: - Update Popup Overlay

    private var updatePopupOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Allow dismissing by clicking outside
                    showUpdatePopup = false
                }

            // Popup view
            UpdatePopupView(
                updateChecker: updateChecker,
                isPresented: $showUpdatePopup
            )
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showUpdatePopup)
    }

    // MARK: - Update Check Logic

    private func checkForUpdatesOnStartup() async {
        guard !hasCheckedForUpdates else { return }
        hasCheckedForUpdates = true
        try? await Task.sleep(for: .seconds(1))
        await updateChecker.checkForUpdates()
        if let info = updateChecker.updateInfo, info.isUpdateAvailable {
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation {
                showUpdatePopup = true
            }
        }
    }
}
