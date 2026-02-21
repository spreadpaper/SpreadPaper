import AppKit

@Observable
class WallpaperManager {
    var connectedScreens: [DisplayInfo] = []
    var totalCanvas: CGRect = .zero
    var presets: [SavedPreset] = []
    var lastError: String?

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
    func setWallpaper(originalImage: NSImage, imageOffset: CGSize, scale: CGFloat, previewScale: CGFloat, isFlipped: Bool) async {
        lastError = nil

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

        // Use screen's native color space for better wide-gamut display support
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
