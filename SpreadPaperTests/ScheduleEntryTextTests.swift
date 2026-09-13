import Foundation
import Testing
@testable import SpreadPaper

/// Issue #129: the entry reads out its own window instead of offering an end field.
struct ScheduleEntryTextTests {
    /// Fixed 24-hour locale, so the expected times do not move with the machine.
    private let locale = Locale(identifier: "en_GB")

    @Test func aMiddleEntryReadsOutWhenItEnds() {
        #expect(
            ScheduleEntryText.handover(start: 12 * 60, next: 15 * 60, isOnly: false, locale: locale)
                == "Shows until 15:00."
        )
    }

    @Test func theLastEntryOfTheDayWrapsPastMidnight() {
        #expect(
            ScheduleEntryText.handover(start: 23 * 60, next: 6 * 60, isOnly: false, locale: locale)
                == "Shows until 06:00 tomorrow."
        )
    }

    /// An entry the next one lands on holds the screen for no time at all.
    @Test func anEntryReplacedOnItsOwnMinuteSaysSo() {
        #expect(
            ScheduleEntryText.handover(start: 12 * 60, next: 12 * 60, isOnly: false, locale: locale)
                == "Never shows: the next starts then."
        )
        #expect(
            ScheduleEntryText.handover(start: 0, next: 0, isOnly: false, locale: locale)
                == "Never shows: the next starts then."
        )
    }

    /// One minute either side of a shared start still reads as a real window.
    @Test func aMinuteEitherSideOfAnEqualStartReadsAsAWindow() {
        #expect(
            ScheduleEntryText.handover(start: 12 * 60, next: 12 * 60 + 1, isOnly: false, locale: locale)
                == "Shows until 12:01."
        )
        #expect(
            ScheduleEntryText.handover(start: 12 * 60, next: 12 * 60 - 1, isOnly: false, locale: locale)
                == "Shows until 11:59 tomorrow."
        )
    }

    /// The only image keeps its own sentence even when the next start matches it.
    @Test func theOnlyImageIgnoresAnEqualNextStart() {
        #expect(
            ScheduleEntryText.handover(start: 12 * 60, next: 12 * 60, isOnly: true, locale: locale)
                == "Shows all day as the only image."
        )
    }

    @Test func aSingleEntryRunsTheWholeDay() {
        #expect(
            ScheduleEntryText.handover(start: 7 * 60, next: 7 * 60, isOnly: true, locale: locale)
                == "Shows all day as the only image."
        )
    }

    @Test func midnightAndTheMinuteBeforeItReadAsTimes() {
        #expect(
            ScheduleEntryText.handover(start: 23 * 60 + 59, next: 0, isOnly: false, locale: locale)
                == "Shows until 00:00 tomorrow."
        )
        #expect(
            ScheduleEntryText.handover(start: 0, next: 23 * 60 + 59, isOnly: false, locale: locale)
                == "Shows until 23:59."
        )
    }

    @Test func placeInTheScheduleReadsAsWords() {
        #expect(ScheduleEntryText.position(index: 2, count: 4) == "Third of four")
        #expect(ScheduleEntryText.position(index: 0, count: 2) == "First of two")
        #expect(ScheduleEntryText.position(index: 15, count: 16) == "Sixteenth of sixteen")
        #expect(ScheduleEntryText.position(index: 0, count: 1) == "Only image")
    }

    @Test func placeBeyondTheSpelledRangeFallsBackToDigits() {
        #expect(ScheduleEntryText.position(index: 16, count: 17) == "17 of 17")
    }
}
