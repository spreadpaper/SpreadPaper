import AppKit
import Foundation
import Testing
@testable import SpreadPaper

/// Issue #129: the entry states what follows it instead of offering an end time.
struct ScheduleEntryTextTests {
    /// Fixed 24-hour locale, so the expected times do not move with the machine.
    private let locale = Locale(identifier: "en_GB")

    @Test func aMiddleEntryNamesTheImageAfterIt() {
        #expect(
            ScheduleEntryText.handover(start: 12 * 60, next: 15 * 60, isOnly: false, locale: locale)
                == "Shows until the next image at 15:00."
        )
    }

    @Test func theLastEntryOfTheDayWrapsPastMidnight() {
        #expect(
            ScheduleEntryText.handover(start: 23 * 60, next: 6 * 60, isOnly: false, locale: locale)
                == "Shows until the first image at 06:00 tomorrow."
        )
    }

    /// Two entries can share a minute, and the second still starts today.
    @Test func anEqualStartBelongsToTheSameDay() {
        #expect(
            ScheduleEntryText.handover(start: 12 * 60, next: 12 * 60, isOnly: false, locale: locale)
                == "Shows until the next image at 12:00."
        )
    }

    @Test func aSingleEntryRunsTheWholeDay() {
        #expect(
            ScheduleEntryText.handover(start: 7 * 60, next: 7 * 60, isOnly: true, locale: locale)
                == "Shows all day as the only image in the schedule."
        )
    }

    @Test func midnightAndTheMinuteBeforeItReadAsTimes() {
        #expect(
            ScheduleEntryText.handover(start: 23 * 60 + 59, next: 0, isOnly: false, locale: locale)
                == "Shows until the first image at 00:00 tomorrow."
        )
        #expect(
            ScheduleEntryText.handover(start: 0, next: 23 * 60 + 59, isOnly: false, locale: locale)
                == "Shows until the next image at 23:59."
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

    @Test func everySentenceFitsTheDialogOnOneLine() {
        let sentences = [
            ScheduleEntryText.handover(start: 12 * 60, next: 15 * 60, isOnly: false, locale: locale),
            ScheduleEntryText.handover(start: 23 * 60, next: 6 * 60, isOnly: false, locale: locale),
            ScheduleEntryText.handover(start: 7 * 60, next: 7 * 60, isOnly: true, locale: locale)
        ]
        let font = NSFont.systemFont(ofSize: 12)
        for sentence in sentences {
            let width = NSAttributedString(string: sentence, attributes: [.font: font]).size().width
            #expect(width <= 380, "\"\(sentence)\" takes \(Int(width))pt of the dialog's 380pt, so it wraps")
        }
    }
}
