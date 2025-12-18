import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import CoreGraphics

// MARK: - DATA MODELS

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

class AppSettings: ObservableObject {
    @AppStorage("appearanceMode") var appearanceMode: String = AppearanceMode.system.rawValue

    var selectedAppearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceMode) ?? .system }
        set { appearanceMode = newValue.rawValue }
    }

    var colorScheme: ColorScheme? {
        switch selectedAppearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct SavedPreset: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var imageFilename: String
    var offsetX: CGFloat
    var offsetY: CGFloat
    var scale: CGFloat
    var previewScale: CGFloat
    var isFlipped: Bool
}

struct DisplayInfo: Identifiable {
    let id = UUID()
    let screen: NSScreen
    let frame: CGRect
}

// MARK: - MANAGER

class WallpaperManager: ObservableObject {
    @Published var connectedScreens: [DisplayInfo] = []
    @Published var totalCanvas: CGRect = .zero
    @Published var presets: [SavedPreset] = []
    
    private let presetsFile = "spreadpaper_presets.json"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        refreshScreens()
        loadPresets()
        
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshScreens() }
            .store(in: &cancellables)
    }
    
    // --- FILE SYSTEM ---
    private func getAppDataDirectory() -> URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0]
        let spreadPaperDir = appSupport.appendingPathComponent("SpreadPaper")
        if !FileManager.default.fileExists(atPath: spreadPaperDir.path) {
            try? FileManager.default.createDirectory(at: spreadPaperDir, withIntermediateDirectories: true)
        }
        return spreadPaperDir
    }

    private func getWallpapersDirectory() -> URL {
        let wallpapersDir = getAppDataDirectory().appendingPathComponent("wallpapers")
        if !FileManager.default.fileExists(atPath: wallpapersDir.path) {
            try? FileManager.default.createDirectory(at: wallpapersDir, withIntermediateDirectories: true)
        }
        return wallpapersDir
    }

    private func sanitizeScreenName(_ name: String) -> String {
        // Remove characters that aren't safe for filenames
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        return name.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
    }

    private func cleanupOldWallpapers(for screenName: String, in directory: URL, except currentFilename: String) {
        // Remove old wallpaper files for this screen to prevent disk bloat
        // Pattern: spreadpaper_wall_[screenName]_[timestamp].png
        let prefix = "spreadpaper_wall_\(screenName)_"
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files {
                let filename = file.lastPathComponent
                if filename.hasPrefix(prefix) && filename.hasSuffix(".png") && filename != currentFilename {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            // Cleanup is best-effort; if it fails, old files will be cleaned up on next application
        }
    }
    
    func savePreset(name: String, originalUrl: URL, offset: CGSize, scale: CGFloat, previewScale: CGFloat, isFlipped: Bool) {
        let destDir = getAppDataDirectory()
        let fileExt = originalUrl.pathExtension
        let newFilename = "\(UUID().uuidString).\(fileExt)"
        let destUrl = destDir.appendingPathComponent(newFilename)
        
        do {
            try FileManager.default.copyItem(at: originalUrl, to: destUrl)
            let newPreset = SavedPreset(
                name: name,
                imageFilename: newFilename,
                offsetX: offset.width,
                offsetY: offset.height,
                scale: scale,
                previewScale: previewScale,
                isFlipped: isFlipped
            )
            presets.append(newPreset)
            persistPresets()
        } catch {
            print("Error saving preset image: \(error)")
        }
    }
    
    func deletePreset(_ preset: SavedPreset) {
        let fileUrl = getAppDataDirectory().appendingPathComponent(preset.imageFilename)
        try? FileManager.default.removeItem(at: fileUrl)
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets.remove(at: idx)
            persistPresets()
        }
    }
    
    func getImageUrl(for preset: SavedPreset) -> URL {
        return getAppDataDirectory().appendingPathComponent(preset.imageFilename)
    }
    
    private func persistPresets() {
        do {
            let data = try JSONEncoder().encode(presets)
            let url = getAppDataDirectory().appendingPathComponent(presetsFile)
            try data.write(to: url)
        } catch {
            print("Failed to save presets json: \(error)")
        }
    }
    
    private func loadPresets() {
        let url = getAppDataDirectory().appendingPathComponent(presetsFile)
        do {
            let data = try Data(contentsOf: url)
            presets = try JSONDecoder().decode([SavedPreset].self, from: data)
        } catch { }
    }
    
    // --- SCREEN LOGIC ---
    func refreshScreens() {
        let screens = NSScreen.screens
        self.totalCanvas = screens.reduce(CGRect.zero) { $0.union($1.frame) }
        self.connectedScreens = screens.map { screen in
            DisplayInfo(screen: screen, frame: screen.frame)
        }
    }
    
    // --- RENDERING ---
    func setWallpaper(originalImage: NSImage, imageOffset: CGSize, scale: CGFloat, previewScale: CGFloat, isFlipped: Bool) {
        for display in connectedScreens {
            renderAndSet(
                original: originalImage,
                screen: display.screen,
                screenFrame: display.frame,
                totalCanvas: totalCanvas,
                offset: imageOffset,
                imageScale: scale,
                previewScale: previewScale,
                isFlipped: isFlipped
            )
        }
    }
    
    private func renderAndSet(original: NSImage, screen: NSScreen, screenFrame: CGRect, totalCanvas: CGRect, offset: CGSize, imageScale: CGFloat, previewScale: CGFloat, isFlipped: Bool) {
        var rect = CGRect(origin: .zero, size: original.size)
        guard let cgImage = original.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return }
        
        let deviceScale = screen.backingScaleFactor
        let widthPx = Int(screenFrame.width * deviceScale)
        let heightPx = Int(screenFrame.height * deviceScale)
        
        guard let context = CGContext(
            data: nil,
            width: widthPx,
            height: heightPx,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        
        // Math
        let realOffsetX_Px = (offset.width / previewScale) * deviceScale
        let realOffsetY_Px = (offset.height / previewScale) * deviceScale
        let drawnImgWidthPx = original.size.width * imageScale * deviceScale
        let drawnImgHeightPx = original.size.height * imageScale * deviceScale
        let totalCanvasWidthPx = totalCanvas.width * deviceScale
        let totalCanvasHeightPx = totalCanvas.height * deviceScale
        let centeringX_Px = (totalCanvasWidthPx - drawnImgWidthPx) / 2.0
        let centeringY_Px = (totalCanvasHeightPx - drawnImgHeightPx) / 2.0
        let relativeScreenX = screenFrame.origin.x - totalCanvas.origin.x
        let relativeScreenY = screenFrame.origin.y - totalCanvas.origin.y
        
        let drawX = centeringX_Px + realOffsetX_Px - (relativeScreenX * deviceScale)
        let drawY = centeringY_Px - realOffsetY_Px - (relativeScreenY * deviceScale)
        
        let drawRect = CGRect(x: drawX, y: drawY, width: drawnImgWidthPx, height: drawnImgHeightPx)
        
        context.interpolationQuality = .high
        
        // Flip Logic
        if isFlipped {
            context.saveGState()
            context.translateBy(x: drawRect.midX, y: drawRect.midY)
            context.scaleBy(x: -1, y: 1)
            context.translateBy(x: -drawRect.midX, y: -drawRect.midY)
        }
        
        context.draw(cgImage, in: drawRect)
        
        if isFlipped {
            context.restoreGState()
        }
        
        guard let outputImage = context.makeImage() else { return }
        saveCGImageAndSet(outputImage, for: screen)
    }
    
    private func saveCGImageAndSet(_ image: CGImage, for screen: NSScreen) {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }

        // Use persistent storage with unique timestamp to force macOS to recognize the new wallpaper
        // macOS caches wallpaper URLs, so using the same filename prevents reapplication
        let sanitizedName = sanitizeScreenName(screen.localizedName)
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "spreadpaper_wall_\(sanitizedName)_\(timestamp).png"
        let wallpapersDir = getWallpapersDirectory()
        let url = wallpapersDir.appendingPathComponent(filename)

        // Clean up old wallpaper files for this screen (prevents disk bloat)
        cleanupOldWallpapers(for: sanitizedName, in: wallpapersDir, except: filename)

        do {
            try pngData.write(to: url)
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [.imageScaling : NSImageScaling.scaleAxesIndependently.rawValue])
        } catch {
            print("Failed to save/set wallpaper for \(screen.localizedName): \(error)")
        }
    }
}

// MARK: - VIEW

struct ContentView: View {
    @StateObject var manager = WallpaperManager()
    @StateObject var settings = AppSettings()
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
            List(selection: $selectedPresetID) {
                Section(header: Text("Saved Layouts")) {
                    Button(action: resetEditor) {
                        Label("New Setup", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.blue)
                    
                    ForEach(manager.presets) { preset in
                        HStack {
                            Label(preset.name, systemImage: "photo")
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .tag(preset.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                manager.deletePreset(preset)
                                if selectedPresetID == preset.id { resetEditor() }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet { manager.deletePreset(manager.presets[index]) }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            ZStack {
                // Background - Modern gradient
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
                
                WindowDragHandler()
                
                GeometryReader { geo in
                    let previewScale = calculatePreviewScale(geo: geo)
                    let canvasWidth = manager.totalCanvas.width * previewScale
                    let canvasHeight = manager.totalCanvas.height * previewScale

                    VStack(spacing: 0) {
                        Spacer()
                        HStack(spacing: 0) {
                            Spacer()
                            
                            // MAIN CANVAS
                            ZStack {
                                // A. Image Layer
                                ZStack {
                                    if let img = selectedImage {
                                        Image(nsImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .scaleEffect(x: isFlipped ? -1 : 1, y: 1)
                                            .frame(
                                                width: img.size.width * previewScale * imageScale,
                                                height: img.size.height * previewScale * imageScale
                                            )
                                            .offset(imageOffset)
                                            .opacity(isDragging ? 0.7 : 1.0)
                                            .animation(isDragging ? .none : .spring(response: 0.4, dampingFraction: 0.7), value: imageOffset)
                                            .highPriorityGesture(
                                                DragGesture()
                                                    .onChanged { value in
                                                        isDragging = true
                                                        let raw = CGSize(width: dragStartOffset.width + value.translation.width, height: dragStartOffset.height + value.translation.height)
                                                        imageOffset = calculateSnapping(raw: raw, imgSize: img.size, canvasSize: manager.totalCanvas.size, previewScale: previewScale, zoomScale: imageScale)
                                                    }
                                                    .onEnded { _ in
                                                        isDragging = false
                                                        dragStartOffset = imageOffset
                                                    }
                                            )
                                    } else {
                                        Button(action: selectImage) {
                                            VStack(spacing: 16) {
                                                ZStack {
                                                    Circle()
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        )
                                                        .frame(width: 80, height: 80)
                                                    Image(systemName: "photo.badge.plus")
                                                        .font(.system(size: 32))
                                                        .foregroundStyle(
                                                            LinearGradient(
                                                                colors: [.blue, .purple],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        )
                                                }
                                                VStack(spacing: 4) {
                                                    Text("Click or Drag Image Here")
                                                        .font(.title2)
                                                        .fontWeight(.semibold)
                                                    Text("Select a file to begin")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .frame(width: canvasWidth, height: canvasHeight)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(width: canvasWidth, height: canvasHeight)
                                .clipped()
                                
                                // B. Monitor Outlines
                                if selectedImage != nil {
                                    ZStack {
                                        ForEach(manager.connectedScreens) { display in
                                            let norm = normalize(frame: display.frame, total: manager.totalCanvas, scale: previewScale)
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [.blue.opacity(0.6), .purple.opacity(0.5)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 2.5
                                                    )
                                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 0)

                                                // Monitor Label
                                                Text(display.screen.localizedName)
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(.primary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Capsule()
                                                            .fill(.ultraThinMaterial)
                                                            .overlay(
                                                                Capsule()
                                                                    .stroke(
                                                                        LinearGradient(
                                                                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                                                            startPoint: .leading,
                                                                            endPoint: .trailing
                                                                        ),
                                                                        lineWidth: 1
                                                                    )
                                                            )
                                                    )
                                                    .padding(8)
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                            }
                                            .frame(width: norm.width, height: norm.height)
                                            .position(x: norm.midX, y: norm.midY)
                                        }
                                    }
                                    .frame(width: canvasWidth, height: canvasHeight)
                                    .allowsHitTesting(false)
                                }
                            }
                            .frame(width: canvasWidth, height: canvasHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(colorScheme == .dark ?
                                          Color(white: 0.15).opacity(0.5) :
                                          Color(white: 1.0).opacity(0.7))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: colorScheme == .dark ?
                                                [Color.blue.opacity(0.3), Color.purple.opacity(0.2)] :
                                                [Color.blue.opacity(0.4), Color.purple.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .contentShape(Rectangle())
                            .shadow(color: colorScheme == .dark ?
                                    Color.black.opacity(0.3) :
                                    Color.blue.opacity(0.15),
                                    radius: 30, x: 0, y: 10)
                            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                                loadDroppedImage(providers)
                                return true
                            }
                            .focusable(false)

                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.bottom, 70) // Account for toolbar height
                    .onAppear { self.currentPreviewScale = previewScale }
                    .onChange(of: geo.size) { _, _ in self.currentPreviewScale = previewScale }
                    .onChange(of: manager.totalCanvas) { _, _ in self.currentPreviewScale = previewScale }
                }

                // TOOLBAR (Native & Clean)
                VStack {
                    Spacer()
                    HStack(spacing: 20) {

                        // Zoom Group
                        HStack(spacing: 12) {
                            Button(action: { imageScale = max(0.1, imageScale - 0.1) }) {
                                Image(systemName: "minus.magnifyingglass")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedImage == nil)

                            Slider(value: $imageScale, in: 0.1...5.0)
                                .frame(width: 100)
                                .controlSize(.small)
                                .disabled(selectedImage == nil)

                            Button(action: { imageScale = min(5.0, imageScale + 0.1) }) {
                                Image(systemName: "plus.magnifyingglass")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedImage == nil)
                        }

                        Divider().frame(height: 20).opacity(0.3)

                        // Flip
                        Toggle(isOn: $isFlipped.animation()) {
                            Label("Flip", systemImage: "arrow.left.and.right")
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                        .disabled(selectedImage == nil)

                        Divider().frame(height: 20).opacity(0.3)

                        // Actions
                        Button(action: selectImage) {
                            Label("Open", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { isShowingSaveAlert = true }) {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedImage == nil || currentOriginalUrl == nil)

                        Button(action: {
                            if let img = selectedImage {
                                manager.setWallpaper(
                                    originalImage: img,
                                    imageOffset: imageOffset,
                                    scale: imageScale,
                                    previewScale: currentPreviewScale,
                                    isFlipped: isFlipped
                                )
                            }
                        }) {
                            Label("Apply Wallpaper", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedImage == nil)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 20, x: 0, y: 8)
                    .padding(.bottom, 40)
                }
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
    }
    
    // --- LOGIC ---
    
    func calculatePreviewScale(geo: GeometryProxy) -> CGFloat {
        let scaleX = geo.size.width / max(manager.totalCanvas.width, 1)
        let scaleY = geo.size.height / max(manager.totalCanvas.height, 1)
        return min(scaleX, scaleY) * 0.85
    }
    
    func resetEditor() {
        selectedImage = nil
        currentOriginalUrl = nil
        selectedPresetID = nil
        imageOffset = .zero
        imageScale = 1.0
        isFlipped = false
    }
    
    func loadPreset(_ preset: SavedPreset) {
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
    
    func calculateSnapping(raw: CGSize, imgSize: NSSize, canvasSize: CGSize, previewScale: CGFloat, zoomScale: CGFloat) -> CGSize {
        var newX = raw.width
        var newY = raw.height
        let threshold: CGFloat = 10.0
        
        let w = imgSize.width * previewScale * zoomScale
        let h = imgSize.height * previewScale * zoomScale
        let cw = canvasSize.width * previewScale
        let ch = canvasSize.height * previewScale
        
        if abs(newX) < threshold { newX = 0 }
        if abs(newX - (w - cw)/2.0) < threshold { newX = (w - cw)/2.0 }
        if abs(newX - -(w - cw)/2.0) < threshold { newX = -(w - cw)/2.0 }
        
        if abs(newY) < threshold { newY = 0 }
        if abs(newY - (h - ch)/2.0) < threshold { newY = (h - ch)/2.0 }
        if abs(newY - -(h - ch)/2.0) < threshold { newY = -(h - ch)/2.0 }
        
        return CGSize(width: newX, height: newY)
    }
    
    func normalize(frame: CGRect, total: CGRect, scale: CGFloat) -> CGRect {
        let x = (frame.origin.x - total.origin.x) * scale
        let y = (total.height - (frame.origin.y - total.origin.y) - frame.height) * scale
        return CGRect(x: x, y: y, width: frame.width * scale, height: frame.height * scale)
    }
    
    func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { loadImage(from: url) }
    }
    
    func loadDroppedImage(_ providers: [NSItemProvider]) {
        if let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url { DispatchQueue.main.async { loadImage(from: url) } }
            }
        }
    }
    
    func loadImage(from url: URL) {
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

// MARK: - SETTINGS VIEW

struct SettingsView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        TabView {
            // General Tab
            Form {
                Section {
                    Picker("Appearance", selection: $settings.selectedAppearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text("Choose how SpreadPaper appears. System matches your macOS appearance settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } header: {
                    Text("Appearance")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gear")
            }

            // Updates Tab
            Form {
                Section {
                    HStack {
                        Text("Current Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    if let info = updateChecker.updateInfo {
                        HStack {
                            Text("Latest Version")
                            Spacer()
                            Text(info.latestVersion)
                                .foregroundStyle(info.isUpdateAvailable ? .orange : .secondary)
                        }

                        if info.isUpdateAvailable {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.orange)
                                Text("Update Available")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("You're up to date")
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    HStack {
                        Button(action: { updateChecker.checkForUpdates() }) {
                            if updateChecker.isChecking {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            } else {
                                Text("Check for Updates")
                            }
                        }
                        .disabled(updateChecker.isChecking)

                        Spacer()

                        if let lastCheck = updateChecker.lastCheckDate {
                            Text("Last checked: \(lastCheck, formatter: dateFormatter)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = updateChecker.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Version")
                        .font(.headline)
                }

                if let info = updateChecker.updateInfo, info.isUpdateAvailable {
                    Section {
                        if info.dmgUrl != nil {
                            Button(action: { updateChecker.downloadDMG() }) {
                                HStack {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text("Download DMG")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if info.zipUrl != nil {
                            Button(action: { updateChecker.downloadZIP() }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Download ZIP")
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(action: { updateChecker.openReleasePage() }) {
                            HStack {
                                Image(systemName: "safari")
                                Text("View on GitHub")
                            }
                        }
                        .buttonStyle(.bordered)
                    } header: {
                        Text("Download Update")
                            .font(.headline)
                    }

                    // Changelog Section
                    Section {
                        let relevantChanges = updateChecker.getChangelogBetweenVersions()
                        if relevantChanges.isEmpty && !info.releaseNotes.isEmpty {
                            // Show release notes from GitHub if no parsed changelog
                            if let attributedString = try? AttributedString(markdown: info.releaseNotes) {
                                Text(attributedString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(info.releaseNotes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(relevantChanges, id: \.version) { entry in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("v\(entry.version)")
                                            .font(.headline)
                                        if let date = entry.date {
                                            Text("(\(date))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if let attributedString = try? AttributedString(markdown: entry.content) {
                                        Text(attributedString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(entry.content)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("What's New")
                            .font(.headline)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Updates", systemImage: "arrow.triangle.2.circlepath")
            }
            .onAppear {
                // Auto-check on first view
                if updateChecker.updateInfo == nil && !updateChecker.isChecking {
                    updateChecker.checkForUpdates()
                }
            }
        }
        .frame(width: 450, height: 400)
        .padding(20)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - HELPERS

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.styleMask.insert(.fullSizeContentView)
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.isOpaque = false
                window.backgroundColor = .clear
                window.isMovableByWindowBackground = false
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.cornerRadius = 16
                window.contentView?.layer?.masksToBounds = true
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct WindowDragHandler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DraggableView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    class DraggableView: NSView { override var mouseDownCanMoveWindow: Bool { true } }
}

#Preview {
    ContentView()
}
