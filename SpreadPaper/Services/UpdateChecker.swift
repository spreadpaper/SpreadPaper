//
//  UpdateChecker.swift
//  SpreadPaper
//
//  GitHub release update checker with changelog support
//

import Foundation
import AppKit
import os

/// Technical failure details go here; `error` carries only plain copy for the UI.
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SpreadPaper", category: "updates")

// MARK: - Models

/// The fields of a GitHub release the checker decodes.
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let publishedAt: Date?
    let assets: [GitHubAsset]

    /// Snake-case names as the GitHub API sends them.
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }

    /// Decodes a GitHub release payload, reading `published_at` as ISO 8601.
    /// Drafts carry `null` there, which decodes to `nil`.
    static func decode(from data: Data) throws -> GitHubRelease {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GitHubRelease.self, from: data)
    }
}

/// One downloadable file attached to a release.
struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    /// Snake-case names as the GitHub API sends them.
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

/// A non-2xx reply from GitHub, worded for the Updates tab.
/// The status code stays in the debug log.
nonisolated struct GitHubStatusError: LocalizedError, Equatable {
    let statusCode: Int

    var errorDescription: String? {
        switch statusCode {
        case 403, 429: String(localized: "GitHub is limiting requests right now, try again later")
        case 404: String(localized: "No release found on GitHub")
        default: String(localized: "GitHub replied with an error (\(statusCode))")
        }
    }
}

/// Outcome of one check: the versions compared, where to get the release, and whether it is newer.
struct UpdateInfo {
    let currentVersion: String
    let latestVersion: String
    let latestTag: String
    let releaseUrl: String
    let dmgUrl: String?
    let zipUrl: String?
    let publishedAt: Date?
    let isUpdateAvailable: Bool
}

/// One release header from CHANGELOG.md, shown in the Updates tab.
struct ChangelogEntry {
    let version: String
    let date: String?

    /// GitHub release page for this version.
    var releaseURL: URL { UpdateChecker.releaseURL(for: version) }
}

// MARK: - UpdateChecker

/// Compares the running version against the latest GitHub release and exposes the result to the UI.
/// Also loads the changelog so the Updates tab can list what changed.
@Observable
class UpdateChecker {
    static let shared = UpdateChecker()

    var updateInfo: UpdateInfo?
    var isChecking = false
    var lastCheckDate: Date?
    var error: String?
    var changelog: [ChangelogEntry] = []

    private static let repoOwner = "spreadpaper"
    private static let repoName = "SpreadPaper"

    /// GitHub release page for a version tag.
    static func releaseURL(for version: String) -> URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/tag/v\(version)")!
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var apiBaseUrl: String {
        "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)"
    }

    // MARK: - Public Methods

    /// Fetches the latest release, records the comparison and loads the changelog when it is newer.
    /// Errors land in `error` as plain copy; a check already in flight is left alone.
    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        error = nil

        do {
            let url = URL(string: "\(apiBaseUrl)/releases/latest")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("SpreadPaper/\(currentVersion)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.checkStatus(response, body: data)
            let release = try GitHubRelease.decode(from: data)
            processRelease(release)

            if updateInfo?.isUpdateAvailable == true {
                await fetchChangelog()
            }
        } catch let decodingError as DecodingError {
            logger.error("Release payload did not decode: \(decodingError, privacy: .public)")
            self.error = "Failed to check for updates: GitHub sent an unexpected reply"
        } catch {
            self.error = "Failed to check for updates: \(error.localizedDescription)"
        }

        isChecking = false
        lastCheckDate = Date()
    }

    /// Reads the changelog at the latest release tag, or from `main` without one.
    /// Best-effort: failures leave `changelog` untouched.
    func fetchChangelog() async {
        if let tag = updateInfo?.latestTag,
           let content = try? await fetchText(Self.changelogURL(ref: "refs/tags/\(tag)")) {
            parseChangelog(content)
            return
        }
        guard let content = try? await fetchText(Self.changelogURL(ref: "main")) else { return }
        parseChangelog(content)
    }

    /// Raw `CHANGELOG.md` at a git ref such as `main` or `refs/tags/v1.2.0`.
    static func changelogURL(ref: String) -> URL {
        URL(string: "https://raw.githubusercontent.com/\(repoOwner)/\(repoName)/\(ref)/CHANGELOG.md")!
    }

    /// Strips one leading `v` from a release tag; anything else stays as is.
    static func version(fromTag tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// True when both strings parse as semver and `latest` sorts above `current`.
    /// Unparseable input never reports an update.
    static func isUpdateAvailable(latest: String, current: String) -> Bool {
        guard let latest = SemanticVersion(latest), let current = SemanticVersion(current) else {
            logger.error("Cannot compare versions \(latest, privacy: .public) and \(current, privacy: .public)")
            return false
        }
        return latest > current
    }

    /// Opens the latest release on GitHub in the browser.
    func openReleasePage() {
        if let urlString = updateInfo?.releaseUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Hands the release's DMG to the browser, if the release has one.
    func downloadDMG() {
        if let urlString = updateInfo?.dmgUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Hands the release's ZIP to the browser, if the release has one.
    func downloadZIP() {
        if let urlString = updateInfo?.zipUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private Methods

    /// Throws `GitHubStatusError` for a non-2xx reply; logs the body size first.
    /// Replies that are not HTTP pass through.
    static func checkStatus(_ response: URLResponse, body: Data) throws {
        guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        logger.debug("GitHub returned \(http.statusCode) with a \(body.count) byte body")
        throw GitHubStatusError(statusCode: http.statusCode)
    }

    /// Body of a GET as UTF-8; throws on transport failure or a non-2xx reply.
    private func fetchText(_ url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.checkStatus(response, body: data)
        return String(decoding: data, as: UTF8.self)
    }

    /// Turns a release into `updateInfo`, picking the DMG and ZIP assets by extension.
    private func processRelease(_ release: GitHubRelease) {
        let latestVersion = Self.version(fromTag: release.tagName)
        let isUpdateAvailable = Self.isUpdateAvailable(latest: latestVersion, current: currentVersion)

        let dmgAsset = release.assets.first { $0.name.hasSuffix(".dmg") }
        let zipAsset = release.assets.first { $0.name.hasSuffix(".zip") }

        updateInfo = UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            latestTag: release.tagName,
            releaseUrl: release.htmlUrl,
            dmgUrl: dmgAsset?.browserDownloadUrl,
            zipUrl: zipAsset?.browserDownloadUrl,
            publishedAt: release.publishedAt,
            isUpdateAvailable: isUpdateAvailable
        )
    }

    /// Reads release headers out of a release-please changelog into `changelog`.
    /// Accepts `## [1.1.3](url) (2025-11-22)` and `## 1.0.0 (2025-11-22)`.
    /// Headers without a version are skipped.
    func parseChangelog(_ content: String) {
        changelog = content
            .split(whereSeparator: \.isNewline)
            .filter { $0.hasPrefix("## ") }
            .compactMap { line -> ChangelogEntry? in
                let header = line.dropFirst(3)
                guard let versionMatch = header.firstMatch(of: #/\[?(?<version>\d+\.\d+\.\d+)\]?/#) else { return nil }
                let dateMatch = header.firstMatch(of: #/\((?<date>\d{4}-\d{2}-\d{2})\)/#)
                return ChangelogEntry(
                    version: String(versionMatch.version),
                    date: dateMatch.map { String($0.date) }
                )
            }
    }
}
