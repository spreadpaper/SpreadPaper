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

    func navigateToNewEditor(type: WallpaperType) {
        showCreationModal = false
        withAnimation(.easeInOut(duration: 0.2)) {
            route = .editorNew(type: type)
        }
    }
}
