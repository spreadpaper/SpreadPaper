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
    /// Displays without an entry in `bezelWidths` get half of this on each side.
    var bezelGap: Double {
        didSet {
            UserDefaults.standard.set(bezelGap, forKey: "bezelGap")
        }
    }

    /// Per-display frame width in screen points, keyed by `CGDirectDisplayID` as a string.
    var bezelWidths: [String: Double] {
        didSet {
            UserDefaults.standard.set(bezelWidths, forKey: "bezelWidths")
        }
    }

    /// Frame width of one display, falling back to half the uniform gap.
    func bezelWidth(for displayID: CGDirectDisplayID) -> Double {
        bezelWidths[String(displayID)] ?? bezelGap / 2
    }

    /// Sets a per-display width. Pass nil to fall back to the uniform gap.
    func setBezelWidth(_ width: Double?, for displayID: CGDirectDisplayID) {
        if let width {
            bezelWidths[String(displayID)] = max(0, min(width, 500))
        } else {
            bezelWidths.removeValue(forKey: String(displayID))
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
        self.bezelWidths = UserDefaults.standard.dictionary(forKey: "bezelWidths") as? [String: Double] ?? [:]
    }
}
