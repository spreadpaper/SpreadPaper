import SwiftUI

enum SettingsTab: Hashable {
    case general
    case updates
}

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var updateChecker = UpdateChecker.shared
    @State private var selectedTab: SettingsTab = .general

    // Buffered edit state
    @State private var editingAppearance: AppearanceMode = .system

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                generalTab
                    .tabItem { Label("General", systemImage: "gear") }
                    .tag(SettingsTab.general)

                updatesTab
                    .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
                    .tag(SettingsTab.updates)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Done") {
                    settings.appearanceMode = editingAppearance
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 460, height: 380)
        .onAppear {
            editingAppearance = settings.appearanceMode
            if updateChecker.updateInfo?.isUpdateAvailable == true {
                selectedTab = .updates
            }
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Appearance") {
                Picker("Mode", selection: $editingAppearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Updates

    private var updatesTab: some View {
        Form {
            Section("Version") {
                LabeledContent("Current Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")

                if let info = updateChecker.updateInfo {
                    LabeledContent("Latest Version") {
                        Text(info.latestVersion)
                            .foregroundStyle(info.isUpdateAvailable ? .orange : .secondary)
                    }

                    LabeledContent("Status") {
                        if info.isUpdateAvailable {
                            Label("Update Available", systemImage: "arrow.down.circle.fill")
                                .foregroundStyle(.orange)
                        } else {
                            Label("Up to date", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }

                LabeledContent {
                    Button(action: { Task { await updateChecker.checkForUpdates() } }) {
                        if updateChecker.isChecking {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Check for Updates")
                        }
                    }
                    .disabled(updateChecker.isChecking)
                } label: {
                    if let lastCheck = updateChecker.lastCheckDate {
                        Text("Last checked: \(lastCheck, formatter: Self.dateFormatter)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = updateChecker.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            if let info = updateChecker.updateInfo, info.isUpdateAvailable {
                Section("Download") {
                    if info.dmgUrl != nil {
                        Button("Download DMG", systemImage: "arrow.down.doc") {
                            updateChecker.downloadDMG()
                        }
                    }

                    if info.zipUrl != nil {
                        Button("Download ZIP", systemImage: "arrow.down.circle") {
                            updateChecker.downloadZIP()
                        }
                    }

                    Button("View on GitHub", systemImage: "safari") {
                        updateChecker.openReleasePage()
                    }
                }

                Section("What's New") {
                    changelogContent(for: info)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            if updateChecker.updateInfo == nil && !updateChecker.isChecking {
                await updateChecker.checkForUpdates()
            }
        }
    }

    // MARK: - Changelog

    @ViewBuilder
    private func changelogContent(for info: UpdateInfo) -> some View {
        let relevantChanges = updateChecker.getChangelogBetweenVersions()

        if relevantChanges.isEmpty && !info.releaseNotes.isEmpty {
            markdownText(info.releaseNotes)
        } else {
            ForEach(relevantChanges, id: \.version) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("v\(entry.version)")
                            .fontWeight(.medium)
                        if let date = entry.date {
                            Text(date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    markdownText(entry.content)
                }
            }
        }
    }

    private func markdownText(_ content: String) -> some View {
        if let attributed = try? AttributedString(markdown: content) {
            Text(attributed)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text(content)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
