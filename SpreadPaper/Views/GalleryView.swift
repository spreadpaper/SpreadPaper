// SpreadPaper/Views/GalleryView.swift

import SwiftUI

struct GalleryView: View {
    @Bindable var manager: WallpaperManager
    @Bindable var navigation: AppNavigation
    @State private var filterIndex: Int = 0
    @State private var thumbnailCache: [UUID: NSImage] = [:]

    private var filteredPresets: [SavedPreset] {
        let filter = GalleryFilter(rawValue: filterIndex) ?? .all
        switch filter {
        case .all: return manager.presets
        case .standard: return manager.presets.filter { !$0.isDynamic }
        case .dynamic: return manager.presets.filter { $0.isDynamic && $0.wallpaperType == "Dynamic" }
        case .appearance: return manager.presets.filter { $0.wallpaperType == "Light/Dark" }
        }
    }

    var body: some View {
        AppShell(
            topBar: { EmptyView() },
            mainContent: {
                if filteredPresets.isEmpty {
                    VStack(spacing: 0) {
                        textHero
                        emptyState
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            textHero

                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 200, maximum: 320), spacing: 12)],
                                spacing: 12
                            ) {
                                ForEach(filteredPresets) { preset in
                                    GalleryCardView(
                                        preset: preset,
                                        thumbnail: thumbnailCache[preset.id],
                                        isActive: false,
                                        onTap: { navigation.navigateToEditor(presetId: preset.id) },
                                        onApply: { applyPreset(preset) },
                                        onDelete: { manager.deletePreset(preset) }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            },
            sidebarContent: {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Filter")

                    VStack(spacing: 4) {
                        ForEach(GalleryFilter.allCases, id: \.self) { filter in
                            Button(action: { filterIndex = filter.rawValue }) {
                                HStack(spacing: 8) {
                                    Image(systemName: iconFor(filter))
                                        .font(.system(size: 10))
                                        .frame(width: 16)
                                    Text(filter.label)
                                        .font(.system(size: 11, weight: filterIndex == filter.rawValue ? .semibold : .regular))
                                    Spacer()
                                    Text("\(countFor(filter))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.cdTextTertiary)
                                }
                                .foregroundStyle(filterIndex == filter.rawValue ? Color.cdAccent : Color.cdTextSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(filterIndex == filter.rawValue ? Color.cdAccent.opacity(0.1) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider().overlay(Color.cdBorder)

                    Button(action: { navigation.showCreationModal = true }) {
                        HStack {
                            Spacer()
                            Image(systemName: "plus")
                            Text("New Wallpaper")
                            Spacer()
                        }
                    }
                    .buttonStyle(CoolDarkButtonStyle(isPrimary: true))

                    Spacer()
                }
                .padding(.top, 40) // Clear traffic lights
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        )
        .task {
            loadThumbnails()
        }
    }

    // MARK: - Text Hero

    private var textHero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SpreadPaper")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.cdTextPrimary)

            if let active = manager.presets.first {
                HStack(spacing: 6) {
                    Text("Active:")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cdTextTertiary)
                    Text(active.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cdTextPrimary)
                    Circle()
                        .fill(Color.cdSuccess)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.top, 40) // Clear traffic lights
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundStyle(Color.cdTextTertiary)
            Text("No wallpapers yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.cdTextSecondary)
            Text("Click \"New Wallpaper\" to get started")
                .font(.system(size: 12))
                .foregroundStyle(Color.cdTextTertiary)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func iconFor(_ filter: GalleryFilter) -> String {
        switch filter {
        case .all: return "square.grid.2x2"
        case .standard: return "photo"
        case .dynamic: return "sun.max"
        case .appearance: return "circle.lefthalf.filled"
        }
    }

    private func countFor(_ filter: GalleryFilter) -> Int {
        switch filter {
        case .all: return manager.presets.count
        case .standard: return manager.presets.filter { !$0.isDynamic }.count
        case .dynamic: return manager.presets.filter { $0.isDynamic && $0.wallpaperType == "Dynamic" }.count
        case .appearance: return manager.presets.filter { $0.wallpaperType == "Light/Dark" }.count
        }
    }

    private func loadThumbnails() {
        for preset in manager.presets {
            if thumbnailCache[preset.id] == nil {
                let url = manager.getImageUrl(for: preset)
                if let image = NSImage(contentsOf: url) {
                    let maxDim: CGFloat = 400
                    let ratio = min(maxDim / image.size.width, maxDim / image.size.height, 1.0)
                    let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
                    let thumb = NSImage(size: newSize)
                    thumb.lockFocus()
                    image.draw(in: NSRect(origin: .zero, size: newSize))
                    thumb.unlockFocus()
                    thumbnailCache[preset.id] = thumb
                }
            }
        }
    }

    private func applyPreset(_ preset: SavedPreset) {
        let url = manager.getImageUrl(for: preset)
        guard let image = NSImage(contentsOf: url) else { return }
        Task {
            await manager.setWallpaper(
                originalImage: image,
                imageOffset: CGSize(width: preset.offsetX, height: preset.offsetY),
                scale: preset.scale,
                previewScale: preset.previewScale,
                isFlipped: preset.isFlipped
            )
        }
    }
}
