// SpreadPaper/Views/SpreadPhoto.swift

import SwiftUI

/// One panel's window onto a scene laid out across several panels side by side.
/// The gaps between panels belong to the scene, so it runs on behind them.
struct PanelSlice: Equatable {
    /// Size of the whole scene the panels are cut from.
    let spread: CGSize

    /// This panel's rectangle inside that scene.
    let frame: CGRect
}

/// Lays `content` out at the full spread size and shows only this panel's slice of it.
struct SpreadContent<Content: View>: View {
    let slice: PanelSlice
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(width: slice.spread.width, height: slice.spread.height)
            .offset(x: -slice.frame.minX, y: -slice.frame.minY)
            .frame(width: slice.frame.width, height: slice.frame.height, alignment: .topLeading)
            .clipped()
    }
}

/// One of the two bundled hero photographs of the same coast, with its attribution.
/// Both are cut to the spread's shape, so either slices across the panels alike.
enum HeroPhoto: CaseIterable {
    case day
    case night

    /// The bundled image the photograph is drawn from.
    var resource: ImageResource {
        switch self {
        case .day: .heroBeach
        case .night: .heroBeachNight
        }
    }

    /// The photographer credited for it.
    var photographer: String {
        switch self {
        case .day: "Ganapathy Kumar"
        case .night: "Michaela"
        }
    }

    /// The photographer's Unsplash profile.
    var profile: URL {
        switch self {
        case .day: URL(string: "https://unsplash.com/@gkumar2175")!
        case .night: URL(string: "https://unsplash.com/@m_hampi")!
        }
    }

    /// The photograph's own page on Unsplash.
    var page: URL {
        switch self {
        case .day:
            URL(string: "https://unsplash.com/photos/tropical-beach-at-sunset-in-maui-7782WXBriyM")!
        case .night:
            URL(string: "https://unsplash.com/photos/silhouette-photo-of-coconut-trees-79l_GcSoHrA")!
        }
    }
}

/// Timing of the hero's day-to-night dissolve, as a loop read off the wall clock.
/// Every panel reads the same clock, so the whole spread turns together.
enum HeroCrossfade {
    /// Seconds one photograph stays alone on screen.
    static let hold: TimeInterval = 2.5

    /// Seconds one photograph takes to dissolve into the other.
    static let fade: TimeInterval = 1.0

    /// Seconds a whole there-and-back loop takes.
    static let period: TimeInterval = (hold + fade) * 2

    /// The point in the loop a stopped hero rests on, one photograph whole.
    static let still: TimeInterval = 0

    /// Seconds since the reference date, which the loop is read off.
    /// Stopped at the still under Reduce Motion.
    static func elapsed(at date: Date, reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? still : date.timeIntervalSinceReferenceDate
    }

    /// How visible the night photograph is at `seconds`, eased at both ends.
    /// Any second on the clock maps into the loop.
    static func nightOpacity(at seconds: TimeInterval) -> Double {
        let offset = seconds.truncatingRemainder(dividingBy: period)
        let elapsed = offset < 0 ? offset + period : offset
        switch elapsed {
        case ..<hold: return 0
        case ..<(hold + fade): return ease((elapsed - hold) / fade)
        case ..<(hold * 2 + fade): return 1
        default: return ease((period - elapsed) / fade)
        }
    }

    /// How visible `photo`'s credit is at `seconds` on the clock.
    /// It hands over as the dissolve passes halfway.
    static func creditOpacity(of photo: HeroPhoto, at seconds: TimeInterval) -> Double {
        let night = nightOpacity(at: seconds)
        let share = photo == .night ? night : 1 - night
        return min(max((share - 0.5) * 2, 0), 1)
    }

    /// Smoothstep over 0...1, so a dissolve leaves and arrives without a corner.
    private static func ease(_ fraction: Double) -> Double {
        let clamped = min(max(fraction, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}

/// One hero photograph, spread across the panels and clipped to this one.
struct SpreadPhoto: View {
    let slice: PanelSlice
    var photo: HeroPhoto = .day

    var body: some View {
        SpreadContent(slice: slice) {
            Image(photo.resource)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityHidden(true)
        }
    }
}
