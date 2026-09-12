import Foundation
import Testing
@testable import SpreadPaper

/// Issue #73: dropped and picked files must be narrowed to images before they reach the editor.
struct ImageFileFilterTests {
    /// Builds a local file URL for a name under /tmp.
    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    @Test func webLinksAreDroppedEvenWithImageExtensions() {
        let web = URL(string: "https://example.com/photo.png")!
        #expect(ImageFileFilter.imageURLs(from: [web, url("local.png")]) == [url("local.png")])
    }

    @Test func commonImageExtensionsAreKept() {
        let urls = [url("a.png"), url("b.jpg"), url("c.jpeg"), url("d.heic"), url("e.tiff"), url("f.webp")]
        #expect(ImageFileFilter.imageURLs(from: urls) == urls)
    }

    @Test func nonImageFilesAreDropped() {
        let urls = [url("notes.txt"), url("paper.pdf"), url("clip.mov"), url("noext")]
        #expect(ImageFileFilter.imageURLs(from: urls).isEmpty)
    }

    @Test func orderIsPreserved() {
        let urls = [url("z.png"), url("skip.txt"), url("a.jpg"), url("m.heic")]
        #expect(ImageFileFilter.imageURLs(from: urls) == [url("z.png"), url("a.jpg"), url("m.heic")])
    }

    @Test func extensionsMatchCaseInsensitively() {
        let urls = [url("shout.PNG"), url("mixed.JpG"), url("loud.HEIC")]
        #expect(ImageFileFilter.imageURLs(from: urls) == urls)
    }

    @Test func emptyInputGivesEmptyOutput() {
        #expect(ImageFileFilter.imageURLs(from: []).isEmpty)
    }
}
