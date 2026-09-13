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

    /// Legacy root whose presets file decodes, so an import can count what it brings in.
    private func makeImportableLegacyRoot(presetCount: Int) throws -> (root: URL, dynamicPresetId: String) {
        let (root, presetId) = try makePopulatedLegacyRoot()
        let presets = (0..<presetCount).map {
            SavedPreset(
                name: "legacy \($0)", imageFilename: "\(UUID().uuidString)_original.jpg",
                offsetX: 0, offsetY: 0, scale: 1, previewScale: 1, isFlipped: false
            )
        }
        try JSONEncoder().encode(presets).write(to: root.appending(path: PresetStore.filename))
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

    // MARK: - Detection

    @Test func aWaitingLibraryNeedsImport() {
        #expect(LegacyDataMigration.needsImport(
            completed: false, suppressed: false, legacyExists: true, destinationHasPresets: false
        ))
    }

    @Test func aCompletedImportNeedsNothing() {
        #expect(LegacyDataMigration.needsImport(
            completed: true, suppressed: false, legacyExists: true, destinationHasPresets: false
        ) == false)
    }

    @Test func nothingToImportWithoutALegacyLibrary() {
        #expect(LegacyDataMigration.needsImport(
            completed: false, suppressed: false, legacyExists: false, destinationHasPresets: false
        ) == false)
    }

    @Test func aLibraryAlreadyHereNeedsNoImport() {
        #expect(LegacyDataMigration.needsImport(
            completed: false, suppressed: false, legacyExists: true, destinationHasPresets: true
        ) == false)
    }

    @Test func aSuppressedBannerStaysOfferedInSettings() {
        #expect(LegacyDataMigration.needsImport(
            completed: false, suppressed: true, legacyExists: true, destinationHasPresets: false
        ) == false)
        #expect(LegacyDataMigration.canOffer(completed: false, legacyExists: true))
    }

    @Test func removalIsOnlyOfferedOnceTheWallpapersAreHere() {
        #expect(LegacyDataMigration.canRemove(completed: false, legacyExists: true) == false)
        #expect(LegacyDataMigration.canRemove(completed: true, legacyExists: false) == false)
        #expect(LegacyDataMigration.canRemove(completed: true, legacyExists: true))
    }

    @Test func settingsOffersNothingWithoutALegacyLibrary() {
        #expect(LegacyDataMigration.canOffer(completed: false, legacyExists: false) == false)
    }

    @Test func settingsOffersNothingOnceTheImportCompleted() {
        #expect(LegacyDataMigration.canOffer(completed: true, legacyExists: true) == false)
    }

    // MARK: - Importing a chosen folder

    @Test func aFolderWithoutWallpapersIsRejected() throws {
        let wrongFolder = try makeTempDirectory()
        try Data("not ours".utf8).write(to: wrongFolder.appending(path: "notes.txt"))
        let destination = try makeTempDirectory()

        try withDefaults { defaults in
            let outcome = LegacyDataMigration.importLibrary(
                from: wrongFolder, destination: destination, defaults: defaults
            )
            #expect(outcome == .noWallpapersFound)
            #expect(defaults.bool(forKey: LegacyDataMigration.completedKey) == false,
                    "a wrong pick must leave the offer standing")
        }

        #expect(relativePaths(under: destination).isEmpty)
        #expect(LegacyDataMigration.holdsLibrary(at: wrongFolder) == false)
    }

    @Test func aChosenFolderImportsEveryFileAndSettlesTheFlag() throws {
        let (chosen, presetId) = try makeImportableLegacyRoot(presetCount: 3)
        let destination = try makeTempDirectory()
        let before = relativePaths(under: chosen)

        try withDefaults { defaults in
            let outcome = LegacyDataMigration.importLibrary(
                from: chosen, destination: destination, defaults: defaults
            )
            #expect(outcome == .imported(count: 3))
            #expect(defaults.bool(forKey: LegacyDataMigration.completedKey))
        }

        #expect(relativePaths(under: destination) == before)
        #expect(relativePaths(under: chosen) == before, "the chosen folder must survive untouched")
        let heic = destination.appending(path: "dynamic/\(presetId)/1_2.heic")
        #expect(FileManager.default.fileExists(atPath: heic.path), "nested dynamic folders must survive")
    }

    // MARK: - Message formatting

    @Test func theConfirmationCountsInSingularAndPlural() {
        #expect(LegacyImportFlow.importedMessage(count: 1) == "Imported 1 wallpaper.")
        #expect(LegacyImportFlow.importedMessage(count: 5) == "Imported 5 wallpapers.")
        #expect(LegacyImportFlow.importedMessage(count: 0) == "Imported 0 wallpapers.")
    }

    @Test func aLibraryIsRecognisedByItsPresetsFile() throws {
        let (legacy, _) = try makePopulatedLegacyRoot()
        let bare = try makeTempDirectory()
        #expect(LegacyDataMigration.holdsLibrary(at: legacy))
        #expect(LegacyDataMigration.holdsLibrary(at: bare) == false)
    }

    @Test func importingIntoALibraryAlreadyHereAddsOnlyTheUnseenOnes() throws {
        let fm = FileManager.default
        let (chosen, chosenPresetId) = try makeImportableLegacyRoot(presetCount: 3)
        let destination = try makeTempDirectory()

        let mine = SavedPreset(
            name: "mine", imageFilename: "mine.jpg",
            offsetX: 0, offsetY: 0, scale: 1, previewScale: 1, isFlipped: false
        )
        try JSONEncoder().encode([mine]).write(to: destination.appending(path: PresetStore.filename))
        // A folder of the same name already here must be filled in, not skipped.
        let wallpapers = destination.appending(path: "wallpapers", directoryHint: .isDirectory)
        try fm.createDirectory(at: wallpapers, withIntermediateDirectories: true)
        try Data("ours".utf8).write(to: wallpapers.appending(path: "spreadpaper_wall_9_9.png"))

        try withDefaults { defaults in
            let outcome = LegacyDataMigration.importLibrary(
                from: chosen, destination: destination, defaults: defaults
            )
            #expect(outcome == .imported(count: 3))
            #expect(defaults.bool(forKey: LegacyDataMigration.completedKey))
        }

        let merged = try JSONDecoder().decode(
            [SavedPreset].self, from: Data(contentsOf: destination.appending(path: PresetStore.filename))
        )
        #expect(merged.count == 4)
        #expect(merged.first?.id == mine.id, "the wallpapers already here must survive, in place")

        #expect(fm.fileExists(atPath: wallpapers.appending(path: "spreadpaper_wall_9_9.png").path),
                "our own render must be left alone")
        #expect(fm.fileExists(atPath: wallpapers.appending(path: "spreadpaper_wall_1_2.png").path),
                "an existing folder must be filled in, not skipped")
        #expect(fm.fileExists(atPath: destination.appending(path: "dynamic/\(chosenPresetId)/1_2.heic").path))
    }

    @Test func anUnreadableLibraryHereIsLeftExactlyAsItIs() throws {
        let (chosen, _) = try makeImportableLegacyRoot(presetCount: 2)
        let destination = try makeTempDirectory()
        let garbage = Data("not json".utf8)
        try garbage.write(to: destination.appending(path: PresetStore.filename))

        try withDefaults { defaults in
            let outcome = LegacyDataMigration.importLibrary(
                from: chosen, destination: destination, defaults: defaults
            )
            #expect(outcome == .unreadable)
            #expect(defaults.bool(forKey: LegacyDataMigration.completedKey) == false)
        }

        #expect(try Data(contentsOf: destination.appending(path: PresetStore.filename)) == garbage)
        #expect(relativePaths(under: destination) == [PresetStore.filename], "nothing may be copied")
    }

    @Test func theLibraryInUseIsNeverMistakenForAnEarlierOne() throws {
        let inUse = try makeTempDirectory()
        let mine = SavedPreset(
            name: "mine", imageFilename: "mine.jpg",
            offsetX: 0, offsetY: 0, scale: 1, previewScale: 1, isFlipped: false
        )
        try JSONEncoder().encode([mine]).write(to: inUse.appending(path: PresetStore.filename))
        let (elsewhere, _) = try makeImportableLegacyRoot(presetCount: 1)

        let manager = WallpaperManager(store: PresetStore(directory: inUse))
        #expect(manager.legacyLibraryLooksRight(at: inUse) == false)
        #expect(manager.lastError == "Those are the wallpapers SpreadPaper uses now.")
        #expect(manager.legacyLibraryLooksRight(at: elsewhere))
        #expect(manager.lastError == nil)
    }

    // MARK: - Removing

    @Test func theFolderInUseIsNeverThrownAway() async throws {
        let (library, _) = try makeImportableLegacyRoot(presetCount: 1)
        let name = "LegacyDataMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let removed = await LegacyDataMigration.removeLibrary(at: library, inUse: library, defaults: defaults)
        #expect(removed == false)
        #expect(defaults.bool(forKey: LegacyDataMigration.completedKey) == false)
        #expect(FileManager.default.fileExists(atPath: library.path), "the folder in use must still be there")
        #expect(LegacyDataMigration.isSameFolder(library, library.appending(path: "..").appending(path: library.lastPathComponent)))
    }

    @Test func aFailedRemovalSettlesNothing() async throws {
        let absent = FileManager.default.temporaryDirectory.appending(path: "absent-\(UUID().uuidString)")
        let name = "LegacyDataMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let inUse = try makeTempDirectory()
        let removed = await LegacyDataMigration.removeLibrary(at: absent, inUse: inUse, defaults: defaults)
        #expect(removed == false)
        #expect(defaults.bool(forKey: LegacyDataMigration.completedKey) == false)
    }
}
