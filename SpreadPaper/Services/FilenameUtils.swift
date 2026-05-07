import Foundation

enum FilenameUtils {
    static func displayName(for storedFilename: String) -> String {
        let base = (storedFilename as NSString).deletingPathExtension
        if let underscore = base.firstIndex(of: "_") {
            return String(base[base.index(after: underscore)...])
        }
        return base
    }

    static func storedName(uuid: UUID, originalFilename: String) -> String {
        let nsName = originalFilename as NSString
        let ext = nsName.pathExtension
        let rawBase = nsName.deletingPathExtension

        let sanitizedBase = rawBase
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "\0", with: "-")

        let cappedBase = sanitizedBase.count > 80 ? String(sanitizedBase.prefix(80)) : sanitizedBase
        let safeBase = cappedBase.isEmpty ? "image" : cappedBase

        return ext.isEmpty ? "\(uuid.uuidString)_\(safeBase)" : "\(uuid.uuidString)_\(safeBase).\(ext)"
    }
}
