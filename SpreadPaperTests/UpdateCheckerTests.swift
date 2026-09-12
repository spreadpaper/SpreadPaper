import Foundation
import Testing
@testable import SpreadPaper

@MainActor
struct UpdateCheckerTests {
    @Test func releaseURLPointsAtGitHubReleaseTag() {
        #expect(
            UpdateChecker.releaseURL(for: "1.8.0")
                == URL(string: "https://github.com/spreadpaper/SpreadPaper/releases/tag/v1.8.0")
        )
    }

    // Issue #85: release-please headers, one linked with a date and one bare without.
    @Test func parseChangelogReadsVersionsAndDates() {
        let checker = UpdateChecker()
        checker.parseChangelog("""
        # Changelog

        ## [1.1.3](https://github.com/spreadpaper/SpreadPaper/compare/v1.1.2...v1.1.3) (2025-11-22)

        ### Bug Fixes

        * something

        ## 1.0.0

        * initial
        """)

        #expect(checker.changelog.map(\.version) == ["1.1.3", "1.0.0"])
        #expect(checker.changelog.map(\.date) == ["2025-11-22", nil])
    }

    @Test func parseChangelogSkipsHeadersWithoutVersion() {
        let checker = UpdateChecker()
        checker.parseChangelog("## Unreleased\n\n## 2.0.0 (2026-01-05)\n")
        #expect(checker.changelog.map(\.version) == ["2.0.0"])
        #expect(checker.changelog.first?.date == "2026-01-05")
    }

    @Test func releaseDecodesPublishedAtAsDate() throws {
        let json = """
        {
          "tag_name": "v1.8.0",
          "name": "v1.8.0",
          "body": "notes",
          "html_url": "https://github.com/spreadpaper/SpreadPaper/releases/tag/v1.8.0",
          "published_at": "2025-11-22T10:15:00Z",
          "assets": [
            { "name": "SpreadPaper.dmg", "browser_download_url": "https://example.com/SpreadPaper.dmg", "size": 1 }
          ]
        }
        """
        let release = try GitHubRelease.decode(from: Data(json.utf8))
        let published = try #require(release.publishedAt)
        #expect(published == Date(timeIntervalSince1970: 1_763_806_500))
        #expect(release.assets.first?.name == "SpreadPaper.dmg")
    }

    @Test func releaseDecodesNullPublishedAtAsNil() throws {
        let json = """
        { "tag_name": "v1.8.0", "name": "n", "body": "b", "html_url": "https://example.com", "published_at": null, "assets": [] }
        """
        #expect(try GitHubRelease.decode(from: Data(json.utf8)).publishedAt == nil)
    }
}
