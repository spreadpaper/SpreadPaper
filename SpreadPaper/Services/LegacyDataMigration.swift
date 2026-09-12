import Foundation
import os

/// Counts only; file names appear at `.public`, full paths never do.
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SpreadPaper", category: "migration")

/// Copies data written by unsandboxed builds into the sandbox container.
/// Runs at most once, then records that in UserDefaults.
/// Never removes anything from the legacy root.
enum LegacyDataMigration {
    /// UserDefaults key recording that the migration has already run.
    static let completedKey = "legacyDataMigrationCompleted"

    /// What a single migration attempt did.
    enum Outcome: Equatable {
        case alreadyCompleted
        case destinationAlreadyPopulated
        case legacyMissing
        case legacyUnreadable
        case migrated(copied: Int, failed: Int)
    }

    /// Data root of an unsandboxed install, under the real home directory.
    /// Inside a sandbox `NSHomeDirectory()` returns the container.
    static func defaultLegacyRoot() -> URL {
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home, isDirectory: true)
            .appending(path: "Library/Application Support/SpreadPaper", directoryHint: .isDirectory)
    }

    /// Migrates the real legacy root into `destination`, against standard defaults.
    /// Silent on every failure; the app carries on with an empty library.
    @discardableResult
    static func runIfNeeded(destination: URL) -> Outcome {
        run(legacyRoot: defaultLegacyRoot(), destination: destination, defaults: .standard)
    }

    /// Copies every visible entry of `legacyRoot` into `destination`, once.
    /// Skips entirely when `destination` already holds a presets file.
    /// Throws nothing: an unreadable root is a no-op.
    @discardableResult
    static func run(legacyRoot: URL, destination: URL, defaults: UserDefaults) -> Outcome {
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

        guard let entries = try? fm.contentsOfDirectory(atPath: legacyRoot.path) else {
            // The flag stays unset so a build that is allowed to read the legacy root can still migrate.
            logger.notice("Legacy data directory is not readable; nothing migrated")
            return .legacyUnreadable
        }

        let names = entries.filter { !$0.hasPrefix(".") }.sorted()
        if !fm.fileExists(atPath: destination.path) {
            try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        var copied = 0
        var failed = 0
        // The presets file lands last: until it exists the next launch retries, so a crash mid-copy
        // cannot strand a library that points at images which never arrived.
        for name in names.filter({ $0 != PresetStore.filename }) + names.filter({ $0 == PresetStore.filename }) {
            if copyEntry(named: name, from: legacyRoot, to: destination) {
                copied += 1
            } else {
                failed += 1
            }
        }

        defaults.set(true, forKey: completedKey)
        logger.notice("Migrated \(copied, privacy: .public) legacy items, \(failed, privacy: .public) failed")
        return .migrated(copied: copied, failed: failed)
    }

    /// Copies one entry, recursing into directories, and reports whether it is in place.
    /// An entry already present in `destination` is left exactly as it is.
    private static func copyEntry(named name: String, from legacyRoot: URL, to destination: URL) -> Bool {
        let fm = FileManager.default
        let target = destination.appending(path: name)
        guard !fm.fileExists(atPath: target.path) else { return true }
        do {
            try fm.copyItem(at: legacyRoot.appending(path: name), to: target)
            return true
        } catch {
            logger.error("Copying legacy item \(name, privacy: .public) failed: \(error, privacy: .public)")
            return false
        }
    }
}
