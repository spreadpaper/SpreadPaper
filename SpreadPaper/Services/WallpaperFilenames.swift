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

    /// Millisecond timestamp a name ends with once `suffix` is dropped, for ordering renders.
    /// Nil unless digits follow the last underscore.
    private static func trailingTimestamp(_ filename: String, suffix: String) -> Int? {
        guard filename.hasSuffix(suffix) else { return nil }
        let stem = filename.dropLast(suffix.count)
        guard let separator = stem.lastIndex(of: "_") else { return nil }
        return Int(stem[stem.index(after: separator)...])
    }

    /// Millisecond timestamp a current static name ends with, for ordering a display's renders.
    /// Nil unless digits follow the last underscore.
    static func staticTimestamp(_ filename: String) -> Int? {
        trailingTimestamp(filename, suffix: ".png")
    }

    /// Millisecond timestamp a current dynamic name ends with, for ordering a display's renders.
    /// Nil for every other shape.
    static func dynamicTimestamp(_ filename: String) -> Int? {
        trailingTimestamp(filename, suffix: ".heic")
    }

    /// Renders one display keeps, at the ceiling of 16 desktops macOS allows per display.
    /// Each desktop holds its own wallpaper path, and points at an earlier file.
    static let retainedRendersPerDisplay = 16

    /// Names one display keeps: its newest renders up to the retention limit, and `current`.
    /// A display with no current render also keeps its oldest.
    private static func keptRenders(
        _ renders: [String],
        current: String?,
        timestamp: (String) -> Int?
    ) -> Set<String> {
        let newestFirst = renders.sorted { (timestamp($0) ?? 0) > (timestamp($1) ?? 0) }
        var kept = Set(newestFirst.prefix(retainedRendersPerDisplay))
        if let current {
            kept.insert(current)
        } else if let oldest = newestFirst.last {
            kept.insert(oldest)
        }
        return kept
    }

    /// Names the static wallpaper directory can lose after an apply, from its own listing.
    /// Each display keeps its newest renders, capped at the retention limit.
    /// Legacy names go once every display is set.
    static func removableStaticFiles(
        in filenames: [String],
        displayIDs: [CGDirectDisplayID],
        keeping: [CGDirectDisplayID: String],
        sweepLegacy: Bool
    ) -> [String] {
        var kept: Set<String> = []
        var owned: Set<String> = []
        for displayID in displayIDs {
            let prefix = staticPrefix(displayID: displayID)
            let renders = filenames.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".png") }
            owned.formUnion(renders)
            kept.formUnion(keptRenders(renders, current: keeping[displayID], timestamp: staticTimestamp))
        }
        return filenames.filter { name in
            guard name.hasSuffix(".png"), !kept.contains(name) else { return false }
            return owned.contains(name) || (sweepLegacy && isLegacyStaticName(name))
        }
    }

    /// Names a dynamic preset directory can lose after an apply, from its own listing.
    /// Each display keeps its newest renders; abandoned temp siblings go.
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
            kept.formUnion(keptRenders(renders, current: keeping[displayID], timestamp: dynamicTimestamp))
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
