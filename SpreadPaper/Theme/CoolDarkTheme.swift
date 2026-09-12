// SpreadPaper/Theme/CoolDarkTheme.swift

import SwiftUI

// MARK: - Color Tokens

extension Color {
    /// Window background, behind every screen.
    static let cdBgPrimary = Color(hex: 0x16161a)

    /// Surface of a panel, card or dialog.
    static let cdBgSecondary = Color(hex: 0x1e1e24)

    /// Surface of a control that sits on a panel.
    static let cdBgElevated = Color(hex: 0x24242c)

    /// Surface of a hovered row or control.
    static let cdBgHover = Color(hex: 0x2a2a34)

    /// Hairline between surfaces.
    static let cdBorder = Color(hex: 0x2a2a32)

    /// Border that has to read on its own.
    static let cdBorderStrong = Color(hex: 0x3a3a44)

    /// Titles and body copy.
    static let cdTextPrimary = Color(hex: 0xe8e8ed)

    /// Supporting copy and inactive labels.
    static let cdTextSecondary = Color(hex: 0x9e9eaa)

    /// Hints, counts and section headers.
    static let cdTextTertiary = Color(hex: 0x6e6e7a)

    /// Indigo of primary actions and selection.
    static let cdAccent = Color(hex: 0x5e5ce6)

    /// Glow cast by an accent surface.
    static let cdAccentGlow = Color(hex: 0x5e5ce6).opacity(0.2)

    /// Green that confirms an applied wallpaper.
    static let cdSuccess = Color(hex: 0x34C759)

    /// Canvas behind the editor's monitors.
    static let cdCanvasBg = Color(hex: 0x111114)

    /// Red of destructive actions and errors.
    static let cdDanger = Color(hex: 0xFF453A)

    /// Amber that marks the dynamic kind.
    static let cdDynamicTint = Color(hex: 0xf5a524)

    /// Periwinkle that marks the light/dark kind.
    static let cdAppearanceTint = Color(hex: 0x7c7cff)

    /// Violet companion stop for accent gradients.
    static let cdAccentSecondary = Color(hex: 0xAF52DE)

    /// Dims whatever sits behind a modal or a badge.
    static let cdOverlayScrim = Color.black.opacity(0.55)

    /// Lighter scrim for controls that float on a thumbnail.
    static let cdOverlayScrimSoft = Color.black.opacity(0.45)

    /// Drop shadow under panels, cards and toasts.
    static let cdShadow = Color.black.opacity(0.4)

    /// Deeper shadow that lifts a modal off the app.
    static let cdShadowStrong = Color.black.opacity(0.6)

    /// Hairline highlight along the edge of a raised surface.
    static let cdHighlightStroke = Color.white.opacity(0.15)

    /// Faintest hairline, for inner edges, dividers and ticks.
    static let cdHighlightStrokeSoft = Color.white.opacity(0.06)

    /// Wash under a hovered control.
    static let cdHoverFill = Color.white.opacity(0.05)

    /// Wash under an active control, a step above hover.
    static let cdActiveFill = Color.white.opacity(0.08)

    /// Hairline ring that keeps a white knob off a pale backdrop.
    static let cdOutlineOnLight = Color.black.opacity(0.08)

    /// Face of a draggable slider or range-bar handle.
    static let cdKnob = Color.white

    /// sRGB colour from a 0xRRGGBB literal.
    fileprivate init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Scene Art

/// Palette for the creation modal's illustrated preview scenes.
/// Artwork, not chrome, so it sits beside the tokens.
enum SceneArt {
    /// Sunset sky, from the top-leading to the bottom-trailing corner.
    static let sunsetSky = [Color(hex: 0x3a3050), Color(hex: 0x1d2036)]

    /// Purple bloom in the far corner of the sunset sky.
    static let sunsetHaze = Color(hex: 0x8a4fa3)

    /// Warm bloom around the sunset sun.
    static let sunsetGlow = Color(hex: 0xd79a55)

    /// Hill silhouette along the bottom of the sunset scene.
    static let sunsetHills = Color(hex: 0x1d1a2b)

    /// Centre of the sun disc.
    static let sunCore = Color(hex: 0xf4e4a0)

    /// Edge of the sun disc, and the colour of its glow.
    static let sunRim = Color(hex: 0xd69a2a)

    /// Daytime sky, from the top-leading to the bottom-trailing corner.
    static let daySky = [Color(hex: 0xe4cf8e), Color(hex: 0xcba06f)]

    /// Pale bloom across the daytime sky.
    static let dayHaze = Color(hex: 0xebdeb2)

    /// Night sky, from the top-leading to the bottom-trailing corner.
    static let nightSky = [Color(hex: 0x2b2442), Color(hex: 0x14102a)]

    /// Violet bloom low in the night sky.
    static let nightHaze = Color(hex: 0x4c3d78)

    /// Centre of the moon disc.
    static let moonCore = Color(hex: 0xe4e1d5)

    /// Edge of the moon disc, and the colour of its glow.
    static let moonRim = Color(hex: 0xa6a4b0)

    /// A pinprick star.
    static let starlight = Color.white

    /// A full day of sky colour, midnight through midnight, read left to right.
    static let dayCycleStops: [Gradient.Stop] = [
        .init(color: nightSky[0], location: 0.0),
        .init(color: Color(hex: 0x503470), location: 0.2),
        .init(color: Color(hex: 0x9a6944), location: 0.42),
        .init(color: Color(hex: 0xe2b965), location: 0.55),
        .init(color: Color(hex: 0x4e6a9e), location: 0.8),
        .init(color: nightSky[0], location: 1.0)
    ]

    /// Glow of the dot that travels the day cycle, centre outwards.
    static let dayCycleMarker = [Color.white.opacity(0.95), Color.white.opacity(0.3), Color.clear]

    /// Unfilled part of the day-cycle timeline.
    static let timelineTrack = Color.white.opacity(0.22)

    /// Filled part of the timeline, dim at its start and bright at the playhead.
    static let timelineFill = [Color.white.opacity(0.1), Color.white.opacity(0.9)]
}

// MARK: - Button Styles

/// Shared chrome for primary, success and secondary buttons. `size` picks the
/// regular or compact metrics; a disabled button fades and loses its glow.
struct CoolDarkButtonStyle: ButtonStyle {
    /// Button metrics. Compact is the 30 pt height used in dialogs and on
    /// gallery cards.
    enum Size {
        case regular
        case compact

        var fontSize: CGFloat {
            switch self {
            case .regular: 14
            case .compact: 13
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .regular: 16
            case .compact: 12
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .regular: 10
            case .compact: 7
            }
        }

        /// Pinned height so compact buttons line up with 30 pt neighbours.
        var minHeight: CGFloat? {
            switch self {
            case .regular: nil
            case .compact: 30
            }
        }
    }

    var isPrimary: Bool = false
    var isSuccess: Bool = false
    var size: Size = .regular

    @Environment(\.isEnabled) var isEnabled

    /// True for the accent and success variants, which drop the border.
    private var isFilled: Bool { isPrimary || isSuccess }

    /// Background colour for the current variant.
    private var fill: Color {
        isSuccess ? Color.cdSuccess : isPrimary ? Color.cdAccent : Color.cdBgElevated
    }

    /// Applies the variant's fill, border and glow, dimming while pressed or disabled.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .semibold))
            .foregroundStyle(isFilled ? Color.cdTextPrimary : Color.cdTextSecondary)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size.minHeight)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isFilled ? Color.clear : Color.cdBorder, lineWidth: 1)
            )
            .shadow(color: isFilled && isEnabled ? fill.opacity(0.3) : .clear, radius: 8)
            .opacity(!isEnabled ? 0.5 : configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Section Header

/// Small uppercase tertiary label that titles a panel section.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.cdTextTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
