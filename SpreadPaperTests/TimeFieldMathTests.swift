import Foundation
import Testing
@testable import SpreadPaper

/// Issue #129: the time menu's arithmetic holds without a view around it.
/// The day's grid, a stored time between two of its steps and the
/// locale's writing all read here.
struct TimeFieldMathTests {
    /// A locale that writes the hour on a twelve hour clock.
    private static let twelveHour = Locale(identifier: "en_US")

    /// A locale that writes it on a twenty four hour clock.
    private static let twentyFourHour = Locale(identifier: "de_DE")

    // MARK: - Wrapping

    @Test func everyCountWrapsIntoTheDayItLandsOn() {
        #expect(TimeFieldMath.wrapped(0) == 0)
        #expect(TimeFieldMath.wrapped(TimeFieldMath.minutesPerDay) == 0)
        #expect(TimeFieldMath.wrapped(-1) == TimeFieldMath.minutesPerDay - 1)
        #expect(TimeFieldMath.wrapped(-TimeFieldMath.minutesPerDay - 30) == TimeFieldMath.minutesPerDay - 30)
        #expect(TimeFieldMath.wrapped(3 * TimeFieldMath.minutesPerDay + 61) == 61)
    }

    // MARK: - The times on offer

    @Test func theMenuCoversTheWholeDayAtItsIncrement() {
        let offered = TimeFieldMath.offered(including: 0)
        #expect(offered.count == TimeFieldMath.minutesPerDay / TimeFieldMath.increment)
        #expect(offered.first == 0)
        #expect(offered.last == TimeFieldMath.minutesPerDay - TimeFieldMath.increment)
        #expect(offered == offered.sorted())
        #expect(offered.allSatisfy { $0 % TimeFieldMath.increment == 0 })
    }

    @Test func aTimeOnTheGridAddsNothingToTheMenu() {
        for minute in stride(from: 0, to: TimeFieldMath.minutesPerDay, by: TimeFieldMath.increment) {
            #expect(TimeFieldMath.offered(including: minute).count == 96)
        }
    }

    /// A schedule written before the grid keeps its own minute.
    @Test func aStoredTimeBetweenTwoStepsKeepsItsPlace() {
        let stored = 6 * 60 + 47
        let offered = TimeFieldMath.offered(including: stored)
        #expect(offered.count == 97)
        #expect(offered.filter { $0 == stored }.count == 1)
        #expect(offered == offered.sorted())
        #expect(offered[offered.firstIndex(of: stored)! - 1] == 6 * 60 + 45)
        #expect(offered[offered.firstIndex(of: stored)! + 1] == 7 * 60)
    }

    @Test func everyStoredMinuteOfTheDayIsOnOffer() {
        for minute in 0..<TimeFieldMath.minutesPerDay {
            #expect(TimeFieldMath.offered(including: minute).contains(minute))
        }
    }

    // MARK: - Locale

    @Test func aTwelveHourLocaleWritesADesignator() {
        let text = TimeFieldMath.text(for: 21 * 60 + 5, locale: Self.twelveHour)
        #expect(Self.twelveHour.hourCycle == .oneToTwelve)
        #expect(text.contains("9:05"))
        #expect(text.localizedCaseInsensitiveContains("pm"))
    }

    @Test func aTwentyFourHourLocaleWritesNone() {
        let text = TimeFieldMath.text(for: 21 * 60 + 5, locale: Self.twentyFourHour)
        #expect(Self.twentyFourHour.hourCycle == .zeroToTwentyThree)
        #expect(text.contains("21"))
        #expect(!text.localizedCaseInsensitiveContains("pm"))
        #expect(!text.localizedCaseInsensitiveContains("am"))
    }

    /// Switching the clock setting changes the writing, never the stored value.
    @Test func theStoredMinuteSurvivesAChangeOfHourCycle() {
        let stored = 6 * 60 + 47
        for locale in [Self.twelveHour, Self.twentyFourHour] {
            #expect(TimeFieldMath.offered(including: stored).contains(stored))
            #expect(TimeFieldMath.text(for: stored, locale: locale).contains("47"))
        }
        #expect(
            TimeFieldMath.text(for: stored, locale: Self.twelveHour)
                != TimeFieldMath.text(for: stored, locale: Self.twentyFourHour)
        )
    }

    @Test func theFieldWritesWhatTheScheduleWritesElsewhere() {
        for locale in [Self.twelveHour, Self.twentyFourHour] {
            let variant = TimeVariant(imageFilename: "a.jpg", hour: 21, minute: 5)
            #expect(TimeFieldMath.text(for: 21 * 60 + 5, locale: locale) == variant.timeString(locale: locale))
        }
    }
}
