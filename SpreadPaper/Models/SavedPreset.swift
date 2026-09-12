import Foundation

/// Persisted wallpaper: image placement plus the variants and flags for dynamic and light/dark kinds.
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
    /// Marks a Light/Dark preset as opposed to a time-of-day Dynamic one; both set `isDynamic`.
    /// Files without the key infer it from `timeVariants` on load.
    var isAppearanceBased: Bool = false

    /// Kind of wallpaper this preset produces, derived from the persisted flags.
    /// Appearance wins over dynamic; neither means static.
    var kind: WallpaperType {
        if isAppearanceBased { return .appearance }
        if isDynamic { return .dynamic }
        return .standard
    }

    /// Keys of the presets JSON; the dynamic and appearance keys may be absent in files on disk.
    private enum CodingKeys: String, CodingKey {
        case id, name, imageFilename, offsetX, offsetY, scale, previewScale, isFlipped
        case isDynamic, timeVariants, isAppearanceBased
    }

    /// Builds a preset with defaults for the dynamic and appearance fields.
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

    /// Decodes a preset, defaulting fields older files lack and inferring `isAppearanceBased` when absent.
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
            // No key: two variants at 12:00 and 00:00 mean appearance-based.
            isAppearanceBased = isDynamic
                && timeVariants.count == 2
                && timeVariants.contains(where: { $0.hour == 12 && $0.minute == 0 })
                && timeVariants.contains(where: { $0.hour == 0 && $0.minute == 0 })
        }
    }
}
