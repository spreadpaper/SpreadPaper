// SpreadPaper/Navigation/AppNavigation.swift

import SwiftUI

enum WallpaperType: String, CaseIterable, Codable {
    case standard = "Static"
    case dynamic = "Dynamic"
    case appearance = "Light/Dark"
}

enum GalleryFilter: Int, CaseIterable {
    case all = 0
    case standard = 1
    case dynamic = 2
    case appearance = 3

    var label: String {
        switch self {
        case .all: return "All"
        case .standard: return "Static"
        case .dynamic: return "Dynamic"
        case .appearance: return "Light/Dark"
        }
    }
}

enum AppRoute: Equatable {
    case wizard
    case gallery
    case editor(presetId: UUID?)  // nil = new, creating
    case editorNew(type: WallpaperType)
}

@Observable
class AppNavigation {
    var route: AppRoute = .gallery
    var showCreationModal = false
    /// Image files for the next new editor, read once via `takePendingImageURLs()`.
    private var pendingImageURLs: [URL] = []

    func navigateToGallery() {
        withAnimation(.easeInOut(duration: 0.2)) {
            route = .gallery
        }
    }

    func navigateToEditor(presetId: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            route = .editor(presetId: presetId)
        }
    }

    /// Opens a fresh editor of the given type, optionally preloaded with image files.
    /// The URLs wait in `pendingImageURLs` until the editor appears.
    func navigateToNewEditor(type: WallpaperType, imageURLs: [URL] = []) {
        showCreationModal = false
        pendingImageURLs = imageURLs
        withAnimation(.easeInOut(duration: 0.2)) {
            route = .editorNew(type: type)
        }
    }

    /// Returns the pending image files and clears them.
    /// A re-appearing editor therefore gets nothing.
    func takePendingImageURLs() -> [URL] {
        defer { pendingImageURLs = [] }
        return pendingImageURLs
    }
}
