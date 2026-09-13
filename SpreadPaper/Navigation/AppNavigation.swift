// SpreadPaper/Navigation/AppNavigation.swift

import SwiftUI

/// Kinds of wallpaper a preset can produce, with the label, icon and tint every screen shows.
enum WallpaperType: String, CaseIterable, Codable {
    case standard = "Static"
    case appearance = "Light/Dark"
    case dynamic = "Dynamic"

    /// The kinds in the order the creation modal offers them.
    /// The one that does most with several images leads.
    static let creationOrder: [WallpaperType] = [.dynamic, .appearance, .standard]

    /// The kind the creation modal opens on, which is the one it lists first.
    static var creationDefault: WallpaperType { creationOrder.first ?? .standard }

    /// Short label shown on cards, filters and the type picker.
    /// One wording for every screen.
    var title: String {
        switch self {
        case .standard:   return "Static"
        case .appearance: return "Light & Dark"
        case .dynamic:    return "Dynamic"
        }
    }

    /// One-line description under the type picker and in the creation modal.
    /// Explains what the kind does with its images.
    var subtitle: String {
        switch self {
        case .standard:   return "One image, stretched seamlessly across every display."
        case .appearance: return "A light image by day, a darker one by night — switched by macOS appearance."
        case .dynamic:    return "A schedule of images that shifts through the day, in sync across all screens."
        }
    }

    /// SF Symbol name that marks the kind in badges, pills and filter rows.
    var systemImage: String {
        switch self {
        case .standard:   return "photo.fill"
        case .appearance: return "circle.lefthalf.filled"
        case .dynamic:    return "clock"
        }
    }

    /// Colour that marks the kind in the card badge and the creation modal glow.
    /// Static stays neutral.
    var tint: Color {
        switch self {
        case .standard:   return Color.cdTextTertiary
        case .appearance: return Color.cdAppearanceTint
        case .dynamic:    return Color.cdDynamicTint
        }
    }
}

/// Sidebar tabs of the gallery: every preset or one wallpaper kind.
enum GalleryFilter: Int, CaseIterable {
    case all = 0
    case standard = 1
    case dynamic = 2
    case appearance = 3

    /// Wallpaper kind this filter narrows to, or nil for every preset.
    var type: WallpaperType? {
        switch self {
        case .all:        return nil
        case .standard:   return .standard
        case .dynamic:    return .dynamic
        case .appearance: return .appearance
        }
    }

    /// Sidebar and toolbar label, taken from the kind's title where there is one.
    var label: String {
        type?.title ?? "All Wallpapers"
    }

    /// SF Symbol for the sidebar row, taken from the kind where there is one.
    var systemImage: String {
        type?.systemImage ?? "square.grid.2x2"
    }
}

/// Screens the main window can show; the editor cases carry what to open.
enum AppRoute: Equatable {
    case wizard
    case gallery
    case editor(presetId: UUID?)
    case editorNew(type: WallpaperType)
}

/// Route state that drives the main window; every screen change goes through here.
@Observable
class AppNavigation {
    var route: AppRoute = .gallery
    var showCreationModal = false
    /// Image files for the next new editor, read once via `takePendingImageURLs()`.
    private var pendingImageURLs: [URL] = []

    /// Animates back to the gallery.
    func navigateToGallery() {
        withAnimation(.easeInOut(duration: 0.2)) {
            route = .gallery
        }
    }

    /// Animates into the editor for a saved preset.
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
