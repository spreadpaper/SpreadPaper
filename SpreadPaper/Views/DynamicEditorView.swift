// SpreadPaper/Views/DynamicEditorView.swift

import SwiftUI
import UniformTypeIdentifiers

struct DynamicEditorView: View {
    @Bindable var manager: WallpaperManager
    @Environment(\.colorScheme) var colorScheme

    @State private var loadedImages: [NSImage] = []
    @State private var originalUrls: [URL] = []
    @State private var thumbnails: [NSImage] = []
    @State private var variants: [TimeVariant] = []
    @State private var selectedVariantIndex: Int = 0
    @State private var scrubberTime: Double = 12.0

    @State private var imageOffset: CGSize = .zero
    @State private var dragStartOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var imageScale: CGFloat = 1.0
    @State private var isFlipped = false
    @State private var currentPreviewScale: CGFloat = 1.0

    @State private var isShowingSaveAlert = false
    @State private var newPresetName = ""

    /// The currently displayed image based on scrubber position
    private var currentImage: NSImage? {
        guard !loadedImages.isEmpty, selectedVariantIndex < loadedImages.count else { return nil }
        return loadedImages[selectedVariantIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Canvas area (same as static editor)
            GeometryReader { geo in
                let previewScale = calculatePreviewScale(geo: geo)
                let canvasWidth = manager.totalCanvas.width * previewScale
                let canvasHeight = manager.totalCanvas.height * previewScale

                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 0) {
                        Spacer()
                        CanvasView(
                            selectedImage: currentImage,
                            imageOffset: $imageOffset,
                            dragStartOffset: $dragStartOffset,
                            isDragging: $isDragging,
                            imageScale: $imageScale,
                            isFlipped: isFlipped,
                            previewScale: previewScale,
                            canvasWidth: canvasWidth,
                            canvasHeight: canvasHeight,
                            colorScheme: colorScheme,
                            manager: manager,
                            onSelectImage: addImages,
                            onDropImage: { providers in loadDroppedImages(providers) }
                        )
                        Spacer()
                    }
                    Spacer()
                }
                .onAppear { self.currentPreviewScale = previewScale }
                .onChange(of: manager.totalCanvas) { _, _ in
                    self.currentPreviewScale = calculatePreviewScale(geo: geo)
                }
            }

            // Timeline (only visible when images are loaded)
            if !variants.isEmpty {
                TimelineView(
                    variants: $variants,
                    selectedVariantIndex: $selectedVariantIndex,
                    scrubberTime: $scrubberTime,
                    thumbnails: thumbnails,
                    onAddImages: addImages,
                    onRemoveVariant: removeVariant
                )
            }
        }
        .onChange(of: selectedVariantIndex) { _, _ in
            fitImage()
        }
        .toolbar { dynamicToolbar }
        .alert("Save Dynamic Preset", isPresented: $isShowingSaveAlert) {
            TextField("Preset Name", text: $newPresetName)
            Button("Cancel", role: .cancel) { }
            Button("Save") { saveDynamicPreset() }
        } message: { Text("Enter a name for this dynamic wallpaper.") }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var dynamicToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button(action: { imageScale = max(0.1, imageScale - 0.1) }) {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(currentImage == nil)

            Slider(value: $imageScale, in: 0.1...5.0)
                .frame(width: 100)
                .disabled(currentImage == nil)

            Button(action: { imageScale = min(5.0, imageScale + 0.1) }) {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(currentImage == nil)

            Toggle(isOn: $isFlipped.animation()) {
                Label("Flip", systemImage: "arrow.left.and.right")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(currentImage == nil)

            Button(action: fitImage) {
                Label("Fit", systemImage: "arrow.up.left.and.arrow.down.right")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(currentImage == nil)

            Spacer()

            Button(action: addImages) {
                Label("Add Images", systemImage: "photo.badge.plus")
                    .labelStyle(.titleAndIcon)
            }

            Button(action: { isShowingSaveAlert = true }) {
                Label("Save", systemImage: "square.and.arrow.down")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(variants.isEmpty)

            Button(action: applyDynamic) {
                Label("Apply Dynamic Wallpaper", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(variants.count < 2)
        }
    }

    // MARK: - Logic

    private func calculatePreviewScale(geo: GeometryProxy) -> CGFloat {
        let scaleX = geo.size.width / max(manager.totalCanvas.width, 1)
        let scaleY = geo.size.height / max(manager.totalCanvas.height, 1)
        return min(scaleX, scaleY) * 0.85
    }

    private func fitImage() {
        guard let image = currentImage else { return }
        let canvas = manager.totalCanvas
        guard canvas.width > 0 && canvas.height > 0 else { return }
        let widthRatio = canvas.width / image.size.width
        let heightRatio = canvas.height / image.size.height
        withAnimation(.spring()) {
            imageScale = max(widthRatio, heightRatio)
            imageOffset = .zero
            dragStartOffset = .zero
        }
    }

    private func addImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.message = "Select images for different times of day"
        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard variants.count < 16 else { break }
            guard let image = NSImage(contentsOf: url) else { continue }

            let existingCount = variants.count
            let defaultHour = existingCount * (24 / max(panel.urls.count + existingCount, 1))

            loadedImages.append(image)
            originalUrls.append(url)
            thumbnails.append(generateThumbnail(image))
            variants.append(TimeVariant(
                imageFilename: url.lastPathComponent,
                hour: min(defaultHour, 23),
                minute: 0
            ))
        }

        if loadedImages.count == variants.count && !loadedImages.isEmpty {
            selectedVariantIndex = 0
            scrubberTime = Double(variants[0].hour)
            fitImage()
        }
    }

    private func loadDroppedImages(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url, let image = NSImage(contentsOf: url) {
                        Task { @MainActor in
                            guard variants.count < 16 else { return }
                            let defaultHour = variants.count * 3
                            loadedImages.append(image)
                            originalUrls.append(url)
                            thumbnails.append(generateThumbnail(image))
                            variants.append(TimeVariant(
                                imageFilename: url.lastPathComponent,
                                hour: min(defaultHour, 23),
                                minute: 0
                            ))
                        }
                    }
                }
            }
        }
    }

    private func removeVariant(at index: Int) {
        guard index < variants.count else { return }
        variants.remove(at: index)
        loadedImages.remove(at: index)
        originalUrls.remove(at: index)
        thumbnails.remove(at: index)
        if selectedVariantIndex >= variants.count {
            selectedVariantIndex = max(0, variants.count - 1)
        }
    }

    private func generateThumbnail(_ image: NSImage) -> NSImage {
        let maxDim: CGFloat = 144  // 2x of 72pt thumbnail
        let ratio = min(maxDim / image.size.width, maxDim / image.size.height)
        let newSize = NSSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        thumbnail.unlockFocus()
        return thumbnail
    }

    private func saveDynamicPreset() {
        guard !newPresetName.isEmpty, !variants.isEmpty else { return }
        manager.saveDynamicPreset(
            name: newPresetName,
            imageUrls: originalUrls,
            hours: variants.map(\.hour),
            minutes: variants.map(\.minute),
            offsets: variants.map { _ in imageOffset },
            scales: variants.map { _ in imageScale },
            previewScale: currentPreviewScale,
            flipped: variants.map { _ in isFlipped }
        )
        newPresetName = ""
    }

    private func applyDynamic() {
        guard variants.count >= 2 else { return }
        let tempPreset = SavedPreset(
            name: "temp",
            imageFilename: "",
            offsetX: imageOffset.width,
            offsetY: imageOffset.height,
            scale: imageScale,
            previewScale: currentPreviewScale,
            isFlipped: isFlipped,
            isDynamic: true,
            timeVariants: variants
        )
        Task {
            await manager.applyDynamicWallpaper(
                preset: tempPreset,
                images: loadedImages,
                previewScale: currentPreviewScale
            )
        }
    }
}
