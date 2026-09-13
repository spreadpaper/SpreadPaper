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

/// One photograph in the hero's day, with the hour it stands for.
/// Its credit travels with it, so one name fits the image.
struct HeroDayPhoto: Identifiable, Equatable {
    /// Hour of the day the photograph is whole on screen, 0 through 23.
    let hour: Int

    /// The bundled image the photograph is drawn from.
    let resource: ImageResource

    /// The photographer credited for it.
    let photographer: String

    /// The photographer's Unsplash profile.
    let profile: URL

    /// The photograph's own page on Unsplash.
    let page: URL

    /// No two photographs stand for the same hour.
    var id: Int { hour }
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

/// A day of photographs on a loop, each whole at the hour it stands for.
/// One loop is one day, so the readout and the image agree.
/// Every panel reads the same clock.
enum HeroDayCycle {
    /// The photographs of the day, ordered by the hour each stands for.
    static let photographs: [HeroDayPhoto] = [
        HeroDayPhoto(
            hour: 6,
            resource: .heroDay1,
            photographer: "Simon Lohmann",
            profile: URL(string: "https://unsplash.com/@slohmann")!,
            page: URL(
                string: "https://unsplash.com/photos/green-mountains-under-blue-sky-during-daytime-I_n_b44cqhk"
            )!
        ),
        HeroDayPhoto(
            hour: 12,
            resource: .heroDay2,
            photographer: "Antony Sklivagkos",
            profile: URL(string: "https://unsplash.com/@antoskli")!,
            page: URL(string: "https://unsplash.com/photos/mountain-peak-under-blue-sky-iTYShprNeRE")!
        ),
        HeroDayPhoto(
            hour: 18,
            resource: .heroDay3,
            photographer: "Michał Parzuchowski",
            profile: URL(string: "https://unsplash.com/@mparzuchowski")!,
            page: URL(
                string: "https://unsplash.com/photos/aerial-photo-of-brown-mountain-under-gray-sky-HbhJyWnE9Oo"
            )!
        ),
        HeroDayPhoto(
            hour: 23,
            resource: .heroDay4,
            photographer: "Benjamin Voros",
            profile: URL(string: "https://unsplash.com/@vorosbenisop")!,
            page: URL(string: "https://unsplash.com/photos/snow-mountain-under-stars-phIFdC6lA4E")!
        )
    ]

    /// Seconds a whole day takes on screen.
    static let period: TimeInterval = 12

    /// Seconds one photograph takes to dissolve into the next.
    static let fade: TimeInterval = 1.0

    /// The point in the loop a stopped hero rests on, one photograph whole.
    /// It rests on the photograph nearest midday.
    static let still: TimeInterval = {
        let midday = photographs.min { abs($0.hour - 12) < abs($1.hour - 12) }
        return period * Double(midday?.hour ?? 0) / 24
    }()

    /// Seconds since the reference date, which the loop is read off.
    /// Stopped at the still under Reduce Motion.
    static func elapsed(at date: Date, reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? still : date.timeIntervalSinceReferenceDate
    }

    /// How far through the day `seconds` falls, from 0 up to 1.
    /// Any second on the clock maps into the loop.
    static func dayFraction(at seconds: TimeInterval) -> Double {
        let offset = seconds.truncatingRemainder(dividingBy: period)
        return (offset < 0 ? offset + period : offset) / period
    }

    /// The hour the readout shows at `seconds`, 0 through 23.
    static func hour(at seconds: TimeInterval) -> Int {
        min(Int(dayFraction(at: seconds) * 24), 23)
    }

    /// How much of the spread photograph `index` fills at `seconds`.
    /// Two neighbours share it through a dissolve.
    static func coverage(of index: Int, at seconds: TimeInterval) -> Double {
        let stage = stage(at: seconds)
        if index == stage.leaving { return 1 - stage.progress }
        if index == stage.arriving { return stage.progress }
        return 0
    }

    /// The opacity photograph `index` is drawn at, stacked in schedule order.
    /// The earlier of a dissolving pair paints solid beneath the other.
    static func opacity(of index: Int, at seconds: TimeInterval) -> Double {
        let share = coverage(of: index, at: seconds)
        guard share > 0 else { return 0 }
        let beneath = photographs.indices.first { coverage(of: $0, at: seconds) > 0 }
        return index == beneath ? 1 : share
    }

    /// How visible photograph `index`'s credit is at `seconds` on the clock.
    /// It hands over as the dissolve passes halfway.
    static func creditOpacity(of index: Int, at seconds: TimeInterval) -> Double {
        min(max((coverage(of: index, at: seconds) - 0.5) * 2, 0), 1)
    }

    /// The two photographs `seconds` falls between, and how far it lies between them.
    /// Progress rests at 0 while one photograph holds alone.
    private static func stage(
        at seconds: TimeInterval
    ) -> (leaving: Int, arriving: Int, progress: Double) {
        let last = photographs.count - 1
        let position = dayFraction(at: seconds) * period
        // The hours before the first photograph's own hour belong to the day before it.
        let elapsed = position < start(of: 0) ? position + period : position
        let leaving = photographs.indices.last { start(of: $0) <= elapsed } ?? last
        let arriving = (leaving + 1) % photographs.count
        let whole = leaving == last ? start(of: 0) + period : start(of: arriving)
        let progress = (elapsed - (whole - fade)) / fade
        return (leaving, arriving, min(max(progress, 0), 1))
    }

    /// Seconds into the loop photograph `index` is whole on screen.
    private static func start(of index: Int) -> TimeInterval {
        period * Double(photographs[index].hour) / 24
    }
}

/// The instant every hero panel and credit reads, in each loop's own seconds.
/// One clock feeds them all, so a spread never tears.
struct HeroClock: Equatable {
    /// Seconds into the Light & Dark loop.
    let themed: TimeInterval

    /// Seconds into the Dynamic day.
    let day: TimeInterval

    /// Reads both loops off one date, stopping either under Reduce Motion.
    init(date: Date, reduceMotion: Bool) {
        themed = HeroCrossfade.elapsed(at: date, reduceMotion: reduceMotion)
        day = HeroDayCycle.elapsed(at: date, reduceMotion: reduceMotion)
    }
}

/// One hero photograph, spread across the panels and clipped to this one.
struct SpreadPhoto: View {
    let slice: PanelSlice
    let resource: ImageResource

    /// Shows one of the Light & Dark pair.
    init(slice: PanelSlice, photo: HeroPhoto = .day) {
        self.slice = slice
        resource = photo.resource
    }

    /// Shows one photograph out of the day.
    init(slice: PanelSlice, photo: HeroDayPhoto) {
        self.slice = slice
        resource = photo.resource
    }

    var body: some View {
        SpreadContent(slice: slice) {
            Image(resource)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityHidden(true)
        }
    }
}
