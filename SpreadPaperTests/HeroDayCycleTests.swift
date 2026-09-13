import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import SpreadPaper

/// Issue #122: the Dynamic hero runs a day of photographs past a clock.
struct HeroDayCycleTests {
    /// Hero height in points, the 260 pt header less its top and bottom insets.
    private static let height: CGFloat = 170

    /// How many points along the loop the assertions sample.
    private static let samples = 600

    /// The day's image sets, each with the file it holds.
    private static let imageSets = [
        (set: "HeroDay1", file: "hero-day-1.jpg"),
        (set: "HeroDay2", file: "hero-day-2.jpg"),
        (set: "HeroDay3", file: "hero-day-3.jpg"),
        (set: "HeroDay4", file: "hero-day-4.jpg")
    ]

    /// Where an image set's file sits in the app's asset catalog.
    private static func assetURL(_ imageSet: String, _ file: String) -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "SpreadPaper/Assets.xcassets/\(imageSet).imageset/\(file)")
    }

    /// Pixel size of the file behind an image set in the app's asset catalog.
    private static func assetSize(_ imageSet: String, _ file: String) throws -> CGSize {
        let url = assetURL(imageSet, file)
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        return CGSize(width: width, height: height)
    }

    /// Seconds into the loop the photograph at `index` is whole on screen.
    /// It mirrors the mapping the app keeps private.
    private static func start(of index: Int) -> TimeInterval {
        HeroDayCycle.period * Double(HeroDayCycle.photographs[index].hour) / 24
    }

    /// The photograph filling most of the spread at `seconds`.
    private static func dominant(at seconds: TimeInterval) -> Int {
        HeroDayCycle.photographs.indices.max {
            HeroDayCycle.coverage(of: $0, at: seconds) < HeroDayCycle.coverage(of: $1, at: seconds)
        } ?? 0
    }

    /// Every photograph tied for the largest share of the spread at `seconds`.
    private static func leaders(at seconds: TimeInterval) -> [Int] {
        let top = HeroDayCycle.coverage(of: dominant(at: seconds), at: seconds)
        return HeroDayCycle.photographs.indices.filter {
            HeroDayCycle.coverage(of: $0, at: seconds) == top
        }
    }

    /// What the stacked opacities actually paint of photograph `index`.
    /// Each layer covers the ones below it by its own opacity.
    private static func painted(_ index: Int, at seconds: TimeInterval) -> Double {
        let above = HeroDayCycle.photographs.indices.filter { $0 > index }
        let hidden = above.reduce(1.0) { $0 * (1 - HeroDayCycle.opacity(of: $1, at: seconds)) }
        return HeroDayCycle.opacity(of: index, at: seconds) * hidden
    }

    /// Whether `hour` falls in the half-open run of hours from `from` to `to`.
    /// The run may pass midnight, so it is walked forwards.
    private static func runOfHours(from: Int, to: Int, holds hour: Int) -> Bool {
        let length = (to - from + 24) % 24
        let offset = (hour - from + 24) % 24
        return offset < (length == 0 ? 24 : length)
    }

    @Test func everyPhotographIsTheSameShape() throws {
        let sizes = try Self.imageSets.map { try Self.assetSize($0.set, $0.file) }
        #expect(Set(sizes.map(\.width)).count == 1, "the photographs would slice differently")
        #expect(Set(sizes.map(\.height)).count == 1, "the photographs would slice differently")
    }

    @Test func thePhotographsMatchTheSpreadTheyFill() throws {
        let spread = HeroSpread(height: Self.height).spread
        for imageSet in Self.imageSets {
            let photo = try Self.assetSize(imageSet.set, imageSet.file)
            let drift = abs(photo.width / photo.height - spread.width / spread.height)
            #expect(drift < 0.01, "\(imageSet.file) is cropped off the spread's aspect")
        }
    }

    @Test func eachPhotographIsSmallEnoughToBundle() throws {
        for imageSet in Self.imageSets {
            let url = Self.assetURL(imageSet.set, imageSet.file)
            let bytes = try #require(
                try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
            )
            #expect(bytes < 400_000, "\(imageSet.file) is \(bytes) bytes")
        }
    }

    @Test func everyBundledPhotographIsOnTheSchedule() {
        #expect(HeroDayCycle.photographs.count == Self.imageSets.count)
    }

    @Test func theScheduleRunsForwardsThroughOneDay() {
        let hours = HeroDayCycle.photographs.map(\.hour)
        #expect(hours == hours.sorted(), "the day runs out of order")
        #expect(Set(hours).count == hours.count, "two photographs claim the same hour")
        #expect(hours.allSatisfy { (0...23).contains($0) })
        for index in hours.indices {
            let next = (index + 1) % hours.count
            let span = Double((hours[next] - hours[index] + 24) % 24) / 24 * HeroDayCycle.period
            #expect(span > HeroDayCycle.fade, "photograph \(index) never holds on its own")
        }
    }

    @Test func everyPhotographCarriesItsOwnPhotographer() {
        let photos = HeroDayCycle.photographs
        #expect(photos.allSatisfy { !$0.photographer.isEmpty })
        #expect(Set(photos.map(\.photographer)).count == photos.count)
        #expect(Set(photos.map(\.profile)).count == photos.count)
        #expect(Set(photos.map(\.page)).count == photos.count)
    }

    @Test func eachPhotographIsWholeAtItsOwnHour() {
        for index in HeroDayCycle.photographs.indices {
            let seconds = Self.start(of: index)
            #expect(HeroDayCycle.coverage(of: index, at: seconds) == 1)
            #expect(HeroDayCycle.hour(at: seconds) == HeroDayCycle.photographs[index].hour)
            #expect(HeroDayCycle.creditOpacity(of: index, at: seconds) == 1)
        }
    }

    @Test func theSpreadIsAlwaysCoveredByOnePhotographOrTwo() {
        for step in 0...Self.samples {
            let seconds = HeroDayCycle.period * Double(step) / Double(Self.samples)
            let shares = HeroDayCycle.photographs.indices.map {
                HeroDayCycle.coverage(of: $0, at: seconds)
            }
            #expect(abs(shares.reduce(0, +) - 1) < 0.0001, "the spread thins out \(seconds)s in")
            #expect(shares.filter { $0 > 0 }.count <= 2, "three photographs share \(seconds)s in")
        }
    }

    @Test func onlyNeighboursInTheDayEverShareTheSpread() {
        for step in 0...Self.samples {
            let seconds = HeroDayCycle.period * Double(step) / Double(Self.samples)
            let showing = HeroDayCycle.photographs.indices.filter {
                HeroDayCycle.coverage(of: $0, at: seconds) > 0
            }
            guard showing.count == 2 else { continue }
            let gap = (showing[1] - showing[0] + HeroDayCycle.photographs.count)
                % HeroDayCycle.photographs.count
            let wraps = showing[0] == 0 && showing[1] == HeroDayCycle.photographs.count - 1
            #expect(gap == 1 || wraps, "the day skips a photograph \(seconds)s in")
        }
    }

    @Test func theStackPaintsWhatTheScheduleAsksFor() {
        for step in 0...Self.samples {
            let seconds = HeroDayCycle.period * Double(step) / Double(Self.samples)
            for index in HeroDayCycle.photographs.indices {
                let asked = HeroDayCycle.coverage(of: index, at: seconds)
                let drawn = Self.painted(index, at: seconds)
                #expect(abs(asked - drawn) < 0.0001, "photograph \(index) paints wrong \(seconds)s in")
            }
        }
    }

    @Test func theDissolveGlidesRatherThanSteps() {
        var previous = HeroDayCycle.coverage(of: 0, at: 0)
        for step in 1...Self.samples {
            let seconds = HeroDayCycle.period * Double(step) / Double(Self.samples)
            let share = HeroDayCycle.coverage(of: 0, at: seconds)
            #expect(abs(share - previous) < 0.05, "the first photograph jumps \(seconds)s in")
            previous = share
        }
    }

    @Test func theLoopComesBackToWhereItStarted() {
        for step in 0...40 {
            let seconds = HeroDayCycle.period * Double(step) / 40
            for index in HeroDayCycle.photographs.indices {
                let now = HeroDayCycle.coverage(of: index, at: seconds)
                let next = HeroDayCycle.coverage(of: index, at: seconds + HeroDayCycle.period)
                let before = HeroDayCycle.coverage(of: index, at: seconds - HeroDayCycle.period * 3)
                #expect(abs(now - next) < 0.0001, "the loop drifts forwards \(seconds)s in")
                #expect(abs(now - before) < 0.0001, "the loop drifts backwards \(seconds)s in")
            }
        }
    }

    @Test func theLastPhotographHandsBackToTheFirst() {
        let last = HeroDayCycle.photographs.count - 1
        let wrap = Self.start(of: 0) - HeroDayCycle.fade / 2
        #expect(HeroDayCycle.coverage(of: last, at: wrap) > 0)
        #expect(HeroDayCycle.coverage(of: 0, at: wrap) > 0)
        #expect(HeroDayCycle.coverage(of: last, at: Self.start(of: last)) == 1)
    }

    @Test func theClockSweepsAWholeDayOverOneLoop() {
        #expect(HeroDayCycle.hour(at: 0) == 0)
        #expect(HeroDayCycle.hour(at: HeroDayCycle.period / 2) == 12)
        #expect(HeroDayCycle.hour(at: HeroDayCycle.period - 0.001) == 23)
        #expect(HeroDayCycle.hour(at: HeroDayCycle.period) == 0)
        #expect(HeroDayCycle.hour(at: -HeroDayCycle.period / 4) == 18)
        var previous = 0
        for step in 0..<Self.samples {
            let seconds = HeroDayCycle.period * Double(step) / Double(Self.samples)
            let hour = HeroDayCycle.hour(at: seconds)
            #expect((0...23).contains(hour))
            #expect(hour >= previous, "the clock runs backwards \(seconds)s in")
            previous = hour
        }
    }

    @Test func theClockAgreesWithThePhotographOnScreen() {
        let photos = HeroDayCycle.photographs
        for step in 0...Self.samples {
            let seconds = HeroDayCycle.period * Double(step) / Double(Self.samples)
            let lead = Int(HeroDayCycle.fade / HeroDayCycle.period * 24 / 2)
            let hour = HeroDayCycle.hour(at: seconds)
            // Halfway through a dissolve neither photograph leads, and either one fits the clock.
            let leading = Self.leaders(at: seconds).contains { index in
                let next = (index + 1) % photos.count
                return Self.runOfHours(
                    from: (photos[index].hour - lead + 24) % 24,
                    to: (photos[next].hour - lead + 24) % 24,
                    holds: hour
                )
            }
            #expect(leading, "the clock reads \(hour) over the wrong photograph at \(seconds)s")
        }
    }

    @Test func onlyOnePhotographerIsEverReadable() {
        for step in 0...Self.samples {
            let seconds = HeroDayCycle.period * Double(step) / Double(Self.samples)
            let credits = HeroDayCycle.photographs.indices.map {
                HeroDayCycle.creditOpacity(of: $0, at: seconds)
            }
            #expect(credits.filter { $0 > 0 }.count <= 1, "two photographers read at \(seconds)s")
            guard let readable = credits.firstIndex(where: { $0 > 0 }) else { continue }
            #expect(readable == Self.dominant(at: seconds), "the credit names the wrong photograph")
        }
    }

    @Test func reduceMotionHoldsOnOneWholePhotograph() {
        let still = HeroDayCycle.still
        let whole = HeroDayCycle.photographs.indices.filter {
            HeroDayCycle.coverage(of: $0, at: still) == 1
        }
        #expect(whole.count == 1, "a stopped hero would show a half-dissolved blend")
        #expect(HeroDayCycle.hour(at: still) == HeroDayCycle.photographs[whole[0]].hour)
        #expect(HeroDayCycle.creditOpacity(of: whole[0], at: still) == 1)
    }

    @Test func reduceMotionStopsTheClockTheHeroReads() {
        let now = Date()
        let stopped = HeroDayCycle.elapsed(at: now, reduceMotion: true)
        let later = HeroDayCycle.elapsed(at: now.addingTimeInterval(3), reduceMotion: true)
        #expect(stopped == later, "a stopped hero still moves with the clock")
        #expect(stopped == HeroDayCycle.still)
        let running = HeroDayCycle.elapsed(at: now, reduceMotion: false)
        let runningLater = HeroDayCycle.elapsed(at: now.addingTimeInterval(3), reduceMotion: false)
        #expect(runningLater - running == 3, "a running hero does not follow the clock")
    }

    @Test func oneClockFeedsBothLoops() {
        let date = Date()
        let clock = HeroClock(date: date, reduceMotion: false)
        #expect(clock.themed == HeroCrossfade.elapsed(at: date, reduceMotion: false))
        #expect(clock.day == HeroDayCycle.elapsed(at: date, reduceMotion: false))
        let stopped = HeroClock(date: date, reduceMotion: true)
        #expect(stopped.themed == HeroCrossfade.still)
        #expect(stopped.day == HeroDayCycle.still)
    }

    @Test func theReadoutFollowsTheUsersClockSetting() {
        let hour = HeroDayCycle.hour(at: HeroDayCycle.still)
        let plain = TimeVariant.clockString(hour: hour, minute: 0, locale: Locale(identifier: "en_GB"))
        let meridiem = TimeVariant.clockString(hour: hour, minute: 0, locale: Locale(identifier: "en_US"))
        #expect(plain == "12:00")
        #expect(meridiem.contains("12:00"))
    }
}
