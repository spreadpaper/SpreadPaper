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
        #expect(WallpaperFilenames.isLegacyDynamicName("27_2.heic"))
        #expect(!WallpaperFilenames.isLegacyDynamicName(WallpaperFilenames.dynamicName(displayID: 69734400, timestamp: 1700000000000)))
        #expect(!WallpaperFilenames.isLegacyDynamicName("notes.txt"))
    }

    @Test func dynamicTimestampReadsOnlyCurrentNames() {
        #expect(WallpaperFilenames.dynamicTimestamp("1_1700000000000.heic") == 1700000000000)
        #expect(WallpaperFilenames.dynamicTimestamp("1.heic") == nil)
        #expect(WallpaperFilenames.dynamicTimestamp("LG ULTRAWIDE.heic") == nil)
        #expect(WallpaperFilenames.dynamicTimestamp(".1_100.heic.killed.tmp") == nil)
    }

    @Test func dynamicTempTargetsAreRecognised() {
        #expect(WallpaperFilenames.dynamicTempTarget(".1_100.heic.killed.tmp") == "1_100.heic")
        #expect(WallpaperFilenames.dynamicTempTarget(".LG ULTRAWIDE.heic.killed.tmp") == "LG ULTRAWIDE.heic")
        #expect(WallpaperFilenames.dynamicTempTarget("1_100.heic") == nil)
        #expect(WallpaperFilenames.dynamicTempTarget(".notes.txt.tmp") == nil)
    }

    @Test func aSetDisplayKeepsOnlyItsNewRender() {
        let current = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 300)
        let listing = [current, "1_100.heic", "1_200.heic"]
        let removable = WallpaperFilenames.removableDynamicFiles(
            in: listing, displayIDs: [1], keeping: [1: current], sweepLegacy: true
        )
        #expect(removable.sorted() == ["1_100.heic", "1_200.heic"])
    }

    @Test func otherDisplaysAndUnrelatedFilesAreSpared() {
        let current = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 300)
        let listing = [current, "1_100.heic", "12_100.heic", "2_100.heic", "1_100.txt"]
        let removable = WallpaperFilenames.removableDynamicFiles(
            in: listing, displayIDs: [1, 2], keeping: [1: current, 2: "2_100.heic"], sweepLegacy: false
        )
        #expect(removable == ["1_100.heic"])
    }

    @Test func aFailedDisplayKeepsItsOldestAndNewestRenders() {
        let listing = ["1_100.heic", "1_200.heic", "1_300.heic", "1_400.heic"]
        let removable = WallpaperFilenames.removableDynamicFiles(
            in: listing, displayIDs: [1], keeping: [:], sweepLegacy: false
        )
        #expect(removable.sorted() == ["1_200.heic", "1_300.heic"])
    }

    @Test func legacyNamesGoOnlyWhenEveryDisplayWasSet() {
        let current = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 1700000000000)
        let listing = [current, "1.heic", "LG ULTRAWIDE.heic"]
        let spared = WallpaperFilenames.removableDynamicFiles(
            in: listing, displayIDs: [1, 2], keeping: [1: current], sweepLegacy: false
        )
        #expect(spared.isEmpty)
        let swept = WallpaperFilenames.removableDynamicFiles(
            in: listing, displayIDs: [1], keeping: [1: current], sweepLegacy: true
        )
        #expect(swept.sorted() == ["1.heic", "LG ULTRAWIDE.heic"])
    }

    @Test func abandonedTempSiblingsAlwaysGo() {
        let current = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 300)
        let listing = [
            current, ".\(current).live.tmp", ".1_100.heic.killed.tmp",
            ".1.heic.killed.tmp", ".LG ULTRAWIDE.heic.killed.tmp", ".2_100.heic.killed.tmp"
        ]
        let removable = WallpaperFilenames.removableDynamicFiles(
            in: listing, displayIDs: [1], keeping: [1: current], sweepLegacy: false
        )
        #expect(removable.sorted() == [
            ".1.heic.killed.tmp", ".1_100.heic.killed.tmp", ".2_100.heic.killed.tmp", ".LG ULTRAWIDE.heic.killed.tmp"
        ])
    }
}
