import Foundation
import Testing

/// The app's Swift files, for suites that scan source text.
enum AppSources {
    /// Every Swift file under `SpreadPaper/`.
    static func all() throws -> [URL] {
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

    /// Every app source but the theme file that mints colours.
    static func outsideTheTheme() throws -> [URL] {
        try all().filter { !$0.path.hasSuffix("Theme/CoolDarkTheme.swift") }
    }

    /// Lines of the given files matching any of the patterns, as `file:line: text`.
    static func lines(in files: [URL], containing patterns: [String]) throws -> [String] {
        var hits: [String] = []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where patterns.contains(where: { line.contains($0) }) {
                hits.append("\(file.lastPathComponent):\(number + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        return hits
    }
}
