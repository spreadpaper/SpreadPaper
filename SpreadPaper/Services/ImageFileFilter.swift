// SpreadPaper/Services/ImageFileFilter.swift

import Foundation
import UniformTypeIdentifiers

/// Keeps only the file URLs whose extension names an image type.
/// Shared by the wizard and the editor drop zones.
nonisolated enum ImageFileFilter {
    /// Returns the image URLs in their original order, non-images removed.
    /// Extensions are matched case-insensitively via UTType.
    static func imageURLs(from urls: [URL]) -> [URL] {
        urls.filter { url in
            let ext = url.pathExtension
            guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else { return false }
            return type.conforms(to: .image)
        }
    }
}
