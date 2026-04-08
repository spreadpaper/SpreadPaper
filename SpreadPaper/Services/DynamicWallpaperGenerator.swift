import AVFoundation
import CoreGraphics
import ImageIO
import Foundation

// MARK: - Metadata Models
// Based on the metadata format reverse-engineered by wallpapper
// (https://github.com/mczachurski/wallpapper) by Marcin Czachurski (MIT).

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

struct TimeBasedItem: Codable {
    enum CodingKeys: String, CodingKey {
        case time = "t"
        case imageIndex = "i"
    }
    var time: Double
    var imageIndex: Int
}

struct AppearanceInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case darkIndex = "d"
        case lightIndex = "l"
    }
    var darkIndex: Int
    var lightIndex: Int
}

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
    static func generateTimeBasedHEIC(
        images: [CGImage],
        hours: [Int],
        minutes: [Int],
        outputURL: URL
    ) throws {
        guard !images.isEmpty else { throw DynamicWallpaperError.noImages }
        guard hours.count == images.count, minutes.count == images.count else {
            throw DynamicWallpaperError.noImages
        }

        let timeItems: [TimeBasedItem] = images.indices.map { idx in
            let fraction = Double(hours[idx]) / 24.0 + Double(minutes[idx]) / 1440.0
            return TimeBasedItem(time: fraction, imageIndex: idx)
        }

        let noonFraction = 12.0 / 24.0
        let lightIndex = timeItems
            .min(by: { abs($0.time - noonFraction) < abs($1.time - noonFraction) })!
            .imageIndex
        let darkIndex = timeItems
            .min(by: { min($0.time, 1.0 - $0.time) < min($1.time, 1.0 - $1.time) })!
            .imageIndex

        let metadata = DynamicMetadata(
            solarItems: nil,
            timeItems: timeItems,
            appearance: AppearanceInfo(darkIndex: darkIndex, lightIndex: lightIndex)
        )

        try writeHEIC(images: images, metadata: metadata, key: "h24", outputURL: outputURL)
    }

    /// Create an appearance-based (apr) dynamic desktop HEIC file.
    /// Two images: one for light mode, one for dark mode.
    static func generateAppearanceHEIC(
        lightImage: CGImage,
        darkImage: CGImage,
        outputURL: URL
    ) throws {
        let appearance = AppearanceInfo(darkIndex: 1, lightIndex: 0)
        try writeHEIC(images: [lightImage, darkImage], metadata: appearance, key: "apr", outputURL: outputURL)
    }

    // MARK: - Shared HEIC writing

    private static func writeHEIC(
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

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, AVFileType.heic.rawValue as CFString, images.count, nil
        ) else {
            throw DynamicWallpaperError.destinationCreationFailed
        }

        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]

        for (index, image) in images.enumerated() {
            if index == 0 {
                CGImageDestinationAddImageAndMetadata(destination, image, imageMetadata, options as CFDictionary)
            } else {
                CGImageDestinationAddImage(destination, image, options as CFDictionary)
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw DynamicWallpaperError.finalizationFailed
        }

        guard data.write(to: outputURL, atomically: true) else {
            throw DynamicWallpaperError.fileWriteFailed
        }
    }
}
