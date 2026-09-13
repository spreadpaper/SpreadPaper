// SpreadPaper/App/SpreadPaperApp.swift

import SwiftUI

/// Entry point: one main window routed by AppNavigation, a Settings scene, and the startup tasks.
@main
struct SpreadPaperApp: App {
    @State private var manager = WallpaperManager()
    @State private var navigation = AppNavigation()
    @State private var settings = AppSettings.shared
    @State private var updateChecker = UpdateChecker.shared
    @State private var hasCheckedForUpdates = false

    /// Forces the dark appearance on every window, Settings included.
    init() {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                mainContent

                if navigation.showCreationModal {
                    CreationModal(navigation: navigation, manager: manager)
                }
            }
            .ignoresSafeArea()
            .frame(minWidth: 900, minHeight: 600)
            .background(Color.cdBgPrimary)
            .followsClockSettings()
            .task {
                await manager.listenForScreenChanges()
            }
            .task {
                await checkForUpdates()
            }
            .onAppear {
                if !settings.hasCompletedWizard {
                    navigation.route = .wizard
                }
            }
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(manager: manager)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch navigation.route {
        case .wizard:
            WizardView(navigation: navigation)
        case .gallery:
            GalleryView(manager: manager, navigation: navigation)
        case .editor(let presetId):
            if let preset = manager.presets.first(where: { $0.id == presetId }) {
                EditorView(manager: manager, navigation: navigation, wallpaperType: preset.kind, presetId: presetId)
            } else {
                GalleryView(manager: manager, navigation: navigation)
            }
        case .editorNew(let type):
            EditorView(manager: manager, navigation: navigation, wallpaperType: type, presetId: nil)
        }
    }

    /// Runs the update check once per launch, after a short delay so startup stays snappy.
    private func checkForUpdates() async {
        guard !hasCheckedForUpdates else { return }
        hasCheckedForUpdates = true
        try? await Task.sleep(for: .seconds(2))
        await updateChecker.checkForUpdates()
    }
}
