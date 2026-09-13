import Foundation
import Testing
@testable import SpreadPaper

/// Issue #123: the copy the user reads stays plain and wraps cleanly.
/// Strings carry no typographic dashes and no padded spacing.
struct UserFacingCopyTests {
    /// Longest a kind description may be and still fit the caption on one line.
    private static let subtitleLimit = 60

    /// What a string literal may never contain, with the name shown on a failure.
    private static let banned: [(needle: String, name: String)] = [
        ("\u{2014}", "an em dash"),
        (" \u{2013} ", "an en dash as punctuation"),
        ("  ", "a double space")
    ]

    /// Every double-quoted run on a line, interpolations and escapes included.
    private static func literals(in line: Substring) -> [String] {
        var found: [String] = []
        var current: String?
        var escaped = false
        for character in line {
            if escaped {
                current?.append(character)
                escaped = false
                continue
            }
            if character == "\\" {
                current?.append(character)
                escaped = current != nil
                continue
            }
            if character == "\"" {
                if let literal = current {
                    found.append(literal)
                    current = nil
                } else {
                    current = ""
                }
                continue
            }
            current?.append(character)
        }
        return found
    }

    @Test func noStringInTheAppUsesADashOrDoubleSpace() throws {
        var offenders: [String] = []
        for file in try AppSources.all() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                for literal in Self.literals(in: line) {
                    for rule in Self.banned where literal.contains(rule.needle) {
                        offenders.append("\(file.lastPathComponent):\(number + 1): \(rule.name) in \"\(literal)\"")
                    }
                }
            }
        }
        #expect(offenders.isEmpty, "banned punctuation in app strings:\n\(offenders.joined(separator: "\n"))")
    }

    @Test func everyKindDescriptionIsOneShortSentence() {
        for type in WallpaperType.allCases {
            let subtitle = type.subtitle
            #expect(subtitle.count <= Self.subtitleLimit, "\(type.title) runs \(subtitle.count) characters")
            #expect(subtitle.hasSuffix("."), "\(type.title) does not end in a full stop")
            #expect(!subtitle.contains("\n"), "\(type.title) carries its own line break")
        }
    }

    @Test func theKindDescriptionsAreCloseInLength() {
        let lengths = WallpaperType.allCases.map(\.subtitle.count)
        guard let shortest = lengths.min(), let longest = lengths.max() else { return }
        #expect(longest - shortest <= 16, "kind descriptions run \(lengths), too uneven to wrap alike")
    }
}
