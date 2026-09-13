import Foundation

/// One run of literal text the compiler hands the app, and where it starts.
/// Interpolated code is no part of it.
struct CopyFragment: Equatable {
    var text: String
    var line: Int
}

/// A construct the scanner cannot read, named by file and line.
/// The copy guard reports it as a failure.
struct CopyScanError: Error, CustomStringConvertible, Equatable {
    let file: String
    let line: Int
    let reason: String

    var description: String { "\(file):\(line): \(reason)" }
}

/// Swift string literals as the compiler would build them.
/// Comments and interpolated code stay out.
struct CopyLiteralScanner {
    /// Where one literal sits, and how to read its body.
    private struct Span {
        let body: Range<Int>
        let end: Int
        let pounds: Int
        let indent: Int
    }

    private let chars: [Character]
    private let lineNumbers: [Int]
    private let file: String

    /// Every literal run in one source file, in source order.
    /// Throws on anything it cannot read.
    static func fragments(in source: String, file: String) throws -> [CopyFragment] {
        try CopyLiteralScanner(source: source, file: file).scan()
    }

    /// Keeps the source as characters, with each one's line.
    /// Windows line endings become plain ones.
    private init(source: String, file: String) {
        let characters = Array(source.replacingOccurrences(of: "\r\n", with: "\n"))
        var numbers: [Int] = []
        numbers.reserveCapacity(characters.count)
        var line = 1
        for character in characters {
            numbers.append(line)
            if character == "\n" { line += 1 }
        }
        chars = characters
        lineNumbers = numbers
        self.file = file
    }

    /// Walks the file, joining literals a `+` concatenates.
    /// Comments and whitespace break no join.
    private func scan() throws -> [CopyFragment] {
        var fragments: [CopyFragment] = []
        var pending: CopyFragment?
        var afterLiteral = false
        var joining = false
        var index = 0

        func flush() {
            if let open = pending, !open.text.isEmpty { fragments.append(open) }
            pending = nil
        }

        while index < chars.count {
            let character = chars[index]
            if character == " " || character == "\t" || character == "\n" || character == "\r" {
                index += 1
                continue
            }
            if character == "\\" {
                flush()
                joining = false
                afterLiteral = false
                index += 2
                continue
            }
            if character == "/", peek(at: index + 1) == "/" {
                index = endOfLine(from: index)
                continue
            }
            if character == "/", peek(at: index + 1) == "*" {
                index = try endOfBlockComment(from: index)
                continue
            }
            if let end = try endOfRegexLiteral(at: index) {
                index = end
                flush()
                joining = false
                afterLiteral = false
                continue
            }
            if opensLiteral(at: index) {
                let found = try span(from: index)
                for (offset, piece) in try resolve(found).enumerated() {
                    if offset == 0, joining, pending != nil {
                        pending?.text += piece.text
                    } else {
                        flush()
                        pending = piece
                    }
                }
                index = found.end
                joining = false
                afterLiteral = true
                continue
            }
            if character == "+", afterLiteral {
                joining = true
                afterLiteral = false
                index += 1
                continue
            }
            flush()
            joining = false
            afterLiteral = false
            index += 1
        }
        flush()
        return fragments
    }

    /// Finds where the literal opening at `start` ends.
    /// Escapes and interpolations do not close it.
    private func span(from start: Int) throws -> Span {
        var index = start
        var pounds = 0
        while index < chars.count, chars[index] == "#" {
            pounds += 1
            index += 1
        }
        guard index < chars.count, chars[index] == "\"" else {
            throw error(at: start, "a string literal was expected here")
        }
        let multiline = matches("\"\"\"", at: index)
        index += multiline ? 3 : 1
        var bodyStart = index
        if multiline {
            while index < chars.count, chars[index] == " " || chars[index] == "\t" { index += 1 }
            guard index < chars.count, chars[index] == "\n" else {
                throw error(at: start, "a multiline literal does not open on a line of its own")
            }
            index += 1
            bodyStart = index
        }
        let closer = multiline ? "\"\"\"" : "\""
        while index < chars.count {
            if isEscape(at: index, pounds: pounds) {
                let escaped = index + 1 + pounds
                guard escaped < chars.count else {
                    throw error(at: index, "an escape runs past the end of the file")
                }
                index = chars[escaped] == "(" ? try endOfInterpolation(from: escaped).end : escaped + 1
                continue
            }
            if matches(closer, at: index), hasPounds(pounds, at: index + closer.count) {
                let end = index + closer.count + pounds
                guard multiline else {
                    return Span(body: bodyStart..<index, end: end, pounds: pounds, indent: 0)
                }
                let closing = try closingLine(bodyStart: bodyStart, delimiter: index)
                return Span(body: closing.body, end: end, pounds: pounds, indent: closing.indent)
            }
            if chars[index] == "\n", !multiline {
                throw error(at: start, "a single line string literal is not closed")
            }
            index += 1
        }
        throw error(at: start, "a string literal is not closed")
    }

    /// Trims a multiline body back to the line above its closing delimiter.
    /// The delimiter's own indentation is measured here.
    private func closingLine(bodyStart: Int, delimiter: Int) throws -> (body: Range<Int>, indent: Int) {
        var start = delimiter
        var indent = 0
        while start > bodyStart, chars[start - 1] == " " || chars[start - 1] == "\t" {
            start -= 1
            indent += 1
        }
        guard start > 0, chars[start - 1] == "\n" else {
            throw error(at: delimiter, "a multiline literal does not close on a line of its own")
        }
        return (bodyStart..<max(bodyStart, start - 1), indent)
    }

    /// Reads a literal body into the text pieces an interpolation separates.
    /// Escapes resolve to the characters they stand for.
    private func resolve(_ literal: Span) throws -> [CopyFragment] {
        var pieces: [CopyFragment] = []
        var text = ""
        var start = literal.body.lowerBound
        var index = literal.body.lowerBound
        var atLineStart = literal.indent > 0

        while index < literal.body.upperBound {
            if atLineStart {
                atLineStart = false
                index = try dedent(from: index, indent: literal.indent, limit: literal.body.upperBound)
                continue
            }
            if isEscape(at: index, pounds: literal.pounds) {
                let escaped = index + 1 + literal.pounds
                guard escaped < literal.body.upperBound else {
                    throw error(at: index, "an escape runs past the end of the literal")
                }
                if chars[escaped] == "(" {
                    pieces.append(CopyFragment(text: text, line: line(at: start)))
                    text = ""
                    let interpolation = try endOfInterpolation(from: escaped)
                    pieces.append(contentsOf: interpolation.nested)
                    index = interpolation.end
                    start = index
                    continue
                }
                let resolved = try escape(at: escaped)
                text += resolved.text
                index = resolved.end
                if chars[escaped] == "\n" { atLineStart = literal.indent > 0 }
                continue
            }
            let character = chars[index]
            text.append(character)
            if character == "\n" { atLineStart = literal.indent > 0 }
            index += 1
        }
        pieces.append(CopyFragment(text: text, line: line(at: start)))
        return pieces
    }

    /// Drops the closing delimiter's indentation from one body line.
    /// A line indented less than that cannot be read.
    private func dedent(from index: Int, indent: Int, limit: Int) throws -> Int {
        var position = index
        var dropped = 0
        while dropped < indent, position < limit, chars[position] == " " || chars[position] == "\t" {
            position += 1
            dropped += 1
        }
        if dropped < indent, position < limit, chars[position] != "\n" {
            throw error(at: position, "a line is indented less than the literal's closing delimiter")
        }
        return position
    }

    /// Turns one escape into the text it stands for.
    /// `index` sits after the backslash.
    private func escape(at index: Int) throws -> (text: String, end: Int) {
        switch chars[index] {
        case "n": return ("\n", index + 1)
        case "t": return ("\t", index + 1)
        case "r": return ("\r", index + 1)
        case "0": return ("\0", index + 1)
        case "\\": return ("\\", index + 1)
        case "\"": return ("\"", index + 1)
        case "'": return ("'", index + 1)
        case "\n": return ("", index + 1)
        case "u": return try unicodeEscape(at: index + 1)
        default: throw error(at: index, "an escape the scanner does not know: \\\(chars[index])")
        }
    }

    /// Resolves `\u{...}` to its character, `index` at the brace.
    /// A scalar it cannot form is a failure.
    private func unicodeEscape(at index: Int) throws -> (text: String, end: Int) {
        guard index < chars.count, chars[index] == "{" else {
            throw error(at: index, "a unicode escape without braces")
        }
        var position = index + 1
        var digits = ""
        while position < chars.count, chars[position] != "}" {
            digits.append(chars[position])
            position += 1
        }
        guard position < chars.count, let value = UInt32(digits, radix: 16), let scalar = Unicode.Scalar(value) else {
            throw error(at: index, "a unicode escape the scanner cannot read")
        }
        return (String(Character(scalar)), position + 1)
    }

    /// Spans the Swift code in an interpolation, `start` at its paren.
    /// Literals nested in it are copy, the code around them is not.
    private func endOfInterpolation(from start: Int) throws -> (end: Int, nested: [CopyFragment]) {
        var nested: [CopyFragment] = []
        var index = start
        var depth = 0
        while index < chars.count {
            let character = chars[index]
            if character == "\\" {
                index += 2
                continue
            }
            if character == "/", peek(at: index + 1) == "/" {
                index = endOfLine(from: index)
                continue
            }
            if character == "/", peek(at: index + 1) == "*" {
                index = try endOfBlockComment(from: index)
                continue
            }
            if let end = try endOfRegexLiteral(at: index) {
                index = end
                continue
            }
            if opensLiteral(at: index) {
                let inner = try span(from: index)
                nested.append(contentsOf: try resolve(inner))
                index = inner.end
                continue
            }
            if character == "(" {
                depth += 1
                index += 1
                continue
            }
            if character == ")" {
                depth -= 1
                index += 1
                if depth == 0 { return (index, nested) }
                continue
            }
            index += 1
        }
        throw error(at: start, "an interpolation is not closed")
    }

    /// Spans an extended regex literal, `#/pattern/#`, if one opens here.
    /// A bare `/pattern/` holds no literal text to scan.
    private func endOfRegexLiteral(at start: Int) throws -> Int? {
        var index = start
        var pounds = 0
        while index < chars.count, chars[index] == "#" {
            pounds += 1
            index += 1
        }
        guard pounds > 0, index < chars.count, chars[index] == "/" else { return nil }
        index += 1
        while index < chars.count {
            if chars[index] == "\\" {
                index += 2
                continue
            }
            if chars[index] == "/", hasPounds(pounds, at: index + 1) { return index + 1 + pounds }
            index += 1
        }
        throw error(at: start, "a regex literal is not closed")
    }

    /// Spans a block comment from its opener, nesting included.
    private func endOfBlockComment(from start: Int) throws -> Int {
        var index = start + 2
        var depth = 1
        while index < chars.count {
            if matches("/*", at: index) {
                depth += 1
                index += 2
                continue
            }
            if matches("*/", at: index) {
                depth -= 1
                index += 2
                if depth == 0 { return index }
                continue
            }
            index += 1
        }
        throw error(at: start, "a block comment is not closed")
    }

    /// Index of the newline ending this line, or the end of the file.
    private func endOfLine(from start: Int) -> Int {
        var index = start
        while index < chars.count, chars[index] != "\n" { index += 1 }
        return index
    }

    /// Whether a string literal, raw or plain, opens at this index.
    private func opensLiteral(at index: Int) -> Bool {
        var position = index
        while position < chars.count, chars[position] == "#" { position += 1 }
        return position < chars.count && chars[position] == "\""
    }

    /// Whether a backslash here escapes, for the literal's pounds.
    private func isEscape(at index: Int, pounds: Int) -> Bool {
        chars[index] == "\\" && hasPounds(pounds, at: index + 1)
    }

    /// Whether that many `#` run from this index.
    private func hasPounds(_ count: Int, at index: Int) -> Bool {
        guard index + count <= chars.count else { return false }
        return !(index..<(index + count)).contains { chars[$0] != "#" }
    }

    /// Whether the source reads exactly that from this index.
    private func matches(_ text: String, at index: Int) -> Bool {
        let characters = Array(text)
        guard index + characters.count <= chars.count else { return false }
        return !characters.indices.contains { chars[index + $0] != characters[$0] }
    }

    /// The character at an index, or nil past the end.
    private func peek(at index: Int) -> Character? {
        index < chars.count ? chars[index] : nil
    }

    /// The line an index sits on, clamped to the file.
    private func line(at index: Int) -> Int {
        lineNumbers.isEmpty ? 1 : lineNumbers[min(index, lineNumbers.count - 1)]
    }

    /// A failure naming the file and the line that stopped the scan.
    private func error(at index: Int, _ reason: String) -> CopyScanError {
        CopyScanError(file: file, line: line(at: index), reason: reason)
    }
}
