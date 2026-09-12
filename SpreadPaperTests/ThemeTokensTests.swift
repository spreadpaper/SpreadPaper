import Foundation
import SwiftUI
import Testing
@testable import SpreadPaper

/// Issue #102: the theme owns every colour the app renders.
/// Views name tokens; only the theme mints them.
struct ThemeTokensTests {
    /// Patterns that mint a colour from raw components.
    private static let literalPatterns = [
        "Color(hex:", "Color(red:", "Color(white:", ".white.opacity(", ".black.opacity("
    ]

    /// App sources outside the theme file, where no literal colour may appear.
    private static func nonThemeSources() throws -> [URL] {
        let app = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "SpreadPaper")
        let files = FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" && !$0.path.hasSuffix("Theme/CoolDarkTheme.swift") } ?? []
        #expect(files.count > 10, "source scan found no app files to check")
        return files
    }

    @Test func themeExposesEveryTokenByName() {
        let tokens: [Color] = [
            .cdBgPrimary, .cdBgSecondary, .cdBgElevated, .cdBgHover,
            .cdBorder, .cdBorderStrong,
            .cdTextPrimary, .cdTextSecondary, .cdTextTertiary,
            .cdAccent, .cdAccentGlow, .cdAccentSecondary,
            .cdSuccess, .cdDanger, .cdDynamicTint, .cdAppearanceTint,
            .cdCanvasBg, .cdOverlayScrim, .cdOverlayScrimSoft,
            .cdShadow, .cdShadowStrong,
            .cdHighlightStroke, .cdHighlightStrokeSoft,
            .cdHoverFill, .cdActiveFill, .cdOutlineOnLight, .cdKnob
        ]
        #expect(Set(tokens).count == tokens.count, "two tokens carry the same colour")
    }

    @Test func sceneArtExposesTheIllustrationPalette() {
        let art: [Color] = [
            SceneArt.sunsetHaze, SceneArt.sunsetGlow, SceneArt.sunsetHills,
            SceneArt.sunCore, SceneArt.sunRim,
            SceneArt.dayHaze, SceneArt.nightHaze,
            SceneArt.moonCore, SceneArt.moonRim,
            SceneArt.starlight, SceneArt.timelineTrack
        ]
        #expect(Set(art).count == art.count, "two scene colours are identical")
        #expect(SceneArt.sunsetSky.count == 2)
        #expect(SceneArt.daySky.count == 2)
        #expect(SceneArt.nightSky.count == 2)
        #expect(SceneArt.timelineFill.count == 2)
        #expect(SceneArt.dayCycleMarker.count == 3)
        #expect(SceneArt.dayCycleStops.count == 6)
    }

    @Test func wallpaperKindsTintFromTokens() {
        #expect(WallpaperType.standard.tint == Color.cdTextTertiary)
        #expect(WallpaperType.appearance.tint == Color.cdAppearanceTint)
        #expect(WallpaperType.dynamic.tint == Color.cdDynamicTint)
    }

    @Test func noSourceOutsideTheThemeMintsALiteralColour() throws {
        var offenders: [String] = []
        for file in try Self.nonThemeSources() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where Self.literalPatterns.contains(where: { line.contains($0) }) {
                offenders.append("\(file.lastPathComponent):\(number + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        #expect(offenders.isEmpty, "literal colours outside the theme:\n\(offenders.joined(separator: "\n"))")
    }
}
