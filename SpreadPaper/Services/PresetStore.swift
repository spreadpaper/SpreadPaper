import Foundation

/// Reads and writes the presets JSON file in the app data directory.
struct PresetStore {
    static let filename = "spreadpaper_presets.json"
    static let backupFilename = "spreadpaper_presets.json.bak"

    /// Result of a successful load.
    struct Loaded {
        let presets: [SavedPreset]
        /// True when the file predates the `isAppearanceBased` key and should be rewritten once.
        let needsMigrationRewrite: Bool
    }

    let directory: URL

    var fileURL: URL { directory.appending(path: Self.filename) }
    var backupURL: URL { directory.appending(path: Self.backupFilename) }

    /// Loads presets from disk. Returns nil when no presets file exists yet.
    func load() throws -> Loaded? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode([SavedPreset].self, from: data)
        let needsRewrite = !decoded.isEmpty && !data.contains(Data("\"isAppearanceBased\"".utf8))
        return Loaded(presets: decoded, needsMigrationRewrite: needsRewrite)
    }

    /// Writes presets to disk.
    func save(_ presets: [SavedPreset]) throws {
        let data = try JSONEncoder().encode(presets)
        try data.write(to: fileURL)
    }
}
