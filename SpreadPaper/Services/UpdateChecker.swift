//
//  UpdateChecker.swift
//  SpreadPaper
//
//  GitHub release update checker with changelog support
//

import Foundation
import Combine
import AppKit

// MARK: - Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let publishedAt: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
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
    let releaseNotes: String
    let releaseUrl: String
    let dmgUrl: String?
    let zipUrl: String?
    let publishedAt: Date?
    let isUpdateAvailable: Bool
}

struct ChangelogEntry {
    let version: String
    let date: String?
    let content: String
}

// MARK: - UpdateChecker

class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var updateInfo: UpdateInfo?
    @Published var isChecking = false
    @Published var lastCheckDate: Date?
    @Published var error: String?
    @Published var changelog: [ChangelogEntry] = []

    private let repoOwner = "spreadpaper"
    private let repoName = "SpreadPaper"
    private var cancellables = Set<AnyCancellable>()

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var apiBaseUrl: String {
        "https://api.github.com/repos/\(repoOwner)/\(repoName)"
    }

    // MARK: - Public Methods

    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true
        error = nil

        let url = URL(string: "\(apiBaseUrl)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("SpreadPaper/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GitHubRelease.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isChecking = false
                self?.lastCheckDate = Date()
                if case .failure(let err) = completion {
                    self?.error = "Failed to check for updates: \(err.localizedDescription)"
                }
            } receiveValue: { [weak self] release in
                self?.processRelease(release)
            }
            .store(in: &cancellables)
    }

    func fetchChangelog() {
        let url = URL(string: "https://raw.githubusercontent.com/\(repoOwner)/\(repoName)/main/CHANGELOG.md")!

        URLSession.shared.dataTaskPublisher(for: url)
            .map { String(data: $0.data, encoding: .utf8) ?? "" }
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] content in
                self?.parseChangelog(content)
            }
            .store(in: &cancellables)
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

        let dateFormatter = ISO8601DateFormatter()
        let publishedDate = dateFormatter.date(from: release.publishedAt)

        updateInfo = UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseNotes: release.body,
            releaseUrl: release.htmlUrl,
            dmgUrl: dmgAsset?.browserDownloadUrl,
            zipUrl: zipAsset?.browserDownloadUrl,
            publishedAt: publishedDate,
            isUpdateAvailable: isUpdateAvailable
        )

        // Fetch changelog if update is available
        if isUpdateAvailable {
            fetchChangelog()
        }
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

    private func parseChangelog(_ content: String) {
        var entries: [ChangelogEntry] = []
        let lines = content.components(separatedBy: "\n")

        var currentVersion: String?
        var currentDate: String?
        var currentContent: [String] = []

        for line in lines {
            // Match version headers like "## [1.1.3](url) (2025-11-22)" or "## 1.0.0 (2025-11-22)"
            if line.hasPrefix("## ") {
                // Save previous entry
                if let version = currentVersion {
                    entries.append(ChangelogEntry(
                        version: version,
                        date: currentDate,
                        content: currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }

                // Parse new version
                let headerContent = String(line.dropFirst(3))

                // Extract version number
                if let versionMatch = headerContent.range(of: #"\[?(\d+\.\d+\.\d+)\]?"#, options: .regularExpression) {
                    currentVersion = String(headerContent[versionMatch])
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                }

                // Extract date
                if let dateMatch = headerContent.range(of: #"\((\d{4}-\d{2}-\d{2})\)"#, options: .regularExpression) {
                    currentDate = String(headerContent[dateMatch])
                        .replacingOccurrences(of: "(", with: "")
                        .replacingOccurrences(of: ")", with: "")
                }

                currentContent = []
            } else if currentVersion != nil && !line.hasPrefix("# ") {
                currentContent.append(line)
            }
        }

        // Add last entry
        if let version = currentVersion {
            entries.append(ChangelogEntry(
                version: version,
                date: currentDate,
                content: currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        changelog = entries
    }

    /// Returns changelog entries between current version and latest version
    func getChangelogBetweenVersions() -> [ChangelogEntry] {
        guard let info = updateInfo else { return [] }

        return changelog.filter { entry in
            compareVersions(current: info.currentVersion, latest: entry.version) &&
            !compareVersions(current: info.latestVersion, latest: entry.version)
        }
    }
}
