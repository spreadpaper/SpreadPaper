# Dynamic Desktop Editor — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add dynamic desktop wallpaper support to SpreadPaper — users load multiple time-of-day images, preview them with a time scrubber, and apply them as native macOS dynamic desktops that shift throughout the day across all monitors.

**Architecture:** New `DynamicWallpaperGenerator` service handles HEIC file creation with Apple's undocumented XMP metadata format (based on wallpapper's reverse engineering). The existing `WallpaperManager` rendering pipeline is reused to split each time variant per monitor. A new `TimelineView` below the canvas provides the time scrubber UI. The `SavedPreset` model is extended with optional dynamic fields (backward-compatible defaults).

**Tech Stack:** Swift 6, SwiftUI, ImageIO (CGImageDestination for HEIC), AVFoundation (AVFileType.heic), CGImageMetadata (XMP embedding)

**Design doc:** `~/.gstack/projects/spreadpaper-SpreadPaper/robin-main-design-20260408-150113.md`

---

## File Structure

### New files
- `SpreadPaper/Services/DynamicWallpaperGenerator.swift` — HEIC generation with solar/time metadata
- `SpreadPaper/Models/TimeVariant.swift` — Data model for time-of-day image variants
- `SpreadPaper/Views/TimelineView.swift` — Time scrubber + image thumbnail strip
- `SpreadPaper/Views/DynamicEditorView.swift` — Detail pane for dynamic presets (wraps canvas + timeline)

### Modified files
- `SpreadPaper/Models/SavedPreset.swift` — Add `isDynamic`, `timeVariants` fields
- `SpreadPaper/Services/WallpaperManager.swift` — Add `applyDynamicWallpaper()`, `saveDynamicPreset()`, directory helpers
- `SpreadPaper/Views/SidebarView.swift` — "New Dynamic Setup" button, dynamic preset badge
- `SpreadPaper/Views/ContentView.swift` — Route to DynamicEditorView when dynamic preset selected
- `SpreadPaper/SpreadPaper.entitlements` — Add `files.user-selected.read-write`

---

### Task 1: GO/NO-GO Spike — HEIC Dynamic Desktop Generation

This is the critical gate. If macOS doesn't honor our generated HEIC files as dynamic desktops, we stop and investigate alternatives.

**Files:**
- Create: `SpreadPaper/Services/DynamicWallpaperGenerator.swift`

- [ ] **Step 1: Create the metadata models**

These mirror the wallpapper project's format (MIT licensed, credit Marcin Czachurski). The metadata is a binary plist encoded as base64, embedded as XMP in the first HEIC image.

```swift
// SpreadPaper/Services/DynamicWallpaperGenerator.swift

import Foundation
import ImageIO
import AVFoundation
import AppKit

// MARK: - Metadata Models
// Based on the HEIC dynamic desktop format reverse-engineered by
// wallpapper (https://github.com/mczachurski/wallpapper) by Marcin Czachurski.
// Licensed under MIT.

/// Solar-based sequence item: sun altitude + azimuth at each image index
struct SolarItem: Codable {
    enum CodingKeys: String, CodingKey {
        case altitude = "a"
        case azimuth = "z"
        case imageIndex = "i"
    }
    var altitude: Double
    var azimuth: Double
    var imageIndex: Int
}

/// Time-based item: fraction of day (0.0–1.0) at each image index
struct TimeBasedItem: Codable {
    enum CodingKeys: String, CodingKey {
        case time = "t"
        case imageIndex = "i"
    }
    /// Fraction of day: hour/24 + minute/1440
    var time: Double
    var imageIndex: Int
}

/// Light/dark appearance indices
struct AppearanceInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case darkIndex = "d"
        case lightIndex = "l"
    }
    var darkIndex: Int
    var lightIndex: Int
}

/// Root metadata container. Only one of solarItems/timeItems should be set.
struct DynamicMetadata: Codable {
    enum CodingKeys: String, CodingKey {
        case solarItems = "si"
        case timeItems = "ti"
        case appearance = "ap"
    }
    var solarItems: [SolarItem]?
    var timeItems: [TimeBasedItem]?
    var appearance: AppearanceInfo?
}
```

- [ ] **Step 2: Create the HEIC generation function**

```swift
// Continue in DynamicWallpaperGenerator.swift

enum DynamicWallpaperError: LocalizedError {
    case noImages
    case imageLoadFailed(String)
    case cgImageConversionFailed
    case destinationCreationFailed
    case metadataCreationFailed
    case finalizationFailed
    case fileWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .noImages: return "No images provided"
        case .imageLoadFailed(let path): return "Failed to load image: \(path)"
        case .cgImageConversionFailed: return "Failed to convert image to CGImage"
        case .destinationCreationFailed: return "Failed to create HEIC destination"
        case .metadataCreationFailed: return "Failed to create image metadata"
        case .finalizationFailed: return "Failed to finalize HEIC file"
        case .fileWriteFailed(let path): return "Failed to write file: \(path)"
        }
    }
}

struct DynamicWallpaperGenerator {

    /// Generate a dynamic desktop HEIC file from a list of CGImages with time metadata.
    /// - Parameters:
    ///   - images: Ordered array of CGImages (one per time-of-day variant)
    ///   - hours: Matching array of hours (0-23) for each image
    ///   - minutes: Matching array of minutes (0-59) for each image
    ///   - outputURL: Where to write the .heic file
    static func generateTimeBasedHEIC(
        images: [CGImage],
        hours: [Int],
        minutes: [Int],
        outputURL: URL
    ) throws {
        guard !images.isEmpty else { throw DynamicWallpaperError.noImages }

        // Build time metadata
        let timeItems = images.indices.map { i in
            TimeBasedItem(
                time: Double(hours[i]) / 24.0 + Double(minutes[i]) / 1440.0,
                imageIndex: i
            )
        }

        // Find closest to noon for light, closest to midnight for dark
        let lightIndex = timeItems.enumerated().min(by: {
            abs($0.element.time - 0.5) < abs($1.element.time - 0.5)
        })?.offset ?? 0
        let darkIndex = timeItems.enumerated().min(by: {
            min($0.element.time, 1.0 - $0.element.time) < min($1.element.time, 1.0 - $1.element.time)
        })?.offset ?? 0

        let metadata = DynamicMetadata(
            solarItems: nil,
            timeItems: timeItems,
            appearance: AppearanceInfo(darkIndex: darkIndex, lightIndex: lightIndex)
        )

        try writeHEIC(images: images, metadata: metadata, metadataKey: "h24", outputURL: outputURL)
    }

    /// Core HEIC writing logic shared between solar and time modes.
    private static func writeHEIC(
        images: [CGImage],
        metadata: some Codable,
        metadataKey: String,
        outputURL: URL
    ) throws {
        // Encode metadata as base64 binary plist
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let plistData = try encoder.encode(metadata)
        let base64String = plistData.base64EncodedString()

        // Create XMP metadata with apple_desktop namespace
        let imageMetadata = CGImageMetadataCreateMutable()
        guard CGImageMetadataRegisterNamespaceForPrefix(
            imageMetadata,
            "http://ns.apple.com/namespace/1.0/" as CFString,
            "apple_desktop" as CFString,
            nil
        ) else {
            throw DynamicWallpaperError.metadataCreationFailed
        }

        guard let tag = CGImageMetadataTagCreate(
            "http://ns.apple.com/namespace/1.0/" as CFString,
            "apple_desktop" as CFString,
            metadataKey as CFString,
            .string,
            base64String as CFTypeRef
        ) else {
            throw DynamicWallpaperError.metadataCreationFailed
        }

        guard CGImageMetadataSetTagWithPath(
            imageMetadata, nil,
            "apple_desktop:\(metadataKey)" as CFString,
            tag
        ) else {
            throw DynamicWallpaperError.metadataCreationFailed
        }

        // Write HEIC with all images
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            AVFileType.heic as CFString,
            images.count,
            nil
        ) else {
            throw DynamicWallpaperError.destinationCreationFailed
        }

        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]

        for (index, image) in images.enumerated() {
            if index == 0 {
                // First image carries the XMP metadata
                CGImageDestinationAddImageAndMetadata(destination, image, imageMetadata, options as CFDictionary)
            } else {
                CGImageDestinationAddImage(destination, image, options as CFDictionary)
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw DynamicWallpaperError.finalizationFailed
        }

        try (destinationData as Data).write(to: outputURL)
    }
}
```

- [ ] **Step 3: Build and verify it compiles**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Add a temporary test button to verify the spike**

Add a menu item or button that generates a test dynamic desktop from 2-3 solid-color images and applies it. This is throwaway code to validate the core assumption.

In `ContentView.swift`, add a temporary toolbar button inside the `editorToolbar`:

```swift
// Add this at the end of ToolbarItemGroup, before the closing brace
Button("Test Dynamic") {
    Task {
        await testDynamicWallpaper()
    }
}
```

Add this function to `ContentView.swift`:

```swift
private func testDynamicWallpaper() async {
    // Generate 3 solid-color test images: blue (night), orange (morning), cyan (midday)
    let colors: [(CGFloat, CGFloat, CGFloat)] = [
        (0.1, 0.1, 0.4),  // Night: dark blue
        (1.0, 0.6, 0.2),  // Morning: orange
        (0.4, 0.8, 1.0),  // Midday: light blue
    ]
    let hours = [0, 8, 12]
    let minutes = [0, 0, 0]

    var testImages: [CGImage] = []
    for (r, g, b) in colors {
        let size = 256
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { continue }
        ctx.setFillColor(red: r, green: g, blue: b, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        if let img = ctx.makeImage() {
            testImages.append(img)
        }
    }

    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = appSupport.appendingPathComponent("SpreadPaper/dynamic_test")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let outputURL = dir.appendingPathComponent("test_dynamic.heic")

    do {
        try DynamicWallpaperGenerator.generateTimeBasedHEIC(
            images: testImages,
            hours: hours,
            minutes: minutes,
            outputURL: outputURL
        )
        print("Dynamic HEIC written to: \(outputURL.path)")

        // Apply to the first screen
        if let screen = NSScreen.main {
            try NSWorkspace.shared.setDesktopImageURL(outputURL, for: screen, options: [:])
            print("Applied dynamic wallpaper to main screen")
        }
    } catch {
        print("Spike FAILED: \(error)")
    }
}
```

- [ ] **Step 5: Build, run, and verify the spike**

Run the app, click "Test Dynamic", then verify:
1. The wallpaper changes to one of the test colors
2. Open System Settings > Wallpaper — does it show as "Dynamic Desktop"?
3. Reboot — does the wallpaper persist?
4. Wait or change system time — do the colors shift?

**If this fails:** STOP. Do not proceed to Task 2. Investigate alternatives:
- Try placing the HEIC in `~/Library/Desktop Pictures/` instead
- Try using `osascript` to set the wallpaper
- Try setting via the `com.apple.desktop` preference domain

**If this succeeds:** Remove the test button code and the test directory. Commit the DynamicWallpaperGenerator.

- [ ] **Step 6: Clean up and commit**

Remove the `testDynamicWallpaper()` function and "Test Dynamic" button from ContentView.swift.
Remove the `dynamic_test` directory: `rm -rf ~/Library/Application\ Support/SpreadPaper/dynamic_test`

```bash
git add SpreadPaper/Services/DynamicWallpaperGenerator.swift
git commit -m "feat: add DynamicWallpaperGenerator for HEIC dynamic desktop creation

Based on the metadata format reverse-engineered by wallpapper
(https://github.com/mczachurski/wallpapper) by Marcin Czachurski (MIT).
Supports time-based (h24) mode with CGImageDestination + XMP metadata."
```

---

### Task 2: Extend Data Model

**Files:**
- Create: `SpreadPaper/Models/TimeVariant.swift`
- Modify: `SpreadPaper/Models/SavedPreset.swift`

- [ ] **Step 1: Create TimeVariant model**

```swift
// SpreadPaper/Models/TimeVariant.swift

import Foundation

struct TimeVariant: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Filename of the stored image (UUID-based, in app support dir)
    var imageFilename: String
    /// Hour of day (0-23)
    var hour: Int
    /// Minute (0-59)
    var minute: Int

    /// Fraction of day (0.0–1.0) for sorting and display
    var dayFraction: Double {
        Double(hour) / 24.0 + Double(minute) / 1440.0
    }

    /// Display string like "8:00 AM"
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 2: Extend SavedPreset with dynamic fields**

All new fields have defaults so existing presets decode without migration.

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

    // Dynamic desktop support
    var isDynamic: Bool = false
    var timeVariants: [TimeVariant] = []
}
```

- [ ] **Step 3: Build to verify backward compatibility**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

Also run the app and verify existing presets still load from `spreadpaper_presets.json`.

- [ ] **Step 4: Commit**

```bash
git add SpreadPaper/Models/TimeVariant.swift SpreadPaper/Models/SavedPreset.swift
git commit -m "feat: add TimeVariant model and extend SavedPreset for dynamic desktops

New fields have defaults so existing preset JSON files decode without
migration. TimeVariant stores hour/minute per image for time-based mode."
```

---

### Task 3: WallpaperManager — Dynamic Preset Support

**Files:**
- Modify: `SpreadPaper/Services/WallpaperManager.swift`

- [ ] **Step 1: Add directory helpers for dynamic wallpapers**

Add these methods to WallpaperManager:

```swift
// In WallpaperManager, after getWallpapersDirectory()

func getDynamicDirectory() -> URL {
    let dynamicDir = getAppDataDirectory().appendingPathComponent("dynamic")
    if !FileManager.default.fileExists(atPath: dynamicDir.path) {
        try? FileManager.default.createDirectory(at: dynamicDir, withIntermediateDirectories: true)
    }
    return dynamicDir
}

private func getDynamicPresetDirectory(presetId: UUID) -> URL {
    let dir = getDynamicDirectory().appendingPathComponent(presetId.uuidString)
    if !FileManager.default.fileExists(atPath: dir.path) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
}
```

- [ ] **Step 2: Add saveDynamicPreset()**

```swift
// In WallpaperManager

func saveDynamicPreset(
    name: String,
    imageUrls: [URL],
    hours: [Int],
    minutes: [Int],
    offsets: [CGSize],
    scales: [CGFloat],
    previewScale: CGFloat,
    flipped: [Bool]
) {
    let presetId = UUID()
    let destDir = getAppDataDirectory()
    var variants: [TimeVariant] = []

    for (index, url) in imageUrls.enumerated() {
        let ext = url.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let destUrl = destDir.appendingPathComponent(filename)

        do {
            try FileManager.default.copyItem(at: url, to: destUrl)
            let variant = TimeVariant(
                imageFilename: filename,
                hour: hours[index],
                minute: minutes[index]
            )
            variants.append(variant)
        } catch {
            print("Error copying image for dynamic preset: \(error)")
        }
    }

    // Sort variants by time
    variants.sort { $0.dayFraction < $1.dayFraction }

    let preset = SavedPreset(
        id: presetId,
        name: name,
        imageFilename: variants.first?.imageFilename ?? "",
        offsetX: offsets.first?.width ?? 0,
        offsetY: offsets.first?.height ?? 0,
        scale: scales.first ?? 1.0,
        previewScale: previewScale,
        isFlipped: flipped.first ?? false,
        isDynamic: true,
        timeVariants: variants
    )

    presets.append(preset)
    persistPresets()
}
```

- [ ] **Step 3: Add applyDynamicWallpaper()**

This is the core function: for each time variant, render it per-monitor using the existing pipeline, then assemble per-monitor HEIC files.

```swift
// In WallpaperManager

func applyDynamicWallpaper(
    preset: SavedPreset,
    images: [NSImage],
    previewScale: CGFloat
) async {
    lastError = nil

    let displays = connectedScreens.map { display in
        (screen: display.screen,
         frame: display.frame,
         scaleFactor: display.screen.backingScaleFactor,
         colorSpace: display.screen.colorSpace?.cgColorSpace,
         name: display.screen.localizedName)
    }

    let presetDir = getDynamicPresetDirectory(presetId: preset.id)
    let variants = preset.timeVariants.sorted { $0.dayFraction < $1.dayFraction }
    let hours = variants.map(\.hour)
    let minutes = variants.map(\.minute)

    for display in displays {
        do {
            // Render each time variant for this specific monitor
            var renderedImages: [CGImage] = []
            for image in images {
                let rendered = try renderForScreen(
                    original: image,
                    screenFrame: display.frame,
                    totalCanvas: totalCanvas,
                    offset: CGSize(width: preset.offsetX, height: preset.offsetY),
                    imageScale: preset.scale,
                    previewScale: previewScale,
                    isFlipped: preset.isFlipped,
                    deviceScale: display.scaleFactor,
                    screenColorSpace: display.colorSpace
                )
                renderedImages.append(rendered)
            }

            // Generate HEIC for this monitor
            let sanitizedName = sanitizeScreenName(display.name)
            let heicURL = presetDir.appendingPathComponent("\(sanitizedName).heic")

            try DynamicWallpaperGenerator.generateTimeBasedHEIC(
                images: renderedImages,
                hours: hours,
                minutes: minutes,
                outputURL: heicURL
            )

            // Apply the dynamic wallpaper
            try NSWorkspace.shared.setDesktopImageURL(heicURL, for: display.screen, options: [:])
        } catch {
            lastError = "Failed to set dynamic wallpaper for \(display.name): \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add SpreadPaper/Services/WallpaperManager.swift
git commit -m "feat: add dynamic wallpaper save and apply to WallpaperManager

Renders each time variant per-monitor using existing pipeline, assembles
per-monitor HEIC files with synchronized time metadata, applies via
NSWorkspace."
```

---

### Task 4: Time Scrubber UI — TimelineView

**Files:**
- Create: `SpreadPaper/Views/TimelineView.swift`

- [ ] **Step 1: Create TimelineView**

The timeline has three parts: a time-of-day slider, thumbnail strip of loaded images, and add/remove controls.

```swift
// SpreadPaper/Views/TimelineView.swift

import SwiftUI

struct TimelineView: View {
    @Binding var variants: [TimeVariant]
    @Binding var selectedVariantIndex: Int
    @Binding var scrubberTime: Double  // 0.0–24.0 (hours)

    let thumbnails: [NSImage]  // Downsampled thumbnails matching variants order
    let onAddImages: () -> Void
    let onRemoveVariant: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Time Variants (\(variants.count) of 16 max)")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(timeLabel(for: scrubberTime))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Time scrubber
                VStack(spacing: 4) {
                    Slider(value: $scrubberTime, in: 0...24, step: 0.25)
                        .onChange(of: scrubberTime) { _, newValue in
                            // Snap to closest variant for preview
                            if let closest = variants.enumerated().min(by: {
                                abs(Double($0.element.hour) + Double($0.element.minute) / 60.0 - newValue) <
                                abs(Double($1.element.hour) + Double($1.element.minute) / 60.0 - newValue)
                            }) {
                                selectedVariantIndex = closest.offset
                            }
                        }

                    // Time markers
                    HStack {
                        Text("12 AM").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Spacer()
                        Text("6 AM").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Spacer()
                        Text("12 PM").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Spacer()
                        Text("6 PM").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Spacer()
                        Text("12 AM").font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                }

                // Thumbnail strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(zip(variants.indices, variants)), id: \.1.id) { index, variant in
                            VStack(spacing: 4) {
                                if index < thumbnails.count {
                                    Image(nsImage: thumbnails[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 72, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(index == selectedVariantIndex ? Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                }
                                Text(variant.timeString)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            .onTapGesture {
                                selectedVariantIndex = index
                                scrubberTime = Double(variant.hour) + Double(variant.minute) / 60.0
                            }
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    onRemoveVariant(index)
                                }
                            }
                        }

                        // Add button
                        if variants.count < 16 {
                            Button(action: onAddImages) {
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 72, height: 44)
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    private func timeLabel(for hours: Double) -> String {
        let h = Int(hours) % 24
        let m = Int((hours.truncatingRemainder(dividingBy: 1)) * 60)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = h
        components.minute = m
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/Views/TimelineView.swift
git commit -m "feat: add TimelineView with time scrubber and thumbnail strip

Time slider (0-24h) snaps to closest variant for canvas preview.
Thumbnail strip shows loaded images with time labels. Add/remove
controls with 16-image max."
```

---

### Task 5: Dynamic Editor View

**Files:**
- Create: `SpreadPaper/Views/DynamicEditorView.swift`

- [ ] **Step 1: Create DynamicEditorView**

This view wraps the existing CanvasView with the TimelineView below it, managing the multi-image state.

```swift
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

            // Default time: spread evenly across remaining slots
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

        // Auto-fit first image if this is the first load
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
                            let defaultHour = variants.count * 3  // Space 3h apart
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
        // Create a temporary preset for applying
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
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/Views/DynamicEditorView.swift
git commit -m "feat: add DynamicEditorView with canvas + timeline integration

Wraps existing CanvasView with TimelineView below. Manages multi-image
loading, thumbnail generation, time assignment, and dynamic wallpaper
application."
```

---

### Task 6: Wire Up Sidebar + ContentView

**Files:**
- Modify: `SpreadPaper/Views/SidebarView.swift`
- Modify: `SpreadPaper/Views/ContentView.swift`

- [ ] **Step 1: Add "New Dynamic Setup" to sidebar and badge dynamic presets**

```swift
// SpreadPaper/Views/SidebarView.swift — replace entire file

import SwiftUI

struct SidebarView: View {
    @Binding var selectedPresetID: SavedPreset.ID?
    let presets: [SavedPreset]
    let onNewSetup: () -> Void
    let onNewDynamicSetup: () -> Void
    let onDelete: (SavedPreset) -> Void

    var body: some View {
        List(selection: $selectedPresetID) {
            Section(header: Text("Saved Layouts")) {
                Button(action: onNewSetup) {
                    Label("New Setup", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.blue)

                Button(action: onNewDynamicSetup) {
                    Label("New Dynamic Setup", systemImage: "sun.max")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.orange)

                ForEach(presets) { preset in
                    HStack {
                        Label(preset.name, systemImage: preset.isDynamic ? "sun.max" : "photo")
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if preset.isDynamic {
                            Text("Dynamic")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    .tag(preset.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            onDelete(preset)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet { onDelete(presets[index]) }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    }
}
```

- [ ] **Step 2: Update ContentView to route to DynamicEditorView**

Add the dynamic editing mode and wire up the new sidebar callback.

In `ContentView.swift`, add a state variable:

```swift
@State private var isDynamicMode = false
```

Update the `NavigationSplitView` sidebar to pass the new callback:

```swift
SidebarView(
    selectedPresetID: $selectedPresetID,
    presets: manager.presets,
    onNewSetup: {
        isDynamicMode = false
        resetEditor()
    },
    onNewDynamicSetup: {
        isDynamicMode = true
        resetEditor()
    },
    onDelete: { preset in
        manager.deletePreset(preset)
        if selectedPresetID == preset.id { resetEditor() }
    }
)
```

Update the detail pane to switch between static and dynamic editors:

```swift
} detail: {
    if isDynamicMode {
        DynamicEditorView(manager: manager)
    } else {
        detailContent
    }
}
```

Update `loadPreset` to set the dynamic mode:

```swift
private func loadPreset(_ preset: SavedPreset) {
    isDynamicMode = preset.isDynamic
    guard !preset.isDynamic else { return }  // Dynamic presets handled by DynamicEditorView
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
```

- [ ] **Step 3: Build, run, and manually test**

Run the app and verify:
1. Sidebar shows both "New Setup" and "New Dynamic Setup" buttons
2. Clicking "New Dynamic Setup" shows the DynamicEditorView (empty canvas with drop zone)
3. Clicking "New Setup" goes back to the static editor
4. Existing presets still load correctly

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add SpreadPaper/Views/SidebarView.swift SpreadPaper/Views/ContentView.swift
git commit -m "feat: wire sidebar and content view for dynamic preset routing

New Dynamic Setup button in sidebar switches to DynamicEditorView.
Dynamic presets show sun icon and orange badge. Existing static
presets continue to work unchanged."
```

---

### Task 7: Update Entitlements

**Files:**
- Modify: `SpreadPaper/SpreadPaper.entitlements`

- [ ] **Step 1: Add read-write file access for pack export**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-write</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
</dict>
</plist>
```

Note: `read-write` replaces `read-only` — it's a superset, so existing file-open functionality is preserved.

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SpreadPaper/SpreadPaper.entitlements
git commit -m "feat: upgrade file access entitlement to read-write

Needed for dynamic wallpaper HEIC export and future pack file saving.
Replaces read-only (read-write is a superset)."
```

---

### Task 8: End-to-End Integration Test

No new files. This task verifies the full flow works.

- [ ] **Step 1: Build and launch the app**

Run: `xcodebuild -scheme SpreadPaper -configuration Debug build 2>&1 | tail -5`
Then run the app from Xcode (Cmd+R).

- [ ] **Step 2: Test the full dynamic wallpaper flow**

1. Click "New Dynamic Setup" in the sidebar
2. Click "Add Images" — select 3-4 panoramic images (different times of day, or same image is fine for testing)
3. Verify thumbnails appear in the timeline strip
4. Drag the time scrubber — the canvas should update to show different images
5. Click "Fit" to auto-fit the current image
6. Click "Apply Dynamic Wallpaper"
7. Check: wallpaper changes on all monitors
8. Open System Settings > Wallpaper — verify it shows as a dynamic wallpaper
9. Switch back to "New Setup" — verify static editor still works
10. Load an existing preset — verify it still works

- [ ] **Step 3: Verify persistence**

1. Close and reopen the app
2. Check that static presets still load
3. Reboot (if testing the spike) to confirm dynamic wallpaper persists

- [ ] **Step 4: Update CLAUDE.md architecture section**

Update the Architecture section in CLAUDE.md to reflect the new files:

Add under the existing bullet list:
```
- **DynamicWallpaperGenerator.swift** — HEIC dynamic desktop file generation with Apple XMP metadata
- **TimeVariant.swift** — Data model for time-of-day image variants
- **TimelineView.swift** — Time scrubber slider and image thumbnail strip
- **DynamicEditorView.swift** — Detail pane for dynamic presets (wraps CanvasView + TimelineView)
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md architecture for dynamic desktop feature"
```
