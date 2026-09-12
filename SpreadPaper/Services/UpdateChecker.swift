//
//  UpdateChecker.swift
//  SpreadPaper
//
//  GitHub release update checker with changelog support
//

import Foundation
import AppKit

// MARK: - Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let publishedAt: Date?
    let assets: [GitHubAsset]

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

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

struct UpdateInfo {
    let currentVersion: String
    let latestVersion: String
    let releaseUrl: String
    let dmgUrl: String?
    let zipUrl: String?
    let publishedAt: Date?
    let isUpdateAvailable: Bool
}

struct ChangelogEntry {
    let version: String
    let date: String?

    /// GitHub release page for this version.
    var releaseURL: URL { UpdateChecker.releaseURL(for: version) }
}

// MARK: - UpdateChecker

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

    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        error = nil

        do {
            let url = URL(string: "\(apiBaseUrl)/releases/latest")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("SpreadPaper/\(currentVersion)", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try GitHubRelease.decode(from: data)
            processRelease(release)

            if updateInfo?.isUpdateAvailable == true {
                await fetchChangelog()
            }
        } catch {
            self.error = "Failed to check for updates: \(error.localizedDescription)"
        }

        isChecking = false
        lastCheckDate = Date()
    }

    func fetchChangelog() async {
        do {
            let url = URL(string: "https://raw.githubusercontent.com/\(Self.repoOwner)/\(Self.repoName)/main/CHANGELOG.md")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let content = String(data: data, encoding: .utf8) ?? ""
            parseChangelog(content)
        } catch {
            // Changelog fetch is best-effort
        }
    }

    func openReleasePage() {
        if let urlString = updateInfo?.releaseUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    func downloadDMG() {
        if let urlString = updateInfo?.dmgUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    func downloadZIP() {
        if let urlString = updateInfo?.zipUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private Methods

    private func processRelease(_ release: GitHubRelease) {
        let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
        let isUpdateAvailable = compareVersions(current: currentVersion, latest: latestVersion)

        let dmgAsset = release.assets.first { $0.name.hasSuffix(".dmg") }
        let zipAsset = release.assets.first { $0.name.hasSuffix(".zip") }

        updateInfo = UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseUrl: release.htmlUrl,
            dmgUrl: dmgAsset?.browserDownloadUrl,
            zipUrl: zipAsset?.browserDownloadUrl,
            publishedAt: release.publishedAt,
            isUpdateAvailable: isUpdateAvailable
        )
    }

    private func compareVersions(current: String, latest: String) -> Bool {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(currentParts.count, latestParts.count) {
            let currentPart = i < currentParts.count ? currentParts[i] : 0
            let latestPart = i < latestParts.count ? latestParts[i] : 0

            if latestPart > currentPart {
                return true
            } else if latestPart < currentPart {
                return false
            }
        }
        return false
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
