import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Geometry of the macOS app icon grid on a 1024pt canvas: an 824pt body
/// centred inside transparent margins, with the rounded corner Apple's
/// grid specifies.
enum IconGrid {
    static let canvas: CGFloat = 1024
    static let body: CGFloat = 824
    static let cornerRadius: CGFloat = 185

    static var bodyRect: CGRect {
        let inset = (canvas - body) / 2
        return CGRect(x: inset, y: inset, width: body, height: body)
    }
}

/// Reads the first image in a PNG file, exiting with a message when the
/// file is missing or undecodable.
///
/// - Parameter url: Location of the source PNG.
/// - Returns: The decoded image.
func loadImage(at url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        FileHandle.standardError.write(Data("cannot read \(url.path)\n".utf8))
        exit(1)
    }
    return image
}

/// Creates an empty sRGB bitmap context with premultiplied alpha and
/// high-quality interpolation, sized square at `side`.
///
/// - Parameter side: Width and height in pixels.
/// - Returns: The drawing context.
func makeContext(side: Int) -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        FileHandle.standardError.write(Data("cannot create \(side)px context\n".utf8))
        exit(1)
    }
    context.interpolationQuality = .high
    return context
}

/// Draws the artwork into the 1024px icon body, clipped to the rounded
/// rectangle so the margins stay transparent.
///
/// - Parameter artwork: Square source image.
/// - Returns: The masked 1024x1024 icon.
func renderMasked(_ artwork: CGImage) -> CGImage {
    let context = makeContext(side: Int(IconGrid.canvas))
    let path = CGPath(
        roundedRect: IconGrid.bodyRect,
        cornerWidth: IconGrid.cornerRadius,
        cornerHeight: IconGrid.cornerRadius,
        transform: nil
    )
    context.addPath(path)
    context.clip()
    context.draw(artwork, in: IconGrid.bodyRect)
    guard let image = context.makeImage() else {
        FileHandle.standardError.write(Data("cannot render icon\n".utf8))
        exit(1)
    }
    return image
}

/// Resamples an image to a square of `side` pixels.
///
/// - Parameters:
///   - image: Source image, expected square.
///   - side: Target width and height in pixels.
/// - Returns: The resized image.
func resized(_ image: CGImage, to side: Int) -> CGImage {
    let context = makeContext(side: side)
    context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    guard let output = context.makeImage() else {
        FileHandle.standardError.write(Data("cannot resize to \(side)px\n".utf8))
        exit(1)
    }
    return output
}

/// Writes an image as a PNG, creating the parent directory when needed.
///
/// - Parameters:
///   - image: Image to encode.
///   - url: Destination file.
func writePNG(_ image: CGImage, to url: URL) {
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        FileHandle.standardError.write(Data("cannot write \(url.path)\n".utf8))
        exit(1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        FileHandle.standardError.write(Data("cannot finalize \(url.path)\n".utf8))
        exit(1)
    }
    print("\(url.lastPathComponent) \(image.width)x\(image.height)")
}

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let iconSet = repoRoot.appending(path: "SpreadPaper/Assets.xcassets/AppIcon.appiconset")
let repoAssets = repoRoot.appending(path: ".github/assets")

let masked = renderMasked(loadImage(at: repoRoot.appending(path: "design/app-icon-source.png")))

for side in [16, 32, 64, 128, 256, 512, 1024] {
    let image = side == Int(IconGrid.canvas) ? masked : resized(masked, to: side)
    writePNG(image, to: iconSet.appending(path: "\(side).png"))
}

writePNG(masked, to: repoAssets.appending(path: "app-icon.png"))
writePNG(masked, to: repoAssets.appending(path: "icon.png"))
writePNG(resized(masked, to: 256), to: repoAssets.appending(path: "app-icon-256.png"))
