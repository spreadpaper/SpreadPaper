import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State var manager = WallpaperManager()
    @State var settings = AppSettings()
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedImage: NSImage?
    @State private var currentOriginalUrl: URL?

    @State private var imageOffset: CGSize = .zero
    @State private var dragStartOffset: CGSize = .zero
    @State private var imageScale: CGFloat = 1.0
    @State private var isDragging = false
    @State private var currentPreviewScale: CGFloat = 1.0
    @State private var isFlipped = false

    @State private var selectedPresetID: SavedPreset.ID?
    @State private var isShowingSaveAlert = false
    @State private var newPresetName = ""

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedPresetID: $selectedPresetID,
                presets: manager.presets,
                onNewSetup: resetEditor,
                onDelete: { preset in
                    manager.deletePreset(preset)
                    if selectedPresetID == preset.id { resetEditor() }
                }
            )
        } detail: {
            ZStack {
                backgroundGradient

                WindowDragHandler()

                GeometryReader { geo in
                    let previewScale = calculatePreviewScale(geo: geo)
                    let canvasWidth = manager.totalCanvas.width * previewScale
                    let canvasHeight = manager.totalCanvas.height * previewScale

                    VStack(spacing: 0) {
                        Spacer()
                        HStack(spacing: 0) {
                            Spacer()

                            CanvasView(
                                selectedImage: selectedImage,
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
                                onSelectImage: selectImage,
                                onDropImage: { providers in loadDroppedImage(providers) }
                            )

                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.bottom, 70) // Account for toolbar height
                    .onAppear { self.currentPreviewScale = previewScale }
                    .onChange(of: geo.size) { _, _ in self.currentPreviewScale = previewScale }
                    .onChange(of: manager.totalCanvas) { _, _ in self.currentPreviewScale = previewScale }
                }

                ToolbarView(
                    imageScale: $imageScale,
                    isFlipped: $isFlipped,
                    hasImage: selectedImage != nil,
                    canSave: selectedImage != nil && currentOriginalUrl != nil,
                    colorScheme: colorScheme,
                    onSelectImage: selectImage,
                    onSave: { isShowingSaveAlert = true },
                    onApply: applyWallpaper
                )
            }
        }
        .alert("Save Preset", isPresented: $isShowingSaveAlert) {
            TextField("Preset Name", text: $newPresetName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let url = currentOriginalUrl, !newPresetName.isEmpty {
                    manager.savePreset(
                        name: newPresetName,
                        originalUrl: url,
                        offset: imageOffset,
                        scale: imageScale,
                        previewScale: currentPreviewScale,
                        isFlipped: isFlipped
                    )
                    newPresetName = ""
                }
            }
        } message: { Text("Enter a name for this layout configuration.") }
        .onChange(of: selectedPresetID) { _, newVal in
            if let id = newVal, let preset = manager.presets.first(where: { $0.id == id }) { loadPreset(preset) }
        }
        .background(WindowAccessor())
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(settings.colorScheme)
        .task {
            await manager.listenForScreenChanges()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.15),
                        Color(red: 0.05, green: 0.05, blue: 0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.98, green: 0.96, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Logic

    private func calculatePreviewScale(geo: GeometryProxy) -> CGFloat {
        let scaleX = geo.size.width / max(manager.totalCanvas.width, 1)
        let scaleY = geo.size.height / max(manager.totalCanvas.height, 1)
        return min(scaleX, scaleY) * 0.85
    }

    private func resetEditor() {
        selectedImage = nil
        currentOriginalUrl = nil
        selectedPresetID = nil
        imageOffset = .zero
        imageScale = 1.0
        isFlipped = false
    }

    private func loadPreset(_ preset: SavedPreset) {
        let url = manager.getImageUrl(for: preset)
        if let img = NSImage(contentsOf: url) {
            withAnimation {
                self.selectedImage = img
                self.currentOriginalUrl = url
                self.imageOffset = CGSize(width: preset.offsetX, height: preset.offsetY)
                self.imageScale = preset.scale
                self.isFlipped = preset.isFlipped
            }
        }
    }

    private func applyWallpaper() {
        if let img = selectedImage {
            manager.setWallpaper(
                originalImage: img,
                imageOffset: imageOffset,
                scale: imageScale,
                previewScale: currentPreviewScale,
                isFlipped: isFlipped
            )
        }
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { loadImage(from: url) }
    }

    private func loadDroppedImage(_ providers: [NSItemProvider]) {
        if let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url { DispatchQueue.main.async { loadImage(from: url) } }
            }
        }
    }

    private func loadImage(from url: URL) {
        if let image = NSImage(contentsOf: url) {
            // AUTO-SCALE TO FIT
            let canvas = manager.totalCanvas
            var startScale: CGFloat = 1.0

            if canvas.width > 0 && canvas.height > 0 && image.size.width > 0 && image.size.height > 0 {
                let widthRatio = canvas.width / image.size.width
                let heightRatio = canvas.height / image.size.height
                startScale = max(widthRatio, heightRatio)
            }

            withAnimation(.spring()) {
                selectedImage = image
                currentOriginalUrl = url
                imageOffset = .zero
                dragStartOffset = .zero
                imageScale = startScale
                selectedPresetID = nil
                isFlipped = false
            }
        }
    }
}

#Preview {
    ContentView()
}
