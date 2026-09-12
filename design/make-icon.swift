import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Geometry of the macOS app icon grid on a 1024pt canvas: an 824pt body
/// centred inside transparent margins, with continuous corners whose
/// curvature matches a 185pt radius.
enum IconGrid {
    static let canvas: CGFloat = 1024
    static let body: CGFloat = 824
    static let cornerRadius: CGFloat = 185

    /// How far a continuous corner runs along each edge before the edge goes
    /// straight, as a multiple of the radius. Apple's grid uses 1.528665.
    static let cornerExtentRatio: CGFloat = 1.528665

    /// Superellipse exponent that puts the curvature at the corner's 45°
    /// point at exactly `cornerRadius` over `cornerExtent`.
    static let cornerExponent: CGFloat = 2.67

    static var cornerExtent: CGFloat { cornerRadius * cornerExtentRatio }

    /// The icon body inside the transparent margins, centred on the canvas.
    static var bodyRect: CGRect {
        let inset = (canvas - body) / 2
        return CGRect(x: inset, y: inset, width: body, height: body)
    }
}

/// Samples one continuous corner as points running from the side edge to
/// the end edge of an `extent` square, following a superellipse.
///
/// - Parameters:
///   - extent: Length of the corner along each edge.
///   - exponent: Superellipse exponent; higher is squarer.
///   - steps: Sample count; 512 stays under a pixel at 1024.
/// - Returns: Points from `(0, extent)` to `(extent, 0)`.
func cornerCurve(extent: CGFloat, exponent: CGFloat, steps: Int) -> [CGPoint] {
    (0...steps).map { step in
        let angle = CGFloat(step) / CGFloat(steps) * (.pi / 2)
        let u = pow(cos(angle), 2 / exponent)
        let v = pow(sin(angle), 2 / exponent)
        return CGPoint(x: extent - extent * u, y: extent - extent * v)
    }
}

/// Builds the squircle outline of `rect`: four continuous corners joined by
/// straight edges, as a closed polyline.
///
/// - Parameter rect: Square body rect.
/// - Returns: The closed icon-body path.
func squirclePath(in rect: CGRect) -> CGPath {
    let extent = IconGrid.cornerExtent
    let curve = cornerCurve(extent: extent, exponent: IconGrid.cornerExponent, steps: 512)
    let reversed = curve.reversed()
    let maxX = rect.maxX, maxY = rect.maxY
    var points: [CGPoint] = []
    points += curve.map { CGPoint(x: rect.minX + $0.x, y: rect.minY + $0.y) }
    points += reversed.map { CGPoint(x: maxX - $0.x, y: rect.minY + $0.y) }
    points += curve.map { CGPoint(x: maxX - $0.x, y: maxY - $0.y) }
    points += reversed.map { CGPoint(x: rect.minX + $0.x, y: maxY - $0.y) }
    let path = CGMutablePath()
    path.addLines(between: points)
    path.closeSubpath()
    return path
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

/// Draws the artwork into the 1024px icon body, clipped to the squircle so
/// the margins stay transparent.
///
/// - Parameter artwork: Square source image.
/// - Returns: The masked 1024x1024 icon.
func renderMasked(_ artwork: CGImage) -> CGImage {
    let context = makeContext(side: Int(IconGrid.canvas))
    context.addPath(squirclePath(in: IconGrid.bodyRect))
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

/// Builds every icon size by halving repeatedly from the 1024px master, so
/// each step averages four pixels into one and the 16px tile keeps its
/// contrast instead of aliasing.
///
/// - Parameter master: The masked 1024x1024 icon.
/// - Returns: Each side length mapped to its image.
func iconLadder(from master: CGImage) -> [Int: CGImage] {
    var images = [Int(IconGrid.canvas): master]
    var side = Int(IconGrid.canvas)
    while side > 16 {
        let next = side / 2
        images[next] = resized(images[side]!, to: next)
        side = next
    }
    return images
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

let master = renderMasked(loadImage(at: repoRoot.appending(path: "design/app-icon-source.png")))
let ladder = iconLadder(from: master)

for side in [16, 32, 64, 128, 256, 512, 1024] {
    writePNG(ladder[side]!, to: iconSet.appending(path: "\(side).png"))
}

writePNG(master, to: repoAssets.appending(path: "app-icon.png"))
writePNG(ladder[256]!, to: repoAssets.appending(path: "app-icon-256.png"))
