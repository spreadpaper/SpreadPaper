# Cool Dark UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all SwiftUI views with custom-styled Cool Dark UI — gallery-first layout, per-row schedule range bars, welcome wizard, no default SwiftUI component chrome.

**Architecture:** SwiftUI + AppKit hybrid. SwiftUI handles layout, navigation, and state via @Observable. AppKit (NSViewRepresentable) handles pixel-level custom components: range bars with draggable handles, custom sliders. All views styled with CoolDarkTheme color tokens and custom ViewModifiers.

**Tech Stack:** Swift 6, SwiftUI, AppKit (NSViewRepresentable), @Observable macro

**Design spec:** `docs/superpowers/specs/2026-04-08-ui-redesign-design.md`

---

## File Structure

### New files
- `SpreadPaper/Theme/CoolDarkTheme.swift` — Color tokens, ButtonStyles, ViewModifiers
- `SpreadPaper/Theme/CoolDarkComponents.swift` — Reusable styled components (SegmentedControl, DarkTextField, etc.)
- `SpreadPaper/Views/GalleryView.swift` — Home screen grid with filter tabs
- `SpreadPaper/Views/GalleryCardView.swift` — Image-forward wallpaper card
- `SpreadPaper/Views/CreationModal.swift` — Type picker sheet (Standard / Dynamic / Light-Dark)
- `SpreadPaper/Views/EditorView.swift` — Canvas + right panel, all three modes
- `SpreadPaper/Views/EditorCanvasView.swift` — Monitor preview canvas (refactored from CanvasView)
- `SpreadPaper/Views/MonitorPreviewView.swift` — Monitor outlines + mask (refactored from MonitorOverlayView)
- `SpreadPaper/Views/ScheduleView.swift` — Per-row range bars list with drag-to-reorder
- `SpreadPaper/Views/RangeBarView.swift` — NSViewRepresentable: draggable start/end handles, snap-to-10min
- `SpreadPaper/Views/WizardView.swift` — 2-step welcome flow
- `SpreadPaper/Navigation/AppNavigation.swift` — Navigation state model

### Modified files
- `SpreadPaper/App/SpreadPaperApp.swift` — New window config, dark appearance, navigation
- `SpreadPaper/Models/AppSettings.swift` — Add `hasCompletedWizard`
- `SpreadPaper/Models/SavedPreset.swift` — Add `wallpaperType` enum

### Removed files (Task 13)
- `SpreadPaper/Views/ContentView.swift`
- `SpreadPaper/Views/SidebarView.swift`
- `SpreadPaper/Views/DynamicEditorView.swift`
- `SpreadPaper/Views/TimelineView.swift`
- `SpreadPaper/Views/ImageDropZone.swift`
- `SpreadPaper/Views/CanvasView.swift`
- `SpreadPaper/Views/MonitorOverlayView.swift`
- `SpreadPaper/Helpers/GlassModifiers.swift`
- `SpreadPaper/Helpers/WindowDragHandler.swift`
- `SpreadPaper/Helpers/WindowAccessor.swift`

---

### Task 1: CoolDarkTheme — Color Tokens and Base Styles

**Files:**
- Create: `SpreadPaper/Theme/CoolDarkTheme.swift`

- [ ] **Step 1: Create the theme file with all color tokens and base styles**

```swift
// SpreadPaper/Theme/CoolDarkTheme.swift

import SwiftUI

// MARK: - Color Tokens

extension Color {
    static let cdBgPrimary = Color(hex: 0x16161a)
    static let cdBgSecondary = Color(hex: 0x1e1e24)
    static let cdBgElevated = Color(hex: 0x24242c)
    static let cdBorder = Color(hex: 0x2a2a32)
    static let cdTextPrimary = Color(hex: 0xe8e8ed)
    static let cdTextSecondary = Color(hex: 0x9e9eaa)
    static let cdTextTertiary = Color(hex: 0x6e6e7a)
    static let cdAccent = Color(hex: 0x5e5ce6)
    static let cdAccentGlow = Color(hex: 0x5e5ce6).opacity(0.2)
    static let cdSuccess = Color(hex: 0x34C759)
    static let cdCanvasBg = Color(hex: 0x111114)
    static let cdDanger = Color(hex: 0xFF453A)

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Button Styles

struct CoolDarkButtonStyle: ButtonStyle {
    var isPrimary: Bool = false
    var isSuccess: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isPrimary || isSuccess ? .white : Color.cdTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSuccess ? Color.cdSuccess : isPrimary ? Color.cdAccent : Color.cdBgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isPrimary || isSuccess ? Color.clear : Color.cdBorder, lineWidth: 1)
            )
            .shadow(color: isSuccess ? Color.cdSuccess.opacity(0.3) : isPrimary ? Color.cdAccent.opacity(0.3) : .clear, radius: 8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct CoolDarkIconButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .foregroundStyle(isDisabled ? Color.cdTextTertiary : Color.cdTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.cdBgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : isDisabled ? 0.5 : 1.0)
    }
}

// MARK: - View Modifiers

struct CoolDarkPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cdBgSecondary)
    }
}

struct CoolDarkCard: ViewModifier {
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .background(Color.cdBgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.cdAccent : Color.cdBorder, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? Color.cdAccentGlow : .clear, radius: 8)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.cdTextTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - Convenience Extensions

extension View {
    func coolDarkPanel() -> some View {
        modifier(CoolDarkPanel())
    }

    func coolDarkCard(isSelected: Bool = false) -> some View {
        modifier(CoolDarkCard(isSelected: isSelected))
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/Theme/CoolDarkTheme.swift
git commit -m "feat: add CoolDarkTheme with color tokens, button styles, view modifiers"
```

---

### Task 2: CoolDarkComponents — Reusable Styled Components

**Files:**
- Create: `SpreadPaper/Theme/CoolDarkComponents.swift`

- [ ] **Step 1: Create reusable components**

```swift
// SpreadPaper/Theme/CoolDarkComponents.swift

import SwiftUI

// MARK: - Custom Segmented Control

struct CoolDarkSegmentedControl: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selection = index } }) {
                    Text(options[index])
                        .font(.system(size: 10, weight: index == selection ? .semibold : .regular))
                        .foregroundStyle(index == selection ? .white : Color.cdTextTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(index == selection ? Color.cdAccent : Color.cdBgSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.cdBorder)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

// MARK: - Custom Text Field

struct CoolDarkTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(Color.cdTextPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.cdBgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
    }
}

// MARK: - Custom Zoom Slider

struct CoolDarkSlider: View {
    @Binding var value: CGFloat
    var range: ClosedRange<CGFloat> = 0.1...5.0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbX = fraction * width

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cdBorder)
                    .frame(height: 4)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cdAccent)
                    .frame(width: thumbX, height: 4)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .stroke(Color.cdAccent, lineWidth: 1.5)
                    .frame(width: 12, height: 12)
                    .offset(x: thumbX - 6)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = max(0, min(1, drag.location.x / width))
                        value = range.lowerBound + CGFloat(fraction) * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 12)
    }
}

// MARK: - Tooltip Overlay

struct FirstRunTooltip: View {
    let text: String
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // Arrow
                Triangle()
                    .fill(Color(hex: 0x333338))
                    .frame(width: 12, height: 6)

                // Body
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: 0x333338))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .onTapGesture { withAnimation { isVisible = false } }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dashed Add Button

struct DashedAddButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cdTextTertiary)
                Spacer()
            }
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(Color.cdBorder)
            )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/Theme/CoolDarkComponents.swift
git commit -m "feat: add CoolDark reusable components — segmented control, slider, text field, tooltip"
```

---

### Task 3: Navigation Model and AppSettings Update

**Files:**
- Create: `SpreadPaper/Navigation/AppNavigation.swift`
- Modify: `SpreadPaper/Models/AppSettings.swift`
- Modify: `SpreadPaper/Models/SavedPreset.swift`

- [ ] **Step 1: Create navigation state model**

```swift
// SpreadPaper/Navigation/AppNavigation.swift

import SwiftUI

enum WallpaperType: String, CaseIterable, Codable {
    case standard = "Static"
    case dynamic = "Dynamic"
    case appearance = "Light/Dark"
}

enum GalleryFilter: Int, CaseIterable {
    case all = 0
    case standard = 1
    case dynamic = 2
    case appearance = 3

    var label: String {
        switch self {
        case .all: return "All"
        case .standard: return "Static"
        case .dynamic: return "Dynamic"
        case .appearance: return "Light/Dark"
        }
    }
}

enum AppRoute: Equatable {
    case wizard
    case gallery
    case editor(presetId: UUID?)  // nil = new, creating
    case editorNew(type: WallpaperType)
}

@Observable
class AppNavigation {
    var route: AppRoute = .gallery
    var showCreationModal = false

    func navigateToGallery() {
        withAnimation(.easeInOut(duration: 0.2)) {
            route = .gallery
        }
    }

    func navigateToEditor(presetId: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            route = .editor(presetId: presetId)
        }
    }

    func navigateToNewEditor(type: WallpaperType) {
        showCreationModal = false
        withAnimation(.easeInOut(duration: 0.2)) {
            route = .editorNew(type: type)
        }
    }
}
```

- [ ] **Step 2: Update AppSettings**

Add `hasCompletedWizard` to `SpreadPaper/Models/AppSettings.swift`:

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
    static let shared = AppSettings()

    var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    var hasCompletedWizard: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedWizard, forKey: "hasCompletedWizard")
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
        self.hasCompletedWizard = UserDefaults.standard.bool(forKey: "hasCompletedWizard")
    }
}
```

- [ ] **Step 3: Add wallpaperType to SavedPreset**

```swift
// SpreadPaper/Models/SavedPreset.swift

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
    var isDynamic: Bool = false
    var timeVariants: [TimeVariant] = []

    /// Computed from isDynamic and timeVariants for display
    var wallpaperType: String {
        if isDynamic && timeVariants.count == 2 &&
           timeVariants.contains(where: { $0.hour == 12 && $0.minute == 0 }) &&
           timeVariants.contains(where: { $0.hour == 0 && $0.minute == 0 }) {
            return "Light/Dark"
        } else if isDynamic {
            return "Dynamic"
        }
        return "Static"
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add SpreadPaper/Navigation/AppNavigation.swift SpreadPaper/Models/AppSettings.swift SpreadPaper/Models/SavedPreset.swift
git commit -m "feat: add navigation model, wizard flag, wallpaper type display

AppNavigation manages gallery/editor/wizard routing. AppSettings
tracks hasCompletedWizard. SavedPreset computes wallpaperType
for display."
```

---

### Task 4: GalleryCardView — Image-Forward Cards

**Files:**
- Create: `SpreadPaper/Views/GalleryCardView.swift`

- [ ] **Step 1: Create the gallery card**

```swift
// SpreadPaper/Views/GalleryCardView.swift

import SwiftUI

struct GalleryCardView: View {
    let preset: SavedPreset
    let thumbnail: NSImage?
    let isActive: Bool
    let onTap: () -> Void
    let onApply: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                // Image
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(16/10, contentMode: .fill)
                        .clipped()
                } else {
                    Color.cdBgElevated
                        .aspectRatio(16/10, contentMode: .fill)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(Color.cdTextTertiary)
                        }
                }

                // Gradient overlay with info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(preset.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        if isActive {
                            Circle()
                                .fill(Color.cdSuccess)
                                .frame(width: 6, height: 6)
                        }
                    }
                    Text(typeLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.cdAccent : Color.cdBorder, lineWidth: isActive ? 2 : 1)
            )
            .shadow(color: isActive ? Color.cdAccentGlow : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Apply") { onApply() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var typeLabel: String {
        let type = preset.wallpaperType
        if type == "Dynamic" {
            return "☀ Dynamic · \(preset.timeVariants.count) images"
        } else if type == "Light/Dark" {
            return "◐ Light / Dark"
        }
        return "🖼 Static"
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/Views/GalleryCardView.swift
git commit -m "feat: add GalleryCardView — image-forward card with overlay info"
```

---

### Task 5: GalleryView — Home Screen Grid

**Files:**
- Create: `SpreadPaper/Views/GalleryView.swift`

- [ ] **Step 1: Create the gallery view**

```swift
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
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/Views/GalleryView.swift
git commit -m "feat: add GalleryView — image-forward grid with filter tabs and empty state"
```

---

### Task 6: CreationModal — Type Picker

**Files:**
- Create: `SpreadPaper/Views/CreationModal.swift`

- [ ] **Step 1: Create the creation modal**

```swift
// SpreadPaper/Views/CreationModal.swift

import SwiftUI

struct CreationModal: View {
    @Bindable var navigation: AppNavigation

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { navigation.showCreationModal = false }

            // Modal
            VStack(spacing: 0) {
                Text("New Wallpaper")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.cdTextPrimary)
                    .padding(.top, 20)

                Text("Choose what kind of wallpaper to create")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cdTextTertiary)
                    .padding(.top, 4)
                    .padding(.bottom, 16)

                VStack(spacing: 8) {
                    CreationRow(
                        icon: "photo",
                        iconGradient: [Color(hex: 0x007AFF), Color(hex: 0x5856D6)],
                        title: "Standard Wallpaper",
                        subtitle: "One image spread across your monitors"
                    ) {
                        navigation.navigateToNewEditor(type: .standard)
                    }

                    CreationRow(
                        icon: "sun.max.fill",
                        iconGradient: [Color(hex: 0xFF9500), Color(hex: 0xFF2D55)],
                        title: "Time of Day",
                        subtitle: "Wallpaper shifts throughout the day"
                    ) {
                        navigation.navigateToNewEditor(type: .dynamic)
                    }

                    CreationRow(
                        icon: "circle.lefthalf.filled",
                        iconGradient: [Color(hex: 0x636366), Color(hex: 0x48484a)],
                        title: "Light & Dark",
                        subtitle: "Different image for each appearance mode"
                    ) {
                        navigation.navigateToNewEditor(type: .appearance)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 340)
            .background(Color.cdBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 20)
        }
    }
}

private struct CreationRow: View {
    let icon: String
    let iconGradient: [Color]
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cdTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cdTextTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cdTextTertiary)
            }
            .padding(10)
            .background(Color.cdBgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/Views/CreationModal.swift
git commit -m "feat: add CreationModal — type picker with Standard / Dynamic / Light-Dark"
```

---

### Task 7: RangeBarView — AppKit Custom Draggable Range Bar

**Files:**
- Create: `SpreadPaper/Views/RangeBarView.swift`

This is the most complex custom component. An NSView that draws a 24-hour bar with a colored range fill and two draggable handles that snap to 10-minute marks.

- [ ] **Step 1: Create the NSViewRepresentable range bar**

```swift
// SpreadPaper/Views/RangeBarView.swift

import SwiftUI
import AppKit

struct RangeBarView: NSViewRepresentable {
    @Binding var startFraction: Double  // 0.0–1.0 (fraction of 24h)
    @Binding var endFraction: Double    // 0.0–1.0
    var accentColor: NSColor = NSColor(Color.cdAccent)
    var isSelected: Bool = false

    func makeNSView(context: Context) -> RangeBarNSView {
        let view = RangeBarNSView()
        view.onRangeChanged = { start, end in
            startFraction = start
            endFraction = end
        }
        return view
    }

    func updateNSView(_ nsView: RangeBarNSView, context: Context) {
        nsView.startFraction = startFraction
        nsView.endFraction = endFraction
        nsView.accentColor = accentColor
        nsView.isSelected = isSelected
        nsView.needsDisplay = true
    }
}

class RangeBarNSView: NSView {
    var startFraction: Double = 0.0
    var endFraction: Double = 1.0
    var accentColor: NSColor = .systemIndigo
    var isSelected: Bool = false
    var onRangeChanged: ((Double, Double) -> Void)?

    private var dragging: DragTarget = .none
    private let handleWidth: CGFloat = 8
    private let barHeight: CGFloat = 8
    private let snapInterval: Double = 10.0 / (24.0 * 60.0) // 10 minutes as fraction of day

    private enum DragTarget {
        case none, start, end
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let barY = (bounds.height - barHeight) / 2
        let barRect = CGRect(x: 0, y: barY, width: bounds.width, height: barHeight)

        // Background track
        ctx.setFillColor(NSColor(Color.cdBorder).cgColor)
        let bgPath = CGPath(roundedRect: barRect, cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil)
        ctx.addPath(bgPath)
        ctx.fillPath()

        // 6-hour tick marks
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.06).cgColor)
        ctx.setLineWidth(1)
        for tick in [0.25, 0.5, 0.75] {
            let x = bounds.width * tick
            ctx.move(to: CGPoint(x: x, y: barY))
            ctx.addLine(to: CGPoint(x: x, y: barY + barHeight))
            ctx.strokePath()
        }

        // Active range fill
        let wraps = endFraction < startFraction
        let alpha: CGFloat = isSelected ? 0.45 : 0.25
        ctx.setFillColor(accentColor.withAlphaComponent(alpha).cgColor)

        if wraps {
            // Wraps around midnight: fill end..1.0 and 0.0..start
            let rightRect = CGRect(x: bounds.width * startFraction, y: barY, width: bounds.width * (1.0 - startFraction), height: barHeight)
            ctx.fill(rightRect)
            let leftRect = CGRect(x: 0, y: barY, width: bounds.width * endFraction, height: barHeight)
            ctx.fill(leftRect)
        } else {
            let fillRect = CGRect(x: bounds.width * startFraction, y: barY, width: bounds.width * (endFraction - startFraction), height: barHeight)
            ctx.fill(fillRect)
        }

        // Draw handles
        drawHandle(ctx: ctx, fraction: startFraction, barY: barY)
        drawHandle(ctx: ctx, fraction: endFraction, barY: barY)
    }

    private func drawHandle(ctx: CGContext, fraction: Double, barY: CGFloat) {
        let x = bounds.width * fraction
        let handleRect = CGRect(x: x - handleWidth / 2, y: barY - 2, width: handleWidth, height: barHeight + 4)

        // Handle body
        ctx.setFillColor(NSColor.white.cgColor)
        let handlePath = CGPath(roundedRect: handleRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        ctx.addPath(handlePath)
        ctx.fillPath()

        // Handle border
        let borderColor = isSelected ? accentColor : NSColor(Color.cdBorder)
        ctx.setStrokeColor(borderColor.cgColor)
        ctx.setLineWidth(1.5)
        ctx.addPath(handlePath)
        ctx.strokePath()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let x = point.x / bounds.width

        let startX = startFraction
        let endX = endFraction

        if abs(x - startX) < 0.03 {
            dragging = .start
        } else if abs(x - endX) < 0.03 {
            dragging = .end
        } else {
            dragging = .none
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragging != .none else { return }
        let point = convert(event.locationInWindow, from: nil)
        let raw = max(0, min(1, point.x / bounds.width))

        // Snap to 10-minute marks
        let snapped = (raw / snapInterval).rounded() * snapInterval

        switch dragging {
        case .start:
            startFraction = snapped
        case .end:
            endFraction = snapped
        case .none:
            break
        }

        onRangeChanged?(startFraction, endFraction)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        dragging = .none
    }

    override func resetCursorRects() {
        let barY = (bounds.height - barHeight) / 2
        let startX = bounds.width * startFraction
        let endX = bounds.width * endFraction

        let startRect = CGRect(x: startX - handleWidth, y: barY - 4, width: handleWidth * 2, height: barHeight + 8)
        let endRect = CGRect(x: endX - handleWidth, y: barY - 4, width: handleWidth * 2, height: barHeight + 8)

        addCursorRect(startRect, cursor: .resizeLeftRight)
        addCursorRect(endRect, cursor: .resizeLeftRight)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/Views/RangeBarView.swift
git commit -m "feat: add RangeBarView — AppKit custom draggable range bar with snap-to-10min

NSViewRepresentable wrapping RangeBarNSView. Draws a 24h bar with
colored range fill and two draggable handles. Supports midnight
wrap-around. Handles snap to 10-minute marks."
```

---

### Task 8: ScheduleView — Per-Row Range Bars

**Files:**
- Create: `SpreadPaper/Views/ScheduleView.swift`

- [ ] **Step 1: Create the schedule view**

```swift
// SpreadPaper/Views/ScheduleView.swift

import SwiftUI

struct ScheduleView: View {
    @Binding var variants: [TimeVariant]
    @Binding var selectedIndex: Int
    let onAddImage: () -> Void
    let onRemoveVariant: (Int) -> Void

    /// Auto-generated day-phase names
    private let phaseNames = ["Sunrise", "Morning", "Noon", "Afternoon", "Late Afternoon", "Sunset", "Dusk", "Night",
                              "Late Night", "Pre-dawn", "Dawn", "Early Morning", "Mid-morning", "Early Afternoon", "Late Evening", "Midnight"]

    private var sortedIndices: [Int] {
        variants.indices.sorted { variants[$0].dayFraction < variants[$1].dayFraction }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Schedule · \(variants.count) images")

            VStack(spacing: 3) {
                ForEach(sortedIndices, id: \.self) { index in
                    scheduleRow(index: index)
                }
            }

            DashedAddButton(label: "+ Add Image", action: onAddImage)
        }
    }

    private func scheduleRow(index: Int) -> some View {
        let variant = variants[index]
        let isSelected = index == selectedIndex
        let nextVariant = nextVariantAfter(index: index)
        let duration = durationHours(from: variant, to: nextVariant)

        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                // Drag handle
                VStack(spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color.cdTextTertiary.opacity(0.3))
                            .frame(width: 8, height: 1.5)
                    }
                }
                .padding(.vertical, 2)

                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cdBgPrimary)
                    .frame(width: 28, height: 18)

                // Name
                Text(phaseNames[safe: index] ?? "Image \(index + 1)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.cdTextPrimary)

                Spacer()

                // Time range
                Text("\(variant.timeString) – \(nextVariant.timeString)")
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.cdAccent : Color.cdTextSecondary)

                // Duration
                Text("\(duration)h")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.cdTextTertiary)
                    .frame(width: 20, alignment: .trailing)
            }

            // Range bar
            RangeBarView(
                startFraction: Binding(
                    get: { variant.dayFraction },
                    set: { newVal in
                        let totalMinutes = Int(newVal * 24 * 60)
                        let snappedMinutes = (totalMinutes / 10) * 10
                        variants[index].hour = snappedMinutes / 60
                        variants[index].minute = snappedMinutes % 60
                    }
                ),
                endFraction: Binding(
                    get: { nextVariant.dayFraction },
                    set: { _ in } // End is derived from next variant
                ),
                isSelected: isSelected
            )
            .frame(height: 12)
            .padding(.leading, 18) // Align with content after drag handle
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Color.cdBgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.cdAccent : Color.cdBorder, lineWidth: isSelected ? 1.5 : 1)
        )
        .onTapGesture { selectedIndex = index }
        .contextMenu {
            Button("Remove", role: .destructive) { onRemoveVariant(index) }
        }
    }

    private func nextVariantAfter(index: Int) -> TimeVariant {
        let sorted = sortedIndices
        guard let pos = sorted.firstIndex(of: index) else { return variants[index] }
        let nextPos = (pos + 1) % sorted.count
        return variants[sorted[nextPos]]
    }

    private func durationHours(from: TimeVariant, to: TimeVariant) -> Int {
        var diff = to.dayFraction - from.dayFraction
        if diff <= 0 { diff += 1.0 }
        return max(1, Int((diff * 24).rounded()))
    }
}

// Safe array access
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/Views/ScheduleView.swift
git commit -m "feat: add ScheduleView — per-row range bars with drag handles and auto-names"
```

---

### Task 9: EditorView — Canvas + Right Panel (All Modes)

**Files:**
- Create: `SpreadPaper/Views/EditorCanvasView.swift`
- Create: `SpreadPaper/Views/MonitorPreviewView.swift`
- Create: `SpreadPaper/Views/EditorView.swift`

- [ ] **Step 1: Create EditorCanvasView (refactored from CanvasView)**

```swift
// SpreadPaper/Views/EditorCanvasView.swift

import SwiftUI
import UniformTypeIdentifiers

struct EditorCanvasView: View {
    let selectedImage: NSImage?
    @Binding var imageOffset: CGSize
    @Binding var imageScale: CGFloat
    @Binding var isFlipped: Bool
    let manager: WallpaperManager
    let onSelectImage: () -> Void
    let onDropImage: ([NSItemProvider]) -> Void

    @State private var dragStartOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let previewScale = calculatePreviewScale(geo: geo)
            let canvasWidth = manager.totalCanvas.width * previewScale
            let canvasHeight = manager.totalCanvas.height * previewScale

            ZStack {
                // Image layer
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
                        .highPriorityGesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    imageOffset = CGSize(
                                        width: dragStartOffset.width + value.translation.width,
                                        height: dragStartOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    dragStartOffset = imageOffset
                                }
                        )
                } else {
                    // Drop zone
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.cdTextTertiary)
                        Text("Drop image here")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cdTextSecondary)
                        Button("Browse Files", action: onSelectImage)
                            .buttonStyle(CoolDarkButtonStyle(isPrimary: true))
                    }
                }

                // Monitor outlines
                if selectedImage != nil {
                    MonitorPreviewView(
                        screens: manager.connectedScreens,
                        totalCanvas: manager.totalCanvas,
                        previewScale: previewScale,
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight
                    )
                }
            }
            .frame(width: canvasWidth, height: canvasHeight)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                onDropImage(providers)
                return true
            }
        }
        .background(Color.cdCanvasBg)
    }

    private func calculatePreviewScale(geo: GeometryProxy) -> CGFloat {
        let scaleX = geo.size.width / max(manager.totalCanvas.width, 1)
        let scaleY = geo.size.height / max(manager.totalCanvas.height, 1)
        return min(scaleX, scaleY) * 0.85
    }
}
```

- [ ] **Step 2: Create MonitorPreviewView**

```swift
// SpreadPaper/Views/MonitorPreviewView.swift

import SwiftUI

struct MonitorPreviewView: View {
    let screens: [DisplayInfo]
    let totalCanvas: CGRect
    let previewScale: CGFloat
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat

    var body: some View {
        ZStack {
            ForEach(screens) { display in
                let norm = normalize(frame: display.frame)
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)

                    Text(display.screen.localizedName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .frame(width: norm.width, height: norm.height)
                .position(x: norm.midX, y: norm.midY)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .allowsHitTesting(false)
    }

    private func normalize(frame: CGRect) -> CGRect {
        let x = (frame.origin.x - totalCanvas.origin.x) * previewScale
        let y = (totalCanvas.height - (frame.origin.y - totalCanvas.origin.y) - frame.height) * previewScale
        return CGRect(x: x, y: y, width: frame.width * previewScale, height: frame.height * previewScale)
    }
}
```

- [ ] **Step 3: Create EditorView — the main editor with right panel**

```swift
// SpreadPaper/Views/EditorView.swift

import SwiftUI

struct EditorView: View {
    @Bindable var manager: WallpaperManager
    @Bindable var navigation: AppNavigation
    let wallpaperType: WallpaperType
    let presetId: UUID?  // nil = new

    @State private var loadedImages: [NSImage] = []
    @State private var originalUrls: [URL] = []
    @State private var variants: [TimeVariant] = []
    @State private var selectedVariantIndex: Int = 0

    @State private var imageOffset: CGSize = .zero
    @State private var imageScale: CGFloat = 1.0
    @State private var isFlipped = false
    @State private var presetName = ""

    private var currentImage: NSImage? {
        guard !loadedImages.isEmpty, selectedVariantIndex < loadedImages.count else { return nil }
        return loadedImages[selectedVariantIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cdTextPrimary)
                Text("· \(wallpaperType.rawValue)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cdTextTertiary)

                Spacer()
                // Balance the back button width
                Color.clear.frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Color.cdBgSecondary)

            Divider().overlay(Color.cdBorder)

            // Main content
            HStack(spacing: 0) {
                // Canvas
                EditorCanvasView(
                    selectedImage: currentImage,
                    imageOffset: $imageOffset,
                    imageScale: $imageScale,
                    isFlipped: $isFlipped,
                    manager: manager,
                    onSelectImage: addImages,
                    onDropImage: { _ in }
                )

                // Right panel
                Divider().overlay(Color.cdBorder)
                rightPanel
            }
        }
        .background(Color.cdBgPrimary)
        .onChange(of: selectedVariantIndex) { _, _ in
            fitImage()
        }
        .onAppear {
            if let presetId, let preset = manager.presets.first(where: { $0.id == presetId }) {
                loadExistingPreset(preset)
            }
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
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

                    HStack(spacing: 6) {
                        Button("Fit") { fitImage() }
                            .buttonStyle(CoolDarkIconButtonStyle())
                            .frame(maxWidth: .infinity)

                        Button("Flip") { isFlipped.toggle() }
                            .buttonStyle(CoolDarkIconButtonStyle())
                            .frame(maxWidth: .infinity)
                    }
                }

                Divider().overlay(Color.cdBorder)

                // Mode-specific section
                switch wallpaperType {
                case .standard:
                    EmptyView() // No extra controls for static
                case .dynamic:
                    ScheduleView(
                        variants: $variants,
                        selectedIndex: $selectedVariantIndex,
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
        .frame(width: 220)
        .background(Color.cdBgSecondary)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider().overlay(Color.cdBorder)
                Button(action: applyWallpaper) {
                    HStack {
                        Spacer()
                        Text("Apply Wallpaper")
                        Spacer()
                    }
                }
                .buttonStyle(CoolDarkButtonStyle(isSuccess: true))
                .disabled(loadedImages.isEmpty)
                .padding(14)
            }
            .background(Color.cdBgSecondary)
        }
    }

    // MARK: - Appearance Section (Light/Dark)

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Appearance")

            HStack(spacing: 6) {
                // Light
                appearanceCard(label: "☀ Light", index: 0)
                // Dark
                appearanceCard(label: "🌙 Dark", index: 1)
            }

            if loadedImages.count < 2 {
                DashedAddButton(label: "+ Add \(loadedImages.isEmpty ? "Light" : "Dark") Image", action: addImages)
            }
        }
    }

    private func appearanceCard(label: String, index: Int) -> some View {
        Button(action: { if index < loadedImages.count { selectedVariantIndex = index } }) {
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
                hour = slot == 0 ? 12 : 0
                minute = 0
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
            selectedVariantIndex = 0
            fitImage()
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

        // Load the primary image
        let url = manager.getImageUrl(for: preset)
        if let img = NSImage(contentsOf: url) {
            loadedImages = [img]
            originalUrls = [url]
        }

        // Load dynamic variants
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

    private func applyWallpaper() {
        guard !loadedImages.isEmpty else { return }

        switch wallpaperType {
        case .standard:
            guard let image = loadedImages.first else { return }
            Task {
                await manager.setWallpaper(
                    originalImage: image,
                    imageOffset: imageOffset,
                    scale: imageScale,
                    previewScale: 1.0,
                    isFlipped: isFlipped
                )
            }
        case .dynamic:
            guard variants.count >= 2 else { return }
            let preset = SavedPreset(
                name: presetName.isEmpty ? "Untitled" : presetName,
                imageFilename: "",
                offsetX: imageOffset.width, offsetY: imageOffset.height,
                scale: imageScale, previewScale: 1.0, isFlipped: isFlipped,
                isDynamic: true, timeVariants: variants
            )
            Task {
                await manager.applyDynamicWallpaper(
                    preset: preset, images: loadedImages, previewScale: 1.0
                )
            }
        case .appearance:
            guard loadedImages.count == 2 else { return }
            Task {
                await manager.applyAppearanceWallpaper(
                    lightImage: loadedImages[0], darkImage: loadedImages[1],
                    offset: imageOffset, scale: imageScale, previewScale: 1.0, isFlipped: isFlipped
                )
            }
        }
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add SpreadPaper/Views/EditorCanvasView.swift SpreadPaper/Views/MonitorPreviewView.swift SpreadPaper/Views/EditorView.swift
git commit -m "feat: add EditorView with canvas, right panel, all three wallpaper modes

Canvas supports drag-to-position, scroll-to-zoom. Right panel has
position controls, mode-specific sections (schedule/appearance),
name field, and apply button. All custom Cool Dark styling."
```

---

### Task 10: WizardView — Welcome Flow

**Files:**
- Create: `SpreadPaper/Views/WizardView.swift`

- [ ] **Step 1: Create the wizard view**

```swift
// SpreadPaper/Views/WizardView.swift

import SwiftUI

struct WizardView: View {
    @Bindable var navigation: AppNavigation
    @State private var settings = AppSettings.shared
    @State private var step = 1
    @State private var displayCount = NSScreen.screens.count

    var body: some View {
        VStack(spacing: 0) {
            // Step indicators
            HStack(spacing: 6) {
                ForEach(1...2, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= step ? Color.cdAccent : Color.cdBorder)
                        .frame(width: 24, height: 4)
                }
            }
            .padding(.top, 24)

            Spacer()

            if step == 1 {
                welcomeStep
            } else {
                pickImageStep
            }

            Spacer()

            // Navigation buttons
            HStack {
                if step > 1 {
                    Button(action: { withAnimation { step -= 1 } }) {
                        Text("← Back")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cdTextTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if step == 1 {
                    Button("Get Started") {
                        withAnimation { step = 2 }
                    }
                    .buttonStyle(CoolDarkButtonStyle(isPrimary: true))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cdBgPrimary)
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            // Monitor illustration
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(colors: [Color.cdAccent, Color(hex: 0x5856D6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 80, height: 52)
                    .shadow(color: Color.cdAccentGlow, radius: 8)

                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(colors: [Color(hex: 0x5856D6), Color(hex: 0xAF52DE)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 80, height: 52)
                    .shadow(color: Color(hex: 0xAF52DE).opacity(0.2), radius: 8)
            }

            Text("Welcome to SpreadPaper")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.cdTextPrimary)

            Text("One wallpaper across all your monitors.\nPick an image, position it, and your desk comes alive.")
                .font(.system(size: 12))
                .foregroundStyle(Color.cdTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("\(displayCount) display\(displayCount == 1 ? "" : "s") detected")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.cdAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.cdBgElevated)
                .clipShape(Capsule())
        }
    }

    private var pickImageStep: some View {
        VStack(spacing: 12) {
            Text("Choose your first wallpaper")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.cdTextPrimary)

            Text("Drop an image or click to browse")
                .font(.system(size: 12))
                .foregroundStyle(Color.cdTextSecondary)

            // Drop zone
            Button(action: pickImage) {
                VStack(spacing: 10) {
                    LinearGradient(colors: [Color.cdAccent, Color(hex: 0x5856D6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white)
                        }

                    Text("Drag & drop an image here")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cdTextSecondary)

                    Text("or browse files")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cdAccent)
                }
                .frame(maxWidth: 300)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundStyle(Color.cdBorder)
                )
                .background(Color.cdBgElevated.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return }

        // Mark wizard complete and go to editor
        settings.hasCompletedWizard = true
        navigation.navigateToNewEditor(type: .standard)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/Views/WizardView.swift
git commit -m "feat: add WizardView — 2-step welcome flow with display detection"
```

---

### Task 11: App Entry Point — Wire Everything Together

**Files:**
- Modify: `SpreadPaper/App/SpreadPaperApp.swift`

- [ ] **Step 1: Rewrite SpreadPaperApp to use new navigation**

```swift
// SpreadPaper/App/SpreadPaperApp.swift

import SwiftUI

@main
struct SpreadPaperApp: App {
    @State private var manager = WallpaperManager()
    @State private var navigation = AppNavigation()
    @State private var settings = AppSettings.shared
    @State private var updateChecker = UpdateChecker.shared
    @State private var hasCheckedForUpdates = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                mainContent

                if navigation.showCreationModal {
                    CreationModal(navigation: navigation)
                }
            }
            .frame(minWidth: 900, minHeight: 600)
            .preferredColorScheme(.dark)
            .background(Color.cdBgPrimary)
            .task {
                await manager.listenForScreenChanges()
            }
            .task {
                await checkForUpdates()
            }
            .onAppear {
                // Force dark appearance on window
                if let window = NSApplication.shared.windows.first {
                    window.appearance = NSAppearance(named: .darkAqua)
                    window.backgroundColor = NSColor(Color.cdBgPrimary)
                }

                // Show wizard if first launch
                if !settings.hasCompletedWizard {
                    navigation.route = .wizard
                }
            }
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch navigation.route {
        case .wizard:
            WizardView(navigation: navigation)
        case .gallery:
            GalleryView(manager: manager, navigation: navigation)
        case .editor(let presetId):
            if let preset = manager.presets.first(where: { $0.id == presetId }) {
                let type: WallpaperType = {
                    switch preset.wallpaperType {
                    case "Dynamic": return .dynamic
                    case "Light/Dark": return .appearance
                    default: return .standard
                    }
                }()
                EditorView(manager: manager, navigation: navigation, wallpaperType: type, presetId: presetId)
            } else {
                GalleryView(manager: manager, navigation: navigation)
            }
        case .editorNew(let type):
            EditorView(manager: manager, navigation: navigation, wallpaperType: type, presetId: nil)
        }
    }

    private func checkForUpdates() async {
        guard !hasCheckedForUpdates else { return }
        hasCheckedForUpdates = true
        try? await Task.sleep(for: .seconds(2))
        await updateChecker.checkForUpdates()
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **` (old views still exist but aren't referenced)

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/App/SpreadPaperApp.swift
git commit -m "feat: rewire app entry point with Cool Dark navigation

Gallery-first routing. Wizard on first launch. Dark window appearance.
Hidden title bar. Creation modal as overlay. All views use new
Cool Dark styled components."
```

---

### Task 12: Remove Old Views

**Files:**
- Remove: All old view files listed in "Removed files" section

- [ ] **Step 1: Delete old view files**

```bash
rm SpreadPaper/Views/ContentView.swift
rm SpreadPaper/Views/SidebarView.swift
rm SpreadPaper/Views/DynamicEditorView.swift
rm SpreadPaper/Views/TimelineView.swift
rm SpreadPaper/Views/ImageDropZone.swift
rm SpreadPaper/Views/CanvasView.swift
rm SpreadPaper/Views/MonitorOverlayView.swift
rm SpreadPaper/Helpers/GlassModifiers.swift
rm SpreadPaper/Helpers/WindowDragHandler.swift
rm SpreadPaper/Helpers/WindowAccessor.swift
```

- [ ] **Step 2: Build and verify nothing is broken**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -10`
Expected: `** BUILD SUCCEEDED **`

If there are compile errors from missing types, fix references. The new views should not import anything from the old files.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove old SwiftUI views replaced by Cool Dark redesign

Removed: ContentView, SidebarView, DynamicEditorView, TimelineView,
ImageDropZone, CanvasView, MonitorOverlayView, GlassModifiers,
WindowDragHandler, WindowAccessor."
```

---

### Task 13: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the architecture section to reflect new file structure**

Update the Architecture section to list the new files, remove references to old files, and document the Cool Dark theme system and navigation model.

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for Cool Dark UI redesign"
```
