import Foundation

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
