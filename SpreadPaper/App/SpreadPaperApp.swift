// SpreadPaper/App/SpreadPaperApp.swift

import SwiftUI

@main
struct SpreadPaperApp: App {
    @State private var manager = WallpaperManager()
    @State private var navigation = AppNavigation()
    @State private var settings = AppSettings.shared
    @State private var updateChecker = UpdateChecker.shared
    @State private var hasCheckedForUpdates = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                mainContent

                if navigation.showCreationModal {
                    CreationModal(navigation: navigation)
                }
            }
            .frame(minWidth: 900, minHeight: 600)
            .preferredColorScheme(.dark)
            .background(Color.cdBgPrimary)
            .task {
                await manager.listenForScreenChanges()
            }
            .task {
                await checkForUpdates()
            }
            .onAppear {
                // Force dark appearance on window
                if let window = NSApplication.shared.windows.first {
                    window.appearance = NSAppearance(named: .darkAqua)
                    window.backgroundColor = NSColor(Color.cdBgPrimary)
                }

                // Show wizard if first launch
                if !settings.hasCompletedWizard {
                    navigation.route = .wizard
                }
            }
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
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
                let type: WallpaperType = {
                    switch preset.wallpaperType {
                    case "Dynamic": return .dynamic
                    case "Light/Dark": return .appearance
                    default: return .standard
                    }
                }()
                EditorView(manager: manager, navigation: navigation, wallpaperType: type, presetId: presetId)
            } else {
                GalleryView(manager: manager, navigation: navigation)
            }
        case .editorNew(let type):
            EditorView(manager: manager, navigation: navigation, wallpaperType: type, presetId: nil)
        }
    }

    private func checkForUpdates() async {
        guard !hasCheckedForUpdates else { return }
        hasCheckedForUpdates = true
        try? await Task.sleep(for: .seconds(2))
        await updateChecker.checkForUpdates()
    }
}
