# SpreadPaper Incremental Modernization — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Modernize SpreadPaper's codebase by breaking up the monolithic ContentView.swift, adopting `@Observable`/async-await, improving the rendering pipeline, and cleaning up the UI.

**Architecture:** Incremental refactor in 5 stages, each producing a compilable app. File organization into Models/Services/Views/Helpers directories. Modern Observation framework replaces Combine-based ObservableObject. Async/await replaces Combine publishers for networking and notifications.

**Tech Stack:** Swift 6, SwiftUI (macOS 15+), Observation framework, structured concurrency, CGContext rendering

**Important notes:**
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup` — Xcode auto-discovers files. No `.pbxproj` edits needed.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is enabled — all types are implicitly `@MainActor`.
- No test target exists. Verification is `xcodebuild build` at each step.
- Build command: `xcodebuild -scheme SpreadPaper -configuration Debug build -quiet`

---

## Task 1: Extract Files — Create Directory Structure and Move Code

Purely mechanical: split ContentView.swift into separate files. Zero behavior changes.

**Files:**
- Create: `SpreadPaper/Models/AppSettings.swift`
- Create: `SpreadPaper/Models/SavedPreset.swift`
- Create: `SpreadPaper/Models/DisplayInfo.swift`
- Create: `SpreadPaper/Services/WallpaperManager.swift`
- Create: `SpreadPaper/Views/CanvasView.swift`
- Create: `SpreadPaper/Views/ToolbarView.swift`
- Create: `SpreadPaper/Views/SidebarView.swift`
- Create: `SpreadPaper/Views/ImageDropZone.swift`
- Create: `SpreadPaper/Views/MonitorOverlayView.swift`
- Create: `SpreadPaper/Views/SettingsView.swift`
- Create: `SpreadPaper/Helpers/WindowAccessor.swift`
- Create: `SpreadPaper/Helpers/WindowDragHandler.swift`
- Move: `SpreadPaper/SpreadPaperApp.swift` -> `SpreadPaper/App/SpreadPaperApp.swift`
- Move: `SpreadPaper/UpdateChecker.swift` -> `SpreadPaper/Services/UpdateChecker.swift`
- Move: `SpreadPaper/UpdatePopupView.swift` -> `SpreadPaper/Views/UpdatePopupView.swift`
- Modify: `SpreadPaper/ContentView.swift` -> `SpreadPaper/Views/ContentView.swift` (slimmed down)
- Delete: original `SpreadPaper/ContentView.swift` (replaced by Views/ContentView.swift + extracted files)

### Step 1: Create directories

```bash
mkdir -p SpreadPaper/App SpreadPaper/Models SpreadPaper/Services SpreadPaper/Views SpreadPaper/Helpers
```

### Step 2: Extract model files

**`SpreadPaper/Models/AppSettings.swift`:**
```swift
import SwiftUI

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
```

**`SpreadPaper/Models/SavedPreset.swift`:**
```swift
import Foundation

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
```

**`SpreadPaper/Models/DisplayInfo.swift`:**
```swift
import AppKit

struct DisplayInfo: Identifiable {
    let id = UUID()
    let screen: NSScreen
    let frame: CGRect
}
```

### Step 3: Extract WallpaperManager

**`SpreadPaper/Services/WallpaperManager.swift`:**

Copy the entire `WallpaperManager` class (lines 53-270 of original ContentView.swift) into this file with these imports:

```swift
import AppKit
import Combine

class WallpaperManager: ObservableObject {
    // ... exact copy of lines 54-270 from original ContentView.swift
}
```

### Step 4: Extract view files

**`SpreadPaper/Views/ImageDropZone.swift`:**
```swift
import SwiftUI

struct ImageDropZone: View {
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
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
```

**`SpreadPaper/Views/MonitorOverlayView.swift`:**
```swift
import SwiftUI

struct MonitorOverlayView: View {
    let screens: [DisplayInfo]
    let totalCanvas: CGRect
    let previewScale: CGFloat
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat

    var body: some View {
        ZStack {
            ForEach(screens) { display in
                let norm = normalize(frame: display.frame, total: totalCanvas, scale: previewScale)
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

    private func normalize(frame: CGRect, total: CGRect, scale: CGFloat) -> CGRect {
        let x = (frame.origin.x - total.origin.x) * scale
        let y = (total.height - (frame.origin.y - total.origin.y) - frame.height) * scale
        return CGRect(x: x, y: y, width: frame.width * scale, height: frame.height * scale)
    }
}
```

**`SpreadPaper/Views/ToolbarView.swift`:**
```swift
import SwiftUI

struct ToolbarView: View {
    @Binding var imageScale: CGFloat
    @Binding var isFlipped: Bool
    let hasImage: Bool
    let canSave: Bool
    let colorScheme: ColorScheme
    let onSelectImage: () -> Void
    let onSave: () -> Void
    let onApply: () -> Void

    var body: some View {
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
                    .disabled(!hasImage)

                    Slider(value: $imageScale, in: 0.1...5.0)
                        .frame(width: 100)
                        .controlSize(.small)
                        .disabled(!hasImage)

                    Button(action: { imageScale = min(5.0, imageScale + 0.1) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!hasImage)
                }

                Divider().frame(height: 20).opacity(0.3)

                // Flip
                Toggle(isOn: $isFlipped.animation()) {
                    Label("Flip", systemImage: "arrow.left.and.right")
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .disabled(!hasImage)

                Divider().frame(height: 20).opacity(0.3)

                // Actions
                Button(action: onSelectImage) {
                    Label("Open", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button(action: onSave) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(!canSave)

                Button(action: onApply) {
                    Label("Apply Wallpaper", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasImage)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 20, x: 0, y: 8)
            .padding(.bottom, 40)
        }
    }
}
```

**`SpreadPaper/Views/SidebarView.swift`:**
```swift
import SwiftUI

struct SidebarView: View {
    @Binding var selectedPresetID: SavedPreset.ID?
    let presets: [SavedPreset]
    let onNewSetup: () -> Void
    let onDelete: (SavedPreset) -> Void

    var body: some View {
        List(selection: $selectedPresetID) {
            Section(header: Text("Saved Layouts")) {
                Button(action: onNewSetup) {
                    Label("New Setup", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.blue)

                ForEach(presets) { preset in
                    HStack {
                        Label(preset.name, systemImage: "photo")
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .tag(preset.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            onDelete(preset)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        onDelete(presets[index])
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }
}
```

**`SpreadPaper/Views/CanvasView.swift`:**
```swift
import SwiftUI
import UniformTypeIdentifiers

struct CanvasView: View {
    let selectedImage: NSImage?
    let manager: WallpaperManager
    let previewScale: CGFloat
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat
    @Binding var imageOffset: CGSize
    @Binding var dragStartOffset: CGSize
    @Binding var imageScale: CGFloat
    @Binding var isDragging: Bool
    @Binding var isFlipped: Bool
    let colorScheme: ColorScheme
    let onSelectImage: () -> Void
    let onDrop: ([NSItemProvider]) -> Void

    var body: some View {
        ZStack {
            // Image Layer
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
                                    let raw = CGSize(
                                        width: dragStartOffset.width + value.translation.width,
                                        height: dragStartOffset.height + value.translation.height
                                    )
                                    imageOffset = calculateSnapping(
                                        raw: raw,
                                        imgSize: img.size,
                                        canvasSize: manager.totalCanvas.size,
                                        previewScale: previewScale,
                                        zoomScale: imageScale
                                    )
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    dragStartOffset = imageOffset
                                }
                        )
                } else {
                    ImageDropZone(
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight,
                        onSelect: onSelectImage
                    )
                }
            }
            .frame(width: canvasWidth, height: canvasHeight)
            .clipped()

            // Monitor Outlines
            if selectedImage != nil {
                MonitorOverlayView(
                    screens: manager.connectedScreens,
                    totalCanvas: manager.totalCanvas,
                    previewScale: previewScale,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight
                )
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
            onDrop(providers.map { $0 })
            return true
        }
        .focusable(false)
    }

    private func calculateSnapping(raw: CGSize, imgSize: NSSize, canvasSize: CGSize, previewScale: CGFloat, zoomScale: CGFloat) -> CGSize {
        var newX = raw.width
        var newY = raw.height
        let threshold: CGFloat = 10.0

        let w = imgSize.width * previewScale * zoomScale
        let h = imgSize.height * previewScale * zoomScale
        let cw = canvasSize.width * previewScale
        let ch = canvasSize.height * previewScale

        if abs(newX) < threshold { newX = 0 }
        if abs(newX - (w - cw) / 2.0) < threshold { newX = (w - cw) / 2.0 }
        if abs(newX - -(w - cw) / 2.0) < threshold { newX = -(w - cw) / 2.0 }

        if abs(newY) < threshold { newY = 0 }
        if abs(newY - (h - ch) / 2.0) < threshold { newY = (h - ch) / 2.0 }
        if abs(newY - -(h - ch) / 2.0) < threshold { newY = -(h - ch) / 2.0 }

        return CGSize(width: newX, height: newY)
    }
}
```

**`SpreadPaper/Views/SettingsView.swift`:**

Copy the entire `SettingsView` struct (lines 720-919 of original ContentView.swift) into this file with these imports:

```swift
import SwiftUI

struct SettingsView: View {
    // ... exact copy of the SettingsView from original ContentView.swift lines 720-919
}
```

### Step 5: Extract helpers

**`SpreadPaper/Helpers/WindowAccessor.swift`:**
```swift
import SwiftUI

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
```

**`SpreadPaper/Helpers/WindowDragHandler.swift`:**
```swift
import SwiftUI

struct WindowDragHandler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DraggableView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    class DraggableView: NSView { override var mouseDownCanMoveWindow: Bool { true } }
}
```

### Step 6: Move existing files to new locations

```bash
mv SpreadPaper/SpreadPaperApp.swift SpreadPaper/App/SpreadPaperApp.swift
mv SpreadPaper/UpdateChecker.swift SpreadPaper/Services/UpdateChecker.swift
mv SpreadPaper/UpdatePopupView.swift SpreadPaper/Views/UpdatePopupView.swift
```

### Step 7: Rewrite ContentView.swift as slim composition view

Replace the original `SpreadPaper/ContentView.swift` with a slimmed-down version at `SpreadPaper/Views/ContentView.swift` that delegates to extracted subviews. Move the `normalize` helper into `MonitorOverlayView`. Keep image loading, preset loading, and `selectImage` logic in ContentView since they coordinate state across subviews.

```swift
import SwiftUI
import UniformTypeIdentifiers

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
                                manager: manager,
                                previewScale: previewScale,
                                canvasWidth: canvasWidth,
                                canvasHeight: canvasHeight,
                                imageOffset: $imageOffset,
                                dragStartOffset: $dragStartOffset,
                                imageScale: $imageScale,
                                isDragging: $isDragging,
                                isFlipped: $isFlipped,
                                colorScheme: colorScheme,
                                onSelectImage: selectImage,
                                onDrop: loadDroppedImage
                            )
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.bottom, 70)
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
            if let id = newVal, let preset = manager.presets.first(where: { $0.id == id }) {
                loadPreset(preset)
            }
        }
        .background(WindowAccessor())
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(settings.colorScheme)
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundGradient: some View {
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
```

### Step 8: Delete the original ContentView.swift

```bash
rm SpreadPaper/ContentView.swift
```

### Step 9: Build to verify

```bash
xcodebuild -scheme SpreadPaper -configuration Debug build -quiet
```

Expected: BUILD SUCCEEDED

### Step 10: Commit

```bash
git add -A
git commit -m "refactor: extract ContentView.swift monolith into organized file structure

Split the 953-line ContentView.swift into Models/, Services/, Views/,
and Helpers/ directories. No behavior changes."
```

---

## Task 2: Adopt @Observable Macro

Replace `ObservableObject`/`@Published`/`@StateObject` with the modern Observation framework.

**Files:**
- Modify: `SpreadPaper/Models/AppSettings.swift`
- Modify: `SpreadPaper/Services/WallpaperManager.swift`
- Modify: `SpreadPaper/Services/UpdateChecker.swift`
- Modify: `SpreadPaper/Views/ContentView.swift`
- Modify: `SpreadPaper/App/SpreadPaperApp.swift`
- Modify: `SpreadPaper/Views/SettingsView.swift`
- Modify: `SpreadPaper/Views/UpdatePopupView.swift`
- Modify: `SpreadPaper/Views/CanvasView.swift`

### Step 1: Convert AppSettings to @Observable

`@AppStorage` doesn't work inside `@Observable` classes. Use `UserDefaults` with `didSet` instead.

```swift
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

@Observable
class AppSettings {
    var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appearanceMode") ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: raw) ?? .system
    }
}
```

### Step 2: Convert WallpaperManager to @Observable

In `SpreadPaper/Services/WallpaperManager.swift`:
- Change `class WallpaperManager: ObservableObject` to `@Observable class WallpaperManager`
- Remove all `@Published` property wrappers
- Keep the `Combine` import and `cancellables` for now (screen notification listener will be converted in Task 3)

```swift
import AppKit
import Combine

@Observable
class WallpaperManager {
    var connectedScreens: [DisplayInfo] = []
    var totalCanvas: CGRect = .zero
    var presets: [SavedPreset] = []

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

    // ... rest of the methods stay identical
}
```

### Step 3: Convert UpdateChecker to @Observable

In `SpreadPaper/Services/UpdateChecker.swift`:
- Change `class UpdateChecker: ObservableObject` to `@Observable class UpdateChecker`
- Remove all `@Published` property wrappers
- Keep Combine networking for now (Task 3 converts it)

```swift
@Observable
class UpdateChecker {
    static let shared = UpdateChecker()

    var updateInfo: UpdateInfo?
    var isChecking = false
    var lastCheckDate: Date?
    var error: String?
    var changelog: [ChangelogEntry] = []

    private let repoOwner = "spreadpaper"
    private let repoName = "SpreadPaper"
    private var cancellables = Set<AnyCancellable>()

    // ... rest stays identical
}
```

### Step 4: Update all views to use @State instead of @StateObject

In `SpreadPaper/Views/ContentView.swift`:
- `@StateObject var manager = WallpaperManager()` -> `@State var manager = WallpaperManager()`
- `@StateObject var settings = AppSettings()` -> `@State var settings = AppSettings()`

In `SpreadPaper/App/SpreadPaperApp.swift`:
- `@StateObject private var updateChecker = UpdateChecker.shared` -> `@State private var updateChecker = UpdateChecker.shared`

In `SpreadPaper/Views/SettingsView.swift`:
- `@StateObject private var settings = AppSettings()` -> `@State private var settings = AppSettings()`
- `@StateObject private var updateChecker = UpdateChecker.shared` -> `@State private var updateChecker = UpdateChecker.shared`

In `SpreadPaper/Views/UpdatePopupView.swift`:
- `@ObservedObject var updateChecker: UpdateChecker` -> just `var updateChecker: UpdateChecker` (Observation framework tracks automatically)

In `SpreadPaper/Views/CanvasView.swift`:
- `let manager: WallpaperManager` stays the same (Observation tracks property access automatically)

### Step 5: Build to verify

```bash
xcodebuild -scheme SpreadPaper -configuration Debug build -quiet
```

Expected: BUILD SUCCEEDED

### Step 6: Commit

```bash
git add -A
git commit -m "refactor: adopt @Observable macro for all observable classes

Replace ObservableObject/@Published/@StateObject with @Observable/@State.
AppSettings uses UserDefaults directly since @AppStorage is incompatible
with @Observable."
```

---

## Task 3: Convert Combine to Async/Await

Replace Combine publishers with structured concurrency.

**Files:**
- Modify: `SpreadPaper/Services/UpdateChecker.swift`
- Modify: `SpreadPaper/Services/WallpaperManager.swift`
- Modify: `SpreadPaper/App/SpreadPaperApp.swift`

### Step 1: Convert UpdateChecker networking to async/await

Replace the full `UpdateChecker` class. Key changes:
- `checkForUpdates()` becomes `func checkForUpdates() async`
- `fetchChangelog()` becomes `func fetchChangelog() async`
- Remove `cancellables` and `import Combine`
- Callers wrap in `Task {}`

```swift
import Foundation
import AppKit

// Models stay identical (GitHubRelease, GitHubAsset, UpdateInfo, ChangelogEntry)

@Observable
class UpdateChecker {
    static let shared = UpdateChecker()

    var updateInfo: UpdateInfo?
    var isChecking = false
    var lastCheckDate: Date?
    var error: String?
    var changelog: [ChangelogEntry] = []

    private let repoOwner = "spreadpaper"
    private let repoName = "SpreadPaper"

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var apiBaseUrl: String {
        "https://api.github.com/repos/\(repoOwner)/\(repoName)"
    }

    // MARK: - Public Methods

    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        error = nil

        do {
            let url = URL(string: "\(apiBaseUrl)/releases/latest")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("SpreadPaper/\(currentVersion)", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            processRelease(release)

            if updateInfo?.isUpdateAvailable == true {
                await fetchChangelog()
            }
        } catch {
            self.error = "Failed to check for updates: \(error.localizedDescription)"
        }

        isChecking = false
        lastCheckDate = Date()
    }

    func fetchChangelog() async {
        do {
            let url = URL(string: "https://raw.githubusercontent.com/\(repoOwner)/\(repoName)/main/CHANGELOG.md")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let content = String(data: data, encoding: .utf8) ?? ""
            parseChangelog(content)
        } catch {
            // Changelog fetch is best-effort
        }
    }

    func openReleasePage() {
        if let urlString = updateInfo?.releaseUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    func downloadDMG() {
        if let urlString = updateInfo?.dmgUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    func downloadZIP() {
        if let urlString = updateInfo?.zipUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private Methods

    // processRelease, compareVersions, parseChangelog, getChangelogBetweenVersions
    // stay identical to current implementation
}
```

### Step 2: Convert WallpaperManager screen notifications to async

Replace the Combine-based notification listener with an async `for await` loop. Remove `import Combine` and `cancellables`.

```swift
import AppKit

@Observable
class WallpaperManager {
    var connectedScreens: [DisplayInfo] = []
    var totalCanvas: CGRect = .zero
    var presets: [SavedPreset] = []

    private let presetsFile = "spreadpaper_presets.json"

    init() {
        refreshScreens()
        loadPresets()
    }

    func listenForScreenChanges() async {
        for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
            refreshScreens()
        }
    }

    // ... rest of methods stay identical
}
```

### Step 3: Update SpreadPaperApp.swift callers

Replace `DispatchQueue.main.asyncAfter` with `Task.sleep` and `.task` modifier:

```swift
import SwiftUI

@main
struct SpreadPaperApp: App {
    @State private var updateChecker = UpdateChecker.shared
    @State private var showUpdatePopup = false
    @State private var hasCheckedForUpdates = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay {
                    if showUpdatePopup {
                        updatePopupOverlay
                    }
                }
                .task {
                    await checkForUpdatesOnStartup()
                }

        }

        Settings {
            SettingsView()
        }
    }

    private var updatePopupOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showUpdatePopup = false
                }

            UpdatePopupView(
                updateChecker: updateChecker,
                isPresented: $showUpdatePopup
            )
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showUpdatePopup)
    }

    private func checkForUpdatesOnStartup() async {
        guard !hasCheckedForUpdates else { return }
        hasCheckedForUpdates = true

        try? await Task.sleep(for: .seconds(1))
        await updateChecker.checkForUpdates()

        if let info = updateChecker.updateInfo, info.isUpdateAvailable {
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation {
                showUpdatePopup = true
            }
        }
    }
}
```

### Step 4: Update ContentView to start screen listener

Add `.task` modifier to start the screen change listener:

In `SpreadPaper/Views/ContentView.swift`, add to the `NavigationSplitView`:

```swift
.task {
    await manager.listenForScreenChanges()
}
```

### Step 5: Update SettingsView check-for-updates call

In `SpreadPaper/Views/SettingsView.swift`, change:
- `.onAppear { if ... { updateChecker.checkForUpdates() } }` to `.task { if ... { await updateChecker.checkForUpdates() } }`
- The "Check for Updates" button: wrap in `Task { await updateChecker.checkForUpdates() }`

### Step 6: Build to verify

```bash
xcodebuild -scheme SpreadPaper -configuration Debug build -quiet
```

Expected: BUILD SUCCEEDED

### Step 7: Commit

```bash
git add -A
git commit -m "refactor: replace Combine with async/await

Convert UpdateChecker networking to async URLSession.
Convert WallpaperManager screen notifications to async sequence.
Remove all Combine imports and cancellables."
```

---

## Task 4: Rendering Pipeline Improvements

Improve color space handling, move rendering off main thread, and surface errors.

**Files:**
- Modify: `SpreadPaper/Services/WallpaperManager.swift`
- Modify: `SpreadPaper/Views/ContentView.swift`

### Step 1: Add error property and async rendering to WallpaperManager

Key changes:
- Add `var lastError: String?` property
- Make `setWallpaper` async and move CGContext rendering to a detached task
- Use screen's native color space instead of hardcoded sRGB
- Propagate errors instead of silently returning

```swift
// In WallpaperManager:

var lastError: String?

func setWallpaper(originalImage: NSImage, imageOffset: CGSize, scale: CGFloat, previewScale: CGFloat, isFlipped: Bool) async {
    lastError = nil

    // Capture screen info on main thread (NSScreen is main-thread-only)
    let displays = connectedScreens.map { display in
        (screen: display.screen,
         frame: display.frame,
         scaleFactor: display.screen.backingScaleFactor,
         colorSpace: display.screen.colorSpace?.cgColorSpace,
         name: display.screen.localizedName)
    }

    for display in displays {
        do {
            let image = try renderForScreen(
                original: originalImage,
                screenFrame: display.frame,
                totalCanvas: totalCanvas,
                offset: imageOffset,
                imageScale: scale,
                previewScale: previewScale,
                isFlipped: isFlipped,
                deviceScale: display.scaleFactor,
                screenColorSpace: display.colorSpace
            )
            try saveAndSetWallpaper(image, screenName: display.name, screen: display.screen)
        } catch {
            lastError = "Failed to set wallpaper for \(display.name): \(error.localizedDescription)"
        }
    }
}

private nonisolated func renderForScreen(
    original: NSImage,
    screenFrame: CGRect,
    totalCanvas: CGRect,
    offset: CGSize,
    imageScale: CGFloat,
    previewScale: CGFloat,
    isFlipped: Bool,
    deviceScale: CGFloat,
    screenColorSpace: CGColorSpace?
) throws -> CGImage {
    var rect = CGRect(origin: .zero, size: original.size)
    guard let cgImage = original.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
        throw WallpaperError.imageConversionFailed
    }

    let widthPx = Int(screenFrame.width * deviceScale)
    let heightPx = Int(screenFrame.height * deviceScale)

    let colorSpace = screenColorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    guard let context = CGContext(
        data: nil,
        width: widthPx,
        height: heightPx,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw WallpaperError.contextCreationFailed
    }

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

    guard let outputImage = context.makeImage() else {
        throw WallpaperError.renderingFailed
    }

    return outputImage
}

private func saveAndSetWallpaper(_ image: CGImage, screenName: String, screen: NSScreen) throws {
    let bitmapRep = NSBitmapImageRep(cgImage: image)
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        throw WallpaperError.pngEncodingFailed
    }

    let sanitizedName = sanitizeScreenName(screenName)
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let filename = "spreadpaper_wall_\(sanitizedName)_\(timestamp).png"
    let wallpapersDir = getWallpapersDirectory()
    let url = wallpapersDir.appendingPathComponent(filename)

    cleanupOldWallpapers(for: sanitizedName, in: wallpapersDir, except: filename)

    try pngData.write(to: url)
    try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [
        .imageScaling: NSImageScaling.scaleAxesIndependently.rawValue
    ])
}

enum WallpaperError: LocalizedError {
    case imageConversionFailed
    case contextCreationFailed
    case renderingFailed
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "Failed to convert image to CGImage"
        case .contextCreationFailed: return "Failed to create rendering context"
        case .renderingFailed: return "Failed to render wallpaper image"
        case .pngEncodingFailed: return "Failed to encode image as PNG"
        }
    }
}
```

### Step 2: Update ContentView to handle async setWallpaper

In `SpreadPaper/Views/ContentView.swift`, update `applyWallpaper`:

```swift
private func applyWallpaper() {
    if let img = selectedImage {
        Task {
            await manager.setWallpaper(
                originalImage: img,
                imageOffset: imageOffset,
                scale: imageScale,
                previewScale: currentPreviewScale,
                isFlipped: isFlipped
            )
        }
    }
}
```

Optionally display `manager.lastError` somewhere in the UI (e.g., as an alert or a small error banner).

### Step 3: Build to verify

```bash
xcodebuild -scheme SpreadPaper -configuration Debug build -quiet
```

Expected: BUILD SUCCEEDED

### Step 4: Commit

```bash
git add -A
git commit -m "feat: improve rendering pipeline

Use screen's native color space for better wide-gamut display support.
Extract pure rendering function as nonisolated for future off-main-thread use.
Surface rendering errors instead of silently failing."
```

---

## Task 5: UI Cleanup

Simplify styling, clean up remaining patterns.

**Files:**
- Modify: `SpreadPaper/Views/ContentView.swift`
- Modify: `SpreadPaper/Views/CanvasView.swift`
- Modify: `SpreadPaper/Views/SettingsView.swift`

### Step 1: Simplify background gradient

In `ContentView.swift`, replace the hardcoded RGBA gradients with a simpler approach:

```swift
@ViewBuilder
private var backgroundGradient: some View {
    Rectangle()
        .fill(.background)
        .ignoresSafeArea()
}
```

Or if the custom gradient look is preferred, keep it but extract to a reusable modifier or view.

### Step 2: Review and simplify SettingsView

Verify SettingsView works with `@Observable` UpdateChecker. The `.task` modifier replaces `.onAppear` for async work:

```swift
.task {
    if updateChecker.updateInfo == nil && !updateChecker.isChecking {
        await updateChecker.checkForUpdates()
    }
}
```

### Step 3: Build to verify

```bash
xcodebuild -scheme SpreadPaper -configuration Debug build -quiet
```

Expected: BUILD SUCCEEDED

### Step 4: Final commit

```bash
git add -A
git commit -m "refactor: clean up UI styling and remaining patterns

Simplify background gradients and update remaining view patterns."
```
