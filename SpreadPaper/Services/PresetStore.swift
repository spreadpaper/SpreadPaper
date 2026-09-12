import Foundation

/// Reads and writes the presets JSON file in the app data directory. A file that
/// fails to decode is moved to a `.bak` sibling before the error surfaces, so a
/// later save can never overwrite the user's only copy.
struct PresetStore {
    static let filename = "spreadpaper_presets.json"
    static let backupFilename = "spreadpaper_presets.json.bak"

    enum LoadError: LocalizedError {
        case corrupted(backup: URL, underlying: any Error)

        var errorDescription: String? {
            switch self {
            case .corrupted(let backup, _):
                return "Could not load presets. A backup was saved as \(backup.lastPathComponent)."
            }
        }
    }

    /// Result of a successful load.
    struct Loaded {
        let presets: [SavedPreset]
        /// True when the file predates the `isAppearanceBased` key and should be rewritten once.
        let needsMigrationRewrite: Bool
    }

    let directory: URL

    var fileURL: URL { directory.appending(path: Self.filename) }
    var backupURL: URL { directory.appending(path: Self.backupFilename) }

    /// Loads presets from disk, returning nil when no presets file exists yet, and
    /// throwing `LoadError.corrupted` after moving an undecodable file aside.
    func load() throws -> Loaded? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        do {
            let decoded = try JSONDecoder().decode([SavedPreset].self, from: data)
            let needsRewrite = !decoded.isEmpty && !data.contains(Data("\"isAppearanceBased\"".utf8))
            return Loaded(presets: decoded, needsMigrationRewrite: needsRewrite)
        } catch {
            try quarantineCorruptFile()
            throw LoadError.corrupted(backup: backupURL, underlying: error)
        }
    }

    /// Writes presets to disk atomically so a crash mid-write cannot leave a partial file.
    func save(_ presets: [SavedPreset]) throws {
        let data = try JSONEncoder().encode(presets)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Moves the presets file to `backupURL`, replacing any earlier backup.
    private func quarantineCorruptFile() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: backupURL.path) {
            try fm.removeItem(at: backupURL)
        }
        try fm.moveItem(at: fileURL, to: backupURL)
    }
}
