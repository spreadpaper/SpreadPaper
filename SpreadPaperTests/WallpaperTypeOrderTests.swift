import Foundation
import Testing
@testable import SpreadPaper

/// The creation modal offers the kinds in its own order and opens on the first of them.
struct WallpaperTypeOrderTests {
    @Test func theModalOffersDynamicFirstAndStaticLast() {
        #expect(WallpaperType.creationOrder == [.dynamic, .appearance, .standard])
    }

    @Test func theModalOpensOnTheKindItListsFirst() {
        #expect(WallpaperType.creationDefault == WallpaperType.creationOrder.first)
        #expect(WallpaperType.creationDefault == .dynamic)
    }

    @Test func everyKindIsOfferedExactlyOnce() {
        let offered = WallpaperType.creationOrder
        #expect(Set(offered) == Set(WallpaperType.allCases))
        #expect(offered.count == WallpaperType.allCases.count)
    }

    @Test func theStoredNamesSurviveTheOfferedOrder() {
        #expect(WallpaperType.standard.rawValue == "Static")
        #expect(WallpaperType.appearance.rawValue == "Light/Dark")
        #expect(WallpaperType.dynamic.rawValue == "Dynamic")
    }
}
