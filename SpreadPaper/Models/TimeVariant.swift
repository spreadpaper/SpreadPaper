import Foundation

/// One image in a dynamic preset with its start time and its own placement.
struct TimeVariant: Identifiable, Codable, Hashable {
    var id = UUID()
    var imageFilename: String
    var hour: Int
    var minute: Int
    var name: String = ""

    // Per-variant position (each image has its own crop/position)
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var scale: CGFloat = 1.0
    var previewScale: CGFloat = 1.0
    var isFlipped: Bool = false

    var dayFraction: Double {
        Double(hour) / 24.0 + Double(minute) / 1440.0
    }

    /// Start time as the given locale writes it, its 24-hour setting honoured.
    /// The caller passes the locale so a change of that setting reaches
    /// the screen without a relaunch.
    func timeString(locale: Locale) -> String {
        Self.clockString(hour: hour, minute: minute, locale: locale)
    }

    /// Formats a wall-clock time the way the locale writes it.
    /// Hour 24 wraps to midnight.
    nonisolated static func clockString(hour: Int, minute: Int, locale: Locale = .current) -> String {
        referenceDate(hour: hour, minute: minute)
            .formatted(
                Date.FormatStyle(locale: locale, calendar: clockCalendar, timeZone: clockZone)
                    .hour().minute()
            )
    }

    /// Zone a clock string is both built and written in, so the machine's
    /// own zone cannot move an hour it was never given.
    nonisolated private static let clockZone = TimeZone.gmt

    /// Calendar carrying that zone.
    nonisolated private static let clockCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = clockZone
        return calendar
    }()

    /// Instant standing for a wall-clock time, counted off the reference date.
    /// Hour 24 wraps to midnight.
    nonisolated private static func referenceDate(hour: Int, minute: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: Double((hour % 24) * 3600 + minute * 60))
    }
}
