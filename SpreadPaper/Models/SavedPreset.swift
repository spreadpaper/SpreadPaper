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
}
