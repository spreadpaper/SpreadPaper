import Foundation
import Testing
@testable import SpreadPaper

/// Issue #85: schedule times must follow the locale's hour cycle, not a hardcoded 12-hour pattern.
struct TimeVariantTests {
    private let sixThirty = TimeVariant(imageFilename: "a.png", hour: 6, minute: 30)

    // ICU separates the meridiem with a narrow no-break space (U+202F).
    @Test func twelveHourLocaleShowsMeridiem() {
        #expect(sixThirty.timeString(locale: Locale(identifier: "en_US")) == "6:30\u{202F}AM")
    }

    @Test func twentyFourHourLocalePadsTheHour() {
        #expect(sixThirty.timeString(locale: Locale(identifier: "nl_NL")) == "06:30")
    }

    @Test func midnightAxisLabelFollowsLocale() {
        #expect(TimeVariant.clockString(hour: 0, minute: 0, locale: Locale(identifier: "en_US")) == "12:00\u{202F}AM")
        #expect(TimeVariant.clockString(hour: 0, minute: 0, locale: Locale(identifier: "nl_NL")) == "00:00")
    }

    @Test func hourTwentyFourWrapsToMidnight() {
        let en = Locale(identifier: "en_US")
        #expect(TimeVariant.clockString(hour: 24, minute: 0, locale: en) == TimeVariant.clockString(hour: 0, minute: 0, locale: en))
    }
}
