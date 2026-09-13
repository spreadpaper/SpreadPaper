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
        referenceDate(hour: hour, minute: minute).formatted(clockStyle(locale).hour().minute())
    }

    /// The hour on its own, cut from the clock string so it reads there as here.
    /// Hour 24 wraps to midnight.
    nonisolated static func hourString(hour: Int, locale: Locale = .current) -> String {
        let written = clockString(hour: hour, minute: 0, locale: locale)
        guard let run = digitRuns(written).first else { return "" }
        return String(written[run])
    }

    /// The minute on its own, cut from the same clock string.
    nonisolated static func minuteString(minute: Int, locale: Locale = .current) -> String {
        let written = clockString(hour: 0, minute: minute, locale: locale)
        let runs = digitRuns(written)
        return runs.count > 1 ? String(written[runs[1]]) : ""
    }

    /// What the locale writes beside an hour to name its half of the day.
    /// Cut from the clock string, so a clock that names more than two
    /// halves names the one this hour falls in.
    nonisolated static func halfOfDayString(hour: Int, locale: Locale = .current) -> String {
        let written = clockString(hour: hour, minute: 0, locale: locale)
        let runs = digitRuns(written)
        guard let first = runs.first, let last = runs.last else { return "" }
        let around = written[..<first.lowerBound] + written[last.upperBound...]
        return around.trimmingCharacters(in: designatorEdge)
    }

    /// Whether the clock writes every hour twice a day, leaving the half to be
    /// named beside it. Read off the clock string, so the system's
    /// 24-Hour Time setting reaches it.
    nonisolated static func namesHalfOfDay(_ locale: Locale = .current) -> Bool {
        (0..<12).allSatisfy {
            hourString(hour: $0, locale: locale) == hourString(hour: $0 + 12, locale: locale)
        }
    }

    /// The mark the locale sets between an hour and a minute.
    /// A locale that writes none falls back to a colon.
    nonisolated static func clockSeparator(locale: Locale = .current) -> String {
        let written = clockString(hour: 10, minute: 30, locale: locale)
        let runs = digitRuns(written)
        guard runs.count > 1 else { return ":" }
        return String(written[runs[0].upperBound..<runs[1].lowerBound])
    }

    /// Marks a locale sets around a designator that are not part of it.
    nonisolated private static let designatorEdge = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "\u{200E}\u{200F}\u{2066}\u{2067}\u{2068}\u{2069}"))

    /// Where the digits sit in a written time, the hour's run first.
    nonisolated private static func digitRuns(_ written: String) -> [Range<String.Index>] {
        var runs: [Range<String.Index>] = []
        var start: String.Index?
        for index in written.indices {
            if written[index].isNumber {
                if start == nil { start = index }
            } else if let begin = start {
                runs.append(begin..<index)
                start = nil
            }
        }
        if let begin = start { runs.append(begin..<written.endIndex) }
        return runs
    }

    /// Style every clock string is written through, in the clock's own zone.
    nonisolated private static func clockStyle(_ locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: clockCalendar, timeZone: clockZone)
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
