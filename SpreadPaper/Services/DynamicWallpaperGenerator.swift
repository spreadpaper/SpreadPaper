import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

// MARK: - Metadata Models
// Based on the metadata format reverse-engineered by wallpapper
// (https://github.com/mczachurski/wallpapper) by Marcin Czachurski (MIT).

/// One sun-position keyframe in Apple's desktop plist, selecting the frame to show.
nonisolated struct SolarItem: Codable {
    /// Single-letter keys as Apple writes them.
    enum CodingKeys: String, CodingKey {
        case altitude = "a"
        case azimuth = "z"
        case imageIndex = "i"
    }
    var altitude: Double
    var azimuth: Double
    var imageIndex: Int
}

/// One time-of-day keyframe: a day fraction and the frame it switches to.
nonisolated struct TimeBasedItem: Codable {
    /// Single-letter keys as Apple writes them.
    enum CodingKeys: String, CodingKey {
        case time = "t"
        case imageIndex = "i"
    }
    var time: Double
    var imageIndex: Int
}

/// Which frames stand in for light and dark mode.
nonisolated struct AppearanceInfo: Codable {
    /// Single-letter keys as Apple writes them.
    enum CodingKeys: String, CodingKey {
        case darkIndex = "d"
        case lightIndex = "l"
    }
    var darkIndex: Int
    var lightIndex: Int
}

/// Root of the h24 desktop plist: time keyframes plus the light and dark fallbacks.
/// Solar items stay nil.
nonisolated struct DynamicMetadata: Codable {
    /// Two-letter keys as Apple writes them.
    enum CodingKeys: String, CodingKey {
        case solarItems = "si"
        case timeItems = "ti"
        case appearance = "ap"
    }
    var solarItems: [SolarItem]?
    var timeItems: [TimeBasedItem]?
    var appearance: AppearanceInfo?
}

// MARK: - Errors

/// Failures raised while building or writing a dynamic desktop HEIC.
enum DynamicWallpaperError: Error, LocalizedError, Equatable {
    case noImages
    case countMismatch
    case destinationCreationFailed
    case metadataCreationFailed
    case finalizationFailed
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .noImages:                   return "No images provided."
        case .countMismatch:              return "Hours and minutes must have one entry per image."
        case .destinationCreationFailed:  return "Failed to create CGImageDestination."
        case .metadataCreationFailed:     return "Failed to create image metadata."
        case .finalizationFailed:         return "Failed to finalize the HEIC file."
        case .fileWriteFailed:            return "Failed to write the HEIC file to disk."
        }
    }
}

// MARK: - Generator

/// Pure HEIC writing over `CGImage`s. Safe to call off the main actor.
enum DynamicWallpaperGenerator {

    /// Create a time-based (h24) dynamic desktop HEIC file.
    nonisolated static func generateTimeBasedHEIC(
        images: [CGImage],
        hours: [Int],
        minutes: [Int],
        outputURL: URL
    ) throws {
        guard !images.isEmpty else { throw DynamicWallpaperError.noImages }
        guard hours.count == images.count, minutes.count == images.count else {
            throw DynamicWallpaperError.countMismatch
        }

        let timeItems: [TimeBasedItem] = images.indices.map { idx in
            let fraction = Double(hours[idx]) / 24.0 + Double(minutes[idx]) / 1440.0
            return TimeBasedItem(time: fraction, imageIndex: idx)
        }

        let noonFraction = 12.0 / 24.0
        guard
            let lightIndex = timeItems
                .min(by: { abs($0.time - noonFraction) < abs($1.time - noonFraction) })?
                .imageIndex,
            let darkIndex = timeItems
                .min(by: { min($0.time, 1.0 - $0.time) < min($1.time, 1.0 - $1.time) })?
                .imageIndex
        else {
            throw DynamicWallpaperError.noImages
        }

        let metadata = DynamicMetadata(
            solarItems: nil,
            timeItems: timeItems,
            appearance: AppearanceInfo(darkIndex: darkIndex, lightIndex: lightIndex)
        )

        try writeHEIC(images: images, metadata: metadata, key: "h24", outputURL: outputURL)
    }

    /// Create an appearance-based (apr) dynamic desktop HEIC file.
    /// Two images: one for light mode, one for dark mode.
    nonisolated static func generateAppearanceHEIC(
        lightImage: CGImage,
        darkImage: CGImage,
        outputURL: URL
    ) throws {
        let appearance = AppearanceInfo(darkIndex: 1, lightIndex: 0)
        try writeHEIC(images: [lightImage, darkImage], metadata: appearance, key: "apr", outputURL: outputURL)
    }

    // MARK: - Shared HEIC writing

    /// Lossy compression quality applied to every frame in a dynamic HEIC.
    nonisolated private static let compressionQuality: CGFloat = 0.9

    /// Encodes `images` into a HEIC at `outputURL`, tagging the first frame with
    /// `metadata` as a base64 binary plist under the Apple desktop XMP key
    /// `key`. Writes a sibling temp file, then moves it into place.
    nonisolated private static func writeHEIC(
        images: [CGImage],
        metadata: some Codable,
        key: String,
        outputURL: URL
    ) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let plistData = try encoder.encode(metadata)
        let base64String = plistData.base64EncodedString()

        let xmpNamespace = "http://ns.apple.com/namespace/1.0/" as CFString
        let xmpPrefix    = "apple_desktop" as CFString
        let imageMetadata = CGImageMetadataCreateMutable()

        guard CGImageMetadataRegisterNamespaceForPrefix(
            imageMetadata, xmpNamespace, xmpPrefix, nil
        ) else {
            throw DynamicWallpaperError.metadataCreationFailed
        }

        guard let tag = CGImageMetadataTagCreate(
            xmpNamespace, xmpPrefix, key as CFString, .string, base64String as CFTypeRef
        ) else {
            throw DynamicWallpaperError.metadataCreationFailed
        }

        guard CGImageMetadataSetTagWithPath(
            imageMetadata, nil, "apple_desktop:\(key)" as CFString, tag
        ) else {
            throw DynamicWallpaperError.metadataCreationFailed
        }

        let directory = outputURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: directory.path) else {
            throw DynamicWallpaperError.fileWriteFailed
        }
        removeStaleTempFiles(for: outputURL)

        // Sibling temp keeps a half-written file off the live wallpaper path.
        let tempURL = directory.appending(path: tempName(for: outputURL, id: UUID().uuidString))
        guard let destination = CGImageDestinationCreateWithURL(
            tempURL as CFURL, UTType.heic.identifier as CFString, images.count, nil
        ) else {
            throw DynamicWallpaperError.destinationCreationFailed
        }

        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: compressionQuality]

        for (index, image) in images.enumerated() {
            if index == 0 {
                CGImageDestinationAddImageAndMetadata(destination, image, imageMetadata, options as CFDictionary)
            } else {
                CGImageDestinationAddImage(destination, image, options as CFDictionary)
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw DynamicWallpaperError.finalizationFailed
        }

        do {
            _ = try FileManager.default.replaceItemAt(outputURL, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw DynamicWallpaperError.fileWriteFailed
        }
    }

    /// Hidden sibling name for an in-progress write of `outputURL`; the `.tmp`
    /// suffix keeps it clear of the `.heic` legacy cleanup.
    nonisolated private static func tempName(for outputURL: URL, id: String) -> String {
        "\(tempPrefix(for: outputURL))\(id).tmp"
    }

    /// Leading part shared by every temp sibling of `outputURL`.
    nonisolated private static func tempPrefix(for outputURL: URL) -> String {
        ".\(outputURL.lastPathComponent)."
    }

    /// Deletes temp siblings of `outputURL` left behind by a killed encode.
    nonisolated private static func removeStaleTempFiles(for outputURL: URL) {
        let directory = outputURL.deletingLastPathComponent()
        let prefix = tempPrefix(for: outputURL)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names where name.hasPrefix(prefix) && name.hasSuffix(".tmp") {
            try? FileManager.default.removeItem(at: directory.appending(path: name))
        }
    }
}
