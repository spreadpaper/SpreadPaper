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
    /// Persisted flag distinguishing Light/Dark presets from time-of-day Dynamic ones.
    /// Older presets without this key are migrated on load by inferring from `timeVariants`.
    var isAppearanceBased: Bool = false

    var wallpaperType: String {
        if isAppearanceBased { return "Light/Dark" }
        if isDynamic { return "Dynamic" }
        return "Static"
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, imageFilename, offsetX, offsetY, scale, previewScale, isFlipped
        case isDynamic, timeVariants, isAppearanceBased
    }

    init(
        id: UUID = UUID(),
        name: String,
        imageFilename: String,
        offsetX: CGFloat,
        offsetY: CGFloat,
        scale: CGFloat,
        previewScale: CGFloat,
        isFlipped: Bool,
        isDynamic: Bool = false,
        timeVariants: [TimeVariant] = [],
        isAppearanceBased: Bool = false
    ) {
        self.id = id
        self.name = name
        self.imageFilename = imageFilename
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
        self.previewScale = previewScale
        self.isFlipped = isFlipped
        self.isDynamic = isDynamic
        self.timeVariants = timeVariants
        self.isAppearanceBased = isAppearanceBased
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        imageFilename = try c.decode(String.self, forKey: .imageFilename)
        offsetX = try c.decode(CGFloat.self, forKey: .offsetX)
        offsetY = try c.decode(CGFloat.self, forKey: .offsetY)
        scale = try c.decode(CGFloat.self, forKey: .scale)
        previewScale = try c.decode(CGFloat.self, forKey: .previewScale)
        isFlipped = try c.decode(Bool.self, forKey: .isFlipped)
        isDynamic = try c.decodeIfPresent(Bool.self, forKey: .isDynamic) ?? false
        timeVariants = try c.decodeIfPresent([TimeVariant].self, forKey: .timeVariants) ?? []

        if let stored = try c.decodeIfPresent(Bool.self, forKey: .isAppearanceBased) {
            isAppearanceBased = stored
        } else {
            // Migration: infer from the legacy heuristic (two variants at 12:00 and 00:00).
            isAppearanceBased = isDynamic
                && timeVariants.count == 2
                && timeVariants.contains(where: { $0.hour == 12 && $0.minute == 0 })
                && timeVariants.contains(where: { $0.hour == 0 && $0.minute == 0 })
        }
    }
}
