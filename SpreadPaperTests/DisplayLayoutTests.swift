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
