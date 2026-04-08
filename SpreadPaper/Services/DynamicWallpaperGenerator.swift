import AVFoundation
import CoreGraphics
import ImageIO
import Foundation

// MARK: - Metadata Models
// Based on the metadata format reverse-engineered by wallpapper
// (https://github.com/mczachurski/wallpapper) by Marcin Czachurski (MIT).

/// Solar position–based item: macOS selects the image whose solar position
/// (altitude/azimuth) is closest to the current sun position.
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

/// Time-based item: macOS selects the image whose fractional time-of-day
/// is closest to the current time.
struct TimeBasedItem: Codable {
    enum CodingKeys: String, CodingKey {
        case time = "t"
        case imageIndex = "i"
    }
    /// Fraction of day: hour/24 + minute/1440
    var time: Double
    var imageIndex: Int
}

/// Light/Dark appearance pair used when the system is in
/// light or dark mode (static pair, no time component).
struct AppearanceInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case darkIndex = "d"
        case lightIndex = "l"
    }
    var darkIndex: Int
    var lightIndex: Int
}

/// Root container written into the HEIC XMP metadata.
/// Only one of `solarItems` / `timeItems` should be set.
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

// MARK: - Errors

enum DynamicWallpaperError: Error, LocalizedError {
    case noImages
    case imageLoadFailed
    case cgImageConversionFailed
    case destinationCreationFailed
    case metadataCreationFailed
    case finalizationFailed
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .noImages:                   return "No images provided."
        case .imageLoadFailed:            return "Failed to load source image."
        case .cgImageConversionFailed:    return "Failed to convert image to CGImage."
        case .destinationCreationFailed:  return "Failed to create CGImageDestination."
        case .metadataCreationFailed:     return "Failed to create image metadata."
        case .finalizationFailed:         return "Failed to finalize the HEIC file."
        case .fileWriteFailed:            return "Failed to write the HEIC file to disk."
        }
    }
}

// MARK: - Generator

enum DynamicWallpaperGenerator {

    /// Create a time-based (h24) dynamic desktop HEIC file.
    ///
    /// - Parameters:
    ///   - images: Array of `CGImage` frames (at least one).
    ///   - hours: Hour component (0-23) for each image (same count as `images`).
    ///   - minutes: Minute component (0-59) for each image (same count as `images`).
    ///   - outputURL: File URL where the HEIC will be written.
    /// - Throws: `DynamicWallpaperError` on failure.
    static func generateTimeBasedHEIC(
        images: [CGImage],
        hours: [Int],
        minutes: [Int],
        outputURL: URL
    ) throws {
        guard !images.isEmpty else { throw DynamicWallpaperError.noImages }

        // -- Build TimeBasedItem array --
        let timeItems: [TimeBasedItem] = images.indices.map { idx in
            let fraction = Double(hours[idx]) / 24.0 + Double(minutes[idx]) / 1440.0
            return TimeBasedItem(time: fraction, imageIndex: idx)
        }

        // -- Auto-pick light/dark indices --
        let noonFraction   = 12.0 / 24.0   // 0.5
        let midnightFraction = 0.0

        let lightIndex = timeItems
            .min(by: { abs($0.time - noonFraction) < abs($1.time - noonFraction) })!
            .imageIndex
        let darkIndex = timeItems
            .min(by: { abs($0.time - midnightFraction) < abs($1.time - midnightFraction) })!
            .imageIndex

        let metadata = DynamicMetadata(
            solarItems: nil,
            timeItems: timeItems,
            appearance: AppearanceInfo(darkIndex: darkIndex, lightIndex: lightIndex)
        )

        // -- Encode as binary plist, then base64 --
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let plistData = try encoder.encode(metadata)
        let base64String = plistData.base64EncodedString()

        // -- Build XMP metadata --
        let xmpNamespace = "http://ns.apple.com/namespace/1.0/" as CFString
        let xmpPrefix    = "apple_desktop" as CFString

        guard CGImageMetadataRegisterNamespaceForPrefix(
            CGImageMetadataCreateMutable(),
            xmpNamespace,
            xmpPrefix,
            nil
        ) else {
            throw DynamicWallpaperError.metadataCreationFailed
        }

        guard let tag = CGImageMetadataTagCreate(
            xmpNamespace,
            xmpPrefix,
            "h24" as CFString,
            .string,
            base64String as CFTypeRef
        ) else {
            throw DynamicWallpaperError.metadataCreationFailed
        }

        let imageMetadata = CGImageMetadataCreateMutable()
        guard CGImageMetadataSetTagWithPath(
            imageMetadata,
            nil,
            "apple_desktop:h24" as CFString,
            tag
        ) else {
            throw DynamicWallpaperError.metadataCreationFailed
        }

        // -- Write HEIC via CGImageDestination --
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            AVFileType.heic.rawValue as CFString,
            images.count,
            nil
        ) else {
            throw DynamicWallpaperError.destinationCreationFailed
        }

        let imageProperties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.9
        ]

        for (index, image) in images.enumerated() {
            if index == 0 {
                CGImageDestinationAddImageAndMetadata(
                    destination,
                    image,
                    imageMetadata,
                    imageProperties as CFDictionary
                )
            } else {
                CGImageDestinationAddImage(
                    destination,
                    image,
                    imageProperties as CFDictionary
                )
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw DynamicWallpaperError.finalizationFailed
        }

        // -- Write to disk --
        guard data.write(to: outputURL, atomically: true) else {
            throw DynamicWallpaperError.fileWriteFailed
        }
    }
}
