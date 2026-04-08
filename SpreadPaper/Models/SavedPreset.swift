import Foundation

struct SavedPreset: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var imageFilename: String
    var offsetX: CGFloat
    var offsetY: CGFloat
    var scale: CGFloat
    var previewScale: CGFloat
    var isFlipped: Bool
    // Dynamic desktop support
    var isDynamic: Bool = false
    var timeVariants: [TimeVariant] = []

    /// Computed from isDynamic and timeVariants for display
    var wallpaperType: String {
        if isDynamic && timeVariants.count == 2 &&
           timeVariants.contains(where: { $0.hour == 12 && $0.minute == 0 }) &&
           timeVariants.contains(where: { $0.hour == 0 && $0.minute == 0 }) {
            return "Light/Dark"
        } else if isDynamic {
            return "Dynamic"
        }
        return "Static"
    }
}
