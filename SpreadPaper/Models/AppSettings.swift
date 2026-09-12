import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

@Observable
class AppSettings {
    static let shared = AppSettings()

    var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    var hasCompletedWizard: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedWizard, forKey: "hasCompletedWizard")
        }
    }

    /// Physical gap between adjacent displays in screen points. 0 disables bezel compensation.
    var bezelGap: Double {
        didSet {
            UserDefaults.standard.set(bezelGap, forKey: "bezelGap")
        }
    }

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appearanceMode") ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: raw) ?? .system
        self.hasCompletedWizard = UserDefaults.standard.bool(forKey: "hasCompletedWizard")
        self.bezelGap = UserDefaults.standard.double(forKey: "bezelGap")
    }
}
