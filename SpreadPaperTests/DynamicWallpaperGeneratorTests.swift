import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import SpreadPaper

/// The HEIC writer runs off the main actor since #59; these read the files back through ImageIO.
struct DynamicWallpaperGeneratorTests {
    private func solidImage(_ gray: CGFloat) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(gray: gray, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        return try #require(context.makeImage())
    }

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "gen-\(UUID().uuidString).heic")
    }

    private func xmp(at url: URL) throws -> String {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let metadata = try #require(CGImageSourceCopyMetadataAtIndex(source, 0, nil))
        let tags = try #require(CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag])
        return tags.map { CGImageMetadataTagCopyName($0) as String? ?? "" }.joined(separator: ",")
    }

    @Test func appearanceFileHasTwoImagesAndAprTag() throws {
        let url = tempURL()
        try DynamicWallpaperGenerator.generateAppearanceHEIC(
            lightImage: try solidImage(1), darkImage: try solidImage(0), outputURL: url
        )
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == 2)
        #expect(try xmp(at: url).contains("apr"))
    }

    @Test func timeBasedFileHasOneImagePerVariantAndH24Tag() throws {
        let url = tempURL()
        try DynamicWallpaperGenerator.generateTimeBasedHEIC(
            images: [try solidImage(0.2), try solidImage(0.5), try solidImage(0.8)],
            hours: [6, 12, 20], minutes: [0, 30, 0], outputURL: url
        )
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == 3)
        #expect(try xmp(at: url).contains("h24"))
    }

    @Test func timeBasedRejectsMismatchedCounts() throws {
        #expect(throws: DynamicWallpaperError.countMismatch) {
            try DynamicWallpaperGenerator.generateTimeBasedHEIC(
                images: [try solidImage(0.5)], hours: [1, 2], minutes: [0, 0], outputURL: tempURL()
            )
        }
    }

    @Test func timeBasedRejectsMismatchedMinutesAlone() throws {
        #expect(throws: DynamicWallpaperError.countMismatch) {
            try DynamicWallpaperGenerator.generateTimeBasedHEIC(
                images: [try solidImage(0.5)], hours: [1], minutes: [0, 0], outputURL: tempURL()
            )
        }
    }

    @Test func writeSweepsStaleTempSiblings() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "gen-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "1.heic")
        try Data("stale".utf8).write(to: directory.appending(path: ".1.heic.killed.tmp"))
        try Data("other".utf8).write(to: directory.appending(path: ".2.heic.killed.tmp"))

        try DynamicWallpaperGenerator.generateAppearanceHEIC(
            lightImage: try solidImage(1), darkImage: try solidImage(0), outputURL: url
        )

        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        #expect(contents == [".2.heic.killed.tmp", "1.heic"])
    }

    @Test func writeFailsWithFileWriteErrorWhenDirectoryIsMissing() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "gen-missing-\(UUID().uuidString)").appending(path: "1.heic")
        #expect(throws: DynamicWallpaperError.fileWriteFailed) {
            try DynamicWallpaperGenerator.generateAppearanceHEIC(
                lightImage: try solidImage(1), darkImage: try solidImage(0), outputURL: url
            )
        }
    }

    @Test func timeBasedRejectsEmptyImages() throws {
        #expect(throws: DynamicWallpaperError.noImages) {
            try DynamicWallpaperGenerator.generateTimeBasedHEIC(
                images: [], hours: [], minutes: [], outputURL: tempURL()
            )
        }
    }

    @Test func writeLeavesOnlyTheOutputFileBehind() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "gen-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "1.heic")

        try DynamicWallpaperGenerator.generateAppearanceHEIC(
            lightImage: try solidImage(1), darkImage: try solidImage(0), outputURL: url
        )

        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(contents == ["1.heic"])
    }

    @Test func writeReplacesAnExistingOutputFile() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "gen-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "1.heic")
        try Data("stale".utf8).write(to: url)

        try DynamicWallpaperGenerator.generateTimeBasedHEIC(
            images: [try solidImage(0.2), try solidImage(0.8)], hours: [8, 20], minutes: [0, 0], outputURL: url
        )

        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == 2)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["1.heic"])
    }
}
