import CoreGraphics
import Foundation

/// Builds the on-disk names for rendered per-display wallpaper files.
enum WallpaperFilenames {
    /// Prefix shared by every static wallpaper written for one display.
    static func staticPrefix(displayID: CGDirectDisplayID) -> String {
        "spreadpaper_wall_\(displayID)_"
    }

    /// Timestamped static wallpaper name. A fresh name per apply makes macOS reload the image.
    static func staticName(displayID: CGDirectDisplayID, timestamp: Int) -> String {
        "\(staticPrefix(displayID: displayID))\(timestamp).png"
    }

    /// Dynamic (HEIC) wallpaper name inside a preset's directory.
    static func dynamicName(displayID: CGDirectDisplayID) -> String {
        "\(displayID).heic"
    }
}
