import Foundation
import Testing
@testable import SpreadPaper

/// Issue #85: stored names keep spaces and inner dots, split on the last extension, and cap the base.
struct FilenameUtilsTests {
    private let uuid = UUID(uuidString: "0B2C1A2E-6F6A-4D4B-9B0F-0C1D2E3F4A5B")!

    @Test func storedNameKeepsSpacesAndInnerDots() {
        #expect(
            FilenameUtils.storedName(uuid: uuid, originalFilename: "my photo.final.PNG")
                == "0B2C1A2E-6F6A-4D4B-9B0F-0C1D2E3F4A5B_my photo.final.PNG"
        )
    }

    @Test func storedNameWithoutExtensionAddsNone() {
        #expect(FilenameUtils.storedName(uuid: uuid, originalFilename: "noext") == "0B2C1A2E-6F6A-4D4B-9B0F-0C1D2E3F4A5B_noext")
        #expect(FilenameUtils.storedName(uuid: uuid, originalFilename: "Photo 12.30 PM") == "0B2C1A2E-6F6A-4D4B-9B0F-0C1D2E3F4A5B_Photo 12.30 PM")
    }

    @Test func storedNameFallsBackForEmptyName() {
        #expect(FilenameUtils.storedName(uuid: uuid, originalFilename: "") == "0B2C1A2E-6F6A-4D4B-9B0F-0C1D2E3F4A5B_image")
    }

    @Test func storedNameSanitisesSeparatorsAndCaps() {
        let long = String(repeating: "x", count: 100)
        #expect(FilenameUtils.storedName(uuid: uuid, originalFilename: "a\\b.png") == "0B2C1A2E-6F6A-4D4B-9B0F-0C1D2E3F4A5B_a-b.png")
        #expect(FilenameUtils.storedName(uuid: uuid, originalFilename: "\(long).png") == "0B2C1A2E-6F6A-4D4B-9B0F-0C1D2E3F4A5B_\(String(repeating: "x", count: 80)).png")
    }

    @Test func displayNameRoundTripsDotsAndSpaces() {
        let stored = FilenameUtils.storedName(uuid: uuid, originalFilename: "my photo.final.PNG")
        #expect(FilenameUtils.displayName(for: stored) == "my photo.final")
    }

    @Test func displayNameHandlesUnprefixedAndEmptyNames() {
        #expect(FilenameUtils.displayName(for: "plain.png") == "plain")
        #expect(FilenameUtils.displayName(for: "50%.jpg") == "50%")
        #expect(FilenameUtils.displayName(for: ".hidden") == ".hidden")
        #expect(FilenameUtils.displayName(for: "Photo 12.30 PM") == "Photo 12.30 PM")
        #expect(FilenameUtils.displayName(for: "") == "")
    }
}
