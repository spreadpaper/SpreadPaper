import SwiftUI

/// User preferences backed by UserDefaults; every property writes through on change.
@Observable
class AppSettings {
    static let shared = AppSettings()

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

    /// Per-display frame widths in screen points, keyed by `CGDirectDisplayID` as a string.
    /// Each entry holds `"horizontal"` and `"vertical"` edge widths.
    var bezelWidths: [String: [String: Double]] {
        didSet {
            UserDefaults.standard.set(bezelWidths, forKey: "bezelWidths")
        }
    }

    /// When false the editor shows one pair of bezel sliders that writes to every display.
    var bezelPerDisplay: Bool {
        didSet {
            UserDefaults.standard.set(bezelPerDisplay, forKey: "bezelPerDisplay")
        }
    }

    /// Frame widths of one display, falling back to half the uniform gap on every edge.
    func bezel(for displayID: CGDirectDisplayID) -> Bezel {
        let entry = bezelWidths[String(displayID)]
        let fallback = bezelGap / 2
        return Bezel(
            horizontal: CGFloat(entry?["horizontal"] ?? fallback),
            vertical: CGFloat(entry?["vertical"] ?? fallback)
        )
    }

    /// Stores one display's frame widths, clamped to 0...500 points.
    func setBezel(_ bezel: Bezel, for displayID: CGDirectDisplayID) {
        bezelWidths[String(displayID)] = [
            "horizontal": Double(max(0, min(bezel.horizontal, 500))),
            "vertical": Double(max(0, min(bezel.vertical, 500))),
        ]
    }

    /// Restores every setting from UserDefaults and drops stale keys.
    init() {
        self.hasCompletedWizard = UserDefaults.standard.bool(forKey: "hasCompletedWizard")
        self.bezelGap = UserDefaults.standard.double(forKey: "bezelGap")
        self.bezelWidths = UserDefaults.standard.dictionary(forKey: "bezelWidths") as? [String: [String: Double]] ?? [:]
        self.bezelPerDisplay = UserDefaults.standard.bool(forKey: "bezelPerDisplay")

        // Clears keys no current setting reads.
        UserDefaults.standard.removeObject(forKey: "showInMenuBar")
        UserDefaults.standard.removeObject(forKey: "launchAtLogin")
        UserDefaults.standard.removeObject(forKey: "appearanceMode")
    }
}
