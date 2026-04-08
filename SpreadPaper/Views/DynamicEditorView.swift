import SwiftUI
import UniformTypeIdentifiers

enum DynamicMode: String, CaseIterable {
    case timeBased = "Time of Day"
    case appearance = "Light / Dark"
}

struct DynamicEditorView: View {
    @Bindable var manager: WallpaperManager
    @Environment(\.colorScheme) var colorScheme

    @State private var mode: DynamicMode = .timeBased
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

    private var currentImage: NSImage? {
        guard !loadedImages.isEmpty, selectedVariantIndex < loadedImages.count else { return nil }
        return loadedImages[selectedVariantIndex]
    }

    private var canApply: Bool {
        switch mode {
        case .timeBased: return variants.count >= 2
        case .appearance: return loadedImages.count == 2
        }
    }

    var body: some View {
        VStack(spacing: 0) {
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

            if !variants.isEmpty {
                timelinePanel
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

    // MARK: - Timeline Panel (thumbnails + time editing, all in one)

    private var timelinePanel: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 10) {
                // Thumbnail strip sorted by time
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(sortedEntries, id: \.variant.id) { entry in
                            VStack(spacing: 3) {
                                if let thumb = entry.thumbnail {
                                    Image(nsImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(entry.originalIndex == selectedVariantIndex ? Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                }

                                if mode == .appearance {
                                    Text(entry.originalIndex == 0 ? "Light" : "Dark")
                                        .font(.system(size: 10, weight: entry.originalIndex == selectedVariantIndex ? .semibold : .regular))
                                        .foregroundStyle(entry.originalIndex == selectedVariantIndex ? .primary : .secondary)
                                } else {
                                    Text(entry.variant.timeString)
                                        .font(.system(size: 10, weight: entry.originalIndex == selectedVariantIndex ? .semibold : .regular))
                                        .foregroundStyle(entry.originalIndex == selectedVariantIndex ? .primary : .secondary)
                                }
                            }
                            .onTapGesture {
                                selectedVariantIndex = entry.originalIndex
                                scrubberTime = Double(entry.variant.hour) + Double(entry.variant.minute) / 60.0
                            }
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    removeVariant(at: entry.originalIndex)
                                }
                            }
                        }

                        let maxImages = mode == .appearance ? 2 : 16
                        if variants.count < maxImages {
                            Button(action: addImages) {
                                VStack(spacing: 3) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 80, height: 50)
                                        .overlay {
                                            Image(systemName: "plus")
                                                .foregroundStyle(.secondary)
                                        }
                                    Text("Add")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // Time editing row (only for time-based mode)
                if mode == .timeBased && selectedVariantIndex < variants.count {
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Text("Shown from")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: shownFromBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 90)
                        }

                        HStack(spacing: 6) {
                            Text("until")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(shownUntilLabel)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private var sortedEntries: [(originalIndex: Int, variant: TimeVariant, thumbnail: NSImage?)] {
        variants.indices.map { i in
            (originalIndex: i,
             variant: variants[i],
             thumbnail: i < thumbnails.count ? thumbnails[i] : nil)
        }
        .sorted { $0.variant.dayFraction < $1.variant.dayFraction }
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

            // Mode toggle in toolbar
            Picker("", selection: $mode) {
                ForEach(DynamicMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .onChange(of: mode) { _, newMode in
                onModeChanged(newMode)
            }

            Button(action: addImages) {
                Label("Add Images", systemImage: "photo.badge.plus")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(mode == .appearance && loadedImages.count >= 2)

            Button(action: applyDynamic) {
                Label("Apply", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(!canApply)
        }
    }

    // MARK: - Time bindings

    private var shownFromBinding: Binding<Date> {
        Binding<Date>(
            get: {
                guard selectedVariantIndex < variants.count else { return Date() }
                let v = variants[selectedVariantIndex]
                var components = DateComponents()
                components.hour = v.hour
                components.minute = v.minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                guard selectedVariantIndex < variants.count else { return }
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                variants[selectedVariantIndex].hour = components.hour ?? 0
                variants[selectedVariantIndex].minute = components.minute ?? 0
            }
        )
    }

    private var shownUntilLabel: String {
        let sorted = variants.sorted { $0.dayFraction < $1.dayFraction }
        guard let currentIdx = sorted.firstIndex(where: { $0.id == variants[selectedVariantIndex].id }) else {
            return "--"
        }
        let nextIdx = (currentIdx + 1) % sorted.count
        return sorted[nextIdx].timeString
    }

    private func onModeChanged(_ newMode: DynamicMode) {
        switch newMode {
        case .appearance:
            while variants.count > 2 {
                let last = variants.count - 1
                variants.remove(at: last)
                loadedImages.remove(at: last)
                originalUrls.remove(at: last)
                thumbnails.remove(at: last)
            }
            if variants.count >= 1 { variants[0].hour = 12; variants[0].minute = 0 }
            if variants.count >= 2 { variants[1].hour = 0; variants[1].minute = 0 }
            selectedVariantIndex = 0
        case .timeBased:
            let dayPhases = [(7,0),(9,0),(12,0),(15,0),(17,0),(19,0),(21,0),(23,0)]
            for (i, v) in variants.enumerated() {
                if i < dayPhases.count {
                    variants[i] = TimeVariant(id: v.id, imageFilename: v.imageFilename, hour: dayPhases[i].0, minute: dayPhases[i].1)
                }
            }
            selectedVariantIndex = 0
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
        panel.allowsMultipleSelection = mode == .timeBased
        panel.message = mode == .appearance
            ? "Select an image for \(loadedImages.isEmpty ? "Light" : "Dark") mode"
            : "Select images for different times of day"
        guard panel.runModal() == .OK else { return }

        let dayPhases = [(7,0),(9,0),(12,0),(15,0),(17,0),(19,0),(21,0),(23,0),(1,0),(3,0),(5,0),(6,0),(8,0),(10,0),(14,0),(16,0)]
        let maxImages = mode == .appearance ? 2 : 16

        for url in panel.urls {
            guard variants.count < maxImages else { break }
            guard let image = NSImage(contentsOf: url) else { continue }

            let slotIndex = variants.count
            let (hour, minute): (Int, Int)
            if mode == .appearance {
                hour = slotIndex == 0 ? 12 : 0
                minute = 0
            } else {
                (hour, minute) = slotIndex < dayPhases.count ? dayPhases[slotIndex] : (min(slotIndex + 7, 23), 0)
            }

            loadedImages.append(image)
            originalUrls.append(url)
            thumbnails.append(generateThumbnail(image))
            variants.append(TimeVariant(
                imageFilename: url.lastPathComponent,
                hour: hour,
                minute: minute
            ))
        }

        if !loadedImages.isEmpty {
            selectedVariantIndex = 0
            fitImage()
        }
    }

    private func loadDroppedImages(_ providers: [NSItemProvider]) {
        let maxImages = mode == .appearance ? 2 : 16
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url, let image = NSImage(contentsOf: url) {
                        Task { @MainActor in
                            guard variants.count < maxImages else { return }
                            let dayPhases = [(7,0),(9,0),(12,0),(15,0),(17,0),(19,0),(21,0),(23,0)]
                            let slot = variants.count
                            let hour: Int
                            if mode == .appearance {
                                hour = slot == 0 ? 12 : 0
                            } else {
                                hour = slot < dayPhases.count ? dayPhases[slot].0 : min(slot + 7, 23)
                            }
                            loadedImages.append(image)
                            originalUrls.append(url)
                            thumbnails.append(generateThumbnail(image))
                            variants.append(TimeVariant(
                                imageFilename: url.lastPathComponent,
                                hour: hour,
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
        let maxDim: CGFloat = 144
        let ratio = min(maxDim / image.size.width, maxDim / image.size.height)
        let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
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
        switch mode {
        case .timeBased:
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
        case .appearance:
            guard loadedImages.count == 2 else { return }
            Task {
                await manager.applyAppearanceWallpaper(
                    lightImage: loadedImages[0],
                    darkImage: loadedImages[1],
                    offset: imageOffset,
                    scale: imageScale,
                    previewScale: currentPreviewScale,
                    isFlipped: isFlipped
                )
            }
        }
    }
}
