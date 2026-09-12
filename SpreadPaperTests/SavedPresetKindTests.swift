import Foundation
import Testing
@testable import SpreadPaper

/// Issue #78: a preset reports its kind as `WallpaperType`, never as a string.
@MainActor
struct SavedPresetKindTests {
    private func preset(isDynamic: Bool = false, isAppearanceBased: Bool = false) -> SavedPreset {
        SavedPreset(
            name: "p",
            imageFilename: "p.png",
            offsetX: 0, offsetY: 0, scale: 1, previewScale: 1, isFlipped: false,
            isDynamic: isDynamic,
            isAppearanceBased: isAppearanceBased
        )
    }

    @Test func staticPresetIsStandard() {
        #expect(preset().kind == .standard)
    }

    @Test func dynamicFlagGivesDynamic() {
        #expect(preset(isDynamic: true).kind == .dynamic)
    }

    @Test func appearanceFlagWinsOverDynamic() {
        #expect(preset(isDynamic: true, isAppearanceBased: true).kind == .appearance)
    }

    /// Files written before `isAppearanceBased` existed carry every other key.
    private func legacyVariantJSON(_ name: String, hour: Int) -> String {
        """
        {
          "id": "\(UUID().uuidString)",
          "imageFilename": "\(name).png",
          "hour": \(hour), "minute": 0, "name": "",
          "offsetX": 0, "offsetY": 0, "scale": 1, "previewScale": 1, "isFlipped": false
        }
        """
    }

    /// Builds a dynamic preset file from before `isAppearanceBased` existed.
    private func legacyPresetJSON(variants: [String]) -> Data {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "name": "legacy",
          "imageFilename": "legacy.png",
          "offsetX": 0, "offsetY": 0, "scale": 1, "previewScale": 1, "isFlipped": false,
          "isDynamic": true,
          "timeVariants": [\(variants.joined(separator: ", "))]
        }
        """
        return Data(json.utf8)
    }

    @Test func legacyNoonAndMidnightPairDecodesAsAppearance() throws {
        let data = legacyPresetJSON(variants: [
            legacyVariantJSON("light", hour: 12),
            legacyVariantJSON("dark", hour: 0)
        ])
        let decoded = try JSONDecoder().decode(SavedPreset.self, from: data)
        #expect(decoded.kind == .appearance)
    }

    @Test func legacyScheduleAtOtherHoursDecodesAsDynamic() throws {
        let data = legacyPresetJSON(variants: [
            legacyVariantJSON("morning", hour: 8),
            legacyVariantJSON("evening", hour: 20)
        ])
        let decoded = try JSONDecoder().decode(SavedPreset.self, from: data)
        #expect(decoded.kind == .dynamic)
    }
}
