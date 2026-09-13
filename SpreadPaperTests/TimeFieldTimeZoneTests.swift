import Foundation
import Testing
@testable import SpreadPaper

/// Issue #129: a start time keeps the minute it was given wherever the machine sits.
/// The field carries minutes since midnight, and the only clock a
/// zone can reach is the one writing them out.
@Suite(.serialized)
struct TimeFieldTimeZoneTests {
    /// Zones that stress an offset, a half hour and a daylight saving rule.
    private static let zones = [
        "UTC",
        "Asia/Kolkata",
        "Australia/Lord_Howe",
        "America/New_York",
        "Pacific/Chatham"
    ]

    /// Locales on either hour cycle.
    private static let locales = [Locale(identifier: "en_US"), Locale(identifier: "de_DE")]

    /// Runs `body` with the process sitting in `identifier`, then puts the zone back.
    private func inZone(_ identifier: String, _ body: () throws -> Void) throws {
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        NSTimeZone.default = try #require(TimeZone(identifier: identifier))
        try body()
    }

    @Test func everyMinuteWritesTheSameWayInEveryZone() throws {
        var written: [String: [String]] = [:]
        for zone in Self.zones {
            try inZone(zone) {
                written[zone] = Self.locales.flatMap { locale in
                    stride(from: 0, to: TimeFieldMath.minutesPerDay, by: 7).map {
                        TimeFieldMath.text(for: $0, locale: locale)
                    }
                }
            }
        }
        let first = try #require(written[Self.zones[0]])
        for zone in Self.zones.dropFirst() {
            #expect(written[zone] == first, "\(zone) wrote the day differently")
        }
    }

    @Test func aClockStringNamesTheHourItWasGivenInEveryZone() throws {
        let locale = Locale(identifier: "en_GB")
        for zone in Self.zones {
            try inZone(zone) {
                for hour in 0..<24 {
                    for minute in [0, 29, 30, 31, 59] {
                        let written = TimeVariant.clockString(hour: hour, minute: minute, locale: locale)
                        let expected = String(format: "%02d:%02d", hour, minute)
                        #expect(written == expected, "\(zone) wrote \(hour):\(minute) as \(written)")
                    }
                }
            }
        }
    }

    @Test func theTimesOnOfferIgnoreTheZoneEntirely() throws {
        var results: [String: [Int]] = [:]
        for zone in Self.zones {
            try inZone(zone) {
                results[zone] = TimeFieldMath.hourOptions(namingHalf: false)
                    + TimeFieldMath.minuteOptions(including: 6 * 60 + 47)
            }
        }
        let first = try #require(results[Self.zones[0]])
        for zone in Self.zones.dropFirst() {
            #expect(results[zone] == first, "\(zone) offered different times")
        }
    }

    @Test func eachPartOfTheClockWritesTheSameWayInEveryZone() throws {
        var written: [String: [String]] = [:]
        for zone in Self.zones {
            try inZone(zone) {
                written[zone] = Self.locales.flatMap { locale in
                    (0..<24).map { TimeVariant.hourString(hour: $0, locale: locale) }
                        + (0..<60).map { TimeVariant.minuteString(minute: $0, locale: locale) }
                        + (0..<24).map { TimeVariant.halfOfDayString(hour: $0, locale: locale) }
                }
            }
        }
        let first = try #require(written[Self.zones[0]])
        for zone in Self.zones.dropFirst() {
            #expect(written[zone] == first, "\(zone) wrote the clock's parts differently")
        }
    }

    @Test func aScheduleEntrySentenceNamesTheSameTimeInEveryZone() throws {
        let locale = Locale(identifier: "en_GB")
        var sentences: [String: String] = [:]
        for zone in Self.zones {
            try inZone(zone) {
                sentences[zone] = ScheduleEntryText.handover(
                    start: 23 * 60 + 30, next: 6 * 60 + 45, isOnly: false, locale: locale
                )
            }
        }
        for zone in Self.zones {
            #expect(sentences[zone] == "Shows until 06:45 tomorrow.", "\(zone) drifted")
        }
    }
}
