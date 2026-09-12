import CoreGraphics
import Foundation
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

    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> RGB {
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
    }
}
