import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import SpreadPaper

/// Issue #59: rendering runs off the main actor, so it must be a pure function of its inputs.
struct WallpaperRendererTests {
    /// Color management shifts pure primaries slightly (blue lands near 4,51,255), so tests
    /// classify by dominant channel instead of comparing exact bytes.
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

    /// Top half red, bottom half blue. CGImage row 0 is the top row.
    private func makeTopBottomImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        // CGContext origin is bottom-left, so the top half is the upper y range.
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: height / 2, width: width, height: height / 2))
        return try #require(context.makeImage())
    }

    /// Samples one pixel. Guards the layout assumptions the index math depends on.
    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> RGB {
        try #require(image.bitsPerPixel == 32)
        try #require(image.alphaInfo == .noneSkipLast)
        let data = try #require(image.dataProvider?.data) as Data
        let index = y * image.bytesPerRow + x * 4
        return RGB(r: data[index], g: data[index + 1], b: data[index + 2])
    }

    /// Two 100x100 point displays side by side, image exactly covering both.
    private func spec(screenX: CGFloat, deviceScale: CGFloat = 1, flipped: Bool = false) -> RenderSpec {
        RenderSpec(
            screenFrame: CGRect(x: screenX, y: 0, width: 100, height: 100),
            totalCanvas: CGRect(x: 0, y: 0, width: 200, height: 100),
            offset: .zero,
            imageScale: 1,
            previewScale: 1,
            isFlipped: flipped,
            deviceScale: deviceScale,
            colorSpace: nil
        )
    }

    @Test func outputMatchesDisplayPixelSize() throws {
        let source = try makeTwoToneImage(width: 200, height: 100)
        let output = try WallpaperRenderer.render(source, spec: spec(screenX: 0, deviceScale: 2))
        #expect(output.width == 200)
        #expect(output.height == 200)
    }

    @Test func leftDisplayShowsLeftHalfOfImage() throws {
        let source = try makeTwoToneImage(width: 200, height: 100)
        let output = try WallpaperRenderer.render(source, spec: spec(screenX: 0))
        #expect(try pixel(output, x: 50, y: 50).isRed)
    }

    @Test func rightDisplayShowsRightHalfOfImage() throws {
        let source = try makeTwoToneImage(width: 200, height: 100)
        let output = try WallpaperRenderer.render(source, spec: spec(screenX: 100))
        #expect(try pixel(output, x: 50, y: 50).isBlue)
    }

    @Test func mirroringSwapsHalves() throws {
        let source = try makeTwoToneImage(width: 200, height: 100)
        let output = try WallpaperRenderer.render(source, spec: spec(screenX: 0, flipped: true))
        #expect(try pixel(output, x: 50, y: 50).isBlue)
    }

    @Test func bezelGapSkipsHiddenStrip() throws {
        // With a 20pt gap the right display starts at x=120 in a 220-wide canvas; the image is
        // stretched to 220 so the boundary sits at x=110. Its left edge pixel is still blue.
        let source = try makeTwoToneImage(width: 220, height: 100)
        var s = spec(screenX: 120)
        s.totalCanvas = CGRect(x: 0, y: 0, width: 220, height: 100)
        let output = try WallpaperRenderer.render(source, spec: s)
        #expect(try pixel(output, x: 0, y: 50).isBlue)
    }

    @Test func topOfImageLandsAtTopOfDisplay() throws {
        let source = try makeTopBottomImage(width: 200, height: 100)
        let output = try WallpaperRenderer.render(source, spec: spec(screenX: 0))
        #expect(try pixel(output, x: 50, y: 10).isRed)
        #expect(try pixel(output, x: 50, y: 90).isBlue)
    }

    @Test func horizontalOffsetShiftsBoundaryRight() throws {
        let source = try makeTwoToneImage(width: 200, height: 100)
        var s = spec(screenX: 0)
        s.offset = CGSize(width: 50, height: 0)
        let output = try WallpaperRenderer.render(source, spec: s)
        // Boundary moved from x=100 to x=150 on the canvas: x=125 is now red.
        #expect(try pixel(output, x: 99, y: 50).isRed)
        var right = spec(screenX: 100)
        right.offset = CGSize(width: 50, height: 0)
        let rightOut = try WallpaperRenderer.render(source, spec: right)
        #expect(try pixel(rightOut, x: 25, y: 50).isRed)
        #expect(try pixel(rightOut, x: 75, y: 50).isBlue)
    }

    @Test func positiveVerticalOffsetMovesImageDown() throws {
        // Editor offsets are in SwiftUI space where +y is down.
        let source = try makeTopBottomImage(width: 200, height: 100)
        var s = spec(screenX: 0)
        s.offset = CGSize(width: 0, height: 30)
        let output = try WallpaperRenderer.render(source, spec: s)
        // Red/blue boundary moved from y=50 to y=80: y=65 is now red.
        #expect(try pixel(output, x: 50, y: 65).isRed)
        #expect(try pixel(output, x: 50, y: 95).isBlue)
    }

    @Test func previewScaleDividesOffset() throws {
        let source = try makeTwoToneImage(width: 200, height: 100)
        var s = spec(screenX: 0)
        s.offset = CGSize(width: 100, height: 0)
        s.previewScale = 2
        let output = try WallpaperRenderer.render(source, spec: s)
        // Offset of 100 preview points at previewScale 2 is 50 canvas points.
        #expect(try pixel(output, x: 99, y: 50).isRed)
    }

    @Test func imageScaleEnlargesTheSource() throws {
        // A 100-wide source at scale 2 covers the 200-wide canvas exactly.
        let source = try makeTwoToneImage(width: 100, height: 50)
        var s = spec(screenX: 100)
        s.imageScale = 2
        let output = try WallpaperRenderer.render(source, spec: s)
        #expect(try pixel(output, x: 50, y: 50).isBlue)
    }

    @Test func retinaDisplayPlacesCropInPixels() throws {
        let source = try makeTwoToneImage(width: 200, height: 100)
        let output = try WallpaperRenderer.render(source, spec: spec(screenX: 100, deviceScale: 2))
        #expect(output.width == 200)
        #expect(try pixel(output, x: 100, y: 100).isBlue)
        let left = try WallpaperRenderer.render(source, spec: spec(screenX: 0, deviceScale: 2))
        #expect(try pixel(left, x: 100, y: 100).isRed)
    }

    @Test func outputUsesRequestedColorSpace() throws {
        let source = try makeTwoToneImage(width: 20, height: 10)
        var s = spec(screenX: 0)
        s.colorSpace = CGColorSpace(name: CGColorSpace.displayP3)
        let output = try WallpaperRenderer.render(source, spec: s)
        #expect(output.colorSpace?.name == CGColorSpace.displayP3)
    }

    @Test func zeroSizedDisplayThrows() throws {
        let source = try makeTwoToneImage(width: 10, height: 10)
        var s = spec(screenX: 0)
        s.screenFrame.size = .zero
        #expect(throws: WallpaperError.self) { try WallpaperRenderer.render(source, spec: s) }
    }

    @Test func pngDataStartsWithPNGSignature() throws {
        let source = try makeTwoToneImage(width: 4, height: 4)
        let data = try WallpaperRenderer.pngData(source)
        #expect(Array(data.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let decoded = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(decoded, 0, nil))
        #expect(image.width == 4 && image.height == 4)
    }
}
