import Foundation
import Testing
@testable import SpreadPaper

/// Issue #85: schedule times follow the locale's hour cycle.
struct TimeVariantTests {
    private let sixThirty = TimeVariant(imageFilename: "a.png", hour: 6, minute: 30)
    private let enUS = Locale(identifier: "en_US")
    private let nlNL = Locale(identifier: "nl_NL")

    // ICU separates the meridiem with a narrow no-break space (U+202F).
    @Test func twelveHourLocaleShowsMeridiem() {
        #expect(sixThirty.timeString(locale: enUS) == "6:30\u{202F}AM")
    }

    @Test func twentyFourHourLocalePadsTheHour() {
        #expect(sixThirty.timeString(locale: nlNL) == "06:30")
    }

    // The System Settings 24-hour toggle surfaces as an hour-cycle override on the locale.
    @Test func twentyFourHourToggleOverridesTwelveHourLocale() {
        var components = Locale.Components(identifier: "en_US")
        components.hourCycle = .zeroToTwentyThree
        #expect(sixThirty.timeString(locale: Locale(components: components)) == "06:30")
    }

    @Test func axisLabelsFollowLocale() {
        #expect(TimeVariant.hourString(hour: 0, locale: enUS) == "12\u{202F}AM")
        #expect(TimeVariant.hourString(hour: 6, locale: enUS) == "6\u{202F}AM")
        #expect(TimeVariant.hourString(hour: 0, locale: nlNL) == "00")
        #expect(TimeVariant.hourString(hour: 18, locale: nlNL) == "18")
    }

    @Test func hourTwentyFourWrapsToMidnight() {
        #expect(TimeVariant.hourString(hour: 24, locale: enUS) == TimeVariant.hourString(hour: 0, locale: enUS))
        #expect(TimeVariant.clockString(hour: 24, minute: 0, locale: nlNL) == "00:00")
    }
}
