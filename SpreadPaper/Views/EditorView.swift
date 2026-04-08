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

    @State private var currentPreviewScale: CGFloat = 1.0
    @State private var presetName = ""
    @State private var editingScheduleIndex: Int? = nil

    private var currentImage: NSImage? {
        guard !loadedImages.isEmpty, selectedVariantIndex < loadedImages.count else { return nil }
        return loadedImages[selectedVariantIndex]
    }

    // Bindings into the current variant's position
    private var imageOffsetBinding: Binding<CGSize> {
        Binding(
            get: {
                guard selectedVariantIndex < variants.count else { return .zero }
                let v = variants[selectedVariantIndex]
                return CGSize(width: v.offsetX, height: v.offsetY)
            },
            set: {
                guard selectedVariantIndex < variants.count else { return }
                variants[selectedVariantIndex].offsetX = $0.width
                variants[selectedVariantIndex].offsetY = $0.height
            }
        )
    }

    private var imageScaleBinding: Binding<CGFloat> {
        Binding(
            get: { selectedVariantIndex < variants.count ? variants[selectedVariantIndex].scale : 1.0 },
            set: { if selectedVariantIndex < variants.count { variants[selectedVariantIndex].scale = $0 } }
        )
    }

    private var isFlippedBinding: Binding<Bool> {
        Binding(
            get: { selectedVariantIndex < variants.count ? variants[selectedVariantIndex].isFlipped : false },
            set: { if selectedVariantIndex < variants.count { variants[selectedVariantIndex].isFlipped = $0 } }
        )
    }

    var body: some View {
        AppShell(
            topBar: {
                HStack {
                    Button(action: { navigation.navigateToGallery() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11))
                            Text("Gallery")
                                .font(.system(size: 12, weight: .medium))
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
                .padding(.top, 40) // Clear traffic lights
                .padding(.bottom, 8)
                .background(Color.cdBgSecondary)
            },
            mainContent: {
                EditorCanvasView(
                    selectedImage: currentImage,
                    imageOffset: imageOffsetBinding,
                    imageScale: imageScaleBinding,
                    isFlipped: isFlippedBinding,
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
        .onChange(of: selectedVariantIndex) { _, newIndex in
            // Auto-fit if this variant hasn't been positioned yet
            if newIndex < variants.count && variants[newIndex].scale <= 0.1 {
                fitImage()
            }
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
                VStack(alignment: .leading, spacing: 20) {
                    // Position
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Position")

                        HStack(spacing: 8) {
                            Text("Zoom")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.cdTextTertiary)
                                .frame(width: 40, alignment: .leading)
                            CoolDarkSlider(value: imageScaleBinding, range: 0.1...5.0)
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

                            Button(action: {
                                guard selectedVariantIndex < variants.count else { return }
                                variants[selectedVariantIndex].isFlipped.toggle()
                            }) {
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
                .padding(16)
            }

            // Action buttons pinned at bottom
            Divider().overlay(Color.cdBorder)
            VStack(spacing: 8) {
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
            .padding(16)
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
                        .frame(height: 70)
                        .clipped()
                } else {
                    Color.cdBgPrimary
                        .frame(height: 70)
                        .overlay {
                            Image(systemName: "plus")
                                .foregroundStyle(Color.cdTextTertiary)
                        }
                }

                Text(label)
                    .font(.system(size: 11, weight: index == selectedVariantIndex ? .semibold : .regular))
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
            guard selectedVariantIndex < variants.count else { return }
            variants[selectedVariantIndex].scale = max(widthRatio, heightRatio)
            variants[selectedVariantIndex].offsetX = 0
            variants[selectedVariantIndex].offsetY = 0
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

        if preset.isDynamic && !preset.timeVariants.isEmpty {
            // For appearance presets, ensure light (hour=12) is index 0, dark (hour=0) is index 1
            let sortedVariants: [TimeVariant]
            if preset.wallpaperType == "Light/Dark" {
                sortedVariants = preset.timeVariants.sorted { $0.hour > $1.hour }
            } else {
                sortedVariants = preset.timeVariants
            }
            variants = sortedVariants
            loadedImages = []
            originalUrls = []
            for variant in sortedVariants {
                let url = manager.getImageUrl(for: SavedPreset(
                    name: "", imageFilename: variant.imageFilename,
                    offsetX: 0, offsetY: 0, scale: 1, previewScale: 1, isFlipped: false
                ))
                if let img = NSImage(contentsOf: url) {
                    loadedImages.append(img)
                    originalUrls.append(url)
                }
            }
            selectedVariantIndex = 0
        } else {
            // Static wallpaper — single image
            let url = manager.getImageUrl(for: preset)
            if let img = NSImage(contentsOf: url) {
                loadedImages = [img]
                originalUrls = [url]
            }
        }
    }

    /// Current variant's position (convenience)
    private var currentOffset: CGSize {
        guard selectedVariantIndex < variants.count else { return .zero }
        let v = variants[selectedVariantIndex]
        return CGSize(width: v.offsetX, height: v.offsetY)
    }
    private var currentScale: CGFloat {
        selectedVariantIndex < variants.count ? variants[selectedVariantIndex].scale : 1.0
    }
    private var currentFlip: Bool {
        selectedVariantIndex < variants.count ? variants[selectedVariantIndex].isFlipped : false
    }

    /// Apply wallpaper to desktop without saving — stay in editor
    private func previewWallpaper() {
        guard !loadedImages.isEmpty else { return }

        // Store previewScale in each variant
        for i in variants.indices {
            variants[i].previewScale = currentPreviewScale
        }

        switch wallpaperType {
        case .standard:
            guard let image = loadedImages.first else { return }
            Task {
                await manager.setWallpaper(
                    originalImage: image, imageOffset: currentOffset,
                    scale: currentScale, previewScale: currentPreviewScale, isFlipped: currentFlip
                )
            }
        case .dynamic:
            guard variants.count >= 2 else { return }
            let v = variants.first ?? variants[0]
            let preset = SavedPreset(
                name: presetName.isEmpty ? "Untitled" : presetName, imageFilename: "",
                offsetX: v.offsetX, offsetY: v.offsetY,
                scale: v.scale, previewScale: currentPreviewScale, isFlipped: v.isFlipped,
                isDynamic: true, timeVariants: variants
            )
            Task {
                await manager.applyDynamicWallpaper(preset: preset, images: loadedImages, previewScale: currentPreviewScale)
            }
        case .appearance:
            guard loadedImages.count == 2, variants.count == 2 else { return }
            Task {
                await manager.applyAppearanceWallpaper(
                    lightImage: loadedImages[0], darkImage: loadedImages[1],
                    lightVariant: variants[0], darkVariant: variants[1]
                )
            }
        }
    }

    /// Save preset, apply wallpaper, navigate back to gallery
    private func saveAndApply() {
        guard !loadedImages.isEmpty else { return }

        let name = presetName.isEmpty ? "Untitled" : presetName

        // Store previewScale in each variant
        for i in variants.indices {
            variants[i].previewScale = currentPreviewScale
        }

        if let presetId, let index = manager.presets.firstIndex(where: { $0.id == presetId }) {
            // Update existing preset
            manager.presets[index].name = name
            manager.presets[index].timeVariants = variants
            // Use first variant's position as the preset-level position (for backward compat)
            if let first = variants.first {
                manager.presets[index].offsetX = first.offsetX
                manager.presets[index].offsetY = first.offsetY
                manager.presets[index].scale = first.scale
                manager.presets[index].previewScale = currentPreviewScale
                manager.presets[index].isFlipped = first.isFlipped
            }
            manager.persistPresetsPublic()
        } else {
            // Create new preset
            manager.saveDynamicPreset(
                name: name,
                imageUrls: originalUrls,
                hours: variants.map(\.hour),
                minutes: variants.map(\.minute),
                offsets: variants.map { CGSize(width: $0.offsetX, height: $0.offsetY) },
                scales: variants.map(\.scale),
                previewScale: currentPreviewScale,
                flipped: variants.map(\.isFlipped)
            )
        }

        // Apply
        previewWallpaper()

        // Navigate back to gallery
        navigation.navigateToGallery()
    }
}
