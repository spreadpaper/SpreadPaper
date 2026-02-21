import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        TabView {
            // General Tab
            Form {
                Section {
                    Picker("Appearance", selection: $settings.selectedAppearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text("Choose how SpreadPaper appears. System matches your macOS appearance settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } header: {
                    Text("Appearance")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gear")
            }

            // Updates Tab
            Form {
                Section {
                    HStack {
                        Text("Current Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    if let info = updateChecker.updateInfo {
                        HStack {
                            Text("Latest Version")
                            Spacer()
                            Text(info.latestVersion)
                                .foregroundStyle(info.isUpdateAvailable ? .orange : .secondary)
                        }

                        if info.isUpdateAvailable {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.orange)
                                Text("Update Available")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("You're up to date")
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    HStack {
                        Button(action: { updateChecker.checkForUpdates() }) {
                            if updateChecker.isChecking {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            } else {
                                Text("Check for Updates")
                            }
                        }
                        .disabled(updateChecker.isChecking)

                        Spacer()

                        if let lastCheck = updateChecker.lastCheckDate {
                            Text("Last checked: \(lastCheck, formatter: Self.dateFormatter)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = updateChecker.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Version")
                        .font(.headline)
                }

                if let info = updateChecker.updateInfo, info.isUpdateAvailable {
                    Section {
                        if info.dmgUrl != nil {
                            Button(action: { updateChecker.downloadDMG() }) {
                                HStack {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text("Download DMG")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if info.zipUrl != nil {
                            Button(action: { updateChecker.downloadZIP() }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Download ZIP")
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(action: { updateChecker.openReleasePage() }) {
                            HStack {
                                Image(systemName: "safari")
                                Text("View on GitHub")
                            }
                        }
                        .buttonStyle(.bordered)
                    } header: {
                        Text("Download Update")
                            .font(.headline)
                    }

                    // Changelog Section
                    Section {
                        let relevantChanges = updateChecker.getChangelogBetweenVersions()
                        if relevantChanges.isEmpty && !info.releaseNotes.isEmpty {
                            // Show release notes from GitHub if no parsed changelog
                            if let attributedString = try? AttributedString(markdown: info.releaseNotes) {
                                Text(attributedString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(info.releaseNotes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(relevantChanges, id: \.version) { entry in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("v\(entry.version)")
                                            .font(.headline)
                                        if let date = entry.date {
                                            Text("(\(date))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if let attributedString = try? AttributedString(markdown: entry.content) {
                                        Text(attributedString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(entry.content)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("What's New")
                            .font(.headline)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Updates", systemImage: "arrow.triangle.2.circlepath")
            }
            .onAppear {
                // Auto-check on first view
                if updateChecker.updateInfo == nil && !updateChecker.isChecking {
                    updateChecker.checkForUpdates()
                }
            }
        }
        .frame(width: 450, height: 400)
        .padding(20)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
