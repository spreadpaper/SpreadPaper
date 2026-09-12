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
        #expect(WallpaperFilenames.dynamicName(displayID: 1) != WallpaperFilenames.dynamicName(displayID: 2))
    }

    @Test func staticPrefixOnlyMatchesItsOwnDisplay() {
        let prefix = WallpaperFilenames.staticPrefix(displayID: 1)
        #expect(WallpaperFilenames.staticName(displayID: 1, timestamp: 5).hasPrefix(prefix))
        #expect(!WallpaperFilenames.staticName(displayID: 12, timestamp: 5).hasPrefix(prefix))
    }

    @Test func legacyStaticNamesAreDetected() {
        #expect(WallpaperFilenames.isLegacyStaticName("spreadpaper_wall_LG ULTRAWIDE_1700000000000.png"))
        #expect(WallpaperFilenames.isLegacyStaticName("spreadpaper_wall_Built-in Retina Display_1.png"))
        #expect(!WallpaperFilenames.isLegacyStaticName(WallpaperFilenames.staticName(displayID: 69734400, timestamp: 1700000000000)))
        #expect(!WallpaperFilenames.isLegacyStaticName("unrelated.png"))
    }

    @Test func legacyDynamicNamesAreDetected() {
        #expect(WallpaperFilenames.isLegacyDynamicName("LG ULTRAWIDE.heic"))
        #expect(!WallpaperFilenames.isLegacyDynamicName(WallpaperFilenames.dynamicName(displayID: 69734400)))
        #expect(!WallpaperFilenames.isLegacyDynamicName("notes.txt"))
    }
}
