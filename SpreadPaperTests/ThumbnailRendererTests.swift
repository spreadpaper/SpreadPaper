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

    /// Writes a PNG with the left half red and the right half blue, returning its URL.
    private func writeTwoTonePNG(width: Int, height: Int) throws -> URL {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        let image = try #require(context.makeImage())

        let url = FileManager.default.temporaryDirectory.appending(path: "thumb-\(UUID().uuidString).png")
        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return url
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
}
