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
}
