// SpreadPaper/Views/SettingsView.swift

import SwiftUI

/// Native macOS Settings window with a General and an Updates tab.
struct SettingsView: View {
    let manager: WallpaperManager

    var body: some View {
        TabView {
            GeneralSettingsTab(manager: manager)
                .tabItem { Label("General", systemImage: "gearshape") }
            UpdatesSettingsTab()
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 480)
    }
}

// MARK: - General

/// Display settings that apply to every connected screen.
private struct GeneralSettingsTab: View {
    @State private var settings = AppSettings.shared
    let manager: WallpaperManager

    var body: some View {
        Form {
            Section {
                LabeledContent("Default display gap") {
                    HStack(spacing: 6) {
                        TextField("Default display gap", value: gap, format: .number.precision(.fractionLength(0)))
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(width: 64)
                        Text("pt")
                            .foregroundStyle(.secondary)
                        Stepper("Default display gap", value: gap, in: 0...1000, step: 1)
                            .labelsHidden()
                    }
                }
            } header: {
                Text("Displays")
            } footer: {
                Text("Gap between adjacent displays in screen points. Per-display widths are set in the editor.")
            }
        }
        .formStyle(.grouped)
        .frame(height: 170)
        .onChange(of: settings.bezelGap) { _, _ in manager.refreshScreens() }
    }

    /// Binding that keeps typed values inside the stepper range.
    private var gap: Binding<Double> {
        Binding(
            get: { settings.bezelGap },
            set: { settings.bezelGap = min(max($0, 0), 1000) }
        )
    }
}

// MARK: - Updates

/// Update status, downloads and release note links.
private struct UpdatesSettingsTab: View {
    @State private var updateChecker = UpdateChecker.shared
    @State private var isLoadingChangelog = false

    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let maxReleaseNotes = 6

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: version)
                LabeledContent("Status", value: statusText)
                LabeledContent("Last checked", value: lastCheckedText)
                HStack {
                    Spacer()
                    if updateChecker.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("Check for Updates") {
                        Task { await updateChecker.checkForUpdates() }
                    }
                    .disabled(updateChecker.isChecking)
                }
            } footer: {
                if let error = updateChecker.error {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            if let info = updateChecker.updateInfo, info.isUpdateAvailable {
                Section("Update to v\(info.latestVersion)") {
                    if info.dmgUrl != nil {
                        Button("Download DMG") { updateChecker.downloadDMG() }
                    }
                    if info.zipUrl != nil {
                        Button("Download ZIP") { updateChecker.downloadZIP() }
                    }
                    Button("View on GitHub") { updateChecker.openReleasePage() }
                }
            }

            Section("Release notes") {
                if updateChecker.changelog.isEmpty {
                    Text(isLoadingChangelog ? "Loading…" : "No release notes available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(updateChecker.changelog.prefix(maxReleaseNotes), id: \.version) { entry in
                        releaseLink(for: entry)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: updateChecker.updateInfo?.isUpdateAvailable == true ? 600 : 520)
        .task {
            if updateChecker.updateInfo == nil && !updateChecker.isChecking {
                await updateChecker.checkForUpdates()
            }
            if updateChecker.changelog.isEmpty {
                isLoadingChangelog = true
                await updateChecker.fetchChangelog()
                isLoadingChangelog = false
            }
        }
    }

    /// Update state as a short label for the Status row.
    private var statusText: String {
        guard let info = updateChecker.updateInfo else { return "Not checked" }
        return info.isUpdateAvailable ? "Update available (v\(info.latestVersion))" : "Up to date"
    }

    private var lastCheckedText: String {
        guard let date = updateChecker.lastCheckDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Row linking one changelog entry to its GitHub release page.
    @ViewBuilder
    private func releaseLink(for entry: ChangelogEntry) -> some View {
        Link(destination: entry.releaseURL) {
            HStack {
                Text("v\(entry.version)")
                Spacer()
                if let date = entry.date {
                    Text(date)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
    }
}
