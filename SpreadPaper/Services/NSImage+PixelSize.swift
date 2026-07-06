import AppKit

extension NSImage {
    nonisolated var pixelSize: CGSize {
        if let bitmapRep = representations
            .compactMap({ $0 as? NSBitmapImageRep })
            .max(by: { ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh) }) {
            return CGSize(width: bitmapRep.pixelsWide, height: bitmapRep.pixelsHigh)
        }

        if let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }

        return size
    }
}
