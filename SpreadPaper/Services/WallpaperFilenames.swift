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

    /// Output file a `.<name>.<id>.tmp` sibling of the HEIC writer belongs to.
    /// Nil for every other filename.
    static func dynamicTempTarget(_ filename: String) -> String? {
        guard filename.hasPrefix("."), filename.hasSuffix(".tmp") else { return nil }
        let body = filename.dropFirst()
        guard let suffix = body.range(of: ".heic") else { return nil }
        return String(body[body.startIndex ..< suffix.upperBound])
    }

    /// Millisecond timestamp a current dynamic name ends with, for ordering a display's renders.
    /// Nil for every other shape.
    static func dynamicTimestamp(_ filename: String) -> Int? {
        guard filename.hasSuffix(".heic") else { return nil }
        let stem = filename.dropLast(".heic".count)
        guard let separator = stem.lastIndex(of: "_") else { return nil }
        return Int(stem[stem.index(after: separator)...])
    }

    /// Names a dynamic preset directory can lose after an apply; a display that was set keeps its new render.
    /// One whose set failed keeps its oldest and newest; abandoned temp siblings always go.
    /// Legacy names go once every display is set.
    static func removableDynamicFiles(
        in filenames: [String],
        displayIDs: [CGDirectDisplayID],
        keeping: [CGDirectDisplayID: String],
        sweepLegacy: Bool
    ) -> [String] {
        var kept: Set<String> = []
        var owned: Set<String> = []
        for displayID in displayIDs {
            let prefix = dynamicPrefix(displayID: displayID)
            let renders = filenames.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".heic") }
            owned.formUnion(renders)
            if let current = keeping[displayID] {
                kept.insert(current)
                continue
            }
            // A successful apply leaves one render behind, so the oldest is what this display still shows.
            let ordered = renders.sorted { (dynamicTimestamp($0) ?? 0) < (dynamicTimestamp($1) ?? 0) }
            if let oldest = ordered.first { kept.insert(oldest) }
            if let newest = ordered.last { kept.insert(newest) }
        }
        return filenames.filter { name in
            // The HEIC writer only sweeps temps of the name it is writing, so earlier names' temps land here.
            if let target = dynamicTempTarget(name) { return !kept.contains(target) }
            guard name.hasSuffix(".heic"), !kept.contains(name) else { return false }
            return owned.contains(name) || (sweepLegacy && isLegacyDynamicName(name))
        }
    }

    /// True for a static wallpaper written before 1.7.1, when files were keyed on the screen name.
    static func isLegacyStaticName(_ filename: String) -> Bool {
        guard filename.hasPrefix("spreadpaper_wall_"), filename.hasSuffix(".png") else { return false }
        return filename.wholeMatch(of: /spreadpaper_wall_\d+_\d+\.png/) == nil
    }

    /// True for a dynamic wallpaper keyed on the screen name or on a bare display ID.
    /// Current names end in a millisecond timestamp, which no screen name reaches.
    static func isLegacyDynamicName(_ filename: String) -> Bool {
        guard filename.hasSuffix(".heic") else { return false }
        return filename.wholeMatch(of: /\d+_\d{10,}\.heic/) == nil
    }
}
