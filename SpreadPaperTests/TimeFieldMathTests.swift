import Foundation
import Testing
@testable import SpreadPaper

/// Issue #129: the time field's arithmetic holds without a view around it.
/// Typed text, the locale's writing, wrapping and stepping all read here.
struct TimeFieldMathTests {
    /// A locale that writes the hour on a twelve hour clock.
    private static let twelveHour = Locale(identifier: "en_US")

    /// A locale that writes it on a twenty four hour clock.
    private static let twentyFourHour = Locale(identifier: "de_DE")

    // MARK: - Wrapping and stepping

    @Test func aStepPastTheEndOfTheDayLandsOnMidnight() {
        #expect(TimeFieldMath.stepped(23 * 60 + 59, by: TimeFieldMath.step) == 0)
    }

    @Test func aStepBackFromMidnightLandsOnTheLastMinute() {
        #expect(TimeFieldMath.stepped(0, by: -TimeFieldMath.step) == 23 * 60 + 59)
    }

    @Test func aCoarseStepWrapsTheSameWay() {
        #expect(TimeFieldMath.stepped(23 * 60 + 50, by: TimeFieldMath.coarseStep) == 5)
        #expect(TimeFieldMath.stepped(10, by: -TimeFieldMath.coarseStep) == 23 * 60 + 55)
    }

    @Test func everyCountWrapsIntoTheDayItLandsOn() {
        #expect(TimeFieldMath.wrapped(0) == 0)
        #expect(TimeFieldMath.wrapped(TimeFieldMath.minutesPerDay) == 0)
        #expect(TimeFieldMath.wrapped(-1) == TimeFieldMath.minutesPerDay - 1)
        #expect(TimeFieldMath.wrapped(-TimeFieldMath.minutesPerDay - 30) == TimeFieldMath.minutesPerDay - 30)
        #expect(TimeFieldMath.wrapped(3 * TimeFieldMath.minutesPerDay + 61) == 61)
    }

    @Test func steppingUpAndBackLeavesEveryMinuteWhereItWas() {
        for minute in 0..<TimeFieldMath.minutesPerDay {
            let moved = TimeFieldMath.stepped(minute, by: TimeFieldMath.step)
            #expect(TimeFieldMath.stepped(moved, by: -TimeFieldMath.step) == minute)
        }
    }

    // MARK: - Typed entry

    @Test func aTimeWithASeparatorReads() {
        #expect(TimeFieldMath.minutes(from: "9:05", locale: Self.twentyFourHour) == 545)
        #expect(TimeFieldMath.minutes(from: "09:05", locale: Self.twentyFourHour) == 545)
        #expect(TimeFieldMath.minutes(from: "9.05", locale: Self.twentyFourHour) == 545)
        #expect(TimeFieldMath.minutes(from: "9h05", locale: Self.twentyFourHour) == 545)
        #expect(TimeFieldMath.minutes(from: " 23:59 ", locale: Self.twentyFourHour) == 1439)
    }

    @Test func bareDigitsRead() {
        #expect(TimeFieldMath.minutes(from: "0905", locale: Self.twentyFourHour) == 545)
        #expect(TimeFieldMath.minutes(from: "905", locale: Self.twentyFourHour) == 545)
        #expect(TimeFieldMath.minutes(from: "9", locale: Self.twentyFourHour) == 540)
        #expect(TimeFieldMath.minutes(from: "09", locale: Self.twentyFourHour) == 540)
        #expect(TimeFieldMath.minutes(from: "0000", locale: Self.twentyFourHour) == 0)
    }

    @Test func aDesignatorMovesTheHourIntoTheAfternoon() {
        #expect(TimeFieldMath.minutes(from: "9:05 PM", locale: Self.twelveHour) == 21 * 60 + 5)
        #expect(TimeFieldMath.minutes(from: "9:05pm", locale: Self.twelveHour) == 21 * 60 + 5)
        #expect(TimeFieldMath.minutes(from: "9:05 AM", locale: Self.twelveHour) == 545)
        #expect(TimeFieldMath.minutes(from: "12:00 AM", locale: Self.twelveHour) == 0)
        #expect(TimeFieldMath.minutes(from: "12:30 PM", locale: Self.twelveHour) == 12 * 60 + 30)
        #expect(TimeFieldMath.minutes(from: "905pm", locale: Self.twelveHour) == 21 * 60 + 5)
    }

    @Test func nonsenseReadsAsNothingAtAll() {
        let rejected = ["", "   ", "abc", "25:00", "9:75", "12345", "9:5:5", "-1", "13:00 PM", ":", "::"]
        for entry in rejected {
            #expect(
                TimeFieldMath.minutes(from: entry, locale: Self.twelveHour) == nil,
                "\"\(entry)\" was read as a time"
            )
        }
    }

    // MARK: - Locale

    @Test func aTwelveHourLocaleWritesADesignator() {
        let text = TimeFieldMath.text(for: 21 * 60 + 5, locale: Self.twelveHour)
        #expect(TimeFieldMath.usesTwelveHourClock(Self.twelveHour))
        #expect(text.contains("9:05"))
        #expect(text.localizedCaseInsensitiveContains("pm"))
    }

    @Test func aTwentyFourHourLocaleWritesNone() {
        let text = TimeFieldMath.text(for: 21 * 60 + 5, locale: Self.twentyFourHour)
        #expect(!TimeFieldMath.usesTwelveHourClock(Self.twentyFourHour))
        #expect(text.contains("21"))
        #expect(!text.localizedCaseInsensitiveContains("pm"))
        #expect(!text.localizedCaseInsensitiveContains("am"))
    }

    @Test func theFieldWritesWhatTheScheduleWritesElsewhere() {
        for locale in [Self.twelveHour, Self.twentyFourHour] {
            let variant = TimeVariant(imageFilename: "a.jpg", hour: 21, minute: 5)
            #expect(TimeFieldMath.text(for: 21 * 60 + 5, locale: locale) == variant.timeString(locale: locale))
        }
    }

    @Test func everyMinuteTheFieldWritesReadsBackAsItself() {
        for locale in [Self.twelveHour, Self.twentyFourHour] {
            for minute in 0..<TimeFieldMath.minutesPerDay {
                let written = TimeFieldMath.text(for: minute, locale: locale)
                #expect(
                    TimeFieldMath.minutes(from: written, locale: locale) == minute,
                    "\"\(written)\" did not read back as minute \(minute)"
                )
            }
        }
    }

    @Test func theSizingSamplesCoverEveryHourTheClockWrites() {
        for locale in [Self.twelveHour, Self.twentyFourHour] {
            let samples = TimeFieldMath.widthSamples(locale: locale)
            #expect(samples.count == 24)
            #expect(Set(samples).count == 24)
        }
    }
}
