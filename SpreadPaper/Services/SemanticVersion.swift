import Foundation

/// A semver 2.0 version with optional prerelease and build metadata.
/// Ordering follows the spec: numeric core, then prerelease.
/// Build metadata never affects ordering or equality.
nonisolated struct SemanticVersion: Comparable, Sendable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int
    /// Dot-split identifiers after the hyphen, empty for a release.
    let prerelease: [String]
    /// Text after `+`, kept verbatim.
    let build: String?

    /// Accepts `major.minor.patch`, `-prerelease` and `+build` per semver 2.0.
    /// Returns nil for anything else, including leading zeros.
    init?(_ string: String) {
        let pattern = #/(?<major>0|[1-9][0-9]*)\.(?<minor>0|[1-9][0-9]*)\.(?<patch>0|[1-9][0-9]*)(?:-(?<prerelease>(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+(?<build>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?/#
        guard let match = string.wholeMatch(of: pattern),
              let major = Int(match.major),
              let minor = Int(match.minor),
              let patch = Int(match.patch) else { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = match.prerelease.map { $0.split(separator: ".").map(String.init) } ?? []
        self.build = match.build.map(String.init)
    }

    /// Core and prerelease, build metadata dropped.
    var description: String {
        let core = "\(major).\(minor).\(patch)"
        return prerelease.isEmpty ? core : "\(core)-\(prerelease.joined(separator: "."))"
    }

    /// Equal when core and prerelease match; build is ignored.
    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        lhs.core == rhs.core && lhs.prerelease == rhs.prerelease
    }

    /// Semver 2.0 section 11 ordering: core, then prerelease identifiers.
    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.core != rhs.core {
            return lhs.core.lexicographicallyPrecedes(rhs.core)
        }
        // A release outranks every prerelease of the same core.
        switch (lhs.prerelease.isEmpty, rhs.prerelease.isEmpty) {
        case (true, _): return false
        case (false, true): return true
        case (false, false): break
        }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) where left != right {
            return Self.identifierPrecedes(left, right)
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }

    private var core: [Int] { [major, minor, patch] }

    /// Semver 2.0 rule 11.4: numeric before alphanumeric, else numeric or ASCII order.
    private static func identifierPrecedes(_ lhs: String, _ rhs: String) -> Bool {
        switch (numericValue(of: lhs), numericValue(of: rhs)) {
        case let (left?, right?): return left < right
        case (.some, .none): return true
        case (.none, .some): return false
        case (.none, .none): return lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
        }
    }

    /// Integer value of an identifier made only of ASCII digits, else nil.
    private static func numericValue(of identifier: String) -> Int? {
        identifier.utf8.allSatisfy { $0 >= 48 && $0 <= 57 } ? Int(identifier) : nil
    }
}
