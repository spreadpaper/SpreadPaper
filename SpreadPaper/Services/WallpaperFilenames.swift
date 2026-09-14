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

    /// Newest render each departed display holds on to, keyed by that display.
    /// A Space pointing at a display that comes back still resolves.
    private static func newestPerDepartedDisplay(
        _ filenames: [String],
        connected: Set<CGDirectDisplayID>,
        displayID: (String) -> CGDirectDisplayID?,
        timestamp: (String) -> Int?
    ) -> Set<String> {
        var newest: [CGDirectDisplayID: String] = [:]
        for name in filenames {
            guard let id = displayID(name), !connected.contains(id) else { continue }
            if let held = newest[id], (timestamp(held) ?? 0) >= (timestamp(name) ?? 0) { continue }
            newest[id] = name
        }
        return Set(newest.values)
    }

    /// Names the static wallpaper directory can lose after an apply, from its own listing.
    /// Each connected display keeps its newest renders up to the retention limit.
    /// A departed display keeps one; legacy names go once all are set.
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
        let connected = Set(displayIDs)
        // An empty display list proves nothing about what is still in use, so it sweeps nothing.
        let sweepUnowned = sweepLegacy && !displayIDs.isEmpty
        let departedKeep = sweepUnowned
            ? newestPerDepartedDisplay(filenames, connected: connected, displayID: staticDisplayID, timestamp: staticTimestamp)
            : []
        return filenames.filter { name in
            guard name.hasSuffix(".png"), !kept.contains(name) else { return false }
            if owned.contains(name) { return true }
            guard sweepUnowned else { return false }
            if let displayID = staticDisplayID(name) {
                return !connected.contains(displayID) && !departedKeep.contains(name)
            }
            return isLegacyStaticName(name)
        }
    }

    /// Names a dynamic preset directory can lose after an apply, from its own listing.
    /// Each connected display keeps its newest; abandoned temp siblings go.
    /// A departed display keeps one; legacy names go once all are set.
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
        let connected = Set(displayIDs)
        // An empty display list proves nothing about what is still in use, so it sweeps nothing.
        let sweepUnowned = sweepLegacy && !displayIDs.isEmpty
        let departedKeep = sweepUnowned
            ? newestPerDepartedDisplay(filenames, connected: connected, displayID: dynamicDisplayID, timestamp: dynamicTimestamp)
            : []
        return filenames.filter { name in
            // The HEIC writer only sweeps temps of the name it is writing, so earlier names' temps land here.
            if let target = dynamicTempTarget(name) { return !kept.contains(target) }
            guard name.hasSuffix(".heic"), !kept.contains(name) else { return false }
            if owned.contains(name) { return true }
            guard sweepUnowned else { return false }
            if let displayID = dynamicDisplayID(name) {
                return !connected.contains(displayID) && !departedKeep.contains(name)
            }
            return isLegacyDynamicName(name)
        }
    }

    /// Display a current static name is keyed on, which says whose render it is.
    /// Nil for a legacy name and for anything the app did not write.
    static func staticDisplayID(_ filename: String) -> CGDirectDisplayID? {
        guard let match = filename.wholeMatch(of: /spreadpaper_wall_(\d+)_\d+\.png/) else { return nil }
        return CGDirectDisplayID(match.1)
    }

    /// Display a current dynamic name is keyed on, which says whose render it is.
    /// Nil for a legacy name and for anything the app did not write.
    static func dynamicDisplayID(_ filename: String) -> CGDirectDisplayID? {
        guard let match = filename.wholeMatch(of: /(\d+)_\d{10,}\.heic/) else { return nil }
        return CGDirectDisplayID(match.1)
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

    /// Folders under `dynamic/` no preset claims any more, from that directory's listing.
    /// Ids are compared as parsed UUIDs, so a folder's casing never decides.
    /// Anything else in that directory is left alone.
    static func removableDynamicDirectories(in names: [String], presetIds: [UUID]) -> [String] {
        let live = Set(presetIds)
        return names.filter { name in
            guard let id = UUID(uuidString: name) else { return false }
            return !live.contains(id)
        }
    }
}
