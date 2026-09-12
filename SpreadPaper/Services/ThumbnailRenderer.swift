// SpreadPaper/Services/ThumbnailRenderer.swift

import CoreGraphics
import Foundation
import ImageIO

/// Downsampled thumbnails via ImageIO, so no AppKit touches a background thread.
/// Keeps nothing decoded after the thumbnail is made, unlike NSImage.
/// Safe to call from any isolation.
enum ThumbnailRenderer {
    /// Builds a thumbnail for the image at `url` whose longest side is `maxPixelSize`.
    /// Applies the EXIF orientation and mirrors horizontally when `flipped`.
    /// Returns nil when the file is missing or not an image.
    nonisolated static func thumbnail(for url: URL, maxPixelSize: Int, flipped: Bool) -> CGImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        return flipped ? mirrored(image) : image
    }

    /// Mirrors `image` horizontally by redrawing it into a fresh sRGB bitmap context.
    /// Source spaces that an 8-bit context rejects (indexed, gray, extended) are
    /// not worth keeping at thumbnail size.
    private nonisolated static func mirrored(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.translateBy(x: CGFloat(width), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
