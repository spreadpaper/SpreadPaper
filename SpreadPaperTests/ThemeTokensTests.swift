import AppKit
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

    /// sRGB components of a token.
    private static func components(_ color: Color) -> (r: Double, g: Double, b: Double) {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? .black
        return (c.redComponent, c.greenComponent, c.blueComponent)
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
        let offenders = try AppSources.lines(
            in: AppSources.outsideTheTheme(),
            containing: Self.literalPatterns
        )
        #expect(offenders.isEmpty, "literal colours outside the theme:\n\(offenders.joined(separator: "\n"))")
    }

    @Test func anIconTokenContrastsWithTheSurfaceBehindIt() {
        let icon = Self.components(.cdTextTertiary)
        let surface = Self.components(.cdBgElevated)
        let gap = abs(icon.r - surface.r) + abs(icon.g - surface.g) + abs(icon.b - surface.b)
        #expect(gap > 0.3, "an icon token is too close to the surface it sits on")
    }
}
