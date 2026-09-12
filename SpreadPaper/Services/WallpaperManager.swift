import AppKit
import os

/// Technical failure details go here; `lastError` carries only plain, actionable copy for the UI.
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SpreadPaper", category: "wallpaper")

/// Owns display detection, preset persistence and wallpaper application for the whole app.
/// Renders off-main over Sendable specs, then sets each desktop image on main.
@Observable
class WallpaperManager {
    var connectedScreens: [DisplayInfo] = []
    /// Union of the display panels; the render canvas.
    var totalCanvas: CGRect = .zero
    /// Union of the panels plus their bezels; what the editor canvas shows.
    var previewBounds: CGRect = .zero
    var presets: [SavedPreset] = []
    var lastError: String?
    var activePresetId: UUID?
    /// True while an apply is in flight. Applies are serialized: a second call returns immediately,
    /// because overlapping renders would delete each other's freshly written files.
    private(set) var isApplying = false

    private let store: PresetStore
    private let activePresetKey = "activePresetId"

    /// Loads screens, presets and the active preset id; `store` defaults to the app support directory.
    init(store: PresetStore? = nil) {
        self.store = store ?? PresetStore(directory: Self.defaultDataDirectory())
        refreshScreens()
        loadPresets()
        if let raw = UserDefaults.standard.string(forKey: activePresetKey) {
            activePresetId = UUID(uuidString: raw)
        }
    }

    /// Records which preset is on the desktop and keeps that choice across launches.
    func setActivePreset(_ id: UUID?) {
        activePresetId = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: activePresetKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activePresetKey)
        }
    }

    /// Refreshes the display list on every screen-parameter change until the calling task is cancelled.
    func listenForScreenChanges() async {
        for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
            refreshScreens()
        }
    }

    // --- FILE SYSTEM ---
    /// App data root under Application Support; created lazily by `getAppDataDirectory`.
    private static func defaultDataDirectory() -> URL {
        URL.applicationSupportDirectory.appending(path: "SpreadPaper")
    }

    /// Store directory, created on first use so callers can write into it right away.
    private func getAppDataDirectory() -> URL {
        let dir = store.directory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Directory for rendered static PNGs, created on first use.
    private func getWallpapersDirectory() -> URL {
        let wallpapersDir = getAppDataDirectory().appending(path: "wallpapers", directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: wallpapersDir.path) {
            try? FileManager.default.createDirectory(at: wallpapersDir, withIntermediateDirectories: true)
        }
        return wallpapersDir
    }

    /// Parent of the per-preset dynamic HEIC folders, created on first use.
    func getDynamicDirectory() -> URL {
        let dynamicDir = getAppDataDirectory().appending(path: "dynamic", directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: dynamicDir.path) {
            try? FileManager.default.createDirectory(at: dynamicDir, withIntermediateDirectories: true)
        }
        return dynamicDir
    }

    /// Folder holding one dynamic preset's per-display HEIC files, created on first use.
    private func getDynamicPresetDirectory(presetId: UUID) -> URL {
        let dir = getDynamicDirectory().appending(path: presetId.uuidString, directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Removes wallpaper files named by screen name, which no current version writes. Called only after
    /// every connected display has a replacement set, so the active wallpaper is never deleted.
    private func removeLegacyFiles(in directory: URL, matching isLegacy: (String) -> Bool) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where isLegacy(file.lastPathComponent) {
            do {
                try FileManager.default.removeItem(at: file)
                logger.info("Removed legacy wallpaper file \(file.lastPathComponent, privacy: .public)")
            } catch {
                logger.error("Removing legacy file \(file.lastPathComponent, privacy: .public) failed: \(error, privacy: .public)")
            }
        }
    }

    /// Deletes earlier static renders for one display so reapplying does not bloat the disk.
    private func cleanupOldWallpapers(for displayID: CGDirectDisplayID, in directory: URL, except currentFilename: String) {
        let prefix = WallpaperFilenames.staticPrefix(displayID: displayID)
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files {
                let filename = file.lastPathComponent
                if filename.hasPrefix(prefix) && filename.hasSuffix(".png") && filename != currentFilename {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            // Best-effort; the next apply retries.
        }
    }

    /// Copies the image into the app data directory and appends a static preset with its placement.
    /// A failed copy surfaces as a plain error message instead of a half-saved preset.
    func savePreset(name: String, originalUrl: URL, offset: CGSize, scale: CGFloat, previewScale: CGFloat, isFlipped: Bool) {
        let destDir = getAppDataDirectory()
        let newFilename = FilenameUtils.storedName(uuid: UUID(), originalFilename: originalUrl.lastPathComponent)
        let destUrl = destDir.appending(path: newFilename)

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
            logger.error("Saving preset image failed: \(error, privacy: .public)")
            lastError = "The preset couldn't be saved."
        }
    }

    /// Copies every image into the app data directory and stores one time variant per image, sorted by start.
    /// The parallel arrays are indexed by image; a missing placement entry falls back to the default.
    func saveDynamicPreset(
        name: String,
        imageUrls: [URL],
        hours: [Int],
        minutes: [Int],
        offsets: [CGSize],
        scales: [CGFloat],
        previewScale: CGFloat,
        flipped: [Bool],
        isAppearanceBased: Bool = false
    ) {
        let presetId = UUID()
        let destDir = getAppDataDirectory()
        var variants: [TimeVariant] = []

        for (index, url) in imageUrls.enumerated() {
            let filename = FilenameUtils.storedName(uuid: UUID(), originalFilename: url.lastPathComponent)
            let destUrl = destDir.appending(path: filename)

            do {
                try FileManager.default.copyItem(at: url, to: destUrl)
                var variant = TimeVariant(
                    imageFilename: filename,
                    hour: hours[index],
                    minute: minutes[index]
                )
                if index < offsets.count {
                    variant.offsetX = offsets[index].width
                    variant.offsetY = offsets[index].height
                }
                if index < scales.count { variant.scale = scales[index] }
                variant.previewScale = previewScale
                if index < flipped.count { variant.isFlipped = flipped[index] }
                variants.append(variant)
            } catch {
                logger.error("Copying image \(index) for dynamic preset failed: \(error, privacy: .public)")
                lastError = "One of the preset images couldn't be saved."
            }
        }

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
            timeVariants: variants,
            isAppearanceBased: isAppearanceBased
        )

        presets.append(preset)
        persistPresets()
    }

    /// Removes a preset and the image in `imageFilename`; variant images stay on disk.
    /// Clears the active preset when it was the one applied.
    func deletePreset(_ preset: SavedPreset) {
        let fileUrl = getAppDataDirectory().appending(path: preset.imageFilename)
        try? FileManager.default.removeItem(at: fileUrl)
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets.remove(at: idx)
            persistPresets()
        }
        if activePresetId == preset.id {
            setActivePreset(nil)
        }
    }

    /// Location of a preset's stored image inside the app data directory.
    func getImageUrl(for preset: SavedPreset) -> URL {
        return getAppDataDirectory().appending(path: preset.imageFilename)
    }

    /// Lets views that edit `presets` in place, such as a rename, write the change to disk.
    func persistPresetsPublic() { persistPresets() }

    /// Writes the presets file, reporting a plain error message when the write fails.
    private func persistPresets() {
        _ = getAppDataDirectory()
        do {
            try store.save(presets)
        } catch {
            logger.error("Writing presets file failed: \(error, privacy: .public)")
            lastError = "Your presets couldn't be saved."
        }
    }

    /// Reads presets from disk, rewriting them once after a migration and recovering from a corrupt file.
    /// A corrupt file is quarantined and the user is told where the backup went.
    private func loadPresets() {
        do {
            guard let loaded = try store.load() else { return }
            presets = loaded.presets
            // Persist any flags inferred during migration so the heuristic only runs once.
            if loaded.needsMigrationRewrite {
                persistPresets()
            }
        } catch PresetStore.LoadError.corrupted(let backup, let underlying) {
            logger.error("Presets file corrupt, moved to \(backup.lastPathComponent, privacy: .public): \(underlying, privacy: .public)")
            presets = []
            lastError = "Your presets couldn't be loaded. A backup was saved as \(backup.lastPathComponent)."
        } catch {
            logger.error("Reading presets file failed: \(error, privacy: .public)")
            presets = []
            lastError = "Your presets couldn't be loaded."
        }
    }

    // --- SCREEN LOGIC ---
    /// Rebuilds the display list from NSScreen with bezel-spaced frames and recomputes both canvases.
    func refreshScreens() {
        let settings = AppSettings.shared
        let physical = NSScreen.screens.map { DisplayInfo(screen: $0) }
        let bezels = physical.map { settings.bezel(for: $0.displayID) }
        let frames = DisplayLayout.spacedFrames(physical.map(\.frame), bezels: bezels)
        self.connectedScreens = zip(physical, zip(frames, bezels)).map { info, layout in
            DisplayInfo(screen: info.screen, frame: layout.0, bezel: layout.1)
        }
        self.totalCanvas = frames.reduce(CGRect.null) { $0.union($1) }
        self.previewBounds = connectedScreens.reduce(CGRect.null) { $0.union($1.frameWithBezel) }
    }

    // --- RENDERING ---

    /// Everything a detached render task needs to know about one display. No AppKit objects;
    /// the output URL is precomputed so the closure calls nothing main-actor isolated.
    private struct RenderTarget: Sendable {
        let displayID: CGDirectDisplayID
        let frame: CGRect
        let deviceScale: CGFloat
        let colorSpace: CGColorSpace?
        let outputURL: URL
    }

    /// One rendered file per display, or the error that prevented it.
    private typealias RenderResults = [CGDirectDisplayID: Result<URL, any Error>]

    /// Snapshot of the connected displays. Geometry is captured before the await; a display
    /// change mid-render is corrected on the next apply.
    private func renderTargets(outputURL: (CGDirectDisplayID) -> URL) -> [RenderTarget] {
        connectedScreens.map { display in
            RenderTarget(
                displayID: display.displayID,
                frame: display.frame,
                deviceScale: display.screen.backingScaleFactor,
                colorSpace: display.screen.colorSpace?.cgColorSpace,
                outputURL: outputURL(display.displayID)
            )
        }
    }

    /// Marks an apply as started. Returns false when one is already running.
    private func beginApply() -> Bool {
        guard !isApplying else {
            logger.info("Apply ignored: another apply is still running")
            return false
        }
        isApplying = true
        lastError = nil
        return true
    }

    /// Pairs one display's geometry with one image placement for the renderer.
    private func spec(for target: RenderTarget, canvas: CGRect, offset: CGSize, scale: CGFloat, previewScale: CGFloat, isFlipped: Bool) -> RenderSpec {
        RenderSpec(
            screenFrame: target.frame,
            totalCanvas: canvas,
            offset: offset,
            imageScale: scale,
            previewScale: previewScale,
            isFlipped: isFlipped,
            deviceScale: target.deviceScale,
            colorSpace: target.colorSpace
        )
    }

    /// Cheap on a bitmap-backed image: returns the underlying rep's CGImage without drawing.
    private func cgImage(from image: NSImage) throws -> CGImage {
        var rect = CGRect(origin: .zero, size: image.pixelSize)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw WallpaperError.imageConversionFailed
        }
        return cg
    }

    /// Runs `work` off the main actor and returns its per-display results.
    private func renderOffMain(_ work: @escaping @Sendable () -> RenderResults) async -> RenderResults {
        await Task.detached(priority: .userInitiated) { work() }.value
    }

    /// Sets each rendered file as the desktop image on main and returns the displays whose
    /// wallpaper was actually set. A display that connected during the render has no
    /// result and is not counted as succeeded.
    private func applyRendered(
        _ results: RenderResults,
        options: [NSWorkspace.DesktopImageOptionKey: Any],
        failureCopy: (String) -> String
    ) -> Set<CGDirectDisplayID> {
        var succeeded: Set<CGDirectDisplayID> = []
        for display in connectedScreens {
            guard let result = results[display.displayID] else {
                logger.info("Display \(display.name, privacy: .public) connected during render, skipped")
                continue
            }
            do {
                let url = try result.get()
                try NSWorkspace.shared.setDesktopImageURL(url, for: display.screen, options: options)
                succeeded.insert(display.displayID)
            } catch {
                logger.error("Applying wallpaper to \(display.name, privacy: .public) failed: \(error, privacy: .public)")
                lastError = failureCopy(display.name)
            }
        }
        return succeeded
    }

    /// True when every currently connected display got its wallpaper set.
    private func allDisplaysSucceeded(_ succeeded: Set<CGDirectDisplayID>) -> Bool {
        succeeded.count == connectedScreens.count
    }

    /// Renders one static PNG per display off-main and sets each as that display's desktop image.
    /// Earlier renders are removed only for displays that now show the new file.
    func setWallpaper(originalImage: NSImage, imageOffset: CGSize, scale: CGFloat, previewScale: CGFloat, isFlipped: Bool) async {
        guard beginApply() else { return }
        defer { isApplying = false }
        let source: CGImage
        do {
            source = try cgImage(from: originalImage)
        } catch {
            logger.error("Converting source image failed: \(error, privacy: .public)")
            lastError = "The image couldn't be read."
            return
        }

        let canvas = totalCanvas
        let wallpapersDir = getWallpapersDirectory()
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let targets = renderTargets { id in
            wallpapersDir.appending(path: WallpaperFilenames.staticName(displayID: id, timestamp: timestamp))
        }
        let specs = targets.map { spec(for: $0, canvas: canvas, offset: imageOffset, scale: scale, previewScale: previewScale, isFlipped: isFlipped) }

        let results = await renderOffMain {
            var out: RenderResults = [:]
            for (target, spec) in zip(targets, specs) {
                out[target.displayID] = Result {
                    let rendered = try WallpaperRenderer.render(source, spec: spec)
                    let data = try WallpaperRenderer.pngData(rendered)
                    try data.write(to: target.outputURL, options: .atomic)
                    return target.outputURL
                }
            }
            return out
        }

        let succeeded = applyRendered(
            results,
            options: [.imageScaling: NSImageScaling.scaleAxesIndependently.rawValue],
            failureCopy: { "The wallpaper couldn't be set on \($0)." }
        )

        // Only displays whose new file is actually showing may lose their old one.
        for displayID in succeeded {
            if case .success(let url)? = results[displayID] {
                cleanupOldWallpapers(for: displayID, in: wallpapersDir, except: url.lastPathComponent)
            }
        }
        if allDisplaysSucceeded(succeeded) {
            removeLegacyFiles(in: wallpapersDir, matching: WallpaperFilenames.isLegacyStaticName)
        }
    }

    /// Renders every variant per display into a time-based HEIC and sets it as the desktop image.
    /// All displays share one schedule so they transition together.
    func applyDynamicWallpaper(
        preset: SavedPreset,
        images: [NSImage],
        previewScale: CGFloat
    ) async {
        guard beginApply() else { return }
        defer { isApplying = false }
        let sources: [CGImage]
        do {
            sources = try images.map(cgImage(from:))
        } catch {
            logger.error("Converting dynamic source images failed: \(error, privacy: .public)")
            lastError = "One of the images couldn't be read."
            return
        }

        let canvas = totalCanvas
        let presetDir = getDynamicPresetDirectory(presetId: preset.id)
        let targets = renderTargets { id in
            presetDir.appending(path: WallpaperFilenames.dynamicName(displayID: id))
        }
        let variants = preset.timeVariants.sorted { $0.dayFraction < $1.dayFraction }
        let hours = variants.map(\.hour)
        let minutes = variants.map(\.minute)

        // Per-variant placement, falling back to the preset's own for images beyond the variant list.
        let placements: [(offset: CGSize, scale: CGFloat, previewScale: CGFloat, isFlipped: Bool)] = images.indices.map { index in
            let variant = index < variants.count ? variants[index] : nil
            return (
                CGSize(width: variant?.offsetX ?? preset.offsetX, height: variant?.offsetY ?? preset.offsetY),
                variant?.scale ?? preset.scale,
                variant?.previewScale ?? previewScale,
                variant?.isFlipped ?? preset.isFlipped
            )
        }
        let specsPerTarget: [[RenderSpec]] = targets.map { target in
            placements.map { spec(for: target, canvas: canvas, offset: $0.offset, scale: $0.scale, previewScale: $0.previewScale, isFlipped: $0.isFlipped) }
        }

        let results = await renderOffMain {
            var out: RenderResults = [:]
            for (target, specs) in zip(targets, specsPerTarget) {
                out[target.displayID] = Result {
                    let rendered = try zip(sources, specs).map { try WallpaperRenderer.render($0, spec: $1) }
                    try DynamicWallpaperGenerator.generateTimeBasedHEIC(images: rendered, hours: hours, minutes: minutes, outputURL: target.outputURL)
                    return target.outputURL
                }
            }
            return out
        }

        let succeeded = applyRendered(results, options: [:], failureCopy: { "The dynamic wallpaper couldn't be set on \($0)." })
        if allDisplaysSucceeded(succeeded) {
            removeLegacyFiles(in: presetDir, matching: WallpaperFilenames.isLegacyDynamicName)
        }
    }

    /// Renders the light and dark images per display into an appearance HEIC and sets it as the desktop image.
    func applyAppearanceWallpaper(
        preset: SavedPreset,
        lightImage: NSImage,
        darkImage: NSImage,
        lightVariant: TimeVariant,
        darkVariant: TimeVariant
    ) async {
        guard beginApply() else { return }
        defer { isApplying = false }
        let light: CGImage
        let dark: CGImage
        do {
            light = try cgImage(from: lightImage)
            dark = try cgImage(from: darkImage)
        } catch {
            logger.error("Converting appearance source images failed: \(error, privacy: .public)")
            lastError = "One of the images couldn't be read."
            return
        }

        let canvas = totalCanvas
        let presetDir = getDynamicPresetDirectory(presetId: preset.id)
        let targets = renderTargets { id in
            presetDir.appending(path: WallpaperFilenames.dynamicName(displayID: id))
        }
        let lightSpecs = targets.map {
            spec(for: $0, canvas: canvas, offset: CGSize(width: lightVariant.offsetX, height: lightVariant.offsetY),
                 scale: lightVariant.scale, previewScale: lightVariant.previewScale, isFlipped: lightVariant.isFlipped)
        }
        let darkSpecs = targets.map {
            spec(for: $0, canvas: canvas, offset: CGSize(width: darkVariant.offsetX, height: darkVariant.offsetY),
                 scale: darkVariant.scale, previewScale: darkVariant.previewScale, isFlipped: darkVariant.isFlipped)
        }

        let results = await renderOffMain {
            var out: RenderResults = [:]
            for (index, target) in targets.enumerated() {
                out[target.displayID] = Result {
                    let renderedLight = try WallpaperRenderer.render(light, spec: lightSpecs[index])
                    let renderedDark = try WallpaperRenderer.render(dark, spec: darkSpecs[index])
                    try DynamicWallpaperGenerator.generateAppearanceHEIC(lightImage: renderedLight, darkImage: renderedDark, outputURL: target.outputURL)
                    return target.outputURL
                }
            }
            return out
        }

        let succeeded = applyRendered(results, options: [:], failureCopy: { "The wallpaper couldn't be set on \($0)." })
        if allDisplaysSucceeded(succeeded) {
            removeLegacyFiles(in: presetDir, matching: WallpaperFilenames.isLegacyDynamicName)
        }
    }
}

/// Failures raised while converting, rendering or encoding a wallpaper image.
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
