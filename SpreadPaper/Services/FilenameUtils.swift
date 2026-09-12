import Foundation

enum FilenameUtils {
    static func displayName(for storedFilename: String) -> String {
        let base = baseName(of: storedFilename)
        if let underscore = base.firstIndex(of: "_") {
            return String(base[base.index(after: underscore)...])
        }
        return base
    }

    static func storedName(uuid: UUID, originalFilename: String) -> String {
        let ext = pathExtension(of: originalFilename)
        let rawBase = baseName(of: originalFilename)

        let sanitizedBase = rawBase
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "\0", with: "-")

        let cappedBase = sanitizedBase.count > 80 ? String(sanitizedBase.prefix(80)) : sanitizedBase
        let safeBase = cappedBase.isEmpty ? "image" : cappedBase

        return ext.isEmpty ? "\(uuid.uuidString)_\(safeBase)" : "\(uuid.uuidString)_\(safeBase).\(ext)"
    }

    /// Extension of a bare filename, empty when it has none.
    /// Empty input stays empty.
    private static func pathExtension(of filename: String) -> String {
        filename.isEmpty ? "" : URL(filePath: filename).pathExtension
    }

    /// Filename with its extension removed.
    /// Preserves non-extension dot tails.
    private static func baseName(of filename: String) -> String {
        let ext = pathExtension(of: filename)
        return ext.isEmpty ? filename : String(filename.dropLast(ext.count + 1))
    }
}
