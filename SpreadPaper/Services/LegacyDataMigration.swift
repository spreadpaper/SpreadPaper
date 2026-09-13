import AppKit
import Foundation
import os

/// Counts only; file names appear at `.public`, full paths never do.
private nonisolated let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SpreadPaper", category: "migration")

/// Copies a library written by an earlier version into the app's own folder.
/// Runs once, on a folder the user picked, then records that.
/// Never removes anything from the source.
enum LegacyDataMigration {
    /// UserDefaults key recording that the import has already happened.
    nonisolated static let completedKey = "legacyDataMigrationCompleted"

    /// UserDefaults key recording that the banner was waved away for good.
    nonisolated static let bannerSuppressedKey = "legacyImportBannerSuppressed"

    /// What a single copy attempt did.
    enum Outcome: Equatable {
        case alreadyCompleted
        case destinationAlreadyPopulated
        case legacyMissing
        case legacyUnreadable
        case migrated(copied: Int, failed: Int)
    }

    /// What an import from a folder the user picked did.
    enum ImportOutcome: Equatable {
        case noWallpapersFound
        case unreadable
        case imported(count: Int)
    }

    /// Data root of an earlier version, under the real home folder.
    /// `NSHomeDirectory()` would answer with the app's own folder.
    nonisolated static func defaultLegacyRoot() -> URL {
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home, isDirectory: true)
            .appending(path: "Library/Application Support/SpreadPaper", directoryHint: .isDirectory)
    }

    /// Whether the gallery should raise the offer on its own.
    /// Pure over the four facts a launch can observe.
    nonisolated static func needsImport(
        completed: Bool, suppressed: Bool, legacyExists: Bool, destinationHasPresets: Bool
    ) -> Bool {
        !completed && !suppressed && legacyExists && !destinationHasPresets
    }

    /// Whether the import is still worth offering somewhere findable.
    /// True once a library is there and has not arrived yet.
    nonisolated static func canOffer(completed: Bool, legacyExists: Bool) -> Bool {
        !completed && legacyExists
    }

    /// Whether the earlier library can be cleared away now.
    /// Only once its wallpapers are safely here.
    nonisolated static func canRemove(completed: Bool, legacyExists: Bool) -> Bool {
        completed && legacyExists
    }

    /// Whether these two names point at the same folder on disk.
    /// Symlinks resolve first, so an alias cannot slip past.
    nonisolated static func isSameFolder(_ one: URL, _ other: URL) -> Bool {
        one.resolvingSymlinksInPath().standardizedFileURL
            == other.resolvingSymlinksInPath().standardizedFileURL
    }

    /// Whether `url` holds a library an earlier version wrote.
    /// Reads through the access a chosen folder grants.
    nonisolated static func holdsLibrary(at url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return FileManager.default.fileExists(atPath: url.appending(path: PresetStore.filename).path)
    }

    /// Moves a library the user picked to the Trash, where it can be fetched back.
    /// The folder named by `inUse` is refused, whatever the user picked.
    /// Records that nothing is left to bring in.
    static func removeLibrary(at url: URL, inUse: URL, defaults: UserDefaults) async -> Bool {
        guard !isSameFolder(url, inUse) else {
            logger.error("Refused to move the folder in use to the Trash")
            return false
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let recycled: Bool = await withCheckedContinuation { continuation in
            NSWorkspace.shared.recycle([url]) { @Sendable _, error in
                continuation.resume(returning: error == nil)
            }
        }
        guard recycled else {
            logger.error("Moving the legacy library to the Trash failed")
            return false
        }

        defaults.set(true, forKey: completedKey)
        return true
    }

    /// Brings the library in `source` into `destination` and records that it arrived.
    /// Wallpapers already in `destination` are kept; only unseen ones are added.
    /// A folder holding no library changes nothing.
    nonisolated static func importLibrary(from source: URL, destination: URL, defaults: UserDefaults) -> ImportOutcome {
        // A folder picked in the open panel is readable without this call, which then answers false.
        // Starting the scope anyway covers the folders that do hand one out, for the whole copy.
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        guard fm.fileExists(atPath: source.appending(path: PresetStore.filename).path) else {
            return .noWallpapersFound
        }

        guard fm.fileExists(atPath: destination.appending(path: PresetStore.filename).path) else {
            switch run(legacyRoot: source, destination: destination, defaults: defaults) {
            case .migrated:
                // Counted from what is now on disk, not from what the source claimed.
                return .imported(count: decodedPresets(in: destination)?.count ?? 0)
            case .legacyUnreadable:
                return .unreadable
            case .alreadyCompleted, .destinationAlreadyPopulated, .legacyMissing:
                return .noWallpapersFound
            }
        }

        // A file that will not decode stays as it is; replacing it would drop whatever it holds.
        guard let existing = decodedPresets(in: destination) else { return .unreadable }
        guard let names = visibleEntries(of: source) else { return .unreadable }

        let known = Set(existing.map(\.id))
        let added = (decodedPresets(in: source) ?? []).filter { !known.contains($0.id) }
        _ = copyEntries(named: names.filter { $0 != PresetStore.filename }, from: source, to: destination)
        if !added.isEmpty, let merged = try? JSONEncoder().encode(existing + added) {
            try? merged.write(to: destination.appending(path: PresetStore.filename), options: .atomic)
        }

        defaults.set(true, forKey: completedKey)
        logger.notice("Imported \(added.count, privacy: .public) wallpapers alongside \(existing.count, privacy: .public) already here")
        return .imported(count: added.count)
    }

    /// Copies every visible entry of `legacyRoot` into `destination`, once.
    /// Skips entirely when `destination` already holds a presets file.
    /// Throws nothing: an unreadable root is a no-op.
    @discardableResult
    nonisolated static func run(legacyRoot: URL, destination: URL, defaults: UserDefaults) -> Outcome {
        guard !defaults.bool(forKey: completedKey) else { return .alreadyCompleted }

        let fm = FileManager.default
        guard !fm.fileExists(atPath: destination.appending(path: PresetStore.filename).path) else {
            defaults.set(true, forKey: completedKey)
            return .destinationAlreadyPopulated
        }

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: legacyRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            defaults.set(true, forKey: completedKey)
            return .legacyMissing
        }

        guard let names = visibleEntries(of: legacyRoot) else {
            // The flag stays unset so a later attempt that can read the folder still copies it.
            logger.notice("Legacy data directory is not readable; nothing migrated")
            return .legacyUnreadable
        }

        // The presets file lands last: until it exists the next attempt retries, so a crash mid-copy
        // cannot strand a library that points at images which never arrived.
        let ordered = names.filter { $0 != PresetStore.filename } + names.filter { $0 == PresetStore.filename }
        let result = copyEntries(named: ordered, from: legacyRoot, to: destination)

        defaults.set(true, forKey: completedKey)
        logger.notice("Migrated \(result.copied, privacy: .public) legacy items, \(result.failed, privacy: .public) failed")
        return .migrated(copied: result.copied, failed: result.failed)
    }

    /// Names of everything in `root` bar dot files, sorted, or nil when it cannot be read.
    nonisolated private static func visibleEntries(of root: URL) -> [String]? {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: root.path) else { return nil }
        return entries.filter { !$0.hasPrefix(".") }.sorted()
    }

    /// Wallpapers recorded in `root`, or nil when there is no readable record.
    nonisolated private static func decodedPresets(in root: URL) -> [SavedPreset]? {
        guard let data = try? Data(contentsOf: root.appending(path: PresetStore.filename)) else { return nil }
        return try? JSONDecoder().decode([SavedPreset].self, from: data)
    }

    /// Copies each named entry into `destination`, creating it first.
    /// Reports how many are in place and how many failed.
    nonisolated private static func copyEntries(named names: [String], from source: URL, to destination: URL) -> (copied: Int, failed: Int) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: destination.path) {
            try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        var copied = 0
        var failed = 0
        for name in names {
            if copyEntry(named: name, from: source, to: destination) {
                copied += 1
            } else {
                failed += 1
            }
        }
        return (copied, failed)
    }

    /// Copies one entry and reports whether it is in place afterwards.
    /// A file already there is kept; a folder there is filled in.
    nonisolated private static func copyEntry(named name: String, from source: URL, to destination: URL) -> Bool {
        let fm = FileManager.default
        let origin = source.appending(path: name)
        let target = destination.appending(path: name)

        var targetIsFolder: ObjCBool = false
        if fm.fileExists(atPath: target.path, isDirectory: &targetIsFolder) {
            var originIsFolder: ObjCBool = false
            fm.fileExists(atPath: origin.path, isDirectory: &originIsFolder)
            guard targetIsFolder.boolValue, originIsFolder.boolValue else { return true }
            guard let names = visibleEntries(of: origin) else { return false }
            return copyEntries(named: names, from: origin, to: target).failed == 0
        }

        do {
            try fm.copyItem(at: origin, to: target)
            return true
        } catch {
            logger.error("Copying legacy item \(name, privacy: .public) failed: \(error, privacy: .public)")
            return false
        }
    }
}
