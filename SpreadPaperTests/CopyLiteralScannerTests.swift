import Foundation
import Testing

/// A snippet and the copy a sound scan finds in it.
private struct Shape {
    let name: String
    let source: String
    let fragments: [String]
}

/// A snippet the scanner must refuse, with the line it names.
private struct Unreadable {
    let name: String
    let source: String
    let line: Int
}

/// A snippet with a `FAULT` slot for banned punctuation.
private struct BlindSpot {
    let name: String
    let template: String
}

/// The extractor behind the copy guard, shape by shape.
/// Comments, interpolations, escapes, joins.
struct CopyLiteralScannerTests {
    /// Copy a user reads, and the Swift shapes that hold it.
    private static let shapes: [Shape] = [
        Shape(
            name: "a plain literal",
            source: #"let label = "Pick an image.""#,
            fragments: ["Pick an image."]
        ),
        Shape(
            name: "a line comment quoting copy",
            source: #"""
                // "One image — spread."
                let label = "Clean."
                """#,
            fragments: ["Clean."]
        ),
        Shape(
            name: "a doc comment quoting copy",
            source: #"""
                /// Pixel size as "width×height".
                let label = "Size"
                """#,
            fragments: ["Size"]
        ),
        Shape(
            name: "a comment holding one unbalanced quote",
            source: #"""
                // The gallery calls it a "preset
                let label = "Preset"
                """#,
            fragments: ["Preset"]
        ),
        Shape(
            name: "a block comment quoting copy",
            source: #"""
                /* "One image — spread." */
                let label = "Clean."
                """#,
            fragments: ["Clean."]
        ),
        Shape(
            name: "a comment marker inside a literal",
            source: #"let home = "https://example.com/a""#,
            fragments: ["https://example.com/a"]
        ),
        Shape(
            name: "the app's ternary interpolation",
            source: #"Text("\(count) item\(count == 1 ? "" : "s") left")"#,
            fragments: [" item", "s", " left"]
        ),
        Shape(
            name: "a literal nested in an interpolation",
            source: #"Text("\(isPair ? "Light and Dark" : "Dynamic") ready")"#,
            fragments: ["Light and Dark", "Dynamic", " ready"]
        ),
        Shape(
            name: "an interpolation nesting parens",
            source: #"Text("Gap \(Int(round(gap * 2))) points")"#,
            fragments: ["Gap ", " points"]
        ),
        Shape(
            name: "escaped quotes around an interpolation",
            source: #"let empty = "No wallpapers match \"\(query)\" in \(filter.label).""#,
            fragments: ["No wallpapers match \"", "\" in ", "."]
        ),
        Shape(
            name: "a multiline literal",
            source: #"""
                let blurb = """
                    Spread one image
                    across every screen.
                    """
                """#,
            fragments: ["Spread one image\nacross every screen."]
        ),
        Shape(
            name: "a multiline literal around an interpolation",
            source: #"""
                let blurb = """
                    Across \(count) screens
                    at once.
                    """
                """#,
            fragments: ["Across ", " screens\nat once."]
        ),
        Shape(
            name: "a multiline literal with a line continuation",
            source: #"""
                let blurb = """
                    One image \
                    spread.
                    """
                """#,
            fragments: ["One image spread."]
        ),
        Shape(
            name: "a bare regex ending in an escaped slash",
            source: #"let pattern = /a\/\//; let label = "Clean.""#,
            fragments: ["Clean."]
        ),
        Shape(
            name: "a concatenation across two lines",
            source: #"""
                let blurb = "One image " +
                    " spread."
                """#,
            fragments: ["One image  spread."]
        ),
        Shape(
            name: "a concatenation broken by a value",
            source: #"let blurb = "One " + name + " spread.""#,
            fragments: ["One ", " spread."]
        ),
        Shape(
            name: "a unicode escape",
            source: #"let label = "One \u{2014} two""#,
            fragments: ["One \u{2014} two"]
        ),
        Shape(
            name: "a backslash escape",
            source: #"let cleaned = name.replacingOccurrences(of: "\\", with: "-")"#,
            fragments: ["\\", "-"]
        ),
        Shape(
            name: "a raw literal keeping its backslash",
            source: ##"let pattern = #"a\nb"#"##,
            fragments: ["a\\nb"]
        ),
        Shape(
            name: "a bare regex literal",
            source: #"let stale = name.wholeMatch(of: /wall_\d+\.png/) == nil"#,
            fragments: []
        ),
        Shape(
            name: "an extended regex literal",
            source: ##"let found = header.firstMatch(of: #/\[?(?<version>\d+)\]?/#)"##,
            fragments: []
        )
    ]

    /// Constructs the scanner refuses rather than passing over.
    private static let unreadable: [Unreadable] = [
        Unreadable(
            name: "a literal left open",
            source: "let label = \"One image\nlet other = 2\n",
            line: 1
        ),
        Unreadable(
            name: "an odd number of quotes on a line",
            source: "let label = \"One image \" spread.\"\n",
            line: 1
        ),
        Unreadable(
            name: "an escape the scanner does not know",
            source: "let label = \"One \\q two\"\n",
            line: 1
        ),
        Unreadable(
            name: "an interpolation left open",
            source: "let label = \"Across \\(count\n",
            line: 1
        ),
        Unreadable(
            name: "a multiline literal left open",
            source: "let blurb = \"\"\"\n    One image\n",
            line: 1
        ),
        Unreadable(
            name: "a block comment left open",
            source: "/* a note\nlet label = \"Clean.\"\n",
            line: 1
        ),
        Unreadable(
            name: "a unicode escape without braces",
            source: "let label = \"One \\u2014 two\"\n",
            line: 1
        ),
        Unreadable(
            name: "a literal left open further down the file",
            source: "let first = \"Clean.\"\nlet second = \"Also clean.\"\nlet third = \"One image\nlet fourth = 4\n",
            line: 3
        )
    ]

    /// Where the old line scanner saw nothing, with a slot for a fault.
    private static let blindSpots: [BlindSpot] = [
        BlindSpot(
            name: "a multiline literal body",
            template: #"""
                let blurb = """
                    OneFAULTtwo
                    """
                """#
        ),
        BlindSpot(
            name: "a multiline literal beside an interpolation",
            template: #"""
                let blurb = """
                    \(count) screensFAULTat once
                    """
                """#
        ),
        BlindSpot(
            name: "a literal under a comment quoting copy",
            template: #"""
                // "One image — spread."
                let label = "OneFAULTtwo"
                """#
        ),
        BlindSpot(
            name: "a literal around an interpolation",
            template: #"Text("\(count) itemFAULTleft")"#
        ),
        BlindSpot(
            name: "a literal nested in an interpolation",
            template: #"Text("\(isPair ? "OneFAULTtwo" : "Dynamic")")"#
        ),
        BlindSpot(
            name: "a literal written with unicode escapes",
            template: #"let label = "OneESCAPEDtwo""#
        ),
        BlindSpot(
            name: "a literal beside a bare regex ending in an escaped slash",
            template: #"let pattern = /a\/\//; let label = "OneFAULTtwo""#
        )
    ]

    /// Copy the app already ships, none of it a fault.
    private static let quiet: [String] = [
        #"Text("\(filteredPresets.count) item\(filteredPresets.count == 1 ? "" : "s")")"#,
        #"return "\(count) display\(count == 1 ? "" : "s") connected""#,
        #"showToast("Added \(added) image\(added == 1 ? "" : "s")")"#,
        #"Text("\(count) item\(count == 1 ?  "" :  "s") left")"#,
        #"let empty = "No wallpapers match \"\(query)\" in \(filter.label).""#,
        #"/// Was "One image — spread." before the rewrite."#,
        #"// Two  spaces and an — em dash, read by nobody."#,
        #"let home = "https://example.com/a""#,
        #"let cleaned = name.replacingOccurrences(of: "\\", with: "-")"#,
        #"let stale = name.wholeMatch(of: /wall_\d+_\d{10,}\.heic/) == nil"#
    ]

    /// The banned faults, written as a source file holds them.
    private static let faults: [(name: String, text: String)] = [
        ("an em dash", "\u{2014}"),
        ("an en dash", " \u{2013} "),
        ("a double space", "  ")
    ]

    /// The same text written as unicode escapes.
    private static func escaped(_ text: String) -> String {
        text.unicodeScalars.map { String(format: "\\u{%04X}", $0.value) }.joined()
    }

    /// One snippet's offences, as the app-wide guard collects them.
    private static func offences(in source: String) -> [String] {
        UserFacingCopyTests.offences(in: source, file: "Fixture.swift")
    }

    @Test func theExtractorReadsEachShapeAsTheCompilerWould() throws {
        for shape in Self.shapes {
            let found = try CopyLiteralScanner.fragments(in: shape.source, file: "Fixture.swift")
            #expect(found.map(\.text) == shape.fragments, "\(shape.name) read as \(found.map(\.text))")
        }
    }

    @Test func theExtractorRefusesWhatItCannotRead() {
        for shape in Self.unreadable {
            do {
                let found = try CopyLiteralScanner.fragments(in: shape.source, file: "Fixture.swift")
                Issue.record("\(shape.name) read as \(found.map(\.text)) instead of failing")
            } catch let failure as CopyScanError {
                #expect(failure.file == "Fixture.swift", "\(shape.name) named \(failure.file)")
                #expect(failure.line == shape.line, "\(shape.name) named line \(failure.line)")
            } catch {
                Issue.record("\(shape.name) threw \(error)")
            }
        }
    }

    @Test func anUnreadableConstructFailsTheGuard() {
        let offences = Self.offences(in: "let label = \"One image\nlet other = 2\n")
        #expect(offences.count == 1)
        #expect(offences.first?.contains("Fixture.swift:1") == true, "\(offences)")
        #expect(offences.first?.contains("unchecked") == true, "\(offences)")
    }

    @Test func everyFaultInEveryBlindSpotIsCaught() {
        for spot in Self.blindSpots {
            for fault in Self.faults {
                let source = spot.template
                    .replacingOccurrences(of: "ESCAPED", with: Self.escaped(fault.text))
                    .replacingOccurrences(of: "FAULT", with: fault.text)
                let reported = Self.offences(in: source)
                #expect(reported.count == 1, "\(fault.name) in \(spot.name) reported \(reported)")
                #expect(
                    reported.first?.contains(fault.name) == true,
                    "\(fault.name) in \(spot.name) reported \(reported)"
                )
                let line = source.contains("\n") ? "Fixture.swift:2" : "Fixture.swift:1"
                #expect(reported.first?.contains(line) == true, "\(fault.name) in \(spot.name) reported \(reported)")
            }
        }
    }

    @Test func aFaultSplitAcrossAConcatenationIsCaught() {
        let doubleSpace = "let blurb = \"One image \" +\n    \" spread.\"\n"
        #expect(!Self.offences(in: doubleSpace).isEmpty, "a double space across a concatenation went unreported")
        let enDash = "let blurb = \"One image \" +\n    \"\u{2013} spread.\"\n"
        #expect(!Self.offences(in: enDash).isEmpty, "an en dash across a concatenation went unreported")
    }

    @Test func aReportedFaultNamesItsFileLineAndString() {
        let offences = Self.offences(in: "let a = \"Fine.\"\nlet b = \"One\u{2014}two\"\n")
        #expect(offences.count == 1, "\(offences)")
        #expect(offences.first?.contains("Fixture.swift:2") == true, "\(offences)")
        #expect(offences.first?.contains("an em dash") == true, "\(offences)")
        #expect(offences.first?.contains("One") == true, "\(offences)")
    }

    @Test func windowsLineEndingsReadLikePlainOnes() {
        let offences = Self.offences(in: "// a note\r\nlet label = \"One\u{2014}two\"\r\n")
        #expect(offences.count == 1, "\(offences)")
        #expect(offences.first?.contains("Fixture.swift:2") == true, "\(offences)")
    }

    @Test func theShapesTheAppAlreadyWritesStayQuiet() {
        for source in Self.quiet {
            #expect(Self.offences(in: source).isEmpty, "\(source) reported \(Self.offences(in: source))")
        }
    }
}
