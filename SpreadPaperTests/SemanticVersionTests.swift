import Foundation
import Testing
@testable import SpreadPaper

/// Issue #83: versions order by semver 2.0, so prereleases stay below their release.
struct SemanticVersionTests {
    private func version(_ string: String) throws -> SemanticVersion {
        try #require(SemanticVersion(string))
    }

    @Test func parsesCoreAndOptionalParts() throws {
        let plain = try version("1.9.0")
        #expect(plain.major == 1 && plain.minor == 9 && plain.patch == 0)
        #expect(plain.prerelease.isEmpty && plain.build == nil)

        let full = try version("1.9.0-beta.1+build.7")
        #expect(full.prerelease == ["beta", "1"])
        #expect(full.build == "build.7")
        #expect(full.description == "1.9.0-beta.1")
    }

    @Test func ordersNumericallyNotLexically() throws {
        #expect(try version("1.8.0") < version("1.9.0"))
        #expect(try version("1.10.0") > version("1.9.0"))
        #expect(try version("1.9.9") < version("2.0.0"))
        #expect(try version("1.1.3") < version("1.8.0"))
    }

    @Test func prereleaseSortsBelowItsRelease() throws {
        #expect(try version("1.9.0-beta.1") < version("1.9.0"))
        #expect(try version("1.9.0-beta.1") > version("1.8.0"))
        #expect(try version("1.9.0-beta.2") > version("1.9.0-beta.1"))
    }

    @Test func prereleaseIdentifiersFollowSpecPrecedence() throws {
        // Semver 2.0 section 11.4 example, in order.
        let ordered = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0"]
        let parsed = try ordered.map(version)
        for (lower, higher) in zip(parsed, parsed.dropFirst()) {
            #expect(lower < higher, "\(lower) should precede \(higher)")
        }
    }

    @Test func buildMetadataIsIgnored() throws {
        #expect(try version("1.9.0+abc") == version("1.9.0+def"))
        #expect(try version("1.9.0+abc") == version("1.9.0"))
        #expect(try !(version("1.9.0+abc") < version("1.9.0+def")))
    }

    @Test func equalityMatchesOrdering() throws {
        let alpha = try version("1.0.0-alpha")
        #expect(try alpha == version("1.0.0-alpha"))
        #expect(!(alpha < alpha))
        #expect(try version("1.0.0-alpha") != version("1.0.0-beta"))
    }

    @Test func rejectsInvalidStrings() {
        for invalid in ["", "1", "1.2", "1.2.x", "v1.2.3", "01.2.3", "-1.2.3", "1.2.3-", "1.2.3-01", "1.2.3-beta.01", "1.2.3-beta..1", "1.2.3+", "1.2.3-٣a", "banana", "1.2.3 "] {
            #expect(SemanticVersion(invalid) == nil, "\(invalid) should not parse")
        }
    }
}
