import CoreGraphics
import Testing
@testable import SpreadPaper

/// Issue #118: the hero panels are windows onto one image, not three copies of it.
struct HeroSpreadTests {
    /// Hero height in points, the 260 pt header less its top and bottom insets.
    private static let height: CGFloat = 170

    /// Two lengths in points that agree to well under a pixel.
    private static func isClose(_ a: CGFloat, _ b: CGFloat) -> Bool {
        abs(a - b) < 0.0001
    }

    @Test func panelsTileTheSpreadLeftToRight() {
        let layout = HeroSpread(height: Self.height)
        #expect(layout.left.minX == 0)
        #expect(Self.isClose(layout.main.minX, layout.left.maxX + HeroSpread.gap))
        #expect(Self.isClose(layout.right.minX, layout.main.maxX + HeroSpread.gap))
        #expect(Self.isClose(layout.right.maxX, layout.spread.width))
    }

    @Test func theGapsBelongToTheSpread() {
        let layout = HeroSpread(height: Self.height)
        let panels = layout.left.width + layout.main.width + layout.right.width
        #expect(Self.isClose(layout.spread.width - panels, HeroSpread.gap * 2))
    }

    @Test func sidePanelsAreShorterAndCentredOnTheMainOne() {
        let layout = HeroSpread(height: Self.height)
        #expect(layout.main.height == Self.height)
        #expect(layout.left.height < layout.main.height)
        #expect(layout.left.height == layout.right.height)
        #expect(Self.isClose(layout.left.midY, layout.main.midY))
        #expect(Self.isClose(layout.right.midY, layout.main.midY))
    }

    @Test func everyPanelKeepsTheMonitorAspectRatio() {
        let layout = HeroSpread(height: Self.height)
        for panel in [layout.left, layout.main, layout.right] {
            #expect(Self.isClose(panel.width / panel.height, HeroSpread.aspectRatio))
        }
    }

    @Test func eachPositionSlicesItsOwnPartOfOneImage() {
        let layout = HeroSpread(height: Self.height)
        let slices = MonitorPosition.allCases.map { layout.slice($0) }
        #expect(slices.allSatisfy { $0.spread == layout.spread })
        #expect(slices.map(\.frame) == [layout.left, layout.main, layout.right])
    }
}
