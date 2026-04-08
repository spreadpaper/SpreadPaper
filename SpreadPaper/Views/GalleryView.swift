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
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("SpreadPaper")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.cdTextPrimary)

                Spacer()

                CoolDarkSegmentedControl(
                    options: GalleryFilter.allCases.map(\.label),
                    selection: $filterIndex
                )

                Spacer()

                Button(action: { navigation.showCreationModal = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New")
                    }
                }
                .buttonStyle(CoolDarkButtonStyle(isPrimary: true))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.cdBgSecondary)

            Divider().overlay(Color.cdBorder)

            // Grid or empty state
            if filteredPresets.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180, maximum: 280), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(filteredPresets) { preset in
                            GalleryCardView(
                                preset: preset,
                                thumbnail: thumbnailCache[preset.id],
                                isActive: false, // TODO: track active wallpaper
                                onTap: { navigation.navigateToEditor(presetId: preset.id) },
                                onApply: { applyPreset(preset) },
                                onDelete: { manager.deletePreset(preset) }
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Color.cdBgPrimary)
        .task {
            loadThumbnails()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundStyle(Color.cdTextTertiary)
            Text("No wallpapers yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.cdTextSecondary)
            Button(action: { navigation.showCreationModal = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Create your first wallpaper")
                }
            }
            .buttonStyle(CoolDarkButtonStyle(isPrimary: true))
            Spacer()
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
