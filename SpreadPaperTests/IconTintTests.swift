import AppKit
import SwiftUI
import Testing
import PhosphorSwift
@testable import SpreadPaper

/// Issue #116: a Phosphor glyph is tinted by template rendering.
/// PhosphorSwift's own `.color(_:)` draws nothing on macOS 26.
@MainActor
struct IconTintTests {
    /// Every app source, so the scan sees each icon call site.
    private static func appSources() throws -> [URL] {
        let app = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "SpreadPaper")
        let files = FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        #expect(files.count > 10, "source scan found no app files to check")
        return files
    }

    /// sRGB components of a theme token.
    private static func components(_ color: Color) -> (r: Double, g: Double, b: Double) {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? .black
        return (c.redComponent, c.greenComponent, c.blueComponent)
    }

    /// Pixels of a rendered view whose colour is nearer the tint than the ground.
    private static func tintedPixels<V: View>(_ view: V, tint: Color, ground: Color) -> Int {
        let host = NSHostingView(rootView: AnyView(
            ZStack { ground; view }.frame(width: 64, height: 64)
        ))
        host.frame = NSRect(x: 0, y: 0, width: 64, height: 64)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return -1 }
        host.cacheDisplay(in: host.bounds, to: rep)

        let t = components(tint)
        let g = components(ground)
        var hits = 0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let toTint = abs(c.redComponent - t.r) + abs(c.greenComponent - t.g) + abs(c.blueComponent - t.b)
                let toGround = abs(c.redComponent - g.r) + abs(c.greenComponent - g.g) + abs(c.blueComponent - g.b)
                if toTint < toGround { hits += 1 }
            }
        }
        return hits
    }

    @Test func noSourceTintsAGlyphThroughTheBlendModeHelper() throws {
        var offenders: [String] = []
        for file in try Self.appSources() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where line.contains(".color(") {
                offenders.append("\(file.lastPathComponent):\(number + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        #expect(offenders.isEmpty, "glyphs tinted through PhosphorSwift's blend-mode helper:\n\(offenders.joined(separator: "\n"))")
    }

    @Test func theEmptyStateIconContrastsWithItsContainer() {
        let icon = Self.components(.cdTextTertiary)
        let container = Self.components(.cdBgElevated)
        let gap = abs(icon.r - container.r) + abs(icon.g - container.g) + abs(icon.b - container.b)
        #expect(gap > 0.3, "the empty-state glyph is too close to the square behind it")
    }

    @Test func aTintedGlyphDrawsInkInTheTintColour() {
        let hits = Self.tintedPixels(
            Ph.image.regular.cdIcon(Color.cdTextTertiary, size: 40),
            tint: .cdTextTertiary,
            ground: .cdBgElevated
        )
        #expect(hits > 200, "the tinted glyph drew \(hits) pixels in its tint")
    }

    @Test func anUntintedGroundDrawsNoInk() {
        let hits = Self.tintedPixels(
            Color.clear.frame(width: 40, height: 40),
            tint: .cdTextTertiary,
            ground: .cdBgElevated
        )
        #expect(hits == 0, "the control rendered \(hits) tinted pixels with no glyph")
    }
}
