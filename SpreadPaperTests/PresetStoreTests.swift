import Foundation
import Testing
@testable import SpreadPaper

@MainActor
struct PresetStoreTests {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "PresetStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func samplePreset(name: String) -> SavedPreset {
        SavedPreset(
            name: name,
            imageFilename: "\(name).png",
            offsetX: 1, offsetY: 2, scale: 1.5, previewScale: 0.25, isFlipped: false
        )
    }

    @Test func missingFileLoadsNothing() throws {
        let store = PresetStore(directory: try makeTempDirectory())
        #expect(try store.load() == nil)
    }

    @Test func roundTrip() throws {
        let store = PresetStore(directory: try makeTempDirectory())
        let presets = [samplePreset(name: "a"), samplePreset(name: "b")]
        try store.save(presets)
        let loaded = try #require(try store.load())
        #expect(loaded.presets == presets)
        #expect(loaded.needsMigrationRewrite == false)
    }

    /// Issue #51: a corrupt presets file must be moved aside, never overwritten.
    @Test func corruptFileIsQuarantinedAndNotOverwritten() throws {
        let store = PresetStore(directory: try makeTempDirectory())
        let garbage = Data("{ this is not json".utf8)
        try garbage.write(to: store.fileURL)

        let manager = WallpaperManager(store: store)
        #expect(manager.presets.isEmpty)
        #expect(manager.lastError != nil, "user must be told the library failed to load")

        manager.persistPresetsPublic()

        let backup = try Data(contentsOf: store.backupURL)
        #expect(backup == garbage, "original bytes must survive in the backup file")
    }
}
