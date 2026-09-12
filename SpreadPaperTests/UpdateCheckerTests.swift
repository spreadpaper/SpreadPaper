import Foundation
import Testing
@testable import SpreadPaper

/// Exercises the checker's pure helpers: URLs, tag parsing, status handling and changelog parsing.
@MainActor
struct UpdateCheckerTests {
    @Test func releaseURLPointsAtGitHubReleaseTag() {
        #expect(
            UpdateChecker.releaseURL(for: "1.8.0")
                == URL(string: "https://github.com/spreadpaper/SpreadPaper/releases/tag/v1.8.0")
        )
    }

    // Issue #83: only a leading v is a prefix; any other v belongs to the version.
    @Test func versionFromTagStripsOnlyLeadingV() {
        #expect(UpdateChecker.version(fromTag: "v1.2.0-dev") == "1.2.0-dev")
        #expect(UpdateChecker.version(fromTag: "1.2.0") == "1.2.0")
        #expect(UpdateChecker.version(fromTag: "v1.8.0") == "1.8.0")
    }

    @Test func changelogURLTargetsTagOrMain() {
        #expect(
            UpdateChecker.changelogURL(ref: "refs/tags/v1.8.0")
                == URL(string: "https://raw.githubusercontent.com/spreadpaper/SpreadPaper/refs/tags/v1.8.0/CHANGELOG.md")
        )
        #expect(
            UpdateChecker.changelogURL(ref: "main")
                == URL(string: "https://raw.githubusercontent.com/spreadpaper/SpreadPaper/main/CHANGELOG.md")
        )
    }

    // Issue #83: the Debug build reports 1.1.3, so every real release must still count as newer.
    @Test func updateAvailabilityFollowsSemver() {
        #expect(UpdateChecker.isUpdateAvailable(latest: "1.8.0", current: "1.1.3"))
        #expect(UpdateChecker.isUpdateAvailable(latest: "1.10.0", current: "1.9.0"))
        #expect(UpdateChecker.isUpdateAvailable(latest: "1.9.0-beta.1", current: "1.1.3"))
        #expect(!UpdateChecker.isUpdateAvailable(latest: "1.9.0-beta.1", current: "1.9.0"))
        #expect(!UpdateChecker.isUpdateAvailable(latest: "1.1.3", current: "1.1.3"))
        #expect(!UpdateChecker.isUpdateAvailable(latest: "1.0.0", current: "1.1.3"))
        #expect(!UpdateChecker.isUpdateAvailable(latest: "nightly", current: "1.1.3"))
    }

    @Test func statusErrorReadsAsPlainCopy() {
        #expect(GitHubStatusError(statusCode: 403).localizedDescription == "GitHub is limiting requests right now, try again later")
        #expect(GitHubStatusError(statusCode: 429).localizedDescription == "GitHub is limiting requests right now, try again later")
        #expect(GitHubStatusError(statusCode: 404).localizedDescription == "No release found on GitHub")
        #expect(GitHubStatusError(statusCode: 500).localizedDescription == "GitHub replied with an error (500)")
    }

    // Issue #83: a non-2xx reply stops before decoding; non-HTTP replies pass through.
    @Test func checkStatusThrowsOnlyForNon2xxHTTP() throws {
        let url = URL(string: "https://api.github.com/repos/spreadpaper/SpreadPaper/releases/latest")!
        let ok = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        let forbidden = try #require(HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil))

        #expect(throws: Never.self) { try UpdateChecker.checkStatus(ok, body: Data()) }
        #expect(throws: Never.self) { try UpdateChecker.checkStatus(URLResponse(), body: Data()) }
        #expect(throws: GitHubStatusError(statusCode: 403)) {
            try UpdateChecker.checkStatus(forbidden, body: Data("<html>".utf8))
        }
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
