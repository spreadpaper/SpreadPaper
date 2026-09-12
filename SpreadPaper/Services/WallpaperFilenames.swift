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

    /// Prefix shared by every dynamic wallpaper written for one display.
    static func dynamicPrefix(displayID: CGDirectDisplayID) -> String {
        "\(displayID)_"
    }

    /// Timestamped dynamic (HEIC) name inside a preset's directory.
    /// A fresh name per apply makes macOS reload the image.
    static func dynamicName(displayID: CGDirectDisplayID, timestamp: Int) -> String {
        "\(dynamicPrefix(displayID: displayID))\(timestamp).heic"
    }

    /// This display's other dynamic renders and their abandoned temp siblings.
    /// Everything else in the listing is left alone.
    static func staleDynamicFiles(in filenames: [String], displayID: CGDirectDisplayID, keeping: String) -> [String] {
        let prefix = dynamicPrefix(displayID: displayID)
        // The HEIC writer only sweeps temps of the name it is writing, so earlier names' temps land here.
        let tempPrefix = ".\(prefix)"
        let keptTempPrefix = ".\(keeping)."
        return filenames.filter { name in
            if name.hasPrefix(prefix), name.hasSuffix(".heic") { return name != keeping }
            return name.hasPrefix(tempPrefix) && name.hasSuffix(".tmp") && !name.hasPrefix(keptTempPrefix)
        }
    }

    /// True for a static wallpaper written before 1.7.1, when files were keyed on the screen name.
    static func isLegacyStaticName(_ filename: String) -> Bool {
        guard filename.hasPrefix("spreadpaper_wall_"), filename.hasSuffix(".png") else { return false }
        return filename.wholeMatch(of: /spreadpaper_wall_\d+_\d+\.png/) == nil
    }

    /// True for a dynamic wallpaper keyed on the screen name or on a bare display ID.
    /// Only `<displayID>_<timestamp>.heic` is current.
    static func isLegacyDynamicName(_ filename: String) -> Bool {
        guard filename.hasSuffix(".heic") else { return false }
        return filename.wholeMatch(of: /\d+_\d+\.heic/) == nil
    }
}
