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

    /// Builds a thumbnail for the image at `url` large enough to cover `target` pixels.
    /// A very wide or very tall source keeps the detail a capped longest
    /// side would spend on its long edge alone.
    nonisolated static func thumbnail(for url: URL, covering target: CGSize, flipped: Bool) -> CGImage? {
        let side = coveringSide(source: pixelSize(of: url) ?? .zero, target: target)
        return thumbnail(for: url, maxPixelSize: side, flipped: flipped)
    }

    /// Longest side a thumbnail of `source` needs before it covers `target`.
    /// A source of unknown size falls back to the target's longest side.
    nonisolated static func coveringSide(source: CGSize, target: CGSize) -> Int {
        let longestTarget = max(target.width, target.height)
        guard source.width > 0, source.height > 0 else { return Int(longestTarget.rounded(.up)) }
        let cover = max(target.width / source.width, target.height / source.height)
        return max(1, Int((cover * max(source.width, source.height)).rounded(.up)))
    }

    /// Pixel dimensions of the image at `url`, read without decoding it.
    /// A quarter turn in the EXIF orientation swaps the two.
    nonisolated static func pixelSize(of url: URL) -> CGSize? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let isTurned = (5...8).contains(orientation)
        return isTurned ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
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
