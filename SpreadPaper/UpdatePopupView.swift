//
//  UpdatePopupView.swift
//  SpreadPaper
//
//  Popup view shown when a new version is available on app startup
//

import SwiftUI
import AppKit

struct UpdatePopupView: View {
    @ObservedObject var updateChecker: UpdateChecker
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header with icon and title
            headerSection

            Divider()

            // Content area with version info and changelog
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    versionInfoSection
                    changelogSection
                }
                .padding(24)
            }
            .frame(maxHeight: 300)

            Divider()

            // Action buttons
            actionButtonsSection
        }
        .frame(width: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }

            Text("Update Available")
                .font(.title2)
                .fontWeight(.semibold)

            if let info = updateChecker.updateInfo {
                Text("SpreadPaper \(info.latestVersion) is now available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Version Info Section

    private var versionInfoSection: some View {
        Group {
            if let info = updateChecker.updateInfo {
                HStack(spacing: 16) {
                    versionBadge(
                        title: "Current",
                        version: info.currentVersion,
                        color: .secondary
                    )

                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    versionBadge(
                        title: "New",
                        version: info.latestVersion,
                        color: .blue
                    )

                    Spacer()

                    if let publishedAt = info.publishedAt {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Released")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(publishedAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func versionBadge(title: String, version: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("v\(version)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Changelog Section

    private var changelogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What's New", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.primary)

            let relevantChanges = updateChecker.getChangelogBetweenVersions()

            if relevantChanges.isEmpty {
                // Show release notes from GitHub if no parsed changelog
                if let info = updateChecker.updateInfo, !info.releaseNotes.isEmpty {
                    changelogContent(info.releaseNotes)
                } else {
                    Text("See the release page for details.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(relevantChanges, id: \.version) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("v\(entry.version)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)

                            if let date = entry.date {
                                Text(date)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        changelogContent(entry.content)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }

    private func changelogContent(_ content: String) -> some View {
        Group {
            if let attributedString = try? AttributedString(markdown: content) {
                Text(attributedString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button(action: { isPresented = false }) {
                Text("Remind Me Later")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if let info = updateChecker.updateInfo {
                if info.dmgUrl != nil {
                    Button(action: {
                        updateChecker.downloadDMG()
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Download DMG")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if info.zipUrl != nil {
                    Button(action: {
                        updateChecker.downloadZIP()
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download ZIP")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button(action: {
                        updateChecker.openReleasePage()
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "safari")
                            Text("View Release")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    UpdatePopupView(
        updateChecker: UpdateChecker.shared,
        isPresented: .constant(true)
    )
}
