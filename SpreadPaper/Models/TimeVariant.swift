import Foundation

struct TimeVariant: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Filename of the stored image (UUID-based, in app support dir)
    var imageFilename: String
    /// Hour of day (0-23)
    var hour: Int
    /// Minute (0-59)
    var minute: Int
    /// User-editable name (defaults to auto-generated phase name if empty)
    var name: String = ""

    /// Fraction of day (0.0–1.0) for sorting and display
    var dayFraction: Double {
        Double(hour) / 24.0 + Double(minute) / 1440.0
    }

    /// Display string like "8:00 AM"
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}
