import Foundation
import Testing
@testable import SpreadPaper

/// Issue #129: the stepper field round-trips the stored hour and minute without drift.
struct ScheduleClockTests {
    @Test func everyMinuteOfTheDayRoundTrips() {
        for minutes in 0..<1440 {
            let time = ScheduleClock.time(from: ScheduleClock.date(hour: minutes / 60, minute: minutes % 60))
            #expect(time.hour == minutes / 60)
            #expect(time.minute == minutes % 60)
        }
    }

    @Test func theBoundariesOfTheDayHold() {
        let midnight = ScheduleClock.time(from: ScheduleClock.date(hour: 0, minute: 0))
        #expect(midnight.hour == 0 && midnight.minute == 0)

        let lastMinute = ScheduleClock.time(from: ScheduleClock.date(hour: 23, minute: 59))
        #expect(lastMinute.hour == 23 && lastMinute.minute == 59)
    }

    @Test func timesOutsideADayClampIntoOne() {
        #expect(ScheduleClock.time(from: ScheduleClock.date(hour: 24, minute: 0)).hour == 23)
        let floored = ScheduleClock.time(from: ScheduleClock.date(hour: -1, minute: -5))
        #expect(floored.hour == 0 && floored.minute == 0)
        #expect(ScheduleClock.time(from: ScheduleClock.date(hour: 9, minute: 90)).minute == 59)
    }

    @Test func theCalendarNeverShiftsForDaylightSaving() {
        #expect(ScheduleClock.calendar.timeZone.secondsFromGMT() == 0)
        let day = ScheduleClock.date(hour: 0, minute: 0)
        #expect(ScheduleClock.date(hour: 23, minute: 59).timeIntervalSince(day) == 23 * 3600 + 59 * 60)
    }
}
