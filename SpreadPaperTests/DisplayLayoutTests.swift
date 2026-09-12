import CoreGraphics
import Testing
@testable import SpreadPaper

/// Issue #40: bezel compensation shifts each display's crop by the gaps between monitors.
struct DisplayLayoutTests {
    private let w: CGFloat = 1440
    private let h: CGFloat = 2560

    @Test func zeroGapLeavesFramesUntouched() {
        let frames = [CGRect(x: 0, y: 0, width: w, height: h), CGRect(x: w, y: 0, width: w, height: h)]
        #expect(DisplayLayout.spacedFrames(frames, gap: 0) == frames)
    }

    @Test func singleDisplayIsNeverShifted() {
        let frames = [CGRect(x: 0, y: 0, width: w, height: h)]
        #expect(DisplayLayout.spacedFrames(frames, gap: 73) == frames)
    }

    @Test func horizontalRowShiftsEachDisplayByAccumulatedGaps() {
        let frames = [
            CGRect(x: 0, y: 0, width: w, height: h),
            CGRect(x: w, y: 0, width: w, height: h),
            CGRect(x: 2 * w, y: 0, width: w, height: h),
        ]
        let spaced = DisplayLayout.spacedFrames(frames, gap: 73)
        #expect(spaced[0].minX == 0)
        #expect(spaced[1].minX == w + 73)
        #expect(spaced[2].minX == 2 * w + 146)
        #expect(spaced.allSatisfy { $0.minY == 0 })
        let canvas = spaced.reduce(CGRect.null) { $0.union($1) }
        #expect(canvas.width == 3 * w + 146)
    }

    @Test func verticalStackShiftsUpwards() {
        let frames = [
            CGRect(x: 0, y: 0, width: h, height: w),
            CGRect(x: 0, y: w, width: h, height: w),
        ]
        let spaced = DisplayLayout.spacedFrames(frames, gap: 20)
        #expect(spaced[0].minY == 0)
        #expect(spaced[1].minY == w + 20)
        #expect(spaced.allSatisfy { $0.minX == 0 })
    }

    @Test func orderIsPreservedRegardlessOfInputOrder() {
        let frames = [
            CGRect(x: w, y: 0, width: w, height: h),
            CGRect(x: 0, y: 0, width: w, height: h),
        ]
        let spaced = DisplayLayout.spacedFrames(frames, gap: 10)
        #expect(spaced[0].minX == w + 10)
        #expect(spaced[1].minX == 0)
    }

    // Issue #58: per-display bezel widths.

    /// Bezel with the given edge widths; vertical defaults to none.
    private func bezel(_ horizontal: CGFloat, _ vertical: CGFloat = 0) -> Bezel {
        Bezel(horizontal: horizontal, vertical: vertical)
    }

    @Test func gapBetweenTwoDisplaysIsTheSumOfTheirBezels() {
        let frames = [CGRect(x: 0, y: 0, width: w, height: h), CGRect(x: w, y: 0, width: w, height: h)]
        let spaced = DisplayLayout.spacedFrames(frames, bezels: [bezel(10), bezel(30)])
        #expect(spaced[0].minX == 0)
        #expect(spaced[1].minX == w + 40)
    }

    @Test func rowOfThreeAccumulatesEachPairsBezels() {
        let frames = [
            CGRect(x: 0, y: 0, width: w, height: h),
            CGRect(x: w, y: 0, width: w, height: h),
            CGRect(x: 2 * w, y: 0, width: w, height: h),
        ]
        let spaced = DisplayLayout.spacedFrames(frames, bezels: [bezel(10), bezel(20), bezel(30)])
        #expect(spaced[1].minX == w + 30)
        #expect(spaced[2].minX == 2 * w + 30 + 50)
    }

    @Test func verticalBezelsOnlyAffectStackedDisplays() {
        let sideBySide = [CGRect(x: 0, y: 0, width: w, height: h), CGRect(x: w, y: 0, width: w, height: h)]
        let stacked = [CGRect(x: 0, y: 0, width: h, height: w), CGRect(x: 0, y: w, width: h, height: w)]
        let bezels = [bezel(0, 15), bezel(0, 25)]
        #expect(DisplayLayout.spacedFrames(sideBySide, bezels: bezels) == sideBySide)
        let spacedStack = DisplayLayout.spacedFrames(stacked, bezels: bezels)
        #expect(spacedStack[1].minY == w + 40)
        #expect(spacedStack[1].minX == 0)
    }

    @Test func uniformGapMatchesHalfBezelPerSide() {
        let frames = [CGRect(x: 0, y: 0, width: w, height: h), CGRect(x: w, y: 0, width: w, height: h)]
        let halves = [Bezel(horizontal: 25, vertical: 25), Bezel(horizontal: 25, vertical: 25)]
        #expect(DisplayLayout.spacedFrames(frames, gap: 50) == DisplayLayout.spacedFrames(frames, bezels: halves))
    }

    @Test func mismatchedBezelCountLeavesFramesUntouched() {
        let frames = [CGRect(x: 0, y: 0, width: w, height: h), CGRect(x: w, y: 0, width: w, height: h)]
        #expect(DisplayLayout.spacedFrames(frames, bezels: [bezel(10)]) == frames)
    }

    @Test func stackedPairLeftOfOneDisplayCountsAsOneColumn() {
        let frames = [
            CGRect(x: 0, y: 0, width: w, height: h / 2),
            CGRect(x: 0, y: h / 2, width: w, height: h / 2),
            CGRect(x: w, y: 0, width: w, height: h),
        ]
        let spaced = DisplayLayout.spacedFrames(frames, gap: 30)
        #expect(spaced[2].minX == w + 30)
        #expect(spaced[1].minY == h / 2 + 30)
    }
}
