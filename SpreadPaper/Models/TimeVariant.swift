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

    /// Start time in the user's locale, honouring the 24-hour setting.
    var timeString: String {
        timeString(locale: .current)
    }

    /// Start time formatted for an explicit locale.
    /// Lets tests pin the output.
    func timeString(locale: Locale) -> String {
        Self.clockString(hour: hour, minute: minute, locale: locale)
    }

    /// Formats a wall-clock time the way the locale writes it.
    /// Hour 24 wraps to midnight.
    static func clockString(hour: Int, minute: Int, locale: Locale = .current) -> String {
        referenceDate(hour: hour, minute: minute)
            .formatted(Date.FormatStyle(locale: locale).hour().minute())
    }

    /// Formats a whole hour the way the locale writes it, for axis labels.
    /// Reads `6 AM` or `06` depending on the hour cycle.
    static func hourString(hour: Int, locale: Locale = .current) -> String {
        referenceDate(hour: hour, minute: 0)
            .formatted(Date.FormatStyle(locale: locale).hour())
    }

    /// Fixed calendar day carrying only the wall-clock time.
    /// Hour 24 wraps to midnight.
    private static func referenceDate(hour: Int, minute: Int) -> Date {
        DateComponents(calendar: .current, year: 2000, month: 1, day: 1, hour: hour % 24, minute: minute).date ?? .now
    }
}
