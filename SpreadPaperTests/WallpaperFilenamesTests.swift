import Foundation
import Testing
@testable import SpreadPaper

/// Issue #55: identical monitors share a localizedName, so files must be keyed on the display ID.
struct WallpaperFilenamesTests {
    @Test func differentDisplaysGetDifferentStaticNames() {
        let a = WallpaperFilenames.staticName(displayID: 1, timestamp: 100)
        let b = WallpaperFilenames.staticName(displayID: 2, timestamp: 100)
        #expect(a != b)
    }

    @Test func differentDisplaysGetDifferentDynamicNames() {
        let a = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 100)
        let b = WallpaperFilenames.dynamicName(displayID: 2, timestamp: 100)
        #expect(a != b)
    }

    @Test func dynamicNamesCarryTheTimestamp() {
        #expect(WallpaperFilenames.dynamicName(displayID: 69734400, timestamp: 1700000000000) == "69734400_1700000000000.heic")
        let a = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 100)
        let b = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 200)
        #expect(a != b)
    }

    @Test func staticPrefixOnlyMatchesItsOwnDisplay() {
        let prefix = WallpaperFilenames.staticPrefix(displayID: 1)
        #expect(WallpaperFilenames.staticName(displayID: 1, timestamp: 5).hasPrefix(prefix))
        #expect(!WallpaperFilenames.staticName(displayID: 12, timestamp: 5).hasPrefix(prefix))
    }

    @Test func dynamicPrefixOnlyMatchesItsOwnDisplay() {
        let prefix = WallpaperFilenames.dynamicPrefix(displayID: 1)
        #expect(WallpaperFilenames.dynamicName(displayID: 1, timestamp: 5).hasPrefix(prefix))
        #expect(!WallpaperFilenames.dynamicName(displayID: 12, timestamp: 5).hasPrefix(prefix))
    }

    @Test func legacyStaticNamesAreDetected() {
        #expect(WallpaperFilenames.isLegacyStaticName("spreadpaper_wall_LG ULTRAWIDE_1700000000000.png"))
        #expect(WallpaperFilenames.isLegacyStaticName("spreadpaper_wall_Built-in Retina Display_1.png"))
        #expect(!WallpaperFilenames.isLegacyStaticName(WallpaperFilenames.staticName(displayID: 69734400, timestamp: 1700000000000)))
        #expect(!WallpaperFilenames.isLegacyStaticName("unrelated.png"))
    }

    @Test func legacyDynamicNamesAreDetected() {
        #expect(WallpaperFilenames.isLegacyDynamicName("LG ULTRAWIDE.heic"))
        #expect(WallpaperFilenames.isLegacyDynamicName("69734400.heic"))
        #expect(!WallpaperFilenames.isLegacyDynamicName(WallpaperFilenames.dynamicName(displayID: 69734400, timestamp: 1700000000000)))
        #expect(!WallpaperFilenames.isLegacyDynamicName("notes.txt"))
    }

    @Test func staleDynamicFilesSkipTheCurrentRender() {
        let current = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 300)
        let listing = [current, "1_100.heic", "1_200.heic"]
        let stale = WallpaperFilenames.staleDynamicFiles(in: listing, displayID: 1, keeping: current)
        #expect(stale.sorted() == ["1_100.heic", "1_200.heic"])
    }

    @Test func staleDynamicFilesSpareOtherDisplaysAndOtherFiles() {
        let current = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 300)
        let listing = [current, "1_100.heic", "12_100.heic", "2_100.heic", "1.heic", "LG ULTRAWIDE.heic", "1_100.txt"]
        let stale = WallpaperFilenames.staleDynamicFiles(in: listing, displayID: 1, keeping: current)
        #expect(stale == ["1_100.heic"])
    }

    @Test func staleDynamicFilesAreRemovedFromDisk() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let current = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 300)
        let written = [current, "1_100.heic", "2_100.heic", "1.heic"]
        for filename in written {
            try Data().write(to: directory.appending(path: filename))
        }

        let listing = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        for filename in WallpaperFilenames.staleDynamicFiles(in: listing, displayID: 1, keeping: current) {
            try FileManager.default.removeItem(at: directory.appending(path: filename))
        }

        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        #expect(remaining == ["1.heic", "1_300.heic", "2_100.heic"])
    }
}
