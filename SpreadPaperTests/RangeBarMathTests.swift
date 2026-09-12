import Foundation
import Testing
@testable import SpreadPaper

/// Issue #81: the time bar snaps in its value math, so drags are checked without a view.
struct RangeBarMathTests {
    @Test func clampsBelowStartOfDay() {
        #expect(RangeBarMath.minutes(for: -0.2) == 0)
        #expect(RangeBarMath.fraction(atX: -40, trackWidth: 200) == 0)
        #expect(RangeBarMath.fraction(0, steppedBy: -1) == 0)
    }

    @Test func clampsEndOfDayToLastMark() {
        let last = RangeBarMath.fraction(forMinutes: 1430)
        #expect(RangeBarMath.minutes(for: 1.0) == 1430)
        #expect(RangeBarMath.minutes(for: 1.7) == 1430)
        #expect(RangeBarMath.fraction(atX: 500, trackWidth: 200) == last)
        #expect(RangeBarMath.fraction(last, steppedBy: 1) == last)
    }

    @Test func snapsToTenMinuteMarks() {
        #expect(RangeBarMath.minutes(for: RangeBarMath.fraction(forMinutes: 364)) == 360)
        #expect(RangeBarMath.minutes(for: RangeBarMath.fraction(forMinutes: 366)) == 370)
        #expect(RangeBarMath.fraction(atX: 51, trackWidth: 200) == RangeBarMath.fraction(forMinutes: 370))
    }

    @Test func midTrackIsNoon() {
        #expect(RangeBarMath.fraction(atX: 100, trackWidth: 200) == 0.5)
        #expect(RangeBarMath.minutes(for: 0.5) == 720)
    }

    @Test func stepsMoveTenMinutes() {
        #expect(RangeBarMath.fraction(0.5, steppedBy: 1) == RangeBarMath.fraction(forMinutes: 730))
        #expect(RangeBarMath.fraction(0.5, steppedBy: -2) == RangeBarMath.fraction(forMinutes: 700))
    }

    @Test func everyMarkRoundTripsExactly() {
        for minutes in stride(from: 0, through: 1430, by: 10) {
            #expect(RangeBarMath.minutes(for: RangeBarMath.fraction(forMinutes: minutes)) == minutes)
        }
    }

    @Test func degenerateInputIsSafe() {
        #expect(RangeBarMath.fraction(atX: 10, trackWidth: 0) == 0)
        #expect(RangeBarMath.minutes(for: .nan) == 0)
        #expect(RangeBarMath.minutes(for: .infinity) == 0)
    }
}
