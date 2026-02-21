//
//  SpreadPaperApp.swift
//  SpreadPaper
//
//  Created by Robin van Baalen on 21-11-2025.
//

import SwiftUI
import Combine

@main
struct SpreadPaperApp: App {
    @StateObject private var updateChecker = UpdateChecker.shared
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
                .onAppear {
                    checkForUpdatesOnStartup()
                }
                .onReceive(updateChecker.$updateInfo) { info in
                    handleUpdateInfoChange(info)
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

    private func checkForUpdatesOnStartup() {
        // Only check once per app launch
        guard !hasCheckedForUpdates else { return }
        hasCheckedForUpdates = true

        // Small delay to let the app fully initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            updateChecker.checkForUpdates()
        }
    }

    private func handleUpdateInfoChange(_ info: UpdateInfo?) {
        guard let info = info else { return }

        // Show popup only if an update is available and we haven't shown it yet
        if info.isUpdateAvailable && hasCheckedForUpdates && !showUpdatePopup {
            // Small delay to ensure changelog is fetched
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showUpdatePopup = true
                }
            }
        }
    }
}
