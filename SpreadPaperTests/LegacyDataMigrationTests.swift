import Foundation
import Testing
@testable import SpreadPaper

/// Drives the one-time legacy copy over throwaway directories and defaults suites.
@MainActor
struct LegacyDataMigrationTests {
    /// Fresh empty directory under the temporary directory.
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "LegacyDataMigrationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Isolated defaults suite, removed again when `body` returns.
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "LegacyDataMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    /// Legacy root holding a presets file, a stored image, `wallpapers/` and `dynamic/<uuid>/`.
    private func makePopulatedLegacyRoot() throws -> (root: URL, dynamicPresetId: String) {
        let fm = FileManager.default
        let root = try makeTempDirectory()
        try Data("[{\"name\":\"legacy\"}]".utf8).write(to: root.appending(path: PresetStore.filename))
        try Data("image-bytes".utf8).write(to: root.appending(path: "\(UUID().uuidString)_original.jpg"))

        let wallpapers = root.appending(path: "wallpapers", directoryHint: .isDirectory)
        try fm.createDirectory(at: wallpapers, withIntermediateDirectories: true)
        try Data("png-bytes".utf8).write(to: wallpapers.appending(path: "spreadpaper_wall_1_2.png"))

        let presetId = UUID().uuidString
        let dynamicPreset = root
            .appending(path: "dynamic", directoryHint: .isDirectory)
            .appending(path: presetId, directoryHint: .isDirectory)
        try fm.createDirectory(at: dynamicPreset, withIntermediateDirectories: true)
        try Data("heic-bytes".utf8).write(to: dynamicPreset.appending(path: "1_2.heic"))
        return (root, presetId)
    }

    /// Every relative path under `root`, sorted, so two trees can be compared.
    private func relativePaths(under root: URL) -> [String] {
        let all = FileManager.default.enumerator(atPath: root.path)?.allObjects as? [String] ?? []
        return all.filter { !$0.hasPrefix(".") && !$0.contains("/.") }.sorted()
    }

    @Test func copiesEveryFileAndLeavesTheLegacyRootIntact() throws {
        let (legacy, presetId) = try makePopulatedLegacyRoot()
        let destination = try makeTempDirectory()
        let before = relativePaths(under: legacy)

        try withDefaults { defaults in
            let outcome = LegacyDataMigration.run(legacyRoot: legacy, destination: destination, defaults: defaults)
            #expect(outcome == .migrated(copied: 4, failed: 0))
            #expect(defaults.bool(forKey: LegacyDataMigration.completedKey))
        }

        #expect(relativePaths(under: destination) == before)
        #expect(relativePaths(under: legacy) == before, "the legacy root must survive untouched")

        for path in before {
            let source = legacy.appending(path: path)
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory)
            guard !isDirectory.boolValue else { continue }
            let copiedBytes = try Data(contentsOf: destination.appending(path: path))
            #expect(copiedBytes == (try Data(contentsOf: source)), "\(path) must be byte-identical")
        }

        let heic = destination.appending(path: "dynamic/\(presetId)/1_2.heic")
        #expect(FileManager.default.fileExists(atPath: heic.path), "nested dynamic folders must survive")
    }

    @Test func populatedDestinationIsNeverOverwritten() throws {
        let (legacy, _) = try makePopulatedLegacyRoot()
        let destination = try makeTempDirectory()
        let existing = Data("[{\"name\":\"container\"}]".utf8)
        try existing.write(to: destination.appending(path: PresetStore.filename))

        try withDefaults { defaults in
            let outcome = LegacyDataMigration.run(legacyRoot: legacy, destination: destination, defaults: defaults)
            #expect(outcome == .destinationAlreadyPopulated)
            #expect(defaults.bool(forKey: LegacyDataMigration.completedKey))
        }

        #expect(try Data(contentsOf: destination.appending(path: PresetStore.filename)) == existing)
        #expect(relativePaths(under: destination) == [PresetStore.filename], "nothing else may be copied")
    }

    @Test func missingLegacyRootStillCompletes() throws {
        let legacy = FileManager.default.temporaryDirectory.appending(path: "absent-\(UUID().uuidString)")
        let destination = try makeTempDirectory()

        try withDefaults { defaults in
            let outcome = LegacyDataMigration.run(legacyRoot: legacy, destination: destination, defaults: defaults)
            #expect(outcome == .legacyMissing)
            #expect(defaults.bool(forKey: LegacyDataMigration.completedKey))
        }

        #expect(relativePaths(under: destination).isEmpty)
    }

    @Test func emptyLegacyRootStillCompletes() throws {
        let legacy = try makeTempDirectory()
        let destination = try makeTempDirectory()

        try withDefaults { defaults in
            let outcome = LegacyDataMigration.run(legacyRoot: legacy, destination: destination, defaults: defaults)
            #expect(outcome == .migrated(copied: 0, failed: 0))
            #expect(defaults.bool(forKey: LegacyDataMigration.completedKey))
        }

        #expect(relativePaths(under: destination).isEmpty)
    }

    @Test func completedFlagSkipsALegacyRootThatWouldOtherwiseCopy() throws {
        let (legacy, _) = try makePopulatedLegacyRoot()
        let destination = try makeTempDirectory()

        try withDefaults { defaults in
            defaults.set(true, forKey: LegacyDataMigration.completedKey)
            let outcome = LegacyDataMigration.run(legacyRoot: legacy, destination: destination, defaults: defaults)
            #expect(outcome == .alreadyCompleted)
        }

        #expect(relativePaths(under: destination).isEmpty, "a completed migration must not read the legacy root")
    }

    @Test func unreadableLegacyRootIsASilentNoOp() throws {
        let fm = FileManager.default
        let (legacy, _) = try makePopulatedLegacyRoot()
        let destination = try makeTempDirectory()
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: legacy.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: legacy.path) }

        try withDefaults { defaults in
            let outcome = LegacyDataMigration.run(legacyRoot: legacy, destination: destination, defaults: defaults)
            #expect(outcome == .legacyUnreadable)
            #expect(defaults.bool(forKey: LegacyDataMigration.completedKey) == false,
                    "a later build that can read the root must still get its chance")
        }

        #expect(relativePaths(under: destination).isEmpty, "no partial state may be left behind")
    }
}
