import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import SpreadPaper

/// Issue #120: the Light & Dark hero shows a light photograph and a dark one.
struct HeroPhotoTests {
    /// Hero height in points, the 260 pt header less its top and bottom insets.
    private static let height: CGFloat = 170

    /// The two hero image sets, each with the file it holds.
    private static let imageSets = [
        (set: "HeroBeach", file: "hero-beach.jpg"),
        (set: "HeroBeachNight", file: "hero-beach-night.jpg")
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

    @Test func bothPhotographsAreTheSameShape() throws {
        let sizes = try Self.imageSets.map { try Self.assetSize($0.set, $0.file) }
        #expect(sizes[0] == sizes[1], "the two hero photographs would slice differently")
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

    @Test func everyPhotographCarriesItsOwnPhotographer() {
        let photos = HeroPhoto.allCases
        #expect(photos.count == 2)
        #expect(photos.allSatisfy { !$0.photographer.isEmpty })
        #expect(Set(photos.map(\.photographer)).count == photos.count)
        #expect(Set(photos.map(\.profile)).count == photos.count)
        #expect(Set(photos.map(\.page)).count == photos.count)
    }

    @Test func theCreditNamesThePhotographBeingShown() {
        #expect(HeroCrossfade.creditOpacity(of: .day, at: 0) == 1)
        #expect(HeroCrossfade.creditOpacity(of: .night, at: 0) == 0)
        let night = HeroCrossfade.hold + HeroCrossfade.fade
        #expect(HeroCrossfade.creditOpacity(of: .night, at: night) == 1)
        #expect(HeroCrossfade.creditOpacity(of: .day, at: night) == 0)
    }

    @Test func onlyOnePhotographerIsEverReadable() {
        let steps = 400
        for step in 0...steps {
            let elapsed = HeroCrossfade.period * Double(step) / Double(steps)
            let day = HeroCrossfade.creditOpacity(of: .day, at: elapsed)
            let dark = HeroCrossfade.creditOpacity(of: .night, at: elapsed)
            #expect(min(day, dark) == 0, "two photographers read at once \(elapsed)s in")
            let showing = HeroCrossfade.nightOpacity(at: elapsed) > 0.5 ? dark : day
            #expect(showing == max(day, dark), "the credit names the photograph behind it")
        }
    }

    @Test func eachPhotographHoldsAloneBeforeItDissolves() {
        #expect(HeroCrossfade.nightOpacity(at: 0) == 0)
        #expect(HeroCrossfade.nightOpacity(at: HeroCrossfade.hold - 0.01) == 0)
        #expect(HeroCrossfade.nightOpacity(at: HeroCrossfade.hold + HeroCrossfade.fade) == 1)
        let heldDark = HeroCrossfade.hold * 2 + HeroCrossfade.fade - 0.01
        #expect(HeroCrossfade.nightOpacity(at: heldDark) == 1)
    }

    @Test func theDissolveRisesAndFallsWithoutAJump() {
        let steps = 200
        var previous = HeroCrossfade.nightOpacity(at: HeroCrossfade.hold)
        for step in 1...steps {
            let elapsed = HeroCrossfade.hold + HeroCrossfade.fade * Double(step) / Double(steps)
            let opacity = HeroCrossfade.nightOpacity(at: elapsed)
            #expect(opacity >= previous, "the dissolve reverses part way in")
            #expect(opacity - previous < 0.05, "the dissolve steps rather than glides")
            previous = opacity
        }
        #expect(previous == 1)
    }

    @Test func theLoopComesBackToWhereItStarted() {
        for step in 0...20 {
            let elapsed = HeroCrossfade.period * Double(step) / 20
            let next = HeroCrossfade.nightOpacity(at: elapsed + HeroCrossfade.period)
            #expect(abs(HeroCrossfade.nightOpacity(at: elapsed) - next) < 0.0001)
        }
        #expect(HeroCrossfade.period == (HeroCrossfade.hold + HeroCrossfade.fade) * 2)
    }

    @Test func reduceMotionHoldsOnOneWholePhotograph() {
        let frozen = HeroCrossfade.nightOpacity(at: HeroCrossfade.still)
        #expect(frozen == 0 || frozen == 1, "a stopped hero would show a half-dissolved blend")
        #expect(HeroCrossfade.creditOpacity(of: .day, at: HeroCrossfade.still) == 1)
        #expect(HeroCrossfade.creditOpacity(of: .night, at: HeroCrossfade.still) == 0)
    }

    @Test func reduceMotionStopsTheClockTheHeroReads() {
        let now = Date()
        let stopped = HeroCrossfade.elapsed(at: now, reduceMotion: true)
        let later = HeroCrossfade.elapsed(at: now.addingTimeInterval(3), reduceMotion: true)
        #expect(stopped == later, "a stopped hero still moves with the clock")
        let running = HeroCrossfade.elapsed(at: now, reduceMotion: false)
        let runningLater = HeroCrossfade.elapsed(at: now.addingTimeInterval(3), reduceMotion: false)
        #expect(runningLater - running == 3, "a running hero does not follow the clock")
    }

    @Test func theLoopReadsTheSameBeforeTheReferenceDate() {
        for step in 0...20 {
            let elapsed = HeroCrossfade.period * Double(step) / 20
            let before = HeroCrossfade.nightOpacity(at: elapsed - HeroCrossfade.period * 3)
            #expect(abs(HeroCrossfade.nightOpacity(at: elapsed) - before) < 0.0001)
        }
        #expect(HeroCrossfade.nightOpacity(at: -HeroCrossfade.fade / 2) > 0)
    }
}
