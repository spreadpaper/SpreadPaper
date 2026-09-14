import Foundation
import Testing
@testable import SpreadPaper

/// Issue #55: identical monitors share a localizedName, so files must be keyed on the display ID.
struct WallpaperFilenamesTests {
    /// Two renders more than one display keeps, so pruning has exactly two to take.
    let overTheLimit = WallpaperFilenames.retainedRendersPerDisplay + 2

    /// Applies to run when a test checks that the directory stops growing.
    let applyCount = 50

    /// Timestamps left after `applyCount` applies, newest first written last.
    var survivingTimestamps: ClosedRange<Int> {
        (applyCount - WallpaperFilenames.retainedRendersPerDisplay + 1) ... applyCount
    }

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

    @Test func staticTimestampReadsOnlyCurrentNames() {
        #expect(WallpaperFilenames.staticTimestamp("spreadpaper_wall_1_1700000000000.png") == 1700000000000)
        #expect(WallpaperFilenames.staticTimestamp("spreadpaper_wall_1_pending.png") == nil)
        #expect(WallpaperFilenames.staticTimestamp("unrelated.png") == nil)
        #expect(WallpaperFilenames.staticTimestamp("1_100.heic") == nil)
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

    @Test func aSetDisplayKeepsTheRendersOtherDesktopsPointAt() {
        let current = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 300)
        let listing = [current, "1_100.heic", "1_200.heic"]
        let removable = WallpaperFilenames.removableDynamicFiles(
            in: listing, displayIDs: [1], keeping: [1: current], sweepLegacy: true
        )
        #expect(removable.isEmpty)
    }

    @Test func theLimitCoversEveryDesktopMacOSAllows() {
        #expect(WallpaperFilenames.retainedRendersPerDisplay == 16)
        let renders = (1 ... 16).map { WallpaperFilenames.dynamicName(displayID: 1, timestamp: $0) }
        let removable = WallpaperFilenames.removableDynamicFiles(
            in: renders, displayIDs: [1], keeping: [1: renders[15]], sweepLegacy: true
        )
        #expect(removable.isEmpty)
    }

    @Test func aSetDisplayLosesOnlyWhatFallsPastTheLimit() {
        let renders = (1 ... overTheLimit).map { WallpaperFilenames.dynamicName(displayID: 1, timestamp: $0) }
        let current = renders[overTheLimit - 1]
        let removable = WallpaperFilenames.removableDynamicFiles(
            in: renders, displayIDs: [1], keeping: [1: current], sweepLegacy: false
        )
        #expect(removable.sorted() == ["1_1.heic", "1_2.heic"])
        #expect(!removable.contains(current))
    }

    @Test func otherDisplaysAndUnrelatedFilesAreSpared() {
        let renders = (1 ... overTheLimit).map { WallpaperFilenames.dynamicName(displayID: 1, timestamp: $0) }
        let listing = renders + ["12_100.heic", "2_100.heic", "1_100.txt"]
        let removable = WallpaperFilenames.removableDynamicFiles(
            in: listing,
            displayIDs: [1, 2],
            keeping: [1: renders[overTheLimit - 1], 2: "2_100.heic"],
            sweepLegacy: false
        )
        #expect(removable.sorted() == ["1_1.heic", "1_2.heic"])
    }

    @Test func aFailedDisplayKeepsItsOldestRenderToo() {
        let renders = (1 ... overTheLimit).map { WallpaperFilenames.dynamicName(displayID: 1, timestamp: $0) }
        let removable = WallpaperFilenames.removableDynamicFiles(
            in: renders, displayIDs: [1], keeping: [:], sweepLegacy: false
        )
        #expect(removable == ["1_2.heic"])
    }

    @Test func repeatedDynamicAppliesStayBounded() {
        var listing: [String] = []
        for timestamp in 1 ... applyCount {
            let current = WallpaperFilenames.dynamicName(displayID: 1, timestamp: timestamp)
            listing.append(current)
            let removable = WallpaperFilenames.removableDynamicFiles(
                in: listing, displayIDs: [1], keeping: [1: current], sweepLegacy: true
            )
            #expect(!removable.contains(current))
            listing.removeAll { removable.contains($0) }
            #expect(listing.count <= WallpaperFilenames.retainedRendersPerDisplay)
        }
        let newest = survivingTimestamps.map { WallpaperFilenames.dynamicName(displayID: 1, timestamp: $0) }
        #expect(listing.sorted() == newest.sorted())
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

    @Test func aSetDisplayKeepsTheStaticRendersOtherDesktopsPointAt() {
        let current = WallpaperFilenames.staticName(displayID: 1, timestamp: 300)
        let listing = [current, WallpaperFilenames.staticName(displayID: 1, timestamp: 100)]
        let removable = WallpaperFilenames.removableStaticFiles(
            in: listing, displayIDs: [1], keeping: [1: current], sweepLegacy: true
        )
        #expect(removable.isEmpty)
    }

    @Test func staticRendersPastTheLimitGoAndOtherFilesAreSpared() {
        let renders = (1 ... overTheLimit).map { WallpaperFilenames.staticName(displayID: 1, timestamp: $0) }
        let current = renders[overTheLimit - 1]
        let other = WallpaperFilenames.staticName(displayID: 2, timestamp: 1)
        let listing = renders + [other, "spreadpaper_wall_12_1.png", "notes.txt"]
        let removable = WallpaperFilenames.removableStaticFiles(
            in: listing, displayIDs: [1, 2], keeping: [1: current, 2: other], sweepLegacy: false
        )
        #expect(removable.sorted() == [
            WallpaperFilenames.staticName(displayID: 1, timestamp: 1),
            WallpaperFilenames.staticName(displayID: 1, timestamp: 2)
        ].sorted())
    }

    @Test func legacyStaticNamesGoOnlyWhenEveryDisplayWasSet() {
        let current = WallpaperFilenames.staticName(displayID: 1, timestamp: 1700000000000)
        let listing = [current, "spreadpaper_wall_LG ULTRAWIDE_1700000000000.png"]
        let spared = WallpaperFilenames.removableStaticFiles(
            in: listing, displayIDs: [1, 2], keeping: [1: current], sweepLegacy: false
        )
        #expect(spared.isEmpty)
        let swept = WallpaperFilenames.removableStaticFiles(
            in: listing, displayIDs: [1], keeping: [1: current], sweepLegacy: true
        )
        #expect(swept == ["spreadpaper_wall_LG ULTRAWIDE_1700000000000.png"])
    }

    @Test func repeatedStaticAppliesStayBounded() {
        var listing: [String] = []
        for timestamp in 1 ... applyCount {
            let current = WallpaperFilenames.staticName(displayID: 1, timestamp: timestamp)
            listing.append(current)
            let removable = WallpaperFilenames.removableStaticFiles(
                in: listing, displayIDs: [1], keeping: [1: current], sweepLegacy: true
            )
            #expect(!removable.contains(current))
            listing.removeAll { removable.contains($0) }
            #expect(listing.count <= WallpaperFilenames.retainedRendersPerDisplay)
        }
        let newest = survivingTimestamps.map { WallpaperFilenames.staticName(displayID: 1, timestamp: $0) }
        #expect(listing.sorted() == newest.sorted())
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

    /// Issue #137: a display that is gone owns renders no later apply can reach.
    /// Its newest stays, so a Space still resolves if that display comes back.
    @Test func aDepartedDisplayKeepsOnlyItsNewestStaticRender() {
        let current = WallpaperFilenames.staticName(displayID: 1, timestamp: 1700000000000)
        let old = WallpaperFilenames.staticName(displayID: 2, timestamp: 1699999999998)
        let older = WallpaperFilenames.staticName(displayID: 2, timestamp: 1699999999997)
        let newest = WallpaperFilenames.staticName(displayID: 2, timestamp: 1699999999999)
        let swept = WallpaperFilenames.removableStaticFiles(
            in: [current, newest, old, older], displayIDs: [1], keeping: [1: current], sweepLegacy: true
        )
        #expect(swept.sorted() == [old, older].sorted())
    }

    /// A sweep with no display to check against would find every render orphaned.
    @Test func noDisplayConnectedSweepsNothing() {
        let renders = (1 ... 3).map { WallpaperFilenames.staticName(displayID: 1, timestamp: 1700000000000 + $0) }
        let swept = WallpaperFilenames.removableStaticFiles(
            in: renders, displayIDs: [], keeping: [:], sweepLegacy: true
        )
        #expect(swept.isEmpty)
    }

    /// The same guard in a preset's own directory.
    @Test func noDisplayConnectedSweepsNoDynamicRenders() {
        let renders = (1 ... 3).map { WallpaperFilenames.dynamicName(displayID: 1, timestamp: 1700000000000 + $0) }
        let swept = WallpaperFilenames.removableDynamicFiles(
            in: renders, displayIDs: [], keeping: [:], sweepLegacy: true
        )
        #expect(swept.isEmpty)
    }

    /// A name the app did not write has no display, so the departed rule never claims it.
    @Test func onlyCurrentNamesCarryADisplayID() {
        #expect(WallpaperFilenames.staticDisplayID("spreadpaper_wall_7_1700000000000.png") == 7)
        #expect(WallpaperFilenames.staticDisplayID("spreadpaper_wall_LG ULTRAWIDE_1700000000000.png") == nil)
        #expect(WallpaperFilenames.staticDisplayID("notes.txt") == nil)
        #expect(WallpaperFilenames.staticDisplayID("spreadpaper_wall_4294967296_1700000000000.png") == nil)
        #expect(WallpaperFilenames.dynamicDisplayID("7_1700000000000.heic") == 7)
        #expect(WallpaperFilenames.dynamicDisplayID("LG ULTRAWIDE.heic") == nil)
        #expect(WallpaperFilenames.dynamicDisplayID("7_100.heic") == nil)
    }

    /// A failed apply spares a departed display's renders, as it spares a legacy name.
    @Test func aDepartedDisplaysStaticRendersStayWhileADisplayFailed() {
        let current = WallpaperFilenames.staticName(displayID: 1, timestamp: 1700000000000)
        let departed = WallpaperFilenames.staticName(displayID: 2, timestamp: 1699999999999)
        let spared = WallpaperFilenames.removableStaticFiles(
            in: [current, departed], displayIDs: [1], keeping: [1: current], sweepLegacy: false
        )
        #expect(spared.isEmpty)
    }

    /// Issue #137: the same gap inside a preset's own directory.
    @Test func aDepartedDisplayKeepsOnlyItsNewestDynamicRender() {
        let current = WallpaperFilenames.dynamicName(displayID: 1, timestamp: 1700000000000)
        let old = WallpaperFilenames.dynamicName(displayID: 2, timestamp: 1699999999998)
        let newest = WallpaperFilenames.dynamicName(displayID: 2, timestamp: 1699999999999)
        let swept = WallpaperFilenames.removableDynamicFiles(
            in: [current, newest, old], displayIDs: [1], keeping: [1: current], sweepLegacy: true
        )
        #expect(swept == [old])
    }

    /// Issue #137: a deleted preset leaves its dynamic folder behind.
    /// Only folders named like a preset id are offered up.
    @Test func dynamicFoldersOfGonePresetsAreRemovable() {
        let live = UUID()
        let gone = UUID()
        let removable = WallpaperFilenames.removableDynamicDirectories(
            in: [live.uuidString, gone.uuidString, "wallpapers", "notes.txt"], presetIds: [live]
        )
        #expect(removable == [gone.uuidString])
    }

    /// A folder written in lowercase is the same id, so its preset still claims it.
    @Test func dynamicFoldersMatchTheirPresetWhateverTheCasing() {
        let live = UUID()
        let removable = WallpaperFilenames.removableDynamicDirectories(
            in: [live.uuidString.lowercased()], presetIds: [live]
        )
        #expect(removable.isEmpty)
    }
}
