import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SpreadPaper

/// Issue #74: thumbnails come from ImageIO off the main actor, as a pure function of the file.
struct ThumbnailRendererTests {
    /// Color management shifts pure primaries slightly, so tests classify by dominant channel.
    private struct RGB: Equatable, CustomStringConvertible {
        let r: UInt8, g: UInt8, b: UInt8
        var isRed: Bool { r > 200 && b < 100 }
        var isBlue: Bool { b > 200 && r < 100 }
        var description: String { "(\(r), \(g), \(b))" }
    }

    /// Left half red, right half blue.
    private func makeTwoToneImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        return try #require(context.makeImage())
    }

    /// Left half black, right half white, in an 8-bit gray space.
    private func makeGrayImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        return try #require(context.makeImage())
    }

    /// Encodes `image` to a temp file of type `type`, with optional ImageIO properties.
    private func write(_ image: CGImage, as type: UTType, properties: [CFString: Any]? = nil) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "thumb-\(UUID().uuidString).\(type.preferredFilenameExtension ?? "bin")")
        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL, type.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary?)
        try #require(CGImageDestinationFinalize(destination))
        return url
    }

    /// Two-tone PNG on disk.
    private func writeTwoTonePNG(width: Int, height: Int) throws -> URL {
        try write(try makeTwoToneImage(width: width, height: height), as: .png)
    }

    /// Samples one pixel. ImageIO picks its own pixel layout, so the image is
    /// redrawn into a known 32-bit layout first.
    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> RGB {
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let normalized = try #require(context.makeImage())
        let data = try #require(normalized.dataProvider?.data) as Data
        let index = y * normalized.bytesPerRow + x * 4
        return RGB(r: data[index], g: data[index + 1], b: data[index + 2])
    }

    @Test func longestSideIsCappedAndAspectIsKept() throws {
        let url = try writeTwoTonePNG(width: 2000, height: 1000)
        defer { try? FileManager.default.removeItem(at: url) }
        let thumb = try #require(ThumbnailRenderer.thumbnail(for: url, maxPixelSize: 480, flipped: false))
        #expect(thumb.width == 480)
        #expect(thumb.height == 240)
    }

    @Test func unflippedKeepsLeftRed() throws {
        let url = try writeTwoTonePNG(width: 2000, height: 1000)
        defer { try? FileManager.default.removeItem(at: url) }
        let thumb = try #require(ThumbnailRenderer.thumbnail(for: url, maxPixelSize: 480, flipped: false))
        #expect(try pixel(thumb, x: 20, y: 120).isRed)
        #expect(try pixel(thumb, x: 460, y: 120).isBlue)
    }

    @Test func flippedSwapsLeftAndRight() throws {
        let url = try writeTwoTonePNG(width: 2000, height: 1000)
        defer { try? FileManager.default.removeItem(at: url) }
        let thumb = try #require(ThumbnailRenderer.thumbnail(for: url, maxPixelSize: 480, flipped: true))
        #expect(thumb.width == 480)
        #expect(thumb.height == 240)
        #expect(try pixel(thumb, x: 20, y: 120).isBlue)
        #expect(try pixel(thumb, x: 460, y: 120).isRed)
    }

    @Test func smallSourceIsNotUpscaled() throws {
        let url = try writeTwoTonePNG(width: 200, height: 100)
        defer { try? FileManager.default.removeItem(at: url) }
        let thumb = try #require(ThumbnailRenderer.thumbnail(for: url, maxPixelSize: 480, flipped: false))
        #expect(thumb.width == 200)
        #expect(thumb.height == 100)
    }

    @Test func exifMirrorTagIsApplied() throws {
        // Orientation 2 is "mirrored horizontally": stored red-left, displayed blue-left.
        let url = try write(
            try makeTwoToneImage(width: 2000, height: 1000), as: .jpeg,
            properties: [kCGImagePropertyOrientation: CGImagePropertyOrientation.upMirrored.rawValue]
        )
        defer { try? FileManager.default.removeItem(at: url) }
        let thumb = try #require(ThumbnailRenderer.thumbnail(for: url, maxPixelSize: 480, flipped: false))
        #expect(try pixel(thumb, x: 20, y: 120).isBlue)
        #expect(try pixel(thumb, x: 460, y: 120).isRed)
    }

    @Test func exifRotationTagSwapsDimensions() throws {
        let url = try write(
            try makeTwoToneImage(width: 2000, height: 1000), as: .jpeg,
            properties: [kCGImagePropertyOrientation: CGImagePropertyOrientation.right.rawValue]
        )
        defer { try? FileManager.default.removeItem(at: url) }
        let thumb = try #require(ThumbnailRenderer.thumbnail(for: url, maxPixelSize: 480, flipped: false))
        #expect(thumb.width == 240)
        #expect(thumb.height == 480)
    }

    @Test func grayscaleSourceCanBeFlipped() throws {
        let url = try write(try makeGrayImage(width: 2000, height: 1000), as: .png)
        defer { try? FileManager.default.removeItem(at: url) }
        let thumb = try #require(ThumbnailRenderer.thumbnail(for: url, maxPixelSize: 480, flipped: true))
        #expect(thumb.width == 480)
        #expect(thumb.height == 240)
        let left = try pixel(thumb, x: 20, y: 120)
        let right = try pixel(thumb, x: 460, y: 120)
        #expect(left.r > 200 && left.g > 200 && left.b > 200)
        #expect(right.r < 50 && right.g < 50 && right.b < 50)
    }

    @Test func nonImageFileReturnsNil() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "thumb-\(UUID().uuidString).txt")
        try Data("not an image".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(ThumbnailRenderer.thumbnail(for: url, maxPixelSize: 480, flipped: false) == nil)
    }

    @Test func missingFileReturnsNil() {
        let url = FileManager.default.temporaryDirectory.appending(path: "thumb-\(UUID().uuidString).png")
        #expect(ThumbnailRenderer.thumbnail(for: url, maxPixelSize: 480, flipped: false) == nil)
    }

    // MARK: - Covering a frame

    /// The frame an entry thumbnail fills, in pixels on a retina display.
    private let entryFrame = CGSize(width: 144, height: 90)

    @Test func aPanoramaStillCoversTheFrameItFills() throws {
        let url = try writeTwoTonePNG(width: 8000, height: 1000)
        defer { try? FileManager.default.removeItem(at: url) }
        let thumb = try #require(ThumbnailRenderer.thumbnail(for: url, covering: entryFrame, flipped: false))
        #expect(CGFloat(thumb.width) >= entryFrame.width)
        #expect(CGFloat(thumb.height) >= entryFrame.height)
    }

    @Test func aTowerStillCoversTheFrameItFills() throws {
        let url = try writeTwoTonePNG(width: 1000, height: 8000)
        defer { try? FileManager.default.removeItem(at: url) }
        let thumb = try #require(ThumbnailRenderer.thumbnail(for: url, covering: entryFrame, flipped: false))
        #expect(CGFloat(thumb.width) >= entryFrame.width)
        #expect(CGFloat(thumb.height) >= entryFrame.height)
    }

    @Test func aSourceSmallerThanTheFrameIsNotBlownUp() throws {
        let url = try writeTwoTonePNG(width: 40, height: 20)
        defer { try? FileManager.default.removeItem(at: url) }
        let thumb = try #require(ThumbnailRenderer.thumbnail(for: url, covering: entryFrame, flipped: false))
        #expect(thumb.width == 40)
        #expect(thumb.height == 20)
    }

    @Test func aCoveringSideScalesTheLongEdgeWithTheShortOne() {
        let frame = CGSize(width: 144, height: 90)
        #expect(ThumbnailRenderer.coveringSide(source: CGSize(width: 8000, height: 1000), target: frame) == 720)
        #expect(ThumbnailRenderer.coveringSide(source: CGSize(width: 1000, height: 8000), target: frame) == 1152)
        #expect(ThumbnailRenderer.coveringSide(source: CGSize(width: 1600, height: 1000), target: frame) == 144)
    }

    @Test func anUnreadableSourceFallsBackToTheFramesLongestSide() {
        let frame = CGSize(width: 144, height: 90)
        #expect(ThumbnailRenderer.coveringSide(source: .zero, target: frame) == 144)
    }

    @Test func pixelSizeReadsTheFileWithoutDecodingIt() throws {
        let url = try writeTwoTonePNG(width: 2000, height: 1000)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(ThumbnailRenderer.pixelSize(of: url) == CGSize(width: 2000, height: 1000))
    }

    @Test func pixelSizeSwapsTheSidesOfAQuarterTurnedFile() throws {
        let image = try makeTwoToneImage(width: 2000, height: 1000)
        let url = try write(
            image, as: .jpeg,
            properties: [kCGImagePropertyOrientation: CGImagePropertyOrientation.right.rawValue]
        )
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(ThumbnailRenderer.pixelSize(of: url) == CGSize(width: 1000, height: 2000))
    }

    @Test func pixelSizeOfSomethingThatIsNotAnImageIsNil() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "thumb-\(UUID().uuidString).txt")
        try Data("not an image".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(ThumbnailRenderer.pixelSize(of: url) == nil)
    }
}
