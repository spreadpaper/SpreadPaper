import Foundation
import Testing
@testable import SpreadPaper

/// Issue #129: the time menus' arithmetic holds without a view around them.
/// An hour, a minute, the half of a day and a stored time between
/// two steps all read here.
struct TimeFieldMathTests {
    /// A locale that writes the hour on a twelve hour clock.
    private static let twelveHour = Locale(identifier: "en_US")

    /// A locale that writes it on a twenty four hour clock.
    private static let twentyFourHour = Locale(identifier: "de_DE")

    /// A time saved before the menu's step existed.
    private static let offGrid = 6 * 60 + 47

    // MARK: - Wrapping

    @Test func everyCountWrapsIntoTheDayItLandsOn() {
        #expect(TimeFieldMath.wrapped(0) == 0)
        #expect(TimeFieldMath.wrapped(TimeFieldMath.minutesPerDay) == 0)
        #expect(TimeFieldMath.wrapped(-1) == TimeFieldMath.minutesPerDay - 1)
        #expect(TimeFieldMath.wrapped(-TimeFieldMath.minutesPerDay - 30) == TimeFieldMath.minutesPerDay - 30)
        #expect(TimeFieldMath.wrapped(3 * TimeFieldMath.minutesPerDay + 61) == 61)
    }

    // MARK: - The hour menu

    @Test func theHourMenuHoldsTheDayTheClockRunsThrough() {
        #expect(TimeFieldMath.hourOptions(namingHalf: false) == Array(0..<24))
        #expect(TimeFieldMath.hourOptions(namingHalf: true) == Array(0..<12))
    }

    @Test func eachMenuIsShortEnoughToReadAtAGlance() {
        for namingHalf in [true, false] {
            let hours = TimeFieldMath.hourOptions(namingHalf: namingHalf).count
            #expect(hours <= 24, "the hour menu offers \(hours) entries")
        }
        #expect(TimeFieldMath.minuteOptions(including: 0).count == 60 / TimeFieldMath.minuteStep)
        #expect(TimeFieldMath.minuteOptions(including: Self.offGrid).count == 60 / TimeFieldMath.minuteStep + 1)
    }

    @Test func theHourMenuOpensOnTheHourTheTimeSitsIn() {
        #expect(TimeFieldMath.hourOption(of: 0, namingHalf: false) == 0)
        #expect(TimeFieldMath.hourOption(of: 21 * 60 + 5, namingHalf: false) == 21)
        #expect(TimeFieldMath.hourOption(of: 0, namingHalf: true) == 0)
        #expect(TimeFieldMath.hourOption(of: 12 * 60, namingHalf: true) == 0)
        #expect(TimeFieldMath.hourOption(of: 21 * 60 + 5, namingHalf: true) == 9)
    }

    @Test func noonSplitsTheDayIntoItsTwoHalves() {
        #expect(!TimeFieldMath.isAfternoon(0))
        #expect(!TimeFieldMath.isAfternoon(11 * 60 + 59))
        #expect(TimeFieldMath.isAfternoon(12 * 60))
        #expect(TimeFieldMath.isAfternoon(TimeFieldMath.minutesPerDay - 1))
    }

    // MARK: - The minute menu

    @Test func theMinuteMenuCoversTheHourAtItsStep() {
        let offered = TimeFieldMath.minuteOptions(including: 0)
        #expect(offered == [0, 15, 30, 45])
        #expect(offered.allSatisfy { $0 % TimeFieldMath.minuteStep == 0 })
    }

    @Test func aMinuteOnTheStepAddsNothingToTheMenu() {
        for minute in stride(from: 0, to: 60, by: TimeFieldMath.minuteStep) {
            #expect(TimeFieldMath.minuteOptions(including: minute) == [0, 15, 30, 45])
        }
    }

    /// A schedule written before the step keeps its own minute.
    @Test func aStoredMinuteBetweenTwoStepsKeepsItsPlace() {
        let offered = TimeFieldMath.minuteOptions(including: Self.offGrid)
        #expect(offered == [0, 15, 30, 45, 47])
        #expect(offered.filter { $0 == 47 }.count == 1)
    }

    @Test func everyStoredMinuteOfTheDayIsOnOffer() {
        for minute in 0..<TimeFieldMath.minutesPerDay {
            #expect(TimeFieldMath.minuteOptions(including: minute).contains(minute % 60))
        }
    }

    // MARK: - Putting the menus back together

    @Test func theMenusNameBackEveryMinuteOfTheDay() {
        for namingHalf in [true, false] {
            for stored in 0..<TimeFieldMath.minutesPerDay {
                let rebuilt = TimeFieldMath.minutes(
                    hourOption: TimeFieldMath.hourOption(of: stored, namingHalf: namingHalf),
                    minute: stored % 60,
                    isAfternoon: TimeFieldMath.isAfternoon(stored),
                    namingHalf: namingHalf
                )
                #expect(rebuilt == stored, "a \(namingHalf ? "twelve" : "twenty four") hour clock lost \(stored)")
            }
        }
    }

    @Test func changingTheHalfOfTheDayMovesTwelveHours() {
        let morning = 9 * 60 + 5
        let afternoon = TimeFieldMath.minutes(
            hourOption: TimeFieldMath.hourOption(of: morning, namingHalf: true),
            minute: morning % 60,
            isAfternoon: true,
            namingHalf: true
        )
        #expect(afternoon == 21 * 60 + 5)
    }

    /// Reaching for another hour never rounds a minute the schedule already held.
    @Test func changingTheHourKeepsAMinuteOffTheStep() {
        let moved = TimeFieldMath.minutes(
            hourOption: 9,
            minute: Self.offGrid % 60,
            isAfternoon: false,
            namingHalf: false
        )
        #expect(moved == 9 * 60 + 47)
        #expect(TimeFieldMath.minuteOptions(including: moved).contains(47))
    }

    // MARK: - Locale

    @Test func aTwelveHourLocaleNamesTheHalfOfTheDay() {
        #expect(Self.twelveHour.hourCycle == .oneToTwelve)
        #expect(TimeFieldMath.namesHalfOfDay(Self.twelveHour))
        let text = TimeFieldMath.text(for: 21 * 60 + 5, locale: Self.twelveHour)
        #expect(text.contains("9:05"))
        #expect(text.localizedCaseInsensitiveContains("pm"))
    }

    @Test func aTwentyFourHourLocaleNamesNone() {
        #expect(Self.twentyFourHour.hourCycle == .zeroToTwentyThree)
        #expect(!TimeFieldMath.namesHalfOfDay(Self.twentyFourHour))
        let text = TimeFieldMath.text(for: 21 * 60 + 5, locale: Self.twentyFourHour)
        #expect(text.contains("21"))
        #expect(!text.localizedCaseInsensitiveContains("pm"))
        #expect(!text.localizedCaseInsensitiveContains("am"))
    }

    /// What the menus show side by side reads as the clock string does.
    @Test func theMenusSpellOutTheClockStringBetweenThem() {
        for locale in [Self.twelveHour, Self.twentyFourHour] {
            let namingHalf = TimeFieldMath.namesHalfOfDay(locale)
            for stored in stride(from: 0, to: TimeFieldMath.minutesPerDay, by: 13) {
                let hour = TimeVariant.hourString(
                    hour: TimeFieldMath.hourOption(of: stored, namingHalf: namingHalf), locale: locale
                )
                let minute = TimeVariant.minuteString(minute: stored % 60, locale: locale)
                let whole = TimeFieldMath.text(for: stored, locale: locale)
                #expect(whole.contains(hour + TimeVariant.clockSeparator(locale: locale) + minute))
                guard namingHalf else { continue }
                let half = TimeVariant.halfOfDayString(
                    isAfternoon: TimeFieldMath.isAfternoon(stored), locale: locale
                )
                #expect(whole.localizedCaseInsensitiveContains(half))
            }
        }
    }

    @Test func theSeparatorIsTheOneTheLocaleWrites() {
        for locale in [Self.twelveHour, Self.twentyFourHour, Locale(identifier: "en_GB")] {
            let mark = TimeVariant.clockSeparator(locale: locale)
            #expect(!mark.isEmpty)
            #expect(TimeVariant.clockString(hour: 10, minute: 30, locale: locale).contains(mark))
        }
    }

    /// Switching the clock setting changes the writing, never the stored value.
    @Test func theStoredMinuteSurvivesAChangeOfHourCycle() {
        for locale in [Self.twelveHour, Self.twentyFourHour] {
            #expect(TimeFieldMath.minuteOptions(including: Self.offGrid).contains(47))
            #expect(TimeFieldMath.text(for: Self.offGrid, locale: locale).contains("47"))
        }
        #expect(
            TimeFieldMath.text(for: Self.offGrid, locale: Self.twelveHour)
                != TimeFieldMath.text(for: Self.offGrid, locale: Self.twentyFourHour)
        )
    }

    @Test func theFieldWritesWhatTheScheduleWritesElsewhere() {
        for locale in [Self.twelveHour, Self.twentyFourHour] {
            let variant = TimeVariant(imageFilename: "a.jpg", hour: 21, minute: 5)
            #expect(TimeFieldMath.text(for: 21 * 60 + 5, locale: locale) == variant.timeString(locale: locale))
        }
    }
}
