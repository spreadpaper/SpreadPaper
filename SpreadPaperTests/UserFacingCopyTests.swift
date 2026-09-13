import AppKit
import Foundation
import Testing
@testable import SpreadPaper

/// The copy the user reads stays plain and wraps cleanly.
/// No typographic dashes, no padded spacing.
struct UserFacingCopyTests {
    /// Narrowest place a kind description renders: the editor inspector, 340pt inset by 28pt a side.
    /// The creation modal gives it 536pt at 14pt.
    private static let inspector = (width: 284.0, size: 12.0)

    /// What a string literal may never contain, with the name shown on a failure.
    private static let banned: [(needle: String, name: String)] = [
        ("\u{2014}", "an em dash"),
        (" \u{2013} ", "an en dash as punctuation"),
        ("  ", "a double space")
    ]

    /// Banned punctuation in one file's copy, as `file:line: fault` lines.
    /// A construct the scanner cannot read is a fault too.
    static func offences(in source: String, file: String) -> [String] {
        do {
            return try CopyLiteralScanner.fragments(in: source, file: file).flatMap { fragment in
                banned.filter { fragment.text.contains($0.needle) }
                    .map { "\(file):\(fragment.line): \($0.name) in \"\(fragment.text)\"" }
            }
        } catch let failure as CopyScanError {
            return ["\(failure.description), so the copy here goes unchecked"]
        } catch {
            return ["\(file): the scan failed with \(error)"]
        }
    }

    @Test func noStringInTheAppUsesADashOrDoubleSpace() throws {
        var offenders: [String] = []
        for file in try AppSources.all() {
            let source = try String(contentsOf: file, encoding: .utf8)
            offenders += Self.offences(in: source, file: file.lastPathComponent)
        }
        #expect(offenders.isEmpty, "banned punctuation in app strings:\n\(offenders.joined(separator: "\n"))")
    }

    /// Width one string takes at the inspector's font, with no wrapping.
    private static func width(_ text: String) -> Double {
        let font = NSFont.systemFont(ofSize: Self.inspector.size)
        return NSAttributedString(string: text, attributes: [.font: font]).size().width
    }

    @Test func everyKindDescriptionFitsTheNarrowestPlaceItRenders() {
        for type in WallpaperType.allCases {
            let subtitle = type.subtitle
            let width = Self.width(subtitle)
            #expect(
                width <= Self.inspector.width,
                "\(type.title) takes \(Int(width))pt of the inspector's \(Int(Self.inspector.width))pt, so it wraps"
            )
            #expect(subtitle.hasSuffix("."), "\(type.title) does not end in a full stop")
            #expect(!subtitle.contains("\n"), "\(type.title) carries its own line break")
        }
    }

    @Test func theDisplayCountReadsTheSameOnEveryScreen() {
        #expect(DisplayInfo.countLabel(0) == "No displays connected")
        #expect(DisplayInfo.countLabel(1) == "1 display connected")
        #expect(DisplayInfo.countLabel(3) == "3 displays connected")
    }

    @Test func theKindDescriptionsAreCloseInWidth() {
        let widths = WallpaperType.allCases.map { Self.width($0.subtitle) }
        guard let shortest = widths.min(), let longest = widths.max() else { return }
        #expect(longest - shortest <= 60, "kind descriptions run \(widths.map { Int($0) })pt, too uneven to read as a set")
    }
}
