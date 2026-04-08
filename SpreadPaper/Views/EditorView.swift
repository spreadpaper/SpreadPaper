// SpreadPaper/Views/EditorView.swift

import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @Bindable var manager: WallpaperManager
    @Bindable var navigation: AppNavigation
    let wallpaperType: WallpaperType
    let presetId: UUID?

    @State private var loadedImages: [NSImage] = []
    @State private var originalUrls: [URL] = []
    @State private var variants: [TimeVariant] = []
    @State private var selectedVariantIndex: Int = 0

    @State private var imageOffset: CGSize = .zero
    @State private var imageScale: CGFloat = 1.0
    @State private var isFlipped = false
    @State private var currentPreviewScale: CGFloat = 1.0
    @State private var presetName = ""
    @State private var editingScheduleIndex: Int? = nil

    private var currentImage: NSImage? {
        guard !loadedImages.isEmpty, selectedVariantIndex < loadedImages.count else { return nil }
        return loadedImages[selectedVariantIndex]
    }

    var body: some View {
        AppShell(
            topBar: {
                HStack {
                    Button(action: { navigation.navigateToGallery() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10))
                            Text("Gallery")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Color.cdAccent)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(presetName.isEmpty ? "Untitled" : presetName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cdTextPrimary)
                    Text("· \(wallpaperType.rawValue)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cdTextTertiary)

                    Spacer()

                    Color.clear.frame(width: 80, height: 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.cdBgSecondary)
            },
            mainContent: {
                EditorCanvasView(
                    selectedImage: currentImage,
                    imageOffset: $imageOffset,
                    imageScale: $imageScale,
                    isFlipped: $isFlipped,
                    manager: manager,
                    onSelectImage: addImages,
                    onDropImage: { _ in },
                    currentPreviewScale: $currentPreviewScale
                )
            },
            sidebarContent: {
                editorSidebar
            }
        )
        .overlay {
            if let idx = editingScheduleIndex, idx < variants.count {
                let scheduleView = ScheduleView(
                    variants: $variants,
                    selectedIndex: $selectedVariantIndex,
                    editingIndex: $editingScheduleIndex,
                    onAddImage: addImages,
                    onRemoveVariant: removeVariant
                )
                ScheduleDetailModal(
                    variant: $variants[idx],
                    defaultName: scheduleView.displayName(for: idx),
                    nextVariant: scheduleView.nextVariantAfter(index: idx),
                    onRemove: {
                        editingScheduleIndex = nil
                        removeVariant(at: idx)
                    },
                    onDone: { editingScheduleIndex = nil }
                )
            }
        }
        .onChange(of: selectedVariantIndex) { _, _ in
            fitImage()
        }
        .onAppear {
            if let presetId, let preset = manager.presets.first(where: { $0.id == presetId }) {
                loadExistingPreset(preset)
            }
        }
    }

    // MARK: - Sidebar

    private var editorSidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Position
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Position")

                        HStack(spacing: 4) {
                            Text("Zoom")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.cdTextTertiary)
                                .frame(width: 32, alignment: .leading)
                            CoolDarkSlider(value: $imageScale, range: 0.1...5.0)
                        }

                        HStack(spacing: 8) {
                            Button(action: fitImage) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 10))
                                    Text("Fit")
                                        .font(.system(size: 11))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(CoolDarkIconButtonStyle())

                            Button(action: { isFlipped.toggle() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.left.and.right")
                                        .font(.system(size: 10))
                                    Text("Flip")
                                        .font(.system(size: 11))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(CoolDarkIconButtonStyle())
                        }
                    }

                    Divider().overlay(Color.cdBorder)

                    // Mode-specific section
                    switch wallpaperType {
                    case .standard:
                        EmptyView()
                    case .dynamic:
                        ScheduleView(
                            variants: $variants,
                            selectedIndex: $selectedVariantIndex,
                            editingIndex: $editingScheduleIndex,
                            onAddImage: addImages,
                            onRemoveVariant: removeVariant
                        )
                    case .appearance:
                        appearanceSection
                    }

                    Divider().overlay(Color.cdBorder)

                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Name")
                        CoolDarkTextField(placeholder: "Wallpaper name", text: $presetName)
                    }
                }
                .padding(14)
            }

            // Action buttons pinned at bottom
            Divider().overlay(Color.cdBorder)
            VStack(spacing: 6) {
                Button(action: previewWallpaper) {
                    HStack {
                        Spacer()
                        Image(systemName: "eye")
                        Text("Preview")
                        Spacer()
                    }
                }
                .buttonStyle(CoolDarkIconButtonStyle())
                .disabled(loadedImages.isEmpty)

                Button(action: saveAndApply) {
                    HStack {
                        Spacer()
                        Text("Save & Apply")
                        Spacer()
                    }
                }
                .buttonStyle(CoolDarkButtonStyle(isSuccess: true))
                .disabled(loadedImages.isEmpty)
            }
            .padding(14)
        }
    }

    // MARK: - Appearance Section (Light/Dark)

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Appearance")

            HStack(spacing: 6) {
                appearanceCard(label: "☀ Light", index: 0)
                appearanceCard(label: "🌙 Dark", index: 1)
            }

            if loadedImages.count < 2 {
                DashedAddButton(label: "+ Add \(loadedImages.isEmpty ? "Light" : "Dark") Image", action: addImages)
            }
        }
    }

    private func appearanceCard(label: String, index: Int) -> some View {
        Button(action: {
            if index < loadedImages.count {
                selectedVariantIndex = index
            } else {
                addImages()
            }
        }) {
            VStack(spacing: 0) {
                if index < loadedImages.count {
                    Image(nsImage: loadedImages[index])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 52)
                        .clipped()
                } else {
                    Color.cdBgPrimary
                        .frame(height: 52)
                        .overlay {
                            Image(systemName: "plus")
                                .foregroundStyle(Color.cdTextTertiary)
                        }
                }

                Text(label)
                    .font(.system(size: 9, weight: index == selectedVariantIndex ? .semibold : .regular))
                    .foregroundStyle(index == selectedVariantIndex ? Color.cdTextPrimary : Color.cdTextSecondary)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.cdBgElevated)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(index == selectedVariantIndex ? Color.cdAccent : Color.cdBorder, lineWidth: index == selectedVariantIndex ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private func fitImage() {
        guard let image = currentImage else { return }
        let canvas = manager.totalCanvas
        guard canvas.width > 0, canvas.height > 0 else { return }
        let widthRatio = canvas.width / image.size.width
        let heightRatio = canvas.height / image.size.height
        withAnimation(.spring()) {
            imageScale = max(widthRatio, heightRatio)
            imageOffset = .zero
        }
    }

    private func addImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = wallpaperType == .dynamic
        guard panel.runModal() == .OK else { return }

        let dayPhases = [(7,0),(9,0),(12,0),(15,0),(17,0),(19,0),(21,0),(23,0),(1,0),(3,0),(5,0),(6,0),(8,0),(10,0),(14,0),(16,0)]
        let maxImages = wallpaperType == .appearance ? 2 : wallpaperType == .dynamic ? 16 : 1

        for url in panel.urls {
            guard loadedImages.count < maxImages else { break }
            guard let image = NSImage(contentsOf: url) else { continue }

            let slot = loadedImages.count
            let hour: Int
            let minute: Int
            if wallpaperType == .appearance {
                hour = slot == 0 ? 12 : 0; minute = 0
            } else if wallpaperType == .dynamic {
                (hour, minute) = slot < dayPhases.count ? dayPhases[slot] : (min(slot + 7, 23), 0)
            } else {
                hour = 12; minute = 0
            }

            loadedImages.append(image)
            originalUrls.append(url)
            variants.append(TimeVariant(imageFilename: url.lastPathComponent, hour: hour, minute: minute))
        }

        if !loadedImages.isEmpty {
            // Select the newly added image, not always the first
            selectedVariantIndex = loadedImages.count - 1
            // Only auto-fit if this is the first image (don't reset position of existing images)
            if loadedImages.count == 1 {
                fitImage()
            }
        }
    }

    private func removeVariant(at index: Int) {
        guard index < variants.count else { return }
        variants.remove(at: index)
        loadedImages.remove(at: index)
        originalUrls.remove(at: index)
        if selectedVariantIndex >= variants.count {
            selectedVariantIndex = max(0, variants.count - 1)
        }
    }

    private func loadExistingPreset(_ preset: SavedPreset) {
        presetName = preset.name
        imageOffset = CGSize(width: preset.offsetX, height: preset.offsetY)
        imageScale = preset.scale
        isFlipped = preset.isFlipped

        let url = manager.getImageUrl(for: preset)
        if let img = NSImage(contentsOf: url) {
            loadedImages = [img]
            originalUrls = [url]
        }

        if preset.isDynamic {
            variants = preset.timeVariants
            for variant in preset.timeVariants {
                let variantUrl = manager.getImageUrl(for: SavedPreset(
                    name: "", imageFilename: variant.imageFilename,
                    offsetX: 0, offsetY: 0, scale: 1, previewScale: 1, isFlipped: false
                ))
                if let img = NSImage(contentsOf: variantUrl) {
                    if loadedImages.count < variants.count {
                        loadedImages.append(img)
                    }
                }
            }
        }
    }

    /// Apply wallpaper to desktop without saving — stay in editor
    private func previewWallpaper() {
        guard !loadedImages.isEmpty else { return }

        switch wallpaperType {
        case .standard:
            guard let image = loadedImages.first else { return }
            Task {
                await manager.setWallpaper(
                    originalImage: image, imageOffset: imageOffset,
                    scale: imageScale, previewScale: currentPreviewScale, isFlipped: isFlipped
                )
            }
        case .dynamic:
            guard variants.count >= 2 else { return }
            let preset = SavedPreset(
                name: presetName.isEmpty ? "Untitled" : presetName, imageFilename: "",
                offsetX: imageOffset.width, offsetY: imageOffset.height,
                scale: imageScale, previewScale: currentPreviewScale, isFlipped: isFlipped,
                isDynamic: true, timeVariants: variants
            )
            Task {
                await manager.applyDynamicWallpaper(preset: preset, images: loadedImages, previewScale: currentPreviewScale)
            }
        case .appearance:
            guard loadedImages.count == 2 else { return }
            Task {
                await manager.applyAppearanceWallpaper(
                    lightImage: loadedImages[0], darkImage: loadedImages[1],
                    offset: imageOffset, scale: imageScale, previewScale: currentPreviewScale, isFlipped: isFlipped
                )
            }
        }
    }

    /// Save preset, apply wallpaper, navigate back to gallery
    private func saveAndApply() {
        guard !loadedImages.isEmpty else { return }

        // Save the preset
        let name = presetName.isEmpty ? "Untitled" : presetName
        manager.saveDynamicPreset(
            name: name,
            imageUrls: originalUrls,
            hours: variants.map(\.hour),
            minutes: variants.map(\.minute),
            offsets: variants.map { _ in imageOffset },
            scales: variants.map { _ in imageScale },
            previewScale: currentPreviewScale,
            flipped: variants.map { _ in isFlipped }
        )

        // Apply
        previewWallpaper()

        // Navigate back to gallery
        navigation.navigateToGallery()
    }
}
