import SwiftUI
import Combine

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

class AppSettings: ObservableObject {
    @AppStorage("appearanceMode") var appearanceMode: String = AppearanceMode.system.rawValue

    var selectedAppearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceMode) ?? .system }
        set { appearanceMode = newValue.rawValue }
    }

    var colorScheme: ColorScheme? {
        switch selectedAppearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
