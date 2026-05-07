// SpreadPaper/Views/SettingsView.swift

import SwiftUI
import PhosphorSwift

enum SettingsTab: Hashable {
    case general
    case updates
}

// MARK: - Cmd+, window (kept for macOS standard behavior)

struct SettingsView: View {
    var body: some View {
        SettingsInWindowView(onClose: nil)
            .frame(width: 640, height: 520)
    }
}

// MARK: - In-window settings (replaces gallery split)

struct SettingsInWindowView: View {
    @State private var settings = AppSettings.shared
    @State private var updateChecker = UpdateChecker.shared
    @State private var selectedTab: SettingsTab = .general
    @State private var launchAtLogin: Bool = false
    @State private var showInMenuBar: Bool = false
    @AppStorage("showInMenuBar") private var showInMenuBarStored: Bool = false
    @AppStorage("launchAtLogin") private var launchAtLoginStored: Bool = false

    let onClose: (() -> Void)?

    private let version: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 220, alignment: .leading)
                .background(Color.cdBgSecondary)

            Divider().overlay(Color.cdBorder)

            VStack(spacing: 0) {
                toolbar
                Divider().overlay(Color.cdBorder)
                ScrollView {
                    Group {
                        switch selectedTab {
                        case .general: generalPane
                        case .updates: updatesPane
                        }
                    }
                    .frame(maxWidth: 540)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.cdBgPrimary)
            }
        }
        .onAppear {
            showInMenuBar = showInMenuBarStored
            launchAtLogin = launchAtLoginStored
            if updateChecker.updateInfo?.isUpdateAvailable == true {
                selectedTab = .updates
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 44)

            if let onClose {
                Button(action: onClose) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back to Library")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(Color.cdTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HoverFillButtonStyle())
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }

            Text("SETTINGS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.cdTextTertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            VStack(spacing: 2) {
                SettingsSidebarRow(
                    label: "General",
                    icon: AnyView(Ph.gear.regular.color(selectedTab == .general ? .white : Color.cdTextSecondary)),
                    isSelected: selectedTab == .general,
                    onTap: { selectedTab = .general }
                )
                SettingsSidebarRow(
                    label: "Updates",
                    icon: AnyView(Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(selectedTab == .updates ? .white : Color.cdTextSecondary)),
                    isSelected: selectedTab == .updates,
                    onTap: { selectedTab = .updates }
                )
            }
            .padding(.horizontal, 10)

            Spacer()

            Text("SpreadPaper \(version)")
                .font(.system(size: 11))
                .foregroundStyle(Color.cdTextTertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text(selectedTab == .general ? "General" : "Updates")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.cdTextPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(Color.cdBgPrimary)
    }

    // MARK: - General

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionGroup(header: "APPEARANCE") {
                SettingsRow(label: "Mode", hint: nil) {
                    AppearancePicker(mode: Binding(
                        get: { settings.appearanceMode },
                        set: { settings.appearanceMode = $0 }
                    ))
                }
            }

            SectionGroup(header: "BEHAVIOR") {
                SettingsRow(label: "Show in menu bar", hint: "Quick access from anywhere") {
                    SPToggle(isOn: $showInMenuBar)
                        .onChange(of: showInMenuBar) { _, new in showInMenuBarStored = new }
                }
                DividerLine()
                SettingsRow(label: "Launch at login", hint: nil) {
                    SPToggle(isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, new in launchAtLoginStored = new }
                }
            }
        }
    }

    // MARK: - Updates

    private var updatesPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionGroup(header: "VERSION") {
                SettingsRow(label: "Current", hint: nil) {
                    Text(version)
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.cdTextPrimary)
                }
                DividerLine()
                SettingsRow(label: "Status", hint: nil) {
                    statusLabel
                }
                DividerLine()
                SettingsRow(label: "Last checked", hint: nil) {
                    Text(lastCheckedText)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cdTextSecondary)
                }
            }

            Button(action: { Task { await updateChecker.checkForUpdates() } }) {
                HStack(spacing: 8) {
                    if updateChecker.isChecking {
                        ProgressView().controlSize(.small).tint(Color.cdTextPrimary)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(updateChecker.isChecking ? "Checking…" : "Check for Updates")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.cdTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(Color.cdBgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(Color.cdBorder, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(updateChecker.isChecking)

            if let info = updateChecker.updateInfo, info.isUpdateAvailable {
                SectionGroup(header: "DOWNLOAD") {
                    if info.dmgUrl != nil {
                        DownloadRow(title: "Download DMG", icon: "arrow.down.doc") { updateChecker.downloadDMG() }
                        DividerLine()
                    }
                    if info.zipUrl != nil {
                        DownloadRow(title: "Download ZIP", icon: "arrow.down.circle") { updateChecker.downloadZIP() }
                        DividerLine()
                    }
                    DownloadRow(title: "View on GitHub", icon: "safari") { updateChecker.openReleasePage() }
                }

                SectionGroup(header: "WHAT'S NEW") {
                    VStack(alignment: .leading, spacing: 14) {
                        changelogContent(for: info)
                    }
                    .padding(14)
                }
            }

            if let error = updateChecker.error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cdDanger)
            }
        }
        .task {
            if updateChecker.updateInfo == nil && !updateChecker.isChecking {
                await updateChecker.checkForUpdates()
            }
        }
    }

    private var statusLabel: some View {
        Group {
            if let info = updateChecker.updateInfo {
                if info.isUpdateAvailable {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Update available (v\(info.latestVersion))")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: 0xf5a524))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Up to date")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.cdSuccess)
                }
            } else {
                Text("—").foregroundStyle(Color.cdTextTertiary)
            }
        }
    }

    private var lastCheckedText: String {
        guard let date = updateChecker.lastCheckDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    @ViewBuilder
    private func changelogContent(for info: UpdateInfo) -> some View {
        let relevant = updateChecker.getChangelogBetweenVersions()
        if relevant.isEmpty && !info.releaseNotes.isEmpty {
            markdownText(info.releaseNotes)
        } else {
            ForEach(relevant, id: \.version) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("v\(entry.version)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.cdTextPrimary)
                        if let date = entry.date {
                            Text(date)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.cdTextTertiary)
                        }
                    }
                    markdownText(entry.content)
                }
            }
        }
    }

    private func markdownText(_ content: String) -> some View {
        Group {
            if let attributed = try? AttributedString(markdown: content) {
                Text(attributed)
            } else {
                Text(content)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.cdTextSecondary)
    }
}

// MARK: - Reusable components

private struct SettingsSidebarRow: View {
    let label: String
    let icon: AnyView
    let isSelected: Bool
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 9) {
                icon
                    .frame(width: 14, height: 14)
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.white : Color.cdTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.cdAccent : (hovering ? Color.cdBgHover : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct HoverFillButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Color.cdBgHover : Color.clear)
            )
            .onHover { hovering = $0 }
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

private struct SectionGroup<Content: View>: View {
    let header: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.cdTextTertiary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.cdBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let label: String
    let hint: String?
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.cdTextPrimary)
                if let hint {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cdTextTertiary)
                }
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Color.cdBorder)
            .frame(height: 1)
    }
}

private struct SPToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Color.cdAccent : Color.cdBgHover)
                .frame(width: 32, height: 19)
                .shadow(color: isOn ? Color.cdAccentGlow : .clear, radius: 6, y: 2)

            Circle()
                .fill(Color.white)
                .frame(width: 15, height: 15)
                .padding(.horizontal, 2)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
        }
        .animation(.easeInOut(duration: 0.16), value: isOn)
        .onTapGesture { isOn.toggle() }
    }
}

private struct AppearancePicker: View {
    @Binding var mode: AppearanceMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppearanceMode.allCases) { m in
                Button(action: { mode = m }) {
                    Text(m.rawValue)
                        .font(.system(size: 12, weight: mode == m ? .semibold : .medium))
                        .foregroundStyle(mode == m ? Color.white : Color.cdTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(mode == m ? Color.cdAccent : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cdBgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.cdBorder, lineWidth: 1)
        )
    }
}

private struct DownloadRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.cdAccent)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.cdTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.cdTextTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
