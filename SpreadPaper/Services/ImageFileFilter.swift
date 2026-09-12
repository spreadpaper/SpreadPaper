// SpreadPaper/Services/ImageFileFilter.swift

import Foundation
import UniformTypeIdentifiers

/// Keeps only the local file URLs whose extension names an image type.
/// Shared by the wizard and the editor drop zones.
nonisolated enum ImageFileFilter {
    /// Returns the image file URLs in their original order, everything else removed.
    /// Web links are dropped so no download happens on the main thread.
    /// Extensions match case-insensitively via UTType.
    static func imageURLs(from urls: [URL]) -> [URL] {
        urls.filter { url in
            guard url.isFileURL else { return false }
            let ext = url.pathExtension
            guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else { return false }
            return type.conforms(to: .image)
        }
    }
}
